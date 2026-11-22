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
    @State private var clipboardContent: String? = nil
    @State private var showClipboardBanner: Bool = false
    @State private var showCoordinateModal: Bool = false

    public init(tracker: SpeedTracker, isDarkMode: Binding<Bool>) {
        self.tracker = tracker
        self._isDarkMode = isDarkMode
    }

    // Các điểm đến gợi ý nhanh
    private let quickDestinations = [
        ("Sân bay Tân Sơn Nhất", "10.8184, 106.6588"),
        ("Chợ Bến Thành", "10.7725, 106.6980"),
        ("Cao tốc Long Thành", "10.7937, 106.7570"),
        ("TP. Vũng Tàu", "10.3460, 107.0843")
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

                // THÔNG BÁO TỰ ĐỘNG PHÁT HIỆN TOẠ ĐỘ TRONG BỘ NHỚ TẠM (CLIPBOARD)
                if showClipboardBanner && !navManager.isNavigating, let clip = clipboardContent {
                    clipboardDetectedCard(clip: clip)
                        .padding(.horizontal, 14)
                        .padding(.top, 6)
                }

                // TIẾN TRÌNH ĐANG PHÂN TÍCH TOẠ ĐỘ
                if navManager.isResolvingLink {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isDarkMode ? .cyan : .blue))
                            .scaleEffect(0.8)
                        Text(navManager.resolvingStatusText ?? "Đang phân tích toạ độ GPS...")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(isDarkMode ? .white : Color(red: 0.1, green: 0.12, blue: 0.15))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isDarkMode ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                    .cornerRadius(10)
                    .padding(.top, 6)
                }

                // DANH SÁCH GỢI Ý TÌM KIẾM (KHI ĐANG GÕ TOẠ ĐỘ HOẶC TÊN ĐỊA ĐIỂM)
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
        .onAppear {
            checkClipboard()
        }
        .sheet(isPresented: $showCoordinateModal) {
            CoordinateInputSheet(
                tracker: tracker,
                navManager: navManager,
                isDarkMode: isDarkMode,
                isPresented: $showCoordinateModal
            )
        }
    }

    // MARK: - TOP HEADER SECTION (BANNER DẪN ĐƯỜNG HOẶC THANH TÌM KIẾM TOẠ ĐỘ)
    @ViewBuilder
    private var topHeaderSection: some View {
        if navManager.isNavigating {
            // BANNER CHỈ DẪN LỘ TRÌNH (TURN-BY-TURN CARD) - CHUẨN TƯƠNG PHẢN CAO KHÔNG BỊ TRẮNG MỜ
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

                    // Khoảng cách tới ngã rẽ và tên đường tiếp theo (Chữ đen rõ ràng trên nền sáng / Chữ trắng trên nền tối)
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
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.85) : Color(red: 0.25, green: 0.28, blue: 0.32))

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
                                .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.55))
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
                        .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.15).opacity(0.96) : Color.white.opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(isDarkMode ? Color.cyan.opacity(0.4) : Color.black.opacity(0.12), lineWidth: 1.5)
                        )
                        .shadow(color: isDarkMode ? Color.black.opacity(0.6) : Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
                )
            }
        } else {
            // THANH TÌM KIẾM ĐỊA ĐIỂM + NÚT NHẬP TOẠ ĐỘ GPS
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(isDarkMode ? .cyan : .blue)
                        .font(.system(size: 16, weight: .bold))

                    TextField("Nhập toạ độ (vd: 10.7769, 106.7009)...", text: $searchQuery)
                        .foregroundColor(isDarkMode ? .white : Color(red: 0.08, green: 0.1, blue: 0.12))
                        .font(.subheadline)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchQuery) { query in
                            let loc = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
                            navManager.searchPlaces(query: query, userLocation: loc)
                        }
                        .onSubmit {
                            handleDirectCoordinateSubmit(searchQuery)
                        }

                    // NÚT MỞ BẢNG NHẬP TOẠ ĐỘ CHUYÊN DỤNG
                    Button(action: {
                        showCoordinateModal = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Toạ độ")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(isDarkMode ? Color.cyan.opacity(0.2) : Color.blue.opacity(0.12))
                        .foregroundColor(isDarkMode ? .cyan : .blue)
                        .cornerRadius(8)
                    }

                    // NÚT DÁN NHANH TỪ BỘ NHỚ TẠM
                    Button(action: {
                        if let clip = UIPasteboard.general.string, !clip.isEmpty {
                            searchQuery = clip
                            handleCoordinateInputAndNavigate(clip)
                        }
                    }) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 14))
                            .padding(6)
                            .background(isDarkMode ? Color.white.opacity(0.12) : Color.black.opacity(0.06))
                            .foregroundColor(isDarkMode ? .white : Color.black.opacity(0.7))
                            .cornerRadius(8)
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
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDarkMode ? Color(red: 0.09, green: 0.11, blue: 0.15).opacity(0.92) : Color.white.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(isDarkMode ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: isDarkMode ? Color.black.opacity(0.5) : Color.black.opacity(0.12), radius: 8, y: 3)
                )

                // GỢI Ý ĐIỂM ĐẾN PHỔ BIẾN BẰNG TOẠ ĐỘ
                if searchQuery.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickDestinations, id: \.0) { item in
                                Button(action: {
                                    handleCoordinateInputAndNavigate(item.1)
                                }) {
                                    HStack(spacing: 5) {
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

    // MARK: - BANNER PHÁT HIỆN TOẠ ĐỘ TỰ ĐỘNG TỪ BỘ NHỚ TẠM (CLIPBOARD)
    @ViewBuilder
    private func clipboardDetectedCard(clip: String) -> some View {
        let parsed = CoordinateParser.shared.parse(clip)
        let displayTitle: String = {
            if let p = parsed {
                let road = DatabaseManager.shared.findNearestRoad(lat: p.coordinate.latitude, lon: p.coordinate.longitude)
                return road?.name ?? p.formattedString
            }
            return GoogleMapsLinkResolver.shared.extractPlaceNameFromText(clip) ?? "Toạ độ GPS mới"
        }()

        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 2) {
                Text("Phát hiện toạ độ trong bộ nhớ tạm:")
                    .font(.caption2)
                    .foregroundColor(isDarkMode ? .gray : Color.black.opacity(0.6))
                Text(displayTitle)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(isDarkMode ? .white : Color.black)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: {
                handleCoordinateInputAndNavigate(clip)
            }) {
                Text("Dẫn đường")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

            Button(action: {
                withAnimation {
                    showClipboardBanner = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isDarkMode ? Color(red: 0.11, green: 0.13, blue: 0.17) : Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.6), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 6, y: 3)
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
                                Image(systemName: item.coordinate != nil ? "mappin.and.ellipse" : "car.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(item.coordinate != nil ? .green : (isDarkMode ? .cyan : .blue))

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(isDarkMode ? .white : Color(red: 0.08, green: 0.1, blue: 0.12))
                                            .lineLimit(1)

                                        if item.coordinate != nil {
                                            Text("GPS")
                                                .font(.system(size: 8, weight: .heavy))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(Color.green.opacity(0.18))
                                                .foregroundColor(.green)
                                                .cornerRadius(3)
                                        }
                                    }

                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption2)
                                            .foregroundColor(isDarkMode ? .gray : Color(red: 0.35, green: 0.38, blue: 0.42))
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

    // MARK: - HÀM XỬ LÝ TOẠ ĐỘ & DẪN ĐƯỜNG
    private func handleDirectCoordinateSubmit(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let parsed = CoordinateParser.shared.parse(trimmed) {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            let startCoord = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
            navManager.navigateToCoordinate(coordinate: parsed.coordinate, customTitle: nil, startCoord: startCoord) { success in
                if success {
                    searchQuery = ""
                    recenterTrigger += 1
                }
            }
        }
    }

    private func handleCoordinateInputAndNavigate(_ text: String) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        showClipboardBanner = false
        let startCoord = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
        navManager.resolveLinkAndNavigate(text: text, startCoord: startCoord) { success in
            if success {
                searchQuery = ""
                recenterTrigger += 1
            }
        }
    }

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

    private func checkClipboard() {
        if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty {
            if CoordinateParser.shared.parse(clip) != nil || GoogleMapsLinkResolver.shared.containsGoogleMapsLinkOrCoordinate(clip) {
                clipboardContent = clip
                withAnimation(.spring()) {
                    showClipboardBanner = true
                }
                return
            }
        }
        showClipboardBanner = false
        clipboardContent = nil
    }
}

// MARK: - MODAL SHEET NHẬP TOẠ ĐỘ GPS TIỆN LỢI CHO TÀI XẾ
public struct CoordinateInputSheet: View {
    @ObservedObject var tracker: SpeedTracker
    @ObservedObject var navManager: NavigationManager
    let isDarkMode: Bool
    @Binding var isPresented: Bool

    @State private var inputText: String = ""
    @State private var parsedCoordinate: ParsedCoordinate? = nil
    @State private var nearestRoadName: String? = nil

    private let sampleCoordinates = [
        ("Chợ Bến Thành", "10.7725, 106.6980"),
        ("Sân bay Tân Sơn Nhất", "10.8184, 106.6588"),
        ("Hồ Con Rùa", "10.7828, 106.6958"),
        ("Nút giao Cao tốc Long Thành", "10.7937, 106.7570")
    ]

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // 1. Ô NHẬP TOẠ ĐỘ
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nhập toạ độ GPS:")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(isDarkMode ? .white : .black)

                        HStack(spacing: 8) {
                            Image(systemName: "location.north.circle.fill")
                                .foregroundColor(isDarkMode ? .cyan : .blue)
                                .font(.title3)

                            TextField("vd: 10.7769, 106.7009", text: $inputText)
                                .font(.body)
                                .foregroundColor(isDarkMode ? .white : .black)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: inputText) { val in
                                    evaluateInput(val)
                                }

                            if !inputText.isEmpty {
                                Button(action: {
                                    inputText = ""
                                    parsedCoordinate = nil
                                    nearestRoadName = nil
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        .padding(12)
                        .background(isDarkMode ? Color(red: 0.12, green: 0.14, blue: 0.18) : Color(red: 0.95, green: 0.95, blue: 0.97))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(parsedCoordinate != nil ? Color.green : (isDarkMode ? Color.white.opacity(0.15) : Color.black.opacity(0.1)), lineWidth: 1.5)
                        )

                        // NÚT DÁN TỪ BỘ NHỚ TẠM
                        Button(action: {
                            if let clip = UIPasteboard.general.string {
                                inputText = clip
                                evaluateInput(clip)
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard.fill")
                                    .font(.subheadline)
                                Text("Dán từ bộ nhớ tạm (Clipboard)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isDarkMode ? Color.white.opacity(0.1) : Color.blue.opacity(0.08))
                            .foregroundColor(isDarkMode ? .cyan : .blue)
                            .cornerRadius(10)
                        }
                    }

                    // 2. KẾT QUẢ PHÂN TÍCH TOẠ ĐỘ THỰC TẾ
                    if let parsed = parsedCoordinate {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.subheadline)
                                Text("Toạ độ hợp lệ")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.green)
                                Spacer()
                                Text(parsed.label ?? "GPS")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .foregroundColor(.green)
                                    .cornerRadius(4)
                            }

                            HStack {
                                Text("Vĩ độ, Kinh độ:")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(parsed.formattedString)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(isDarkMode ? .white : .black)
                            }

                            if let road = nearestRoadName {
                                HStack {
                                    Text("Đường gần nhất:")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text(road)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(isDarkMode ? .cyan : .blue)
                                }
                            }

                            // NÚT BẮT ĐẦU DẪN ĐƯỜNG
                            Button(action: {
                                startNavigation(with: parsed)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.headline)
                                    Text("Bắt đầu Chỉ đường")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(LinearGradient(colors: [Color.green, Color(red: 0.0, green: 0.65, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(color: Color.green.opacity(0.4), radius: 6, y: 3)
                            }
                            .padding(.top, 4)
                        }
                        .padding(14)
                        .background(isDarkMode ? Color(red: 0.1, green: 0.15, blue: 0.12) : Color(red: 0.94, green: 0.98, blue: 0.94))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.green.opacity(0.5), lineWidth: 1.2)
                        )
                    } else if !inputText.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Chưa nhận dạng được toạ độ. Vui lòng nhập định dạng: 10.7769, 106.7009 hoặc độ phút giây.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    }

                    // 3. TOẠ ĐỘ MẪU ĐỂ CHỌN NHANH
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Điểm đến mẫu (Nhấn để chọn):")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.gray)

                        ForEach(sampleCoordinates, id: \.0) { sample in
                            Button(action: {
                                inputText = sample.1
                                evaluateInput(sample.1)
                            }) {
                                HStack {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(isDarkMode ? .cyan : .blue)
                                        .font(.caption)
                                    Text(sample.0)
                                        .font(.subheadline)
                                        .foregroundColor(isDarkMode ? .white : .black)
                                    Spacer()
                                    Text(sample.1)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isDarkMode ? Color.white.opacity(0.06) : Color.black.opacity(0.04))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // 4. HƯỚNG DẪN LẤY TOẠ ĐỘ TỪ GOOGLE MAPS
                    VStack(alignment: .leading, spacing: 6) {
                        Text("💡 Mẹo lấy toạ độ từ Google Maps (Miễn phí 100%):")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(isDarkMode ? .yellow : Color(red: 0.8, green: 0.5, blue: 0.0))

                        Text("1. Mở ứng dụng Google Maps trên điện thoại.\n2. Nhấn giữ vào bất kỳ điểm nào bạn muốn đến.\n3. Nhấn vào dãy toạ độ hiện lên (vd: 10.776889, 106.700806) để Sao chép.\n4. Mở VietSpeed và bấm \"Dán từ bộ nhớ tạm\".")
                            .font(.caption2)
                            .foregroundColor(isDarkMode ? Color.white.opacity(0.7) : Color.black.opacity(0.7))
                            .lineSpacing(3)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isDarkMode ? Color(red: 0.14, green: 0.13, blue: 0.08) : Color(red: 1.0, green: 0.98, blue: 0.92))
                    .cornerRadius(10)
                }
                .padding(16)
            }
            .background(isDarkMode ? Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea() : Color(red: 0.97, green: 0.97, blue: 0.98).ignoresSafeArea())
            .navigationTitle("Nhập Toạ độ GPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        isPresented = false
                    }
                    .foregroundColor(isDarkMode ? .cyan : .blue)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                if let clip = UIPasteboard.general.string, CoordinateParser.shared.parse(clip) != nil {
                    inputText = clip
                    evaluateInput(clip)
                }
            }
        }
    }

    private func evaluateInput(_ text: String) {
        if let parsed = CoordinateParser.shared.parse(text) {
            self.parsedCoordinate = parsed
            let road = DatabaseManager.shared.findNearestRoad(lat: parsed.coordinate.latitude, lon: parsed.coordinate.longitude)
            self.nearestRoadName = road?.name
        } else {
            self.parsedCoordinate = nil
            self.nearestRoadName = nil
        }
    }

    private func startNavigation(with parsed: ParsedCoordinate) {
        let startCoord = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
        navManager.navigateToCoordinate(coordinate: parsed.coordinate, customTitle: nearestRoadName, startCoord: startCoord) { success in
            if success {
                isPresented = false
            }
        }
    }
}
