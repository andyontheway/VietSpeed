import SwiftUI
import MapKit

public struct VietmapMapView: UIViewRepresentable {
    @ObservedObject var tracker: SpeedTracker
    @ObservedObject var navManager: NavigationManager
    var is3DMode: Bool
    var recenterTrigger: Int

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsTraffic = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.overrideUserInterfaceStyle = .dark // Bản đồ đêm sang trọng chống chói

        // Thiết lập góc nhìn 3D lái xe ban đầu
        if let userLoc = mapView.userLocation.location ?? tracker.lastLocationObject {
            let camera = MKMapCamera(
                lookingAtCenter: userLoc.coordinate,
                fromDistance: 600,
                pitch: is3DMode ? 58 : 0,
                heading: userLoc.course >= 0 ? userLoc.course : 0
            )
            mapView.setCamera(camera, animated: false)
        }

        context.coordinator.mapView = mapView
        return mapView
    }

    public func updateUIView(_ uiView: MKMapView, context: Context) {
        context.coordinator.parent = self

        // 1. Cập nhật góc nhìn 3D / 2D
        if context.coordinator.lastIs3D != is3DMode {
            context.coordinator.lastIs3D = is3DMode
            var camera = uiView.camera
            camera.pitch = is3DMode ? 58 : 0
            uiView.setCamera(camera, animated: true)
        }

        // 2. Kích hoạt nút định tâm (Recenter)
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            if let userLoc = tracker.lastLocationObject ?? uiView.userLocation.location {
                let camera = MKMapCamera(
                    lookingAtCenter: userLoc.coordinate,
                    fromDistance: 550,
                    pitch: is3DMode ? 58 : 0,
                    heading: userLoc.course >= 0 ? userLoc.course : uiView.camera.heading
                )
                uiView.setCamera(camera, animated: true)
            }
        }

        // 3. Cập nhật tuyến đường vẽ trên bản đồ (Route Polyline)
        if let activeRoute = navManager.activeRoute {
            if context.coordinator.renderedRoute != activeRoute {
                context.coordinator.renderedRoute = activeRoute
                uiView.removeOverlays(uiView.overlays)
                uiView.addOverlay(activeRoute.polyline, level: .aboveRoads)

                // Căn khung nhìn bao trọn tuyến đường lúc mới bấm
                if !context.coordinator.hasZoomedToRoute {
                    context.coordinator.hasZoomedToRoute = true
                    let rect = activeRoute.polyline.boundingMapRect
                    uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 120, left: 40, bottom: 200, right: 40), animated: true)
                }
            }
        } else {
            if context.coordinator.renderedRoute != nil {
                context.coordinator.renderedRoute = nil
                context.coordinator.hasZoomedToRoute = false
                uiView.removeOverlays(uiView.overlays)
            }
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public class Coordinator: NSObject, MKMapViewDelegate {
        var parent: VietmapMapView
        weak var mapView: MKMapView?
        var lastIs3D: Bool = true
        var lastRecenterTrigger: Int = 0
        var renderedRoute: MKRoute? = nil
        var hasZoomedToRoute: Bool = false
        private var lastCameraUpdateTime: Date = Date.distantPast

        init(_ parent: VietmapMapView) {
            self.parent = parent
        }

        // Tuỳ biến đường vẽ tuyến đường (Polyline) phong cách Neon hiện đại
        public func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor(red: 0.0, green: 0.65, blue: 1.0, alpha: 0.95) // Neon Blue/Cyan
                renderer.lineWidth = 8.0
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Khi vị trí xe thay đổi: bám mượt mà khi di chuyển
        public func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
            guard let loc = userLocation.location else { return }
            let now = Date()
            guard now.timeIntervalSince(lastCameraUpdateTime) >= 1.0 else { return }
            lastCameraUpdateTime = now

            if loc.speed > 0.8 && loc.course >= 0 {
                let camera = MKMapCamera(
                    lookingAtCenter: loc.coordinate,
                    fromDistance: 550,
                    pitch: parent.is3DMode ? 58 : 0,
                    heading: loc.course
                )
                mapView.setCamera(camera, animated: true)
            }
        }
    }
}
