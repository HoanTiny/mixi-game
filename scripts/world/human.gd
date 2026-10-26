extends Node3D
## Người thật: nhân vật Microsoft Rocketbox (giấy phép MIT, assets/rb) có xương Biped, mặt, tóc, quần áo chụp
## thật; động tác đứng, đi, ngồi, nói chuyện lấy từ thư viện động tác của Rocketbox (đã đổi sang assets/rb/anims,
## đi tại chỗ). Cùng cách dùng với character.gd: animate(delta, moving), sit(on, hip_h, back), hold(kind),
## add_item(bone, mesh). Gánh, đẩy xe, bưng đồ thì hai tay đặt lại theo tư thế sau khi động tác chạy (_HoldArms).

const ROOT := "res://assets/rb"
## Độ cao khớp hông lúc ngồi ghế trong động tác ngồi của Rocketbox (mét).
const SIT_HIP := 0.6
## Độ cao khớp hông lúc đứng của người lớn trong bộ Rocketbox.
const ADULT_HIP := 0.895
## Tốc độ bước của động tác đi (mét mỗi giây ở speed_scale 1).
const WALK_SPEED := 1.35
## Xương của khung người cũ (character.gd) ứng với xương Biped, để gắn phụ kiện.
const BONE_MAP := {"head": "Bip01 Head", "chest": "Bip01 Spine2", "spine": "Bip01 Spine1", "hips": "Bip01 Pelvis",
	"hand_l": "Bip01 L Hand", "hand_r": "Bip01 R Hand"}
## Vị trí xương tương ứng trong khung người cũ cao 1,72 m (phụ kiện dựng theo khung đó).
const OLD_BONE_POS := {"head": Vector3(0, 1.56, 0), "chest": Vector3(0, 1.3, 0), "spine": Vector3(0, 1.1, 0),
	"hips": Vector3(0, 0.95, 0), "hand_l": Vector3(0.222, 0.895, 0), "hand_r": Vector3(-0.222, 0.895, 0)}

static var _scenes := {}
static var _anims := {}
static var _mats := {}

var look: Dictionary = {}
var _model: Node3D
var _sk: Skeleton3D
var _ap: AnimationPlayer
var _arms: Node
var _state := ""
var _sitting := false
var _hold := ""
var _female := false
var _seen: VisibleOnScreenNotifier3D
var _worn := {}


static func make(look_in: Dictionary) -> Node3D:
	var h = load("res://scripts/world/human.gd").new()
	h.look = look_in
	h._build()
	return h


static func exists(name: String) -> bool:
	return ResourceLoader.exists("%s/%s/%s.fbx" % [ROOT, name, name])


func _build() -> void:
	var name := str(look.rb)
	_female = bool(look.get("female", name.begins_with("Female") or name.contains("_Female")))
	if not _scenes.has(name):
		_scenes[name] = load("%s/%s/%s.fbx" % [ROOT, name, name])
	_model = (_scenes[name] as PackedScene).instantiate()
	add_child(_model)
	_sk = _model.get_node("Skeleton3D")
	# Trẻ em dùng khung Bip02: đổi tên cho khớp động tác người lớn, hạ độ cao hông theo tỉ lệ người.
	if _sk.get_bone_name(0) != "Bip01":
		for i in _sk.get_bone_count():
			_sk.set_bone_name(i, _sk.get_bone_name(i).replace("Bip02", "Bip01"))
		for mi in _sk.find_children("*", "MeshInstance3D", true, false):
			var skin: Skin = (mi as MeshInstance3D).skin
			if skin == null:
				continue
			skin = skin.duplicate()
			for b in skin.get_bind_count():
				skin.set_bind_name(b, skin.get_bind_name(b).replace("Bip02", "Bip01"))
			(mi as MeshInstance3D).skin = skin
	var pelvis := _sk.find_bone("Bip01 Pelvis")
	if pelvis >= 0:
		_sk.motion_scale = _sk.get_bone_global_rest(pelvis).origin.y / ADULT_HIP
	_skin(name, "")
	var head := str(look.get("head", ""))
	if head != "" and head != name and exists(head):
		_swap_head(name, head)
	# Người Việt thấp hơn người mẫu Rocketbox (nam chừng 1,75 m, nữ 1,65 m).
	_model.scale = Vector3.ONE * float(look.get("scale", 1.0))
	# Trình chạy động tác sẵn có trong fbx (rỗng): nạp thư viện đứng, đi, ngồi, nói.
	_ap = _model.get_node_or_null("AnimationPlayer")
	if _ap == null:
		_ap = AnimationPlayer.new()
		_model.add_child(_ap)
	_ap.add_animation_library("rb", _library(_female))
	_ap.play("rb/idle")
	_ap.seek(randf() * 5.0, true)
	_arms = _HoldArms.new()
	_sk.add_child(_arms)
	_accessories()
	# Ra khỏi khung nhìn hay bị ẩn (người dựng sẵn chờ dùng) thì dừng động tác: đỡ tính xương cho cả chục người.
	var vis := VisibleOnScreenNotifier3D.new()
	vis.aabb = AABB(Vector3(-0.6, 0.0, -0.6), Vector3(1.2, 2.0, 1.2))
	vis.screen_entered.connect(_wake.bind(true))
	vis.screen_exited.connect(_wake.bind(false))
	add_child(vis)
	_seen = vis


