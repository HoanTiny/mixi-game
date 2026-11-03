#!/usr/bin/env python3
"""Author compact Hanoi: real-scale buildings, short daily loops and distinct destination pockets."""
import json
import math
import os
import random
import gen_hanoi_map as g

MAP_ID = "hn_pho_co"
LAYOUT_VERSION = 2
g.X0, g.X1, g.Z0, g.Z1 = -70.0, 174.0, -65.0, 145.0
g.rng = random.Random(1010)
LANDMARKS = []


def style_for(zone):
    return {"pho": ((3.8, 5.8), (2, 3), 0.25), "ngo": ((4.0, 6.2), (1, 2), 0.35),
            "phuc_tan": ((4.0, 6.5), (1, 2), 0.35), "ven_ho": ((5.0, 7.5), (2, 3), 0.20),
            "bo_kia": ((4.5, 7.0), (1, 2), 0.45)}[zone]


g.style_for = style_for


def rect(x0, z0, x1, z1):
    return [(x0, z0), (x1, z0), (x1, z1), (x0, z1)]


# Centre of reserved lot, frontage width, depth, facing road, along x.
# RealCity derives exact doors; dimensions retain the existing human/building scale.
LOCATIONS = {
    "xom_bo_me": ((-8, 16), 13, 10, "Ngõ 25 Phúc Tân", True),
    "tiem_sau": ((-8, -10.8), 9, 11, "Phố Hàng Chiếu", True),
    "cho_cau_nho": ((16, -12.3), 26, 14, "Phố Hàng Chiếu", True),
    "com_hanh": ((16, 15.5), 8, 11, "Ngõ 25 Phúc Tân", True),
    "nha_di_nam": ((-31, 16), 7, 10, "Ngõ 25 Phúc Tân", True),
    "hem_dua": ((50, -14), 5.5, 8, "Ngõ Gạch", False),
    "cam_do": ((35, 14), 5, 8, "Ngõ Gạch", False),
    "ben_xe_6": ((65.2, -10), 7, 3, "Phố Trần Nhật Duật", False),
    "bai_boc_vac": ((67, -20), 8, 6, "Phố Trần Nhật Duật", False),
    "xe_tho": ((48, -5.3), 6, 4, "Phố Hàng Chiếu", True),
    "nha_tro_giuong": ((60, 16), 12, 10, "Ngõ 25 Phúc Tân", True),
    "quan_net": ((-42.7, 45), 6, 10, "Phố Hàng Bạc", False),
    "shop_ao": ((-43.7, 65), 6, 8, "Phố Hàng Bạc", False),
    "tiem_toc": ((-43.7, 80), 5, 8, "Phố Hàng Bạc", False),
    "ve_so": ((-34, -8.3), 4, 6, "Phố Hàng Chiếu", True),
    "bi_a": ((-24, 68.8), 8, 9, "Phố Lương Ngọc Quyến", True),
    "ben_can": ((50, 73), 24, 10, "Phố Tạ Hiện", False),
    "ho_guom": ((4, 88.5), 8, 3, "Đường dạo Hồ Gươm", True),
    "cau_tre": ((147.2, 12), 9, 9, "Phố Ngọc Thụy", False),
}
NO_INSET = ("bai_boc_vac", "xe_tho", "ho_guom")
# Door and arrival offsets project toward the road. Recess the shelter so both
# remain on the sidewalk, with the whole structure clear of Hàng Chiếu junction.
LOCATION_INSET = {"ben_xe_6": 3.5}

