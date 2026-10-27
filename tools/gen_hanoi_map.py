#!/usr/bin/env python3
"""Dựng tay map "phường An Hòa" kiểu một khu phố Hà Nội (không lấy bản đồ thật), ghi ra data/maps/hn_an_hoa.json
cùng định dạng map nướng sẵn (scripts/realmap/area_data.gd from_dict) và data/maps/hn_an_hoa_story.json (chỗ đặt các
địa điểm của truyện).

Bố cục gọn như map của Nobody: vài con phố rõ ràng, mỗi khu một vẻ, đi bộ vài phút là hết:
- Bắc: rạch Bờ Me chạy ngang, bờ kè trồng cây, Cầu Nhỏ bắc qua; bên kia rạch một dãy nhà lưng quay ra kênh.
- Phố Bờ Me (phố buôn bán, xe đông) chạy dọc rạch: xóm trọ cuối ngõ, quán cơm, tiệm sửa xe, năm quán ven rạch,
  chợ Cầu Nhỏ ở chân cầu.
- Phố An Hòa ở giữa, song song; ngõ, ngách nối hai phố.
- Phố đường tàu ở phía tây: đường ray chạy sát hai dãy nhà.
- Nam: hồ An Hòa có đường ven hồ, đình làng sau hồ; khu tập thể năm tầng phía đông.

Đơn vị mét, x hướng đông, z hướng nam (máy quay nhìn từ phía nam lên). Chạy: python3 tools/gen_hanoi_map.py
"""
import json
import math
import os
import random

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
MAP_ID = "hn_an_hoa"
X0, X1, Z0, Z1 = -215.0, 215.0, -180.0, 175.0

rng = random.Random(1987)

# Màu tường phố Hà Nội: vàng Hà Nội, vàng nhạt, kem, trắng ngà, xám, hồng phai, xanh nhạt; ít màu đất.
WALLS = ["e8b84a", "f0cf7a", "f2e3b6", "efe8d6", "dcd6c8", "e6c9b8", "cfdbe0", "d6e2cc", "f1c27d", "e3a95c",
         "cbc4b4", "f4eee0", "d8c7a3", "b9c8b5"]
OLD_WALLS = ["d9b45f", "c9a663", "cdbb92", "b8a98a", "d6c08d"]
TILES = ["9a4a2f", "8c3f28", "a5532f", "7d3a25", "93492e"]
TAPTHE_WALLS = ["d4cbb5", "cfc6af", "dad1bb", "c9c1ad"]

roads = []        # {l, k, w, n, b, t, s, sw}
buildings = []    # định dạng nướng sẵn
parks = []
water = []
waterways = []
walls = []
rails = []
trees = []
reserved = []     # đa giác không xây nhà (lô địa điểm, sân đình, sân tập thể, bãi cỏ)


# ---------------------------------------------------------------- hình học

def sub(a, b): return (a[0] - b[0], a[1] - b[1])
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def mul(a, k): return (a[0] * k, a[1] * k)
def length(a): return math.hypot(a[0], a[1])
def norm(a):
    l = length(a)
    return (a[0] / l, a[1] / l) if l > 1e-9 else (0.0, 0.0)
def left(d): return (d[1], -d[0])  # pháp tuyến bên trái theo chiều vẽ (x đông, z nam)


def seg_dist(p, a, b):
    ab = sub(b, a)
    t = max(0.0, min(1.0, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / max(ab[0] ** 2 + ab[1] ** 2, 1e-9)))
    q = add(a, mul(ab, t))
    return length(sub(p, q))


def in_poly(p, poly):
    x, y = p
    inside = False
    n = len(poly)
    for i in range(n):
        x1, y1 = poly[i]
        x2, y2 = poly[(i + 1) % n]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            inside = not inside
    return inside


def poly_hits(poly, test):
    """Kiểm tra đa giác (lấy mẫu cạnh và bên trong) có điểm nào thỏa test."""
    pts = list(poly)
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        k = max(1, int(length(sub(b, a)) / 0.8))
        for j in range(k):
            pts.append(add(a, mul(sub(b, a), j / k)))
    cx = sum(p[0] for p in poly) / n
    cz = sum(p[1] for p in poly) / n
    pts.append((cx, cz))
    for p in poly:
        pts.append(((p[0] + cx) / 2, (p[1] + cz) / 2))
    return any(test(p) for p in pts)


