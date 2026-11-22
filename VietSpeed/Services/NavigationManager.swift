import Foundation
import MapKit
import Combine
import CoreLocation

public final class NavigationManager: NSObject, ObservableObject {
    public static let shared = NavigationManager()

    @Published public var searchResults: [MKMapItem] = []
    @Published public var isSearching: Bool = false
    @Published public var activeRoute: MKRoute? = nil
    @Published public var isNavigating: Bool = false
    @Published public var destinationTitle: String? = nil
    @Published public var remainingDistance: String = ""
    @Published public var remainingTime: String = ""
    @Published public var nextInstruction: String = ""
    @Published public var nextStepDistance: String = ""
    @Published public var nextStepIcon: String = "arrow.up"

    private var cancellables = Set<AnyCancellable>()

    override private init() {
        super.init()
    }

    /// Tìm kiếm địa điểm bằng Apple MapKit
    public func searchPlaces(query: String, userLocation: CLLocationCoordinate2D? = nil) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        if let loc = userLocation {
            request.region = MKCoordinateRegion(
                center: loc,
                latitudinalMeters: 50_000,
                longitudinalMeters: 50_000
            )
        }

        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                guard let self = self, let response = response else { return }
                self.searchResults = response.mapItems
            }
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
        remainingDistance = ""
        remainingTime = ""
        nextInstruction = ""
        VoiceAlertManager.shared.speak(key: "stop_nav", message: "Đã kết thúc chỉ đường.", cooldownSeconds: 2.0)
    }
}
