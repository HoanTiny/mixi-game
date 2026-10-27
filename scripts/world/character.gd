extends Node3D
## Nhân vật 3D: một lưới liền bo tròn gắn khung xương (Skeleton3D), cử động mềm ở vai, khuỷu, hông, gối.
## Lưới dựng bằng code theo dáng nam hay nữ: thân, cổ, cổ áo, tay, bàn tay có ngón cái, chân, bàn chân đi dép,
## đầu có mắt, mày, mũi, miệng, tai, tóc theo kiểu. Mỗi dáng và kiểu tóc chỉ dựng một lần rồi dùng chung; màu da,
## áo, quần, dép, tóc, độ dài tay áo, ống quần, gấu áo là tham số shader nên mỗi người một vẻ mà không dựng lại lưới.
## Nón lá, nón kết, mũ bảo hiểm, ba lô, tạp dề gắn theo xương đầu, ngực, lưng.
##
## look: skin, hair, hair_style (short | long | bun | ponytail), shirt, sleeve (short | long), pants, legs (long |
##       shorts), shoes, footwear (sandals | shoes), hat (none | non_la | cap | helmet), helmet (màu mũ bảo hiểm),
##       bag, apron, tunic (áo dài qua hông như áo bà ba), female, height (mét), build (độ đậm người, 0.9–1.15)
## Tư thế: sit (lái xe máy hay ngồi sau), hold (đẩy xe đẩy bằng hai tay, tay phải giữ đòn gánh trên vai).

const LOOKS := {
	# An, 27 tuổi, thợ sửa điện máy: áo thun xám xanh, quần kaki, dép quai hậu, ba lô đồ nghề.
	"AN": {"rb": "Male_Adult_09", "head": "Male_Adult_09", "scale": 0.96,
		"skin": "d1a07a", "hair": "1b1714", "hair_style": "short", "shirt": "5b7f8f", "sleeve": "short",
		"pants": "5e5446", "shoes": "3b3b3b", "hat": "none", "bag": true, "height": 1.72, "build": 1.02},
	# Linh, 20 tuổi: áo đồng phục trường nghề xanh, quần jean, giày trắng, tóc cột đuôi ngựa.
	"LINH": {"rb": "Female_Adult_12", "head": "Sports_Female_02", "scale": 0.95,
		"skin": "e2b48f", "hair": "1b1714", "hair_style": "ponytail", "shirt": "4f8fb5", "sleeve": "short",
		"pants": "3b5b82", "shoes": "f2f0ea", "footwear": "shoes", "hat": "none", "bag": true, "height": 1.58,
		"build": 0.94, "female": true},
	# Bà Tư, 70 tuổi: áo bà ba tím dài qua hông, quần đen, tóc bạc búi.
	"BA_TU": {"rb": "Female_Adult_02", "head": "Business_Female_03", "scale": 0.92, "hair_tone": "grey",
		"skin": "c99a76", "hair": "d8d8d8", "hair_style": "bun", "shirt": "8a6f9a", "sleeve": "long",
		"pants": "1f1f24", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.5, "build": 0.95,
		"female": true, "tunic": true},
	# Chị Hạnh: áo thun cam, tạp dề, tóc búi.
	"HANH": {"rb": "Chef_Female_01", "head": "Chef_Female_01", "scale": 0.95,
		"skin": "d8a27a", "hair": "2b211b", "hair_style": "bun", "shirt": "c0603a", "sleeve": "short",
		"pants": "2c2f3a", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.58, "build": 1.04,
		"female": true, "apron": true},
	# Chú Sáu: sơ mi xanh bạc màu dài tay, quần kaki, nón kết.
	"SAU": {"rb": "Male_Adult_14", "head": "Business_Male_02", "scale": 0.95, "hair_tone": "grey",
		"skin": "b97d55", "hair": "9a9a9a", "hair_style": "short", "shirt": "3f6f8f", "sleeve": "long",
		"pants": "6d5d4b", "shoes": "3b3b3b", "hat": "cap", "bag": false, "height": 1.64, "build": 1.08},
	# Minh, tài xế giao hàng: áo khoác xanh, mũ bảo hiểm, giày.
	"MINH": {"rb": "Male_Adult_10", "head": "Male_Adult_10", "scale": 0.97,
		"skin": "c98f63", "hair": "1b1714", "hair_style": "short", "shirt": "2f8a5a", "sleeve": "long",
		"pants": "2c3e50", "shoes": "f5f5f5", "footwear": "shoes", "hat": "helmet", "bag": false, "height": 1.74,
		"build": 1.04},
	# Cô Duyên: áo sơ mi hoa, quần tây.
	"DUYEN": {"rb": "Female_Adult_05", "head": "Female_Adult_03", "scale": 0.94,
		"skin": "d8a27a", "hair": "2b211b", "hair_style": "bun", "shirt": "b5577a", "sleeve": "long",
		"pants": "4a4a52", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.56, "build": 1.06,
		"female": true},
	# Trâm, thợ điện: áo bảo hộ xanh rêu, nón kết, giày bảo hộ.
	"TRAM": {"rb": "Female_Adult_03", "head": "Female_Adult_03", "scale": 0.95,
		"skin": "d9a77c", "hair": "1b1714", "hair_style": "ponytail", "shirt": "2f6f6a", "sleeve": "long",
		"pants": "35455e", "shoes": "3b3b3b", "footwear": "shoes", "hat": "cap", "bag": false, "height": 1.62,
		"build": 0.98, "female": true},
	# Anh Phúc: áo sơ mi trắng, quần tây, giày da.
	"PHUC": {"rb": "Business_Male_02", "head": "Business_Male_02", "scale": 0.97,
		"skin": "c99a76", "hair": "1b1714", "hair_style": "short", "shirt": "efeee8", "sleeve": "short",
		"pants": "6f7277", "shoes": "3b3b3b", "footwear": "shoes", "hat": "none", "bag": false, "height": 1.7,
		"build": 1.12},
	# Chương 2 · Má (cô Hậu), 49 tuổi: áo sơ mi caro tay dài của người làm xưởng, quần đen, tóc búi có sợi bạc.
	"MA": {"rb": "Female_Adult_11", "head": "Business_Female_03", "scale": 0.94,
		"skin": "c99a76", "hair": "3a3028", "hair_style": "bun", "shirt": "7a8f6a", "sleeve": "long",
		"pants": "26262c", "shoes": "8b5a2b", "hat": "none", "bag": false, "height": 1.55, "build": 1.02,
		"female": true},
	# Ông Ba Lành, 78 tuổi: áo thun trắng ngả màu, quần đùi, tóc bạc trắng.
	"ONG_BA": {"rb": "Gardener_Male_01", "head": "Male_Adult_10", "scale": 0.93, "hair_tone": "grey",
		"skin": "b07a52", "hair": "e0e0dc", "hair_style": "short", "shirt": "e6e1d3", "sleeve": "short",
		"pants": "4a4a52", "legs": "shorts", "shoes": "6b4f3a", "hat": "none", "bag": false, "height": 1.6,
		"build": 0.94},
	# Kha, 23 tuổi, sửa điện thoại ở chợ: áo thun đen, quần jean, giày trắng.
	"KHA": {"rb": "Male_Adult_17", "head": "Male_Adult_10", "scale": 0.96,
		"skin": "d9a77c", "hair": "1b1714", "hair_style": "short", "shirt": "2b2b31", "sleeve": "short",
		"pants": "3b5b82", "shoes": "f2f0ea", "footwear": "shoes", "hat": "none", "bag": false, "height": 1.7,
		"build": 0.95},
	# Chương 3–5: chị Mai (y tá), anh Quân, anh Phong, bé Tín, chị Lụa (dựng sẵn bằng người thật).
	"MAI": {"rb": "Medical_Female_01", "head": "Medical_Female_01", "scale": 0.95, "female": true, "hat": "none"},
	"QUAN": {"rb": "Male_Adult_02", "head": "Business_Male_02", "scale": 0.96, "hat": "none"},
	"PHONG": {"rb": "Male_Adult_05", "head": "Male_Adult_10", "scale": 0.95, "hair_tone": "grey", "hat": "none"},
	"TIN": {"rb": "Male_Child_01", "scale": 1.0, "hat": "none", "height": 1.25},
	"LUA": {"rb": "Female_Adult_14", "head": "Sports_Female_02", "scale": 0.94, "female": true, "hat": "none"},
}

