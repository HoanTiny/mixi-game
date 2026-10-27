#!/usr/bin/env python3
"""Dựng tay map phố cổ Hà Nội cho truyện (8 khu, tên thật, nén lại cho đi bộ vài phút là tới), ghi ra
data/maps/hn_pho_co.json (định dạng map nướng sẵn) và data/maps/hn_pho_co_story.json (chỗ đặt địa điểm, công trình
mốc). Dùng lại các hàm dựng phố, dãy nhà ống của tools/gen_hanoi_map.py.

Tám khu, từ bắc xuống nam (x hướng đông, z hướng nam, đơn vị mét):
1. [Bắc] Cầu Long Biên và chợ Long Biên: chân cầu ngoài đê, chợ đầu mối, điểm xe buýt trên đê.
2. [Đông Bắc] Bãi Phúc Tân ngoài đê: ngõ nhỏ, nhà thấp, xóm trọ, vựa đồng nát, bãi sông.
3. [Tây Bắc] Vòm cầu đường sắt Phùng Hưng: cầu cạn gạch chạy ngang phía bắc, tiệm sửa xe, xưởng hàn trong vòm.
4. [Trung tâm Bắc] Chợ Đồng Xuân và ngõ chợ: chợ lớn, ngõ ăn uống (quán cơm Hạnh), phố Hàng Chiếu.
5. [Tây Trung] Mê cung ngõ phố cổ: Hàng Đào, Hàng Buồm, Hàng Bạc, Đinh Liệt, ngõ Gạch; nhà ống cao hẹp.
6. [Đông Trung] Phố đêm Tạ Hiện: dãy quán bia vỉa hè, Lương Ngọc Quyến, Mã Mây.
7. [Trung tâm Nam] Quảng trường Đông Kinh Nghĩa Thục, vòng xuyến, Hồ Gươm (Tháp Rùa, đền Ngọc Sơn, cầu Thê Húc).
8. [Nam] Tràng Tiền Plaza và khu phố Pháp: Lý Thái Tổ, biệt thự, ngân hàng, tòa văn phòng, chung cư cao cấp.
Sông Hồng chạy dọc mép đông; bên kia sông là Ngọc Thụy.
Chạy: python3 tools/gen_phocu_map.py
"""
import json
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_hanoi_map as g  # noqa: E402

MAP_ID = "hn_pho_co"
g.X0, g.X1, g.Z0, g.Z1 = -240.0, 262.0, -252.0, 295.0
g.rng = random.Random(1010)
rng = g.rng

VILLA_WALLS = ["f0c75e", "eed28f", "f3e6c4", "e9b44c", "f2d27c"]
VIADUCT = "8f4d38"


def style_for(zone):
    return {
        "pho": ((3.4, 5.2), (3, 5), 0.08),
        "pho_co": ((3.0, 4.6), (2, 4), 0.3),
        "pho_nho": ((3.6, 5.6), (2, 4), 0.15),
        "ngo": ((3.8, 6.5), (2, 4), 0.25),
        "phuc_tan": ((4.0, 6.5), (1, 3), 0.35),
        "ven_ho": ((4.5, 7.5), (3, 6), 0.05),
        "phap": ((8.0, 12.0), (2, 4), 0.0),
        "bo_kia": ((4.5, 8.0), (1, 3), 0.35),
        "duong_tau": ((3.4, 5.0), (2, 4), 0.25),
    }[zone]


g.style_for = style_for


