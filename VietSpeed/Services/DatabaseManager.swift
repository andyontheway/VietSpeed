import Foundation
import SQLite3
import CoreLocation

public final class DatabaseManager {
    public static let shared = DatabaseManager()
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.jr.VietSpeed.database", qos: .userInitiated)

    private init() {
        openDatabase()
    }

    deinit {
        queue.sync {
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
        }
    }

    private func openDatabase() {
        // 1. Kiểm tra trong Documents trước (nếu người dùng cập nhật file mới qua mạng)
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localURL = docs.appendingPathComponent("roads_vietnam.sqlite")
        var path = localURL.path

        if !FileManager.default.fileExists(atPath: path) {
            // 2. Dùng file mặc định nhúng trong App Bundle
            if let bundlePath = Bundle.main.path(forResource: "roads_vietnam", ofType: "sqlite") {
                path = bundlePath
            } else {
                print("❌ Không tìm thấy roads_vietnam.sqlite trong bundle!")
                return
            }
        }

        // Mở SQLite ở chế độ READONLY + FULLMUTEX (an toàn tuyệt đối cho đa luồng)
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path, &db, flags, nil) == SQLITE_OK {
            print("✅ Đã kết nối cơ sở dữ liệu đường Việt Nam: \(path)")
        } else {
            print("❌ Lỗi mở database SQLite")
        }
    }

    /// Tra cứu đoạn đường gần nhất với toạ độ GPS (Thread-Safe bằng queue.sync)
    public func findNearestRoad(lat: Double, lon: Double, deltaMeters: Double = 50.0) -> RoadInfo? {
        return queue.sync {
            if let road = queryRoadInternal(lat: lat, lon: lon, deltaMeters: deltaMeters) {
                return road
            }
            // Mở rộng bán kính 100m khi ở trong nhà / mép đường
            return queryRoadInternal(lat: lat, lon: lon, deltaMeters: 100.0)
        }
    }

    private func queryRoadInternal(lat: Double, lon: Double, deltaMeters: Double) -> RoadInfo? {
        guard let db = db else { return nil }

        let deltaDeg = deltaMeters / 111000.0

        let query = """
            SELECT r.name, r.speed_limit, r.highway_type, r.center_lat, r.center_lon
            FROM road_index idx
            JOIN roads r ON idx.id = r.id
            WHERE idx.min_lat <= ? AND idx.max_lat >= ?
              AND idx.min_lon <= ? AND idx.max_lon >= ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, lat + deltaDeg)
        sqlite3_bind_double(statement, 2, lat - deltaDeg)
        sqlite3_bind_double(statement, 3, lon + deltaDeg)
        sqlite3_bind_double(statement, 4, lon - deltaDeg)

        var closestRoad: RoadInfo?
        var minDistance = Double.infinity

        while sqlite3_step(statement) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(statement, 0))
            let speed = Int(sqlite3_column_int(statement, 1))
            let hwType = String(cString: sqlite3_column_text(statement, 2))
            let centerLat = sqlite3_column_double(statement, 3)
            let centerLon = sqlite3_column_double(statement, 4)

            let dLat = lat - centerLat
            let dLon = lon - centerLon
            let distSq = dLat * dLat + dLon * dLon

            if distSq < minDistance {
                minDistance = distSq
                closestRoad = RoadInfo(
                    name: name,
                    speedLimit: speed,
                    highwayType: hwType,
                    centerLat: centerLat,
                    centerLon: centerLon
                )
            }
        }

        return closestRoad
    }

    /// Kiểm tra camera phạt nguội trong phạm vi phía trước (Thread-Safe bằng queue.sync)
    public func findNearbyCamera(lat: Double, lon: Double, radiusMeters: Double = 500.0) -> CameraInfo? {
        return queue.sync {
            guard let db = db else { return nil }

            let deltaDeg = radiusMeters / 111000.0

            let query = """
                SELECT c.id, c.name, c.speed_limit, c.lat, c.lon
                FROM camera_index idx
                JOIN cameras c ON idx.id = c.id
                WHERE idx.min_lat <= ? AND idx.max_lat >= ?
                  AND idx.min_lon <= ? AND idx.max_lon >= ?;
            """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_double(statement, 1, lat + deltaDeg)
            sqlite3_bind_double(statement, 2, lat - deltaDeg)
            sqlite3_bind_double(statement, 3, lon + deltaDeg)
            sqlite3_bind_double(statement, 4, lon - deltaDeg)

            var closestCam: CameraInfo?
            var minDistance = Double.infinity

            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                let name = String(cString: sqlite3_column_text(statement, 1))
                let speed = Int(sqlite3_column_int(statement, 2))
                let cLat = sqlite3_column_double(statement, 3)
                let cLon = sqlite3_column_double(statement, 4)

                let dLat = (lat - cLat) * 111000.0
                let dLon = (lon - cLon) * 111000.0 * cos(lat * .pi / 180.0)
                let distMeters = sqrt(dLat * dLat + dLon * dLon)

                if distMeters <= radiusMeters && distMeters < minDistance {
                    minDistance = distMeters
                    closestCam = CameraInfo(
                        id: id,
                        name: name,
                        speedLimit: speed,
                        lat: cLat,
                        lon: cLon,
                        distance: distMeters
                    )
                }
            }

            return closestCam
        }
    }
}
