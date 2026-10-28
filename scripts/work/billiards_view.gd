extends Node3D
## Orthographic 3D presentation. One metre = 100 simulation pixels. Input and
## aiming use the inverse camera projection at ball height, independent of tilt.
const WP := preload("res://scripts/work/work_props.gd")
var camera: Camera3D
var table_root: Node3D
var balls: Array[MeshInstance3D] = []
var cue: MeshInstance3D
var canvas_size := Vector2.ZERO
var ball_radius := 0.11

func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("171c1c")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b9c9cd")
	env.environment.ambient_light_energy = 0.45
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-68, -35, 0)
	light.light_color = Color("fff0d7")
	light.light_energy = 0.9
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 30
	add_child(light)
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.position = Vector3(3, 15, 10)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.current = true

func point(p: Vector2, y := 0.0) -> Vector3:
	return Vector3((p.x-canvas_size.x*0.5)/100.0, y, (p.y-canvas_size.y*0.5)/100.0)

func display(p: Vector2) -> Vector2:
	return camera.unproject_position(point(p,ball_radius))

func input_point(p: Vector2) -> Vector2:
	var hit = Plane(Vector3.UP,ball_radius).intersects_ray(camera.project_ray_origin(p),camera.project_ray_normal(p))
	if hit == null: return p
	return Vector2(hit.x,hit.z)*100.0+canvas_size*0.5

func disk(parent: Node3D, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius; mesh.bottom_radius = radius
	mesh.height = height; mesh.radial_segments = 32
	n.mesh = mesh; n.material_override = mat; n.position = at
	parent.add_child(n)
	return n

func layout(size: Vector2, table: Rect2, entries: Array, radius: float, pocket_radius: float) -> void:
	canvas_size = size
	ball_radius = radius/100.0
	camera.size = size.y/100.0*1.30
	if is_instance_valid(table_root):
		remove_child(table_root); table_root.queue_free()
	table_root = Node3D.new(); add_child(table_root)
	balls.clear()
	var center := point(table.get_center())
	var w := table.size.x/100.0
	var d := table.size.y/100.0
	WP.box(table_root, Vector3(size.x/100.0+4, 0.1, size.y/100.0+4), WP.tex("brown_planks_05", 0.6, Color("77716b")), Vector3(0,-0.6,0))
	WP.box(table_root, Vector3(w+0.66,0.35,d+0.66), WP.tex("brown_planks_05", 1.1, Color("6e4d35")), center+Vector3(0,-0.41,0))
	var felt := ShaderMaterial.new()
	felt.shader = preload("res://scripts/work/table_felt.gdshader")
	WP.box(table_root, Vector3(w,0.025,d), felt, center+Vector3(0,-0.025,0))
	var cushion := WP.plain(Color("244b43"),0.95)
	var trim := WP.plain(Color("b39a69"),0.48,0.4)
	# Split cushions leave the six pocket openings visible.
	for side in [-1.0,1.0]:
		for half in [-1.0,1.0]:
			WP.box(table_root, Vector3(w/2-0.38,0.10,0.13), cushion, center+Vector3(half*w/4,0,side*(d/2+0.065)))
		WP.box(table_root, Vector3(0.13,0.10,d-0.4), cushion, center+Vector3(side*(w/2+0.065),0,0))
		WP.box(table_root, Vector3(w+0.57,0.025,0.025), trim, center+Vector3(0,0.02,side*(d/2+0.29)))
		for mark in [0.125,0.25,0.375,0.625,0.75,0.875]:
			disk(table_root, point(Vector2(table.position.x+w*100*mark,table.get_center().y+side*(d*50+21)),0.045),0.025,0.012,WP.plain(Color("d7cba8")))
	for y in [0.0,1.0]:
		for x in [0.0,0.5,1.0]:
			var p := point(table.position+Vector2(x,y)*table.size)
			disk(table_root,p+Vector3(0,0.055,0),pocket_radius/100.0+0.055,0.065,WP.plain(Color("4c382c")))
			disk(table_root,p+Vector3(0,0.093,0),pocket_radius/100.0,0.012,WP.plain(Color("080e0d")))
	for i in entries.size():
		var n := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = ball_radius; sphere.height = 2*ball_radius
		sphere.radial_segments = 24; sphere.rings = 12
		n.mesh = sphere
		n.material_override = WP.plain(entries[i].c,0.24)
		table_root.add_child(n); balls.append(n)
		if i>0:
			var number := Label3D.new()
			number.text = str(i); number.font_size = 32; number.pixel_size = 0.002
			number.modulate = Color("f7f1d9"); number.outline_size = 5
			number.position.y = ball_radius+0.002; number.rotation.x = -PI/2
			n.add_child(number)
	cue = WP.box(table_root,Vector3(0.045,0.045,2.6),WP.tex("brown_planks_05",1.0,Color("d7ba83")),Vector3.ZERO)
	var tip := WP.box(cue,Vector3(0.048,0.045,0.055),WP.plain(Color("a2c5bf")),Vector3(0,-0.02,1.28))
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sync(table,entries,Vector2.ZERO,false,0)

func sync(table: Rect2, entries: Array, pull: Vector2, aiming: bool, dt: float) -> void:
	for i in mini(entries.size(),balls.size()):
		var b: Dictionary = entries[i]
		var target := point(table.position+(b.p as Vector2)*table.size,ball_radius)
		var movement := target-balls[i].position
		if dt>0 and movement.length()>0.0001 and movement.length()<1.0:
			balls[i].rotate(Vector3(movement.z,0,-movement.x).normalized(),movement.length()/ball_radius)
		balls[i].position = target; balls[i].visible = not b.in
	cue.visible = aiming and pull.length()>4
	if cue.visible:
		var direction := Vector3(pull.x,0,pull.y).normalized()
		var power := clampf(pull.length()/220.0,0.05,1.0)
		cue.position = point(table.position+(entries[0].p as Vector2)*table.size,ball_radius)-direction*(ball_radius+0.06+power*0.6+1.3)
		cue.rotation.y = atan2(direction.x,direction.z)
