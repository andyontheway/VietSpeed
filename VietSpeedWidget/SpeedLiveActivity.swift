import ActivityKit
import WidgetKit
import SwiftUI

struct SpeedLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SpeedWidgetAttributes.self) { context in
            // GIAO DIỆN MÀN HÌNH KHOÁ (LOCK SCREEN BANNER)
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(context.state.isOverSpeed ? Color.red : Color.green)
                            .frame(width: 8, height: 8)
                        Text(context.state.roadName)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }

                    if let cam = context.state.cameraAlertText {
                        Text(cam)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    } else {
                        Text(context.state.subSign)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                // Tốc độ hiện tại
                VStack(spacing: -2) {
                    Text("\(context.state.currentSpeed)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(context.state.isOverSpeed ? .red : .white)
                    Text("km/h")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                // Biển báo tốc độ giới hạn
                ZStack {
                    Circle()
                        .fill(Color.white)
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 5)
                    Text("\(context.state.speedLimit)")
                        .font(.system(size: 19, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }
                .frame(width: 48, height: 48)
            }
            .padding(16)
            .background(Color.black.opacity(0.9))
        } dynamicIsland: { context in
            DynamicIsland {
                // KHI NHẤN GIỮ MỞ RỘNG (EXPANDED DYNAMIC ISLAND)
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(context.state.currentSpeed)")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(context.state.isOverSpeed ? .red : .white)
                        Text("km/h")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.leading, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                            Circle()
                                .strokeBorder(Color.red, lineWidth: 4)
                            Text("\(context.state.speedLimit)")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(.black)
                        }
                        .frame(width: 42, height: 42)

                        Text(context.state.subSign)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.trailing, 8)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        Text(context.state.roadName)
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if let cam = context.state.cameraAlertText {
                            Text(cam)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                }
            } compactLeading: {
                // BÊN TRÁI VIÊN THUỐC: Tốc độ xe (Chấm trạng thái + Số km/h)
                HStack(spacing: 3) {
                    Circle()
                        .fill(context.state.isOverSpeed ? Color.red : Color.green)
                        .frame(width: 5, height: 5)
                    Text("\(context.state.currentSpeed)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(context.state.isOverSpeed ? .red : .white)
                }
                .padding(.leading, 4)
                .padding(.trailing, 2)
            } compactTrailing: {
                // BÊN PHẢI VIÊN THUỐC: Biển tròn viền đỏ (Được căn lề an toàn để KHÔNG CẤN CAMERA)
                ZStack {
                    Circle()
                        .fill(Color.white)
                    // Dùng strokeBorder thay vì stroke để viền đỏ nằm hoàn toàn bên trong hình tròn
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 2.5)
                    Text("\(context.state.speedLimit)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 22, height: 22)
                .aspectRatio(1, contentMode: .fit)
                .padding(.leading, 6)   // ĐỆM CÁCH XA CAMERA: Giúp hình tròn không bị khoét lẹm vào phần cảm biến
                .padding(.trailing, 4)  // Đệm lề phải
            } minimal: {
                // Khi có app khác (nhạc) cùng chiếm Dynamic Island
                ZStack {
                    Circle()
                        .fill(Color.white)
                    Circle()
                        .strokeBorder(Color.red, lineWidth: 2)
                    Text("\(context.state.speedLimit)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.black)
                }
                .frame(width: 18, height: 18)
            }
        }
    }
}