## Xương: tên, cha, vị trí trong khung (mét, dáng cao 1,72 m, mặt nhìn về +z). Dáng nữ co vai, nở hông.
const BONES := [
	["root", -1, Vector3(0, 0, 0)],
	["hips", 0, Vector3(0, 0.95, 0)],
	["spine", 1, Vector3(0, 1.1, 0)],
	["chest", 2, Vector3(0, 1.3, 0)],
	["neck", 3, Vector3(0, 1.47, 0)],
	["head", 4, Vector3(0, 1.56, 0)],
	["arm_l", 3, Vector3(0.19, 1.425, 0)],
	["forearm_l", 6, Vector3(0.212, 1.15, -0.01)],
	["hand_l", 7, Vector3(0.222, 0.895, 0.0)],
	["arm_r", 3, Vector3(-0.19, 1.425, 0)],
	["forearm_r", 9, Vector3(-0.212, 1.15, -0.01)],
	["hand_r", 10, Vector3(-0.222, 0.895, 0.0)],
	["thigh_l", 1, Vector3(0.095, 0.92, 0)],
	["shin_l", 12, Vector3(0.098, 0.5, 0.008)],
	["foot_l", 13, Vector3(0.1, 0.085, -0.02)],
	["thigh_r", 1, Vector3(-0.095, 0.92, 0)],
	["shin_r", 15, Vector3(-0.098, 0.5, 0.008)],
	["foot_r", 16, Vector3(-0.1, 0.085, -0.02)],
]
const TEMPLATE_H := 1.72
## Vùng màu trong lưới (kênh đỏ của màu đỉnh, chia 20): shader tô theo vùng.
enum Region { SKIN, TORSO, ARM, LEG, FOOT, HAIR, PUPIL, EYE_WHITE, LIPS, TRIM }

const BODY_SHADER := """
shader_type spatial;
render_mode cull_back;
uniform vec3 skin : source_color = vec3(0.82, 0.63, 0.48);
uniform vec3 shirt : source_color = vec3(0.4, 0.5, 0.6);
uniform vec3 pants : source_color = vec3(0.2, 0.25, 0.3);
uniform vec3 shoes : source_color = vec3(0.2, 0.2, 0.2);
uniform vec3 hair : source_color = vec3(0.1, 0.08, 0.07);
// Tay áo che tới đâu trên cánh tay (0 vai, 0,5 khuỷu, 1 cổ tay); ống quần che tới đâu (1 cổ chân);
// gấu áo trên thân (0 háng, 1 cổ): dưới gấu là quần. closed_shoes: giày kín, không thì dép (đế và quai).
uniform float sleeve = 0.3;
uniform float legs = 0.97;
uniform float hem = 0.26;
uniform bool closed_shoes = false;
void fragment() {
	int r = int(COLOR.r * 20.0 + 0.5);
	float t = COLOR.g;
	vec3 c = skin;
	float rough = 0.78;
	if (r == 1) {
		c = t < hem ? pants : shirt;
	} else if (r == 2) {
		c = t < sleeve ? shirt : skin;
	} else if (r == 3) {
		c = t < legs ? pants : skin;
	} else if (r == 4) {
		c = (closed_shoes || UV.y < 0.3 || abs(UV.x - 0.58) < 0.07) ? shoes : skin;
	} else if (r == 5) {
		c = hair;
		rough = 0.55;
	} else if (r == 6) {
		c = vec3(0.04, 0.035, 0.035);
		rough = 0.25;
	} else if (r == 7) {
		c = vec3(0.92, 0.91, 0.88);
		rough = 0.35;
	} else if (r == 8) {
		c = mix(skin, vec3(0.6, 0.2, 0.18), 0.5);
	} else if (r == 9) {
		c = shirt * 0.78;
	}
	ALBEDO = c * COLOR.b;
	ROUGHNESS = rough;
}
"""

## Lưới đã dựng theo "dáng|kiểu tóc", phụ kiện đã dựng, shader dùng chung.
static var _cache := {}
static var _shader: Shader

var look: Dictionary = {}
var _sk: Skeleton3D
var _b := {}
var _mat: ShaderMaterial
var _phase := 0.0
var _move := 0.0
var _sitting := false
var _back := false
var _hip_h := 0.93
var _hold := ""


## Dáng An theo bộ quần áo đang mặc (bảng Nhân vật): thân người mặc bộ đó, giữ đầu, mặt của An.
static func an_look(game) -> Dictionary:
	var look: Dictionary = LOOKS.AN.duplicate()
	if game == null or not game.is_started():
		return look
	for it in game.cfg.get("items", {}).get("clothes", []):
		if str(it.id) == game.outfit() and it.has("rb"):
			look["rb"] = str(it.rb)
	# Áo bóc từ túi mù đang mặc (data/clothes.json, có thân người thật rb) thì thay cả thân.
	var top: String = str(game.wardrobe().worn.get("ao", "")) if game.has_method("wardrobe") else ""
	if top != "" and game.cloth(top).has("rb"):
		look["rb"] = str(game.cloth(top).rb)
	return look


static func make(look_in: Dictionary) -> Node3D:
	# Có người thật (Rocketbox, assets/rb) thì dùng người thật; khung người dựng bằng code chỉ còn làm dự phòng.
	if look_in.has("rb"):
		var Human = load("res://scripts/world/human.gd")
		if Human.exists(str(look_in.rb)):
			return Human.make(look_in)
	var c = load("res://scripts/world/character.gd").new()
	c.look = look_in
	c._build()
	return c


## Người thật cho người đi đường: thân (quần áo) trong POOL, đầu (mặt, tóc) người châu Á trong HEADS (ghép đầu, xem
## human.gd); người lớn tuổi tóc bạc. Không dùng thân, mặt của An, Linh.
const POOL_M := ["Male_Adult_01", "Male_Adult_07", "Delivery_Male_01", "Construction_Male_02", "Male_Adult_02",
	"Male_Adult_05", "Male_Adult_14", "Male_Adult_17"]
const POOL_F := ["Female_Adult_08", "Female_Adult_07", "Female_Adult_02", "Female_Adult_05", "Female_Adult_11",
	"Female_Adult_14", "Business_Female_03"]
