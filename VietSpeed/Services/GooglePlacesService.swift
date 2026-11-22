import Foundation
import CoreLocation

// MARK: - MÔ HÌNH DỮ LIỆU GOOGLE PLACES
public struct GooglePlaceItem: Identifiable, Hashable {
    public let id: String // place_id
    public let title: String // main_text (Tên địa điểm, quán ăn...)
    public let subtitle: String // secondary_text (Địa chỉ chi tiết, quận, thành phố...)
    public let fullDescription: String

    public init(id: String, title: String, subtitle: String, fullDescription: String) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.fullDescription = fullDescription
    }
}

// Cấu trúc giải mã JSON từ Google Places Autocomplete API
private struct GoogleAutocompleteResponse: Decodable {
    let predictions: [Prediction]
    let status: String
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case predictions, status
        case errorMessage = "error_message"
    }

    struct Prediction: Decodable {
        let placeId: String
        let description: String
        let structuredFormatting: StructuredFormatting?

        enum CodingKeys: String, CodingKey {
            case placeId = "place_id"
            case description
            case structuredFormatting = "structured_formatting"
        }
    }

    struct StructuredFormatting: Decodable {
        let mainText: String?
        let secondaryText: String?

        enum CodingKeys: String, CodingKey {
            case mainText = "main_text"
            case secondaryText = "secondary_text"
        }
    }
}

// Cấu trúc giải mã JSON từ Google Place Details API
private struct GooglePlaceDetailsResponse: Decodable {
    let result: PlaceDetailResult?
    let status: String

    struct PlaceDetailResult: Decodable {
        let name: String?
        let formattedAddress: String?
        let geometry: Geometry?

        enum CodingKeys: String, CodingKey {
            case name
            case formattedAddress = "formatted_address"
            case geometry
        }
    }

    struct Geometry: Decodable {
        let location: LocationCoordinates?
    }

    struct LocationCoordinates: Decodable {
        let lat: Double
        let lng: Double
    }
}

// MARK: - GOOGLE PLACES SERVICE
public final class GooglePlacesService {
    public static let shared = GooglePlacesService()
    private var activeDataTask: URLSessionDataTask?

    private init() {}

    /// Tìm kiếm gợi ý địa điểm qua Google Places Autocomplete API
    public func searchAutocomplete(
        query: String,
        apiKey: String,
        userLocation: CLLocationCoordinate2D?,
        completion: @escaping ([GooglePlaceItem]) -> Void
    ) {
        // Huỷ request trước đó nếu người dùng đang tiếp tục gõ phím
        activeDataTask?.cancel()
        activeDataTask = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion([])
            return
        }

        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json")
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "input", value: trimmed),
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "language", value: "vi"), // Ưu tiên tiếng Việt
            URLQueryItem(name: "components", value: "country:vn") // Giới hạn lãnh thổ Việt Nam
        ]

        if let loc = userLocation {
            queryItems.append(URLQueryItem(name: "location", value: "\(loc.latitude),\(loc.longitude)"))
            queryItems.append(URLQueryItem(name: "radius", value: "50000")) // Bán kính 50km xung quanh xe
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            completion([])
            return
        }

        activeDataTask = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return // Đã huỷ vì có từ khoá mới
            }

            guard let data = data, error == nil else {
                print("❌ Lỗi mạng Google Places Autocomplete: \(error?.localizedDescription ?? "Unknown")")
                DispatchQueue.main.async { completion([]) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(GoogleAutocompleteResponse.self, from: data)
                if decoded.status == "OK" {
                    let items: [GooglePlaceItem] = decoded.predictions.map { pred in
                        let title = pred.structuredFormatting?.mainText ?? pred.description
                        let subtitle = pred.structuredFormatting?.secondaryText ?? ""
                        return GooglePlaceItem(
                            id: pred.placeId,
                            title: title,
                            subtitle: subtitle,
                            fullDescription: pred.description
                        )
                    }
                    DispatchQueue.main.async {
                        completion(items)
                    }
                } else {
                    if let err = decoded.errorMessage {
                        print("⚠️ Google Places API Status: \(decoded.status) - \(err)")
                    }
                    DispatchQueue.main.async { completion([]) }
                }
            } catch {
                print("❌ Lỗi giải mã JSON Google Places: \(error.localizedDescription)")
                DispatchQueue.main.async { completion([]) }
            }
        }

        activeDataTask?.resume()
    }

    /// Lấy toạ độ GPS chính xác (lat, lon) từ place_id của Google
    public func fetchPlaceLocation(
        placeId: String,
        apiKey: String,
        completion: @escaping (CLLocationCoordinate2D?, String?) -> Void
    ) {
        var components = URLComponents(string: "https://maps.googleapis.com/maps/api/place/details/json")
        components?.queryItems = [
            URLQueryItem(name: "place_id", value: placeId),
            URLQueryItem(name: "fields", value: "name,formatted_address,geometry"),
            URLQueryItem(name: "language", value: "vi"),
            URLQueryItem(name: "key", value: apiKey)
        ]

        guard let url = components?.url else {
            completion(nil, nil)
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Lỗi lấy toạ độ Google Place Details: \(error?.localizedDescription ?? "Unknown")")
                DispatchQueue.main.async { completion(nil, nil) }
                return
            }

            do {
                let decoded = try JSONDecoder().decode(GooglePlaceDetailsResponse.self, from: data)
                if decoded.status == "OK", let res = decoded.result, let loc = res.geometry?.location {
                    let coordinate = CLLocationCoordinate2D(latitude: loc.lat, longitude: loc.lng)
                    let name = res.name ?? "Điểm đến"
                    DispatchQueue.main.async {
                        completion(coordinate, name)
                    }
                } else {
                    DispatchQueue.main.async { completion(nil, nil) }
                }
            } catch {
                print("❌ Lỗi decode Place Details: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil, nil) }
            }
        }.resume()
    }
}
