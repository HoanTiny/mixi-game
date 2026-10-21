extends Node3D
## Lớp cảnh ngày mưa (15 và 29): rạch dâng tràn bờ, chỗ trũng ven rạch ngập, vũng nước trên đường,
## nước bắn quanh chân An, An che dù, phố vắng bớt người. Mức 1 (ngày 15) ngập Hẻm Bờ Nam;
## mức 2 (ngày 29, mưa dài từ sáng) ngập thêm đường Bờ Me và khúc cuối các hẻm đổ ra rạch.
## Trước xóm trọ là thùng đồ của nhà: có che hay không tùy việc chuẩn bị ngày 14, 23, 28.

const FLOOD_Y := 0.2
## Lội nước: đi chậm hơn, và mỗi mét tính giờ nhiều hơn.
const WADE_SPEED := 0.6
const WADE_COST := 1.6

var world
var level := 0
var _floods := {1: [], 2: []}
var _nodes := {}
var _splash: CPUParticles3D
var _umbrella: Node3D
var _yard: Node3D
var _yard_key := ""
var _ripple_rects := {1: [], 2: []}
var _ripples: Array[CPUParticles3D] = []
## Vùng quanh An có gợn nước (rộng hơn khung hình một chút).
const VIEW := Vector2(36, 26)


func build() -> void:
	var city = world.city
	var water := StandardMaterial3D.new()
	# Nước ngập ở Sài Gòn đục màu phù sa, không trong.
	water.albedo_color = Color(0.38, 0.34, 0.26, 0.82)
	water.roughness = 0.05
	water.metallic = 0.3
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var muddy := StandardMaterial3D.new()
	muddy.albedo_color = Color("4a4636")
	muddy.roughness = 0.08
	muddy.metallic = 0.2
	for l in [1, 2]:
		var n := Node3D.new()
		n.name = "mua_%d" % l
		n.visible = false
		add_child(n)
		_nodes[l] = n
	# Rạch tràn bờ: mặt nước phủ hết hai bãi cỏ, bùn ven rạch; chỉ còn lề đá kè nhô lên.
	if city.streets.has("bo_me") and city.streets.has("bo_nam"):
		var z0: float = city.streets.bo_me.rect.end.y
		var z1: float = city.streets.bo_nam.rect.position.y
		var w: float = city.bounds.size.x + 60.0
		var bank := Rect2(city.bounds.position.x - 30.0, z0, w, z1 - z0)
		_plane(bank, 0.08, muddy, _nodes[1])
		_ripple_rects[1] = [bank]
		_ripple_rects[2] = [bank]
	# Chỗ trũng: Hẻm Bờ Nam ngập từ ngày 15; ngày 29 ngập cả đường Bờ Me và đáy các hẻm.
	if city.streets.has("bo_nam"):
		_flood(city.streets.bo_nam.rect, 1, water)
	if city.streets.has("bo_me"):
		var r: Rect2 = city.streets.bo_me.rect
		_flood(r, 2, water)
		for id in city.order:
			var st: Dictionary = city.streets[id]
			if st.axis == "z" and str(st.kind) in ["hem", "cho"] and absf(float(st.hi) - r.position.y) < 1.0:
				var sr: Rect2 = st.rect
				_flood(Rect2(sr.position.x, r.position.y - 9.0, sr.size.x, 9.0), 2, water)
	_build_puddles()
	_build_splash()
	for i in _ripple_rects[2].size():
		_ripples.append(_ripple_emitter())
	_build_umbrella()


## Vùng ngập ở mức l (và mọi mức cao hơn).
func _flood(r: Rect2, l: int, mat: Material) -> void:
	_plane(r, FLOOD_Y, mat, _nodes[l])
	for k in _floods:
		if k >= l:
			_floods[k].append(r)
			_ripple_rects[k].append(r)


func _plane(r: Rect2, y: float, mat: Material, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(r.get_center().x, y, r.get_center().y)
	parent.add_child(mi)


## Vũng nước trên mặt đường nhựa và trong hẻm: hình bầu dục, bóng loáng.
func _build_puddles() -> void:
	var city = world.city
	var rng := RandomNumberGenerator.new()
	rng.seed = 1529
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.25, 0.26, 0.82)
	mat.roughness = 0.03
	mat.metallic = 0.3
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for id in city.order:
		var st: Dictionary = city.streets[id]
		var kind := str(st.kind)
		if not kind in ["duong", "cho", "bo_ke", "hem", "hem_nho"]:
			continue
		var r: Rect2 = st.rect
		var horiz: bool = st.axis == "x"
		var cross: float = r.size.y if horiz else r.size.x
		var span: float = r.size.x if horiz else r.size.y
		# Đường lớn: vũng nằm trên phần lòng đường (thấp hơn vỉa hè); hẻm: khắp mặt hẻm.
		var road: float = float(st.get("road", cross)) if kind in ["duong", "cho", "bo_ke"] else cross
		var y := 0.055 if kind in ["duong", "cho", "bo_ke"] else 0.065
		for i in int(span / 9.0):
			var u := rng.randf_range(0.0, span)
			var v := rng.randf_range(-road / 2.0 + 0.6, road / 2.0 - 0.6)
			var p := Vector2(r.position.x + u, r.get_center().y + v) if horiz else Vector2(r.get_center().x + v, r.position.y + u)
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.0
			cm.bottom_radius = 1.0
			cm.height = 0.01
			cm.radial_segments = 14
			cm.rings = 1
			mi.mesh = cm
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.scale = Vector3(rng.randf_range(0.5, 1.6), 1.0, rng.randf_range(0.4, 1.0))
			mi.rotation.y = rng.randf() * TAU
			mi.position = Vector3(p.x, y, p.y)
			_nodes[1].add_child(mi)


