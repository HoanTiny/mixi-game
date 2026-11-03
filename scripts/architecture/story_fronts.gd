extends RefCounted
## Street-facing identity for every named Hanoi location. Visuals retain the
## existing plot/door coordinates; only the authored pilot opens walkable rooms.
const Kit := preload("res://scripts/architecture/street_kit.gd")
const Props := preload("res://scripts/work/work_props.gd")

const PROFILES := {
	"cho_cau_nho": {"kind": "market", "sign": "CHỢ LONG BIÊN", "sub": "RAU QUẢ · HÀNG KHÔ · ĐỒ CŨ", "color": "744d3e"},
	"ben_xe_6": {"kind": "bus", "sign": "ĐIỂM XE BUÝT LONG BIÊN", "sub": "CHỜ XE TRONG VẠCH", "color": "465d51"},
	"nha_di_nam": {"kind": "home", "sign": "NHÀ DÌ NGA", "sub": "HÀNG CHIẾU", "color": "6a6150"},
	"hem_dua": {"kind": "home", "sign": "PHÒNG TRỌ NGÕ GẠCH", "sub": "PHÒNG NHỎ · GÁC XÉP", "color": "736b59"},
	"ben_can": {"kind": "beer", "sign": "BIA HƠI TẠ HIỆN", "sub": "MÓN NHÀ · BIA HƠI", "color": "58644a"},
	"cau_tre": {"kind": "home", "sign": "PHÒNG TRỌ NGỌC THỤY", "sub": "HIÊN THOÁNG · GẦN BẾN SÔNG", "color": "586b64"},
	"bai_boc_vac": {"kind": "loading", "sign": "BÃI BỐC VÁC LONG BIÊN", "sub": "ĐIỂM TẬP KẾT HÀNG", "color": "72644d"},
	"xe_tho": {"kind": "cart", "sign": "CHO THUÊ XE THỒ", "sub": "XE KÉO · CHỞ HÀNG", "color": "6b5d49"},
	"nha_tro_giuong": {"kind": "dorm", "sign": "NHÀ TRỌ GIƯỜNG TẦNG", "sub": "30.000Đ / ĐÊM", "color": "6e5d4c"},
	"quan_net": {"kind": "internet", "sign": "INTERNET HÀNG BẠC", "sub": "MỞ CỬA 24 GIỜ", "color": "475d66"},
	"cam_do": {"kind": "pawn", "sign": "CẦM ĐỒ NGÕ GẠCH", "sub": "CẦM ĐỒ · CHUỘC ĐỒ", "color": "774c43"},
	"ve_so": {"kind": "lottery", "sign": "ĐẠI LÝ VÉ SỐ MÃ MÂY", "sub": "VÉ SỐ KIẾN THIẾT", "color": "7a6951"},
	"ho_guom": {"kind": "park", "sign": "GÓC NGHỈ HỒ GƯƠM", "sub": "GHẾ ĐÁ · BÀN CỜ", "color": "5e6a58"},
	"shop_ao": {"kind": "clothes", "sign": "HÀNG THÙNG HÀNG ĐÀO", "sub": "SI-ĐA · TÚI MÙ 99K", "color": "765c5c"},
	"bi_a": {"kind": "billiards", "sign": "BI-A ANH DŨNG", "sub": "30K / GIỜ", "color": "3f5c51"},
	"tiem_toc": {"kind": "barber", "sign": "TIỆM TÓC HÀNG BẠC", "sub": "CẮT GỘI · NHUỘM TÓC", "color": "6c625a"}
}

static func _groups(parent: Node3D, height: float) -> Dictionary:
	var result := {"height": height, "blockers": [], "owns_dressing": true, "front_occlusion_cut": true}
	for key in ["ground", "upper", "roof", "front_walls"]:
		var node := Node3D.new()
		node.name = key.capitalize() + "Architecture"
		parent.add_child(node)
		result[key] = node
	return result