const HEADS_M := ["Male_Adult_10", "Business_Male_02"]
const HEADS_F := ["Female_Adult_03", "Business_Female_03", "Medical_Female_01", "Sports_Female_02"]
## Người đám đông, người lái xe (tools/bake_people.gd nướng sẵn từng tư thế theo id, crowd.gd và traffic.gd dùng).
const CROWD := [
	{"id": "m1", "rb": "Male_Adult_01", "head": "Male_Adult_10", "scale": 0.95},
	{"id": "m2", "rb": "Male_Adult_07", "head": "Business_Male_02", "scale": 0.96},
	{"id": "m3", "rb": "Delivery_Male_01", "head": "Male_Adult_10", "hair_tone": "grey", "scale": 0.94},
	{"id": "m4", "rb": "Male_Adult_17", "head": "Business_Male_02", "scale": 0.95},
	{"id": "m5", "rb": "Male_Adult_02", "head": "Male_Adult_10", "scale": 0.96},
	{"id": "f1", "rb": "Female_Adult_08", "head": "Female_Adult_03", "scale": 0.94},
	{"id": "f2", "rb": "Female_Adult_07", "head": "Sports_Female_02", "scale": 0.94},
	{"id": "f3", "rb": "Female_Adult_02", "head": "Business_Female_03", "hair_tone": "grey", "scale": 0.92},
	{"id": "f4", "rb": "Female_Adult_05", "head": "Medical_Female_01", "scale": 0.94},
]
const CROWD_CHILD := {"id": "c1", "rb": "Male_Child_01", "scale": 1.0}
## Đầu có bản tóc bạc (tools/viet_look.py).
const GREY_HEADS := ["Male_Adult_10", "Business_Male_02", "Business_Female_03"]


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
	var out := {
		"skin": ["c98f63", "d9a77c", "e2b48f", "b97d55"][rng.randi() % 4],
		"hair": ["1b1714", "2b211b", "3a2a20"][rng.randi() % 3],
		"hair_style": (["long", "bun", "ponytail"][rng.randi() % 3]) if female else "short",
		"shirt": shirts[rng.randi() % shirts.size()],
		"sleeve": "long" if rng.randf() < 0.35 else "short",
		"pants": pants[rng.randi() % pants.size()],
		"legs": "shorts" if not female and rng.randf() < 0.25 else "long",
		"shoes": ["e8efe9", "3b3b3b", "8b5a2b", "2f6fb0"][rng.randi() % 4],
		"footwear": "shoes" if rng.randf() < 0.3 else "sandals",
		"hat": hat, "bag": rng.randf() < 0.2,
		"helmet": ["c0392b", "f2f0ea", "2f6fb0", "1f1f24", "f1c40f", "d98fa0", "7d8c6a"][rng.randi() % 7],
		"height": rng.randf_range(1.55, 1.68) if female else rng.randf_range(1.62, 1.78),
		"build": rng.randf_range(0.92, 1.1),
		"female": female,
		"rb": (POOL_F if female else POOL_M)[rng.randi() % (POOL_F if female else POOL_M).size()],
		"head": (HEADS_F if female else HEADS_M)[rng.randi() % (HEADS_F if female else HEADS_M).size()],
		"scale": rng.randf_range(0.92, 0.96) if female else rng.randf_range(0.93, 0.98),
	}
	if str(out.head) in GREY_HEADS and rng.randf() < 0.2:
		out["hair_tone"] = "grey"
	return out


# ---------------------------------------------------------------- dựng

func _build() -> void:
	var female := bool(look.get("female", false))
	var style := str(look.get("hair_style", "short"))
	var key := "%s|%s" % ["f" if female else "m", style]
	if not _cache.has(key):
		_cache[key] = _make_body(female, style)
	var body: Dictionary = _cache[key]
	_sk = Skeleton3D.new()
	add_child(_sk)
	var bones: Array = body.bones
	for i in bones.size():
		var bd: Array = bones[i]
		_sk.add_bone(str(bd[0]))
		_b[str(bd[0])] = i
		if int(bd[1]) >= 0:
			_sk.set_bone_parent(i, int(bd[1]))
		var local: Vector3 = (bd[2] as Vector3) - ((bones[int(bd[1])][2] as Vector3) if int(bd[1]) >= 0 else Vector3.ZERO)
		_sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, local))
		_sk.reset_bone_pose(i)
	var k := float(look.get("height", 1.72)) / TEMPLATE_H
	var w := float(look.get("build", 1.0))
	_sk.scale = Vector3(k * w, k, k * w)
	var mi := MeshInstance3D.new()
	mi.mesh = body.mesh
	mi.skin = body.skin
	_sk.add_child(mi)
	mi.skeleton = NodePath("..")
	if _shader == null:
		_shader = Shader.new()
		_shader.code = BODY_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	_mat.set_shader_parameter("skin", Color(str(look.get("skin", "d9a77c"))))
	_mat.set_shader_parameter("shirt", Color(str(look.get("shirt", "4f7fb3"))))
	_mat.set_shader_parameter("pants", Color(str(look.get("pants", "35455e"))))
	_mat.set_shader_parameter("shoes", Color(str(look.get("shoes", "3b3b3b"))))
	_mat.set_shader_parameter("hair", Color(str(look.get("hair", "1b1714"))))
	_mat.set_shader_parameter("sleeve", 0.97 if str(look.get("sleeve", "short")) == "long" else 0.3)
	_mat.set_shader_parameter("legs", 0.42 if str(look.get("legs", "long")) == "shorts" else 0.97)
	_mat.set_shader_parameter("hem", 0.05 if bool(look.get("tunic", false)) else 0.26)
	_mat.set_shader_parameter("closed_shoes", str(look.get("footwear", "sandals")) == "shoes")
	mi.material_override = _mat
	# Phụ kiện theo xương.
	match str(look.get("hat", "none")):
		"non_la":
			_attach("head", _acc("non_la"), Color("e3d3a0"))
		"cap":
			_attach("head", _acc("cap"), Color(str(look.get("shirt", "3f6f8f"))).darkened(0.1))
		"helmet":
			_attach("head", _acc("helmet"), Color(str(look.get("helmet", "c0392b"))))
	if bool(look.get("bag", false)):
		_attach("chest", _acc("bag"), Color("4a4f3a"))
	if bool(look.get("apron", false)):
		_attach("spine", _acc("apron"), Color("f1ece0"))


## Gắn thêm một món đồ mang theo (lưới dựng theo khung người cao 1,72 m, như đòn gánh) vào xương.
func add_item(bone: String, mesh: Mesh) -> void:
	_attach(bone, mesh, Color(1, 1, 1))


## Gắn một lưới phụ kiện (màu đỉnh nhân với tint) vào xương.
func _attach(bone: String, mesh: Mesh, tint: Color) -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	_sk.add_child(ba)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = tint
	m.roughness = 0.75
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	# Phụ kiện dựng theo vị trí trong khung; đặt lại về gốc xương.
	mi.position = -_bone_pos(bone)
	ba.add_child(mi)


func _bone_pos(bone: String) -> Vector3:
	for bd in BONES:
		if str(bd[0]) == bone:
			return bd[2]
	return Vector3.ZERO


