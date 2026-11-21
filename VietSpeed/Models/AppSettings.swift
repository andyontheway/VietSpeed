import Foundation
import SwiftUI

public enum VehicleType: String, CaseIterable, Identifiable {
    case car = "car"
    case motorcycle = "motorcycle"
    case truck = "truck"
    case bus = "bus"
    case container = "container"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .car: return "Xe ô tô con (Dưới 9 chỗ)"
        case .motorcycle: return "Xe mô tô / Xe máy"
        case .truck: return "Xe tải (Trên 3.5 tấn)"
        case .bus: return "Xe khách (Trên 30 chỗ)"
        case .container: return "Xe container / Đầu kéo"
        }
    }

    public var icon: String {
        switch self {
        case .car: return "car.fill"
        case .motorcycle: return "bicycle"
        case .truck: return "truck.box.fill"
        case .bus: return "bus.fill"
        case .container: return "car.badge.gearshape.fill"
        }
    }

    public var subSignLabel: String {
        switch self {
        case .car: return "XE Ô TÔ CON"
        case .motorcycle: return "XE MÁY"
        case .truck: return "XE TẢI"
        case .bus: return "XE KHÁCH"
        case .container: return "CONTAINER"
        }
    }
}
