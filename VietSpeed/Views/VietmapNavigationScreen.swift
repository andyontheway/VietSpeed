import SwiftUI
import MapKit
import CoreLocation

public struct VietmapNavigationScreen: View {
    @ObservedObject var tracker: SpeedTracker
    @ObservedObject var navManager = NavigationManager.shared
    @Binding var isDarkMode: Bool

    @State private var is3DMode: Bool = true
    @State private var recenterTrigger: Int = 0
    @State private var searchQuery: String = ""

    public init(tracker: SpeedTracker, isDarkMode: Binding<Bool>) {
        self.tracker = tracker
        self._isDarkMode = isDarkMode
    }

    // Các điểm đến gợi ý nhanh
    private let quickDestinations = [
        ("Sân bay Tân Sơn Nhất", "Sân bay Tân Sơn Nhất, TP.HCM"),
        ("Chợ Bến Thành", "Chợ Bến Thành, Quận 1"),
        ("Cao tốc Long Thành", "Nút giao An Phú, Cao tốc TP.HCM - Long Thành"),
        ("TP. Vũng Tàu", "Thành phố Vũng Tàu, Bà Rịa - Vũng Tàu")
    ]

    public var body: some View {
        ZStack {
            // 1. LỚP BẢN ĐỒ 3D TOÀN MÀN HÌNH (DAY / NIGHT ENGINE)
            VietmapMapView(
                tracker: tracker,
                navManager: navManager,
                is3DMode: is3DMode,
                isDarkMode: isDarkMode,
                recenterTrigger: recenterTrigger
            )
            .ignoresSafeArea()

            // 2. CÁC LỚP WIDGET ĐIỀU HƯỚNG NỔI TRÊN BẢN ĐỒ
            VStack(spacing: 0) {
                // TOP BAR: DẪN ĐƯỜNG HOẶC TÌM KIẾM
                topHeaderSection
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                // DANH SÁCH GỢI Ý TÌM KIẾM (KHI ĐANG GÕ)
                if !navManager.searchResults.isEmpty && !navManager.isNavigating {
                    searchResultsDropdown
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }

                Spacer()

                // PHẦN ĐÁY: WIDGET TỐC ĐỘ VIETMAP (TRÁI) & CÁC NÚT ĐIỀU KHIỂN BẢN ĐỒ (PHẢI)
                bottomControlsSection
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            }
        }
    }

