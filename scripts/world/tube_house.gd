extends RefCounted
## Dựng nhà ống kiểu phố Sài Gòn bằng khối: tầng trệt có cửa cuốn hoặc cổng sắt, mái hiên tôn,
## biển hiệu chữ to; tầng trên có ban công lan can sắt, máy lạnh, đồ phơi; nóc có bồn nước inox.
## Mỗi căn lấy ngẫu nhiên theo rng nên cả dãy phố không căn nào giống căn nào.

const GROUND_H := 3.4
const FLOOR_H := 3.1
## Màu sơn nhà phố hay gặp: vàng, xanh ngọc, hồng, kem, cam nhạt, xanh lá nhạt, tím nhạt.
const WALLS := ["e9c46a", "8fd3d0", "f2a7a7", "f3ead8", "ffc98b", "b9d99a", "cdb4db", "f6e27f", "a7c7e7"]
const AWNINGS := ["2f6fb0", "c0392b", "2e8b57", "d9d9d9", "e67e22", "1f8a9a"]
const BOARDS := ["c0392b", "1e5aa8", "f1c40f", "1b7a43", "8e2b8e", "e0e0e0"]
const CLOTHES := ["e74c3c", "3498db", "f1c40f", "ecf0f1", "9b59b6", "2ecc71", "e67e22"]
const FILLER_SIGNS := ["SỬA XE", "TẠP HÓA", "PHỞ", "CẮT TÓC", "BÁNH MÌ", "PHOTOCOPY", "NHÀ THUỐC", "SIM THẺ", "GỘI ĐẦU", "BÚN BÒ", "ĐIỆN THOẠI", "VẢI SỢI"]

var front_z := -5.0
var font: Font
var _mats := {}
## Mỗi căn gộp mọi khối thành một lưới tô màu theo đỉnh, cả căn chỉ tốn một lần vẽ.
var _st: SurfaceTool
var _vc_mat: StandardMaterial3D


func _init(front: float, label_font: Font) -> void:
	front_z = front
	font = label_font


func _mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[k] = m
	return _mats[k]


func _begin() -> void:
	_st = SurfaceTool.new()
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


func _end(parent: Node3D) -> void:
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.roughness = 0.9
	var mi := MeshInstance3D.new()
	mi.mesh = _st.commit()
	mi.material_override = _vc_mat
	parent.add_child(mi)
	_st = null


## Thêm một khối hộp vào lưới của căn đang dựng, đáy tại pos (pos.y là cao độ đáy).
## tilt: nghiêng quanh trục x (mái hiên, mái tôn), xoay quanh tâm khối.
func _box(_parent: Node3D, size: Vector3, pos: Vector3, c: Color, tilt := 0.0) -> void:
	var center := pos + Vector3(0, size.y / 2.0, 0)
	var b := Basis(Vector3.RIGHT, tilt)
	var hs := size / 2.0
	_st.set_color(c)
	for axis in 3:
		for s in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = s
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var corners := []
			for q in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				corners.append(center + b * ((n + u * q[0] + v * q[1]) * hs))
			_st.set_normal(b * n)
			for i in [0, 2, 1, 0, 3, 2]:
				_st.add_vertex(corners[i])


func pick(rng: RandomNumberGenerator, list: Array) -> Color:
	return Color(list[rng.randi() % list.size()])


