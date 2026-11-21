import SwiftUI

public struct ContentView: View {
    @StateObject private var tracker = SpeedTracker.shared
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack {
            // Nền đen OLED tiết kiệm pin, chớp đỏ cảnh báo khi vượt tốc độ
            Color(tracker.isOverSpeed ? .systemRed : .black)
                .opacity(tracker.isOverSpeed ? 0.9 : 1.0)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.3), value: tracker.isOverSpeed)

            VStack(spacing: 0) {
                // 1. THANH ĐIỀU HƯỚNG TRÊN CÙNG (TOP BAR)
                HStack(spacing: 8) {
                    // Trạng thái Offline
                    HStack(spacing: 5) {
                        Circle()
                            .fill(tracker.isSimulating ? Color.orange : Color.green)
                            .frame(width: 7, height: 7)
                        Text(tracker.isSimulating ? "Demo" : "Offline")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(10)

                    // NÚT TEST DEMO
                    Button(action: {
                        tracker.toggleSpecialDemo()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tracker.isSimulating ? "stop.fill" : "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(tracker.isSimulating ? .yellow : .green)
                            Text(tracker.isSimulating ? "Dừng Test" : "⚡ Test")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(tracker.isSimulating ? Color.orange.opacity(0.3) : Color.blue.opacity(0.3))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(tracker.isSimulating ? Color.orange : Color.blue, lineWidth: 1.2)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    // NÚT BẬT / TẮT DYNAMIC ISLAND TRỰC TIẾP
                    Button(action: {
                        tracker.toggleDynamicIsland()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: tracker.isDynamicIslandActive ? "circle.inset.filled" : "circle")
                                .font(.system(size: 10))
                                .foregroundColor(tracker.isDynamicIslandActive ? .green : .gray)
                            Text(tracker.isDynamicIslandActive ? "🏝️ Island: Bật" : "🏝️ Island: Tắt")
                                .font(.caption2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(tracker.isDynamicIslandActive ? Color.green.opacity(0.25) : Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(tracker.isDynamicIslandActive ? Color.green : Color.gray.opacity(0.4), lineWidth: 1.2)
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }

                    Spacer()

                    // NÚT CÀI ĐẶT
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)

                // 2. TÊN ĐƯỜNG HIỆN TẠI & THÔNG TIN GPS THỰC TẾ
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .foregroundColor(tracker.gpsAccuracy > 0 ? .green : .orange)
                            .font(.subheadline)
                        Text(tracker.roadName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }

                    // Hiển thị độ chính xác GPS thực tế để người dùng yên tâm
                    HStack(spacing: 6) {
                        Circle()
                            .fill(tracker.gpsAccuracy > 0 ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(tracker.gpsStatusText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)

                        if let coord = tracker.lastCoordinate {
                            Text("• \(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.gray.opacity(0.8))
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(16)
                .padding(.top, 12)

                Spacer(minLength: 20)

                // 3. ĐỒNG HỒ TỐC ĐỘ THỰC TẾ (SPEEDOMETER)
                VStack(spacing: -8) {
                    Text("\(tracker.currentSpeed)")
                        .font(.system(size: 115, weight: .black, design: .rounded))
                        .foregroundColor(tracker.isOverSpeed ? .yellow : .white)
                        .shadow(color: tracker.isOverSpeed ? .red : .clear, radius: 25)

                    Text("km/h")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                }

                Spacer(minLength: 24)

                // 4. BIỂN BÁO CHÍNH (Vòng tròn viền đỏ)
                HStack(spacing: 28) {
                    if let limit = tracker.speedLimit {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 130, height: 130)
                                .overlay(
                                    Circle().stroke(Color.red, lineWidth: 16)
                                )
                                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)

                            Text("\(limit)")
                                .font(.system(size: 54, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .stroke(Color.gray.opacity(0.4), lineWidth: 4)
                                .frame(width: 110, height: 110)
                            Text("--")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }

                    // Thẻ camera phạt nguội
                    if let cam = tracker.activeCamera {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.orange)
                                .frame(width: 110, height: 110)
                                .shadow(color: .orange.opacity(0.5), radius: 8)

                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.title)
                                    .foregroundColor(.white)
                                Text("\(Int(cam.distance))m")
                                    .font(.headline)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.white)
                                Text("PHẠT NGUỘI")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }

                // SPACER 1: Canh giữa Biển chính -> Biển phụ
                Spacer(minLength: 16)

                // 5. BIỂN PHỤ
                if let road = tracker.currentRoad {
                    HStack(spacing: 12) {
                        Image(systemName: road.subSignIcon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                        Text(road.subSignTitle)
                            .font(.system(size: 13, weight: .heavy))
                            .tracking(2.0)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 3)
                }

                // SPACER 2: Canh giữa Biển phụ -> Footer
                Spacer(minLength: 16)

                // 6. FOOTER THÔNG BÁO DƯỚI CÙNG
                HStack(spacing: 6) {
                    Circle()
                        .fill(tracker.isSimulating ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(tracker.isSimulating ? "Đang chạy Test Demo • Bấm 'Dừng Test' để quay lại GPS thật" : "Đang chạy ngầm Offline • Tương thích Google Maps")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            // Khi mở app: bật GPS thật ngay lập tức
            tracker.setupLocationManager()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
