extends SceneTree
## Rebuild authored architecture scenes without opening the editor or importing assets.
## godot --headless --path . -s tools/build_architecture.gd
## Add -- --preview in a graphical run to capture tests/architecture-kit-preview.png.
const Kit := preload("res://scripts/architecture/street_kit.gd")
const TYPES := [
	{"id": "rice_shop", "kind": "restaurant", "width": 8.0, "depth": 8.0, "seed": 0},
	{"id": "repair_workshop", "kind": "repair", "width": 9.0, "depth": 8.0, "seed": 1},
	{"id": "lodging_courtyard", "kind": "lodging", "width": 13.0, "depth": 8.0, "seed": 2},
	{"id": "terrace_shuttered", "kind": "residential", "width": 5.8, "depth": 8.0, "seed": 0},
	{"id": "terrace_narrow_balcony", "kind": "residential", "width": 5.2, "depth": 8.0, "seed": 1},
	{"id": "terrace_three_bay", "kind": "residential", "width": 6.6, "depth": 8.0, "seed": 2},
	{"id": "terrace_flat_roof", "kind": "residential", "width": 5.5, "depth": 8.0, "seed": 3},
	{"id": "terrace_plain_sash", "kind": "residential", "width": 5.8, "depth": 8.0, "seed": 4},
	{"id": "terrace_roof_rail", "kind": "residential", "width": 6.6, "depth": 8.0, "seed": 5},
]

func _initialize() -> void:
	call_deferred("_run")