DESCRIPTIONS = {
    "xom_bo_me": "Xóm trọ Phúc Tân có sân chung và dây phơi. Ra đầu ngõ là quán cơm Hạnh; qua lối ngang tới tiệm chú Sơn và chợ. Cuối tháng cả xóm phải chuyển đi.",
    "tiem_sau": "Tiệm chú Sơn ở góc Hàng Chiếu, sát dãy vòm cầu Gầm Cầu: sửa xe máy và đồ điện gia dụng. Bàn sửa nhìn sang sạp linh kiện ở chợ.",
    "cho_cau_nho": "Chợ Long Biên thu gọn quanh sân bốc hàng: rau quả, linh kiện, đồ cũ, sạp cô Thắm và bảng tin nhà trọ. Ngõ Gạch rẽ ngay bên chợ.",
    "com_hanh": "Quán cơm Hạnh ở cửa ngõ Phúc Tân. Thợ sửa, người bốc vác và shipper ghé ăn rồi quay lại ca làm. Từ đây đi một đoạn ngõ ngắn là tới sân trọ.",
    "nha_di_nam": "Nhà dì Nga cùng ngõ Phúc Tân, cách sân trọ vài cửa. Ở tạm được bảy ngày, phải gửi bớt đồ; ra chợ và điểm xe đều thuận đường.",
    "hem_dua": "Phòng gác xép trong ngõ Gạch ngay bên chợ. Cửa sát ngõ, trần thấp, ít chỗ phơi; có người bán rau và tiệm cầm đồ ở đầu ngõ.",
    "cam_do": "Tiệm cầm đồ đầu ngõ Gạch: cầm đồ lấy tiền ngay, hẹn mười ngày chuộc, có lãi.",
    "ben_xe_6": "Điểm xe buýt Long Biên trên Trần Nhật Duật, ở mép cụm chợ. Xe đưa công nhân và học viên tới khu công nghiệp; từ đây cũng có chuyến sang khu khác.",
    "bai_boc_vac": "Bãi xe tải rau quả cạnh chợ Long Biên, ngay trước điểm xe buýt. Người bốc vác nhận ca và tiền công tại bàn điều phối.",
    "xe_tho": "Điểm thuê xe thồ cạnh sạp đầu chợ. Kéo hàng giữa kho và các sạp, trả theo chuyến.",
    "nha_tro_giuong": "Nhà trọ giường tầng ở cuối ngõ Phúc Tân, 30.000đ một đêm: phòng chung, quạt trần và tủ khóa nhỏ.",
    "quan_net": "Quán net Hàng Bạc trên phố dịch vụ cạnh khu trọ: tìm việc, đọc tin, chơi một ván hoặc nghỉ qua đêm.",
    "shop_ao": "Shop quần áo si-đa của chị Vy trên phố dịch vụ Hàng Bạc: bán lẻ và túi mù 99.000đ.",
    "tiem_toc": "Tiệm tóc Hàng Bạc gần lối xuống hồ, mở 08:00–19:00: cắt gọn, tỉa và nhuộm tóc.",
    "ve_so": "Đại lý vé số ở đầu Hàng Chiếu: vé 10.000đ một tờ, chiều mở thưởng.",
    "bi_a": "Quán bi-a anh Dũng trên Lương Ngọc Quyến. Gần phố Tạ Hiện, tối có người nghỉ ca ghé chơi.",
    "ben_can": "Dãy quán bia Tạ Hiện chung lối đi và đường điện cũ. Hợp đồng sửa điện của anh Phúc dẫn An sang cụm việc làm này.",
    "ho_guom": "Dãy ghế đá đầu đường dạo hồ Gươm. Có bàn cờ, người tập dưỡng sinh và chỗ nghỉ sau ca làm; đường dạo nối lại phố dịch vụ.",
    "cau_tre": "Phòng Ngọc Thụy bên kia sông Hồng. Hiên rộng, thoáng và tiền vào ở thấp hơn, nhưng đi làm phải qua cầu hoặc đi xe.",
}


