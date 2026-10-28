extends RefCounted
## Authored street architecture in metres. +Z faces the pavement; rear is -depth.
## Ground, upper and roof are independently batched so camera cutaway never squashes a mesh.
const Props := preload("res://scripts/work/work_props.gd")
static var _materials: Dictionary = {}

class Batch:
	extends RefCounted
	var surfaces: Dictionary = {}
	func surface(material: Material) -> SurfaceTool:
		if not surfaces.has(material):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[material] = st
		return surfaces[material]
	func quad(mat: Material, points: Array, normal: Vector3, uv: Array, colors: Array = []) -> void:
		var st := surface(mat)
		for i in [0, 2, 1, 0, 3, 2]:
			st.set_normal(normal)
			st.set_uv(uv[i])
			st.set_color(colors[i] if not colors.is_empty() else Color.WHITE)
			st.add_vertex(points[i])
	func triangle(mat: Material, points: Array, normal: Vector3, uv: Array, colors: Array = []) -> void:
		var st := surface(mat)
		var order := [0, 1, 2]
		if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0:
			order = [0, 2, 1]
		for i in order:
			st.set_normal(normal)
			st.set_uv(uv[i])
			st.set_color(colors[i] if not colors.is_empty() else Color.WHITE)
			st.add_vertex(points[i])
	func box(mat: Material, center: Vector3, size: Vector3, rotation := Basis.IDENTITY, tint := Color.WHITE) -> void:
		var half := size / 2.0
		for axis in 3:
			for s in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[axis] = s
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = 1.0
				var v := Vector3.ZERO
				v[(axis + 2) % 3] = 1.0
				var corners: Array = []
				var coords: Array = []
				for q in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
					var p: Vector3 = (n + u * q[0] + v * q[1]) * half
					corners.append(center + rotation * p)
					coords.append(Vector2(p.dot(u), p.dot(v)))
				if s < 0:
					corners.reverse()
					coords.reverse()
				quad(mat, corners, rotation * n, coords, [tint, tint, tint, tint])
	func rod(mat: Material, a: Vector3, b: Vector3, radius: float, segments := 8) -> void:
		var axis := (b - a).normalized()
		var u := axis.cross(Vector3.UP).normalized()
		if u.length_squared() < 0.1:
			u = Vector3.RIGHT
		var v := axis.cross(u).normalized()
		for i in segments:
			var a0 := TAU * float(i) / segments
			var a1 := TAU * float(i + 1) / segments
			var p0 := (u * cos(a0) + v * sin(a0)) * radius
			var p1 := (u * cos(a1) + v * sin(a1)) * radius
			quad(mat, [a + p0, a + p1, b + p1, b + p0], (p0 + p1).normalized(), [Vector2(0, 0), Vector2(radius, 0), Vector2(radius, a.distance_to(b)), Vector2(0, a.distance_to(b))])
	func finish(parent: Node3D, mesh_name: String) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		for mat in surfaces:
			var st: SurfaceTool = surfaces[mat]
			st.generate_tangents()
			st.index()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		var node := MeshInstance3D.new()
		node.name = mesh_name
		node.mesh = mesh
		parent.add_child(node)
		return node

static func _mat(key: String, seed: int) -> Material:
	# Only paint/shutter colours vary. Grime shape seeds must not duplicate materials.
	var variant := posmod(seed, 4) if key in ["wall", "shutter"] else 0
	var cache_key := "%s_%d" % [key, variant]
	if _materials.has(cache_key):
		return _materials[cache_key]
	var m: StandardMaterial3D
	match key:
		"wall":
			m = Props.tex("painted_plaster_wall", 0.65, Color(["c9bc9c", "b2b5a1", "b8a898", "aaa89a"][variant])).duplicate()
		"old":
			m = Props.tex("plastered_wall_04", 0.7, Color("9a8d77")).duplicate()
		"floor":
			m = Props.tex("worn_tile_floor", 0.75, Color("a9b3ae")).duplicate()
		"concrete":
			m = Props.tex("concrete_floor_02", 0.32, Color("8f9189")).duplicate()
		"roof":
			m = Props.tex("corrugated_iron", 0.85, Color("817d71")).duplicate()
		"wood":
			m = Props.tex("brown_planks_05", 0.8, Color("7d735a")).duplicate()
		"iron":
			m = Props.plain(Color("37433e"), 0.67, 0.42)
		"shutter":
			m = Props.plain(Color(["5a7067", "776c58", "667777", "6c635b"][variant]), 0.79, 0.18)
		"glass":
			m = Props.plain(Color("243c3b"), 0.24, 0.12)
		"display_glass":
			m = Props.plain(Color(0.32, 0.48, 0.47, 0.17), 0.2, 0.05)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		"brick":
			m = Props.tex("plastered_wall_04", 3.1, Color("9a7059")).duplicate()
		"damp":
			m = Props.tex("plastered_wall_04", 1.35, Color("60685b")).duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.normal_scale = 0.45
		"lime":
			m = Props.tex("plastered_wall_04", 1.55, Color("ccc2a7")).duplicate()
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.normal_scale = 0.65
		"skirting":
			m = Props.tex("concrete_floor_worn_001", 1.7, Color("8c8d7d")).duplicate()
		"equipment":
			m = Props.tex("painted_plaster_wall", 2.0, Color("c1c4b9")).duplicate()
		_:
			m = Props.plain(Color("9d967f"), 0.92)
	m.uv1_triplanar = false
	m.uv1_world_triplanar = false
	m.vertex_color_use_as_albedo = true
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[cache_key] = m
	return m

