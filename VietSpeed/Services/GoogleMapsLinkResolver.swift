import Foundation
import CoreLocation

public struct ResolvedPlaceInfo {
    public let title: String
    public let coordinate: CLLocationCoordinate2D
    public let originalUrl: String?
}

public final class GoogleMapsLinkResolver {
    public static let shared = GoogleMapsLinkResolver()

    private init() {}

    /// Kiểm tra xem chuỗi văn bản có chứa liên kết Google Maps hoặc toạ độ GPS không
    public func containsGoogleMapsLinkOrCoordinate(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.contains("maps.app.goo.gl") ||
           lower.contains("goo.gl/maps") ||
           lower.contains("google.com/maps") ||
           lower.contains("maps.google.com") {
            return true
        }

        // Kiểm tra xem có phải toạ độ dạng "10.7719, 106.6983"
        return parseDirectCoordinate(text) != nil
    }

    /// Trích xuất URL từ đoạn văn bản người dùng chia sẻ từ Google Maps
    public func extractUrlFromText(_ text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        for match in matches ?? [] {
            if let range = Range(match.range, in: text), let url = URL(string: String(text[range])) {
                let host = url.host?.lowercased() ?? ""
                if host.contains("google.com") || host.contains("goo.gl") {
                    return url
                }
            }
        }
        return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Trích xuất tên địa điểm từ đoạn văn bản chia sẻ của Google Maps
    /// (Thường dòng đầu tiên là tên quán/địa điểm, ví dụ: "Phở Hoà Pasteur\n260C Pasteur...\nhttps://maps.app...")
    public func extractPlaceNameFromText(_ text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.lowercased().hasPrefix("http") }

        if let first = lines.first, first.count < 80 {
            return first
        }
        return nil
    }