def rect(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


LANDMARKS = []


def build():
    X0, X1, Z0, Z1 = g.X0, g.X1, g.Z0, g.Z1
    # --- Sông Hồng dọc mép đông, bãi sông cỏ, bên kia là Ngọc Thụy.
    # Bờ sông uốn lượn tự nhiên; bờ Phúc Tân có dải bãi bồi cát vàng, rộng hẹp theo khúc sông.
    def west(z):
        return 192 + 3.2 * math.sin(z / 46.0) + 1.6 * math.sin(z / 17.0 + 0.7)

    def east(z):
        return 236 + 2.4 * math.sin(z / 52.0 + 1.3) + 1.2 * math.sin(z / 21.0)
    zs = [Z0 + (Z1 - Z0) * i / 60.0 for i in range(61)]
    river = [(round(west(z), 2), round(z, 2)) for z in zs] + [(round(east(z), 2), round(z, 2)) for z in reversed(zs)]
    g.water.append(river)
    g.waterways.append({"k": "river", "l": [214, Z0, 214, Z1], "n": "Sông Hồng", "w": 44.0})
    bai = [(185.0, z) for z in (Z0, Z1)] + [(round(west(z), 2), round(z, 2)) for z in reversed(zs)]
    bai = [bai[0]] + bai[2:] + [bai[1]]
    g.parks.append({"k": "sand", "n": "Bãi bồi sông Hồng", "p": bai})
    g.reserved.append(rect(184, Z0, 190, Z1))
    z = Z0 + 8
    while z < Z1 - 6:
        if abs(z + 200) > 10:
            g.trees.append((round(186.5 + rng.uniform(-1, 1), 1), round(z, 1)))
        z += rng.uniform(10, 15)

    # --- Hồ Gươm, đường dạo ven hồ, Tháp Rùa, đền Ngọc Sơn.
    lake = g.ellipse(-60, 166, 46, 66, n=40, wobble=0.04, seed=11)
    g.water.append(lake)
    promenade = rect(-119.5, 84, -1.5, 248.5)
    g.parks.append({"k": "park", "n": "Vườn hoa Hồ Gươm", "p": promenade})
    g.reserved.append(promenade)
    for p in g.ellipse(-60, 166, 53, 74, n=34, seed=5):
        g.trees.append((round(p[0], 1), round(p[1], 1)))
    # Tháp Rùa trên gò giữa hồ (nền đá thấp; tháp dựng ở công trình mốc), đền Ngọc Sơn trên đảo phía đông bắc.
    g.house(g.ellipse(-62, 188, 5.5, 4.2, n=14), 0.6, "8e8a7e", name="Gò Rùa", kind="islet")
    LANDMARKS.append({"kind": "thap_rua", "pos": [-62, 188]})
    g.house(g.ellipse(-28, 118, 8, 6, n=16), 0.6, "8e8a7e", name="Đảo Ngọc", kind="islet")
    g.house(rect(-33, 114, -23, 122), 5.0, "d9b56b", name="Đền Ngọc Sơn", roof="hipped", roof_colour="6e2f22",
            kind="temple", worship=True, roof_h=2.6)
    LANDMARKS.append({"kind": "red_bridge", "a": [-3, 112], "b": [-21, 116]})

    # --- Quảng trường Đông Kinh Nghĩa Thục: sân lát đá, vòng xuyến.
    square = rect(-112, 46, -8, 82)
    g.parks.append({"k": "square", "n": "Quảng trường Đông Kinh Nghĩa Thục", "p": square})
    g.reserved.append(square)

    # --- Đường. Phố lớn trước (dãy nhà bám phố lớn trước).
    de = g.road("Phố Trần Nhật Duật", [(120, Z0), (120, Z1)], 10.0, "primary", sw=3.0)
    hang_chieu = g.road("Phố Hàng Chiếu", [(-225, -130), (115, -130)], 7.0, "tertiary", sw=3.0)
    gam_cau = g.road("Phố Gầm Cầu", [(-225, -188), (115, -188)], 6.0, "residential", sw=2.5)
    hang_dau = g.road("Phố Hàng Đậu", [(-225, -236), (115, -236)], 6.0, "residential", sw=2.0)
    phung_hung = g.road("Phố Phùng Hưng", [(-225, Z0), (-225, 40)], 8.0, "secondary", sw=3.0)
    hang_buom = g.road("Phố Hàng Buồm", [(-225, -75), (115, -75)], 6.0, "residential", sw=2.0)
    hang_bac = g.road("Phố Hàng Bạc", [(-225, -20), (115, -20)], 6.0, "residential", sw=2.0)
    cau_go = g.road("Phố Cầu Gỗ", [(-225, 40), (115, 40)], 7.0, "tertiary", sw=3.0)
    hang_dao = g.road("Phố Hàng Đào", [(-120, -130), (-120, 40)], 6.0, "residential", sw=2.0)
    ma_may = g.road("Phố Mã Mây", [(0, -130), (0, -20)], 5.0, "residential", sw=1.5)
    ta_hien = g.road("Phố Tạ Hiện", [(60, -75), (60, -20)], 5.0, "residential", sw=2.5)
    lnq = g.road("Phố Lương Ngọc Quyến", [(0, -62), (115, -62)], 5.0, "residential", sw=1.5)
    dinh_liet = g.road("Phố Đinh Liệt", [(-60, -20), (-60, 40)], 5.0, "residential", sw=1.5)
    le_thai_to = g.road("Phố Lê Thái Tổ", [(-125, 40), (-125, Z1)], 7.0, "tertiary", sw=3.0)
    dinh_tien_hoang = g.road("Phố Đinh Tiên Hoàng", [(5, 40), (5, 255)], 7.0, "tertiary", sw=3.0)
    # Đáy hồ: phố Hàng Khay chạy dưới hồ, sang tới Đinh Tiên Hoàng thì thành phố Tràng Tiền.
    hang_khay = g.road("Phố Hàng Khay", [(-225, 255), (5, 255)], 8.0, "secondary", sw=3.0)
    trang_tien = g.road("Phố Tràng Tiền", [(5, 255), (115, 255)], 8.0, "secondary", sw=3.0)
    ly_thai_to = g.road("Phố Lý Thái Tổ", [(60, 40), (60, Z1)], 7.0, "tertiary", sw=3.5)
    vong_xuyen = g.ellipse(-60, 64, 13, 13, n=24)
    vong_xuyen.append(vong_xuyen[0])
    vx = g.road("Vòng xuyến Đông Kinh Nghĩa Thục", vong_xuyen, 7.0, "tertiary", sw=0.0)
    g.road("Vòng xuyến Đông Kinh Nghĩa Thục", [(-60, 40), (-60, 51)], 7.0, "tertiary", sw=0.0)
    g.road("Vòng xuyến Đông Kinh Nghĩa Thục", [(-60, 77), (-60, 84)], 5.0, "pedestrian", small=True)
    # Cầu Long Biên: đoạn đất qua bãi sông (chân cầu, chợ), nhịp qua sông, chân cầu bên Ngọc Thụy.
    long_bien = g.road("Cầu Long Biên", [(120, -200), (182, -200)], 6.0, "secondary", sw=1.5)
    g.road("Cầu Long Biên", [(182, -200), (246, -200)], 6.0, "secondary", bridge=True)
    g.road("Cầu Long Biên", [(246, -200), (252, -200)], 6.0, "secondary")
    LANDMARKS.append({"kind": "truss", "a": [184, -200], "b": [244, -200], "w": 9.0, "h": 9.0, "spans": 2})
    ngoc_thuy = g.road("Phố Ngọc Thụy", [(252, Z0), (252, -60)], 4.0, "residential", small=True)
    # Bãi Phúc Tân ngoài đê.
    phuc_tan = g.road("Phố Phúc Tân", [(150, -176), (150, 80)], 4.0, "service", small=True)
    ngo_pt = []
    for z, so in ((-140, 25), (-95, 51), (-50, 79), (0, 105), (50, 131)):
        ngo_pt.append(g.road("Ngõ %d Phúc Tân" % so, [(128, z), (184, z)], 3.0, "service", small=True))
    # Ngõ trong phố cổ.
    ngo_dx = g.road("Ngõ Chợ Đồng Xuân", [(20, -188), (20, -130)], 3.0, "service", small=True)
    ngo_gach = g.road("Ngõ Gạch", [(-170, -75), (-170, -20)], 2.6, "service", small=True)
    ngo_hb = g.road("Ngõ Hàng Bạc", [(-225, -48), (-120, -48)], 2.6, "service", small=True)
    ngo_hd = g.road("Ngõ Hàng Đào", [(-90, -130), (-90, -75)], 2.8, "service", small=True)
    ngo_mm = g.road("Ngõ Mã Mây", [(-60, -75), (-60, -20)], 2.8, "service", small=True)
    ngo_lnq = g.road("Ngõ Lương Ngọc Quyến", [(90, -75), (90, -20)], 2.8, "service", small=True)
    ngo_cg = g.road("Ngõ Cầu Gỗ", [(-225, 5), (-120, 5)], 2.6, "service", small=True)
    ngo_lt = g.road("Ngõ Lê Thái Tổ", [(-225, 120), (-125, 120)], 3.0, "service", small=True)
    g.road("Đường dạo Hồ Gươm", [(-100, 96), (-20, 96)], 3.0, "pedestrian", small=True)
    ngo_lt2 = g.road("Ngõ Lê Thái Tổ", [(-225, 190), (-125, 190)], 3.0, "service", small=True)

    # --- Lô địa điểm của truyện (dọn trước).
    for k, (at, w, d, road_name, along_x) in LOCATIONS.items():
        if k in ("ben_xe_6", "bai_boc_vac", "ho_guom"):
            continue
        g.LOTS[k] = g._lot_for(at, w, d, along_x)
        g.reserved.append(g.LOTS[k])

    # --- Cầu cạn đường sắt (vòm cầu Phùng Hưng, Gầm Cầu): mỗi vòm một khối gạch 6 m, trong vòm là tiệm, xưởng;
    # chừa chỗ tiệm chú Sơn.
    x = -238.0
    while x < 112.0:
        x1 = min(x + 6.0, 112.0)
        poly = rect(x, -212, x1, -198)
        if not any(g.poly_hits(poly, lambda p, q=q: g.in_poly(p, q)) for q in g.LOTS.values()):
            g.house(poly, 7.4, VIADUCT, name="Vòm cầu", kind="viaduct")
        x = x1 + 0.0
    g.reserved.append(rect(-240, -213, 113, -197))
    LANDMARKS.append({"kind": "viaduct_top", "a": [-240, -205], "b": [113, -205], "y": 7.4, "w": 14.0})
    LANDMARKS.append({"kind": "arches", "a": [-240, -197.9], "b": [113, -197.9], "h": 5.2, "step": 6.0})

    # --- Công trình lớn.
    dong_xuan = rect(-80, -182, 8, -142)
    g.house(dong_xuan, 13.5, "c9b48f", name="Chợ Đồng Xuân", kind="market")
    g.reserved.append(rect(-82, -184, 10, -140))
    LANDMARKS.append({"kind": "gables", "a": [-80, -141.9], "b": [8, -141.9], "n": 3, "h": 13.5, "col": "d8c39b"})
    plaza = rect(12, 264, 108, 293)
    g.house(plaza, 22.0, "efe9de", name="Tràng Tiền Plaza", kind="retail")
    g.reserved.append(rect(10, 262, 110, 295))
    g.house(rect(72, 52, 104, 84), 18.0, "e7dcc4", name="Ngân hàng", kind="bank")
    g.house(rect(74, 140, 106, 176), 58.0, "d6dbe0", name="Chung cư cao cấp", kind="apartments")
    g.house(rect(74, 200, 106, 232), 44.0, "5d7389", name="Tòa văn phòng", kind="office")
    for q in (rect(70, 50, 106, 86), rect(72, 138, 108, 178), rect(72, 198, 108, 234)):
        g.reserved.append(q)
    # Vựa đồng nát Phúc Tân: bãi rào tôn.
    vua = rect(158, -42, 178, -26)
    g.walls.append({"h": 2.0, "k": "fence", "l": [158, -42, 178, -42, 178, -26, 158, -26]})
    g.reserved.append(vua)
    g.house(rect(130, -34, 136, -28), 3.0, "b9c8b5", name="Nhà vệ sinh công cộng", kind="toilets")
    # Chợ Long Biên: mái tôn rộng (địa điểm dựng trong game); bãi xe tải nông sản cạnh chợ.
    truck_yard = rect(126, -180, 146, -150)
    g.parks.append({"k": "parking", "n": "Bãi xe tải nông sản", "p": truck_yard})
    g.reserved.append(truck_yard)

    # Biệt thự phố Pháp dọc Lý Thái Tổ, Đinh Tiên Hoàng: lùi vào sau vườn trước, mái ngói dốc bốn mái.
    for xr, side in ((60, -1), (60, 1), (5, 1)):
        z = 50.0
        while z < 246:
            w = rng.uniform(11, 15)
            d = rng.uniform(10, 13)
            front = xr + side * (3.5 + 3.5 + 4.0)
            back = front + side * d
            poly = rect(min(front, back), z, max(front, back), z + w)
            if not g.poly_hits(poly, lambda p: g.blocked(p)) and not g.overlaps_house(poly):
                g.house(poly, rng.choice([7.4, 10.6, 10.6]), rng.choice(VILLA_WALLS), roof="hipped",
                        roof_colour=rng.choice(g.TILES), roof_h=3.0, kind="villa")
                g.trees.append((round(front - side * 2.0, 1), round(z + w / 2, 1)))
            z += w + rng.uniform(4, 8)

    # --- Dãy nhà ống theo thứ tự ưu tiên.
    for r, zone, dmax in ((hang_chieu, "pho", 20), (hang_buom, "pho_co", 20), (hang_bac, "pho_co", 20),
                          (cau_go, "pho", 18), (gam_cau, "pho", 14), (hang_dau, "pho", 14), (trang_tien, "pho", 18), (hang_khay, "pho", 18)):
        g.row(r, +1, zone, dmax=dmax)
        g.row(r, -1, zone, dmax=dmax)
    g.row(de, -1, "pho", dmax=18)
    g.row(de, +1, "phuc_tan", dmax=12)
    g.row(phung_hung, -1, "pho", dmax=18)
    for r in (hang_dao, ma_may, ta_hien, lnq, dinh_liet):
        g.row(r, +1, "pho_co", dmax=18)
        g.row(r, -1, "pho_co", dmax=18)
    for r in (le_thai_to, dinh_tien_hoang, ly_thai_to):
        g.row(r, +1, "ven_ho", dmax=16)
        g.row(r, -1, "ven_ho", dmax=16)
    g.row(phuc_tan, +1, "phuc_tan", dmax=14, dmin=4.0)
    g.row(phuc_tan, -1, "phuc_tan", dmax=14, dmin=4.0)
    for r in ngo_pt:
        g.row(r, +1, "phuc_tan", dmax=14, dmin=4.0)
        g.row(r, -1, "phuc_tan", dmax=14, dmin=4.0)
    for r in (ngo_dx, ngo_gach, ngo_hb, ngo_hd, ngo_mm, ngo_lnq, ngo_cg, ngo_lt, ngo_lt2):
        g.row(r, +1, "ngo", dmax=18, dmin=4.0)
        g.row(r, -1, "ngo", dmax=18, dmin=4.0)
    g.row(ngoc_thuy, -1, "bo_kia", dmax=10, dmin=4.0)
    g.row(ngoc_thuy, +1, "bo_kia", dmax=8, dmin=4.0)
    g.row(long_bien, +1, "phuc_tan", dmax=10, dmin=4.0)

    # --- Cây sấu, cây bàng dọc vỉa hè phố lớn.
    for r in (hang_chieu, cau_go, trang_tien, hang_khay, de, ly_thai_to, le_thai_to, dinh_tien_hoang):
        pts = r["_pts"]
        a, b = pts[0], pts[-1]
        horiz = abs(b[0] - a[0]) > abs(b[1] - a[1])
        off = r["w"] / 2.0 + r["sw"] * 0.55
        t = 8.0
        L = g.length(g.sub(b, a))
        while t < L - 6:
            c = g.add(a, g.mul(g.norm(g.sub(b, a)), t))
            for side in (-1, 1):
                p = (round(c[0], 1), round(c[1] + side * off, 1)) if horiz else (round(c[0] + side * off, 1), round(c[1], 1))
                if not g.in_corridor(p, pad=1.0, skip=r) and not any(g.in_poly(p, q) for q in g.LOTS.values()):
                    g.trees.append(p)
            t += rng.uniform(13, 17)

    # --- Chữ lớn của các khu (hiện khi tới gần).
    for text, pos, y in (("CẦU LONG BIÊN", (214, -200), 13), ("CHỢ LONG BIÊN", (155, -192), 9),
                         ("BÃI PHÚC TÂN", (160, -70), 10), ("VÒM CẦU PHÙNG HƯNG", (-160, -205), 11),
                         ("CHỢ ĐỒNG XUÂN", (-36, -142), 17), ("PHỐ TẠ HIỆN", (60, -48), 9),
                         ("PHỐ HÀNG BẠC", (-140, -20), 9), ("QUẢNG TRƯỜNG ĐÔNG KINH NGHĨA THỤC", (-60, 64), 9),
                         ("HỒ HOÀN KIẾM", (-60, 140), 8), ("THÁP RÙA", (-62, 188), 12),
                         ("ĐỀN NGỌC SƠN", (-28, 118), 10), ("TRÀNG TIỀN PLAZA", (60, 262), 25),
                         ("PHỐ PHÁP", (60, 150), 9), ("NGỌC THỤY", (250, -120), 8)):
        LANDMARKS.append({"kind": "label", "text": text, "pos": list(pos), "y": y})


# id: (giữa nhà, bề ngang, chiều sâu, phố quay mặt ra, bề ngang dọc theo trục x?)
LOCATIONS = {
    "xom_bo_me": ((170, -133), 13, 10, "Ngõ 25 Phúc Tân", True),
    "cho_cau_nho": ((155, -190), 26, 14, "Cầu Long Biên", True),
    "ben_xe_6": ((113, -175), 7, 3, "Phố Trần Nhật Duật", False),
    "tiem_sau": ((71, -199), 9, 11, "Phố Gầm Cầu", True),
    "com_hanh": ((97, -142), 8, 11, "Phố Hàng Chiếu", True),
    "nha_di_nam": ((80, -142), 7, 10, "Phố Hàng Chiếu", True),
    "hem_dua": ((-164, -48), 5.5, 8, "Ngõ Gạch", False),
    "ben_can": ((70, -40), 24, 10, "Phố Tạ Hiện", False),
    "cau_tre": ((245, -150), 9, 9, "Phố Ngọc Thụy", False),
    # Giai đoạn 4: chỗ làm, dịch vụ, chỗ chơi mới.
    "bai_boc_vac": ((131, -165), 8, 6, "Phố Trần Nhật Duật", False),
    "xe_tho": ((-100, -138.5), 6, 4, "Phố Hàng Chiếu", True),
    "nha_tro_giuong": ((166, -57), 12, 10, "Ngõ 79 Phúc Tân", True),
    "quan_net": ((-100, -30), 6, 10, "Phố Hàng Bạc", True),
    "cam_do": ((-175.5, -62), 5, 8, "Ngõ Gạch", False),
    "ve_so": ((7, -100), 4, 6, "Phố Mã Mây", False),
    "ho_guom": ((-60, 92.5), 8, 3, "Đường dạo Hồ Gươm", True),
    # Đời sống phố: shop si-đa túi mù, quán bi-a.
    "shop_ao": ((-111, -100), 6, 8, "Phố Hàng Đào", False),
    "bi_a": ((30, -53.5), 8, 9, "Phố Lương Ngọc Quyến", True),
}
## Địa điểm không dựng nhà (mái che, ghế đá): sát mép đường, không lùi.
NO_INSET = ("ben_xe_6", "bai_boc_vac", "xe_tho", "ho_guom")

DESCRIPTIONS = {
    "ben_xe_6": "Điểm xe buýt Long Biên trên đê Trần Nhật Duật, sát chân cầu: xe đưa rước công nhân ra khu công nghiệp Bắc Thăng Long đón ở đây. Trung tâm nghề của Linh cũng đi xe ở đây.",
    "cho_cau_nho": "Chợ Long Biên dưới chân cầu Long Biên, ngoài đê: chợ đầu mối rau quả, xe tải nông sản về từ nửa đêm, sạp vật tư, hàng đồ cũ, sạp đồng nát của cô Thắm và quán trà đá có bảng tin cho thuê phòng.",
    "com_hanh": "Quán cơm bình dân của chị Hạnh ở cuối phố Hàng Chiếu, sau lưng chợ Đồng Xuân, cho người làm ca, người kéo xe thồ, shipper. Nhận ca phụ, giao cơm, nghe chuyện dãy quán cần sửa điện.",
    "tiem_sau": "Tiệm chú Sơn trong một vòm cầu đường sắt bên phố Gầm Cầu: sửa xe máy, thêm một bàn sửa đồ điện gia dụng. Tàu chạy qua trên đầu thì cả tiệm rung.",
    "xom_bo_me": "Tám phòng trọ quanh khoảng sân trong ngõ 25 Phúc Tân, ngoài đê, sau lưng là bãi sông Hồng; vòi nước chung, dây phơi dưới mái tôn. Về đây để nghỉ và đi ngủ.",
    "hem_dua": "Gác xép trong ngõ Gạch rẽ ra từ phố Hàng Buồm, đầu ngõ có cây bàng, quanh là quán net, tiệm cầm đồ. Phòng nhỏ, trần thấp, cửa sát mặt ngõ, ít chỗ phơi.",
    "bai_boc_vac": "Bãi xe tải nông sản sát chợ Long Biên: tối nào xe rau, xe quả từ các tỉnh cũng về, cần người bốc dỡ xuống chợ đầu mối, trả công theo ca.",
    "xe_tho": "Điểm thuê xe thồ đầu phố Hàng Chiếu, sau lưng chợ Đồng Xuân: kéo hàng từ kho ra các sạp trong chợ, trả theo chuyến.",
    "nha_tro_giuong": "Nhà trọ giường tầng trong ngõ 79 Phúc Tân, 30.000đ một đêm: phòng chung mười hai giường, quạt trần, tủ khóa nhỏ, người làm thuê ngủ lại qua đêm.",
    "quan_net": "Quán net phố Hàng Bạc mở thâu đêm: lên mạng tìm việc, đọc tin, chơi một ván, hay gục xuống bàn ngủ qua đêm cho rẻ.",
    "cam_do": "Tiệm cầm đồ trong ngõ Gạch: cầm đồ lấy tiền ngay, hẹn mười ngày chuộc, có lãi.",
    "ve_so": "Đại lý vé số đầu phố Mã Mây: vé 10.000đ một tờ, chiều mở thưởng.",
    "shop_ao": "Shop quần áo si-đa của chị Vy trên phố Hàng Đào: hàng thùng về từ cửa khẩu, bán lẻ, bán túi mù 99.000đ, bóc ra gì mặc nấy.",
    "bi_a": "Quán bi-a của anh Dũng trên phố Lương Ngọc Quyến: sáu bàn lỗ, quạt trần, tiếng bi chạm nhau lách cách tới khuya; tối thứ Bảy có giải.",
    "ho_guom": "Dãy ghế đá ven hồ Gươm, đầu đường dạo phía Đông Kinh Nghĩa Thục: sáng sớm các cụ tập dưỡng sinh, ngày nào cũng có mấy bàn cờ tướng, tối người ngồi hóng gió, có người ngủ lại.",
    "cau_tre": "Bên kia sông, phải đi qua cầu Long Biên. Dãy nhà trên phố Ngọc Thụy, lưng quay ra sông; phòng thoáng, có hiên rộng, đi làm xa hơn.",
    "nha_di_nam": "Nhà dì Nga trên phố Hàng Chiếu, gần chợ Đồng Xuân và điểm xe buýt. Ở tạm được bảy ngày, phải gửi bớt đồ.",
    "ben_can": "Dãy năm quán bia hơi vỉa hè phố Tạ Hiện, chung lối đi và đường điện cũ chằng chịt. Hợp đồng sửa điện của anh Phúc.",
}


def main():
    for k, (at, w, d, road_name, along_x) in LOCATIONS.items():
        pass
    build()
    data = {
        "buildings": [{k: v for k, v in b.items() if not k.startswith("_")} for b in g.buildings],
        "parks": [{"k": p["k"], "n": p["n"], "p": [round(c, 2) for q in p["p"] for c in q]} for p in g.parks],
        "pois": [],
        "rails": [],
        "roads": [{k: v for k, v in r.items() if not k.startswith("_")} for r in g.roads],
        "stats": {"hand": len(g.buildings)},
        "tree_rows": [],
        "trees": [c for p in g.trees for c in p],
        "walls": g.walls,
        "water": [{"n": "Sông Hồng" if i == 0 else "Hồ Hoàn Kiếm", "p": [round(c, 2) for p in w for c in p]}
                  for i, w in enumerate(g.water)],
        "waterways": g.waterways,
    }
    out = {"baked": "dựng tay", "bbox": [21.026, 105.846, 21.04, 105.858], "center": [21.0333, 105.8520],
           "clip": [g.X0, g.Z0, g.X1, g.Z0, g.X1, g.Z1, g.X0, g.Z1], "data": data, "id": MAP_ID,
           "name": "Phố cổ Hà Nội (dựng tay, nén gọn)", "sources": "Dựng tay theo địa danh thật, không lấy dữ liệu bản đồ"}
    path = os.path.join(g.ROOT, "data", "maps", MAP_ID + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    names = sorted({r["n"] for r in g.roads if r["n"]})
    locs = {}
    for k, (at, w, d, road_name, along_x) in LOCATIONS.items():
        locs[k] = {"at": list(at), "w": w, "d": d, "road": road_name}
        if k in NO_INSET:
            locs[k]["inset"] = 0.0
    story = {
        "_ghi_chu": "Đặt truyện lên map phố cổ dựng tay (data/maps/hn_pho_co.json, sinh bằng tools/gen_phocu_map.py). "
                    "locations: at là giữa nhà, road là phố quay mặt ra, inset là khoảng lùi khỏi mép đường. landmarks: "
                    "công trình mốc dựng thêm trên màn phố (scripts/world/landmarks.gd).",
        "map": MAP_ID,
        "displayName": "Phố cổ Hà Nội",
        "walkHoursPerMeter": 0.001,
        "locations": locs,
        "names": {n: n for n in names},
        "fallbackNames": ["Phố cổ"],
        "descriptions": DESCRIPTIONS,
        "landmarks": LANDMARKS,
        "questAreas": {"meo_be_bap": {"around": "cho_cau_nho", "radius": 80}},
        "vendorRoutes": {
            "banh_mi": [[115, -84], [115, 30], [10, 36], [-115, 36], [-115, -126], [115, -126], [115, -84]],
            "xoi": [[150, -170], [150, 70], [150, -170]],
            "ve_chai": [[124, -140], [180, -140], [180, 0], [124, 0], [124, -140]],
            "che": [[-120, 44], [0, 44], [0, 250], [-120, 250], [-120, 44]],
            "hu_tieu": [[60, -24], [60, -72], [-120, -72], [-120, -24], [60, -24]],
            "kem": [[5, 44], [5, 250], [60, 250], [60, 44], [5, 44]],
            "hoa_qua": [[126, -125], [126, -60], [150, -60], [150, -125], [126, -125]],
            "hoa": [[-115, -24], [0, -24], [0, -71], [-115, -71], [-115, -24]],
            "bong_bay": [[-100, 44], [-20, 44], [-20, 96], [-100, 96], [-100, 44]],
            "banh_ran": [[-60, -71], [60, -71], [60, -24], [-60, -24], [-60, -71]],
        },
    }
    with open(os.path.join(g.ROOT, "data", "maps", MAP_ID + "_story.json"), "w", encoding="utf-8") as f:
        json.dump(story, f, ensure_ascii=False, indent=1)
    print("nhà:", len(g.buildings), "đường:", len(g.roads), "cây:", len(g.trees), "->", path)
    print("phố:", ", ".join(names))


if __name__ == "__main__":
    main()
