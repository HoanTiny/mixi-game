extends SceneTree
const Avatar := preload("res://scripts/world/an_character.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(900,900)
	var stage := Node3D.new()
	root.add_child(stage)
	var avatar := Avatar.new()
	stage.add_child(avatar)
	avatar.setup(Color.WHITE,Color.WHITE)
	assert(avatar.skeleton != null, "Missing skeleton")
	assert(not avatar.walk_clip.is_empty(), "Missing walk")
	assert(not avatar.idle_clip.is_empty(), "Missing idle")
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0.25,1.0,4)
	camera.look_at(Vector3(0,0.9,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.15
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("363939")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-25,0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	for pose in ["idle","walk","colors"]:
		if pose == "walk":
			avatar.animate_motion(1.5,0.016)
		if pose == "colors":
			avatar.animate_motion(0,0.016)
			avatar.set_colors({"hair":"75513a","shirt":"567e64","pants":"3e414c"})
		for i in range(40):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/an-%s-preview.png" % pose)
	print("An skeleton: ",avatar.skeleton.get_bone_count()," bones; idle/walk/color PASS")
	quit()