## Nước bắn lên quanh chân An khi mưa rơi xuống mặt đường.
func _build_splash() -> void:
	_splash = CPUParticles3D.new()
	_splash.amount = 260
	_splash.lifetime = 0.3
	_splash.local_coords = false
	_splash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_splash.emission_box_extents = Vector3(13, 0.02, 9)
	_splash.direction = Vector3.UP
	_splash.spread = 35.0
	_splash.initial_velocity_min = 1.0
	_splash.initial_velocity_max = 2.0
	_splash.gravity = Vector3(0, -9.8, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.05
	drop.radial_segments = 4
	drop.rings = 2
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(0.85, 0.9, 0.95, 0.55)
	drop.material = dm
	_splash.mesh = drop
	_splash.emitting = false
	_splash.visible = false
	add_child(_splash)


## Gợn tròn loang ra chỗ mưa rơi xuống mặt nước ngập.
func _ripple_emitter() -> CPUParticles3D:
	var e := CPUParticles3D.new()
	e.amount = 140
	e.lifetime = 0.7
	e.local_coords = false
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	e.gravity = Vector3.ZERO
	e.initial_velocity_min = 0.0
	e.initial_velocity_max = 0.0
	e.emitting = false
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	ring.rings = 12
	ring.ring_segments = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	ring.material = m
	e.mesh = ring
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.05))
	grow.add_point(Vector2(1, 0.4))
	e.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.set_color(0, Color(0.9, 0.92, 0.95, 0.4))
	fade.set_color(1, Color(0.9, 0.92, 0.95, 0.0))
	e.color_ramp = fade
	add_child(e)
	return e


## Cây dù của An: cán và tán xanh đậm, chỉ hiện khi trời mưa.
func _build_umbrella() -> void:
	_umbrella = Node3D.new()
	_umbrella.visible = false
	world._block(Vector3(0.03, 0.85, 0.03), Vector3(0.18, 1.2, 0.05), Color("2b2b2b"), _umbrella)
	var canopy := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.72
	cm.height = 0.28
	cm.radial_segments = 8
	canopy.mesh = cm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("1f3f6a")
	mat.roughness = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = mat
	canopy.position = Vector3(0.18, 2.12, 0.05)
	_umbrella.add_child(canopy)
	world.player.add_child(_umbrella)


## Bật hay tắt cảnh mưa ở mức l (0 là tạnh). flags: cờ của ván chơi, để dựng thùng đồ trước xóm trọ.
func apply(l: int, flags: Dictionary) -> void:
	level = l
	for k in _nodes:
		_nodes[k].visible = l >= int(k)
	_splash.emitting = l > 0
	_splash.visible = l > 0
	for e in _ripples:
		if l == 0:
			e.emitting = false
	_umbrella.visible = l > 0
	# Phố vắng bớt: hai phần ba người đi bộ và một nửa xe trú mưa.
	for i in world.walkers.size():
		world.walkers[i].node.visible = l == 0 or i % 3 == 0
	for i in world.bikes.size():
		world.bikes[i].node.visible = l == 0 or i % 2 == 0
	var key := "" if l == 0 else "%d:%s" % [l, _prep_state(l, flags)]
	# Đồ phơi: đã chuẩn bị thì cất vô từ trước, chưa thì còn ướt sũng trên dây.
	for c in get_tree().get_nodes_in_group("do_phoi"):
		c.visible = l == 0 or _prep_state(l, flags) == "uot"
	if key != _yard_key:
		_yard_key = key
		_build_yard(l, flags)


func _process(_delta: float) -> void:
	if level <= 0 or world.player == null:
		return
	var pp: Vector3 = world.player.position
	_splash.position = pp + Vector3(0, 0.12, 0)
	# Mỗi vùng nước một bộ gợn, chỉ phát trong phần vùng nước nằm quanh An.
	var view := Rect2(Vector2(pp.x, pp.z) - VIEW / 2.0, VIEW)
	var rects: Array = _ripple_rects[mini(level, 2)]
	for i in _ripples.size():
		var e := _ripples[i]
		var on := i < rects.size() and (rects[i] as Rect2).intersects(view)
		if on:
			var r: Rect2 = (rects[i] as Rect2).intersection(view)
			var y := 0.09 if i == 0 else FLOOD_Y + 0.01
			e.position = Vector3(r.get_center().x, y, r.get_center().y)
			e.emission_box_extents = Vector3(r.size.x / 2.0, 0.0, r.size.y / 2.0)
		if e.emitting != on:
			e.emitting = on