def ellipse(cx, cz, rx, rz, n=40, wobble=0.0, seed=0):
    r = random.Random(seed)
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        k = 1.0 + (r.uniform(-wobble, wobble) if wobble else 0.0)
        out.append((cx + math.cos(a) * rx * k, cz + math.sin(a) * rz * k))
    return out


def round_rect(x0, z0, x1, z1, r, n=6):
    out = []
    corners = [(x1 - r, z0 + r, -90), (x1 - r, z1 - r, 0), (x0 + r, z1 - r, 90), (x0 + r, z0 + r, 180)]
    for cx, cz, a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            out.append((cx + math.cos(a) * r, cz + math.sin(a) * r))
    return out


# ---------------------------------------------------------------- đường

def road(name, pts, w, kind="residential", sw=None, small=False, bridge=False):
    r = {"l": [c for p in pts for c in (round(p[0], 2), round(p[1], 2))], "k": kind, "w": w, "n": name,
         "b": bridge, "t": False, "s": small}
    if sw is not None:
        r["sw"] = sw
    r["_pts"] = [tuple(p) for p in pts]
    r["_hw"] = w / 2.0 + (sw or 0.0)
    roads.append(r)
    return r


def in_corridor(p, pad=0.25, skip=None):
    for r in roads:
        if r is skip:
            continue
        pts = r["_pts"]
        for i in range(len(pts) - 1):
            if seg_dist(p, pts[i], pts[i + 1]) < r["_hw"] + pad:
                return True
    return False


def in_water(p):
    return any(in_poly(p, w) for w in water)


def in_reserved(p):
    return any(in_poly(p, q) for q in reserved)


def outside(p):
    return not (X0 + 1 <= p[0] <= X1 - 1 and Z0 + 1 <= p[1] <= Z1 - 1)


def blocked(p, skip=None):
    return outside(p) or in_water(p) or in_reserved(p) or in_corridor(p, skip=skip)


# ---------------------------------------------------------------- nhà

def house(poly, h, colour, name="", roof="", roof_colour="", kind="house", worship=False, roof_h=0.0):
    buildings.append({"c": colour, "h": round(h, 2), "hi": False, "k": True, "kind": kind, "mh": 0.0, "n": name,
                      "p": [round(c, 2) for p in poly for c in p], "rc": roof_colour, "rh": roof_h, "rs": roof,
                      "s": "hand", "w": worship, "_poly": poly})


def overlaps_house(poly):
    xs = [p[0] for p in poly]
    zs = [p[1] for p in poly]
    bx = (min(xs), min(zs), max(xs), max(zs))
    for b in buildings:
        q = b["_poly"]
        qx = [p[0] for p in q]
        qz = [p[1] for p in q]
        if max(qx) < bx[0] + 0.05 or min(qx) > bx[2] - 0.05 or max(qz) < bx[1] + 0.05 or min(qz) > bx[3] - 0.05:
            continue
        if poly_hits(poly, lambda p: in_poly(p, q)) or poly_hits(q, lambda p: in_poly(p, poly)):
            return True
    return False


def free_depth(front, inward, road_ref, dmax):
    """Chiều sâu còn trống phía sau mặt tiền; nếu gặp đường khác thì chỉ lấy nửa (dãy bên kia cũng xây)."""
    d = 0.5
    while d <= dmax * 2 + 0.5:
        p = add(front, mul(inward, d))
        if outside(p) or in_water(p) or in_reserved(p):
            return d - 0.6, False
        if in_corridor(p, pad=0.3, skip=road_ref):
            return d / 2.0 - 0.15, True
        d += 0.5
    return dmax, False


def style_for(zone):
    """(bề ngang, số tầng, tỉ lệ nhà cổ mái ngói) theo khu."""
    return {
        "pho": ((3.6, 5.6), (3, 5), 0.06),
        "pho_nho": ((3.8, 6.0), (2, 4), 0.14),
        "ngo": ((4.0, 7.0), (2, 4), 0.22),
        "duong_tau": ((3.4, 5.0), (2, 4), 0.25),
        "ven_ho": ((4.5, 7.5), (3, 6), 0.05),
        "bo_kia": ((4.5, 8.0), (1, 3), 0.35),
    }[zone]


