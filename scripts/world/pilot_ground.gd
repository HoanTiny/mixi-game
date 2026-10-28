extends RefCounted
## Authored street surfacing, batched by material. Coordinates follow the pilot's
## frontage: x along the shops, positive z toward the road. No physics/navigation.
const SIDEWALK_Y := 0.068
const ASPHALT_Y := 0.064
const CURB_TOP := 0.168
const CONCRETE := "res://assets/ph/textures/concrete_floor_worn_001/concrete_floor_worn_001_"
const ASPHALT := "res://assets/textures/duong_"
const SURFACE_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meters = 3.0;
uniform bool packed_roughness = true;
uniform float normal_strength = 0.30;
uniform vec2 oil_center = vec2(37.0, 1.0);
uniform float oil_strength = 0.12;
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV / meters;
	vec3 base = texture(base_tex, uv).rgb;
	float broad = noise(UV * 0.31 + vec2(8.1, 2.9));
	float fine = noise(UV * 3.7);
	// Broad, feathered contamination at the repair threshold: a material change,
	// not opaque decal dots. Low contrast keeps the walking surface readable.
	vec2 q = (UV - oil_center) / vec2(2.1, 0.68);
	float damp = (1.0 - smoothstep(0.18, 1.15, length(q))) * (0.65 + fine * 0.35);
	float medium = noise(UV * 0.87 + vec2(3.4, 11.0));
	float edge = clamp(1.0 - smoothstep(0.0, 0.55, UV.y) + smoothstep(2.58, 3.12, UV.y), 0.0, 1.0);
	float edge_dirt = edge * (0.06 + 0.10 * medium);
	float tone = 0.72 + broad * 0.08;
	// Warm, quiet concrete. Retain the photographed wear without bleaching the
	// slabs; dirt gathers against the storefront and curb instead of random dots.
	base = mix(base, vec3(0.115, 0.106, 0.092), 0.20);
	ALBEDO = base * COLOR.rgb * tone * (1.0 - damp * oil_strength - edge_dirt);
	vec3 packed = texture(rough_tex, uv).rgb;
	float rough = packed_roughness ? packed.g : packed.r;
	ROUGHNESS = clamp(rough * 0.34 + 0.60 - damp * 0.15, 0.68, 0.98);
	SPECULAR = 0.24;
	AO = packed_roughness ? mix(0.85, 1.0, packed.r) : 1.0;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
}
"""
const ASPHALT_SHADER := """
shader_type spatial;
render_mode diffuse_burley, blend_mix, depth_draw_never;
uniform sampler2D base_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float meters = 1.35;
uniform float normal_strength = 0.10;
uniform vec2 oil_center = vec2(37.0, 4.15);
uniform float oil_strength = 0.10;
float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0)), f.x), f.y);
}
void fragment() {
	vec2 uv_a = UV / meters;
	// Different scale, rotation and phase break the long repeated cracks in the
	// source photograph. Its contribution is fine aggregate, not the road colour.
	vec2 uv_b = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * UV / (meters * 1.61) + vec2(7.3, 4.9);
	float a = dot(texture(base_tex, uv_a).rgb, vec3(0.299, 0.587, 0.114));
	float b = dot(texture(base_tex, uv_b).rgb, vec3(0.299, 0.587, 0.114));
	float aggregate = clamp((mix(a, b, 0.47) - 0.15) * 0.11, -0.009, 0.009);
	float broad = noise(UV * 0.18 + vec2(2.8, 6.1));
	float medium = noise(UV * 0.71 + vec2(14.0, 3.7));
	vec2 q = (UV - oil_center) / vec2(2.3, 0.75);
	float damp = (1.0 - smoothstep(0.15, 1.15, length(q))) * (0.75 + medium * 0.25);
	vec3 asphalt = vec3(0.043, 0.040, 0.035) * (0.86 + broad * 0.19 + medium * 0.10);
	// Compatibility shades in sRGB; these hand-authored reflectance values are
	// linear. Convert only there so the same road does not collapse to black.
	vec3 road_color = max(asphalt + vec3(aggregate), vec3(0.001));
	if (OUTPUT_IS_SRGB) {
		road_color = pow(road_color, vec3(1.0 / 2.2));
	}
	ALBEDO = road_color * COLOR.rgb * (1.0 - damp * oil_strength);
	ROUGHNESS = clamp(0.85 + texture(rough_tex, uv_b).r * 0.10 - damp * 0.10, 0.76, 0.97);
	SPECULAR = 0.16;
	NORMAL_MAP = mix(texture(normal_tex, uv_a).rgb, texture(normal_tex, uv_b).rgb, 0.45);
	NORMAL_MAP_DEPTH = normal_strength;
	// Fade only this asphalt layer, keeping all concrete/metal geometry opaque.
	// The base road and centre stripe remain visible through the final 60 cm.
	ALPHA = 1.0 - smoothstep(6.0, 6.6, UV.y);
}
"""


static func build(world) -> Node3D:
	var root := Node3D.new()
	root.name = "PilotGround"
	if world.city == null or not world.city.pilot_active:
		return root
	var origin: Vector2 = world.city.pilot_origin
	var normal: Vector2 = world.city.pilot_normal
	var length: float = world.city.pilot_length
	root.position = Vector3(origin.x, 0.0, origin.y)
	root.rotation.y = atan2(normal.x, normal.y)
	var repair: Dictionary = world.city.locs.tiem_sau
	var tangent := Vector2(normal.y, -normal.x)
	var repair_x := ((repair.center as Vector2) - origin).dot(tangent)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20731
	# Existing sidewalk is y~.04, road y~.05, and curb reaches .16. These
	# elevations cover those surfaces without fighting them or changing foot height.
	var joints := _batch()
	_quad(joints, Rect2(0, 0.0, length, 3.12), SIDEWALK_Y - 0.006, Color.WHITE)
	_finish(root, joints, _plain(Color("423d37"), 0.98), "JointBed")
	var slabs := _batch()
	for row in 2:
		var z0 := 0.0 if row == 0 else 1.54
		var z1 := 1.54 if row == 0 else 3.12
		var x := -0.75 if row == 1 else 0.0
		while x < length:
			var end := minf(x + rng.randf_range(1.65, 2.45), length)
			var start := maxf(x, 0.0)
			if end - start > 0.06:
				var tint := rng.randf_range(1.06, 1.18)
				var chip := rng.randf_range(0.025, 0.095)
				_slab(slabs, Rect2(start + 0.009, z0 + 0.009, end - start - 0.018, z1 - z0 - 0.018),
					SIDEWALK_Y, chip, Color(tint, tint * 0.975, tint * 0.925))
			x = end
	_finish(root, slabs, _surface(true, Vector2(repair_x, 0.74)), "ConcreteSlabs")
	var road := _batch()
	# Stop short of the existing centreline; never paint over lane markings.
	_quad(road, Rect2(0, 3.31, length, 3.29), ASPHALT_Y, Color(0.86, 0.865, 0.85))
	_finish(root, road, _surface(false, Vector2(repair_x + 0.7, 4.15)), "AgedAsphalt")
	var gutter := _batch()
	_quad(gutter, Rect2(0, 3.32, length, 0.34), ASPHALT_Y + 0.006, Color(0.78, 0.76, 0.70))
	_finish(root, gutter, _surface(true, Vector2(repair_x, 3.5)), "Gutter")
	var curb := _batch()
	# Continuous dark skin covers the former bright curb. Short chamfered caps
	# provide modest chips and real side faces instead of a perfect white stripe.
	_quad(curb, Rect2(0, 3.095, length, 0.24), CURB_TOP - 0.003, Color(0.73, 0.71, 0.66))
	_face(curb, Vector3(0, ASPHALT_Y, 3.34), Vector3(length, ASPHALT_Y, 3.34),
		Vector3(length, CURB_TOP - 0.012, 3.34), Vector3(0, CURB_TOP - 0.012, 3.34), Vector3.BACK, Color(0.73, 0.71, 0.66))
	var cursor := 0.0
	while cursor < length:
		var end := minf(cursor + rng.randf_range(1.1, 1.65), length)
		var tone := rng.randf_range(0.91, 1.04)
		_slab(curb, Rect2(cursor + 0.008, 3.09, maxf(end - cursor - 0.016, 0.005), 0.25),
			CURB_TOP, rng.randf_range(0.018, 0.045), Color(tone, tone * 0.98, tone * 0.92))
		cursor = end
	_finish(root, curb, _surface(true, Vector2(-100, -100)), "ChippedCurb")
	var iron := _batch()
	var ribs := _batch()
	for x in [15.5, repair_x + 0.2, length - 8.0]:
		_drain(iron, ribs, Vector2(x, 3.53))
	_manhole(iron, ribs, Vector2(repair_x - 1.3, 5.28))
	_finish(root, iron, _plain(Color("484842"), 0.89, 0.24), "IronFrames")
	_finish(root, ribs, _plain(Color("63615a"), 0.84, 0.32), "IronRibs")
	root.set_meta("surface_draw_calls", 7)
	root.set_meta("local_extent", Rect2(0, 0, length, 6.6))
	return root


static func _surface(concrete: bool, oil: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SURFACE_SHADER if concrete else ASPHALT_SHADER
	mat.shader = shader
	var path := CONCRETE if concrete else ASPHALT
	mat.set_shader_parameter("base_tex", load(path + ("diff.jpg" if concrete else "albedo.jpg")))
	mat.set_shader_parameter("normal_tex", load(path + ("nor.jpg" if concrete else "normal.jpg")))
	mat.set_shader_parameter("rough_tex", load(path + ("arm.jpg" if concrete else "rough.jpg")))
	mat.set_shader_parameter("meters", 2.8 if concrete else 1.35)
	if concrete:
		mat.set_shader_parameter("packed_roughness", true)
	mat.set_shader_parameter("normal_strength", 0.24 if concrete else 0.10)
	mat.set_shader_parameter("oil_center", oil)
	mat.set_shader_parameter("oil_strength", 0.16 if concrete else 0.10)
	return mat


static func _plain(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.roughness = rough
	mat.metallic = metal
	return mat


static func _batch() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


static func _finish(root: Node3D, st: SurfaceTool, material: Material, label: String) -> void:
	st.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = st.commit()
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh)


static func _vertex(st: SurfaceTool, p: Vector3, normal: Vector3, tint: Color) -> void:
	st.set_normal(normal)
	st.set_color(tint)
	st.set_uv(Vector2(p.x, p.z) if absf(normal.y) > 0.5 else Vector2(p.x, p.y))
	st.add_vertex(p)


static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, tint: Color) -> void:
	var points := [a, b, c, a, c, d]
	if (b - a).cross(c - a).dot(normal) > 0.0:
		points = [a, c, b, a, d, c]
	for p in points:
		_vertex(st, p, normal, tint)


static func _quad(st: SurfaceTool, rect: Rect2, y: float, tint: Color) -> void:
	_face(st, Vector3(rect.position.x, y, rect.position.y), Vector3(rect.end.x, y, rect.position.y),
		Vector3(rect.end.x, y, rect.end.y), Vector3(rect.position.x, y, rect.end.y), Vector3.UP, tint)


static func _slab(st: SurfaceTool, rect: Rect2, y: float, chip: float, tint: Color) -> void:
	var a := rect.position
	var b := rect.end
	var points := PackedVector2Array([Vector2(a.x + chip, a.y), Vector2(b.x - chip * 0.6, a.y),
		Vector2(b.x, a.y + chip * 0.7), Vector2(b.x, b.y - chip), Vector2(b.x - chip, b.y),
		Vector2(a.x + chip * 0.65, b.y), Vector2(a.x, b.y - chip * 0.65), Vector2(a.x, a.y + chip)])
	var center := rect.get_center()
	for i in points.size():
		for p in [center, points[i], points[(i + 1) % points.size()]]:
			_vertex(st, Vector3(p.x, y, p.y), Vector3.UP, tint)


static func _drain(iron: SurfaceTool, ribs: SurfaceTool, at: Vector2) -> void:
	_quad(iron, Rect2(at - Vector2(0.48, 0.205), Vector2(0.96, 0.41)), 0.076, Color.WHITE)
	for i in 8:
		_quad(ribs, Rect2(at + Vector2(-0.43 + float(i) * 0.12, -0.17), Vector2(0.042, 0.34)), 0.080, Color.WHITE)
	for z in [-0.19, 0.16]:
		_quad(ribs, Rect2(at + Vector2(-0.46, z), Vector2(0.92, 0.025)), 0.081, Color.WHITE)


static func _manhole(iron: SurfaceTool, ribs: SurfaceTool, at: Vector2) -> void:
	for i in 48:
		var a := TAU * float(i) / 48.0
		var b := TAU * float(i + 1) / 48.0
		for p in [at, at + Vector2(cos(a), sin(a)) * 0.48, at + Vector2(cos(b), sin(b)) * 0.48]:
			_vertex(iron, Vector3(p.x, 0.078, p.y), Vector3.UP, Color.WHITE)
		var inner0 := at + Vector2(cos(a), sin(a)) * 0.425
		var inner1 := at + Vector2(cos(b), sin(b)) * 0.425
		var outer0 := at + Vector2(cos(a), sin(a)) * 0.455
		var outer1 := at + Vector2(cos(b), sin(b)) * 0.455
		_face(ribs, Vector3(inner0.x, 0.082, inner0.y), Vector3(outer0.x, 0.082, outer0.y),
			Vector3(outer1.x, 0.082, outer1.y), Vector3(inner1.x, 0.082, inner1.y), Vector3.UP, Color.WHITE)
	for i in range(-3, 4):
		var z := float(i) * 0.105
		var half_width := sqrt(0.38 * 0.38 - z * z)
		_quad(ribs, Rect2(at + Vector2(-half_width, z - 0.007), Vector2(half_width * 2.0, 0.014)), 0.082, Color(0.83, 0.81, 0.76))
