extends Node3D
## Nhân vật dựng bằng khối có khớp (đầu, vai, khuỷu, hông, gối), tự chạy hoạt cảnh đi, đứng, ngồi.
## Ngoại hình lấy từ một từ điển "look", nên Minh, nhân vật phụ và người đi đường dùng chung bộ khung.
##
## look: skin, hair, hair_style (short | long | bun), shirt, sleeve (short | long), pants, shoes,
##       hat (none | non_la | cap | helmet), bag (true/false), height (mét), build (độ đậm người, 0.9–1.15)

const LOOKS := {
	# An, 27 tuổi, thợ sửa điện máy: áo thun xám xanh, quần kaki, dép quai hậu, ba lô đồ nghề.
	"AN": {"skin": "d1a07a", "hair": "1b1714", "hair_style": "short", "shirt": "5b7f8f", "sleeve": "short",
		"pants": "5e5446", "shoes": "3b3b3b", "hat": "none", "bag": true, "height": 1.72, "build": 1.02},
	# Linh, 20 tuổi: áo đồng phục trường nghề xanh, quần jean, tóc cột.
	"LINH": {"skin": "e2b48f", "hair": "1b1714", "hair_style": "long", "shirt": "4f8fb5", "sleeve": "short",
		"pants": "3b5b82", "shoes": "f2f0ea", "hat": "none", "bag": true, "height": 1.58, "build": 0.94},
	# Bà Tư, 70 tuổi: áo bà ba tím, quần đen, tóc bạc búi.
	"BA_TU": {"skin": "c99a76", "hair": "d8d8d8", "hair_style": "bun", "shirt": "8a6f9a", "sleeve": "long",
		"pants": "1f1f24", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.5, "build": 0.95},
	# Chị Hạnh: áo thun cam, tạp dề, tóc búi.
	"HANH": {"skin": "d8a27a", "hair": "2b211b", "hair_style": "bun", "shirt": "c0603a", "sleeve": "short",
		"pants": "2c2f3a", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.58, "build": 1.04},
	# Chú Sáu: sơ mi xanh bạc màu dài tay, quần kaki, nón kết.
	"SAU": {"skin": "b97d55", "hair": "9a9a9a", "hair_style": "short", "shirt": "3f6f8f", "sleeve": "long",
		"pants": "6d5d4b", "shoes": "3b3b3b", "hat": "cap", "bag": false, "height": 1.64, "build": 1.08},
	# Minh, tài xế giao hàng: áo khoác xanh, mũ bảo hiểm.
	"MINH": {"skin": "c98f63", "hair": "1b1714", "hair_style": "short", "shirt": "2f8a5a", "sleeve": "long",
		"pants": "2c3e50", "shoes": "f5f5f5", "hat": "helmet", "bag": false, "height": 1.74, "build": 1.04},
	# Cô Duyên: áo sơ mi hoa, quần tây.
	"DUYEN": {"skin": "d8a27a", "hair": "2b211b", "hair_style": "bun", "shirt": "b5577a", "sleeve": "long",
		"pants": "4a4a52", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.56, "build": 1.06},
	# Trâm, thợ điện: áo bảo hộ xanh rêu, nón kết.
	"TRAM": {"skin": "d9a77c", "hair": "1b1714", "hair_style": "long", "shirt": "2f6f6a", "sleeve": "long",
		"pants": "35455e", "shoes": "3b3b3b", "hat": "cap", "bag": false, "height": 1.62, "build": 0.98},
	# Anh Phúc: áo sơ mi trắng, quần tây.
	"PHUC": {"skin": "c99a76", "hair": "1b1714", "hair_style": "short", "shirt": "efeee8", "sleeve": "short",
		"pants": "6f7277", "shoes": "3b3b3b", "hat": "none", "bag": false, "height": 1.7, "build": 1.12},
}

var look: Dictionary = {}
var _mats := {}
var _phase := 0.0
var _move := 0.0
var _sitting := false
# Khớp
var body: Node3D
var hips: Node3D
var chest: Node3D
var head: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var elbow_l: Node3D
var elbow_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var knee_l: Node3D
var knee_r: Node3D


static func make(look_in: Dictionary) -> Node3D:
	var c = load("res://scripts/world/character.gd").new()
	c.look = look_in
	c._build()
	return c


