import Foundation
import MapKit
import Combine
import CoreLocation
import UIKit

// MARK: - MÔ HÌNH KẾT QUẢ TÌM KIẾM
public struct PlaceSearchResult: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let isGoogleLink: Bool
    public let coordinate: CLLocationCoordinate2D?
    public let mapItem: MKMapItem?

    public init(id: String, title: String, subtitle: String, isGoogleLink: Bool, coordinate: CLLocationCoordinate2D?, mapItem: MKMapItem?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.isGoogleLink = isGoogleLink
        self.coordinate = coordinate
        self.mapItem = mapItem
    }

    public static func == (lhs: PlaceSearchResult, rhs: PlaceSearchResult) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public final class NavigationManager: NSObject, ObservableObject {
    public static let shared = NavigationManager()

    @Published public var searchResults: [PlaceSearchResult] = []
    @Published public var isSearching: Bool = false
    @Published public var isResolvingLink: Bool = false
    @Published public var resolvingStatusText: String? = nil
    @Published public var activeRoute: MKRoute? = nil
    @Published public var isNavigating: Bool = false
    @Published public var destinationTitle: String? = nil
    @Published public var destinationCoordinate: CLLocationCoordinate2D? = nil
    @Published public var remainingDistance: String = ""
    @Published public var remainingTime: String = ""
    @Published public var nextInstruction: String = ""
    @Published public var nextStepDistance: String = ""
    @Published public var nextStepIcon: String = "arrow.up"

    private var cancellables = Set<AnyCancellable>()
    private var currentSearch: MKLocalSearch?

    override private init() {
        super.init()
    }

    /// Tìm kiếm địa điểm (Ưu tiên toạ độ GPS trước, sau đó tới link Google Maps hoặc từ khoá)
    public func searchPlaces(query: String, userLocation: CLLocationCoordinate2D? = nil) {
        currentSearch?.cancel()
        currentSearch = nil

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }

        // 🌟 1. ƯU TIÊN SỐ 1: PHÂN TÍCH TOẠ ĐỘ GPS TRỰC TIẾP (10.7769, 106.7009 hoặc DMS)
        if let parsed = CoordinateParser.shared.parse(trimmed) {
            let lat = parsed.coordinate.latitude
            let lon = parsed.coordinate.longitude

            // Tìm tên đường gần nhất từ cơ sở dữ liệu offline để tài xế dễ nhận biết
            let road = DatabaseManager.shared.findNearestRoad(lat: lat, lon: lon)
            let roadName = road?.name ?? "Điểm toạ độ GPS"

            let item = PlaceSearchResult(
                id: parsed.formattedString,
                title: "📍 \(roadName)",
                subtitle: "Toạ độ: \(parsed.formattedString)",
                isGoogleLink: false,
                coordinate: parsed.coordinate,
                mapItem: nil
            )
            self.searchResults = [item]
            self.isSearching = false
            return
        }

        // 🌟 2. NẾU LÀ LIÊN KẾT GOOGLE MAPS: BÓC TÁCH TOẠ ĐỘ
        if GoogleMapsLinkResolver.shared.containsGoogleMapsLinkOrCoordinate(trimmed) {
            isResolvingLink = true
            resolvingStatusText = "Đang phân tích toạ độ từ link..."

            GoogleMapsLinkResolver.shared.resolve(text: trimmed) { [weak self] result in
                guard let self = self else { return }
                self.isResolvingLink = false
                self.resolvingStatusText = nil

                switch result {
                case .success(let info):
                    let item = PlaceSearchResult(
                        id: "\(info.coordinate.latitude),\(info.coordinate.longitude)",
                        title: info.title,
                        subtitle: "Toạ độ: \(String(format: "%.5f, %.5f", info.coordinate.latitude, info.coordinate.longitude))",
                        isGoogleLink: true,
                        coordinate: info.coordinate,
                        mapItem: nil
                    )
                    self.searchResults = [item]
                case .failure(let error):
                    print("⚠️ Không bóc tách được: \(error.localizedDescription)")
                    self.searchResults = []
                }
            }
            return
        }

        // 3. TÌM KIẾM MẶC ĐỊNH BẰNG APPLE MAPKIT
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.pointOfInterest, .address]

        if let loc = userLocation {
            request.region = MKCoordinateRegion(
                center: loc,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        let search = MKLocalSearch(request: request)
        currentSearch = search
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                guard let self = self, let response = response else { return }
                self.searchResults = response.mapItems.map { item in
                    PlaceSearchResult(
                        id: "\(item.placemark.coordinate.latitude),\(item.placemark.coordinate.longitude)",
                        title: item.name ?? "Điểm đến",
                        subtitle: item.placemark.title ?? "",
                        isGoogleLink: false,
                        coordinate: item.placemark.coordinate,
                        mapItem: item
                    )
                }
            }
        }
    }

    /// Dẫn đường trực tiếp đến toạ độ GPS
    public func navigateToCoordinate(
        coordinate: CLLocationCoordinate2D,
        customTitle: String? = nil,
        startCoord: CLLocationCoordinate2D,
        completion: ((Bool) -> Void)? = nil
    ) {
        let road = DatabaseManager.shared.findNearestRoad(lat: coordinate.latitude, lon: coordinate.longitude)
        let title = customTitle ?? road?.name ?? String(format: "Toạ độ %.4f, %.4f", coordinate.latitude, coordinate.longitude)

        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = title

        self.destinationCoordinate = coordinate
        self.calculateRoute(from: startCoord, to: mapItem, completion: completion)
    }

    /// Khởi chạy dẫn đường từ chuỗi toạ độ hoặc liên kết (Dán toạ độ / link)
    public func resolveLinkAndNavigate(text: String, startCoord: CLLocationCoordinate2D, completion: ((Bool) -> Void)? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let parsed = CoordinateParser.shared.parse(trimmed) {
            navigateToCoordinate(coordinate: parsed.coordinate, customTitle: nil, startCoord: startCoord, completion: completion)
            return
        }

        isResolvingLink = true
        resolvingStatusText = "Đang phân tích toạ độ..."

        GoogleMapsLinkResolver.shared.resolve(text: trimmed) { [weak self] result in
            guard let self = self else { return }
            self.isResolvingLink = false
            self.resolvingStatusText = nil

            switch result {
            case .success(let info):
                let placemark = MKPlacemark(coordinate: info.coordinate)
                let mapItem = MKMapItem(placemark: placemark)
                mapItem.name = info.title
                self.destinationCoordinate = info.coordinate
                self.calculateRoute(from: startCoord, to: mapItem, completion: completion)
            case .failure(let error):
                print("❌ Lỗi phân tích: \(error.localizedDescription)")
                completion?(false)
            }
        }
    }

    /// Khởi chạy dẫn đường từ kết quả tìm kiếm đã chọn
    public func navigateTo(
        item: PlaceSearchResult,
        startCoord: CLLocationCoordinate2D,
        completion: ((Bool) -> Void)? = nil
    ) {
        if let coord = item.coordinate {
            navigateToCoordinate(coordinate: coord, customTitle: item.title, startCoord: startCoord, completion: completion)
        } else if let mapItem = item.mapItem {
            self.destinationCoordinate = mapItem.placemark.coordinate
            self.calculateRoute(from: startCoord, to: mapItem, completion: completion)
        }
    }

    /// Tính toán đường đi từ vị trí hiện tại đến điểm đến
    public func calculateRoute(from startCoord: CLLocationCoordinate2D, to destinationItem: MKMapItem, completion: ((Bool) -> Void)? = nil) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startCoord))
        request.destination = destinationItem
        request.transportType = .automobile
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self, let route = response?.routes.first else {
                    print("Lỗi tính toán đường đi: \(error?.localizedDescription ?? "Không tìm thấy đường")")
                    completion?(false)
                    return
                }

                self.activeRoute = route
                self.destinationTitle = destinationItem.name ?? "Điểm đến"
                self.destinationCoordinate = destinationItem.placemark.coordinate
                self.updateRouteMetrics(route: route)
                self.isNavigating = true
                self.searchResults = []

                // Thông báo giọng nói tiếng Việt
                let km = String(format: "%.1f", route.distance / 1000.0)
                let minutes = Int(route.expectedTravelTime / 60.0)
                VoiceAlertManager.shared.speak(
                    key: "start_nav",
                    message: "Bắt đầu chỉ đường đến \(self.destinationTitle ?? "điểm đến"). Quãng đường \(km) ki-lô-mét, dự kiến \(minutes) phút.",
                    cooldownSeconds: 2.0
                )

                completion?(true)
            }
        }
    }

    /// Cập nhật thông số lộ trình (khoảng cách & thời gian)
    public func updateRouteMetrics(route: MKRoute) {
        let km = route.distance / 1000.0
        if km >= 1.0 {
            remainingDistance = String(format: "%.1f km", km)
        } else {
            remainingDistance = "\(Int(route.distance)) m"
        }

        let minutes = Int(ceil(route.expectedTravelTime / 60.0))
        if minutes >= 60 {
            let hours = minutes / 60
            let remMin = minutes % 60
            remainingTime = "\(hours)h \(remMin)p"
        } else {
            remainingTime = "\(max(1, minutes)) phút"
        }

        if let firstStep = route.steps.dropFirst().first {
            nextInstruction = firstStep.instructions.isEmpty ? "Đi thẳng theo tuyến đường" : firstStep.instructions
            let stepMeters = Int(firstStep.distance)
            nextStepDistance = stepMeters >= 1000 ? String(format: "%.1f km", Double(stepMeters) / 1000.0) : "\(stepMeters) m"
            nextStepIcon = determineManeuverIcon(instruction: firstStep.instructions)
        } else {
            nextInstruction = "Tiếp tục di chuyển theo lộ trình"
            nextStepDistance = ""
            nextStepIcon = "arrow.up"
        }
    }

    /// Phân tích chỉ dẫn để lấy icon mũi tên phù hợp
    private func determineManeuverIcon(instruction: String) -> String {
        let lower = instruction.lowercased()
        if lower.contains("phải") || lower.contains("right") {
            return "arrow.turn.up.right"
        } else if lower.contains("trái") || lower.contains("left") {
            return "arrow.turn.up.left"
        } else if lower.contains("quay đầu") || lower.contains("u-turn") {
            return "arrow.uturn.down"
        } else if lower.contains("bùng binh") || lower.contains("vòng xuyến") || lower.contains("roundabout") {
            return "arrow.triangle.2.circlepath"
        } else {
            return "arrow.up"
        }
    }

    /// Huỷ dẫn đường
    public func stopNavigation() {
        activeRoute = nil
        isNavigating = false
        destinationTitle = nil
        destinationCoordinate = nil
        remainingDistance = ""
        remainingTime = ""
        nextInstruction = ""
        VoiceAlertManager.shared.speak(key: "stop_nav", message: "Đã kết thúc chỉ đường.", cooldownSeconds: 2.0)
    }

    /// Mở địa điểm / lộ trình trực tiếp sang ứng dụng Google Maps chính thức
    public static func openInGoogleMapsApp(destinationCoord: CLLocationCoordinate2D, destinationName: String?) {
        let lat = destinationCoord.latitude
        let lon = destinationCoord.longitude
        let appUrl = URL(string: "comgooglemaps://?daddr=\(lat),\(lon)&directionsmode=driving")
        let webUrl = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lon)")

        if let appUrl = appUrl, UIApplication.shared.canOpenURL(appUrl) {
            UIApplication.shared.open(appUrl)
        } else if let webUrl = webUrl {
            UIApplication.shared.open(webUrl)
        }
    }
}
