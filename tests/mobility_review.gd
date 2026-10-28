extends SceneTree
## Actual runtime assets, neutral close views for material/rig/vehicle review.
## godot --path . -s res://tests/mobility_review.gd -- --review=mobility
const Avatar := preload("res://scripts/world/an_character.gd")
const Character := preload("res://scripts/world/character.gd")
const Props := preload("res://scripts/world/props3d.gd")
var stage: Node3D
var subjects: Node3D
var camera: Camera3D
var label := "mobility"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review="):
			label = arg.trim_prefix("--review=").validate_filename()
	root.size = Vector2i(1366, 800)
	stage = Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("434a4a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c2c4ce")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 0.9
	environment.environment = env
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("686762")
	material.roughness = 0.94
	floor_mesh.material_override = material
	stage.add_child(floor_mesh)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	subjects = Node3D.new()
	stage.add_child(subjects)
	var an := Avatar.new()
	subjects.add_child(an)
	an.setup(Color.WHITE, Color.WHITE)
	an.position.x = -1.25
	var hanh := Character.make(Character.LOOKS.HANH.duplicate(true))
	subjects.add_child(hanh)
	var sau := Character.make(Character.LOOKS.SAU.duplicate(true))
	subjects.add_child(sau)
	sau.position.x = 1.25
	camera.size = 2.85
	camera.position = Vector3(0.25, 2.1, 6)
	camera.look_at(Vector3(0, 0.9, 0))
	await _capture("people")
	an.animate_motion(1.35, 0.016)
	await _capture("walk")
	hanh.hide()
	sau.hide()
	an.position = Vector3(0, 0, Props.RIDER_Z)
	an.sit(true, Props.SEAT_H)
	if an.has_method("hold"):
		an.hold("ride")
	if an.has_method("wear"):
		an.wear("helmet", true)
	subjects.add_child(Props.instance(Props.motorbike("tay_ga", true), Color("713f37")))
	camera.size = 3.15
	camera.position = Vector3(4, 2.5, 5.5)
	camera.look_at(Vector3(0, 0.85, 0))
	await _capture("an-riding")
	_clear()
	for spec in [["tay_ga", -1.15, "596867"], ["xe_so", 1.15, "713f37"]]:
		var bike := Props.instance(Props.motorbike(spec[0], true), Color(spec[2]))
		bike.position.x = spec[1]
		bike.rotation.y = 0.25
		subjects.add_child(bike)
	camera.size = 3.6
	camera.position = Vector3(4.5, 3.1, 5.8)
	camera.look_at(Vector3(0, 0.65, 0))
	await _capture("bikes")
	_clear()
	var car := Props.instance(Props.car(), Color("7c817d"))
	subjects.add_child(car)
	camera.size = 4.2
	camera.position = Vector3(5.6, 3.5, 6.2)
	camera.look_at(Vector3(0, 0.7, 0))
	await _capture("car")
	_clear()
	var rider := Props.rider_real("tay_ga", "m1", "f1", Color("343937"), true)
	if rider != null:
		var bike := MeshInstance3D.new()
		bike.mesh = rider
		bike.set_surface_override_material(0, Props.material(Color("596867")))
		subjects.add_child(bike)
	camera.size = 3.05
	camera.position = Vector3(4, 2.5, 5.5)
	camera.look_at(Vector3(0, 0.85, 0))
	await _capture("riders")
	print("PASS: mobility close views rendered with ", RenderingServer.get_current_rendering_method())
	quit()

func _clear() -> void:
	for child in subjects.get_children():
		subjects.remove_child(child)
		child.queue_free()

func _capture(view: String) -> void:
	for frame in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/%s-%s-preview.png" % [label, view])