## Ngoại hình ngẫu nhiên cho người đi đường: quần áo thường ngày ở Sài Gòn.
static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var female := rng.randf() < 0.5
	var shirts := ["e8e4da", "c0392b", "2f6fb0", "f1c40f", "7d8c6a", "e67e22", "8e44ad", "ecf0f1", "16a085", "d98fa0"]
	var pants := ["2c3e50", "35455e", "1f1f24", "6d5d4b", "8a8f98", "3b3b3b"]
	var hat := "none"
	var r := rng.randf()
	if r < 0.15:
		hat = "non_la"
	elif r < 0.27:
		hat = "cap"
	return {
		"skin": ["c98f63", "d9a77c", "e2b48f", "b97d55"][rng.randi() % 4],
		"hair": ["1b1714", "2b211b", "3a2a20"][rng.randi() % 3],
		"hair_style": (["long", "bun"][rng.randi() % 2]) if female else "short",
		"shirt": shirts[rng.randi() % shirts.size()],
		"sleeve": "long" if rng.randf() < 0.35 else "short",
		"pants": pants[rng.randi() % pants.size()],
		"shoes": ["e8efe9", "3b3b3b", "8b5a2b", "2f6fb0"][rng.randi() % 4],
		"hat": hat, "bag": rng.randf() < 0.2,
		"height": rng.randf_range(1.55, 1.68) if female else rng.randf_range(1.62, 1.78),
		"build": rng.randf_range(0.92, 1.1),
	}


func _mat(hex: String) -> StandardMaterial3D:
	if not _mats.has(hex):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(hex)
		m.roughness = 0.85
		_mats[hex] = m
	return _mats[hex]


