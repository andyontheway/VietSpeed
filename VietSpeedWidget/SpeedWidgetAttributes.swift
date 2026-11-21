import Foundation
import ActivityKit

public struct SpeedWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var currentSpeed: Int
        public var speedLimit: Int
        public var roadName: String
        public var isOverSpeed: Bool
        public var subSign: String
        public var cameraAlertText: String?

        public init(currentSpeed: Int, speedLimit: Int, roadName: String, isOverSpeed: Bool, subSign: String, cameraAlertText: String? = nil) {
            self.currentSpeed = currentSpeed
            self.speedLimit = speedLimit
            self.roadName = roadName
            self.isOverSpeed = isOverSpeed
            self.subSign = subSign
            self.cameraAlertText = cameraAlertText
        }
    }

    public var title: String

    public init(title: String = "VietSpeed") {
        self.title = title
    }
}
