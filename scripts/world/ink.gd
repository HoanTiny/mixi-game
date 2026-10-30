extends RefCounted
## Nét mực kiểu "Nobody" cho màn phố 3D:
##   - Viền đen inverted hull: vẽ lại mặt sau của lưới, đẩy ra theo pháp tuyến một khoảng cố định tính bằng điểm ảnh
##     trên màn hình (OUTLINE_PX), nên viền dày đều 1,5–2 px dù ở gần hay xa. outline() gắn vào material_overlay của
##     nhân vật, xe, đồ vật; nhà và cây dùng building_outline() làm next_pass vì phải hạ theo nhà bị cắt quanh An.
##   - Đổ bóng cel 3 cấp: CEL_LIGHT là hàm light() chèn vào shader của nhân vật (sáng, nửa tối, tối, ranh giới mềm
##     vài phần trăm); vật liệu StandardMaterial3D thì đổi sang DIFFUSE_TOON (toonify).
##   - Bóng chân đậm nghiêng 45° theo nắng (blob): một mặt phẳng nằm dưới chân, hướng tính trong không gian thế giới
##     nên nhân vật xoay người bóng vẫn đổ về cùng một phía.
## Bật tắt chung bằng enabled (world.gd đặt theo config "ink").

const OUTLINE_PX := 1.8
const INK := Color(0.055, 0.045, 0.04)
## Hướng bóng đổ trên mặt đất (x, z), nghiêng 45° theo nắng (world.gd quay mặt trời cùng hướng).
const SHADOW_DIR := Vector2(0.70711, 0.70711)

static var enabled := true
static var _outline: ShaderMaterial
static var _blob: ShaderMaterial
static var _blob_mesh: PlaneMesh

const HULL := """
	vec4 clip_pos = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n_view = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec2 n_clip = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy;
	float n_len = length(n_clip);
	if (n_len > 1e-5) {
		clip_pos.xy += n_clip / n_len * px * 2.0 / VIEWPORT_SIZE * clip_pos.w;
	}
	POSITION = clip_pos;
"""

const OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;
uniform vec4 ink : source_color = vec4(0.055, 0.045, 0.04, 1.0);
uniform float px = 1.8;
void vertex() {
__HULL__
}
void fragment() {
	ALBEDO = ink.rgb;
}
"""

## Viền cho nhà, cây: cùng cách hạ nhà quanh An như BUILDING_SHADER của area_builder.gd (cut_on, caps, flat_color,
## trunk, INSTANCE_CUSTOM), đồ gắn kèm nhỏ (kiểu 3: ban công, hoa) thì không viền cho đỡ rối.
const BUILDING_OUTLINE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;
uniform vec4 ink : source_color = vec4(0.055, 0.045, 0.04, 1.0);
uniform float px = 1.6;
uniform bool cut_on = false;
uniform sampler2D caps : filter_nearest;
uniform int caps_w = 128;
uniform bool flat_color = false;
uniform bool trunk = false;
void vertex() {
	if (cut_on && trunk) {
		VERTEX.y = (VERTEX.y + 1.2) * max(INSTANCE_CUSTOM.r, 0.12) - 1.2;
	} else if (cut_on && flat_color) {
		VERTEX *= INSTANCE_CUSTOM.r;
	} else if (CUSTOM0.y > 2.5) {
		VERTEX = vec3(0.0, -10.0, 0.0);
	} else if (cut_on && CUSTOM0.y > 0.5) {
		int i = int(CUSTOM0.x + 0.5);
		float cap = texelFetch(caps, ivec2(i % caps_w, i / caps_w), 0).r;
		if (CUSTOM0.y > 1.5) {
			if (cap < UV2.y - 0.1) {
				VERTEX = vec3(0.0, -10.0, 0.0);
			}
		} else if (VERTEX.y > cap) {
			VERTEX.y = cap;
		}
	}
__HULL__
}
void fragment() {
	ALBEDO = ink.rgb;
}
"""