def row(r, side, zone, dmax=18.0, dmin=5.0, start=0.0, end=None, gaps=()):
    """Dãy nhà ống dọc một bên đường r (side +1: bên trái theo chiều vẽ). gaps: khoảng (u0, u1) chừa trống."""
    pts = r["_pts"]
    widths, floors, old_share = style_for(zone)
    u_total = 0.0
    seg_info = []
    for i in range(len(pts) - 1):
        l = length(sub(pts[i + 1], pts[i]))
        seg_info.append((u_total, l, pts[i], norm(sub(pts[i + 1], pts[i]))))
        u_total += l
    end = u_total if end is None else end
    u = start
    while u < end - 2.5:
        w = rng.uniform(*widths)
        if u + w > end:
            w = end - u
            if w < 3.0:
                break
        if any(g0 - 0.3 < u + w and u < g1 + 0.3 for g0, g1 in gaps):
            nxt = min(g1 for g0, g1 in gaps if g0 - 0.3 < u + w and u < g1 + 0.3) + 0.3
            u = max(u + 0.5, nxt)
            continue
        um = u + w / 2
        seg = None
        for s in seg_info:
            if s[0] <= um <= s[0] + s[1] + 1e-6:
                seg = s
                break
        if seg is None:
            break
        u0, l, a, d = seg
        # Nhà sát góc khúc quanh: bỏ, khỏi chĩa vào đường.
        if um - u0 < w / 2 - 0.01 or u0 + l - um < w / 2 - 0.01:
            u += 1.0
            continue
        n = left(d)
        if side < 0:
            n = (-n[0], -n[1])
        inward = n
        base = add(add(a, mul(d, um - u0)), mul(inward, r["_hw"] + 0.15))
        fa = add(base, mul(d, -w / 2))
        fb = add(base, mul(d, w / 2))
        depth_a, _ = free_depth(fa, inward, r, dmax)
        depth_b, _ = free_depth(fb, inward, r, dmax)
        depth_m, _ = free_depth(base, inward, r, dmax)
        depth = min(depth_a, depth_b, depth_m, dmax)
        if depth < dmin:
            u += w
            continue
        poly = [fa, fb, add(fb, mul(inward, depth)), add(fa, mul(inward, depth))]
        if poly_hits(poly, lambda p: blocked(p, skip=r)) or overlaps_house(poly):
            u += 1.0
            continue
        old = rng.random() < old_share
        if old:
            fl = rng.randint(1, 2)
            h = fl * 3.3
            house(poly, h, rng.choice(OLD_WALLS), roof="gabled", roof_colour=rng.choice(TILES),
                  roof_h=min(w * 0.4, 2.2))
        else:
            fl = rng.randint(*floors)
            # Nhà ống mặt phố: mỗi căn một chiều cao, lệch nhau vài tầng như phố thật.
            h = fl * 3.3 + rng.uniform(0.2, 0.9)
            house(poly, h, rng.choice(WALLS))
        u += w


# ---------------------------------------------------------------- bố cục