func _owned(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		_owned(child, scene)

func _validate_mesh(mesh: ArrayMesh, id: String) -> Dictionary:
	var tris := 0
	var vertices := 0
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
		assert(points.size() == normals.size(), "%s missing normals" % id)
		assert(points.size() == uvs.size(), "%s missing UVs" % id)
		assert(points.size() * 4 == tangents.size(), "%s missing tangents" % id)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for i in range(0, indices.size(), 3):
			var a := points[indices[i]]
			var b := points[indices[i + 1]]
			var c := points[indices[i + 2]]
			# Godot's front-facing triangles are clockwise, opposite vertex normals.
			assert((b - a).cross(c - a).dot(normals[indices[i]]) <= 0.001, "%s inverted face" % id)
		tris += indices.size() / 3
		vertices += points.size()
	return {"triangles": tris, "vertices": vertices, "surfaces": mesh.get_surface_count()}

func _validate_plan() -> void:
	# Regression: narrow filler lots must never silently grow into their neighbours.
	for width in [3.2, 3.4, 3.6]:
		for seed in 6:
			var house := Node3D.new()
			var result := Kit.build(house, "residential", width, 8, seed)
			var mesh_node: MeshInstance3D = result.ground.get_child(0)
			var bounds := mesh_node.mesh.get_aabb()
			assert(bounds.position.x >= -width / 2.0 - 0.01)
			assert(bounds.end.x <= width / 2.0 + 0.01)
			_validate_mesh(mesh_node.mesh, "narrow_" + str(width))
			house.free()
	var lodging := Node3D.new()
	var plan := Kit.build(lodging, "lodging", 13, 8, 2)
	assert(plan.front_walls != null)
	var permanent_mesh: ArrayMesh = plan.ground.get_child(0).mesh
	for surface in permanent_mesh.get_surface_count():
		var points: PackedVector3Array = permanent_mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in points:
			if point.z > -3.99:
				# The compact-map cutaway keeps 40 cm masonry courses inside closed
				# room footprints. Nothing above the floor may enter the open passage.
				assert(point.y <= 0.401, "Tall front-wing occluder left in permanent ground mesh")
				if point.y > 0.2:
					var inside_room := false
					for blocker in plan.blockers:
						inside_room = inside_room or blocker.grow(0.001).has_point(Vector2(point.x, point.z))
					assert(inside_room, "Permanent masonry blocks the lodging passage")
	for point in [Vector2(0, -0.2), Vector2(-1.49, -3.9), Vector2(1.49, -3.9), Vector2(-3.49, -5.5), Vector2(3.49, -5.5), Vector2(0, -7.6)]:
		for blocker in plan.blockers:
			assert(not blocker.has_point(point), "Lodging courtyard/passage blocked")
	assert(plan.blockers.size() == 5)
	lodging.free()

func _run() -> void:
	var preview := "--preview" in OS.get_cmdline_user_args()
	if preview:
		await _preview()
		quit()
		return
	DirAccess.make_dir_recursive_absolute("res://assets/architecture")
	DirAccess.make_dir_recursive_absolute("res://scenes/architecture")
	var metrics: Array = []
	for cfg in TYPES:
		if "--hero-only" in OS.get_cmdline_user_args() and cfg.kind == "residential":
			continue
		var node := Node3D.new()
		node.name = cfg.id
		root.add_child(node)
		var result: Dictionary = Kit.build(node, cfg.kind, cfg.width, cfg.depth, cfg.seed)
		node.set_meta("kind", cfg.kind)
		node.set_meta("width", cfg.width)
		node.set_meta("depth", cfg.depth)
		node.set_meta("height", result.height)
		node.set_meta("seed", cfg.seed)
		var count := {"id": cfg.id, "triangles": 0, "vertices": 0, "surfaces": 0}
		var group_names := ["ground", "upper", "roof"]
		if result.front_walls != null:
			group_names.append("front_walls")
		if result.get("occluding_shell") != null:
			group_names.append("occluding_shell")
		for section in group_names:
			var group: Node3D = result[section]
			var mesh_node := group.get_child(0) as MeshInstance3D
			var stats := _validate_mesh(mesh_node.mesh, cfg.id + "/" + section)
			for key in ["triangles", "vertices", "surfaces"]:
				count[key] += stats[key]
			var mesh_path: String = "res://assets/architecture/%s_%s.res" % [cfg.id, section]
			var error := ResourceSaver.save(mesh_node.mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
			assert(error == OK, "Cannot save mesh: " + mesh_path)
			mesh_node.mesh.take_over_path(mesh_path)
		_owned(node, node)
		var scene := PackedScene.new()
		assert(scene.pack(node) == OK)
		var scene_path: String = "res://scenes/architecture/%s.tscn" % cfg.id
		assert(ResourceSaver.save(scene, scene_path) == OK)
		# Loading saved meshes/scenes catches missing subresources, beyond parser checks.
		var loaded := load(scene_path) as PackedScene
		assert(loaded != null and loaded.can_instantiate())
		var instance := loaded.instantiate()
		assert(instance.has_node("GroundArchitecture/MasonryAndDetails"))
		assert(instance.has_node("UpperArchitecture/UpperAndBalcony"))
		assert(instance.has_node("RoofArchitecture/RoofAndCornice"))
		if cfg.kind == "lodging":
			assert(instance.has_node("FrontWingWalls/FrontWallsAndDoors"))
			assert(instance.has_node("CourtyardShell/CourtyardWalls"))
		instance.free()
		metrics.append(count)
		node.free()
	_validate_plan()
	print("ARCHITECTURE_KIT_OK ", JSON.stringify(metrics))
	quit()

func _preview() -> void:
	root.size = Vector2i(1440, 900)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("293038")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c5c7c5")
	environment.environment.ambient_light_energy = 0.65
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff0d6")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	world.add_child(sun)
	var ground := MeshInstance3D.new()
	var ground_mesh := BoxMesh.new()
	ground_mesh.size = Vector3(55, 0.15, 25)
	ground.mesh = ground_mesh
	ground.position = Vector3(1, -0.13, -3)
	ground.material_override = Kit.Props.plain(Color("777b76"), 0.95)
	world.add_child(ground)
	var sections: Array = []
	for i in 3:
		var cfg: Dictionary = TYPES[i]
		var building := Node3D.new()
		building.position.x = [-12.0, -1.0, 13.0][i]
		world.add_child(building)
		sections.append(Kit.build(building, cfg.kind, cfg.width, cfg.depth, cfg.seed))
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 27.0
	world.add_child(camera)
	camera.position = Vector3(22, 21, 34)
	camera.look_at(Vector3(1.5, 2.0, -3))
	camera.make_current()
	for i in 24:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests")
	var output := "res://tests/architecture-kit-preview.png"
	assert(root.get_texture().get_image().save_png(output) == OK)
	print("ARCHITECTURE_PREVIEW ", ProjectSettings.globalize_path(output))
	for section in sections:
		section.upper.visible = false
		section.roof.visible = false
		if section.front_walls != null:
			section.front_walls.visible = false
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://tests/architecture-kit-cutaway-preview.png") == OK)