## Đổ bóng bậc thang 3 cấp: sáng (1), nửa tối (0,55), tối (0,22) theo N·L nhân bóng đổ; ranh giới mềm chừng 4%.
const CEL_LIGHT := """
void light() {
	float lit = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float band = mix(0.22, 0.55, smoothstep(0.08, 0.12, lit));
	band = mix(band, 1.0, smoothstep(0.48, 0.52, lit));
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
"""

const BLOB_SHADER := """
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Bóng chân: mặt phẳng 2 × 2 (đỉnh -1..1) đặt ở gốc nhân vật. Dựng lại trong không gian thế giới: kéo dài theo hướng
// nắng dir, dời một phần theo hướng đó, không xoay theo người.
uniform vec2 dir = vec2(0.70711, 0.70711);
uniform float radius = 0.42;
uniform float stretch = 1.9;
uniform float strength = 0.62;
// Nâng khỏi gốc nhân vật để nằm trên mặt vỉa hè (cao hơn mặt đường chừng 0,15 m).
uniform float lift = 0.18;
varying vec2 v_uv;
void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 fwd = vec3(dir.x, 0.0, dir.y);
	vec3 side = vec3(-dir.y, 0.0, dir.x);
	float sx = length(MODEL_MATRIX[0].xyz);
	vec3 p = origin + lift * vec3(0.0, 1.0, 0.0) + fwd * (VERTEX.z * radius * stretch + radius * (stretch - 1.0) * 0.85) * sx
		+ side * VERTEX.x * radius * sx;
	v_uv = VERTEX.xz;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
}
void fragment() {
	float d = length(v_uv);
	float a = 1.0 - smoothstep(0.35, 1.0, d);
	ALBEDO = vec3(0.04, 0.03, 0.025);
	ALPHA = a * strength;
}
"""


static func outline() -> ShaderMaterial:
	if _outline == null:
		var sh := Shader.new()
		sh.code = OUTLINE_SHADER.replace("__HULL__", HULL)
		_outline = ShaderMaterial.new()
		_outline.shader = sh
		_outline.set_shader_parameter("ink", INK)
		_outline.set_shader_parameter("px", OUTLINE_PX)
	return _outline


static var _building_shader: Shader


## Viền cho một vật liệu nhà/cây (ShaderMaterial của area_builder): next_pass dùng chung tham số cắt.
static func building_outline(base: ShaderMaterial) -> ShaderMaterial:
	if _building_shader == null:
		_building_shader = Shader.new()
		_building_shader.code = BUILDING_OUTLINE_SHADER.replace("__HULL__", HULL)
	var m := ShaderMaterial.new()
	m.shader = _building_shader
	m.set_shader_parameter("ink", INK)
	for k in ["caps", "caps_w", "flat_color", "trunk", "cut_on"]:
		var v = base.get_shader_parameter(k)
		if v != null:
			m.set_shader_parameter(k, v)
	return m


## Gắn viền vào mọi lưới dưới root (nhân vật, xe, đồ vật). Bỏ qua chữ, sprite, hạt, lưới dẹt (mặt đất, vạch sơn).
static func apply_outline(root: Node, min_height := 0.25) -> void:
	if not enabled or root == null:
		return
	for n in [root] + root.find_children("*", "GeometryInstance3D", true, false):
		if not (n is MeshInstance3D or n is MultiMeshInstance3D) or n.has_meta("no_ink"):
			continue
		var aabb: AABB = n.get_aabb()
		if aabb.size.y < min_height:
			continue
		n.material_overlay = outline()


## Tên node kiến trúc có cắt tường riêng (story_fronts, lived_in_interiors…): không viền bằng overlay.
const SKIP_NAMES := ["Architecture", "Walls", "Wing", "Roof", "Ground", "Floor", "Interior", "Facade", "Front"]


