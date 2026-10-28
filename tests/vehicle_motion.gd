extends SceneTree
## Real-renderer evidence: only wheel pixels move, a revolution returns them,
## stopped/parked meshes stay still and night lights belong to moving vehicles.
const Props := preload("res://scripts/world/props3d.gd")
var failed := false
var camera: Camera3D
var bike: MeshInstance3D

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func frame() -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func changed(a: Image, b: Image, region: Rect2i) -> int:
	var n := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length() > 0.035:
				n += 1
	return n

func region(center: Vector3, radius: float) -> Rect2i:
	# Project uses a stretched logical viewport; screenshot pixels use window size.
	var p := camera.unproject_position(center) * Vector2(root.size) / root.get_visible_rect().size
	var pixel_radius := radius * float(root.size.y) / camera.size
	return Rect2i(Vector2i(p - Vector2.ONE * pixel_radius), Vector2i.ONE * ceili(pixel_radius * 2.0)).intersection(Rect2i(Vector2i.ZERO, root.size))

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run vehicle_motion with the real Compatibility renderer")
		quit(1)
		return
	root.size = Vector2i(1000, 650)
	RenderingServer.global_shader_parameter_set("night", 0.0)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("747774")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	scene.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.6
	sun.shadow_enabled = false
	scene.add_child(sun)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	scene.add_child(camera)
	camera.position = Vector3(5.0, 0.8, 0)
	camera.look_at(Vector3(0, 0.8, 0))
	camera.make_current()
	bike = Props.moving_instance(Props.motorbike("tay_ga", true), Color("733e38"))
	scene.add_child(bike)
	var parked := Props.instance(bike.mesh, Color("733e38"))
	var moving_mat := bike.get_surface_override_material(0) as ShaderMaterial
	var parked_mat := parked.get_surface_override_material(0) as ShaderMaterial
	check(moving_mat != parked_mat, "Player material must not change parked copies with identical paint")
	check(moving_mat.get_shader_parameter("rolling") == true, "Moving vehicle opts into wheel animation")
	check(parked_mat.get_shader_parameter("rolling") != true, "Parked vehicles opt out of wheel animation")
	var still := await frame()
	still.save_png("res://tests/vehicle-motion-still-preview.png")
	Props.set_vehicle_distance(bike, 0.27 * 0.47)
	var rolled := await frame()
	var wheel_changes := changed(still, rolled, region(Vector3(0, 0.27, 0.76), 0.29))
	print("MOTION regions front=", region(Vector3(0, 0.27, 0.76), 0.29), " rear=", region(Vector3(0, 0.27, -0.58), 0.29), " body=", region(Vector3(0, 0.95, 0.0), 0.28), " changes=", wheel_changes, "/", changed(still, rolled, region(Vector3(0, 0.27, -0.58), 0.29)), "/", changed(still, rolled, region(Vector3(0, 0.95, 0.0), 0.28)))
	check(wheel_changes > 120, "Rendered front tread/spokes visibly rotate with distance")
	check(changed(still, rolled, region(Vector3(0, 0.27, -0.58), 0.29)) > 120, "Rendered rear wheel rotates")
	check(changed(still, rolled, region(Vector3(0, 0.95, 0.0), 0.28)) == 0, "Frame, seat and handlebars stay fixed")
	check(changed(rolled, await frame(), Rect2i(Vector2i.ZERO, root.size)) == 0, "No movement means no wheel rotation, independent of wall clock")
	rolled.save_png("res://tests/vehicle-motion-roll-preview.png")
	Props.set_vehicle_distance(bike, TAU * Props.wheel_radius(bike.mesh))
	var revolution := await frame()
	check(changed(still, revolution, Rect2i(Vector2i.ZERO, root.size)) < 10, "One distance/radius revolution restores identical geometry/normals")
	RenderingServer.global_shader_parameter_set("night", 1.0)
	var lit := await frame()
	print("LIGHT changes=", changed(revolution, lit, Rect2i(Vector2i.ZERO, root.size)), " region=", region(Vector3(0, 1.057, 0.572), 0.14))
	check(changed(revolution, lit, region(Vector3(0, 1.057, 0.572), 0.14)) > 10, "Moving headlamp lens lights at night")
	lit.save_png("res://tests/vehicle-motion-night-preview.png")
	bike.visible = false
	scene.add_child(parked)
	var parked_night := await frame()
	RenderingServer.global_shader_parameter_set("night", 0.0)
	check(changed(parked_night, await frame(), Rect2i(Vector2i.ZERO, root.size)) == 0, "Parked lenses do not illuminate from traffic's shared cache")
	print("PASS: rendered wheel motion, fixed body, stopped wheels, full revolution, isolated materials and moving-only night lenses; changed wheel pixels=", wheel_changes) if not failed else print("FAIL: vehicle motion")
	quit(1 if failed else 0)
