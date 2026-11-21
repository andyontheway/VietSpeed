import sqlite3
import osmium
import re
import os
import sys
import time

PBF_FILE = "/Users/jr/Movies/MEDIA/vietnam-261120.osm.pbf"
OUTPUT_DB = "/Users/jr/Movies/APP/roads_vietnam.sqlite"

MAJOR_HIGHWAYS = {
    'motorway', 'motorway_link',
    'trunk', 'trunk_link',
    'primary', 'primary_link',
    'secondary', 'secondary_link',
    'tertiary', 'tertiary_link',
    'unclassified'
}

def parse_speed(speed_val, highway_type):
    if speed_val:
        s = str(speed_val).lower().strip()
        if 'urban' in s:
            return 60
        if 'rural' in s:
            return 80
        m = re.search(r'\d+', s)
        if m:
            v = int(m.group())
            if 20 <= v <= 140:
                return v

    hw = highway_type or ''
    if 'motorway' in hw:
        return 100
    if 'trunk' in hw:
        return 80
    if 'primary' in hw:
        return 60
    if 'secondary' in hw:
        return 60
    if 'tertiary' in hw:
        return 50
    return 50

class VietnamTrafficHandler(osmium.SimpleHandler):
    def __init__(self, cursor):
        super().__init__()
        self.cursor = cursor
        self.road_records = []
        self.rtree_records = []
        self.camera_records = []
        self.cam_rtree_records = []
        self.road_id = 0
        self.cam_id = 0
        self.total_ways_processed = 0

    def node(self, n):
        # Kiểm tra camera phạt nguội / kiểm tra tốc độ
        hw = n.tags.get('highway')
        enf = n.tags.get('enforcement')
        dev = n.tags.get('device:type')
        if hw == 'speed_camera' or enf or dev == 'speed_camera':
            self.cam_id += 1
            name = n.tags.get('name', 'Camera giám sát tốc độ')
            speed = parse_speed(n.tags.get('maxspeed'), 'primary')
            lat, lon = n.lat, n.lon
            self.camera_records.append((self.cam_id, name, speed, lat, lon))
            self.cam_rtree_records.append((self.cam_id, lat - 0.0001, lat + 0.0001, lon - 0.0001, lon + 0.0001))

    def way(self, w):
        hw = w.tags.get('highway')
        if not hw:
            return

        name = w.tags.get('name')
        maxspeed = w.tags.get('maxspeed')

        # Lọc các loại đường chính hoặc đường có tên/tốc độ cụ thể
        should_include = False
        if hw in MAJOR_HIGHWAYS:
            should_include = True
        elif hw in ('residential', 'living_street') and (name or maxspeed):
            should_include = True

        if not should_include:
            return

        display_name = name if name else f"Đoạn {hw}"
        speed_limit = parse_speed(maxspeed, hw)

        # Lấy toạ độ các nodes
        coords = []
        try:
            for n in w.nodes:
                if n.lat != 0 and n.lon != 0:
                    coords.append((n.lat, n.lon))
        except Exception:
            return

        if len(coords) < 2:
            return

        # Chia đoạn đường dài thành các đoạn nhỏ (mỗi đoạn 6-8 điểm mốc) để R-Tree tìm kiếm chính xác
        chunk_size = 7
        overlap = 1
        i = 0
        while i < len(coords) - 1:
            chunk = coords[i : i + chunk_size]
            if len(chunk) < 2:
                break

            lats = [pt[0] for pt in chunk]
            lons = [pt[1] for pt in chunk]
            min_lat, max_lat = min(lats), max(lats)
            min_lon, max_lon = min(lons), max(lons)
            center_lat = (min_lat + max_lat) / 2.0
            center_lon = (min_lon + max_lon) / 2.0

            self.road_id += 1
            self.road_records.append((self.road_id, display_name, speed_limit, hw, center_lat, center_lon))
            self.rtree_records.append((self.road_id, min_lat, max_lat, min_lon, max_lon))

            if len(self.road_records) >= 15000:
                self.flush()

            i += (chunk_size - overlap)

        self.total_ways_processed += 1
        if self.total_ways_processed % 20000 == 0:
            print(f"-> Đã xử lý {self.total_ways_processed} tuyến đường ({self.road_id} đoạn)...")

    def flush(self):
        if self.road_records:
            self.cursor.executemany("INSERT INTO roads VALUES (?, ?, ?, ?, ?, ?)", self.road_records)
            self.cursor.executemany("INSERT INTO road_index VALUES (?, ?, ?, ?, ?)", self.rtree_records)
            self.road_records.clear()
            self.rtree_records.clear()

        if self.camera_records:
            self.cursor.executemany("INSERT INTO cameras VALUES (?, ?, ?, ?, ?)", self.camera_records)
            self.cursor.executemany("INSERT INTO camera_index VALUES (?, ?, ?, ?, ?)", self.cam_rtree_records)
            self.camera_records.clear()
            self.cam_rtree_records.clear()

def main():
    if not os.path.exists(PBF_FILE):
        print(f"Lỗi: Không tìm thấy file {PBF_FILE}")
        sys.exit(1)

    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    print(f"Bắt đầu chuyển đổi: {PBF_FILE} -> {OUTPUT_DB}")
    start_time = time.time()

    conn = sqlite3.connect(OUTPUT_DB)
    cursor = conn.cursor()

    # Tối ưu tốc độ ghi SQLite
    cursor.execute("PRAGMA synchronous = OFF;")
    cursor.execute("PRAGMA journal_mode = MEMORY;")
    cursor.execute("PRAGMA cache_size = 100000;")

    # Tạo bảng metadata
    cursor.execute("""
        CREATE TABLE roads (
            id INTEGER PRIMARY KEY,
            name TEXT,
            speed_limit INTEGER,
            highway_type TEXT,
            center_lat REAL,
            center_lon REAL
        );
    """)

    # Tạo chỉ mục không gian R*Tree
    cursor.execute("""
        CREATE VIRTUAL TABLE road_index USING rtree(
            id,
            min_lat, max_lat,
            min_lon, max_lon
        );
    """)

    cursor.execute("""
        CREATE TABLE cameras (
            id INTEGER PRIMARY KEY,
            name TEXT,
            speed_limit INTEGER,
            lat REAL,
            lon REAL
        );
    """)

    cursor.execute("""
        CREATE VIRTUAL TABLE camera_index USING rtree(
            id,
            min_lat, max_lat,
            min_lon, max_lon
        );
    """)

    handler = VietnamTrafficHandler(cursor)
    handler.apply_file(PBF_FILE, locations=True)
    handler.flush()

    print("Đang hoàn thiện cơ sở dữ liệu và tối ưu index...")
    conn.commit()

    # Thu gọn và giải phóng dung lượng thừa
    cursor.execute("VACUUM;")
    conn.close()

    elapsed = time.time() - start_time
    file_size_mb = os.path.getsize(OUTPUT_DB) / (1024 * 1024)
    print(f"✅ HOÀN THÀNH trong {elapsed:.1f} giây!")
    print(f"📊 Tổng số đoạn đường lưu trữ: {handler.road_id}")
    print(f"📊 Tổng số camera: {handler.cam_id}")
    print(f"📁 Dung lượng file SQLite: {file_size_mb:.2f} MB")
    print(f"📍 Vị trí file: {OUTPUT_DB}")

if __name__ == "__main__":
    main()
