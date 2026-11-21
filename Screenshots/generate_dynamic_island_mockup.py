import math
from PIL import Image, ImageDraw, ImageFont

# Kích thước chuẩn màn hình iPhone 17 (1179 x 2556)
W, H = 1179, 2556
img = Image.new("RGB", (W, H), color="#1e2022")
draw = ImageDraw.Draw(img)

# Font chữ hệ thống macOS
def get_font(size, bold=False):
    try:
        if bold:
            return ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
        else:
            return ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size)
    except:
        return ImageFont.load_default()

font_time = get_font(42, bold=True)
font_nav_dist = get_font(40, bold=False)
font_nav_street = get_font(52, bold=True)
font_eta_time = get_font(56, bold=True)
font_eta_sub = get_font(38, bold=False)

font_island_speed = get_font(44, bold=True)
font_island_unit = get_font(24, bold=False)
font_island_sign = get_font(32, bold=True)

# 1. VẼ NỀN BẢN ĐỒ GOOGLE MAPS (DARK MODE)
# Vẽ sông Sài Gòn uốn lượn
river_points = [
    (1179, 700), (900, 900), (750, 1200), (820, 1600), (600, 2100), (400, 2556),
    (0, 2556), (0, 2100), (450, 1600), (520, 1200), (650, 900), (950, 700)
]
draw.polygon(river_points, fill="#152636")

# Vẽ các khối đô thị / công viên
draw.rounded_rectangle([150, 850, 550, 1300], radius=30, fill="#23272a")
draw.rounded_rectangle([750, 1400, 1100, 1900], radius=30, fill="#252b2f")
draw.rounded_rectangle([100, 1500, 480, 1950], radius=30, fill="#1c2c22") # Công viên cây xanh

# Vẽ các tuyến đường xá xung quanh
road_color = "#33393f"
draw.line([(0, 1100), (1179, 1000)], fill=road_color, width=28)
draw.line([(0, 1750), (1179, 1650)], fill=road_color, width=32)
draw.line([(350, 500), (450, 2556)], fill=road_color, width=24)
draw.line([(900, 500), (850, 2556)], fill=road_color, width=26)

# Tuyến đường dẫn đường màu xanh Google Maps (Route Polyline)
route_pts = [
    (590, 2150), (590, 1650), (610, 1400), (750, 1150), (980, 950)
]
# Viền bóng của đường dẫn đường
draw.line(route_pts, fill="#174ea6", width=42, joint="curve")
# Đường chính màu xanh Google Maps
draw.line(route_pts, fill="#4285f4", width=30, joint="curve")

# Mũi tên chỉ hướng trên đường xanh
draw.polygon([(600, 1370), (580, 1420), (620, 1420)], fill="#ffffff")

# Vị trí xe ô tô của bạn (Navigation Puck)
car_x, car_y = 590, 1900
draw.ellipse([car_x - 45, car_y - 45, car_x + 45, car_y + 45], fill="#ffffff")
draw.ellipse([car_x - 38, car_y - 38, car_x + 38, car_y + 38], fill="#1a73e8")
# Mũi tên xe
draw.polygon([(car_x, car_y - 25), (car_x - 16, car_y + 15), (car_x, car_y + 6), (car_x + 16, car_y + 15)], fill="#ffffff")

# 2. KHUNG ĐIỀU HƯỚNG GOOGLE MAPS (XANH LÁ ĐẬM Ở TRÊN)
nav_y = 210
draw.rounded_rectangle([32, nav_y, 1147, nav_y + 240], radius=40, fill="#137333")

# Mũi tên rẽ phải màu trắng
arrow_x, arrow_y = 120, nav_y + 120
draw.line([(arrow_x, arrow_y + 40), (arrow_x, arrow_y - 10), (arrow_x + 40, arrow_y - 10)], fill="#ffffff", width=14)
draw.polygon([(arrow_x + 55, arrow_y - 10), (arrow_x + 25, arrow_y - 35), (arrow_x + 25, arrow_y + 15)], fill="#ffffff")

draw.text((210, nav_y + 45), "Sau 300 m", font=font_nav_dist, fill="#d2e3fc")
draw.text((210, nav_y + 115), "Rẽ phải vào Đ. Mai Chí Thọ", font=font_nav_street, fill="#ffffff")

