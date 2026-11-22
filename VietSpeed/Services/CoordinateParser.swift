import Foundation
import CoreLocation

public struct ParsedCoordinate: Equatable {
    public let coordinate: CLLocationCoordinate2D
    public let formattedString: String
    public let label: String?

    public static func == (lhs: ParsedCoordinate, rhs: ParsedCoordinate) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

public final class CoordinateParser {
    public static let shared = CoordinateParser()

    private init() {}

    /// Phân tích toạ độ GPS từ bất kỳ định dạng nào (chuỗi số, link Google Maps, độ phút giây DMS...)
    public func parse(_ text: String) -> ParsedCoordinate? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // 1. Kiểm tra định dạng DMS (Độ Phút Giây): 10°46'36.8"N 106°42'02.9"E
        if let dmsCoord = parseDMS(trimmed) {
            return makeResult(lat: dmsCoord.latitude, lon: dmsCoord.longitude, label: "Độ phút giây (DMS)")
        }

        // 2. Kiểm tra link chứa toạ độ (@lat,lon hoặc q=lat,lon hoặc !3d!4d)
        if let urlCoord = parseUrl(trimmed) {
            return makeResult(lat: urlCoord.latitude, lon: urlCoord.longitude, label: "Toạ độ từ Google Maps")
        }

        // 3. Kiểm tra định dạng số thập phân thông thường: 10.776889, 106.700806
        if let decCoord = parseDecimal(trimmed) {
            return makeResult(lat: decCoord.latitude, lon: decCoord.longitude, label: nil)
        }

        return nil
    }

    private func parseDecimal(_ text: String) -> CLLocationCoordinate2D? {
        // Tìm 2 cụm số thập phân cách nhau bởi dấu phẩy, khoảng trắng, dấu chấm phẩy hoặc từ ngữ
        let pattern = "(-?\\d{1,2}\\.\\d+)[^\\d-]+(-?\\d{1,3}\\.\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 3 else {
            return nil
        }

        let latStr = ns.substring(with: match.range(at: 1))
        let lonStr = ns.substring(with: match.range(at: 2))

        guard var lat = Double(latStr), var lon = Double(lonStr) else { return nil }

        // Tự động hoán vị nếu người dùng nhập ngược (Kinh độ trước, Vĩ độ sau)
        // Tại Việt Nam: Vĩ độ nằm trong khoảng [8.0 .. 24.0], Kinh độ nằm trong khoảng [102.0 .. 110.0]
        if lat > 50.0 && lon < 30.0 {
            swap(&lat, &lon)
        }

        guard validate(lat: lat, lon: lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func parseUrl(_ text: String) -> CLLocationCoordinate2D? {
        // @10.776889,106.700806
        if let atMatch = matchTwoFloats(pattern: "@(-?\\d{1,2}\\.\\d+),(-?\\d{1,3}\\.\\d+)", in: text) {
            return atMatch
        }

        // ?q=10.776889,106.700806 hoặc ll=10.776889,106.700806 hoặc daddr=10.776889,106.700806
        if let qMatch = matchTwoFloats(pattern: "[?&](?:q|ll|daddr|destination)=(-?\\d{1,2}\\.\\d+),(-?\\d{1,3}\\.\\d+)", in: text) {
            return qMatch
        }

        // !3d10.776889!4d106.700806 (Protobuf Google)
        if let protoMatch = matchTwoFloats(pattern: "!3d(-?\\d{1,2}\\.\\d+)!4d(-?\\d{1,3}\\.\\d+)", in: text) {
            return protoMatch
        }

        return nil
    }

    private func parseDMS(_ text: String) -> CLLocationCoordinate2D? {
        let pattern = "(\\d+)[°\\s]+(\\d+)['\\s]+([\\d.]+)[\\\"\\s]*([NSns])[^\\d]+(\\d+)[°\\s]+(\\d+)['\\s]+([\\d.]+)[\\\"\\s]*([EWew])"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 9 else {
            return nil
        }

        guard let d1 = Double(ns.substring(with: match.range(at: 1))),
              let m1 = Double(ns.substring(with: match.range(at: 2))),
              let s1 = Double(ns.substring(with: match.range(at: 3))),
              let d2 = Double(ns.substring(with: match.range(at: 5))),
              let m2 = Double(ns.substring(with: match.range(at: 6))),
              let s2 = Double(ns.substring(with: match.range(at: 7))) else {
            return nil
        }

        let h1 = ns.substring(with: match.range(at: 4)).uppercased()
        let h2 = ns.substring(with: match.range(at: 8)).uppercased()

        var lat = d1 + (m1 / 60.0) + (s1 / 3600.0)
        if h1 == "S" { lat = -lat }

        var lon = d2 + (m2 / 60.0) + (s2 / 3600.0)
        if h2 == "W" { lon = -lon }

        guard validate(lat: lat, lon: lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func matchTwoFloats(pattern: String, in text: String) -> CLLocationCoordinate2D? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 3 else {
            return nil
        }

        guard var lat = Double(ns.substring(with: match.range(at: 1))),
              var lon = Double(ns.substring(with: match.range(at: 2))) else {
            return nil
        }

        if lat > 50.0 && lon < 30.0 {
            swap(&lat, &lon)
        }

        guard validate(lat: lat, lon: lon) else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private func validate(lat: Double, lon: Double) -> Bool {
        lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0
    }

    private func makeResult(lat: Double, lon: Double, label: String?) -> ParsedCoordinate {
        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let formatted = String(format: "%.6f, %.6f", lat, lon)
        return ParsedCoordinate(coordinate: coord, formattedString: formatted, label: label)
    }
}