static func _library(female: bool) -> AnimationLibrary:
	var sex := "f" if female else "m"
	var key := sex
	if _anims.has(key):
		return _anims[key]
	var lib := AnimationLibrary.new()
	for pair in [["idle", "idle_neutral_01"], ["walk", "walk_neutral_01"], ["sit", "sit_chair_idle_neutral_01"], ["talk", "gestic_talk_neutral_01"]]:
		var path := "%s/anims/%s_%s.res" % [ROOT, sex, pair[1]]
		if not ResourceLoader.exists(path):
			continue
		lib.add_animation(pair[0], load(path))
	_anims[key] = lib
	return lib


## Vật liệu theo tên mặt lưới: thân (quần áo, tay chân), đầu (mặt), tóc và mi (ảnh có kênh trong suốt). hair "grey":
## dùng ảnh tóc bạc (tools/viet_look.py) cho đầu và tóc.
func _skin(name: String, hair: String, only: MeshInstance3D = null) -> void:
	for mi in ([only] if only != null else _sk.find_children("*", "MeshInstance3D", true, false)):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for i in mesh.get_surface_count():
			(mi as MeshInstance3D).set_surface_override_material(i, _material(name, _part(mesh, i), hair))


static func _part(mesh: Mesh, i: int) -> String:
	var src := mesh.surface_get_material(i)
	var sname := src.resource_name.to_lower() if src != null else ""
	return "opacity" if sname.contains("opacity") else ("head" if sname.contains("head") else "body")


## Ghép đầu (mặt, tóc, mi) của người head lên thân người name: bỏ mặt lưới đầu, tóc của thân; lưới đầu kia gắn vào
## cùng khung xương theo tên xương (hai người chung bộ xương Biped), nên đi theo cổ, đầu của thân.
func _swap_head(name: String, head: String) -> void:
	for mi in _sk.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).mesh = _parts(name, ["body"])
		_skin(name, "", mi)
	if not _scenes.has(head):
		_scenes[head] = load("%s/%s/%s.fbx" % [ROOT, head, head])
	var src: Node = (_scenes[head] as PackedScene).instantiate()
	var smi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
	var mi := MeshInstance3D.new()
	mi.mesh = _parts(head, ["head", "opacity"])
	mi.skin = smi.skin
	_sk.add_child(mi)
	mi.skeleton = NodePath("..")
	src.free()
	_skin(head, str(look.get("hair_tone", "")), mi)