def build():
    river = [(112 + 1.5 * math.sin(z / 28), z) for z in range(-65, 146, 5)]
    river += [(137 + math.sin(z / 31), z) for z in range(145, -66, -5)]
    g.water.append(river)
    g.waterways.append({"k": "river", "l": [124.5, -65, 124.5, 145], "n": "Sông Hồng", "w": 22.0})
    g.parks.append({"k": "sand", "n": "Bãi sông Phúc Tân", "p": rect(98, -65, 110, 145)})
    g.reserved.append(rect(96, -65, 112, 145))
    main = g.road("Phố Hàng Chiếu", [(-52, 0), (80, 0)], 6, sw=2)
    lane = g.road("Ngõ 25 Phúc Tân", [(-52, 24), (74, 24)], 3, "service", sw=1.2, small=True)
    for x in (1.5, 28):
        g.road("Lối sang chợ Phúc Tân", [(x, 0), (x, 24)], 3.2, "service", sw=0.5, small=True)
    gach = g.road("Ngõ Gạch", [(42, -27), (42, 24)], 2.6, "service", sw=0.6, small=True)
    west = g.road("Phố Hàng Bạc", [(-52, -30), (-52, 94)], 5, sw=1.5)
    east = g.road("Phố Trần Nhật Duật", [(74, -48), (74, 94)], 7, "secondary", sw=2)
    gam = g.road("Phố Gầm Cầu", [(-52, -30), (74, -30)], 5, sw=1.5)
    south = g.road("Phố Lương Ngọc Quyến", [(-52, 60), (74, 60)], 5, sw=1.5)
    ta_hien = g.road("Phố Tạ Hiện", [(40, 60), (40, 94)], 5, sw=2.5)
    go = g.road("Phố Cầu Gỗ", [(-52, 94), (74, 94)], 5, sw=1.5)
    g.road("Lối xuống Hồ Gươm", [(4, 24), (4, 60), (4, 82), (4, 92)], 3, "pedestrian", sw=0, small=True)
    g.road("Đường dạo Hồ Gươm", [(-20, 92), (30, 92)], 3, "pedestrian", sw=0, small=True)
    g.road("Đường dạo phía tây", [(-24, 94), (-24, 140), (34, 140), (34, 94)], 3, "pedestrian", sw=0, small=True)
    bridge_land = g.road("Cầu Long Biên", [(74, -30), (110, -30)], 6, "secondary", sw=1.5)
    g.road("Cầu Long Biên", [(110, -30), (140, -30)], 6, "secondary", bridge=True)
    g.road("Cầu Long Biên", [(140, -30), (155, -30)], 6, "secondary", sw=1.5)
    ngoc = g.road("Phố Ngọc Thụy", [(155, -48), (155, 60)], 4, sw=1, small=True)
    LANDMARKS.append({"kind": "truss", "a": [110, -30], "b": [140, -30], "w": 9, "h": 8, "spans": 1})
    for key, (at, w, d, _, along_x) in LOCATIONS.items():
        g.LOTS[key] = g._lot_for(at, w, d, along_x)
        g.reserved.append(g.LOTS[key])
    # Visible shared spaces replace the interior filler rows between daily stops.
    inner = rect(4, 7, 10, 20)
    g.parks.append({"k": "square", "n": "Sân nghỉ đầu ngõ", "p": inner})
    g.reserved.append(inner)
    # Facing shop fronts must also read at the playable camera distance: a
    # short shared apron replaces the opposite tall filler directly under the
    # camera. Other houses still frame the lane on both sides.
    for apron in (rect(-17, 27, -0.5, 42), rect(10, 27, 23, 42)):
        g.parks.append({"k": "pedestrian", "n": "Khoảng sân chung đầu ngõ", "p": apron})
        g.reserved.append(apron)
    yard = rect(48, -26, 68, -9)
    g.parks.append({"k": "parking", "n": "Sân bốc hàng Long Biên", "p": yard})
    g.reserved.append(yard)
    bus_apron = rect(63.5, -14, 70.5, -6)
    g.parks.append({"k": "pedestrian", "n": "Sân đợi xe Long Biên", "p": bus_apron})
    g.reserved.append(bus_apron)
    g.water.append(g.ellipse(4, 116, 18, 19, n=32, wobble=0.025, seed=11))
    promenade = rect(-22, 96, 32, 138)
    g.parks.append({"k": "park", "n": "Vườn hoa ven hồ", "p": promenade})
    g.reserved.append(promenade)
    g.house(g.ellipse(4, 121, 2.8, 2.3, n=12), 0.6, "8e8a7e", name="Gò Rùa", kind="islet")
    LANDMARKS.append({"kind": "thap_rua", "pos": [4, 121]})
    # Short heritage frontage retains the railway identity without a 350 m wall.
    for x in range(-45, 26, 6):
        g.house(rect(x, -48, x + 5.7, -39), 6.4, "8f4d38", name="Vòm cầu", kind="viaduct")
    g.reserved.append(rect(-46, -50, 33, -38))
    LANDMARKS.extend([
        {"kind": "viaduct_top", "a": [-45, -44], "b": [32, -44], "y": 6.4, "w": 9},
        {"kind": "arches", "a": [-45, -38.9], "b": [32, -38.9], "h": 4.8, "step": 6},
    ])
    for road, zone, depth in [(main, "pho", 10), (lane, "phuc_tan", 10), (west, "pho", 10),
                              (east, "pho", 11), (gam, "pho", 10), (south, "pho", 10),
                              (go, "ven_ho", 10), (gach, "ngo", 7), (ta_hien, "pho", 9),
                              (ngoc, "bo_kia", 9), (bridge_land, "phuc_tan", 8)]:
        for side in (-1, 1):
            g.row(road, side, zone, dmax=depth, dmin=4)
    # Trees mark junctions and rest pockets, rather than walling off every frontage.
    for road in (main, west, east, south, go):
        a, b = road["_pts"][0], road["_pts"][-1]
        direction = g.norm(g.sub(b, a))
        normal = g.left(direction)
        for u in range(10, int(g.length(g.sub(b, a))) - 5, 18):
            base = g.add(a, g.mul(direction, u))
            for side in (-1, 1):
                point = g.add(base, g.mul(normal, side * (road["w"] / 2 + road["sw"] * 0.6)))
                if not g.in_corridor(point, pad=1, skip=road) and not any(g.in_poly(point, lot) for lot in g.LOTS.values()):
                    g.trees.append(tuple(round(v, 1) for v in point))
    for point in g.ellipse(4, 116, 23, 23, n=12):
        g.trees.append(tuple(round(v, 1) for v in point))
    # Close-camera location labels already identify these short streets. Giant
    # landmark labels from the old overview would cover An at the new doors.