    /// Bóc tách toạ độ và tên địa điểm từ Link hoặc Text Google Maps
    public func resolve(
        text: String,
        completion: @escaping (Result<ResolvedPlaceInfo, Error>) -> Void
    ) {
        // 1. Kiểm tra toạ độ trực tiếp dạng "10.7769, 106.7009"
        if let directCoord = parseDirectCoordinate(text) {
            let info = ResolvedPlaceInfo(
                title: "Toạ độ GPS",
                coordinate: directCoord,
                originalUrl: nil
            )
            DispatchQueue.main.async { completion(.success(info)) }
            return
        }

        // 2. Tìm link trong văn bản
        guard let url = extractUrlFromText(text) else {
            let error = NSError(domain: "VietSpeed", code: -1, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy liên kết Google Maps hợp lệ"])
            DispatchQueue.main.async { completion(.failure(error)) }
            return
        }

        let extractedName = extractPlaceNameFromText(text)
        let urlString = url.absoluteString

        // 3. Nếu link đã chứa toạ độ trực tiếp (@lat,lon hoặc q=lat,lon)
        if let (coord, nameFromUrl) = parseCoordinateFromUrlString(urlString) {
            let finalName = extractedName ?? nameFromUrl ?? "Điểm đến Google Maps"
            let info = ResolvedPlaceInfo(
                title: finalName,
                coordinate: coord,
                originalUrl: urlString
            )
            DispatchQueue.main.async { completion(.success(info)) }
            return
        }

        // 4. Nếu là link rút gọn (maps.app.goo.gl hoặc goo.gl/maps): Giải mã redirect
        resolveRedirectUrl(url: url) { [weak self] finalUrl, htmlBody in
            guard let self = self else { return }

            var resolvedCoord: CLLocationCoordinate2D?
            var resolvedName: String?

            if let finalUrlStr = finalUrl?.absoluteString {
                if let (coord, name) = self.parseCoordinateFromUrlString(finalUrlStr) {
                    resolvedCoord = coord
                    resolvedName = name
                }
            }

            // Nếu trong URL chưa có toạ độ: tìm trong meta tags của HTML trả về
            if resolvedCoord == nil, let html = htmlBody {
                resolvedCoord = self.parseCoordinateFromHtml(html)
            }

            if let coord = resolvedCoord {
                let finalName = extractedName ?? resolvedName ?? "Điểm đến Google Maps"
                let info = ResolvedPlaceInfo(
                    title: finalName,
                    coordinate: coord,
                    originalUrl: urlString
                )
                DispatchQueue.main.async { completion(.success(info)) }
            } else {
                let error = NSError(
                    domain: "VietSpeed",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "Không thể lấy toạ độ từ liên kết Google Maps này"]
                )
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Theo dõi redirect HTTP 301/302 để lấy URL đích cuối cùng
    private func resolveRedirectUrl(url: URL, completion: @escaping (URL?, String?) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let finalUrl = response?.url
            var html: String?
            if let data = data {
                html = String(data: data, encoding: .utf8)
            }
            completion(finalUrl, html)
        }
        task.resume()
    }

    /// Bóc tách toạ độ từ URL chuỗi ký tự bằng Regex
    private func parseCoordinateFromUrlString(_ urlStr: String) -> (CLLocationCoordinate2D, String?)? {
        // Regex 1: @10.776889,106.700806
        let patternAt = "@(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)"
        if let match = matchRegex(pattern: patternAt, in: urlStr) {
            if let lat = Double(match[1]), let lon = Double(match[2]) {
                let name = extractNameFromPlacePath(urlStr)
                return (CLLocationCoordinate2D(latitude: lat, longitude: lon), name)
            }
        }

        // Regex 2: ?q=10.776889,106.700806 hoặc daddr=10.776889,106.700806
        let patternQ = "[?&](?:q|ll|daddr|destination)=(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)"
        if let match = matchRegex(pattern: patternQ, in: urlStr) {
            if let lat = Double(match[1]), let lon = Double(match[2]) {
                let name = extractNameFromPlacePath(urlStr)
                return (CLLocationCoordinate2D(latitude: lat, longitude: lon), name)
            }
        }

        // Regex 3: !3d10.776889!4d106.700806 (Protobuf format của Google)
        let patternProto = "!3d(-?\\d+\\.\\d+)!4d(-?\\d+\\.\\d+)"
        if let match = matchRegex(pattern: patternProto, in: urlStr) {
            if let lat = Double(match[1]), let lon = Double(match[2]) {
                let name = extractNameFromPlacePath(urlStr)
                return (CLLocationCoordinate2D(latitude: lat, longitude: lon), name)
            }
        }

        return nil
    }

    /// Tìm toạ độ trong nội dung HTML trang đích của Google Maps (StaticMap hoặc Meta)
    private func parseCoordinateFromHtml(_ html: String) -> CLLocationCoordinate2D? {
        // 1. Tìm trong link staticmap: center=10.776889%2C106.700806
        let patternCenter = "center=(-?\\d+\\.\\d+)(?:%2C|,)(-?\\d+\\.\\d+)"
        if let match = matchRegex(pattern: patternCenter, in: html) {
            if let lat = Double(match[1]), let lon = Double(match[2]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        // 2. Tìm trong meta og:image hoặc window.APP_INITIALIZATION_STATE: [10.776889,106.700806]
        let patternAppInit = "\\[null,null,(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)\\]"
        if let match = matchRegex(pattern: patternAppInit, in: html) {
            if let lat = Double(match[1]), let lon = Double(match[2]) {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }

        return nil
    }

    /// Lấy tên địa điểm từ đường dẫn URL e.g. /place/Pho+Hoa+Pasteur/
    private func extractNameFromPlacePath(_ urlStr: String) -> String? {
        let pattern = "/place/([^/@?]+)"
        if let match = matchRegex(pattern: pattern, in: urlStr) {
            let encodedName = match[1]
            let decoded = encodedName.removingPercentEncoding ?? encodedName
            let clean = decoded.replacingOccurrences(of: "+", with: " ")
            return clean.isEmpty ? nil : clean
        }
        return nil
    }

    /// Kiểm tra và tách toạ độ từ chuỗi gõ tay thuần tuý e.g. "10.7769, 106.7009"
    private func parseDirectCoordinate(_ text: String) -> CLLocationCoordinate2D? {
        let pattern = "^\\s*(-?\\d+\\.\\d+)\\s*[,\\s]\\s*(-?\\d+\\.\\d+)\\s*$"
        if let match = matchRegex(pattern: pattern, in: text) {
            if let lat = Double(match[1]), let lon = Double(match[2]) {
                if lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 {
                    return CLLocationCoordinate2D(latitude: lat, longitude: lon)
                }
            }
        }
        return nil
    }

    private func matchRegex(pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsString = text as NSString
        guard let result = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsString.length)) else {
            return nil
        }
        var groups: [String] = []
        for i in 0..<result.numberOfRanges {
            groups.append(nsString.substring(with: result.range(at: i)))
        }
        return groups
    }
}