## Một căn nhà ống mặt tiền rộng w, sâu d, n tầng, tâm mặt tiền tại x. Trả về chiều cao nóc.
## shop: tầng trệt mở cửa buôn bán; sign: chữ trên biển hiệu ("" là không có biển).
func house(parent: Node3D, x: float, w: float, d: float, floors: int, wall: Color, rng: RandomNumberGenerator, sign := "", shop := true) -> float:
	var f := front_z
	var h := GROUND_H + FLOOR_H * float(floors - 1)
	_begin()
	_box(parent, Vector3(w - 0.06, h, d), Vector3(x, 0, f - d / 2.0), wall)
	# Gờ tường ngăn giữa hai căn, sơn đậm hơn cho thấy từng căn riêng.
	for side in [-1.0, 1.0]:
		_box(parent, Vector3(0.18, h, 0.25), Vector3(x + side * (w / 2.0 - 0.09), 0, f + 0.05), wall.darkened(0.12))

	# Tầng trệt.
	var inner := w - 0.6
	if shop:
		_box(parent, Vector3(inner, 2.55, 0.05), Vector3(x, 0, f + 0.02), Color("2b2622"))
		# Cửa cuốn kéo lên gần hết, còn một khúc dưới mái hiên.
		_box(parent, Vector3(inner + 0.1, 0.4, 0.28), Vector3(x, 2.5, f + 0.14), Color("a3a9ae"))
	else:
		# Cổng sắt kéo, nhiều song dọc.
		_box(parent, Vector3(inner, 2.4, 0.04), Vector3(x, 0, f + 0.02), Color("3c4046"))
		var bx := -inner / 2.0 + 0.15
		while bx < inner / 2.0:
			_box(parent, Vector3(0.05, 2.4, 0.06), Vector3(x + bx, 0, f + 0.06), Color("6b7178"))
			bx += 0.32
	# Mái hiên tôn nghiêng ra đường.
	_box(parent, Vector3(w - 0.1, 0.05, 1.5), Vector3(x, 2.62, f + 0.75), pick(rng, AWNINGS), 0.18)
	if sign != "":
		var board := pick(rng, BOARDS)
		# Biển treo ở mép ban công tầng hai, trên mái hiên, để nhìn từ trên xuống vẫn thấy.
		_box(parent, Vector3(w - 0.3, 0.95, 0.12), Vector3(x, 2.95, f + 0.95), board)
		var l := Label3D.new()
		l.text = sign
		l.font = font
		l.font_size = 80
		l.pixel_size = 0.009
		l.outline_size = 0
		l.modulate = Color("1d1d1d") if board.get_luminance() > 0.6 else Color("fff4c2")
		# Chữ dài thì thu nhỏ cho vừa bề ngang biển.
		var fit := (w - 0.7) / l.pixel_size
		var tw := font.get_string_size(sign, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x
		if tw > fit:
			l.font_size = int(l.font_size * fit / tw)
		l.position = Vector3(x, 3.42, f + 1.02)
		parent.add_child(l)

	# Các tầng trên.
	for i in range(1, floors):
		var y0 := GROUND_H + FLOOR_H * float(i - 1)
		_box(parent, Vector3(inner, 2.25, 0.05), Vector3(x, y0 + 0.2, f + 0.02), Color("3b4a5a") if rng.randf() < 0.7 else Color("6d4c41"))
		if rng.randf() < 0.6:
			# Rèm cửa màu.
			_box(parent, Vector3(inner * 0.3, 2.0, 0.03), Vector3(x - inner * 0.32, y0 + 0.3, f + 0.05), pick(rng, CLOTHES).lightened(0.3))
		_box(parent, Vector3(w - 0.2, 0.15, 0.85), Vector3(x, y0, f + 0.42), wall.darkened(0.08))
		# Lan can sắt: hai thanh ngang và song dọc thưa.
		var rail := Color("2f3237")
		_box(parent, Vector3(w - 0.2, 0.05, 0.05), Vector3(x, y0 + 1.0, f + 0.82), rail)
		_box(parent, Vector3(w - 0.2, 0.05, 0.05), Vector3(x, y0 + 0.2, f + 0.82), rail)
		var rx := -(w - 0.2) / 2.0
		while rx <= (w - 0.2) / 2.0 + 0.01:
			_box(parent, Vector3(0.035, 0.85, 0.035), Vector3(x + rx, y0 + 0.15, f + 0.82), rail)
			rx += 0.45
		if rng.randf() < 0.5:
			_box(parent, Vector3(0.8, 0.55, 0.32), Vector3(x + w / 2.0 - 0.75, y0 + 2.35, f + 0.18), Color("e9ecef"))
		if rng.randf() < 0.45:
			# Dây phơi đồ trước ban công.
			_box(parent, Vector3(w - 0.4, 0.02, 0.02), Vector3(x, y0 + 2.05, f + 0.62), Color("555555"))
			var cx := -(w - 0.6) / 2.0 + 0.3
			while cx < (w - 0.6) / 2.0:
				if rng.randf() < 0.7:
					var ch := rng.randf_range(0.4, 0.7)
					_box(parent, Vector3(0.38, ch, 0.02), Vector3(x + cx, y0 + 2.05 - ch, f + 0.62), pick(rng, CLOTHES))
				cx += 0.5
		if rng.randf() < 0.5:
			for k in rng.randi_range(1, 3):
				_box(parent, Vector3(0.3, 0.45, 0.3), Vector3(x - w / 2.0 + 0.5 + k * 0.45, y0 + 0.15, f + 0.55), Color("3f7d3a"))

	# Nóc: gờ trước, bồn nước inox, có căn có mái tôn che sân thượng.
	_box(parent, Vector3(w - 0.06, 0.25, 0.3), Vector3(x, h, f - 0.1), wall.darkened(0.15))
	var tank := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.45
	cm.bottom_radius = 0.45
	cm.height = 1.1
	tank.mesh = cm
	tank.material_override = _mat(Color("d5d9de"))
	tank.rotation.z = PI / 2.0 if rng.randf() < 0.5 else 0.0
	tank.position = Vector3(x + rng.randf_range(-w / 4.0, w / 4.0), h + 0.6, f - d * 0.6)
	parent.add_child(tank)
	if rng.randf() < 0.5:
		_box(parent, Vector3(w - 0.1, 0.06, d * 0.55), Vector3(x, h + 2.0, f - d * 0.65), Color("8e9aa3") if rng.randf() < 0.6 else Color("b5651d"), -0.15)
		for px in [-w / 2.0 + 0.2, w / 2.0 - 0.2]:
			_box(parent, Vector3(0.08, 2.0, 0.08), Vector3(x + px, h, f - d * 0.4), Color("5d6166"))
	_end(parent)
	return h


## Nhà ống chen vào khoảng trống [a, b] trên mặt phố: chia thành các căn rộng 3,8 đến 5,5 m.
## Khoảng hẹp hơn 3,5 m để trống làm hẻm.
func fill(parent: Node3D, a: float, b: float, rng: RandomNumberGenerator) -> void:
	var x := a
	while b - x >= 3.5:
		var w := minf(rng.randf_range(3.8, 5.5), b - x)
		if b - x - w < 3.5 and b - x - w > 0.0:
			w = b - x
		var sign: String = FILLER_SIGNS[rng.randi() % FILLER_SIGNS.size()] if rng.randf() < 0.55 else ""
		house(parent, x + w / 2.0, w, rng.randf_range(9.0, 14.0), rng.randi_range(2, 5), pick(rng, WALLS), rng, sign, sign != "" or rng.randf() < 0.3)
		x += w


## Dãy nhà cao phía sau (chỉ thấy phần trên mái): khối, cửa sổ và bồn nước, ít chi tiết cho nhẹ.
func back_row(parent: Node3D, a: float, b: float, z: float, rng: RandomNumberGenerator) -> void:
	var x := a
	while x < b:
		var w := rng.randf_range(4.0, 7.0)
		var h := GROUND_H + FLOOR_H * float(rng.randi_range(4, 8))
		var wall := pick(rng, WALLS).darkened(0.08)
		_begin()
		_box(parent, Vector3(w - 0.1, h, 8.0), Vector3(x + w / 2.0, 0, z - 4.0), wall)
		var y := GROUND_H + 0.6
		while y < h - 1.5:
			_box(parent, Vector3(w * 0.55, 1.4, 0.05), Vector3(x + w / 2.0, y, z + 0.02), Color("4a5867"))
			y += FLOOR_H
		_end(parent)
		var tank := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.45
		cm.height = 1.1
		tank.mesh = cm
		tank.material_override = _mat(Color("d5d9de"))
		tank.position = Vector3(x + w / 2.0, h + 0.55, z - 3.0)
		parent.add_child(tank)
		x += w
