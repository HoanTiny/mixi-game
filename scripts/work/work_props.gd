extends RefCounted
## Đồ vật cho chỗ làm 3D: mô hình chụp từ đồ thật và vật liệu PBR của Poly Haven (CC0, assets/ph), cộng vài món dựng
## bằng khối (pallet gỗ, cuộn dây, bó ống, bao gạo, quạt, nồi cơm, máy bơm, bàn ủi, tô cơm, ly trà đá) phủ vật liệu thật.

const ROOT := "res://assets/ph"

static var _scenes := {}
static var _mats := {}


## Mô hình glTF của Poly Haven, gốc ở đáy, mét thật; scale để chỉnh cỡ.
static func model(name: String, scale := 1.0) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load("%s/models/%s/%s.gltf" % [ROOT, name, name])
	var n: Node3D = (_scenes[name] as PackedScene).instantiate()
	if scale != 1.0:
		n.scale = Vector3.ONE * scale
	var holder := Node3D.new()
	holder.add_child(n)
	return holder


## Vật liệu PBR lặp lại tile lần trên mỗi mét (texture Poly Haven: diff, nor_gl, arm = AO/roughness/metal).
static func tex(name: String, tile := 1.0, tint := Color(1, 1, 1)) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, tile, tint.to_html()]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	var base := "%s/textures/%s/%s" % [ROOT, name, name]
	m.albedo_texture = load(base + "_diff.jpg")
	m.albedo_color = tint
	if ResourceLoader.exists(base + "_nor.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "_nor.jpg")
	if ResourceLoader.exists(base + "_arm.jpg"):
		var arm: Texture2D = load(base + "_arm.jpg")
		m.roughness_texture = arm
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.metallic_texture = arm
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		m.ao_enabled = true
		m.ao_texture = arm
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * tile
	_mats[key] = m
	return m


static func plain(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


static func box(parent: Node3D, size: Vector3, mat: Material, pos: Vector3, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos + Vector3(0, size.y / 2.0, 0)
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r: float, h: float, mat: Material, pos: Vector3, axis := Vector3.UP, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	if axis == Vector3.RIGHT:
		mi.rotation.z = PI / 2.0
	elif axis == Vector3.BACK:
		mi.rotation.x = PI / 2.0
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- món dựng sẵn

## Pallet gỗ 1,2 × 1,0 m: ba thanh đế, chín cục kê, bảy nan mặt.
static func pallet() -> Node3D:
	var n := Node3D.new()
	var wood := tex("brown_planks_05", 1.2, Color(1.0, 0.92, 0.8))
	for x in [-0.5, 0.0, 0.5]:
		box(n, Vector3(0.1, 0.022, 1.0), wood, Vector3(x, 0, 0))
		for z in [-0.42, 0.0, 0.42]:
			box(n, Vector3(0.1, 0.08, 0.14), wood, Vector3(x, 0.022, z))
	for i in 7:
		box(n, Vector3(1.2, 0.022, 0.1), wood, Vector3(0, 0.102, -0.45 + i * 0.15))
	return n


## Bao gạo 50 kg: bao dứa trắng ngà, hơi phồng (col: bao lưới rau, bao khoai, bao dép màu khác).
static func sack(col := Color("ddd3b8")) -> Node3D:
	var n := Node3D.new()
	var weave := plain(col, 0.95)
	box(n, Vector3(0.42, 0.16, 0.66), weave, Vector3.ZERO)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	mi.mesh = sm
	mi.scale = Vector3(0.44, 0.1, 0.62)
	mi.position.y = 0.16
	mi.material_override = weave
	n.add_child(mi)
	box(n, Vector3(0.3, 0.004, 0.1), plain(Color("2f6fb0")), Vector3(0, 0.205, -0.12))
	return n


## Cuộn dây điện: lõi gỗ hai bích, dây cam quấn quanh.
static func spool() -> Node3D:
	var n := Node3D.new()
	var wood := tex("brown_planks_05", 2.0)
	cyl(n, 0.22, 0.04, wood, Vector3(-0.13, 0.22, 0), Vector3.RIGHT)
	cyl(n, 0.22, 0.04, wood, Vector3(0.13, 0.22, 0), Vector3.RIGHT)
	cyl(n, 0.16, 0.22, plain(Color("e0672a"), 0.6), Vector3(0, 0.22, 0), Vector3.RIGHT)
	return n


## Bó ống luồn dây PVC xám, cột hai sợi dây.
static func pipes() -> Node3D:
	var n := Node3D.new()
	var pvc := plain(Color("b8bcc2"), 0.45)
	for i in 6:
		cyl(n, 0.025, 1.0, pvc, Vector3(-0.06 + (i % 3) * 0.06, 0.03 + (i / 3) * 0.05, 0), Vector3.BACK)
	for z in [-0.3, 0.3]:
		cyl(n, 0.1, 0.02, plain(Color("2b2b2b")), Vector3(0, 0.05, z), Vector3.BACK)
	return n


## Quạt bàn: đế tròn, thân, lồng quạt xanh.
static func fan() -> Node3D:
	return preload("res://scripts/work/repair_models.gd").fan()


static func kettle() -> Node3D:
	return preload("res://scripts/work/repair_models.gd").kettle()


static func rice_cooker() -> Node3D:
	var n := Node3D.new()
	cyl(n, 0.17, 0.22, plain(Color("f2efe8"), 0.35), Vector3(0, 0.11, 0))
	cyl(n, 0.16, 0.06, plain(Color("cfd3d8"), 0.3, 0.6), Vector3(0, 0.25, 0), Vector3.UP, 0.1)
	box(n, Vector3(0.08, 0.05, 0.03), plain(Color("c0392b")), Vector3(0, 0.08, 0.17))
	return n


static func pump() -> Node3D:
	var n := Node3D.new()
	box(n, Vector3(0.3, 0.04, 0.22), plain(Color("2b2b2b")), Vector3.ZERO)
	cyl(n, 0.09, 0.26, plain(Color("2e8b57"), 0.5, 0.3), Vector3(-0.03, 0.13, 0), Vector3.RIGHT)
	cyl(n, 0.08, 0.06, plain(Color("8a8f98"), 0.4, 0.7), Vector3(0.14, 0.13, 0), Vector3.RIGHT)
	return n


static func iron() -> Node3D:
	var n := Node3D.new()
	box(n, Vector3(0.14, 0.03, 0.24), plain(Color("c8ccd2"), 0.25, 0.8), Vector3.ZERO)
	box(n, Vector3(0.11, 0.07, 0.2), plain(Color("8e44ad"), 0.5), Vector3(0, 0.03, 0))
	box(n, Vector3(0.03, 0.05, 0.14), plain(Color("2b2b2b")), Vector3(0, 0.1, 0))
	return n


## Tô cơm (tô sứ trắng viền xanh, cơm, miếng sườn), tô canh chua (nước cam), ly trà đá.
static func dish(kind: String) -> Node3D:
	var n := Node3D.new()
	match kind:
		"tra":
			var glass := plain(Color(0.85, 0.75, 0.45, 0.75), 0.1)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cyl(n, 0.04, 0.12, glass, Vector3(0, 0.06, 0), Vector3.UP, 0.05)
		"bia":
			# Cốc bia hơi thủy tinh xanh, bọt trắng.
			var glass := plain(Color(0.78, 0.62, 0.22, 0.85), 0.1)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			cyl(n, 0.05, 0.15, glass, Vector3(0, 0.075, 0), Vector3.UP, 0.06)
			cyl(n, 0.06, 0.03, plain(Color("f6f1e4"), 0.9), Vector3(0, 0.16, 0))
		"lac", "nem":
			# Đĩa nhựa, lạc rang nâu hay nem chua rán vàng.
			cyl(n, 0.11, 0.015, plain(Color("f4f4f0"), 0.3), Vector3(0, 0.008, 0))
			for i in 5:
				var a := TAU * i / 5.0
				if kind == "nem":
					box(n, Vector3(0.07, 0.03, 0.03), plain(Color("d08a3a"), 0.7), Vector3(cos(a) * 0.05, 0.03, sin(a) * 0.05), a)
				else:
					box(n, Vector3(0.025, 0.02, 0.02), plain(Color("9a5a2a"), 0.8), Vector3(cos(a) * 0.04, 0.025, sin(a) * 0.04), a)
		_:
			cyl(n, 0.06, 0.08, plain(Color("f4f4f0"), 0.25), Vector3(0, 0.04, 0), Vector3.UP, 0.1)
			cyl(n, 0.095, 0.01, plain(Color("2f6fb0"), 0.3), Vector3(0, 0.08, 0))
			var top := plain(Color("f6f1e4"), 0.8) if kind == "com" else plain(Color("e07a3c"), 0.2)
			cyl(n, 0.088, 0.02, top, Vector3(0, 0.075, 0))
			if kind == "com":
				box(n, Vector3(0.08, 0.025, 0.05), plain(Color("8a4a24"), 0.6), Vector3(0.02, 0.08, 0))
	return n


## Tô màu mọi mặt lưới của một mô hình (thùng nhựa đỏ đựng cà chua…).
static func _tint(n: Node, c: Color) -> void:
	for ch in n.find_children("*", "MeshInstance3D", true, false):
		(ch as MeshInstance3D).material_override = plain(c, 0.6)


## Chồng bát dơ: ba tô úp lên nhau, dính vụn.
static func dirty_stack() -> Node3D:
	var n := Node3D.new()
	for i in 3:
		cyl(n, 0.06, 0.07, plain(Color("ece8dc"), 0.3), Vector3(0, 0.035 + i * 0.05, 0), Vector3.UP, 0.1)
	cyl(n, 0.07, 0.01, plain(Color("9a7a4a"), 0.9), Vector3(0, 0.18, 0))
	return n


## Bàn inox thấp của quán cơm vỉa hè.
static func steel_table() -> Node3D:
	var n := Node3D.new()
	var steel := plain(Color("c9ced4"), 0.25, 0.85)
	box(n, Vector3(1.2, 0.03, 0.75), steel, Vector3(0, 0.72, 0))
	for x in [-0.55, 0.55]:
		for z in [-0.32, 0.32]:
			cyl(n, 0.02, 0.72, steel, Vector3(x, 0.36, z))
	return n


## Món đang cầm hay đặt xuống, theo khóa loại hàng.
static func item(key: String) -> Node3D:
	match key:
		"mi":
			return model("cardboard_box_01")
		"nuoc":
			return model("plastic_crate_03", 1.2)
		"gao":
			return sack()
		"day":
			return spool()
		"ong":
			return pipes()
		"cb":
			return model("power_box_01", 0.7)
		"com", "canh", "tra", "bia", "lac", "nem":
			return dish(key)
		# Chợ đầu mối, chợ Đồng Xuân (bốc vác, xe thồ).
		"rau":
			return sack(Color("6f9a4a"))
		"cu":
			return sack(Color("b89a6a"))
		"qua":
			var crate := model("plastic_crate_03", 1.2)
			_tint(crate, Color("c0503a"))
			return crate
		"vai":
			var n := Node3D.new()
			cyl(n, 0.13, 0.7, plain(Color("b04a6a"), 0.9), Vector3(0, 0.13, 0), Vector3.RIGHT)
			return n
		"dep":
			return sack(Color("4a6ab0"))
		"thung":
			return model("cardboard_box_01", 0.9)
		"dirty":
			return dirty_stack()
		"Quạt bàn":
			return fan()
		"Nồi cơm điện":
			return rice_cooker()
		"Máy bơm":
			return pump()
		"Bàn là":
			return iron()
	return model("cardboard_box_01", 0.5)


## Chiều cao một món khi chồng lên nhau.
static func item_h(key: String) -> float:
	return {"mi": 0.34, "nuoc": 0.33, "gao": 0.2, "day": 0.44, "ong": 0.1, "cb": 0.35, "dirty": 0.2, "rau": 0.2, "cu": 0.2,
		"qua": 0.33, "vai": 0.26, "dep": 0.2, "thung": 0.3}.get(key, 0.14)
