# 🚗 VietSpeed - iOS Offline Speed Limit & Camera Alert (Dynamic Island)

**VietSpeed** là ứng dụng iOS chạy hoàn toàn **Offline 100%** giúp tài xế theo dõi tốc độ GPS thực tế, cảnh báo giới hạn tốc độ cung đường và camera phạt nguội — đặc biệt hỗ trợ hiển thị trực tiếp trên **Dynamic Island / Live Activity** chạy ngầm song song với **Google Maps**.

---

## ✨ Tính Năng Nổi Bật

- 🗺️ **Bản Đồ Dẫn Đường 3D Phong Cách Vietmap:**
  - Chế độ bản đồ 3D (`58° pitch`) lái xe bám theo hướng di chuyển (`Follow with Heading`), giao diện Dark Mode chống chói mắt ban đêm.
  - Cụm **Widget tốc độ Vietmap nổi**: Hiển thị song song biển giới hạn tốc độ (vòng tròn viền đỏ), đồng hồ tốc độ điện tử (đổi màu đỏ/vàng khi quá tốc độ), biển phụ (Khu đông dân cư / Cao tốc), và cảnh báo camera phạt nguội đếm ngược khoảng cách.
  - **Dẫn đường lộ trình (Turn-by-Turn Guidance):** Banner chỉ đường hiển thị mũi tên rẽ trực quan, khoảng cách ngã rẽ, tổng quãng đường còn lại và thời gian dự kiến (ETA) kèm thông báo giọng nói tiếng Việt.
  - **Tìm kiếm địa điểm nhanh:** Tích hợp `MKLocalSearch` thông minh tìm kiếm địa chỉ mọi nơi tại Việt Nam, kèm gợi ý nhanh (Sân bay Tân Sơn Nhất, Chợ Bến Thành, Cao tốc Long Thành...).
  - **Chuyển đổi 1 chạm:** Chuyển đổi linh hoạt giữa chế độ **⚡ HUD Tốc độ** (đen OLED tiết kiệm pin) và chế độ **🗺️ Bản đồ Vietmap**.

- 🚗 **100% Offline SQLite Database:**
  - Nhúng sẵn cơ sở dữ liệu hơn **1.430.000 đoạn đường** và camera trên toàn lãnh thổ Việt Nam (trích xuất từ OpenStreetMap).
  - Sử dụng cấu trúc chỉ mục không gian **R*Tree** với tốc độ tra cứu siêu tốc: **0.05ms - 0.2ms**, không tốn 4G/5G, không phụ thuộc vào sóng mạng ở các cung đèo/vùng xa.
  
- 🏝️ **Tích Hợp Dynamic Island & Live Activity:**
  - Chạy ngầm êm ái khi bạn đang mở Google Maps, Apple Maps hay nghe nhạc.
  - Hiển thị viên thuốc Dynamic Island với kim đo tốc độ thực tế và biển báo giới hạn tròn viền đỏ.
  - Căn lề an toàn (`strokeBorder`, padding thông minh) chống cấn hoặc bị lẹm vào cụm camera TrueDepth / Face ID trên **iPhone 14 Pro, iPhone 15 Pro, 16 Pro Max**.
  - Tự động dọn dẹp biến mất ngay khi tắt app, kèm nút gạt **Bật / Tắt Dynamic Island** chủ động.

- 🛑 **Biển Báo Phụ Tiêu Chuẩn:**
  - Tự động nhận diện và hiển thị biển phụ tương ứng: `KHU ĐÔNG DÂN CƯ`, `NGOÀI ĐÔ THỊ`, `ĐƯỜNG CAO TỐC`.
  - Thiết kế tỉ lệ chuẩn Quy chuẩn 41:2019/BGTVT.

- 📷 **Cảnh Báo Camera Phạt Nguội:**
  - Quét camera phía trước trong phạm vi 500m và đếm ngược khoảng cách thời gian thực.

- 🗣️ **Cảnh Báo Giọng Nói Tiếng Việt (Audio Ducking):**
  - Giọng đọc tự nhiên, rõ ràng khi lái xe.
  - Tự động hạ nhỏ âm lượng nhạc/dẫn đường Google Maps khi có thông báo và tự động khôi phục ngay sau khi đọc xong.

- ⚙️ **Tuỳ Chọn Loại Phương Tiện:**
  - Hỗ trợ tuỳ chỉnh: Ô tô con, Xe máy, Xe tải, Xe khách, Xe container.

---

## 🛠️ Công Nghệ Sử Dụng

- **Ngôn ngữ:** Swift 5.0 (SwiftUI + Combine)
- **Hệ điều hành:** iOS 17.0+ (Tối ưu cho Dynamic Island trên iPhone 14 Pro / 15 / 16 Series)
- **Frameworks:**
  - `CoreLocation`: Định vị vệ tinh độ chính xác cao (`automotiveNavigation`, `kCLLocationAccuracyBestForNavigation`).
  - `ActivityKit` & `WidgetKit`: Dynamic Island & Lock Screen Live Activity.
  - `AVFoundation`: Xử lý âm thanh đa kênh và Text-to-Speech tiếng Việt.
  - `SQLite3` (C API): Truy vấn cơ sở dữ liệu không gian cục bộ.
- **Công cụ sinh dự án:** `xcodegen`

---

## 🚀 Hướng Dẫn Cài Đặt & Chạy Dự Án

### 1. Yêu cầu hệ thống
- macOS với **Xcode 15.0+**
- Thiết bị iOS 17.0+ (Khuyến nghị các dòng máy có Dynamic Island)

### 2. Tạo Xcode Project (nếu dùng xcodegen)
```bash
brew install xcodegen
xcodegen generate
```

### 3. Build & Chạy trên iPhone
1. Mở file `VietSpeed.xcodeproj` bằng Xcode.
2. Vào mục **Signing & Capabilities**, chọn Team phát triển của bạn.
3. Cắm iPhone vào máy Mac, chọn thiết bị và bấm **Run (Cmd + R)**.

---

## 📁 Cấu Trúc Thư Mục

```
VietSpeed/
├── VietSpeed/                  # Target Ứng dụng chính (iOS App)
│   ├── App/                    # VietSpeedApp.swift (App Lifecycle)
│   ├── Models/                 # RoadInfo, AppSettings, SpeedWidgetAttributes
│   ├── Views/                  # ContentView (Dashboard), SettingsView
│   ├── Services/               # SpeedTracker (GPS), DatabaseManager, VoiceAlertManager
│   └── Resources/              # roads_vietnam.sqlite, Info.plist, Assets
├── VietSpeedWidget/            # Target Extension Widget (ActivityKit)
│   ├── SpeedLiveActivity.swift # Giao diện Dynamic Island & Màn hình khoá
│   └── VietSpeedWidgetBundle.swift
├── build_roads_db.py           # Script Python sinh CSDL SQLite từ OpenStreetMap (.osm.pbf)
├── project.yml                 # File cấu hình sinh project xcodegen
└── README.md
```

---

## 📄 Bản Quyền & Giấy Phép
Dự án được xây dựng và phát triển cho cộng đồng lái xe tại Việt Nam. Dữ liệu bản đồ được đóng góp từ cộng đồng [OpenStreetMap](https://www.openstreetmap.org/) (ODbL).
