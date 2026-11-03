# Khu mẫu (tên hư cấu, chỉ để thử) quanh tâm Nominatim mẫu: overpass.json, overpass_preview.json, nominatim.json, ob/VNM.fgb.
# Nhà Open Buildings cố tình có ca phải bỏ: tin cậy thấp, trùng nhà OSM, nằm trên đường, nằm trên hồ.
import sys, os, json, math, random
import numpy as np, shapely
from shapely.geometry import box, Polygon, MultiPolygon, Point, LineString
from pyogrio.raw import write
OUT = sys.argv[1]
random.seed(7)
LAT0, LON0 = 21.0045, 105.8190
KX = 111320.0 * math.cos(math.radians(LAT0)); KY = 110574.0
def ll(x, z): return (LON0 + x / KX, LAT0 - z / KY)
def geom(pts): return [{"lat": ll(x, z)[1], "lon": ll(x, z)[0]} for x, z in pts]
els = []; nid = [1]
def way(pts, tags, closed=False):
    pts = list(pts)
    if closed and pts[0] != pts[-1]: pts = pts + [pts[0]]
    nid[0] += 1
    els.append({"type": "way", "id": nid[0], "geometry": geom(pts), "tags": tags}); return pts
def rect(cx, cz, w, d, ang=0.0):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + c * x - s * z, cz + s * x + c * z) for x, z in [(-w/2, -d/2), (w/2, -d/2), (w/2, d/2), (-w/2, d/2)]]
roads = []
def road(pts, tags, width):
    way(pts, tags); roads.append((LineString(pts), width))
