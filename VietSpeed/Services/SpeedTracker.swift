import Foundation
import CoreLocation
import Combine
import ActivityKit
import UIKit

public final class SpeedTracker: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = SpeedTracker()
    private let locationManager = CLLocationManager()

    @Published public var currentSpeed: Int = 0          // km/h (0 nếu đứng yên)
    @Published public var speedLimit: Int? = nil         // Giới hạn tốc độ tuyến đường
    @Published public var roadName: String = "Đang tìm tín hiệu GPS..."
    @Published public var isOverSpeed: Bool = false
    @Published public var activeCamera: CameraInfo? = nil
    @Published public var currentRoad: RoadInfo? = nil
    @Published public var gpsAccuracy: Double = 0.0
    @Published public var isLocationAuthorized: Bool = false
    @Published public var isSimulating: Bool = false
    @Published public var isDynamicIslandActive: Bool = false
    @Published public var lastCoordinate: CLLocationCoordinate2D? = nil
    @Published public var lastLocationObject: CLLocation? = nil
    @Published public var gpsStatusText: String = "Đang tìm vệ tinh GPS..."

    private var previousSpeedLimit: Int? = nil
    private var simulationTimer: AnyCancellable?
    private var liveActivity: Activity<SpeedWidgetAttributes>?
    private var hasSetupLocation = false
    private var isQuerying = false
    private var pendingLocation: CLLocation? = nil
    private var lastQueriedLocation: CLLocation? = nil
    private var lastQueryTime: Date = Date.distantPast

    override public init() {
        super.init()

        // LẮNG NGHE KHI THOÁT HOẶC KILL APP: TẮT DYNAMIC ISLAND NGAY LẬP TỨC
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppExit),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleAppExit() {
        stopAllLiveActivities()
    }

    /// CHỦ ĐỘNG BẬT VÀ KẾT NỐI GPS THẬT
    public func setupLocationManager() {
        guard !hasSetupLocation else { return }
        hasSetupLocation = true

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2.0
        locationManager.activityType = .automotiveNavigation

        // Yêu cầu quyền GPS
        locationManager.requestWhenInUseAuthorization()

        // Bắt đầu cập nhật vị trí GPS ngay lập tức
        locationManager.startUpdatingLocation()

        enableBackgroundModesIfAuthorized()

        if let loc = locationManager.location {
            handleNewLocation(loc)
        }
    }

    private func enableBackgroundModesIfAuthorized() {
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            locationManager.showsBackgroundLocationIndicator = true
            if status == .authorizedWhenInUse {
                locationManager.requestAlwaysAuthorization()
            }
        }
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        enableBackgroundModesIfAuthorized()
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isLocationAuthorized = true
            gpsStatusText = "Đã cấp quyền GPS"
            locationManager.startUpdatingLocation()
            if let loc = locationManager.location {
                handleNewLocation(loc)
            } else {
                roadName = "Đang tìm tín hiệu GPS ngoài trời..."
            }
        case .denied, .restricted:
            isLocationAuthorized = false
            gpsStatusText = "Chưa cho phép GPS"
            roadName = "Vui lòng cho phép quyền Vị trí trong Cài đặt"
        case .notDetermined:
            isLocationAuthorized = false
            gpsStatusText = "Chờ cấp quyền GPS..."
        @unknown default:
            break
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isSimulating else { return } // Không can thiệp nếu đang bật nút Test Demo
        guard let location = locations.last else { return }
        handleNewLocation(location)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("⚠️ CoreLocation Error: \(error.localizedDescription)")
        DispatchQueue.main.async {
            if let clErr = error as? CLError, clErr.code == .locationUnknown {
                self.gpsStatusText = "Đang tìm vệ tinh GPS ngoài trời..."
            } else {
                self.gpsStatusText = "Tín hiệu GPS yếu"
            }
        }
    }

    private func handleNewLocation(_ location: CLLocation) {
        let rawSpeed = location.speed
        let speedKmh = rawSpeed > 0 ? Int(rawSpeed * 3.6) : 0
        let accuracy = location.horizontalAccuracy

        DispatchQueue.main.async {
            self.currentSpeed = speedKmh
            self.gpsAccuracy = accuracy
            self.lastCoordinate = location.coordinate
            self.lastLocationObject = location
            if accuracy > 0 {
                self.gpsStatusText = "GPS: Tốt (±\(Int(accuracy))m)"
            }
        }

        evaluateAndQuery(location: location, speedKmh: speedKmh)
    }

    private func evaluateAndQuery(location: CLLocation, speedKmh: Int) {
        let now = Date()

        // Nếu đang có truy vấn đang chạy: lưu location mới nhất vào pending
        if isQuerying {
            pendingLocation = location
            return
        }

        // Nếu mới truy vấn cách đây < 0.8s và di chuyển chưa tới 5 mét -> bỏ qua
        if let last = lastQueriedLocation,
           location.distance(from: last) < 5.0,
           now.timeIntervalSince(lastQueryTime) < 0.8 {
            return
        }

        isQuerying = true
        lastQueriedLocation = location
        lastQueryTime = now

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let road = DatabaseManager.shared.findNearestRoad(lat: lat, lon: lon)
            let camera = DatabaseManager.shared.findNearbyCamera(lat: lat, lon: lon)

            DispatchQueue.main.async {
                self.applyDatabaseResults(road: road, camera: camera, speedKmh: speedKmh)
                self.isQuerying = false

                // Nếu có toạ độ mới hơn đến trong lúc đang query: tiếp tục chạy
                if let nextLoc = self.pendingLocation {
                    self.pendingLocation = nil
                    self.evaluateAndQuery(location: nextLoc, speedKmh: self.currentSpeed)
                }
            }
        }
    }

    private func applyDatabaseResults(road: RoadInfo?, camera: CameraInfo?, speedKmh: Int) {
        self.currentRoad = road
        if let road = road {
            self.roadName = road.name
            self.speedLimit = road.speedLimit
            self.isOverSpeed = (speedKmh > road.speedLimit && road.speedLimit > 0)

            // Cảnh báo giọng nói khi tốc độ thay đổi
            if self.previousSpeedLimit != nil && self.previousSpeedLimit != road.speedLimit {
                VoiceAlertManager.shared.alertSpeedLimitChanged(newLimit: road.speedLimit, roadName: road.name)
            }
            self.previousSpeedLimit = road.speedLimit

            // Cảnh báo quá tốc độ
            if self.isOverSpeed {
                VoiceAlertManager.shared.alertOverSpeed(limit: road.speedLimit)
            }
        } else {
            self.roadName = "Khu dân cư (Chưa vào đường chính)"
            self.speedLimit = nil
            self.isOverSpeed = false
        }

        self.activeCamera = camera
        if let camera = camera {
            VoiceAlertManager.shared.alertCamera(camera: camera)
        }

        // Cập nhật Dynamic Island NẾU đang được bật
        if self.isDynamicIslandActive {
            self.updateLiveActivity(speedKmh: speedKmh, road: road, camera: camera)
        }
    }

    // MARK: - Quản lý Live Activity / Dynamic Island (Bật / Tắt chủ động)
    public func toggleDynamicIsland() {
        if isDynamicIslandActive {
            stopAllLiveActivities()
        } else {
            startLiveActivity(
                initialSpeed: currentSpeed,
                limit: speedLimit ?? 60,
                roadName: roadName,
                subSign: currentRoad?.subSignTitle ?? "KHU ĐÔNG DÂN CƯ"
            )
        }
    }

    public func startLiveActivity(initialSpeed: Int = 0, limit: Int = 60, roadName: String = "VietSpeed", subSign: String = "KHU ĐÔNG DÂN CƯ") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Kết nối lại nếu đã có
        if let existing = Activity<SpeedWidgetAttributes>.activities.first {
            self.liveActivity = existing
            self.isDynamicIslandActive = true
            return
        }

        let attributes = SpeedWidgetAttributes(title: "VietSpeed Live")
        let state = SpeedWidgetAttributes.ContentState(
            currentSpeed: initialSpeed,
            speedLimit: limit,
            roadName: roadName,
            isOverSpeed: initialSpeed > limit,
            subSign: subSign,
            cameraAlertText: nil
        )

        do {
            liveActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            self.isDynamicIslandActive = true
            print("🟢 Đã bật Dynamic Island!")
        } catch {
            print("Lỗi bật Dynamic Island: \(error.localizedDescription)")
        }
    }

    public func stopAllLiveActivities() {
        Task {
            for activity in Activity<SpeedWidgetAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            await MainActor.run {
                self.liveActivity = nil
                self.isDynamicIslandActive = false
            }
            print("🛑 Đã tắt sạch Dynamic Island!")
        }
    }

    public func updateLiveActivity(speedKmh: Int, road: RoadInfo?, camera: CameraInfo?) {
        guard isDynamicIslandActive else { return }

        let limit = road?.speedLimit ?? 60
        let rName = road?.name ?? "VietSpeed"
        let sub = road?.subSignTitle ?? "KHU ĐÔNG DÂN CƯ"
        let isOver = (speedKmh > limit && limit > 0)
        let camText = camera != nil ? "📷 Phạt nguội \(Int(camera!.distance))m" : nil

        guard let activity = liveActivity ?? Activity<SpeedWidgetAttributes>.activities.first else {
            startLiveActivity(initialSpeed: speedKmh, limit: limit, roadName: rName, subSign: sub)
            return
        }
        self.liveActivity = activity

        let updatedState = SpeedWidgetAttributes.ContentState(
            currentSpeed: speedKmh,
            speedLimit: limit,
            roadName: rName,
            isOverSpeed: isOver,
            subSign: sub,
            cameraAlertText: camText
        )

        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }

    // MARK: - CHẾ ĐỘ DEMO & CHUYỂN VỀ GPS THẬT
    public func toggleSpecialDemo() {
        if isSimulating {
            stopDemoAndSwitchToRealGPS()
        } else {
            startSpecialDemo()
        }
    }

    private func startSpecialDemo() {
        isSimulating = true
        startLiveActivity(initialSpeed: 55, limit: 60, roadName: "Mai Chí Thọ", subSign: "KHU ĐÔNG DÂN CƯ")

        struct DemoStep {
            let road: String
            let speed: Int
            let limit: Int
            let subSign: String
            let camDist: Int?
            let voiceMsg: String?
        }

        let steps: [DemoStep] = [
            DemoStep(
                road: "Đại lộ Mai Chí Thọ",
                speed: 55,
                limit: 60,
                subSign: "KHU ĐÔNG DÂN CƯ",
                camDist: nil,
                voiceMsg: "Đại lộ Mai Chí Thọ. Tốc độ giới hạn 60."
            ),
            DemoStep(
                road: "Đại lộ Mai Chí Thọ",
                speed: 56,
                limit: 60,
                subSign: "KHU ĐÔNG DÂN CƯ",
                camDist: 500,
                voiceMsg: "Chú ý! Phía trước cách 500 mét có camera phạt nguội."
            ),
            DemoStep(
                road: "Đại lộ Mai Chí Thọ",
                speed: 68,
                limit: 60,
                subSign: "KHU ĐÔNG DÂN CƯ",
                camDist: 350,
                voiceMsg: "Tốc độ giới hạn 60. Bạn đang chạy quá tốc độ!"
            ),
            DemoStep(
                road: "Cao tốc TP.HCM - Long Thành",
                speed: 90,
                limit: 120,
                subSign: "ĐƯỜNG CAO TỐC",
                camDist: nil,
                voiceMsg: "Đoạn đường cao tốc. Tốc độ giới hạn 120 ki-lô-mét một giờ."
            ),
            DemoStep(
                road: "Cao tốc TP.HCM - Long Thành",
                speed: 115,
                limit: 120,
                subSign: "ĐƯỜNG CAO TỐC",
                camDist: nil,
                voiceMsg: nil
            ),
            DemoStep(
                road: "Nút giao Dầu Giây (Đường nhánh)",
                speed: 62,
                limit: 60,
                subSign: "KHU ĐÔNG DÂN CƯ",
                camDist: nil,
                voiceMsg: "Chú ý giảm tốc độ. Tốc độ giới hạn 60."
            )
        ]

        var stepIndex = 0

        func executeStep() {
            let st = steps[stepIndex]
            self.currentSpeed = st.speed
            self.speedLimit = st.limit
            self.roadName = st.road
            self.isOverSpeed = (st.speed > st.limit)
            let demoLat = st.road.contains("Cao tốc") ? 10.795 : 10.780
            let demoLon = st.road.contains("Cao tốc") ? 106.760 : 106.740
            let demoCoord = CLLocationCoordinate2D(latitude: demoLat, longitude: demoLon)
            self.lastCoordinate = demoCoord
            self.lastLocationObject = CLLocation(
                coordinate: demoCoord,
                altitude: 15,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                course: 65.0,
                speed: Double(st.speed) / 3.6,
                timestamp: Date()
            )

            self.currentRoad = RoadInfo(
                name: st.road,
                speedLimit: st.limit,
                highwayType: st.limit >= 100 ? "motorway" : "primary",
                centerLat: 10.78,
                centerLon: 106.74
            )

            if let dist = st.camDist {
                self.activeCamera = CameraInfo(id: 99, name: "Camera phạt nguội", speedLimit: st.limit, lat: 10.785, lon: 106.745, distance: Double(dist))
            } else {
                self.activeCamera = nil
            }

            if let msg = st.voiceMsg {
                VoiceAlertManager.shared.speak(key: "demo_\(stepIndex)", message: msg, cooldownSeconds: 1.0)
            }

            let camText = st.camDist != nil ? "📷 Phạt nguội \(st.camDist!)m" : nil
            let islandState = SpeedWidgetAttributes.ContentState(
                currentSpeed: st.speed,
                speedLimit: st.limit,
                roadName: st.road,
                isOverSpeed: self.isOverSpeed,
                subSign: st.subSign,
                cameraAlertText: camText
            )
            Task {
                await self.liveActivity?.update(.init(state: islandState, staleDate: nil))
            }

            stepIndex = (stepIndex + 1) % steps.count
        }

        executeStep()
        simulationTimer = Timer.publish(every: 4.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                executeStep()
            }
    }

    public func stopDemoAndSwitchToRealGPS() {
        isSimulating = false
        simulationTimer?.cancel()
        simulationTimer = nil
        activeCamera = nil
        isOverSpeed = false
        previousSpeedLimit = nil

        // TẮT SẠCH DYNAMIC ISLAND KHI DỪNG TEST
        stopAllLiveActivities()

        locationManager.startUpdatingLocation()

        if let realLoc = locationManager.location {
            handleNewLocation(realLoc)
        } else {
            self.currentSpeed = 0
            self.roadName = "Đang bắt GPS thực tế..."
        }

        VoiceAlertManager.shared.speak(key: "gps_active", message: "Đã dừng test. Trở về GPS thực tế.", cooldownSeconds: 2.0)
    }
}