# ---------------------------------------------------------------- lưới thân

## Lưới dáng người (nam/nữ) với kiểu tóc: trả về {mesh, skin, bones}.
static func _make_body(female: bool, style: String) -> Dictionary:
	var g := Mesher.new()
	var bones: Array = []
	for bd in BONES:
		var p: Vector3 = bd[2]
		if female:
			if str(bd[0]).begins_with("arm") or str(bd[0]).begins_with("forearm") or str(bd[0]).begins_with("hand"):
				p.x *= 0.9
			elif str(bd[0]).begins_with("thigh") or str(bd[0]).begins_with("shin") or str(bd[0]).begins_with("foot"):
				p.x *= 0.98
		bones.append([bd[0], bd[1], p])
	var idx := {}
	for i in bones.size():
		idx[str(bones[i][0])] = i
	var P := func(n: String) -> Vector3: return bones[idx[n]][2]
	var B := func(n: String) -> int: return idx[n]
	var fw := 0.93 if female else 1.0

	# Thân: vòng elip từ háng lên vai, dưới thắt lưng gắn xương hông, ngang ngực gắn xương ngực.
	var torso_m := [[0.875, 0.13, 0.092, 0.0], [0.92, 0.17, 0.114, 0.0], [0.98, 0.172, 0.112, 0.0], [1.05, 0.16, 0.104, 0.0],
		[1.12, 0.152, 0.102, 0.0], [1.2, 0.162, 0.11, 0.0], [1.28, 0.178, 0.118, 0.0], [1.35, 0.19, 0.115, 0.0],
		[1.4, 0.2, 0.104, 0.0], [1.435, 0.19, 0.094, 0.0], [1.46, 0.14, 0.08, 0.0], [1.478, 0.075, 0.065, 0.0]]
	var torso_f := [[0.875, 0.135, 0.094, 0.0], [0.92, 0.182, 0.12, 0.0], [0.98, 0.184, 0.117, 0.0], [1.05, 0.158, 0.1, 0.0],
		[1.12, 0.135, 0.092, 0.0], [1.2, 0.143, 0.102, 0.004], [1.27, 0.158, 0.126, 0.016], [1.34, 0.165, 0.112, 0.008],
		[1.395, 0.175, 0.097, 0.0], [1.43, 0.165, 0.088, 0.0], [1.455, 0.12, 0.075, 0.0], [1.472, 0.068, 0.06, 0.0]]
	var rings := []
	var tl: Array = torso_f if female else torso_m
	var y0 := float(tl[0][0])
	var y1 := float(tl[tl.size() - 1][0])
	for r in tl:
		var y := float(r[0])
		var wts := _blend_y(y, [[1.0, B.call("hips")], [1.08, B.call("spine")], [1.22, B.call("chest")]])
		rings.append({"c": Vector3(0, y, float(r[3])), "rx": float(r[1]), "rz": float(r[2]), "b": wts, "t": (y - y0) / (y1 - y0)})
	g.tube(rings, Region.TORSO, true, true, 14, false, 0.0, TAU, 0.35)
	# Cổ, cổ áo.
	var neck_r := 0.052 * fw
	g.tube([{"c": Vector3(0, 1.43, 0.0), "rx": neck_r, "rz": neck_r, "b": [[B.call("chest"), 1.0]], "t": 0.0},
		{"c": Vector3(0, 1.5, 0.008), "rx": neck_r, "rz": neck_r, "b": [[B.call("neck"), 1.0]], "t": 0.0},
		{"c": Vector3(0, 1.58, 0.012), "rx": neck_r * 0.95, "rz": neck_r * 0.95, "b": [[B.call("head"), 1.0]], "t": 0.0}], Region.SKIN, false, false)
	g.tube([{"c": Vector3(0, 1.448, 0.0), "rx": neck_r + 0.03, "rz": neck_r + 0.026, "b": [[B.call("chest"), 1.0]], "t": 0.0},
		{"c": Vector3(0, 1.478, 0.004), "rx": neck_r + 0.012, "rz": neck_r + 0.012, "b": [[B.call("chest"), 0.6], [B.call("neck"), 0.4]], "t": 0.0}], Region.TRIM, false, false)

	# Tay: bắp vai tròn, cánh tay, khuỷu, cẳng tay, cổ tay; bàn tay có ngón cái.
	var aw := 0.88 if female else 1.0
	for s in ["l", "r"]:
		var S: Vector3 = P.call("arm_" + s)
		var E: Vector3 = P.call("forearm_" + s)
		var W: Vector3 = P.call("hand_" + s)
		var ba: int = B.call("arm_" + s)
		var bf: int = B.call("forearm_" + s)
		var bh: int = B.call("hand_" + s)
		var arm := [[-0.05, S + Vector3(-0.014 if s == "l" else 0.014, 0.0, 0), 0.044, 0.048, [[ba, 1.0]]], [0.0, S + Vector3(0, -0.012, 0), 0.056, 0.058, [[ba, 1.0]]],
			[0.15, S.lerp(E, 0.3), 0.057, 0.059, [[ba, 1.0]]], [0.35, S.lerp(E, 0.72), 0.049, 0.051, [[ba, 1.0]]],
			[0.5, E, 0.043, 0.046, [[ba, 0.5], [bf, 0.5]]], [0.62, E.lerp(W, 0.25), 0.044, 0.042, [[bf, 1.0]]],
			[0.8, E.lerp(W, 0.6), 0.036, 0.033, [[bf, 1.0]]], [1.0, W, 0.029, 0.024, [[bf, 0.6], [bh, 0.4]]]]
		var ar := []
		for a in arm:
			ar.append({"c": a[1], "rx": float(a[2]) * aw, "rz": float(a[3]) * aw, "b": a[4], "t": float(a[0])})
		g.tube(ar, Region.ARM, true, true)
		var down := (W - E).normalized()
		var side := 1.0 if s == "l" else -1.0
		# Lòng bàn tay quay vào thân: bề ngang theo trục z, bề dày theo trục x.
		g.tube([{"c": W + down * 0.01, "rx": 0.022 * aw, "rz": 0.03 * aw, "b": [[bh, 1.0]], "t": 0.0},
			{"c": W + down * 0.06, "rx": 0.022 * aw, "rz": 0.045 * aw, "b": [[bh, 1.0]], "t": 0.0},
			{"c": W + down * 0.115, "rx": 0.018 * aw, "rz": 0.04 * aw, "b": [[bh, 1.0]], "t": 0.0},
			{"c": W + down * 0.16, "rx": 0.013 * aw, "rz": 0.028 * aw, "b": [[bh, 1.0]], "t": 0.0}], Region.SKIN, true, true)
		g.tube([{"c": W + down * 0.035 + Vector3(-side * 0.008, 0, 0.032) * aw, "rx": 0.012 * aw, "rz": 0.012 * aw, "b": [[bh, 1.0]], "t": 0.0},
			{"c": W + down * 0.085 + Vector3(-side * 0.012, 0, 0.046) * aw, "rx": 0.01 * aw, "rz": 0.01 * aw, "b": [[bh, 1.0]], "t": 0.0}], Region.SKIN, false, true)

	# Chân: đùi, gối, bắp chân, cổ chân; bàn chân đi dép (đế, quai) hay giày.
	var lw := 1.03 if female else 1.0
	for s in ["l", "r"]:
		var H: Vector3 = P.call("thigh_" + s)
		var K: Vector3 = P.call("shin_" + s)
		var A: Vector3 = P.call("foot_" + s)
		var bt: int = B.call("thigh_" + s)
		var bs: int = B.call("shin_" + s)
		var bfo: int = B.call("foot_" + s)
		var leg := [[-0.06, H + Vector3(-0.012 if s == "l" else 0.012, 0.045, 0), 0.07, 0.074, [[bt, 0.5], [B.call("hips"), 0.5]]], [0.0, H, 0.086, 0.09, [[bt, 1.0]]],
			[0.2, H.lerp(K, 0.4), 0.078, 0.082, [[bt, 1.0]]], [0.42, H.lerp(K, 0.85), 0.062, 0.066, [[bt, 1.0]]],
			[0.5, K, 0.058, 0.06, [[bt, 0.5], [bs, 0.5]]], [0.62, K.lerp(A, 0.25), 0.06, 0.066, [[bs, 1.0]]],
			[0.8, K.lerp(A, 0.6), 0.047, 0.05, [[bs, 1.0]]], [0.96, K.lerp(A, 0.92), 0.038, 0.04, [[bs, 1.0]]],
			[1.0, A, 0.036, 0.038, [[bs, 0.5], [bfo, 0.5]]]]
		var lr := []
		for a in leg:
			lr.append({"c": a[1], "rx": float(a[2]) * lw, "rz": float(a[3]) * lw, "b": a[4], "t": float(a[0])})
		g.tube(lr, Region.LEG, true, true)
		var fl := 0.94 if female else 1.0
		var foot := [[0.0, Vector3(A.x, 0.05, A.z - 0.06 * fl), 0.038, 0.042], [0.3, Vector3(A.x, 0.048, A.z + 0.02 * fl), 0.044, 0.042],
			[0.62, Vector3(A.x, 0.035, A.z + 0.11 * fl), 0.047, 0.03], [0.85, Vector3(A.x, 0.028, A.z + 0.16 * fl), 0.042, 0.022],
			[1.0, Vector3(A.x, 0.026, A.z + 0.185 * fl), 0.032, 0.018]]
		var fr := []
		for a in foot:
			fr.append({"c": a[1], "rx": float(a[2]) * fl, "rz": float(a[3]), "b": [[bfo, 1.0]], "t": float(a[0])})
		g.tube(fr, Region.FOOT, true, true, 12, true)

	# Đầu: elip thon cằm, tai, mắt (lòng trắng, con ngươi), mày, mũi, miệng.
	var hs := 0.96 if female else 1.0
	var hc := Vector3(0, 1.605, 0.012)
	var hr := Vector3(0.096, 0.116, 0.106) * hs
	var bhd: int = B.call("head")
	g.ellipsoid(hc, hr, Region.SKIN, bhd, 12, 16, func(u: Vector3) -> Vector3:
		var v := u
		if v.y < 0.0:
			v.x *= 1.0 - 0.28 * minf(-v.y, 1.0)
			v.z = v.z * (1.0 - 0.12 * minf(-v.y, 1.0)) + 0.05 * minf(-v.y, 1.0)
		if v.z < 0.0:
			v.z *= 0.94
		return v)
	var face := func(x: float, y: float) -> Vector3:
		# Điểm trên mặt trước của đầu (x, y lệch so với tâm đầu).
		var zz := hr.z * sqrt(maxf(0.0, 1.0 - pow(x / hr.x, 2) - pow(y / hr.y, 2)))
		return hc + Vector3(x, y, zz)
	for sx in [-1.0, 1.0]:
		g.ellipsoid(face.call(sx * 0.036 * hs, 0.022 * hs) + Vector3(0, 0, -0.004), Vector3(0.019, 0.015, 0.008) * hs, Region.EYE_WHITE, bhd, 4, 8)
		g.ellipsoid(face.call(sx * 0.036 * hs, 0.02 * hs) + Vector3(0, 0, -0.001), Vector3(0.0105, 0.0125, 0.007) * hs, Region.PUPIL, bhd, 4, 8)
		g.ellipsoid(face.call(sx * 0.037 * hs, 0.05 * hs) + Vector3(0, 0, -0.003), Vector3(0.022, 0.0055, 0.006) * hs, Region.HAIR, bhd, 3, 8)
		g.ellipsoid(hc + Vector3(sx * hr.x * 0.98, 0.005, -0.006), Vector3(0.012, 0.03, 0.022) * hs, Region.SKIN, bhd, 4, 8)
	g.ellipsoid(face.call(0.0, -0.008 * hs) + Vector3(0, 0, -0.004), Vector3(0.013, 0.021, 0.016) * hs, Region.SKIN, bhd, 4, 8, Callable(), 0.95)
	g.ellipsoid(face.call(0.0, -0.05 * hs) + Vector3(0, 0, -0.005), Vector3(0.022, 0.0065, 0.006) * hs, Region.LIPS, bhd, 3, 8)

	# Tóc: vỏ ôm đầu có đường chân tóc trước cao, sau thấp; tóc dài thêm mảng sau lưng, tóc búi thêm búi,
	# đuôi ngựa thêm đuôi.
	var hair_r := hr * Vector3(1.07, 1.06, 1.07)
	var front := 58.0
	var back := 118.0
	if style == "short":
		hair_r = hr * Vector3(1.08, 1.12, 1.08)
		front = 62.0
	g.cap(hc + Vector3(0, 0.006, -0.004), hair_r, Region.HAIR, bhd, deg_to_rad(front), deg_to_rad(back), 9, 18)
	match style:
		"long":
			var panel := []
			for i in 5:
				var u := float(i) / 4.0
				panel.append({"c": hc + Vector3(0, 0.02 - u * 0.27, -0.015 - u * 0.03), "rx": hr.x * (1.08 + u * 0.18), "rz": hr.z * (1.04 + u * 0.1),
					"b": [[bhd, 1.0 - u * 0.6], [B.call("chest"), u * 0.6]], "t": 0.0})
			g.tube(panel, Region.HAIR, false, false, 16, false, deg_to_rad(200.0), deg_to_rad(340.0))
		"bun":
			g.ellipsoid(hc + Vector3(0, hr.y * 0.55, -hr.z * 0.95), Vector3(0.05, 0.045, 0.045) * hs, Region.HAIR, bhd, 6, 10)
		"ponytail":
			g.ellipsoid(hc + Vector3(0, hr.y * 0.35, -hr.z * 1.02), Vector3(0.022, 0.02, 0.02), Region.TRIM, bhd, 4, 8)
			g.tube([{"c": hc + Vector3(0, hr.y * 0.36, -hr.z * 1.05), "rx": 0.03, "rz": 0.03, "b": [[bhd, 1.0]], "t": 0.0},
				{"c": hc + Vector3(0, hr.y * 0.05, -hr.z * 1.22), "rx": 0.038, "rz": 0.034, "b": [[bhd, 1.0]], "t": 0.0},
				{"c": hc + Vector3(0, -hr.y * 0.45, -hr.z * 1.2), "rx": 0.032, "rz": 0.028, "b": [[bhd, 0.7], [B.call("neck"), 0.3]], "t": 0.0},
				{"c": hc + Vector3(0, -hr.y * 0.95, -hr.z * 1.08), "rx": 0.016, "rz": 0.014, "b": [[bhd, 0.5], [B.call("neck"), 0.5]], "t": 0.0}], Region.HAIR, false, true)

	var skin := Skin.new()
	for i in bones.size():
		skin.add_named_bind(str(bones[i][0]), Transform3D(Basis.IDENTITY, -(bones[i][2] as Vector3)))
	return {"mesh": g.commit(), "skin": skin, "bones": bones}