## Feathered irregular patches use vertex alpha, so stains never look like square decals.
## UVs remain metre-scale; all patches of a type share one surface in each cutaway group.
static func _weather_patch(b: Batch, center: Vector3, size: Vector2, normal: Vector3, seed: int, light := false, opacity := 0.65) -> void:
	var tangent := Vector3(normal.z, 0, -normal.x)
	var mat := _mat("lime" if light else "damp", seed)
	var count := 11
	var inner: Array[Vector3] = []
	var outer: Array[Vector3] = []
	var uv: Array[Vector2] = []
	for i in count:
		var angle := TAU * float(i) / count
		var ragged := 0.76 + 0.21 * absf(sin(float(seed * 17 + i * 29) * 1.73))
		var offset := Vector2(cos(angle) * size.x, sin(angle) * size.y) * 0.5 * ragged
		outer.append(center + tangent * offset.x + Vector3.UP * offset.y)
		inner.append(center + tangent * offset.x * 0.68 + Vector3.UP * offset.y * 0.8)
		uv.append(offset)
	var tint := Color(1, 1, 1, opacity)
	var transparent := Color(1, 1, 1, 0)
	for i in count:
		var j := (i + 1) % count
		b.triangle(mat, [center, inner[i], inner[j]], normal, [Vector2.ZERO, uv[i] * 0.7, uv[j] * 0.7], [tint, tint, tint])
		# The patch ring must use clockwise winding on all wall orientations.
		b.triangle(mat, [inner[i], outer[i], outer[j]], normal, [uv[i] * 0.7, uv[i], uv[j]], [tint, transparent, transparent])
		b.triangle(mat, [inner[i], outer[j], inner[j]], normal, [uv[i] * 0.7, uv[j], uv[j] * 0.7], [tint, transparent, tint])

static func _lower_wall(b: Batch, center: Vector3, length: float, normal: Vector3, seed: int) -> void:
	var tangent := Vector3(normal.z, 0, -normal.x)
	var mat := _mat("damp", seed)
	var count := maxi(1, ceili(length / 0.75))
	# One continuous low gradient, not a row of stamped circles. The subtly uneven
	# top edge vanishes into plaster at approximately 45 cm above the floor.
	for i in count:
		var left := -length / 2.0 + i * length / count
		var right := -length / 2.0 + (i + 1) * length / count
		var edge_left := 0.45 + sin(float(seed * 3 + i) * 1.41) * 0.025
		var edge_right := 0.45 + sin(float(seed * 3 + i + 1) * 1.41) * 0.025
		var lower_left := center + tangent * left + Vector3.UP * 0.15
		var lower_right := center + tangent * right + Vector3.UP * 0.15
		var middle_left := center + tangent * left + Vector3.UP * 0.28
		var middle_right := center + tangent * right + Vector3.UP * 0.28
		var upper_left := center + tangent * left + Vector3.UP * edge_left
		var upper_right := center + tangent * right + Vector3.UP * edge_right
		var lower := Color(1, 1, 1, 0.22)
		var middle := Color(1, 1, 1, 0.08)
		var clear := Color(1, 1, 1, 0)
		b.quad(mat, [lower_left, lower_right, middle_right, middle_left], normal, [Vector2(left, 0.15), Vector2(right, 0.15), Vector2(right, 0.28), Vector2(left, 0.28)], [lower, lower, middle, middle])
		b.quad(mat, [middle_left, middle_right, upper_right, upper_left], normal, [Vector2(left, 0.28), Vector2(right, 0.28), Vector2(right, edge_right), Vector2(left, edge_left)], [middle, middle, clear, clear])
	if length > 1.8 and posmod(seed, 3) == 0:
		var offset := sin(float(seed) * 2.17) * length * 0.3
		_weather_patch(b, center + tangent * offset + Vector3.UP * 0.7 + normal * 0.001, Vector2(0.3, 0.85), normal, seed + 31, false, 0.12)

