import SwiftUI

public enum AppViewMode: String, CaseIterable {
    case hud = "HUD"
    case map = "Bản đồ"
    
    var icon: String {
        switch self {
        case .hud: return "speedometer"
        case .map: return "map.fill"
        }
    }
}

public struct ContentView: View {
    @StateObject private var tracker = SpeedTracker.shared
    @AppStorage("is_dark_mode") private var isDarkMode: Bool = true
    @State private var showSettings = false
    @State private var selectedMode: AppViewMode = .hud
    @Environment(\.scenePhase) private var scenePhase

    public init() {}

    public var body: some View {
        ZStack {
            // NỀN CỦA GIAO DIỆN THEO CHẾ ĐỘ SÁNG / TỐI
            if selectedMode == .hud {
                if isDarkMode {
                    Color(tracker.isOverSpeed ? .systemRed : .black)
                        .opacity(tracker.isOverSpeed ? 0.9 : 1.0)
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.3), value: tracker.isOverSpeed)
                } else {
                    Color(tracker.isOverSpeed ? Color(red: 1.0, green: 0.9, blue: 0.9) : Color(red: 0.94, green: 0.95, blue: 0.97))
                        .ignoresSafeArea()
                        .animation(.easeInOut(duration: 0.3), value: tracker.isOverSpeed)
                }
            } else {
                (isDarkMode ? Color.black : Color(red: 0.95, green: 0.96, blue: 0.98))
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                // 1. THANH ĐIỀU HƯỚNG TRÊN CÙNG DÙNG CHUNG (GLOBAL TOP BAR)
                HStack(spacing: 6) {
                    // Trạng thái Offline / Demo
                    HStack(spacing: 4) {
                        Circle()
                            .fill(tracker.isSimulating ? Color.orange : Color.green)
                            .frame(width: 6, height: 6)
                        Text(tracker.isSimulating ? "Demo" : "Offline")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.12, blue: 0.15))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .background(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                    .cornerRadius(8)

                    // BỘ CHUYỂN ĐỔI CHẾ ĐỘ: HUD TỐC ĐỘ <-> BẢN ĐỒ VIETMAP
                    HStack(spacing: 2) {
                        ForEach(AppViewMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    selectedMode = mode
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 9, weight: .bold))
                                    Text(mode.rawValue)
                                        .font(.system(size: 11, weight: .heavy))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(selectedMode == mode ? (isDarkMode ? Color.cyan : Color.blue) : Color.clear)
                                .foregroundColor(selectedMode == mode ? (isDarkMode ? .black : .white) : (isDarkMode ? .white.opacity(0.8) : Color.black.opacity(0.65)))
                                .cornerRadius(7)
                            }
                        }
                    }
                    .padding(2)
                    .background(isDarkMode ? Color.black.opacity(0.6) : Color.black.opacity(0.06))
                    .cornerRadius(9)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(isDarkMode ? Color.white.opacity(0.18) : Color.black.opacity(0.1), lineWidth: 1)
                    )

                    Spacer()

                    // NÚT CHUYỂN SÁNG / TỐI NHANH TRÊN HEADER
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isDarkMode.toggle()
                        }
                    }) {
                        Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isDarkMode ? .yellow : .orange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 6)
                            .background(isDarkMode ? Color.yellow.opacity(0.2) : Color.orange.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(isDarkMode ? Color.yellow.opacity(0.5) : Color.orange.opacity(0.4), lineWidth: 1)
                            )
                            .cornerRadius(8)
                    }

                    // NÚT TEST DEMO
                    Button(action: {
                        tracker.toggleSpecialDemo()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: tracker.isSimulating ? "stop.fill" : "play.fill")
                                .font(.system(size: 9))
                                .foregroundColor(tracker.isSimulating ? .yellow : (isDarkMode ? .green : .blue))
                            Text(tracker.isSimulating ? "Dừng" : "Test")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 6)
                        .background(tracker.isSimulating ? Color.orange.opacity(0.3) : (isDarkMode ? Color.blue.opacity(0.3) : Color.blue.opacity(0.12)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(tracker.isSimulating ? Color.orange : Color.blue, lineWidth: 1)
                        )
                        .foregroundColor(isDarkMode ? .white : Color.blue)
                        .cornerRadius(8)
                    }

                    // NÚT BẬT / TẮT DYNAMIC ISLAND TRỰC TIẾP
                    Button(action: {
                        tracker.toggleDynamicIsland()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: tracker.isDynamicIslandActive ? "circle.inset.filled" : "circle")
                                .font(.system(size: 9))
                                .foregroundColor(tracker.isDynamicIslandActive ? .green : .gray)
                            Text("Island")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 6)
                        .background(tracker.isDynamicIslandActive ? Color.green.opacity(0.25) : (isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.05)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(tracker.isDynamicIslandActive ? Color.green : Color.gray.opacity(0.4), lineWidth: 1)
                        )
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.12, blue: 0.15))
                        .cornerRadius(8)
                    }

                    // NÚT CÀI ĐẶT
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.12, blue: 0.15))
                            .padding(6)
                            .background(isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 6)

                // 2. NỘI DUNG CHÍNH THEO CHẾ ĐỘ ĐANG CHỌN
                if selectedMode == .hud {
                    hudSpeedView
                } else {
                    VietmapNavigationScreen(tracker: tracker, isDarkMode: $isDarkMode)
                }
            }
        }
        .onAppear {
            // Khi mở app: khởi động GPS thật ngay lập tức
            tracker.setupLocationManager()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - GIAO DIỆN CHUYÊN DỤNG HUD TỐC ĐỘ (DAY / NIGHT ADAPTIVE)
    private var hudSpeedView: some View {
        VStack(spacing: 0) {
            // TÊN ĐƯỜNG HIỆN TẠI & THÔNG TIN GPS THỰC TẾ
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(tracker.gpsAccuracy > 0 ? .green : .orange)
                        .font(.subheadline)
                    Text(tracker.roadName)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.05, green: 0.08, blue: 0.12))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                // Hiển thị độ chính xác GPS thực tế
                HStack(spacing: 6) {
                    Circle()
                        .fill(tracker.gpsAccuracy > 0 ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                    Text(tracker.gpsStatusText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(isDarkMode ? .gray : Color.black.opacity(0.55))

                    if let coord = tracker.lastCoordinate {
                        Text("• \(String(format: "%.4f, %.4f", coord.latitude, coord.longitude))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(isDarkMode ? Color.gray.opacity(0.8) : Color.black.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(isDarkMode ? Color.white.opacity(0.08) : Color.white)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isDarkMode ? 0.3 : 0.06), radius: 6, y: 3)
            .padding(.top, 12)

            Spacer(minLength: 20)

            // ĐỒNG HỒ TỐC ĐỘ THỰC TẾ (SPEEDOMETER)
            VStack(spacing: -8) {
                Text("\(tracker.currentSpeed)")
                    .font(.system(size: 115, weight: .black, design: .rounded))
                    .foregroundColor(tracker.isOverSpeed ? (isDarkMode ? .yellow : .red) : (isDarkMode ? .white : Color(red: 0.05, green: 0.08, blue: 0.12)))
                    .shadow(color: tracker.isOverSpeed ? .red : .clear, radius: 25)

                Text("km/h")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .gray : Color.black.opacity(0.5))
            }

            Spacer(minLength: 24)

            // BIỂN BÁO CHÍNH (Vòng tròn viền đỏ chuẩn VN) & CAMERA
            HStack(spacing: 28) {
                if let limit = tracker.speedLimit {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 130, height: 130)
                            .overlay(
                                Circle().stroke(Color.red, lineWidth: 16)
                            )
                            .shadow(color: .black.opacity(isDarkMode ? 0.5 : 0.2), radius: 10, x: 0, y: 5)

                        Text("\(limit)")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                    }
                } else {
                    ZStack {
                        Circle()
                            .stroke(isDarkMode ? Color.gray.opacity(0.4) : Color.black.opacity(0.2), lineWidth: 4)
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

            Spacer(minLength: 16)

            // BIỂN PHỤ
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

            Spacer(minLength: 16)

            // FOOTER THÔNG BÁO DƯỚI CÙNG
            HStack(spacing: 6) {
                Circle()
                    .fill(tracker.isSimulating ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(tracker.isSimulating ? "Đang chạy Test Demo • Bấm 'Dừng' để quay lại GPS thật" : "Đang chạy ngầm Offline • Tương thích Google Maps")
                    .font(.caption2)
                    .foregroundColor(isDarkMode ? .white.opacity(0.7) : Color.black.opacity(0.6))
            }
            .padding(.bottom, 20)
        }
    }
}