def build():
    # --- Rạch Bờ Me và bờ kè hai bên.
    canal = [(X0, -128.0), (X1, -128.0), (X1, -114.0), (X0, -114.0)]
    water.append(canal)
    waterways.append({"k": "canal", "l": [X0, -121.0, X1, -121.0], "n": "Rạch Bờ Me", "w": 14.0})
    for z in (-110.5, -131.5):
        reserved.append([(X0, z - 3.5), (X1, z - 3.5), (X1, z + 3.5), (X0, z + 3.5)])
    x = X0 + 6
    while x < X1 - 4:
        if abs(x - 60) > 9:
            trees.append((round(x + rng.uniform(-1.5, 1.5), 1), -110.8))
            trees.append((round(x + rng.uniform(-1.5, 1.5), 1), -131.2))
        x += rng.uniform(9, 13)

    # --- Hồ An Hòa và đường ven hồ.
    lake = ellipse(-40, 95, 44, 28, n=36, wobble=0.07, seed=7)
    water.append(lake)
    ring = round_rect(-104, 50, 24, 140, 14)
    ring.append(ring[0])
    promenade = round_rect(-100.5, 53.5, 20.5, 136.5, 11)
    parks.append({"k": "park", "n": "Vườn hoa ven hồ", "p": promenade})
    reserved.append(promenade)
    for p in ellipse(-40, 95, 51, 34, n=26, seed=3):
        trees.append((round(p[0], 1), round(p[1], 1)))

    # --- Đình An Hòa sau hồ: sân gạch, cổng, hai cây đa.
    dinh_yard = [(-66, 146), (-14, 146), (-14, 174), (-66, 174)]
    reserved.append(dinh_yard)
    parks.append({"k": "village_green", "n": "Sân đình", "p": dinh_yard})
    house([(-56, 158), (-24, 158), (-24, 170), (-56, 170)], 5.2, "d9b56b", name="Đình An Hòa", roof="hipped",
          roof_colour="6e2f22", kind="temple", worship=True, roof_h=3.4)
    house([(-46, 147.2), (-34, 147.2), (-34, 149.2), (-46, 149.2)], 3.6, "c9a24f", name="Cổng đình", roof="gabled",
          roof_colour="6e2f22", kind="gate", worship=True, roof_h=1.4)
    walls.append({"h": 1.4, "k": "wall", "l": [-66, 147, -66, 174, -14, 174, -14, 147]})
    trees.extend([(-60, 152), (-20, 152), (-62, 166), (-18, 166)])

    # --- Khu tập thể năm tầng: bốn dãy, sân giữa có cây, sân chơi.
    for z in (34, 76, 118):
        for x0, x1 in ((72, 128), (140, 196)):
            house([(x0, z), (x1, z), (x1, z + 12), (x0, z + 12)], 16.4, rng.choice(TAPTHE_WALLS),
                  name="Nhà A%d" % (len([b for b in buildings if b["kind"] == "apartments"]) + 1), kind="apartments")
            reserved.append([(x0 - 1, z - 1), (x1 + 1, z - 1), (x1 + 1, z + 13), (x0 - 1, z + 13)])
        yard = [(66, z + 16), (205, z + 16), (205, z + 30), (66, z + 30)]
        if z < 118:
            parks.append({"k": "grass" if z == 34 else "playground", "n": "", "p": yard})
            reserved.append(yard)
            for k in range(6):
                trees.append((round(rng.uniform(72, 200), 1), round(rng.uniform(z + 18, z + 28), 1)))

    # --- Phố, ngõ (đường lớn trước: dãy nhà bám đường lớn trước).
    bo_me = road("Phố Bờ Me", [(X0, -80), (X1, -80)], 8.0, "secondary", sw=3.5)
    an_hoa = road("Phố An Hòa", [(X0, 20), (X1, 20)], 7.0, "tertiary", sw=3.0)
    cho = road("Phố Chợ Cầu Nhỏ", [(60, -80), (60, 20)], 6.0, "residential", sw=2.5)
    road("Cầu Nhỏ", [(60, -108), (60, -134)], 6.0, "residential", bridge=True)
    cau_n = road("Phố Chợ Cầu Nhỏ", [(60, -80), (60, -108)], 6.0, "residential", sw=1.5)
    cau_s = road("Phố Chợ Cầu Nhỏ", [(60, -134), (60, -152)], 6.0, "residential", sw=1.5)
    ben_kia = road("Phố Bên Kia Rạch", [(X0, -152), (X1, -152)], 6.0, "residential", sw=2.0)
    hang_than = road("Phố Hàng Than", [(150, -80), (150, 20)], 6.0, "residential", sw=2.5)
    ho = road("Phố Hồ", [(-40, 20), (-40, 50)], 6.0, "residential", sw=2.5)
    ven_ho = road("Phố Ven Hồ", ring, 5.0, "residential", sw=1.5)
    tap_the = road("Phố Tập Thể", [(55, 20), (55, Z1)], 6.0, "residential", sw=2.5)
    dinh = road("Phố Đình", [(-121.5, 144), (-104, 144)], 5.0, "residential", sw=1.0)
    # Phố đường tàu: đường ray vòng từ mép tây vào rồi chạy thẳng xuống nam, hai bên sát nhà, lối đi lát xi măng.
    rail = [(X0, -40), (-170, -40), (-150, -37.5), (-136, -30), (-128, -18), (-125, -4), (-125, Z1)]
    rails.append({"l": [c for p in rail for c in p]})
    duong_tau = road("Phố Đường Tàu", rail, 7.0, "pedestrian", small=True)
    # Ngõ, ngách.
    ngo_xom = road("Ngõ Bờ Me", [(-60, -84), (-60, -97)], 3.2, "service", small=True)
    san_xom = road("Ngõ Bờ Me", [(-67, -97), (-53, -97)], 3.2, "service", small=True)
    ngo_dua = road("Ngõ Dừa", [(40, -76), (40, -44)], 3.0, "service", small=True)
    ngo_gieng = road("Ngõ Giếng", [(-121.5, -30), (-20, -30), (56.5, -30)], 3.4, "service", small=True)
    ngo_tram = road("Ngõ Trạm", [(-20, -76), (-20, 16.5)], 3.2, "service", small=True)
    ngo_than = road("Ngõ Hàng Than", [(63.5, -30), (146.5, -30)], 3.2, "service", small=True)
    ngo_dong = road("Ngõ Đông", [(153.5, -40), (X1, -40)], 3.2, "service", small=True)
    ngo_tay0 = road("Ngõ Đường Tàu", [(X0, -12), (-128.5, -12)], 3.2, "service", small=True)
    ngo_tay1 = road("Ngõ Đường Tàu", [(X0, 56), (-128.5, 56)], 3.2, "service", small=True)
    ngo_tay = road("Ngõ Đường Tàu", [(X0, 90), (-128.5, 90)], 3.2, "service", small=True)
    ngo_ho = road("Ngõ Hồ", [(28, 100), (51, 100)], 3.0, "service", small=True)
    ngo_tay2 = road("Ngõ Đường Tàu", [(X0, 140), (-128.5, 140)], 3.2, "service", small=True)
    # Ngõ tập thể chạy sát mặt trước mỗi dãy nhà năm tầng (dãy có ban công, cục nóng, kiốt tầng trệt nhìn ra ngõ).
    ngo_tt = [road("Ngõ Tập Thể", [(58, z), (X1, z)], 4.0, "service", small=True) for z in (30, 72, 114, 156)]
    ngo_bk = road("Ngõ Bên Kia", [(-60, -155), (-60, -178)], 3.0, "service", small=True)

    # --- Lô của các địa điểm (dọn trước để dãy nhà chừa chỗ, cửa thẳng hàng với dãy bên cạnh).
    for lot in LOTS.values():
        reserved.append(lot)

    # --- Dãy nhà, theo thứ tự ưu tiên.
    # Dãy cắt ngang đường khác thì tự bỏ căn đó (chừa miệng ngõ, ngã tư); hai dãy quay lưng nhau chia đôi chỗ trống.
    row(bo_me, +1, "pho", dmax=22)    # phía bắc: lưng quay ra rạch
    row(bo_me, -1, "pho", dmax=20)
    row(an_hoa, +1, "pho", dmax=20)
    row(an_hoa, -1, "pho", dmax=20)
    row(ben_kia, -1, "bo_kia", dmax=13)   # bờ bắc rạch: lưng quay ra rạch
    row(ben_kia, +1, "bo_kia", dmax=18)
    for r in (cho, hang_than, ho, tap_the, cau_n, cau_s):
        row(r, +1, "pho_nho", dmax=18)
        row(r, -1, "pho_nho", dmax=18)
    row(ven_ho, +1, "ven_ho", dmax=16)
    row(duong_tau, +1, "duong_tau", dmax=14)
    row(duong_tau, -1, "duong_tau", dmax=14)
    for r in (ngo_xom, san_xom, ngo_dua, ngo_gieng, ngo_tram, ngo_than, ngo_dong, ngo_tay0, ngo_tay1, ngo_tay, ngo_tay2,
              ngo_bk, ngo_ho, dinh):
        row(r, +1, "ngo", dmax=18, dmin=4.5)
        row(r, -1, "ngo", dmax=18, dmin=4.5)
    for r in ngo_tt:
        row(r, +1, "ngo", dmax=9, dmin=4.5)
        row(r, -1, "ngo", dmax=9, dmin=4.5)

    # --- Cây sấu, cây bàng dọc vỉa hè phố lớn, hàng liễu ven hồ đã có.
    for r, z in ((bo_me, -80), (an_hoa, 20)):
        off = r["w"] / 2.0 + r["sw"] * 0.55
        x = X0 + 8
        while x < X1 - 8:
            for side in (-1, 1):
                p = (round(x + rng.uniform(-1, 1), 1), z + side * off)
                if not in_corridor(p, pad=1.0, skip=r) and not any(in_poly(p, q) for q in LOTS.values()):
                    trees.append(p)
            x += rng.uniform(13, 17)