## Gắn viền cho đồ vật rời trong cảnh (đèn, thùng rác, xe đẩy, bàn ghế…), bỏ qua nhánh skip (khu nhà của area_builder),
## kiến trúc có cắt tường riêng, vật liệu shader riêng (mặt đất, nước) và lưới dẹt.
static func outline_props(root: Node, skip: Array = []) -> int:
	if not enabled or root == null:
		return 0
	var n_done := 0
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		if not (n is MeshInstance3D or n is MultiMeshInstance3D) or n.has_meta("no_ink") or n.material_overlay != null:
			continue
		var bad := false
		var p: Node = n
		while p != null and p != root:
			if skip.has(p):
				bad = true
				break
			for k in SKIP_NAMES:
				if str(p.name).contains(k):
					bad = true
					break
			if bad:
				break
			p = p.get_parent()
		if bad:
			continue
		# Nhà, cây (shader có ảnh caps) đã có viền riêng (building_outline); mặt nước, mặt đất là lưới rộng, dẹt.
		var mo = n.material_override
		if mo is ShaderMaterial and (mo.next_pass != null or (mo.shader != null and mo.shader.code.contains("sampler2D caps"))):
			continue
		var aabb: AABB = n.get_aabb()
		if aabb.size.y < 0.25 or (n is MeshInstance3D and (aabb.size.x > 40.0 or aabb.size.z > 40.0)):
			continue
		n.material_overlay = outline()
		n_done += 1
	return n_done


## Đổi vật liệu StandardMaterial3D dưới root sang đổ bóng toon (ranh sáng tối rõ), shader có light() thì giữ.
static func toonify(root: Node) -> void:
	if not enabled or root == null:
		return
	for n in [root] + root.find_children("*", "MeshInstance3D", true, false):
		if not n is MeshInstance3D:
			continue
		var mi := n as MeshInstance3D
		var mats: Array = [mi.material_override]
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				mats.append(mi.get_surface_override_material(i))
				mats.append(mi.mesh.surface_get_material(i))
		for m in mats:
			if m is BaseMaterial3D and m.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
				m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				m.specular_mode = BaseMaterial3D.SPECULAR_TOON


static func _blob_mesh_get() -> PlaneMesh:
	if _blob_mesh == null:
		_blob_mesh = PlaneMesh.new()
		_blob_mesh.size = Vector2(2, 2)
	return _blob_mesh


## Vật liệu bóng chân bán kính radius (dùng cho MultiMesh bóng của đồ phố, street_grit.gd).
static func blob_material(radius := 0.42, stretch := 1.9, strength := 0.62) -> ShaderMaterial:
	if _blob == null:
		var sh := Shader.new()
		sh.code = BLOB_SHADER
		_blob = ShaderMaterial.new()
		_blob.shader = sh
		_blob.set_shader_parameter("dir", SHADOW_DIR)
	var m := _blob.duplicate() as ShaderMaterial
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("stretch", stretch)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("lift", 0.07)
	return m


## Bóng chân đậm dưới node (gốc ở mặt đất). radius: bán kính ngang (m); stretch: kéo dài theo nắng.
static func blob(node: Node3D, radius := 0.42, stretch := 1.9, strength := 0.62) -> MeshInstance3D:
	if not enabled or node == null:
		return null
	if _blob == null:
		var sh := Shader.new()
		sh.code = BLOB_SHADER
		_blob = ShaderMaterial.new()
		_blob.shader = sh
		_blob.set_shader_parameter("dir", SHADOW_DIR)
		_blob_mesh = PlaneMesh.new()
		_blob_mesh.size = Vector2(2, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = _blob_mesh
	var m := _blob.duplicate() as ShaderMaterial
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("stretch", stretch)
	m.set_shader_parameter("strength", strength)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_ink", true)
	# Hình chữ nhật bao rộng để không bị cắt khi nhìn nghiêng (đỉnh được dựng lại trong shader).
	mi.custom_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6))
	mi.name = "InkBlob"
	node.add_child(mi)
	return mi