## Đang đứng trong chỗ ngập không.
func wading(p: Vector2) -> bool:
	if level <= 0:
		return false
	for r in _floods[mini(level, 2)]:
		if r.has_point(p):
			return true
	return false


## Vùng ngập hôm nay, để bản đồ tô màu.
func flood_rects() -> Array:
	return [] if level <= 0 else _floods[mini(level, 2)]


## "tot": đồ đã kê cao, phủ bạt; "mot_phan": Linh che phần của em và bà; "uot": chưa che gì.
func _prep_state(l: int, flags: Dictionary) -> String:
	if flags.get("chuanBiNha", false):
		return "tot"
	if l >= 2 and (flags.get("phuXom23", false) or flags.get("haiDot", false)):
		return "tot"
	if flags.get("linhCheDo", false):
		return "mot_phan"
	return "uot"


## Thùng đồ trước xóm trọ: ngày 15 vài thùng, ngày 29 cả chồng thùng chuyển nhà xếp ngoài hiên.
func _build_yard(l: int, flags: Dictionary) -> void:
	if _yard != null:
		_yard.queue_free()
		_yard = null
	if l <= 0 or not world.city.locs.has(world.HOME):
		return
	var p: Dictionary = world.city.locs[world.HOME]
	_yard = Node3D.new()
	add_child(_yard)
	var home: Node3D = world._frame_node(p)
	_yard.add_child(home)
	var state := _prep_state(l, flags)
	var half := float(p.w) / 2.0
	var cols := 3 if l >= 2 else 2
	var rows := 2 if l >= 2 else 1
	var x0 := -half + 0.9
	var dry := Color("b08a5a")
	var wet := Color("6e5638")
	for c in cols:
		for r in rows:
			var covered := state == "tot" or (state == "mot_phan" and c == 0)
			var lift := 0.36 if covered else 0.16
			var pos := Vector3(x0 + c * 0.68, lift + r * 0.46, 0.55)
			world._block(Vector3(0.62, 0.44, 0.52), pos, dry if covered else wet, home)
	if state != "uot":
		# Gạch kê và tấm bạt xanh trùm kín phần đã che.
		var n := cols if state == "tot" else 1
		var width := n * 0.68 + 0.1
		var cx := x0 + (n - 1) * 0.34
		for bx in [cx - width / 2.0 + 0.2, cx + width / 2.0 - 0.2]:
			world._block(Vector3(0.22, 0.2, 0.5), Vector3(bx, 0.16, 0.55), Color("9a4a3a"), home)
		var tarp: MeshInstance3D = world._block(Vector3(width, 0.04, 0.72), Vector3(cx, 0.36 + rows * 0.46, 0.55), Color("2f6fb0"), home)
		tarp.rotation.z = 0.04
		for sz in [0.2, 0.9]:
			world._block(Vector3(width, rows * 0.46 + 0.1, 0.03), Vector3(cx, 0.3, sz), Color("2f6fb0"), home)
	if state != "tot":
		# Chưa che: nước dột từ mái tôn, thau nhựa hứng, vũng nước quanh chân thùng.
		var basin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.32
		cm.bottom_radius = 0.24
		cm.height = 0.18
		basin.mesh = cm
		basin.material_override = world._mat_cached(Color("c8503f"))
		basin.position = Vector3(x0 + cols * 0.68 + 0.3, 0.25, 0.9)
		home.add_child(basin)
		var pud := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.0
		pm.bottom_radius = 1.0
		pm.height = 0.01
		pud.mesh = pm
		var pmat := StandardMaterial3D.new()
		pmat.albedo_color = Color(0.25, 0.27, 0.27, 0.8)
		pmat.roughness = 0.03
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pud.material_override = pmat
		pud.scale = Vector3(1.4, 1, 0.6)
		pud.position = Vector3(x0 + cols * 0.34, 0.165, 0.9)
		home.add_child(pud)
	# Ngày 14 chia việc cho cả xóm: nhà hàng xóm dọc Bờ Me cũng phủ bạt đồ trước cửa.
	if flags.get("chiaViec14", false):
		var rng := RandomNumberGenerator.new()
		rng.seed = 14
		for q in world.city.plots:
			if q.loc != "" or str(q.street) != "bo_me" or (q.center as Vector2).distance_to(p.center) > 28.0 or rng.randf() < 0.4:
				continue
			var n: Node3D = world._frame_node(q)
			_yard.add_child(n)
			world._block(Vector3(0.9, 0.55, 0.6), Vector3(rng.randf_range(-1.0, 1.0), 0.16, 0.45), Color("2f6fb0"), n)

