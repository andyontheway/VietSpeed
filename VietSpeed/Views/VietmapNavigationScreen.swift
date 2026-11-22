import SwiftUI
import MapKit
import CoreLocation

public struct VietmapNavigationScreen: View {
    @ObservedObject var tracker: SpeedTracker
    @ObservedObject var navManager = NavigationManager.shared
    
    @State private var is3DMode: Bool = true
    @State private var recenterTrigger: Int = 0
    @State private var searchQuery: String = ""
    @State private var isSearchFocused: Bool = false
    
    public init(tracker: SpeedTracker) {
        self.tracker = tracker
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
            // 1. LỚP BẢN ĐỒ 3D TOÀN MÀN HÌNH (VIETMAP 3D ENGINE)
            VietmapMapView(
                tracker: tracker,
                navManager: navManager,
                is3DMode: is3DMode,
                recenterTrigger: recenterTrigger
            )
            .ignoresSafeArea()
            
            // 2. CÁC LỚP WIDGET ĐIỀU HƯỚNG NỔI TRÊN BẢN ĐỒ
            VStack(spacing: 0) {
                // TOP BAR: DẪN ĐƯỜNG HOẶC TÌM KIẾM
                topHeaderSection
                    .padding(.horizontal, 14)
                    .padding(.top, 6)
                
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
    
    // MARK: - TOP HEADER SECTION
    @ViewBuilder
    private var topHeaderSection: some View {
        if navManager.isNavigating {
            // BANNER CHỈ DẪN LỘ TRÌNH (TURN-BY-TURN HUD)
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // Biểu tượng rẽ hướng tiếp theo
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.05, green: 0.55, blue: 0.95))
                            .frame(width: 52, height: 52)
                            .shadow(color: Color.blue.opacity(0.4), radius: 6)
                        
                        VStack(spacing: 2) {
                            Image(systemName: navManager.nextStepIcon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Khoảng cách tới ngã rẽ và tên đường tiếp theo
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            if !navManager.nextStepDistance.isEmpty {
                                Text(navManager.nextStepDistance)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            Text(navManager.nextInstruction)
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        // Quãng đường còn lại & Thời gian dự kiến
                        HStack(spacing: 8) {
                            Label(navManager.remainingDistance, systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.85))
                            
                            Text("•")
                                .foregroundColor(.gray)
                            
                            Label(navManager.remainingTime, systemImage: "clock.fill")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    
                    Spacer()
                    
                    // Nút huỷ lộ trình
                    Button(action: {
                        navManager.stopNavigation()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(UIColor.systemBackground).opacity(0.92))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(red: 0.0, green: 0.65, blue: 1.0).opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                )
            }
        } else {
            // THANH TÌM KIẾM ĐỊA ĐIỂM + CHIP ĐIỂM ĐẾN NHANH
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cyan)
                        .font(.system(size: 16, weight: .bold))
                    
                    TextField("Tìm điểm đến (Sân bay, Bến Thành...)", text: $searchQuery)
                        .foregroundColor(.white)
                        .font(.subheadline)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: searchQuery) { query in
                            let loc = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
                            navManager.searchPlaces(query: query, userLocation: loc)
                        }
                    
                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            navManager.searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.black.opacity(0.82))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.4), radius: 8)
                )
                
                // GỢI Ý ĐIỂM ĐẾN PHỔ BIẾN (KHI CHƯA GÕ TÌM KIẾM)
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
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.75))
                                    .foregroundColor(.white)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.cyan.opacity(0.5), lineWidth: 0.8)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - DROPDOWN DANH SÁCH KẾT QUẢ TÌM KIẾM
    private var searchResultsDropdown: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(navManager.searchResults.prefix(5), id: \.self) { item in
                        Button(action: {
                            startNavigatingTo(item: item)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "car.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.cyan)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Điểm đến")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    if let title = item.placemark.title {
                                        Text(title)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("Chỉ đường")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.cyan)
                                    .foregroundColor(.black)
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        Divider().background(Color.white.opacity(0.1))
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.6), radius: 10)
        )
    }
    
    // MARK: - BOTTOM CONTROLS SECTION (WIDGET TỐC ĐỘ VIETMAP + NÚT MAP)
    private var bottomControlsSection: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // CỤM WIDGET TỐC ĐỘ PHONG CÁCH VIETMAP ĐẶC TRƯNG
            VStack(alignment: .leading, spacing: 8) {
                // TÊN ĐƯỜNG HIỆN TẠI (BADGE TRÊN CỤM ĐỒNG HỒ)
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(tracker.gpsAccuracy > 0 ? .green : .orange)
                    Text(tracker.roadName)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.85))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                )
                
                // HÀNG BIỂN BÁO & ĐỒNG HỒ TỐC ĐỘ
                HStack(spacing: 10) {
                    // 1. BIỂN BÁO GIỚI HẠN TỐC ĐỘ (Vòng tròn viền đỏ)
                    if let limit = tracker.speedLimit {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 68, height: 68)
                                .overlay(
                                    Circle().stroke(Color.red, lineWidth: 8)
                                )
                                .shadow(color: .black.opacity(0.4), radius: 6)
                            
                            Text("\(limit)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.7))
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
                            .foregroundColor(tracker.isOverSpeed ? .yellow : .white)
                            .shadow(color: tracker.isOverSpeed ? .red : .clear, radius: 10)
                        
                        Text("km/h")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.gray)
                    }
                    .frame(minWidth: 70)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.85))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tracker.isOverSpeed ? Color.red : Color.white.opacity(0.2), lineWidth: tracker.isOverSpeed ? 2 : 1)
                    )
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.black, lineWidth: 1.5)
                    )
                }
                
                // 4. CẢNH BÁO CAMERA PHẠT NGUỘI NỔI BẬT
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
            
            // CỤM NÚT ĐIỀU KHIỂN BẢN ĐỒ BÊN PHẢI
            VStack(spacing: 12) {
                // Nút chuyển 2D / 3D
                Button(action: {
                    withAnimation {
                        is3DMode.toggle()
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                            )
                        
                        Text(is3DMode ? "3D" : "2D")
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.cyan)
                    }
                }
                
                // Nút Định tâm lại xe (Recenter & Follow Heading)
                Button(action: {
                    recenterTrigger += 1
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 46, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                        
                        Image(systemName: "location.north.line.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }
    
    // MARK: - KHỞI TẠO LỘ TRÌNH DẪN ĐƯỜNG
    private func startNavigatingTo(item: MKMapItem) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        let startCoord = tracker.lastCoordinate ?? CLLocationCoordinate2D(latitude: 10.7769, longitude: 106.7009)
        navManager.calculateRoute(from: startCoord, to: item) { success in
            if success {
                searchQuery = ""
                recenterTrigger += 1
            }
        }
    }
}
