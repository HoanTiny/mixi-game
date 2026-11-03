extends SceneTree
## All story locations: stable plot extents, finite indexed geometry and separate
## cutaway groups. Run without editor/import; add --integration for the real map.
const Fronts := preload("res://scripts/world/street_prototype.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const WorkProps := preload("res://scripts/work/work_props.gd")
const City := preload("res://scripts/world/real_city.gd")
var failures: Array[String] = []

class FacadeHost:
	extends RefCounted
	var font: Font = UI.text_font()
	func _block(size: Vector3, pos: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
		return WorkProps.box(parent, size, WorkProps.plain(color), pos)

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _geometry(node: Node3D, transform: Transform3D, id: String, w: float, d: float) -> int:
	var frame := transform * node.transform
	var triangles := 0
	if node is MeshInstance3D and node.mesh is ArrayMesh:
		var mesh: ArrayMesh = node.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			_check(normals.size() == vertices.size() and uv.size() == vertices.size(), id + ": missing shading data")
			triangles += indices.size() / 3
			for vertex in vertices:
				var p := frame * vertex
				_check(p.is_finite(), id + ": non-finite geometry")
				# Small balcony/eave projections are allowed; plots are never scaled.
				_check(absf(p.x) <= w / 2.0 + 0.5, id + ": geometry widened lot")
				_check(p.z >= -d - 0.5 and p.z <= 1.4, id + ": geometry exceeds depth")
	for child in node.get_children():
		if child is Node3D:
			triangles += _geometry(child, frame, id, w, d)
	return triangles

func _run() -> void:
	var story: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/hn_pho_co_story.json"))
	var host := FacadeHost.new()
	var report: Array = []
	var identities := {}
	_check(story.locations.size() == Fronts.LOCATIONS.size(), "Architecture coverage does not match all named story locations")
	for id: String in story.locations:
		_check(id in Fronts.LOCATIONS, "Missing named frontage: " + id)
		var cfg: Dictionary = story.locations[id]
		var node := Node3D.new()
		root.add_child(node)
		var kit := Fronts.build(host, node, id, float(cfg.w), float(cfg.d))
		for group in ["ground", "upper", "roof"]:
			_check(kit.has(group) and kit[group] is Node3D, id + ": missing cutaway group " + group)
		_check(kit.ground != kit.upper and kit.upper != kit.roof, id + ": cutaway groups alias")
		_check(node.scale == Vector3.ONE, id + ": lot has been stretched")
		_check(kit.get("owns_dressing", false), id + ": duplicate legacy dressing would remain")
		if id not in Fronts.PRIMARY:
			_check(kit.front_walls != null and kit.get("front_occlusion_cut", false), id + ": tall front shell would keep hiding An after roof cut")
		if id == "xom_bo_me":
			_check(kit.get("occluding_shell") != null, "Lodging rear courtyard walls cannot be cut")
			var floor_mesh: Mesh = kit.ground.get_child(0).mesh
			_check(floor_mesh.get_aabb().end.y <= 0.5, "Lodging permanent floor still contains tall walls")
			_check(floor_mesh.get_aabb().end.y >= 0.28, "Lodging cutaway lost its low room outlines")
		identities[kit.identity] = true
		var tris := _geometry(node, Transform3D.IDENTITY, id, float(cfg.w), float(cfg.d))
		_check(tris > 100 and tris < 180000, id + ": unexpected geometry budget")
		report.append({"id": id, "identity": kit.identity, "triangles": tris})
		node.free()
	_check(identities.size() >= 14, "Location uses collapsed to too few building identities")
	if "--integration" in OS.get_cmdline_user_args():
		var city := City.new("hn_pho_co")
		var start := city.loc_door("xom_bo_me")
		for id: String in story.locations:
			var door := city.loc_door(id)
			_check(city.walkable(door), "Door blocked: " + id)
			_check(id == "xom_bo_me" or not city.path(start, door).is_empty(), "No route from home: " + id)
	if failures.is_empty():
		print("PASS: 19 named locations, varied uses, exact plots, finite geometry, separate cutaways, no legacy dressing; ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