## A small irregular area of missing render: staggered, individually toned bricks
## with mortar between them, surrounded by chipped limewash rather than a solid panel.
static func _brick_repair(b: Batch, x: float, z: float, available_width: float, seed: int) -> void:
	var patch_w := minf(0.68, available_width * 0.84)
	var brick_w := minf(0.21, patch_w / 2.0)
	var cols := maxi(1, floori(patch_w / brick_w))
	_weather_patch(b, Vector3(x, 0.48, z), Vector2(minf(available_width * 0.94, patch_w + 0.1), 0.8), Vector3.BACK, seed, true, 0.92)
	for row in 4:
		var n := maxi(1, cols - (1 if row == 3 else 0))
		for col in n:
			var xx := x + (col - (n - 1) * 0.5) * brick_w + (0.035 if row % 2 else -0.025)
			xx = clampf(xx, x - available_width / 2.0 + brick_w / 2.0, x + available_width / 2.0 - brick_w / 2.0)
			var tone := 0.75 + 0.24 * absf(sin(float(seed * 11 + row * 5 + col * 7)))
			b.box(_mat("brick", seed), Vector3(xx, 0.22 + row * 0.135, z + 0.009), Vector3(brick_w - 0.014, 0.115, 0.016), Basis.IDENTITY, Color(tone, tone * 0.97, tone * 0.9))

static func _electrical_service(b: Batch, width: float, seed: int) -> void:
	var x := -width / 2.0 + 0.22
	var iron := _mat("iron", seed)
	b.box(_mat("equipment", seed), Vector3(x, 1.86, 0.12), Vector3(0.23, 0.37, 0.13))
	b.box(_mat("glass", seed), Vector3(x, 1.94, 0.191), Vector3(0.13, 0.1, 0.014))
	b.box(iron, Vector3(x + 0.075, 1.74, 0.195), Vector3(0.024, 0.035, 0.018))
	for shift in [-0.065, 0.065]:
		b.rod(iron, Vector3(x + shift, 2.05, 0.11), Vector3(x + shift, 2.68, 0.11), 0.011, 6)
		b.rod(iron, Vector3(x + shift, 1.67, 0.11), Vector3(x + shift, 0.55, 0.11), 0.011, 6)
		b.box(iron, Vector3(x + shift, 2.4, 0.1), Vector3(0.035, 0.025, 0.055))

static func _air_conditioner(b: Batch, width: float, seed: int, y := 5.98) -> void:
	if width < 5.0:
		return
	var x := width / 2.0 - 0.65
	var metal := _mat("equipment", seed)
	var iron := _mat("iron", seed)
	b.box(metal, Vector3(x, y, 0.24), Vector3(0.87, 0.51, 0.36))
	b.box(iron, Vector3(x - 0.13, y, 0.426), Vector3(0.46, 0.37, 0.012))
	for i in 9:
		b.box(metal, Vector3(x - 0.13, y - 0.16 + i * 0.04, 0.44), Vector3(0.48, 0.012, 0.015))
	for i in 6:
		b.box(iron, Vector3(x + 0.29, y - 0.14 + i * 0.05, 0.426), Vector3(0.12, 0.018, 0.015))
	for s in [-1.0, 1.0]:
		b.rod(iron, Vector3(x + s * 0.28, y - 0.32, 0.03), Vector3(x + s * 0.28, y - 0.32, 0.43), 0.022, 6)
		b.rod(iron, Vector3(x + s * 0.28, y - 0.32, 0.43), Vector3(x + s * 0.28, y - 0.11, 0.03), 0.016, 6)
	b.rod(_mat("old", seed), Vector3(x + 0.44, y - 0.05, 0.15), Vector3(x + 0.54, y - 0.5, 0.09), 0.024, 6)
	_weather_patch(b, Vector3(x + 0.33, y - 0.68, 0.045), Vector2(0.18, 0.85), Vector3.BACK, seed + 51, false, 0.65)

static func _side_weather(b: Batch, width: float, center_z: float, length: float, seed: int) -> void:
	for s in [-1.0, 1.0]:
		# Narrow cement skirting stays inside the wall footprint, with irregular damp above.
		b.box(_mat("skirting", seed), Vector3(s * (width / 2.0 - 0.294), 0.31, center_z), Vector3(0.012, 0.34, length))
		_lower_wall(b, Vector3(s * (width / 2.0 - 0.306), 0, center_z), length - 0.08, Vector3(-s, 0, 0), seed + int(s * 7))
		_lower_wall(b, Vector3(s * (width / 2.0 + 0.003), 0, center_z), length - 0.08, Vector3(s, 0, 0), seed + int(s * 13))

static func _pier_weather(b: Batch, x: float, pier_width: float, z: float, seed: int, brick := true) -> void:
	b.box(_mat("skirting", seed), Vector3(x, 0.3, z - 0.004), Vector3(pier_width - 0.035, 0.32, 0.012))
	_lower_wall(b, Vector3(x, 0, z + 0.004), pier_width - 0.025, Vector3.BACK, seed)
	_weather_patch(b, Vector3(x + pier_width * 0.13, 1.1, z + 0.006), Vector2(pier_width * 0.65, 1.55), Vector3.BACK, seed + 22, true, 0.65)
	_weather_patch(b, Vector3(x - pier_width * 0.19, 1.9, z + 0.007), Vector2(pier_width * 0.33, 1.75), Vector3.BACK, seed + 8, false, 0.38)
	if brick:
		_brick_repair(b, x, z + 0.009, pier_width - 0.025, seed)