## Trọng số theo độ cao y giữa các mốc [y, xương]: dưới mốc đầu là xương đầu, giữa hai mốc thì chia.
static func _blend_y(y: float, marks: Array) -> Array:
	if y <= float(marks[0][0]):
		return [[int(marks[0][1]), 1.0]]
	for i in marks.size() - 1:
		var a: Array = marks[i]
		var b: Array = marks[i + 1]
		if y <= float(b[0]):
			var w := (y - float(a[0])) / (float(b[0]) - float(a[0]))
			return [[int(a[1]), 1.0 - w], [int(b[1]), w]]
	return [[int(marks[marks.size() - 1][1]), 1.0]]


# ---------------------------------------------------------------- phụ kiện

static func _acc(kind: String) -> Mesh:
	var key := "acc|" + kind
	if _cache.has(key):
		return _cache[key]
	var g := Mesher.new(false)
	var head := Vector3(0, 1.605, 0.012)
	match kind:
		"non_la":
			# Nón lá: chóp nón hơi cong, quai dưới cằm.
			var rings := []
			for i in 7:
				var u := float(i) / 6.0
				var r := 0.012 + 0.29 * u
				rings.append({"c": head + Vector3(0, 0.27 - 0.17 * pow(u, 1.15), 0), "rx": r, "rz": r, "c2": Color(0.9 + 0.1 * u, 0.88 + 0.1 * u, 0.82 + 0.1 * u)})
			g.tube(rings, 0, false, false, 20)
			g.tube([{"c": head + Vector3(0, 0.1, 0), "rx": 0.292, "rz": 0.292, "c2": Color(0.8, 0.74, 0.58)},
				{"c": head + Vector3(0, 0.095, 0), "rx": 0.3, "rz": 0.3, "c2": Color(0.8, 0.74, 0.58)}], 0, false, false, 20)
		"cap":
			g.cap(head + Vector3(0, 0.035, -0.004), Vector3(0.106, 0.105, 0.116), 0, -1, deg_to_rad(80.0), deg_to_rad(95.0), 7, 16)
			g.disc(head + Vector3(0, 0.05, 0.13), Vector2(0.085, 0.07), 0.012, Color(0.85, 0.85, 0.85))
		"helmet":
			g.cap(head + Vector3(0, 0.03, 0.0), Vector3(0.122, 0.128, 0.13), 0, -1, deg_to_rad(88.0), deg_to_rad(105.0), 8, 18)
			g.disc(head + Vector3(0, 0.035, 0.12), Vector2(0.09, 0.05), 0.01, Color(0.25, 0.25, 0.28))
			g.disc(head + Vector3(0, 0.12, -0.02), Vector2(0.03, 0.09), 0.02, Color(0.95, 0.95, 0.95))
		"bag":
			# Ba lô đồ nghề: thân tròn cạnh, nắp, quai qua vai.
			g.ellipsoid(Vector3(0, 1.27, -0.19), Vector3(0.15, 0.19, 0.08), 0, -1, 8, 12, Callable(), 1.0, true)
			g.ellipsoid(Vector3(0, 1.21, -0.26), Vector3(0.1, 0.08, 0.035), 0, -1, 5, 10, Callable(), 1.0, true, Color(0.8, 0.8, 0.8))
			for sx in [-0.1, 0.1]:
				g.band(Vector3(sx, 1.465, 0.0), Vector3(sx * 1.05, 1.14, 0.125), Vector3(sx, 1.44, -0.17), 0.035, Color(0.6, 0.6, 0.6))
		"apron":
			g.panel(Vector3(0, 1.22, 0.125), Vector3(0, 0.72, 0.14), 0.3, 0.34, Color(1, 1, 1))
	var m := g.commit()
	_cache[key] = m
	return m