static func _bench(b: Kit.Batch, x: float, z: float, width: float, seed: int) -> void:
	var iron := Kit._mat("iron", seed)
	var timber := Kit._mat("wood", seed)
	for sx in [-1.0, 1.0]:
		b.box(iron, Vector3(x + sx * (width / 2.0 - 0.17), 0.28, z), Vector3(0.08, 0.5, 0.55))
		b.rod(iron, Vector3(x + sx * (width / 2.0 - 0.17), 0.24, z - 0.23), Vector3(x + sx * (width / 2.0 - 0.17), 0.98, z - 0.27), 0.027)
	for plank in 3:
		b.box(timber, Vector3(x, 0.54, z - 0.18 + plank * 0.17), Vector3(width, 0.055, 0.14))
		b.box(timber, Vector3(x, 0.7 + plank * 0.11, z - 0.28), Vector3(width, 0.075, 0.05))

static func _table(b: Kit.Batch, x: float, z: float, w: float, d: float, seed: int, top := 0.78) -> void:
	var iron := Kit._mat("iron", seed)
	b.box(Kit._mat("wood", seed), Vector3(x, top, z), Vector3(w, 0.07, d))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.rod(iron, Vector3(x + sx * (w / 2.0 - 0.09), 0.14, z + sz * (d / 2.0 - 0.09)), Vector3(x + sx * (w / 2.0 - 0.09), top, z + sz * (d / 2.0 - 0.09)), 0.035)

static func _crate(b: Kit.Batch, x: float, y: float, z: float, seed: int) -> void:
	var timber := Kit._mat("wood", seed)
	for side in [-1.0, 1.0]:
		for slat in 3:
			b.box(timber, Vector3(x + side * 0.31, y + 0.09 + slat * 0.12, z), Vector3(0.045, 0.085, 0.44))
			b.box(timber, Vector3(x, y + 0.09 + slat * 0.12, z + side * 0.22), Vector3(0.62, 0.085, 0.035))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.box(timber, Vector3(x + sx * 0.27, y + 0.2, z + sz * 0.19), Vector3(0.045, 0.4, 0.045))
	b.box(Kit._mat("old", seed), Vector3(x, y + 0.025, z), Vector3(0.6, 0.05, 0.42))

static func _wheel(b: Kit.Batch, center: Vector3, radius: float, seed: int) -> void:
	var iron := Kit._mat("iron", seed)
	for i in 16:
		var a := float(i) * TAU / 16.0
		var c := float(i + 1) * TAU / 16.0
		var p := center + Vector3(0, cos(a), sin(a)) * radius
		var q := center + Vector3(0, cos(c), sin(c)) * radius
		b.rod(iron, p, q, 0.047, 6)
		if i % 2 == 0:
			b.rod(iron, center, p, 0.013, 4)

static func _handcart(b: Kit.Batch, x: float, z: float, seed: int) -> void:
	var wood := Kit._mat("wood", seed)
	var iron := Kit._mat("iron", seed)
	for i in 6:
		b.box(wood, Vector3(x - 0.41 + i * 0.164, 0.68, z), Vector3(0.145, 0.07, 1.5))
	for side in [-1.0, 1.0]:
		b.rod(iron, Vector3(x + side * 0.44, 0.62, z - 0.7), Vector3(x + side * 0.44, 0.8, z + 1.15), 0.035)
		_wheel(b, Vector3(x + side * 0.58, 0.44, z - 0.05), 0.3, seed)
		b.rod(iron, Vector3(x + side * 0.3, 0.16, z + 0.6), Vector3(x + side * 0.3, 0.65, z + 0.6), 0.025)
	b.rod(iron, Vector3(x - 0.44, 0.8, z + 1.15), Vector3(x + 0.44, 0.8, z + 1.15), 0.035)