## Wall with an actual rectangular opening; the aperture is empty, reveals have depth.
static func _opening(b: Batch, mat: Material, x: float, y: float, z: float, width: float, height: float, aperture: float, opening_h: float, thickness := 0.3) -> void:
	var pier := (width - aperture) / 2.0
	for s in [-1.0, 1.0]:
		b.box(mat, Vector3(x + s * (aperture / 2.0 + pier / 2.0), y + height / 2.0, z), Vector3(pier, height, thickness))
	if height > opening_h:
		b.box(mat, Vector3(x, y + (height + opening_h) / 2.0, z), Vector3(aperture, height - opening_h, thickness))

static func _window(b: Batch, x: float, y: float, z: float, w: float, h: float, seed: int, open_shutters := true) -> void:
	var stone := _mat("old", seed)
	var trim := _mat("shutter", seed)
	# Deep jamb, recessed glazing, sash and projecting sill.
	b.box(_mat("glass", seed), Vector3(x, y + h / 2.0, z - 0.19), Vector3(w, h, 0.045))
	for s in [-1.0, 1.0]:
		b.box(stone, Vector3(x + s * (w / 2.0 + 0.06), y + h / 2.0, z - 0.06), Vector3(0.12, h + 0.2, 0.34))
		b.box(trim, Vector3(x + s * w / 2.0, y + h / 2.0, z), Vector3(0.065, h, 0.07))
	b.box(stone, Vector3(x, y - 0.08, z + 0.1), Vector3(w + 0.35, 0.16, 0.5))
	b.box(stone, Vector3(x, y + h + 0.06, z + 0.03), Vector3(w + 0.28, 0.12, 0.34))
	b.box(trim, Vector3(x, y + h / 2.0, z + 0.02), Vector3(0.045, h, 0.08))
	b.box(trim, Vector3(x, y + h * 0.57, z + 0.02), Vector3(w, 0.045, 0.08))
	if open_shutters:
		for s in [-1.0, 1.0]:
			var pivot := Vector3(x + s * (w / 2.0 + 0.15), y, z + 0.05)
			var yaw := Basis(Vector3.UP, s * 0.38)
			var center := pivot + yaw * Vector3(s * w * 0.24, h / 2.0, 0)
			b.box(trim, center, Vector3(w * 0.45, h + 0.08, 0.065), yaw)
			for i in 8:
				var slat := center + Vector3(0, -h * 0.4 + i * h * 0.11, 0.05)
				b.box(_mat("iron", seed), slat, Vector3(w * 0.37, 0.025, 0.045), yaw)

static func _rail(b: Batch, x0: float, x1: float, y: float, z: float, seed: int) -> void:
	var iron := _mat("iron", seed)
	for offset in [0.15, 0.93]:
		b.rod(iron, Vector3(x0, y + offset, z), Vector3(x1, y + offset, z), 0.027)
	var n := maxi(2, ceili((x1 - x0) / 0.2))
	for i in n + 1:
		var x := lerpf(x0, x1, float(i) / n)
		b.rod(iron, Vector3(x, y, z), Vector3(x, y + 0.95, z), 0.014)

static func _sloped_roof(b: Batch, width: float, depth: float, eave: float, ridge: float, seed: int) -> void:
	var mat := _mat("roof", seed)
	var z0 := 0.45
	var z1 := -depth - 0.3
	var middle := (z0 + z1) / 2.0
	var x0 := -width / 2.0 - 0.25
	var x1 := width / 2.0 + 0.25
	for part in [[z0, eave, middle, ridge], [middle, ridge, z1, eave]]:
		var a := Vector3(x0, part[1], part[0])
		var c := Vector3(x1, part[3], part[2])
		var normal := Vector3(0, absf(part[0] - part[2]), part[3] - part[1]).normalized()
		if part[0] == middle:
			normal.z = -absf(normal.z)
		b.quad(mat, [a, Vector3(x1, a.y, a.z), c, Vector3(x0, c.y, c.z)], normal, [Vector2(0, 0), Vector2(width, 0), Vector2(width, depth / 2.0), Vector2(0, depth / 2.0)])
	# Folded ridge and gutters have thickness rather than a zero-thickness silhouette.
	b.box(mat, Vector3(0, ridge + 0.025, middle), Vector3(width + 0.55, 0.08, 0.18))
	for z in [z0, z1]:
		b.box(_mat("iron", seed), Vector3(0, eave - 0.04, z), Vector3(width + 0.6, 0.13, 0.13))
	# Masonry gables close the two end faces below the corrugated roof sheets.
	for s in [-1.0, 1.0]:
		var x: float = s * (width / 2.0 - 0.02)
		b.triangle(_mat("wall", seed), [Vector3(x, eave, 0.2), Vector3(x, ridge - 0.015, middle), Vector3(x, eave, -depth)], Vector3(s, 0, 0), [Vector2(0, 0), Vector2(depth / 2.0, ridge - eave), Vector2(depth, 0)])