def main():
    build()
    data = {
        "buildings": [{k: v for k, v in b.items() if not k.startswith("_")} for b in g.buildings],
        "parks": [{"k": p["k"], "n": p["n"], "p": [round(c, 2) for q in p["p"] for c in q]} for p in g.parks],
        "pois": [], "rails": [],
        "roads": [{k: v for k, v in r.items() if not k.startswith("_")} for r in g.roads],
        "stats": {"hand": len(g.buildings)}, "tree_rows": [],
        "trees": [c for point in g.trees for c in point], "walls": g.walls,
        "water": [{"n": "Sông Hồng" if i == 0 else "Hồ Gươm", "p": [round(c, 2) for point in w for c in point]} for i, w in enumerate(g.water)],
        "waterways": g.waterways,
    }
    out = {"baked": "dựng tay", "bbox": [21.026, 105.846, 21.04, 105.858], "center": [21.0333, 105.852],
           "clip": [g.X0, g.Z0, g.X1, g.Z0, g.X1, g.Z1, g.X0, g.Z1], "data": data, "id": MAP_ID,
           "layoutVersion": LAYOUT_VERSION, "name": "Phố cổ Hà Nội — cụm sinh hoạt",
           "sources": "Bố trí hư cấu theo địa danh Hà Nội, ưu tiên sinh hoạt; không theo tỷ lệ bản đồ địa lý"}
    locations = {}
    for key, (at, w, d, road, _) in LOCATIONS.items():
        locations[key] = {"at": list(at), "w": w, "d": d, "road": road}
        if key in NO_INSET:
            locations[key]["inset"] = 0
        if key in LOCATION_INSET:
            locations[key]["inset"] = LOCATION_INSET[key]
    names = sorted({r["n"] for r in g.roads if r["n"]})
    story = {
        "_ghi_chu": "Sinh bằng tools/gen_phocu_map.py. Bố trí mới giữ tỷ lệ nhà/người, giảm khoảng trống giữa hoạt động.",
        "map": MAP_ID, "displayName": "Phố cổ Hà Nội", "layoutVersion": LAYOUT_VERSION,
        "walkHoursPerMeter": 0.0032, "locations": locations, "names": {n: n for n in names},
        "fallbackNames": ["Phố cổ"], "descriptions": DESCRIPTIONS, "landmarks": LANDMARKS,
        "questAreas": {"meo_be_bap": {"around": "cho_cau_nho", "radius": 35}},
        "vendorRoutes": {
            "banh_mi": [[-48, 0], [70, 0], [70, 24], [-48, 24], [-48, 0]],
            "xoi": [[1.5, 0], [28, 0], [28, 24], [1.5, 24], [1.5, 0]],
            "ve_chai": [[-48, 24], [70, 24], [70, 60], [-48, 60], [-48, 24]],
            "che": [[-48, 60], [36, 60], [36, 94], [-48, 94], [-48, 60]],
            "hu_tieu": [[-48, 60], [70, 60], [70, 24], [-48, 24], [-48, 60]],
            "kem": [[-24, 94], [-24, 140], [34, 140], [34, 94], [-24, 94]],
            "hoa_qua": [[16, 0], [70, 0], [70, -30], [16, -30], [16, 0]],
            "hoa": [[-48, 0], [-48, 60], [4, 60], [4, 24], [-48, 24], [-48, 0]],
            "bong_bay": [[-48, 60], [36, 60], [36, 94], [-48, 94], [-48, 60]],
            "banh_ran": [[-48, 24], [28, 24], [28, 0], [-48, 0], [-48, 24]],
        },
    }
    root = os.path.join(g.ROOT, "data", "maps")
    for suffix, payload, indent in [(".json", out, None), ("_story.json", story, 1)]:
        with open(os.path.join(root, MAP_ID + suffix), "w", encoding="utf8") as target:
            json.dump(payload, target, ensure_ascii=False, indent=indent, separators=None if indent else (",", ":"))
    print(f"layout={LAYOUT_VERSION} houses={len(g.buildings)} roads={len(g.roads)} trees={len(g.trees)} bounds=244x210m")


if __name__ == "__main__":
    main()