static func _outdoor(parent: Node3D, kind: String, w: float, d: float, seed: int) -> Dictionary:
	var height := 1.4 if kind == "park" else 3.3
	var kit := _groups(parent, height)
	var ground := Kit.Batch.new()
	var roof := Kit.Batch.new()
	var metal := Kit._mat("iron", seed)
	ground.box(Kit._mat("concrete", seed), Vector3(0, 0.065, -d / 2.0), Vector3(w, 0.13, d))
	if kind == "park":
		for side in [-1.0, 1.0]:
			_bench(ground, side * 2.45, -d + 0.65, 1.75, seed)
		ground.rod(metal, Vector3(-w / 2.0 + 0.95, 0.13, -0.15), Vector3(-w / 2.0 + 0.95, 1.36, -0.15), 0.04)
		ground.rod(Kit._mat("concrete", seed), Vector3(0, 0.14, -d + 0.85), Vector3(0, 0.77, -d + 0.85), 0.2, 10)
		ground.box(Kit._mat("old", seed), Vector3(0, 0.79, -d + 0.85), Vector3(0.85, 0.085, 0.85))
		var stone := Props.plain(Color("ccc4ac"), 0.93)
		ground.box(stone, Vector3(0, 0.838, -d + 0.85), Vector3(0.68, 0.012, 0.68))
		for line in 9:
			ground.box(metal, Vector3(-0.28 + line * 0.07, 0.846, -d + 0.85), Vector3(0.005, 0.003, 0.56))
			ground.box(metal, Vector3(0, 0.846, -d + 0.57 + line * 0.07), Vector3(0.56, 0.003, 0.005))
		for side in [-1.0, 1.0]:
			ground.rod(Kit._mat("concrete", seed), Vector3(side * 0.72, 0.14, -d + 0.85), Vector3(side * 0.72, 0.46, -d + 0.85), 0.24, 12)
	else:
		for sx in [-1.0, 1.0]:
			for z in [-d + 0.2, -0.15]:
				ground.box(metal, Vector3(sx * (w / 2.0 - 0.2), 1.55, z), Vector3(0.105, 2.85, 0.105))
		roof.box(Kit._mat("roof", seed), Vector3(0, 3.02, -d / 2.0), Vector3(w + 0.15, 0.075, d + 0.35), Basis(Vector3.RIGHT, 0.045))
		for x in [-w * 0.25, 0.0, w * 0.25]:
			roof.rod(metal, Vector3(x, 2.86, -0.1), Vector3(x, 2.98, -d + 0.1), 0.045)
		ground.box(Kit._mat("old", seed), Vector3(0, 0.43, -d + 0.12), Vector3(w, 0.6, 0.2))
		if kind == "bus":
			_bench(ground, 0.65, -d + 0.72, w - 2.6, seed)
			ground.box(metal, Vector3(-w / 2.0 + 0.6, 1.72, -d + 0.17), Vector3(0.92, 1.6, 0.10))
			ground.box(Kit._mat("equipment", seed), Vector3(-w / 2.0 + 0.6, 1.72, -d + 0.23), Vector3(0.81, 1.47, 0.012))
			for line in 5:
				ground.box(Kit._mat("shutter", seed), Vector3(-w / 2.0 + 0.6, 1.26 + line * 0.2, -d + 0.24), Vector3(0.64, 0.025, 0.006))
		elif kind == "loading":
			for i in 9:
				_crate(ground, -w / 2.0 + 0.65 + (i % 4) * 0.74, 0.14 + floori(i / 4.0) * 0.42, -d + 0.6 + (i % 2) * 0.5, seed)
			_handcart(ground, w * 0.29, -d + 1.55, seed)
		else:
			for side in [-1.0, 1.0]:
				_handcart(ground, side * w * 0.28, -d + 1.1, seed)
	ground.finish(kit.ground, "StreetFurniture")
	if not roof.surfaces.is_empty():
		roof.finish(kit.roof, "ShelterRoof")
	kit["sign_position"] = Vector3(0, 2.48 if kind != "park" else 0.9, 0.12)
	kit["sign_width"] = minf(w - 0.5, 5.4 if kind != "park" else 1.8)
	if kind == "park":
		kit.sign_position = Vector3(-w / 2.0 + 0.95, 0.8, -0.08)
	kit["blockers"] = [Rect2(-w / 2.0, -d, w, d)]
	return kit