## Lưới của người name chỉ gồm các mặt thuộc parts (dùng chung giữa những người cùng kiểu).
static func _parts(name: String, parts: Array) -> ArrayMesh:
	var key := "mesh|%s|%s" % [name, ",".join(parts)]
	if _mats.has(key):
		return _mats[key]
	var n: Node = (_scenes[name] as PackedScene).instantiate()
	var mesh: Mesh = (n.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		if _part(mesh, i) not in parts:
			continue
		var arrays := mesh.surface_get_arrays(i)
		# Kênh phụ (custom) của bản nhập fbx không cần cho người: bỏ, khỏi khai kiểu kênh.
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arrays[c] = null
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(i), arrays, [], {},
			mesh.surface_get_format(i) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		out.surface_set_material(out.get_surface_count() - 1, mesh.surface_get_material(i))
	n.free()
	_mats[key] = out
	return out


static func _material(name: String, part: String, hair := "") -> Material:
	var key := name + "|" + part + "|" + hair
	if _mats.has(key):
		return _mats[key]
	var dir := "%s/%s/" % [ROOT, name]
	var m := StandardMaterial3D.new()
	m.roughness = 0.82
	if part == "opacity":
		var tex := dir + ("opacity_grey.png" if hair == "grey" and ResourceLoader.exists(dir + "opacity_grey.png") else "opacity_color.png")
		if ResourceLoader.exists(tex):
			m.albedo_texture = load(tex)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.6
	else:
		var color := dir + part + "_color.jpg"
		if part == "head" and hair == "grey" and ResourceLoader.exists(dir + "head_grey.jpg"):
			color = dir + "head_grey.jpg"
		if not ResourceLoader.exists(color):
			color = dir + "body_color.jpg"
		m.albedo_texture = load(color)
		var nor := dir + part + "_normal.jpg"
		if ResourceLoader.exists(nor):
			m.normal_enabled = true
			m.normal_texture = load(nor)
	_mats[key] = m
	return m


## Nón lá, nón kết, mũ bảo hiểm, ba lô, tạp dề: lưới của character.gd dựng theo khung cũ, gắn theo xương Biped.
func _accessories() -> void:
	var Character = load("res://scripts/world/character.gd")
	match str(look.get("hat", "none")):
		"non_la":
			_attach("head", Character._acc("non_la"), Color("e3d3a0"))
		"cap":
			_attach("head", Character._acc("cap"), Color(str(look.get("shirt", "3f6f8f"))).darkened(0.1))
		"helmet":
			_attach("head", Character._acc("helmet"), Color(str(look.get("helmet", "c0392b"))))


func add_item(bone: String, mesh: Mesh) -> void:
	_attach(bone, mesh, Color(1, 1, 1))


## Gắn lưới theo xương: bù hướng nghỉ của xương Biped (trục x dọc xương) để lưới giữ hướng như ở khung cũ, chỉ đi
## theo chuyển động của xương.
func _attach(bone: String, mesh: Mesh, tint: Color) -> Node3D:
	var bname: String = BONE_MAP.get(bone, "Bip01 Spine2")
	var idx := _sk.find_bone(bname)
	if idx < 0:
		return null
	var ba := BoneAttachment3D.new()
	ba.bone_name = bname
	_sk.add_child(ba)
	var fix := Node3D.new()
	var rest := _sk.get_bone_global_rest(idx)
	fix.transform = Transform3D(rest.basis.inverse(), Vector3.ZERO)
	ba.add_child(fix)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.roughness = 0.75
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	# Lưới dựng quanh vị trí xương ở khung cũ; dời về gốc xương, bù chênh chiều cao đầu.
	var old: Vector3 = OLD_BONE_POS.get(bone, Vector3(0, 1.3, 0))
	mi.position = -old + (Vector3(0, 0.06, 0) if bone == "head" else Vector3.ZERO)
	fix.add_child(mi)
	return ba


## Đội, cởi đồ thêm lúc đang chơi (mũ bảo hiểm khi lên xe máy): dựng lần đầu, sau đó chỉ bật tắt.
func wear(kind: String, on: bool, tint := Color("2f6fb0")) -> void:
	if on and not _worn.has(kind):
		var Character = load("res://scripts/world/character.gd")
		_worn[kind] = _attach("head", Character._acc(kind), tint)
	if _worn.get(kind) != null:
		(_worn[kind] as Node3D).visible = on


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _ap != null:
		_wake(_seen == null or _seen.is_on_screen())


func _wake(on_screen: bool) -> void:
	_ap.active = on_screen and is_visible_in_tree()


func animate(_delta: float, moving: float) -> void:
	var want := "sit" if _sitting else ("walk" if moving > 0.12 else "idle")
	if want == "idle" and bool(look.get("talker", false)) and _ap.has_animation("rb/talk"):
		want = "talk"
	if want != _state:
		_ap.play("rb/" + want, 0.25)
		_state = want
	# Người trong game đi nhanh hơn người thật (bản đồ thu nhỏ): bước nhanh theo, không trượt chân quá nhiều.
	_ap.speed_scale = clampf(moving * 1.6, 0.7, 2.6) if want == "walk" else 1.0


## Ngồi: hip_h là độ cao khớp hông so với gốc người (ghế đẩu, yên xe); hạ hay nâng cả người cho khớp.
func sit(on: bool, hip_h := 0.93, _back := false) -> void:
	_sitting = on
	_model.position.y = (hip_h - SIT_HIP * _model.scale.y) if on else 0.0
	animate(0.0, 0.0)


## "push": đẩy xe, bưng đồ trước bụng; "carry": tay phải giữ đòn gánh trên vai; "ride": nắm tay lái xe máy; "": tay
## theo động tác.
func hold(kind: String) -> void:
	_hold = kind
	_arms.kind = kind


## Đặt lại hai tay sau khi động tác chạy: cánh tay, cẳng tay, bàn tay chỉ theo hướng muốn (không gian người,
## mặt nhìn +z, bên trái là +x).
class _HoldArms extends SkeletonModifier3D:
	var kind := ""

	func _process_modification_with_delta(_d: float) -> void:
		_apply()

	func _process_modification() -> void:
		_apply()

	func _apply() -> void:
		if kind == "":
			return
		var sk := get_skeleton()
		if sk == null:
			return
		for side in ["L", "R"]:
			var s := 1.0 if side == "L" else -1.0
			var up_dir: Vector3
			var fore_dir: Vector3
			if kind == "carry":
				if side == "L":
					continue
				up_dir = Vector3(-0.35, -0.15, 0.55)
				fore_dir = Vector3(0.15, 0.85, -0.25)
			elif kind == "ride":
				# Lái xe máy: vai xuống chéo ra trước tới tay lái.
				up_dir = Vector3(s * 0.18, -0.6, 0.78)
				fore_dir = Vector3(s * 0.05, -0.25, 0.97)
			else:
				up_dir = Vector3(s * 0.1, -0.78, 0.6)
				fore_dir = Vector3(-s * 0.12, 0.08, 1.0)
			_chain(sk, "Bip01 %s UpperArm" % side, "Bip01 %s Forearm" % side, "Bip01 %s Hand" % side, up_dir.normalized(), fore_dir.normalized())

	func _chain(sk: Skeleton3D, upper: String, fore: String, hand: String, d1: Vector3, d2: Vector3) -> void:
		var iu := sk.find_bone(upper)
		var iff := sk.find_bone(fore)
		var ih := sk.find_bone(hand)
		if iu < 0 or iff < 0 or ih < 0:
			return
		var ru := sk.get_bone_global_rest(iu)
		var rf := sk.get_bone_global_rest(iff)
		var rh := sk.get_bone_global_rest(ih)
		var lu := ru.origin.distance_to(rf.origin)
		var lf := rf.origin.distance_to(rh.origin)
		var origin := sk.get_bone_global_pose(iu).origin
		var bu := Basis(Quaternion(ru.basis.x.normalized(), d1)) * ru.basis
		sk.set_bone_global_pose(iu, Transform3D(bu, origin))
		var of := origin + d1 * lu
		var bf := Basis(Quaternion(rf.basis.x.normalized(), d2)) * rf.basis
		sk.set_bone_global_pose(iff, Transform3D(bf, of))
		var bh := Basis(Quaternion(rh.basis.x.normalized(), d2)) * rh.basis
		sk.set_bone_global_pose(ih, Transform3D(bh, of + d2 * lf))