# Lô dành cho địa điểm của truyện (nhà dựng riêng trong game): khớp với "locations" trong file truyện.
LOTS = {}
LOCATIONS = {
    # id: (giữa nhà, bề ngang, chiều sâu, phố quay mặt ra)
    "xom_bo_me": ((-60, -104), 13, 10, "Ngõ Bờ Me"),
    "com_hanh": ((-38, -93), 8, 11, "Phố Bờ Me"),
    "tiem_sau": ((-70, -93), 8, 11, "Phố Bờ Me"),
    "ben_can": ((22, -93), 24, 10, "Phố Bờ Me"),
    "cho_cau_nho": ((82, -66), 18, 13, "Phố Bờ Me"),
    "hem_dua": ((45, -58), 5.5, 8, "Ngõ Dừa"),
    "cau_tre": ((112, -142), 9, 9, "Phố Bên Kia Rạch"),
    "ben_xe_6": ((-160, -76), 7, 3, "Phố Bờ Me"),
    "nha_di_nam": ((-166, 8), 7, 10, "Phố An Hòa"),
}


def _lot_for(at, w, d, along_x):
    """Lô dọn sẵn quanh chỗ đặt địa điểm (at là giữa nhà): bề ngang dọc theo phố, nới 1 m mỗi bên để chừa lối."""
    x, z = at
    hx, hz = (w / 2 + 1.0, d / 2 + 1.5) if along_x else (d / 2 + 1.5, w / 2 + 1.0)
    return [(x - hx, z - hz), (x + hx, z - hz), (x + hx, z + hz), (x - hx, z + hz)]


