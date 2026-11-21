import Foundation

public struct RoadInfo: Identifiable {
    public var id: String { "\(name)-\(centerLat)-\(centerLon)" }
    public let name: String
    public let speedLimit: Int
    public let highwayType: String
    public let centerLat: Double
    public let centerLon: Double

    /// Biển phụ chuẩn giao thông Việt Nam gắn kèm dưới biển tốc độ
    public var subSignTitle: String {
        if highwayType.contains("motorway") {
            return "ĐƯỜNG CAO TỐC"
        } else if speedLimit >= 80 {
            return "NGOÀI ĐÔ THỊ"
        } else if speedLimit <= 60 {
            return "KHU ĐÔNG DÂN CƯ"
        } else {
            return "ÁP DỤNG XE CON"
        }
    }

    public var subSignIcon: String {
        if highwayType.contains("motorway") {
            return "road.lanes"
        } else if speedLimit >= 80 {
            return "car.fill"
        } else {
            return "building.2.fill"
        }
    }

    public init(name: String, speedLimit: Int, highwayType: String, centerLat: Double, centerLon: Double) {
        self.name = name
        self.speedLimit = speedLimit
        self.highwayType = highwayType
        self.centerLat = centerLat
        self.centerLon = centerLon
    }
}

public struct CameraInfo: Identifiable {
    public let id: Int
    public let name: String
    public let speedLimit: Int
    public let lat: Double
    public let lon: Double
    public var distance: Double = 0
}