# ---------------------------------------------------------------- cử động

## Gọi mỗi khung hình: moving 0..1 là tốc độ so với đi bộ bình thường.
func animate(delta: float, moving: float) -> void:
	_move = lerpf(_move, clampf(moving, 0.0, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	if _sitting:
		_pose_sit()
		return
	_phase += delta * lerpf(1.6, 9.5, _move)
	var s := sin(_phase)
	var swing := 0.42 * _move
	_rot("thigh_l", s * swing)
	_rot("thigh_r", -s * swing)
	_rot("shin_l", maxf(0.0, -cos(_phase)) * 0.72 * _move)
	_rot("shin_r", maxf(0.0, cos(_phase)) * 0.72 * _move)
	# Bàn chân giữ gần song song mặt đất.
	_rot("foot_l", -(s * swing + maxf(0.0, -cos(_phase)) * 0.72 * _move) * 0.6)
	_rot("foot_r", -(-s * swing + maxf(0.0, cos(_phase)) * 0.72 * _move) * 0.6)
	_rot("arm_l", -s * swing * 0.85, 0.0, 0.05)
	_rot("arm_r", s * swing * 0.85, 0.0, -0.05)
	_rot("forearm_l", -0.18 - maxf(0.0, s) * 0.45 * _move)
	_rot("forearm_r", -0.18 - maxf(0.0, -s) * 0.45 * _move)
	_rot("spine", 0.04 * _move, s * 0.06 * _move)
	_rot("chest", 0.02 * _move + sin(_phase * 0.5) * 0.01 * (1.0 - _move), -s * 0.05 * _move)
	_rot("head", -0.05 * _move)
	match _hold:
		"push":
			# Hai tay nắm tay đẩy trước bụng (cao chừng 1 m, cách người nửa mét).
			_rot("arm_l", -0.75, 0.0, 0.06)
			_rot("arm_r", -0.75, 0.0, -0.06)
			_rot("forearm_l", -0.5)
			_rot("forearm_r", -0.5)
		"carry":
			# Tay phải đưa lên giữ đòn gánh trên vai.
			_rot("arm_r", -0.5, 0.0, -0.1)
			_rot("forearm_r", -2.27)
	# Nhún người khi bước, thở nhẹ khi đứng.
	_sk.position.y = absf(sin(_phase)) * 0.035 * _move + sin(_phase * 0.5) * 0.003 * (1.0 - _move)


## Ngồi xe máy: hip_h là độ cao khớp hông so với gốc người (gốc đặt ở mặt đất dưới yên); back: ngồi sau, hai tay để
## trên đùi, gối dạng ra ôm hông người lái.
func sit(on: bool, hip_h := 0.93, back := false) -> void:
	_sitting = on
	_hip_h = hip_h
	_back = back


## "push": đẩy xe đẩy, "carry": gánh, "": tay đung đưa khi đi.
func hold(kind: String) -> void:
	_hold = kind


## Ngồi xe máy: đùi đưa ra trước, cẳng chân gập về sau cho bàn chân đặt trên sàn xe, lưng hơi đổ tới, hai tay vươn
## tới tay lái (cao hơn hông chừng 0,12 m, xa hơn hông chừng 0,53 m về phía trước).
func _pose_sit() -> void:
	var spread := 0.3 if _back else 0.12
	_rot("thigh_l", -1.3, 0.0, spread)
	_rot("thigh_r", -1.3, 0.0, -spread)
	_rot("shin_l", 1.6)
	_rot("shin_r", 1.6)
	_rot("foot_l", -0.3)
	_rot("foot_r", -0.3)
	if _back:
		_rot("arm_l", -0.35, 0.0, 0.12)
		_rot("arm_r", -0.35, 0.0, -0.12)
		_rot("forearm_l", -0.95)
		_rot("forearm_r", -0.95)
		_rot("spine", 0.05)
	else:
		_rot("arm_l", -0.9, 0.0, 0.1)
		_rot("arm_r", -0.9, 0.0, -0.1)
		_rot("forearm_l", -0.4)
		_rot("forearm_r", -0.4)
		_rot("spine", 0.2)
	_rot("chest", 0.0)
	_rot("head", -0.12 if not _back else 0.0)
	_sk.position.y = _hip_h - 0.95 * _sk.scale.y


func _rot(bone: String, x: float, y := 0.0, z := 0.0) -> void:
	_sk.set_bone_pose_rotation(_b[bone], Quaternion.from_euler(Vector3(x, y, z)))


# ---------------------------------------------------------------- dựng lưới

## Gom đỉnh, tam giác (có trọng số xương nếu skinned) rồi xuất ArrayMesh. Màu đỉnh: r = vùng / 20, g = vị trí dọc
## (tay áo, ống quần, gấu áo), b = độ sáng; UV dùng cho bàn chân (dọc, cao) để vẽ đế và quai dép.
class Mesher:
	var st := SurfaceTool.new()
	var skinned := true
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()

	func _init(with_skin := true) -> void:
		skinned = with_skin
		if skinned:
			st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func vert(p: Vector3, n: Vector3, col: Color, b: Array, uv := Vector2.ZERO) -> int:
		st.set_normal(n)
		st.set_color(col)
		st.set_uv(uv)
		if skinned:
			var bi := PackedInt32Array([0, 0, 0, 0])
			var bw := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
			for i in mini(b.size(), 4):
				bi[i] = int(b[i][0])
				bw[i] = float(b[i][1])
			st.set_bones(bi)
			st.set_weights(bw)
		st.add_vertex(p)
		pts.append(p)
		nrm.append(n)
		return pts.size() - 1

	## Tam giác quay mặt trước theo pháp tuyến các đỉnh (Godot: mặt trước theo chiều kim đồng hồ).
	func tri(a: int, b: int, c: int) -> void:
		var face := (pts[b] - pts[a]).cross(pts[c] - pts[a])
		if face.dot(nrm[a] + nrm[b] + nrm[c]) > 0.0:
			var t := b
			b = c
			c = t
		st.add_index(a)
		st.add_index(b)
		st.add_index(c)

	func commit() -> ArrayMesh:
		return st.commit()

	static func _col(region: int, t: float, shade := 1.0) -> Color:
		return Color(float(region) / 20.0, t, shade)

	## Ống elip qua các vòng {c, rx, rz, b (trọng số xương), t, c2 (màu riêng)}; nắp tròn hai đầu; uv_foot: đặt UV
	## (dọc, cao) cho bàn chân; a0..a1: chỉ dựng một cung (mảng tóc sau lưng, hai mặt).
	func tube(rings: Array, region: int, cap0: bool, cap1: bool, segs := 12, uv_foot := false, a0 := 0.0, a1 := TAU, cap_depth := 0.9) -> void:
		var full := a1 - a0 >= TAU - 0.001
		var cols := segs if full else segs + 1
		var n := rings.size()
		var frames := []
		for i in n:
			var c: Vector3 = rings[i].c
			var prev: Vector3 = rings[maxi(i - 1, 0)].c
			var nxt: Vector3 = rings[mini(i + 1, n - 1)].c
			var ax := (nxt - prev).normalized()
			var ref := Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.BACK
			var sv := (ref - ax * ax.dot(ref)).normalized()
			var fv := sv.cross(ax)
			if absf(ax.y) > 0.7:
				if fv.z < 0.0:
					fv = -fv
			elif fv.y < 0.0:
				fv = -fv
			frames.append([ax, sv, fv])
		var ids := []
		for i in n:
			var r: Dictionary = rings[i]
			var row := PackedInt32Array()
			var ax: Vector3 = frames[i][0]
			var sv: Vector3 = frames[i][1]
			var fv: Vector3 = frames[i][2]
			# Độ dốc bán kính dọc ống (ống loe, chóp nón): pháp tuyến nghiêng theo.
			var rp: Dictionary = rings[maxi(i - 1, 0)]
			var rn: Dictionary = rings[mini(i + 1, n - 1)]
			var ds := maxf((rn.c as Vector3).distance_to(rp.c), 0.0001)
			var slope := ((float(rn.rx) + float(rn.rz)) - (float(rp.rx) + float(rp.rz))) / 2.0 / ds
			for j in cols:
				var th := a0 + (a1 - a0) * float(j) / float(segs)
				var p: Vector3 = r.c + sv * float(r.rx) * cos(th) + fv * float(r.rz) * sin(th)
				var nn := ((sv * cos(th) / float(r.rx) + fv * sin(th) / float(r.rz)).normalized() - ax * slope).normalized()
				var col: Color = r.get("c2", _col(region, float(r.get("t", 0.0))))
				var uv := Vector2(float(r.get("t", 0.0)), 0.5 + 0.5 * sin(th)) if uv_foot else Vector2.ZERO
				row.append(vert(p, nn, col, r.get("b", [[0, 1.0]]), uv))
			ids.append(row)
		for i in n - 1:
			for j in cols - (0 if full else 1):
				var j2 := (j + 1) % cols
				tri(ids[i][j], ids[i][j2], ids[i + 1][j2])
				tri(ids[i][j], ids[i + 1][j2], ids[i + 1][j])
		if not full:
			# Mặt trong (tóc dài): lặp lại vòng với pháp tuyến quay vào.
			var inner := []
			for i in n:
				var row := PackedInt32Array()
				for j in cols:
					var k: int = ids[i][j]
					row.append(vert(pts[k], -nrm[k], rings[i].get("c2", _col(region, float(rings[i].get("t", 0.0)))), rings[i].get("b", [[0, 1.0]])))
				inner.append(row)
			for i in n - 1:
				for j in cols - 1:
					tri(inner[i][j], inner[i][j + 1], inner[i + 1][j + 1])
					tri(inner[i][j], inner[i + 1][j + 1], inner[i + 1][j])
			return
		for end in [0, n - 1]:
			if (end == 0 and not cap0) or (end == n - 1 and not cap1):
				continue
			var r: Dictionary = rings[end]
			var ax: Vector3 = frames[end][0] * (-1.0 if end == 0 else 1.0)
			var sv: Vector3 = frames[end][1]
			var fv: Vector3 = frames[end][2]
			var depth := minf(float(r.rx), float(r.rz)) * cap_depth
			var last: PackedInt32Array = ids[end]
			for k in range(1, 4):
				var ph := PI / 2.0 * float(k) / 3.0
				var row := PackedInt32Array()
				var cc: Vector3 = r.c + ax * depth * sin(ph)
				for j in cols:
					var th := TAU * float(j) / float(segs)
					var p := cc + sv * float(r.rx) * cos(ph) * cos(th) + fv * float(r.rz) * cos(ph) * sin(th)
					var nn := ((sv * cos(th) / float(r.rx) + fv * sin(th) / float(r.rz)).normalized() * cos(ph) + ax * sin(ph)).normalized()
					var col: Color = r.get("c2", _col(region, float(r.get("t", 0.0))))
					var uv := Vector2(float(r.get("t", 0.0)), 0.5 + 0.5 * sin(th)) if uv_foot else Vector2.ZERO
					row.append(vert(p, nn, col, r.get("b", [[0, 1.0]]), uv))
				for j in cols:
					var j2 := (j + 1) % cols
					tri(last[j], last[j2], row[j2])
					tri(last[j], row[j2], row[j])
				last = row

	## Elip tâm c bán kính r; deform biến đổi điểm trên mặt cầu đơn vị; scale_z < 1 ép dẹt mặt sau (mũi).
	func ellipsoid(c: Vector3, r: Vector3, region: int, bone: int, rows := 8, cols := 12, deform := Callable(), shade := 1.0, plain := false, tint := Color(1, 1, 1)) -> void:
		var ids := []
		for i in rows + 1:
			var th := PI * float(i) / float(rows)
			var row := PackedInt32Array()
			for j in cols:
				var ph := TAU * float(j) / float(cols)
				var u := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
				var v: Vector3 = u if not deform.is_valid() else deform.call(u)
				var p := c + Vector3(v.x * r.x, v.y * r.y, v.z * r.z)
				var nn := Vector3(v.x / r.x, v.y / r.y, v.z / r.z).normalized()
				var col := tint if plain else _col(region, 0.0, shade)
				row.append(vert(p, nn, col, [[maxi(bone, 0), 1.0]]))
			ids.append(row)
		for i in rows:
			for j in cols:
				var j2 := (j + 1) % cols
				tri(ids[i][j], ids[i][j2], ids[i + 1][j2])
				tri(ids[i][j], ids[i + 1][j2], ids[i + 1][j])

	## Vỏ chỏm (tóc, nón kết, mũ bảo hiểm): từ đỉnh xuống tới vĩ độ front (phía trước) .. back (phía sau).
	func cap(c: Vector3, r: Vector3, region: int, bone: int, front: float, back: float, rows := 8, cols := 16) -> void:
		var ids := []
		for i in rows + 1:
			var u := float(i) / float(rows)
			var row := PackedInt32Array()
			for j in cols:
				var ph := TAU * float(j) / float(cols)
				var lim := front + (back - front) * (1.0 - cos(ph)) / 2.0 + 0.12 * pow(sin(ph), 2)
				var th := u * lim
				var v := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
				var p := c + Vector3(v.x * r.x, v.y * r.y, v.z * r.z)
				var nn := Vector3(v.x / r.x, v.y / r.y, v.z / r.z).normalized()
				var col := Color(1, 1, 1) if region < 0 or bone < 0 else _col(region, 0.0)
				row.append(vert(p, nn, col, [[maxi(bone, 0), 1.0]]))
			ids.append(row)
		for i in rows:
			for j in cols:
				var j2 := (j + 1) % cols
				tri(ids[i][j], ids[i][j2], ids[i + 1][j2])
				tri(ids[i][j], ids[i + 1][j2], ids[i + 1][j])

	## Đĩa elip dẹt (lưỡi trai, kính mũ): tâm c, bán kính (x, z), dày h.
	func disc(c: Vector3, r: Vector2, h: float, tint: Color) -> void:
		var top := vert(c + Vector3(0, h / 2.0, 0), Vector3.UP, tint, [[0, 1.0]])
		var bot := vert(c - Vector3(0, h / 2.0, 0), Vector3.DOWN, tint, [[0, 1.0]])
		var n := 14
		var ring_t := PackedInt32Array()
		var ring_b := PackedInt32Array()
		for j in n:
			var a := TAU * float(j) / float(n)
			var off := Vector3(cos(a) * r.x, 0, sin(a) * r.y)
			ring_t.append(vert(c + off + Vector3(0, h / 2.0, 0), Vector3.UP, tint, [[0, 1.0]]))
			ring_b.append(vert(c + off - Vector3(0, h / 2.0, 0), Vector3.DOWN, tint, [[0, 1.0]]))
		for j in n:
			var j2 := (j + 1) % n
			tri(top, ring_t[j], ring_t[j2])
			tri(bot, ring_b[j2], ring_b[j])
			var a := TAU * (float(j) + 0.5) / float(n)
			var sn := Vector3(cos(a), 0, sin(a))
			var s0 := vert(pts[ring_t[j]], sn, tint, [[0, 1.0]])
			var s1 := vert(pts[ring_t[j2]], sn, tint, [[0, 1.0]])
			var s2 := vert(pts[ring_b[j2]], sn, tint, [[0, 1.0]])
			var s3 := vert(pts[ring_b[j]], sn, tint, [[0, 1.0]])
			tri(s0, s1, s2)
			tri(s0, s2, s3)

	## Dải quai đeo qua vai: từ trước ngực a, lên vai b, xuống sau lưng c; bề ngang w.
	func band(a: Vector3, b: Vector3, c: Vector3, w: float, tint: Color) -> void:
		for seg in [[b, a], [a, c]]:
			var p0: Vector3 = seg[0]
			var p1: Vector3 = seg[1]
			var side := Vector3(w / 2.0, 0, 0)
			var nn := (p1 - p0).cross(side).normalized()
			if nn.y < 0.0:
				nn = -nn
			var i0 := vert(p0 - side, nn, tint, [[0, 1.0]])
			var i1 := vert(p0 + side, nn, tint, [[0, 1.0]])
			var i2 := vert(p1 + side, nn, tint, [[0, 1.0]])
			var i3 := vert(p1 - side, nn, tint, [[0, 1.0]])
			tri(i0, i1, i2)
			tri(i0, i2, i3)

	## Tấm (tạp dề): mép trên ở top, mép dưới ở bottom, rộng trên w0, dưới w1, cong nhẹ theo thân.
	func panel(top: Vector3, bottom: Vector3, w0: float, w1: float, tint: Color) -> void:
		var rows := 4
		var cols := 6
		var ids := []
		for i in rows + 1:
			var u := float(i) / float(rows)
			var row := PackedInt32Array()
			var w := lerpf(w0, w1, u)
			for j in cols + 1:
				var v := float(j) / float(cols) - 0.5
				var p := top.lerp(bottom, u) + Vector3(v * w, 0, -0.06 * pow(v * 2.0, 2))
				row.append(vert(p, Vector3(v * 0.4, 0, 1).normalized(), tint, [[0, 1.0]]))
			ids.append(row)
		for i in rows:
			for j in cols:
				tri(ids[i][j], ids[i][j + 1], ids[i + 1][j + 1])
				tri(ids[i][j], ids[i + 1][j + 1], ids[i + 1][j])