## Kinds: restaurant, repair, lodging, residential. Residential seed selects six profiles.
## Blockers are local XZ footprints; upper/roof can be hidden independently for cutaway.
## Geometry is authored at the requested lot size; only balcony/eave details overhang.
static func build(parent: Node3D, kind: String, width: float, depth: float, seed: int = 0, split_shell := false) -> Dictionary:
	# Lot boundaries must stay exact: widening a narrow terrace breaks navigation.
	assert(width >= 3.0 and depth >= 4.0, "Architecture lots require at least 3m width and 4m depth")
	assert(kind != "lodging" or width >= 7.0, "Courtyard lodging requires at least 7m width")
	var w := width
	var d := depth
	var ground := Node3D.new()
	ground.name = "GroundArchitecture"
	var upper := Node3D.new()
	upper.name = "UpperArchitecture"
	var roof := Node3D.new()
	roof.name = "RoofArchitecture"
	parent.add_child(ground)
	parent.add_child(upper)
	parent.add_child(roof)
	var front_walls: Node3D = null
	if kind == "lodging" or split_shell:
		front_walls = Node3D.new()
		front_walls.name = "FrontWingWalls"
		parent.add_child(front_walls)
	var occluding_shell: Node3D = null
	if kind == "lodging":
		occluding_shell = Node3D.new()
		occluding_shell.name = "CourtyardShell"
		parent.add_child(occluding_shell)
	var g := Batch.new()
	var slab := Batch.new() if split_shell or kind == "lodging" else g
	var u := Batch.new()
	var r := Batch.new()
	var fw := Batch.new()
	var wall := _mat("wall", seed)
	var old := _mat("old", seed)
	var iron := _mat("iron", seed)
	var shutter := _mat("shutter", seed)
	var blockers: Array[Rect2] = []
	var h := 7.2
	var sign_y := 2.95
	# All shells have floors and individual thickness walls, never a footprint-sized solid box.
	slab.box(_mat("concrete" if kind in ["repair", "lodging"] else "floor", seed), Vector3(0, 0.07, -d / 2.0), Vector3(w, 0.14, d))
	for s in [-1.0, 1.0]:
		if kind == "lodging":
			var split := minf(4.0, d * 0.5)
			fw.box(old, Vector3(s * (w / 2.0 - 0.15), 1.65, -split / 2.0), Vector3(0.3, 3.3, split))
			g.box(old, Vector3(s * (w / 2.0 - 0.15), 1.65, -split - (d - split) / 2.0), Vector3(0.3, 3.3, d - split))
		else:
			g.box(old, Vector3(s * (w / 2.0 - 0.15), 1.65, -d / 2.0), Vector3(0.3, 3.3, d))
		blockers.append(Rect2(s * (w / 2.0 - 0.15) - 0.15, -d, 0.3, d))
	g.box(old, Vector3(0, 1.65, -d + 0.15), Vector3(w, 3.3, 0.3))
	blockers.append(Rect2(-w / 2.0, -d, w, 0.3))
	if kind == "lodging":
		var split := minf(4.0, d * 0.5)
		_side_weather(fw, w, -split / 2.0, split, seed)
		_side_weather(g, w, -split - (d - split) / 2.0, d - split, seed + 17)
	else:
		_side_weather(g, w, -d / 2.0, d, seed)
	g.box(_mat("skirting", seed), Vector3(0, 0.31, -d + 0.3), Vector3(w - 0.5, 0.34, 0.012))
	_lower_wall(g, Vector3(0, 0, -d + 0.308), w - 0.6, Vector3.BACK, seed + 11)
	_weather_patch(g, Vector3(-w * 0.21, 1.65, -d + 0.309), Vector2(w * 0.29, 2.1), Vector3.BACK, seed + 19, false, 0.25)
	_weather_patch(g, Vector3(w * 0.17, 1.5, -d + 0.31), Vector2(w * 0.21, 1.75), Vector3.BACK, seed + 47, true, 0.43)
	if kind == "lodging":
		h = 6.3
		var corridor := 3.0
		var wing := (w - corridor) / 2.0
		var front_depth := minf(4.0, d * 0.5)
		var courtyard := minf(7.0, w - 1.4)
		var rear_wing := (w - courtyard) / 2.0
		# Re-entrant plan: a three-metre alley opens to a wider rear court.
		# These five rectangles are also consumed by the pedestrian navigation.
		blockers.clear()
		for s in [-1.0, 1.0]:
			var x: float = s * (corridor / 2.0 + wing / 2.0)
			var door_width := minf(1.2, wing - 0.5)
			_opening(fw, wall, x, 0.14, -0.2, wing, 3.2, door_width, 2.25)
			fw.box(_mat("wood", seed), Vector3(x, 1.3, -0.49), Vector3(door_width - 0.1, 2.3, 0.07))
			var front_pier := (wing - door_width) / 2.0
			for sx in [-1.0, 1.0]:
				_pier_weather(fw, x + sx * (door_width / 2.0 + front_pier / 2.0), front_pier, -0.044, seed + int(s * 5 + sx * 7), sx == s)
				fw.box(_mat("skirting", seed), Vector3(x + sx * (door_width / 2.0 + 0.04), 1.31, -0.15), Vector3(0.075, 2.34, 0.28))
			fw.box(old, Vector3(x, 2.46, -0.15), Vector3(door_width + 0.18, 0.14, 0.31))
			# Corridor wall is built around a door aperture, with deep timber reveal.
			var door_z := -front_depth * 0.52
			var inner_x: float = s * (corridor / 2.0 + 0.11)
			var segment_front := -door_z - 0.5
			var segment_back := front_depth + door_z - 0.5
			fw.box(wall, Vector3(inner_x, 1.65, -segment_front / 2.0), Vector3(0.22, 3.3, segment_front))
			fw.box(wall, Vector3(inner_x, 1.65, -front_depth + segment_back / 2.0), Vector3(0.22, 3.3, segment_back))
			fw.box(wall, Vector3(inner_x, 2.85, door_z), Vector3(0.22, 0.9, 1.0))
			fw.box(_mat("wood", seed), Vector3(inner_x + s * 0.07, 1.3, door_z), Vector3(0.055, 2.3, 0.93))
			for dz in [-0.52, 0.52]:
				fw.box(old, Vector3(inner_x - s * 0.09, 1.3, door_z + dz), Vector3(0.13, 2.45, 0.09))
			fw.rod(iron, Vector3(inner_x - s * 0.15, 1.0, door_z + 0.3), Vector3(inner_x - s * 0.15, 1.2, door_z + 0.3), 0.025)
			blockers.append(Rect2(x - wing / 2.0, -front_depth, wing, front_depth))
			fw.box(wall, Vector3(x, 1.65, -front_depth + 0.12), Vector3(wing, 3.3, 0.24))
			# Upper rooms have separate walls, floor slabs, and actual window openings.
			_opening(u, wall, x, 3.4, -0.15, wing, 2.65, minf(1.35, wing - 0.6), 2.1)
			_window(u, x, 3.55, 0.02, minf(1.27, wing - 0.68), 1.85, seed + 1)
			u.box(old, Vector3(x, 3.36, -front_depth / 2.0), Vector3(wing, 0.16, front_depth))
			for sx in [-1.0, 1.0]:
				u.box(wall, Vector3(x + sx * (wing / 2.0 - 0.12), 4.72, -front_depth / 2.0), Vector3(0.24, 2.7, front_depth))
			u.box(wall, Vector3(x, 4.72, -front_depth + 0.12), Vector3(wing, 2.7, 0.24))
			r.box(_mat("roof", seed), Vector3(x, 6.13, -front_depth / 2.0), Vector3(wing + 0.1, 0.16, front_depth + 0.25))
			r.box(old, Vector3(x, 6.05, 0.09), Vector3(wing + 0.16, 0.25, 0.38))
			# Low rear rooms leave a genuine open-air court, rather than a roof gap.
			var rear_x: float = s * (courtyard / 2.0 + rear_wing / 2.0)
			var rear_depth := d - front_depth - 0.3
			var rear_z := -front_depth - rear_depth / 2.0
			g.box(wall, Vector3(s * (courtyard / 2.0 + 0.1), 1.45, rear_z), Vector3(0.2, 2.9, rear_depth))
			g.box(wall, Vector3(rear_x, 1.45, -front_depth - 0.1), Vector3(rear_wing, 2.9, 0.2))
			g.box(_mat("wood", seed), Vector3(s * (courtyard / 2.0 - 0.015), 1.2, rear_z), Vector3(0.04, 2.1, 1.0))
			_lower_wall(g, Vector3(s * (courtyard / 2.0 - 0.004), 0, rear_z), rear_depth - 0.1, Vector3(-s, 0, 0), seed + int(s * 11))
			_lower_wall(g, Vector3(rear_x, 0, -front_depth + 0.003), rear_wing - 0.1, Vector3.BACK, seed + int(s * 23))
			_weather_patch(u, Vector3(x, 5.75, 0.008), Vector2(wing * 0.72, 0.32), Vector3.BACK, seed + int(s * 5), false, 0.37)
			r.box(_mat("roof", seed), Vector3(rear_x, 3.08, rear_z), Vector3(rear_wing + 0.25, 0.12, rear_depth + 0.2))
			blockers.append(Rect2(rear_x - rear_wing / 2.0, -d + 0.3, rear_wing, rear_depth))
		blockers.append(Rect2(-w / 2.0, -d, w, 0.3))
		# Keep the room plan legible when the tall shell yields to the camera.
		# These low courses stay wholly inside the existing blocked footprints.
		for room in blockers:
			var course := minf(0.22, minf(room.size.x, room.size.y) / 2.0)
			var middle := room.get_center()
			for side in [-1.0, 1.0]:
				slab.box(old, Vector3(middle.x, 0.24, middle.y + side * (room.size.y - course) / 2.0), Vector3(room.size.x, 0.32, course))
				slab.box(old, Vector3(middle.x + side * (room.size.x - course) / 2.0, 0.24, middle.y), Vector3(course, 0.32, room.size.y))
		fw.box(old, Vector3(0, 3.0, 0), Vector3(corridor, 0.28, 0.4))
		g.box(old, Vector3(0, 0.09, -0.12), Vector3(corridor, 0.08, 0.55))
		_air_conditioner(u, w, seed, 5.68)
	elif kind == "repair":
		h = 4.75
		var opening := maxf(2.4, w - 1.1)
		var shop_pier := (w - opening) / 2.0
		_opening(g, wall, 0, 0.14, -0.1, w, 3.45, opening, 2.9)
		# Rolled steel shutter header and grooved vertical guides.
		g.box(shutter, Vector3(0, 3.0, 0.05), Vector3(opening, 0.48, 0.32))
		for i in 5:
			g.box(iron, Vector3(0, 2.81 + i * 0.085, 0.23), Vector3(opening, 0.018, 0.035))
		for s in [-1.0, 1.0]:
			g.box(iron, Vector3(s * (opening / 2.0 + 0.025), 1.55, 0.09), Vector3(0.08, 2.9, 0.12))
			blockers.append(Rect2(s * (opening / 2.0 + shop_pier / 2.0) - shop_pier / 2.0, -0.3, shop_pier, 0.6))
			_pier_weather(g, s * (w / 2.0 - shop_pier / 2.0), shop_pier, 0.056, seed + int(s * 9))
		# Offset high windows and a shallow pitched roof distinguish the low repair workshop.
		for s in [-1.0, 1.0]:
			u.box(wall, Vector3(s * (w / 2.0 - 0.14), 3.85, -d / 2.0), Vector3(0.28, 0.9, d))
		u.box(wall, Vector3(0, 3.85, -d + 0.14), Vector3(w, 0.9, 0.28))
		for i in 3:
			var bay := (w - 0.4) / 3.0
			var wx := -bay + i * bay
			_opening(u, wall, wx, 3.4, -0.14, bay, 0.9, minf(1.27, w * 0.2 + 0.07), 0.7)
			_window(u, wx, 3.55, 0.02, minf(1.2, w * 0.2), 0.42, seed, false)
		_sloped_roof(r, w, d, 4.3, h, seed)
	else:
		var restaurant := kind == "restaurant"
		var shop := kind in ["shop", "service"]
		var profile := posmod(seed, 6) if not restaurant else 0
		var ground_opening := maxf(2.4, w - 1.2) if restaurant or shop else maxf(2.5, w * 0.55)
		_opening(g, wall, 0, 0.14, -0.12, w, 3.3, ground_opening, 2.6)
		var pier := (w - ground_opening) / 2.0
		for s in [-1.0, 1.0]:
			blockers.append(Rect2(s * (ground_opening / 2.0 + pier / 2.0) - pier / 2.0, -0.3, pier, 0.6))
			_pier_weather(g, s * (ground_opening / 2.0 + pier / 2.0), pier, 0.035, seed + int(s * 13), s < 0 or seed % 2 == 0)
		g.box(old, Vector3(0, 0.12, 0.1), Vector3(w, 0.14, 0.55))
		# Upper storey is assembled around two tall openings, not one solid face.
		var bays := 3 if w >= 5.5 and (profile == 2 or profile == 5) else 2
		var bay := (w - 0.4) / bays
		for i in bays:
			var x := -w / 2.0 + 0.2 + (i + 0.5) * bay
			_opening(u, wall, x, 3.45, -0.14, bay, 3.05, minf(1.25, bay - 0.6), 2.3)
			_window(u, x, 3.6, 0.025, minf(1.18, bay - 0.67), 2.05, seed, profile != 2 and profile != 4)
		for s in [-1.0, 1.0]:
			u.box(wall, Vector3(s * (w / 2.0 - 0.14), 4.95, -d / 2.0), Vector3(0.28, 3.0, d))
			u.box(old, Vector3(s * (w / 2.0 - 0.15), 3.55, 0.42), Vector3(0.18, 0.35, 1.0))
		u.box(wall, Vector3(0, 4.95, -d + 0.14), Vector3(w, 3.0, 0.28))
		u.box(old, Vector3(0, 3.4, -d / 2.0 + 0.4), Vector3(w + 0.12, 0.22, d + 0.9))
		# Balcony slab and iron balustrade are silhouette geometry.
		var balcony_w := w - 0.15 if profile % 2 == 0 else w * 0.55
		u.box(old, Vector3(0, 3.52, 0.48), Vector3(balcony_w, 0.13, 1.1))
		_rail(u, -balcony_w / 2.0 + 0.1, balcony_w / 2.0 - 0.1, 3.6, 1.0, seed)
		for s in [-1.0, 1.0]:
			u.rod(iron, Vector3(s * (balcony_w / 2.0 - 0.1), 4.53, 0), Vector3(s * (balcony_w / 2.0 - 0.1), 4.53, 1.0), 0.027)
		# Cornice mouldings project at different depths; a rear roof slope retains an urban terrace profile.
		for offset in [0.0, 0.13]:
			r.box(old, Vector3(0, 6.5 + offset, 0.05 + offset * 0.5), Vector3(w + 0.25 + offset, 0.09, 0.48))
		if profile in [2, 3, 5]:
			h = 7.65 if profile == 5 else 7.17
			r.box(old, Vector3(0, 6.58, -d / 2.0), Vector3(w + 0.12, 0.16, d + 0.15))
			for s in [-1.0, 1.0]:
				r.box(wall, Vector3(s * (w / 2.0 - 0.09), 6.85, -d / 2.0), Vector3(0.18, 0.55, d))
			r.box(wall, Vector3(0, 6.85, 0), Vector3(w, 0.55, 0.18))
			r.box(old, Vector3(0, 7.13, 0), Vector3(w + 0.12, 0.08, 0.32))
			if profile == 5:
				_rail(r, -w / 2.0 + 0.25, w / 2.0 - 0.25, 6.7, -d + 0.12, seed)
		else:
			_sloped_roof(r, w, d, 6.62, h, seed)
		if restaurant:
			# Segmented cloth canopy above the actual recess, supported by slim steel arms.
			var segments := maxi(4, ceili(w / 0.8))
			for i in segments:
				var x := -w / 2.0 + (i + 0.5) * w / segments
				g.box(shutter if i % 2 == 0 else _mat("old", seed), Vector3(x, 2.66, 0.5), Vector3(w / segments - 0.015, 0.045, 1.2), Basis(Vector3.RIGHT, 0.15))
			for s in [-1.0, 1.0]:
				g.rod(iron, Vector3(s * (w / 2.0 - 0.4), 2.3, -0.1), Vector3(s * (w / 2.0 - 0.4), 2.55, 1.05), 0.022)
		else:
			# Recessed folding residential entry, leaving central 2.5 m as an open passage.
			for s in [-1.0, 1.0]:
				g.box(shutter, Vector3(s * (ground_opening / 2.0 + 0.03), 1.4, -0.42), Vector3(0.12, 2.5, 0.55))
			if shop:
				# Shop displays sit behind a real reveal; the central entrance stays open.
				var display_w := maxf(0.28, (ground_opening - 1.6) / 2.0)
				for s in [-1.0, 1.0]:
					var glass_x: float = s * (0.8 + display_w / 2.0)
					for side in [-1.0, 1.0]:
						g.box(iron, Vector3(glass_x + side * (display_w / 2.0 - 0.022), 1.35, -0.55), Vector3(0.045, 2.4, 0.07))
					for y in [0.17, 2.53]:
						g.box(iron, Vector3(glass_x, y, -0.55), Vector3(display_w, 0.045, 0.07))
					g.box(_mat("display_glass", seed), Vector3(glass_x, 1.4, -0.5), Vector3(maxf(0.16, display_w - 0.09), 2.23, 0.025))
					g.box(old, Vector3(glass_x, 0.2, -0.46), Vector3(display_w + 0.05, 0.1, 0.16))
		_air_conditioner(u, w, seed)
	if kind != "lodging":
		var header_y := 4.17 if kind == "repair" else 6.22
		for i in 3:
			_weather_patch(u, Vector3(-w / 2.0 + (i + 0.5) * w / 3.0, header_y, 0.018), Vector2(w * 0.28, 0.22 if kind == "repair" else 0.36), Vector3.BACK, seed + i * 11, i == 1, 0.36)
		for s in [-1.0, 1.0]:
			if kind != "repair":
				_weather_patch(u, Vector3(s * (w / 2.0 - 0.23), 4.78, 0.019), Vector2(0.26, 2.5), Vector3.BACK, seed + int(s * 17), false, 0.4)
	# Rain pipe elbows, roof drain, horizontal service wire: small geometry with purpose.
	var px := -w / 2.0 + 0.2
	var pipe_batch := fw if kind == "lodging" else g
	_electrical_service(pipe_batch, w, seed)
	pipe_batch.rod(iron, Vector3(px, 0.2, 0.2), Vector3(px, 3.25, 0.2), 0.045)
	u.rod(iron, Vector3(px, 3.25, 0.2), Vector3(px, h - 0.4, 0.2), 0.045)
	for y in [0.6, 2.2]:
		if y < h - 0.4:
			pipe_batch.box(iron, Vector3(px, y, 0.18), Vector3(0.14, 0.04, 0.12))
	u.box(iron, Vector3(px, 4.2, 0.18), Vector3(0.14, 0.04, 0.12))
	u.rod(iron, Vector3(px, h - 0.4, 0.2), Vector3(px, h - 0.33, 0.43), 0.045)
	ground.set_meta("blockers", blockers)
	if kind == "lodging":
		slab.finish(ground, "MasonryAndDetails")
		g.finish(occluding_shell, "CourtyardWalls")
	elif split_shell:
		slab.finish(ground, "PermanentFloor")
		g.finish(front_walls, "CutawayGroundShell")
	else:
		g.finish(ground, "MasonryAndDetails")
	u.finish(upper, "UpperAndBalcony")
	r.finish(roof, "RoofAndCornice")
	if kind == "lodging":
		fw.finish(front_walls, "FrontWallsAndDoors")
	return {"height": h, "ground": ground, "upper": upper, "roof": roof, "front_walls": front_walls, "occluding_shell": occluding_shell, "front_occlusion_cut": split_shell, "blockers": blockers, "sign_position": Vector3(0, sign_y, 0.15), "sign_width": w - 0.6}