    // MARK: - TOP HEADER SECTION (BANNER DẪN ĐƯỜNG HOẶC THANH TÌM KIẾM)
    @ViewBuilder
    private var topHeaderSection: some View {
        if navManager.isNavigating {
            // BANNER CHỈ DẪN LỘ TRÌNH (TURN-BY-TURN CARD) - CHUẨN TƯƠNG PHẢN CAO
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    // Biểu tượng rẽ hướng tiếp theo
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(
                                colors: [Color(red: 0.05, green: 0.52, blue: 0.98), Color(red: 0.02, green: 0.38, blue: 0.88)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 54, height: 54)
                            .shadow(color: Color.blue.opacity(0.35), radius: 6, y: 3)

                        Image(systemName: navManager.nextStepIcon)
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(.white)
                    }

                    // Khoảng cách tới ngã rẽ và tên đường tiếp theo
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if !navManager.nextStepDistance.isEmpty {
                                Text(navManager.nextStepDistance)
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(isDarkMode ? .white : Color(red: 0.05, green: 0.08, blue: 0.12))
                            }
                            Text(navManager.nextInstruction)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(isDarkMode ? .white : Color(red: 0.05, green: 0.08, blue: 0.12))
                                .lineLimit(1)
                        }

                        // Quãng đường còn lại & Thời gian dự kiến (ETA)
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .font(.system(size: 11, weight: .bold))
                                Text(navManager.remainingDistance)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.75) : Color(red: 0.35, green: 0.38, blue: 0.42))

                            Text("•")
                                .foregroundColor(isDarkMode ? Color.gray.opacity(0.6) : Color.gray.opacity(0.4))

                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 11))
                                Text(navManager.remainingTime)
                                    .font(.system(size: 12, weight: .black))
                            }
                            .foregroundColor(isDarkMode ? Color.green : Color(red: 0.0, green: 0.55, blue: 0.22))
                        }
                    }

                    Spacer()

                    VStack(spacing: 6) {
                        // Nút huỷ lộ trình dẫn đường
                        Button(action: {
                            navManager.stopNavigation()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(isDarkMode ? Color.white.opacity(0.65) : Color.black.opacity(0.45))
                        }

                        // Nút mở sang Google Maps chính thức nếu muốn
                        if let destCoord = navManager.destinationCoordinate {
                            Button(action: {
                                NavigationManager.openInGoogleMapsApp(destinationCoord: destCoord, destinationName: navManager.destinationTitle)
                            }) {
                                Image(systemName: "arrow.up.right.square.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(isDarkMode ? .cyan : .blue)
                            }
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.15).opacity(0.96) : Color.white.opacity(0.97))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isDarkMode ? Color.cyan.opacity(0.4) : Color.black.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: isDarkMode ? Color.black.opacity(0.6) : Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                )
            }
        } else {
            // THANH TÌM KIẾM ĐỊA ĐIỂM + CHIP GỢI Ý
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isDarkMode ? .cyan : .blue)
                        .font(.system(size: 16, weight: .bold))

                    TextField(navManager.activeSearchEngine == "Google" ? "Tìm bằng Google Places (Quán ăn, ngõ hẻm...)" : "Tìm điểm đến...", text: $searchQuery)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .font(.subheadline)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchQuery) { query in
                            let loc = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
                            navManager.searchPlaces(query: query, userLocation: loc)
                        }

                    if navManager.activeSearchEngine == "Google" {
                        Text("Google")
                            .font(.system(size: 8, weight: .black))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }

                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            navManager.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(isDarkMode ? .gray : Color.black.opacity(0.4))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.15).opacity(0.92) : Color.white.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isDarkMode ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.12), radius: 8, y: 3)
                )

                // GỢI Ý ĐIỂM ĐẾN PHỔ BIẾN
                if searchQuery.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickDestinations, id: \.0) { item in
                                Button(action: {
                                    searchQuery = item.0
                                    let loc = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
                                    navManager.searchPlaces(query: item.1, userLocation: loc)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.and.ellipse")
                                            .font(.caption2)
                                        Text(item.0)
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(isDarkMode ? Color.black.opacity(0.75) : Color.white.opacity(0.92))
                                    .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.12, blue: 0.15))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isDarkMode ? Color.cyan.opacity(0.4) : Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.1), radius: 4, y: 2)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - DROPDOWN KẾT QUẢ TÌM KIẾM
    private var searchResultsDropdown: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(navManager.searchResults.prefix(5), id: \.self) { item in
                        Button(action: {
                            startNavigatingTo(item: item)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: item.isGooglePlace ? "mappin.and.ellipse" : "car.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(item.isGooglePlace ? .red : (isDarkMode ? .cyan : .blue))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(isDarkMode ? .white : .black)
                                            .lineLimit(1)

                                        if item.isGooglePlace {
                                            Text("Google")
                                                .font(.system(size: 8, weight: .heavy))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.blue)
                                                .cornerRadius(3)
                                        }
                                    }

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(isDarkMode ? .gray : Color(red: 0.4, green: 0.42, blue: 0.45))
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text("Chỉ đường")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 6)
                                    .background(isDarkMode ? Color.cyan : Color.blue)
                                    .foregroundColor(isDarkMode ? .black : .white)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                        }
                        Divider().background(isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.08))
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.15).opacity(0.96) : Color.white.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isDarkMode ? Color.cyan.opacity(0.5) : Color.blue.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: isDarkMode ? Color.black.opacity(0.6) : Color.black.opacity(0.18), radius: 12, y: 4)
        )
    }

    // MARK: - BOTTOM CONTROLS SECTION (WIDGET TỐC ĐỘ + NÚT BẢN ĐỒ)
    private var bottomControlsSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // CỤM WIDGET TỐC ĐỘ PHONG CÁCH VIETMAP
            VStack(alignment: .leading, spacing: 8) {
                // TÊN ĐƯỜNG HIỆN TẠI
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(tracker.gpsAccuracy > 0 ? .green : .orange)
                    Text(tracker.roadName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.08, green: 0.1, blue: 0.12))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                .cornerRadius(9)
                .overlay(
                    RoundedRectangle(cornerRadius: 9)
                        .stroke(isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.12), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)

                // HÀNG BIỂN BÁO & ĐỒNG HỒ TỐC ĐỘ
                HStack(spacing: 10) {
                    // 1. BIỂN BÁO GIỚI HẠN TỐC ĐỘ (Vòng tròn viền đỏ chuẩn)
                    if let limit = tracker.speedLimit {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Circle().stroke(Color.red, lineWidth: 8)
                                )
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)

                            Text("\(limit)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(isDarkMode ? Color.black.opacity(0.7) : Color.white.opacity(0.9))
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Circle().stroke(Color.gray.opacity(0.5), lineWidth: 3)
                                )
                            Text("--")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                        }
                    }

                    // 2. ĐỒNG HỒ ĐO TỐC ĐỘ THỰC TẾ
                    VStack(spacing: -2) {
                        Text("\(tracker.currentSpeed)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundColor(tracker.isOverSpeed ? .red : (isDarkMode ? .white : Color(red: 0.05, green: 0.08, blue: 0.12)))
                            .shadow(color: tracker.isOverSpeed ? .red.opacity(0.5) : .clear, radius: 8)

                        Text("km/h")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.gray)
                    }
                    .frame(minWidth: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tracker.isOverSpeed ? Color.red : (isDarkMode ? Color.white.opacity(0.2) : Color.black.opacity(0.12)), lineWidth: tracker.isOverSpeed ? 2 : 1)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 5, y: 2)
                }

                // 3. BIỂN PHỤ (KHU DÂN CƯ / CAO TỐC)
                if let road = tracker.currentRoad {
                    HStack(spacing: 6) {
                        Image(systemName: road.subSignIcon)
                            .font(.caption2)
                            .foregroundColor(.black)
                        Text(road.subSignTitle)
                            .font(.system(size: 10, weight: .black))
                            .tracking(1.0)
                            .foregroundColor(.black)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.2), radius: 4, y: 2)
                }

                // 4. CẢNH BÁO CAMERA PHẠT NGUỘI
                if let cam = tracker.activeCamera {
                    HStack(spacing: 6) {
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                        Text("📷 Phạt nguội \(Int(cam.distance))m")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .cornerRadius(8)
                    .shadow(color: .orange.opacity(0.5), radius: 6)
                }
            }

            Spacer()

            // CỤM NÚT ĐIỀU KHIỂN BẢN ĐỒ BÊN PHẢI (2D/3D + SÁNG/TỐI + ĐỊNH TÂM)
            VStack(spacing: 10) {
                // Nút chuyển chế độ Sáng ☀️ / Tối 🌙 trực tiếp trên bản đồ
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isDarkMode.toggle()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isDarkMode ? Color.yellow.opacity(0.6) : Color.orange.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)

                        Image(systemName: isDarkMode ? "moon.stars.fill" : "sun.max.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isDarkMode ? .yellow : .orange)
                    }
                }

                // Nút chuyển 2D / 3D
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        is3DMode.toggle()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isDarkMode ? Color.cyan.opacity(0.6) : Color.blue.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)

                        Text(is3DMode ? "3D" : "2D")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(isDarkMode ? .cyan : .blue)
                    }
                }

                // Nút Định tâm lại xe (Recenter & Follow Heading)
                Button(action: {
                    recenterTrigger += 1
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(isDarkMode ? Color.white.opacity(0.3) : Color.black.opacity(0.15), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)

                        Image(systemName: "location.north.line.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.12, blue: 0.15))
                    }
                }
            }
        }
    }

    // MARK: - KHỞI TẠO LỘ TRÌNH DẪN ĐƯỜNG
    private func startNavigatingTo(item: PlaceSearchResult) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let startCoord = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
        navManager.navigateTo(item: item, startCoord: startCoord) { success in
            if success {
                searchQuery = ""
                recenterTrigger += 1
            }
        }
    }
}