# Đường lớn, đường nhánh, ngõ, ngách.
road([(-420, -120), (420, -120)], {"highway": "primary", "name": "Phố Mẫu Lớn", "lanes": "4"}, 12.8)
road([(-150, -420), (-150, 420)], {"highway": "secondary", "name": "Đường Mẫu Dọc"}, 10)
for z in (-40, 40, 160):
    road([(-420, z), (-150, z), (230, z + 6)], {"highway": "residential", "name": "Ngõ %d Phố Mẫu" % (abs(z) // 2)}, 6)
for x in (-60, 40, 150):
    road([(x, -120), (x, -40), (x + 4, 40)], {"highway": "service", "name": "Ngách %d" % (abs(x) // 10)}, 4)
road([(-60, 40), (-60, 160)], {"highway": "footway"}, 2)
road([(-150, 250), (300, 250)], {"highway": "tertiary", "name": "Đường Ven Sông Mẫu", "bridge": "no"}, 8)
road([(60, 250), (60, 330)], {"highway": "tertiary", "name": "Cầu Mẫu", "bridge": "yes"}, 8)
# Sông và hồ.
river = [(-420, 290), (-100, 286), (100, 292), (420, 288)]
way(river, {"waterway": "river", "name": "Sông Mẫu", "width": "24"})
bank = [(x, z - 12) for x, z in river] + [(x, z + 12) for x, z in reversed(river)]
way(bank, {"natural": "water", "water": "river"}, closed=True)
lake = [(120 + 60 * math.cos(a) * (1 + 0.15 * math.sin(3 * a)), 100 + 42 * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 28)[:-1]]
way(lake, {"natural": "water", "name": "Hồ Mẫu"}, closed=True)
lake_poly = Polygon(lake)
way([(40, 50), (210, 50), (210, 152), (40, 152)], {"leisure": "park", "name": "Vườn hoa Mẫu"}, closed=True)
way([(-140, 175), (-60, 175), (-60, 235), (-140, 235)], {"leisure": "pitch"}, closed=True)
# Chùa trong khuôn viên có tường bao, đình là một điểm di tích.
way(rect(-100, 100, 20, 14), {"building": "temple", "amenity": "place_of_worship", "religion": "buddhist", "name": "Chùa Mẫu", "roof:shape": "hipped", "building:levels": "1", "roof:levels": "1"}, closed=True)
way(rect(-100, 126, 10, 6), {"building": "yes", "roof:shape": "gabled", "building:levels": "1"}, closed=True)
way([(-125, 85), (-75, 85), (-75, 135), (-125, 135), (-125, 85)], {"barrier": "wall"})
way([(-125, 140), (-75, 140)], {"barrier": "fence"})
els.append({"type": "node", "id": 9, "lat": ll(-20, 130)[1], "lon": ll(-20, 130)[0], "tags": {"historic": "memorial", "name": "Bia Mẫu"}})
way([(-420, -300), (420, -300)], {"railway": "rail"})
# Nhà OSM vẽ tay dọc phố lớn: số tầng, màu tường, vài nhà mái dốc, một tòa cao có building:part.
osm_polys = []
x = -410
palette = ["#f1e3b8", "#e9c9a3", "#c9dbe3", "#f0c9b8", None, None, "#ffffff", "yellow"]
while x < 410:
    w = random.uniform(3.6, 6.0)
    if abs(x - (-150)) < 8 or abs(x + 60) < 3 or abs(x - 40) < 3 or abs(x - 150) < 3: x += 8; continue
    for side in (-1, 1):
        cz = -120 + side * (6.4 + 8)
        poly = rect(x + w / 2, cz, w - 0.2, 16)
        tags = {"building": "house", "building:levels": str(random.randint(3, 7))}
        c = random.choice(palette)
        if c: tags["building:colour"] = c
        if random.random() < 0.1: tags["roof:shape"] = "gabled"; tags["roof:colour"] = "#9a4a32"
        way(poly, tags, closed=True); osm_polys.append(Polygon(poly))
    x += w
tower = rect(-20, 205, 30, 22)
way(tower, {"building": "apartments", "name": "Tòa Mẫu", "height": "45"}, closed=True)
way(rect(-20, 205, 30, 22), {"building:part": "yes", "building:levels": "14", "building:colour": "#d8dde3"}, closed=True)
way(rect(-20, 205, 12, 8), {"building:part": "yes", "height": "52", "min_height": "45", "building:colour": "#b9c2cc"}, closed=True)
osm_polys.append(Polygon(tower))
json.dump({"version": 0.6, "elements": els}, open(os.path.join(OUT, "overpass.json"), "w"), ensure_ascii=False)
prev = [e for e in els if e["type"] == "way" and ("highway" in e["tags"] and e["tags"]["highway"] in ("primary", "secondary", "tertiary", "residential") or e["tags"].get("natural") == "water" or e["tags"].get("waterway") == "river")]
json.dump({"version": 0.6, "elements": prev}, open(os.path.join(OUT, "overpass_preview.json"), "w"), ensure_ascii=False)
json.dump([{"display_name": "Khu Mẫu, Quận Thử, Hà Nội, Việt Nam (dữ liệu mẫu)", "lat": str(LAT0), "lon": str(LON0),
            "boundingbox": [str(LAT0 - 0.004), str(LAT0 + 0.004), str(LON0 - 0.004), str(LON0 + 0.004)],
            "addresstype": "quarter", "address": {"country_code": "vn"}},
           {"display_name": "Phố Mẫu Lớn, Quận Thử, Hà Nội, Việt Nam (dữ liệu mẫu)", "lat": str(LAT0 + 0.001), "lon": str(LON0 - 0.002),
            "boundingbox": [str(LAT0), str(LAT0 + 0.002), str(LON0 - 0.003), str(LON0 - 0.001)], "addresstype": "road", "address": {"country_code": "vn"}}],
          open(os.path.join(OUT, "nominatim.json"), "w"), ensure_ascii=False)
# Open Buildings: dãy nhà ống dọc các ngõ, cộng các ca phải lọc, cộng nhà rải xa để thử chỉ mục.
geoms, conf, src, why = [], [], [], []
def add(poly, c, s, w):
    geoms.append(Polygon(poly)); conf.append(c); src.append(s); why.append(w)
road_union = shapely.union_all([l.buffer(wd / 2) for l, wd in roads])
for z0 in (-40, 40, 160):
    for side in (-1, 1):
        x = -410
        while x < 220:
            w = random.uniform(3.5, 5.5)
            poly = rect(x + w / 2, z0 + side * (3 + 7), w - 0.3, 13, ang=random.uniform(-0.03, 0.03))
            P = Polygon(poly)
            if not P.intersects(road_union) and not P.intersects(lake_poly) and not any(P.intersects(o) for o in osm_polys):
                r = random.random()
                add(poly, round(random.uniform(0.71, 0.97), 3) if r < 0.6 else (float("nan") if r < 0.8 else round(random.uniform(0.4, 0.69), 3)),
                    "Google" if r < 0.6 or r >= 0.8 else "Microsoft", "low" if r >= 0.8 else "keep")
            x += w
if "--dense" in sys.argv:  # khu đặc như phố cổ: nhà ống phủ kín các khối nhà còn trống
    occupied = shapely.union_all([Polygon(g) for g in [list(gg.exterior.coords) for gg in geoms]] + osm_polys) if geoms else None
    for gx in np.arange(-300, 300, 5.2):
        for gz in np.arange(-300, 300, 14.5):
            poly = rect(gx + 2.5, gz + 7, 4.8, 14)
            P = Polygon(poly)
            if P.intersects(road_union) or P.intersects(lake_poly) or abs(gz - 289) < 30 or (occupied is not None and P.intersects(occupied)):
                continue
            add(poly, round(random.uniform(0.72, 0.97), 3), "Google", "keep")
for i in range(40):  # trùng nhà OSM (dò lại từ ảnh, lệch một chút)
    o = random.choice(osm_polys); cx, cz = o.centroid.x + random.uniform(-0.8, 0.8), o.centroid.y + random.uniform(-0.8, 0.8)
    add(rect(cx, cz, 4.5, 14), 0.9, "Google", "dup")
for i in range(15):  # trên lòng đường lớn
    add(rect(random.uniform(-400, 400), -120 + random.uniform(-2, 2), 5, 4), 0.85, "Google", "road")
for i in range(15):  # trên mặt hồ, mặt sông
    p = lake_poly.representative_point() if i % 2 else Point(random.uniform(-400, 400), 289)
    add(rect(p.x + random.uniform(-15, 15), p.y + random.uniform(-6, 6), 4, 4), 0.8, "Microsoft", "water")
for i in range(6000):  # nhà rải xa ngoài khu
    a = random.uniform(0, 2 * math.pi); r = random.uniform(900, 5000)
    add(rect(r * math.cos(a), r * math.sin(a), 6, 9), 0.9, "Google", "far")
g_ll = [Polygon([ll(x, z) for x, z in g.exterior.coords]) for g in geoms]
g_ll = [MultiPolygon([g]) for g in g_ll]
os.makedirs(os.path.join(OUT, "ob"), exist_ok=True)
fn = os.path.join(OUT, "ob", "VNM.fgb")
if os.path.exists(fn): os.remove(fn)
write(fn, shapely.to_wkb(np.array(g_ll, dtype=object)), field_data=[np.array(conf), np.array(src, dtype=object), np.array(why, dtype=object)],
      fields=["confidence", "bf_source", "test_why"], geometry_type="MultiPolygon", crs="EPSG:4326", driver="FlatGeobuf", layer_options={"SPATIAL_INDEX": "YES"})
from collections import Counter
print("osm elements", len(els), "osm buildings", len(osm_polys), "ob", Counter(why))
