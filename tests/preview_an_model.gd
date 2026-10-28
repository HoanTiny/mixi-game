extends SceneTree
## Isolated generated-model preview; does not load or change game saves.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1000, 1000)
	var stage := Node3D.new()
	root.add_child(stage)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file("res://assets/characters/an/an-tripo-v1.glb", state)
	if err != OK:
		push_error("GLB load failed: %s" % err)
		quit(1)
		return
	var model := doc.generate_scene(state)
	stage.add_child(model)
	var bounds := AABB()
	var first := true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first or bounds.size.y <= 0.0:
		push_error("No visible geometry in GLB")
		quit(1)
		return
	print("GLB bounds: ", bounds)
	var center := bounds.get_center()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.19, 0.20)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -30, 0)
	light.light_energy = 1.6
	stage.add_child(light)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(bounds.size.y, bounds.size.x) * 1.2
	camera.far = 1000.0
	for view in ["front", "back"]:
		var direction := 1.0 if view == "front" else -1.0
		camera.position = center + Vector3(bounds.size.y * 2.0 * direction, bounds.size.y * 0.03, bounds.size.y * 0.12 * direction)
		camera.look_at(center)
		for i in range(10):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://assets/characters/an/preview-%s.png" % view)
	print("An GLB preview PASS")
	quit()