static func _market(parent: Node3D, w: float, d: float, seed: int) -> Dictionary:
	var kit := _groups(parent, 5.45)
	var g := Kit.Batch.new()
	var shell := Kit.Batch.new()
	var u := Kit.Batch.new()
	var r := Kit.Batch.new()
	var wall := Kit._mat("old", seed)
	var iron := Kit._mat("iron", seed)
	g.box(Kit._mat("concrete", seed), Vector3(0, 0.07, -d / 2), Vector3(w, 0.14, d))
	shell.box(wall, Vector3(0, 1.7, -d + 0.2), Vector3(w, 3.4, 0.4))
	for s in [-1.0, 1.0]:
		shell.box(wall, Vector3(s * (w / 2.0 - 0.2), 1.7, -d / 2.0), Vector3(0.4, 3.4, d))
	var bays := maxi(3, floori(w / 4.3))
	if bays % 2 == 0:
		bays -= 1
	for i in bays + 1:
		var x := -w / 2.0 + 0.25 + i * (w - 0.5) / bays
		shell.box(wall, Vector3(x, 1.85, -0.18), Vector3(0.48, 3.7, 0.56))
		Kit._pier_weather(shell, x, 0.48, 0.11, seed + i)
		u.rod(iron, Vector3(x, 3.7, 0), Vector3(x, 5.15, -d / 2.0), 0.055)
		u.rod(iron, Vector3(x, 5.15, -d / 2.0), Vector3(x, 3.7, -d), 0.055)
		u.rod(iron, Vector3(x, 3.72, 0), Vector3(x, 3.72, -d), 0.045)
		if i < bays:
			var sx := x + (w - 0.5) / bays * 0.5
			_table(g, sx, -1.55, minf(2.6, w / bays - 0.8), 0.85, seed, 0.88)
			for item in 3:
				_crate(g, sx - 0.73 + item * 0.73, 0.94, -1.55, seed + i)
	Kit._sloped_roof(r, w, d, 3.85, 5.35, seed)
	r.box(wall, Vector3(0, 3.6, 0.08), Vector3(w, 0.34, 0.55))
	g.finish(kit.ground, "MarketHallAndStalls")
	shell.finish(kit.front_walls, "MarketMasonry")
	u.finish(kit.upper, "MarketTrusses")
	r.finish(kit.roof, "MarketRoof")
	kit["sign_position"] = Vector3(0, 3.48, 0.47)
	kit["sign_width"] = minf(7.5, w * 0.65)
	kit["blockers"] = [Rect2(-w / 2.0, -d, w, d)]
	return kit

static func _terrace(parent: Node3D, kind: String, w: float, d: float, seed: int) -> Dictionary:
	var kit := _groups(parent, 0.0)
	var count := maxi(2, roundi(w / 5.0))
	for i in count:
		var piece := Node3D.new()
		piece.position.x = -w / 2.0 + (i + 0.5) * w / count
		parent.add_child(piece)
		var unit := Kit.build(piece, "restaurant" if kind == "beer" else "residential", w / count, d, seed + i, true)
		for key in ["ground", "upper", "roof", "front_walls"]:
			var part: Node3D = unit[key]
			piece.remove_child(part)
			part.position.x = piece.position.x
			kit[key].add_child(part)
		kit.height = maxf(kit.height, float(unit.height))
		parent.remove_child(piece)
		piece.free()
	kit["sign_position"] = Vector3(0, 2.83 if kind == "beer" else 2.94, 1.12)
	kit["sign_width"] = minf(5.4, w - 0.6)
	kit["blockers"] = [Rect2(-w / 2.0, -d, w, d)]
	return kit