# 3. THANH THÔNG TIN GOOGLE MAPS DƯỚI CÙNG (ETA BAR)
eta_y = 2220
draw.rounded_rectangle([32, eta_y, 1147, eta_y + 240], radius=44, fill="#202124")
# Nút đỏ thoát điều hướng
draw.ellipse([70, eta_y + 60, 190, eta_y + 180], fill="#303134")
draw.line([(110, eta_y + 100), (150, eta_y + 140)], fill="#ea4335", width=8)
draw.line([(150, eta_y + 100), (110, eta_y + 140)], fill="#ea4335", width=8)

# Thông tin thời gian và khoảng cách
draw.text((230, eta_y + 55), "24 phút", font=font_eta_time, fill="#34a853")
draw.text((230, eta_y + 130), "15 km • Dự kiến đến 19:44", font=font_eta_sub, fill="#9aa0a6")

# Nút âm thanh và tìm kiếm phụ
draw.ellipse([980, eta_y + 60, 1100, eta_y + 180], fill="#303134")
draw.text((1025, eta_y + 95), "🔊", font=font_nav_dist, fill="#ffffff")

# 4. STATUS BAR TRÊN CÙNG
draw.text((90, 52), "19:20", font=font_time, fill="#ffffff")
# 5G & Battery icon bên phải
draw.text((980, 55), "5G", font=get_font(34, bold=True), fill="#ffffff")
draw.rounded_rectangle([1045, 62, 1095, 88], radius=6, outline="#ffffff", width=3)
draw.rectangle([1049, 66, 1085, 84], fill="#34c759") # Pin xanh

# =====================================================================
# 5. NGÔI SAO CHÍNH: DYNAMIC ISLAND (VIÊN THUỐC HOẠT ĐỘNG VIETSPEED)
# =====================================================================
island_w = 460
island_h = 110
island_x = (W - island_w) // 2
island_y = 38

# Vẽ viên thuốc màu đen sâu bóng bẩy với viền mờ cao cấp
draw.rounded_rectangle([island_x, island_y, island_x + island_w, island_y + island_h], 
                       radius=55, fill="#000000", outline="#222222", width=2)

# BÊN TRÁI VIÊN THUỐC: Tốc độ xe hiện tại
# Chấm xanh thể hiện GPS đang chạy ngầm
draw.ellipse([island_x + 28, island_y + 48, island_x + 42, island_y + 62], fill="#34c759")

# Số tốc độ 58
draw.text((island_x + 55, island_y + 26), "58", font=font_island_speed, fill="#ffffff")
draw.text((island_x + 115, island_y + 44), "km/h", font=font_island_unit, fill="#8e8e93")

# KHU VỰC GIỮA: Cảm biến Camera TrueDepth / FaceID
sensor_cx = W // 2 + 10
draw.ellipse([sensor_cx - 24, island_y + 32, sensor_cx + 24, island_y + 80], fill="#080808")

# BÊN PHẢI VIÊN THUỐC: Biển báo tốc độ 60 tròn đỏ thu nhỏ
sign_cx = island_x + island_w - 65
sign_cy = island_y + island_h // 2
sign_r = 38

# Vòng tròn trắng viền đỏ
draw.ellipse([sign_cx - sign_r, sign_cy - sign_r, sign_cx + sign_r, sign_cy + sign_r], 
             fill="#ffffff", outline="#ff3b30", width=8)
# Chữ số 60 trong biển báo
draw.text((sign_cx - 20, sign_cy - 18), "60", font=font_island_sign, fill="#000000")

# =====================================================================
# 6. THẺ MÔ TẢ TRỰC QUAN GÓC DƯỚI (CALLOUT GIẢI THÍCH)
# =====================================================================
callout_y = 620
draw.rounded_rectangle([60, callout_y, 1119, callout_y + 260], radius=32, 
                       fill="#000000e0", outline="#444444", width=3)

font_tag_title = get_font(38, bold=True)
font_tag_body = get_font(32, bold=False)

draw.text((100, callout_y + 35), "⚡ VIETSPEED TRÊN DYNAMIC ISLAND", font=font_tag_title, fill="#34c759")
draw.text((100, callout_y + 95), "• Bên trái: 58 km/h (Tốc độ xe thực tế từ GPS)", font=font_tag_body, fill="#ffffff")
draw.text((100, callout_y + 145), "• Bên phải: [ 60 ] (Biển báo giới hạn của đoạn đường)", font=font_tag_body, fill="#ffffff")
draw.text((100, callout_y + 195), "• Màn hình chính: Google Maps dẫn đường toàn màn hình", font=font_tag_body, fill="#a0a0a0")

# Lưu ảnh
output_path = "/Users/jr/Movies/APP/dynamic_island_googlemaps_demo.png"
img.save(output_path, "PNG")
print(f"Đã lưu ảnh demo hoàn tất: {output_path}")
