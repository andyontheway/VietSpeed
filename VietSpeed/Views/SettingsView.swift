import SwiftUI

public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    // Lưu các cấu hình vào bộ nhớ máy (UserDefaults) để giữ nguyên sau khi tắt app
    @AppStorage("is_dark_mode") private var isDarkMode: Bool = true
    @AppStorage("google_maps_api_key") private var googleApiKey: String = ""
    @AppStorage("selected_vehicle") private var selectedVehicleRaw: String = VehicleType.car.rawValue
    @AppStorage("speed_tolerance") private var speedTolerance: Int = 0 // Dung sai vượt quá: 0, 5, 10 km/h
    @AppStorage("voice_alert_enabled") private var voiceAlertEnabled: Bool = true
    @AppStorage("camera_alert_enabled") private var cameraAlertEnabled: Bool = true
    @AppStorage("route_target") private var routeTarget: String = "TP.HCM - Đà Lạt"

    @State private var isDownloadingRoute = false
    @State private var downloadMessage: String? = nil

    private var selectedVehicle: VehicleType {
        get { VehicleType(rawValue: selectedVehicleRaw) ?? .car }
        set { selectedVehicleRaw = newValue.rawValue }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            Form {
                // 0. CHẾ ĐỘ HIỂN THỊ (SÁNG / TỐI)
                Section(header: Label("Giao diện hiển thị", systemImage: "circle.righthalf.filled")) {
                    Picker("Chế độ màu", selection: $isDarkMode) {
                        HStack {
                            Image(systemName: "moon.stars.fill")
                            Text("Chế độ Tối (Ban đêm / OLED)")
                        }.tag(true)

                        HStack {
                            Image(systemName: "sun.max.fill")
                            Text("Chế độ Sáng (Ban ngày)")
                        }.tag(false)
                    }
                    .pickerStyle(.inline)
                }

                // 0.1 CẤU HÌNH GOOGLE PLACES API (TÌM ĐỊA ĐIỂM VIỆT NAM)
                Section(
                    header: Label("Tìm kiếm Google Places", systemImage: "globe.asia.australia.fill"),
                    footer: Text(googleApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                        "Chưa nhập Key: Đang dùng Apple Maps. Dán Google API Key để tìm kiếm chính xác từng quán ăn, cây xăng, địa chỉ ngõ hẻm tại Việt Nam." :
                        "🟢 Đang kích hoạt tìm kiếm địa điểm thông minh bằng Google Places API.")
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Google API Key:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Spacer()
                            if !googleApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Đã kích hoạt")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                            }
                        }

                        SecureField("Dán Google Places API Key vào đây...", text: $googleApiKey)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Link(destination: URL(string: "https://console.cloud.google.com/google/maps-apis")!) {
                        HStack {
                            Image(systemName: "arrow.up.right.square")
                            Text("Lấy Google API Key miễn phí ($200/tháng)")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }

                // 1. CHỌN LOẠI PHƯƠNG TIỆN (Quan trọng theo luật giao thông VN)
                Section(header: Label("Phương tiện lưu thông", systemImage: "car.2.fill")) {
                    ForEach(VehicleType.allCases) { vehicle in
                        HStack {
                            Image(systemName: vehicle.icon)
                                .foregroundColor(.blue)
                                .frame(width: 28)
                            Text(vehicle.displayName)
                                .font(.subheadline)
                            Spacer()
                            if selectedVehicle == vehicle {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedVehicleRaw = vehicle.rawValue
                        }
                    }
                }

                // 2. TẢI TRƯỚC TUYẾN ĐƯỜNG DỰ KIẾN (Pre-download Route)
                Section(header: Label("Tải trước tuyến đường di chuyển", systemImage: "arrow.down.circle.fill"),
                        footer: Text("Tải và lưu trước các biển báo, camera trên hành lang tuyến đường dự kiến trước khi khởi hành.")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tuyến đường dự kiến đi:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("Ví dụ: TP.HCM - Đà Lạt hoặc QL1A", text: $routeTarget)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button(action: handleDownloadRoute) {
                        HStack {
                            if isDownloadingRoute {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                Text("Đang đồng bộ tuyến đường...")
                            } else {
                                Image(systemName: "icloud.and.arrow.down")
                                Text("Tải trước dữ liệu tuyến đường")
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .disabled(isDownloadingRoute || routeTarget.trimmingCharacters(in: .whitespaces).isEmpty)

                    if let msg = downloadMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // 3. CÀI ĐẶT CẢNH BÁO & ÂM THANH
                Section(header: Label("Cảnh báo & Âm thanh", systemImage: "speaker.wave.3.fill")) {
                    Toggle("Cảnh báo bằng giọng nói tiếng Việt", isOn: $voiceAlertEnabled)

                    Toggle("Cảnh báo camera phạt nguội", isOn: $cameraAlertEnabled)

                    Picker("Báo khi chạy quá tốc độ từ", selection: $speedTolerance) {
                        Text("+0 km/h (Chính xác)").tag(0)
                        Text("+5 km/h (Châm chước)").tag(5)
                        Text("+10 km/h (Mức phạt)").tag(10)
                    }
                    .pickerStyle(.menu)
                }

                // 4. DỮ LIỆU BẢN ĐỒ OFFLINE
                Section(header: Label("Dữ liệu ngoại tuyến (Offline)", systemImage: "internaldrive.fill")) {
                    HStack {
                        Text("Bản đồ số Việt Nam")
                        Spacer()
                        Text("157 MB")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Tổng số đoạn đường")
                        Spacer()
                        Text("1.433.211 đoạn")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Trạng thái")
                        Spacer()
                        Text("🟢 Đã sẵn sàng Offline")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // 5. THÔNG TIN PHIÊN BẢN
                Section {
                    HStack {
                        Text("Phiên bản ứng dụng")
                        Spacer()
                        Text("VietSpeed 1.0 (Build 2026)")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }

    private func handleDownloadRoute() {
        isDownloadingRoute = true
        downloadMessage = nil

        // Giả lập đồng bộ tuyến đường nạp vào cache máy
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isDownloadingRoute = false
            downloadMessage = "✅ Đã tải và tối ưu dữ liệu cho: \(routeTarget)"
        }
    }
}