func _part(parent: Node3D, mesh: Mesh, hex: String, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(hex)
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _joint(parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.position = pos
	parent.add_child(j)
	return j


func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	return m


func _sphere(r: float, h := -1.0) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0 if h < 0.0 else h
	m.radial_segments = 14
	m.rings = 8
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Dựng theo tỉ lệ người cao 1,72 m rồi co giãn theo chiều cao thật.
func _build() -> void:
	var skin: String = look.get("skin", "d9a77c")
	var shirt: String = look.get("shirt", "4f7fb3")
	var pants: String = look.get("pants", "35455e")
	var shoes: String = look.get("shoes", "e8efe9")
	var hair: String = look.get("hair", "1b1714")
	var w: float = float(look.get("build", 1.0))
	body = Node3D.new()
	add_child(body)
	var k := float(look.get("height", 1.72)) / 1.72
	body.scale = Vector3(k * w, k, k * w)

	# Hông và chân: khớp hông ở 0,92 m, gối ở giữa.
	hips = _joint(body, Vector3(0, 0.92, 0))
	_part(hips, _box(Vector3(0.34, 0.16, 0.2)), pants, Vector3(0, 0.02, 0))
	for side in [-1.0, 1.0]:
		var hip := _joint(hips, Vector3(side * 0.095, -0.04, 0))
		_part(hip, _cyl(0.075, 0.062, 0.44), pants, Vector3(0, -0.22, 0))
		var knee := _joint(hip, Vector3(0, -0.44, 0))
		_part(knee, _cyl(0.06, 0.05, 0.42), pants, Vector3(0, -0.21, 0))
		_part(knee, _cyl(0.042, 0.04, 0.05), skin, Vector3(0, -0.43, 0))
		# Dép: đế dẹt, quai ngang.
		_part(knee, _box(Vector3(0.1, 0.03, 0.25)), shoes, Vector3(0, -0.46, 0.04))
		_part(knee, _box(Vector3(0.11, 0.035, 0.06)), shoes, Vector3(0, -0.435, 0.08))
		if side < 0.0:
			hip_l = hip
			knee_l = knee
		else:
			hip_r = hip
			knee_r = knee

	# Thân, cổ, đầu.
	chest = _joint(hips, Vector3(0, 0.08, 0))
	_part(chest, _cyl(0.2, 0.17, 0.52), shirt, Vector3(0, 0.26, 0), Vector3.ZERO, Vector3(1, 1, 0.68))
	_part(chest, _cyl(0.205, 0.2, 0.07), Color(shirt).darkened(0.12).to_html(false), Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(1, 1, 0.7))
	_part(chest, _cyl(0.05, 0.055, 0.08), skin, Vector3(0, 0.54, 0))
	head = _joint(chest, Vector3(0, 0.555, 0))
	_part(head, _sphere(0.115, 0.27), skin, Vector3(0, 0.12, 0.005))
	for side in [-1.0, 1.0]:
		_part(head, _sphere(0.016), "1d1a18", Vector3(side * 0.042, 0.135, 0.1))
		_part(head, _box(Vector3(0.045, 0.01, 0.01)), hair, Vector3(side * 0.043, 0.168, 0.102))
		_part(head, _sphere(0.025), skin, Vector3(side * 0.112, 0.12, 0))
	_part(head, _box(Vector3(0.02, 0.035, 0.03)), Color(skin).darkened(0.08).to_html(false), Vector3(0, 0.11, 0.115))
	_part(head, _box(Vector3(0.045, 0.008, 0.01)), "8c4a3c", Vector3(0, 0.07, 0.106))
	match str(look.get("hair_style", "short")):
		"long":
			_part(head, _sphere(0.122, 0.2), hair, Vector3(0, 0.17, -0.01))
			_part(head, _box(Vector3(0.22, 0.32, 0.07)), hair, Vector3(0, 0.03, -0.085))
		"bun":
			_part(head, _sphere(0.122, 0.2), hair, Vector3(0, 0.17, -0.01))
			_part(head, _sphere(0.06), hair, Vector3(0, 0.2, -0.12))
		_:
			_part(head, _sphere(0.123, 0.17), hair, Vector3(0, 0.185, -0.012))
			_part(head, _box(Vector3(0.2, 0.045, 0.06)), hair, Vector3(0, 0.215, 0.07), Vector3(0.35, 0, 0))
	match str(look.get("hat", "none")):
		"non_la":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.01
			cone.bottom_radius = 0.3
			cone.height = 0.2
			cone.radial_segments = 16
			_part(head, cone, "e9d9a6", Vector3(0, 0.33, 0))
		"cap":
			_part(head, _sphere(0.127, 0.16), shirt, Vector3(0, 0.21, -0.005))
			_part(head, _box(Vector3(0.16, 0.015, 0.11)), shirt, Vector3(0, 0.215, 0.13))
		"helmet":
			_part(head, _sphere(0.14, 0.2), "c0392b", Vector3(0, 0.2, 0))

	# Tay: vai, khuỷu; tay áo ngắn thì cẳng tay là da.
	var long_sleeve := str(look.get("sleeve", "short")) == "long"
	for side in [-1.0, 1.0]:
		var sh := _joint(chest, Vector3(side * 0.225, 0.47, 0))
		_part(sh, _sphere(0.07), shirt, Vector3.ZERO)
		_part(sh, _cyl(0.055, 0.048, 0.3), shirt if long_sleeve else skin, Vector3(0, -0.16, 0))
		_part(sh, _cyl(0.066, 0.062, 0.13), shirt, Vector3(0, -0.06, 0))
		var el := _joint(sh, Vector3(0, -0.3, 0))
		_part(el, _cyl(0.046, 0.038, 0.27), shirt if long_sleeve else skin, Vector3(0, -0.135, 0))
		_part(el, _sphere(0.048), skin, Vector3(0, -0.3, 0.01))
		if side < 0.0:
			shoulder_l = sh
			elbow_l = el
		else:
			shoulder_r = sh
			elbow_r = el

	if bool(look.get("bag", false)):
		_part(chest, _box(Vector3(0.3, 0.36, 0.14)), "4a4f3a", Vector3(0, 0.3, -0.19))
		_part(chest, _box(Vector3(0.24, 0.12, 0.05)), "3c4030", Vector3(0, 0.2, -0.27))
		for side in [-1.0, 1.0]:
			_part(chest, _box(Vector3(0.035, 0.42, 0.03)), "2f3326", Vector3(side * 0.11, 0.3, 0.115))


## Gọi mỗi khung hình: moving 0..1 là tốc độ so với đi bộ bình thường.
func animate(delta: float, moving: float) -> void:
	_move = lerpf(_move, clampf(moving, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	if _sitting:
		_pose_sit()
		return
	_phase += delta * lerpf(1.6, 9.5, _move)
	var s := sin(_phase)
	var swing := 0.55 * _move
	hip_l.rotation.x = s * swing
	hip_r.rotation.x = -s * swing
	knee_l.rotation.x = maxf(0.0, -cos(_phase)) * 0.9 * _move
	knee_r.rotation.x = maxf(0.0, cos(_phase)) * 0.9 * _move
	shoulder_l.rotation.x = -s * swing * 0.9
	shoulder_r.rotation.x = s * swing * 0.9
	shoulder_l.rotation.z = -0.08
	shoulder_r.rotation.z = 0.08
	elbow_l.rotation.x = -0.25 - maxf(0.0, s) * 0.5 * _move
	elbow_r.rotation.x = -0.25 - maxf(0.0, -s) * 0.5 * _move
	# Nhún người khi bước, thở nhẹ khi đứng.
	body.position.y = absf(sin(_phase)) * 0.045 * _move + sin(_phase * 0.5) * 0.004 * (1.0 - _move)
	chest.rotation.y = s * 0.08 * _move
	chest.rotation.x = 0.06 * _move
	head.rotation.x = -0.04 * _move


func sit(on: bool) -> void:
	_sitting = on


## Ngồi xe máy: đùi đưa ra trước, cẳng chân thả xuống, hai tay vươn lên tay lái.
func _pose_sit() -> void:
	hip_l.rotation.x = -1.35
	hip_r.rotation.x = -1.35
	knee_l.rotation.x = 1.25
	knee_r.rotation.x = 1.25
	shoulder_l.rotation.x = -1.0
	shoulder_r.rotation.x = -1.0
	elbow_l.rotation.x = -0.4
	elbow_r.rotation.x = -0.4
	body.position.y = -0.42
