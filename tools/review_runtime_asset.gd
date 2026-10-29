extends SceneTree
## Isolated GLB/scene review. -- --asset=res://... --label=cart --height=1.8
## Does not instantiate the world or read a player save (use --demo).
var output := "res://build/asset-review"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := "res://art/higgsfield/source-3d/street_food_cart-web.glb"
	var label := "cart-source"
	var height := 0.0
	var hero := ""
	var motion := 0.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--asset="):
			source = arg.trim_prefix("--asset=")
		elif arg.begins_with("--label="):
			label = arg.trim_prefix("--label=").validate_filename()
		elif arg.begins_with("--height="):
			height = arg.trim_prefix("--height=").to_float()
		elif arg.begins_with("--hero="):
			hero = arg.trim_prefix("--hero=")
		elif arg == "--walk":
			motion = 1.0
	root.size = Vector2i(1100, 900)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var stage := Node3D.new()
	root.add_child(stage)
	var model: Node3D
	if not hero.is_empty():
		model = load("res://scripts/world/named_character.gd").make(hero)
		source = "hero:" + hero
	elif source.ends_with(".glb"):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		assert(doc.append_from_file(source, state) == OK, "Cannot read " + source)
		model = doc.generate_scene(state)
	else:
		model = load(source).instantiate()
	stage.add_child(model)
	await process_frame
	if model.has_method("animate"):
		for step in 30:
			model.animate(1.0 / 60.0, motion)
	var bounds := _bounds(model)
	if height > 0:
		model.scale *= height / bounds.size.y
		bounds = _bounds(model)
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	bounds = _bounds(model)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("898f8c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_energy = 0.85
	light.shadow_enabled = true
	stage.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(200, 200)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("898f8c")
	mat.roughness = 1.0
	floor_mesh.material_override = mat
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * 1.5
	camera.far = 200
	var target := Vector3(0, bounds.size.y * 0.5, 0)
	var views := {"front": Vector3(0, 0, 5), "side": Vector3(5, 0, 0), "back": Vector3(0, 0, -5), "street": Vector3(4, 4, 5)}
	for view in views:
		camera.position = target + (views[view] as Vector3) * bounds.size.y
		camera.look_at(target)
		for frame in 8:
			if model.has_method("animate"):
				model.animate(1.0 / 60.0, motion)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output + "/" + label + "-" + view + ".png")
	var meshes := []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_bounds: AABB = _skin_bounds(node) if node.skin != null else node.global_transform * node.get_aabb()
		meshes.append({"name": str(node.name), "bounds": str(mesh_bounds), "surfaces": node.mesh.get_surface_count()})
	var report := {"source": source, "bounds": str(bounds), "meshes": meshes}
	FileAccess.open(output + "/" + label + ".json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("REVIEW ASSET ", report)
	quit()

func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var next: AABB = _skin_bounds(node) if node.skin != null else node.global_transform * node.get_aabb()
		box = next if first else box.merge(next)
		first = false
	assert(not first, "No mesh in asset")
	return box

## Imported skinned bounds must include inverse bind scale, not just node.scale.
static func _skin_bounds(instance: MeshInstance3D) -> AABB:
	var skeleton := instance.get_node(instance.skeleton) as Skeleton3D
	skeleton.force_update_all_bone_transforms()
	var matrices: Array[Transform3D] = []
	for i in instance.skin.get_bind_count():
		var bone: int = instance.skin.get_bind_bone(i)
		if not instance.skin.get_bind_name(i).is_empty():
			bone = skeleton.find_bone(instance.skin.get_bind_name(i))
		matrices.append(skeleton.get_bone_global_pose(bone) * instance.skin.get_bind_pose(i))
	var box := AABB()
	var first := true
	for surface in instance.mesh.get_surface_count():
		var arrays: Array = instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := weights.size() / vertices.size()
		for vertex in vertices.size():
			var point := Vector3.ZERO
			for weight in stride:
				point += (matrices[bones[vertex * stride + weight]] * vertices[vertex]) * weights[vertex * stride + weight]
			point = skeleton.global_transform * point
			box = AABB(point, Vector3.ZERO) if first else box.expand(point)
			first = false
	return box