static func _shop_details(parent: Node3D, kind: String, w: float, d: float, seed: int) -> Node3D:
	var detail := Node3D.new()
	detail.name = "UseSpecificDetails"
	parent.add_child(detail)
	var b := Kit.Batch.new()
	var iron := Kit._mat("iron", seed)
	var wood := Kit._mat("wood", seed)
	var equipment := Kit._mat("equipment", seed)
	var dark := Kit._mat("glass", seed)
	var left := -w * 0.29
	var right := w * 0.29
	match kind:
		"internet":
			for side in [-1.0, 1.0]:
				for i in 2:
					var x: float = side * w * 0.29
					var z := -1.1 - i * 1.4
					_table(b, x, z, 1.25, 0.68, seed)
					b.box(iron, Vector3(x, 1.1, z - 0.15), Vector3(0.64, 0.43, 0.075))
					b.box(Props.plain(Color("577781"), 0.5), Vector3(x, 1.1, z - 0.105), Vector3(0.55, 0.34, 0.014))
					b.box(iron, Vector3(x, 0.84, z + 0.18), Vector3(0.43, 0.03, 0.16))
					b.box(equipment, Vector3(x + 0.43, 0.42, z), Vector3(0.23, 0.55, 0.42))
					_bench(b, x, z + 0.62, 0.62, seed)
		"pawn", "lottery":
			var counter_width := w * 0.56
			b.box(wood, Vector3(left * 0.55, 0.65, -1.22), Vector3(counter_width, 1.0, 0.65))
			b.box(equipment, Vector3(left * 0.55, 1.18, -1.2), Vector3(counter_width + 0.08, 0.08, 0.74))
			if kind == "pawn":
				for i in 9:
					var x := left * 0.55 - counter_width / 2.0 + 0.1 + i * (counter_width - 0.2) / 8.0
					b.rod(iron, Vector3(x, 1.22, -1.2), Vector3(x, 2.5, -1.2), 0.018, 6)
				b.box(iron, Vector3(left * 0.55, 2.48, -1.2), Vector3(counter_width, 0.05, 0.08))
				b.box(dark, Vector3(right, 0.7, -2), Vector3(0.74, 1.1, 0.58))
			else:
				for row in 3:
					for col in 4:
						b.box(Props.plain(Color("c3bda2"), 1), Vector3(left * 0.55 - 0.66 + col * 0.3, 1.26 + row * 0.006, -1.38 + row * 0.18), Vector3(0.24, 0.008, 0.15))
		"clothes":
			for side in [-1.0, 1.0]:
				var x: float = side * w * 0.31
				for dx in [-0.55, 0.55]:
					b.rod(iron, Vector3(x + dx, 0.16, -1.2), Vector3(x + dx, 1.88, -1.2), 0.023)
				b.rod(iron, Vector3(x - 0.55, 1.88, -1.2), Vector3(x + 0.55, 1.88, -1.2), 0.025)
				for i in 4:
					var tone := Props.plain(Color(["88796a", "5a6d68", "817078", "a59c83"][i]), 1.0)
					var xx := x - 0.4 + i * 0.27
					b.box(tone, Vector3(xx, 1.36, -1.2), Vector3(0.23, 0.6, 0.09), Basis(Vector3.FORWARD, 0.04 * (i - 2)))
					b.box(tone, Vector3(xx, 1.63, -1.2), Vector3(0.37, 0.16, 0.085))
		"barber":
			b.box(wood, Vector3(left, 1.65, -1.65), Vector3(1.35, 1.8, 0.11))
			b.box(Props.plain(Color("819795"), 0.08, 0.72), Vector3(left, 1.65, -1.58), Vector3(1.16, 1.6, 0.025))
			_table(b, left, -1.3, 1.35, 0.4, seed, 0.9)
			b.rod(iron, Vector3(left, 0.16, -0.55), Vector3(left, 0.64, -0.55), 0.1, 12)
			b.box(Props.plain(Color("5b4840"), 0.84), Vector3(left, 0.68, -0.55), Vector3(0.64, 0.14, 0.64))
			b.box(Props.plain(Color("5b4840"), 0.84), Vector3(left, 1.0, -0.28), Vector3(0.64, 0.55, 0.12))
			_bench(b, right, -1.8, 1.25, seed)
		"billiards":
			var felt := Props.plain(Color("345b49"), 0.98)
			for x in [left, right]:
				_table(b, x, -1.9, 1.45, 2.35, seed, 0.87)
				b.box(felt, Vector3(x, 0.914, -1.9), Vector3(1.25, 0.018, 2.14))
				for sx in [-1.0, 1.0]:
					for zz in [-2.91, -1.9, -0.89]:
						b.rod(dark, Vector3(x + sx * 0.6, 0.921, zz), Vector3(x + sx * 0.6, 0.925, zz), 0.065, 8)
			for i in 4:
				b.rod(wood, Vector3(w / 2.0 - 0.4 - i * 0.11, 0.16, -3.5), Vector3(w / 2.0 - 0.48 - i * 0.11, 1.65, -3.5), 0.014, 6)
		"beer":
			var count := maxi(3, roundi(w / 4.8))
			for i in count:
				var x := -w / 2.0 + (i + 0.5) * w / count
				_table(b, x, -1.25, 1.3, 0.8, seed, 0.67)
				for s in [-1.0, 1.0]:
					_bench(b, x + s * 0.9, -1.25, 0.55, seed)
				for cup in 2:
					b.rod(equipment, Vector3(x - 0.25 + cup * 0.5, 0.71, -1.25), Vector3(x - 0.25 + cup * 0.5, 0.84, -1.25), 0.045, 8)
		"home", "dorm":
			_bench(b, right, -1.2, minf(1.3, w * 0.22), seed)
			b.box(wood, Vector3(left, 0.45, -0.85), Vector3(minf(1.2, w * 0.22), 0.6, 0.32))
			for i in 4:
				b.box(dark, Vector3(left - 0.35 + i * 0.22, 0.18, -0.6), Vector3(0.15, 0.055, 0.3))
			if kind == "dorm":
				for y in [0.55, 1.65]:
					b.box(equipment, Vector3(left, y, -2.25), Vector3(0.9, 0.13, 1.85))
					for sx in [-0.49, 0.49]:
						b.rod(iron, Vector3(left + sx, 0.14, -3.2), Vector3(left + sx, 2.05, -3.2), 0.025)
						b.rod(iron, Vector3(left + sx, 0.14, -1.3), Vector3(left + sx, 2.05, -1.3), 0.025)
				for rung in 5:
					b.rod(iron, Vector3(left - 0.35, 0.4 + rung * 0.29, -1.25), Vector3(left + 0.05, 0.4 + rung * 0.29, -1.25), 0.018)
	if not b.surfaces.is_empty():
		var mesh := b.finish(detail, "BatchedStreetActivityProps")
		mesh.visibility_range_end = 72.0
		mesh.visibility_range_end_margin = 8.0
	return detail

static func build(parent: Node3D, id: String, w: float, d: float, seed: int) -> Dictionary:
	assert(PROFILES.has(id), "Missing story architecture: " + id)
	var spec: Dictionary = PROFILES[id]
	var kind: String = spec.kind
	var kit: Dictionary
	if kind in ["bus", "loading", "cart", "park"]:
		kit = _outdoor(parent, kind, w, d, seed)
	elif kind == "market":
		kit = _market(parent, w, d, seed)
	elif kind == "beer" or (kind == "dorm" and w >= 8.0):
		kit = _terrace(parent, kind, w, d, seed)
	else:
		kit = Kit.build(parent, "residential" if kind == "home" else "service", w, d, seed, true)
		kit.sign_position = Vector3(0, 2.83, 1.12)
		kit.sign_width = minf(w - 0.6, 5.4)
	kit["details"] = _shop_details(kit.ground, kind, w, d, seed)
	kit["owns_dressing"] = true
	kit["identity"] = kind
	kit["sign_text"] = str(spec.sign) + "\n" + str(spec.sub)
	kit["sign_color"] = Color(spec.color)
	kit.ground.set_meta("story_location", id)
	kit.ground.set_meta("identity", kind)
	return kit