def main():
    for k, (at, w, d, road_name) in LOCATIONS.items():
        if k == "ben_xe_6":
            continue
        LOTS[k] = _lot_for(at, w, d, road_name != "Ngõ Dừa")
    build()
    data = {
        "buildings": [{k: v for k, v in b.items() if not k.startswith("_")} for b in buildings],
        "parks": parks if not parks else [{"k": p["k"], "n": p["n"], "p": [round(c, 2) for q in p["p"] for c in q]} for p in parks],
        "pois": [],
        "rails": rails,
        "roads": [{k: v for k, v in r.items() if not k.startswith("_")} for r in roads],
        "stats": {"hand": len(buildings)},
        "tree_rows": [],
        "trees": [c for p in trees for c in p],
        "walls": walls,
        "water": [{"n": "Rạch Bờ Me" if i == 0 else "Hồ An Hòa", "p": [round(c, 2) for p in w for c in p]} for i, w in enumerate(water)],
        "waterways": waterways,
    }
    clip = [X0, Z0, X1, Z0, X1, Z1, X0, Z1]
    out = {"baked": "dựng tay", "bbox": [21.0255, 105.8424, 21.0287, 105.8466], "center": [21.0271, 105.8445],
           "clip": clip, "data": data, "id": MAP_ID, "name": "Phường An Hòa (dựng tay, kiểu phố Hà Nội)",
           "sources": "Dựng tay, không lấy dữ liệu bản đồ thật"}
    path = os.path.join(ROOT, "data", "maps", MAP_ID + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    names = sorted({r["n"] for r in roads if r["n"]})
    print("nhà:", len(buildings), "đường:", len(roads), "cây:", len(trees), "->", path)
    print("tên phố:", ", ".join(names))
    write_story(names)


def write_story(names):
    locs = {}
    for k, (at, w, d, road_name) in LOCATIONS.items():
        locs[k] = {"at": list(at), "w": w, "d": d, "road": road_name}
        if k == "ben_xe_6":
            # Mái chờ xe đứng trên vỉa hè, không lùi vào thẳng hàng nhà.
            locs[k]["inset"] = 0.0
    story = {
        "_ghi_chu": "Đặt truyện lên map dựng tay kiểu phố Hà Nội (data/maps/hn_an_hoa.json, sinh bằng "
                    "tools/gen_hanoi_map.py). locations: at là giữa nhà của địa điểm, road là phố nó quay mặt ra, inset "
                    "là khoảng lùi khỏi mép đường (mặc định bằng vỉa hè của phố đó). names: tên phố giữ nguyên.",
        "map": MAP_ID,
        "displayName": "Phường An Hòa",
        "walkHoursPerMeter": 0.0018,
        "locations": locs,
        "names": {n: n for n in names},
        "fallbackNames": ["Phố Xóm Mới"],
        "descriptions": {
            "ben_xe_6": "Điểm đón xe đưa rước công nhân trên vỉa hè phố Bờ Me, gần đầu phố đường tàu. Xe chạy ra khu công nghiệp; trung tâm nghề của Linh cũng đi xe ở đây.",
            "cho_cau_nho": "Chợ ở góc phố Bờ Me và phố Chợ Cầu Nhỏ, ngay chân Cầu Nhỏ bắc qua rạch: sạp vật tư, hàng đồ cũ, tiệm photo, sạp ve chai của cô Út và quán trà đá có bảng tin cho thuê phòng.",
            "com_hanh": "Quán cơm bình dân cho người làm ca trên phố Bờ Me, cạnh đầu ngõ vào xóm trọ. Nhận ca phụ, giao cơm, nghe chuyện dãy quán cần sửa điện.",
            "tiem_sau": "Tiệm sửa xe ngay đầu ngõ Bờ Me, cách xóm trọ vài bước, có thêm một bàn sửa đồ gia dụng.",
            "xom_bo_me": "Tám phòng quanh khoảng sân cuối ngõ Bờ Me, sau lưng là rạch; vòi nước chung, dây phơi dưới mái tôn. Về đây để nghỉ và đi ngủ.",
            "hem_dua": "Phòng trong ngõ Dừa rẽ ra từ phố Bờ Me, sát chân Cầu Nhỏ, đầu ngõ có cây dừa, cách chợ vài bước. Phòng nhỏ, cửa sát mặt ngõ, ít chỗ phơi.",
            "cau_tre": "Bên kia rạch, phải đi vòng qua Cầu Nhỏ. Dãy nhà trên phố Bên Kia Rạch, lưng quay ra kênh; phòng thoáng, có hiên rộng, đi làm xa hơn.",
            "nha_di_nam": "Nhà dì Năm trên phố An Hòa, gần phố đường tàu và điểm đón xe. Ở tạm được bảy ngày, phải gửi bớt đồ.",
            "ben_can": "Năm quán ven rạch trên phố Bờ Me, gần chân Cầu Nhỏ, lưng quay ra kênh, chung lối đi và đường điện cũ. Hợp đồng của anh Phúc.",
        },
        "questAreas": {"meo_be_bap": {"around": "cho_cau_nho", "radius": 70}},
        "vendorRoutes": {
            "banh_mi": [[-170, -76], [-40, -76], [55, -76], [55, 16], [-40, 16], [-170, 16], [-170, -76]],
            "xoi": [[-120, 24], [-120, 150], [-104, 144], [-104, 52], [-40, 46], [-40, 24], [-120, 24]],
            "ve_chai": [[-120, -30], [56, -30], [146, -30], [150, -76], [60, -76], [-60, -84], [-120, -30]],
            "che": [[-40, 46], [24, 52], [24, 138], [-104, 138], [-104, 52], [-40, 46]],
            "hu_tieu": [[55, 24], [55, 140], [150, 146], [150, 62], [58, 62], [55, 24]],
        },
    }
    path = os.path.join(ROOT, "data", "maps", MAP_ID + "_story.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(story, f, ensure_ascii=False, indent=1)
    print("->", path)


if __name__ == "__main__":
    main()
