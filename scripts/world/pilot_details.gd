extends RefCounted
## Small working clusters for the authored pilot street. Photographed objects keep
## their original PBR materials; the only procedural pieces are a hose and tools.
## Returns an unparented root: world.add_child(PilotDetails.build(world)).
const WorkProps := preload("res://scripts/work/work_props.gd")
const Models := preload("res://scripts/world/models.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
const CityMap := preload("res://scripts/world/city_map.gd")

const FLOOR_Y := 0.15
const PAVEMENT_Y := 0.052


static func build(world) -> Node3D:
	var root := Node3D.new()
	root.name = "PilotDetails"
	if not world.real or not world.city.pilot_active:
		return root
	for id in ["com_hanh", "tiem_sau", "xom_bo_me"]:
		if not world.city.locs.has(id):
			continue
		var plot: Dictionary = world.city.locs[id]
		var frame := Node3D.new()
		frame.name = "Details_" + id
		frame.position = Vector3(plot.center.x, 0.0, plot.center.y)
		frame.rotation.y = CityMap.rot_y(plot.normal)
		root.add_child(frame)
		match id:
			"com_hanh":
				_serving_cart(world, frame, float(plot.w))
			"tiem_sau":
				_service_corner(frame, float(plot.w))
			"xom_bo_me":
				_returned_goods(frame, float(plot.w))
	return root


## Measured bottom and center, rather than trusting inconsistent glTF pivots.
## All placements are deterministic; source meshes and textures remain shared.
static func _scan(parent: Node3D, asset: String, pos: Vector3, height: float, yaw := 0.0) -> Node3D:
	var model := WorkProps.model(asset)
	var source := Models._bounds(model, model.transform)
	var factor := height / maxf(source.size.y, 0.001)
	model.scale *= factor
	var bounds := Models._bounds(model, model.transform)
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var holder := Node3D.new()
	holder.name = asset
	holder.position = pos
	holder.rotation.y = yaw
	holder.set_meta("source_asset", asset)
	holder.set_meta("source_scale", factor)
	holder.set_meta("source_bottom", source.position.y)
	holder.add_child(model)
	parent.add_child(holder)
	return holder


static func _serving_cart(world, parent: Node3D, width: float) -> void:
	# Fits beside the right dining table, wholly behind the threshold. The left
	# table and its two animated diners remain untouched.
	var position := Vector3(width * 0.4, FLOOR_Y, -0.46)
	var cart := _scan(parent, "industrial_storage_cart", position, 1.06)
	cart.name = "ServingCart"
	# Measured horizontal shelves of this source mesh are y=1.28 and y=.76;
	# the 1.377m bounding-box top belongs to its handle, not a support surface.
	var scale_factor := float(cart.get_meta("source_scale"))
	var source_bottom := float(cart.get_meta("source_bottom"))
	var top := FLOOR_Y + (1.28 - source_bottom) * scale_factor
	var middle := FLOOR_Y + (0.76 - source_bottom) * scale_factor
	_scan(parent, "pot_enamel_01", Vector3(position.x - 0.27, top, position.z - 0.08), 0.23, 0.08)
	_scan(parent, "pot_enamel_01", Vector3(position.x + 0.27, top, position.z - 0.08), 0.18, -0.28)
	_scan(parent, "wooden_bowl_02", Vector3(position.x + 0.06, top, position.z + 0.23), 0.085)
	_scan(parent, "plastic_crate_03", Vector3(position.x + 0.12, middle, position.z), 0.23)
	var steam := _steam(world)
	steam.position = Vector3(position.x - 0.27, top + 0.23, position.z - 0.08)
	parent.add_child(steam)


static func _service_corner(parent: Node3D, width: float) -> void:
	# Used parts stay beside the generator; the desk's helper/customer positions
	# at x=.24w,z=-2.65/-.65 and the central approach remain clear.
	var barrel_pos := Vector3(-width * 0.4, FLOOR_Y, -0.2)
	_scan(parent, "barrel_03", barrel_pos, 0.78, 0.15)
	_scan(parent, "cardboard_box_01", Vector3(barrel_pos.x + 0.72, FLOOR_Y, -0.12), 0.26, -0.13)
	var tools := Props3D.instance(_hand_tools())
	tools.name = "ToolsOnDrum"
	tools.position = barrel_pos + Vector3(0, 0.785, 0)
	parent.add_child(tools)
	var hose := Props3D.instance(_hose())
	hose.name = "CoiledServiceHose"
	hose.position = Vector3(barrel_pos.x + 0.1, FLOOR_Y, -0.87)
	parent.add_child(hose)
	# A shallow drip pan belongs under the existing engine, not in the walkway.
	var pan := Props3D.instance(_drip_pan())
	pan.name = "EngineDripPan"
	pan.position = Vector3(-width * 0.25, FLOOR_Y + 0.008, -1.15)
	pan.rotation.y = 0.65
	parent.add_child(pan)
	var oil := WorkProps.cyl(pan, 0.16, 0.002, WorkProps.plain(Color("171b18"), 0.16, 0.05), Vector3(0, 0.022, 0))
	oil.name = "OilInPan"
	oil.scale.x = 1.3
	oil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func _returned_goods(parent: Node3D, width: float) -> void:
	# A drum and reusable delivery packaging against the outer lodging wing.
	# Their front edges end before z=.7; the entire x[-1.5,1.5] passage and the
	# courtyard activity area remain clear. Pavement is lower than indoor floors.
	var x := -width * 0.4
	_scan(parent, "barrel_03", Vector3(x, PAVEMENT_Y, 0.35), 0.7, -0.32)
	var crate_x := x + 0.72
	_scan(parent, "plastic_crate_03", Vector3(crate_x, PAVEMENT_Y, 0.35), 0.27)
	_scan(parent, "cardboard_box_01", Vector3(crate_x + 0.015, PAVEMENT_Y + 0.27, 0.35), 0.19, 0.08)


## One mesh for a loosely coiled rubber hose, including a brass coupling.
static func _hose() -> ArrayMesh:
	var g := Props3D.Character.Mesher.new(false)
	var rubber := Props3D._c("343c36")
	var last := Vector3.ZERO
	for i in 65:
		var t := float(i) / 64.0
		var angle := t * TAU * 2.2
		var radius := 0.19 + t * 0.1
		var point := Vector3(cos(angle) * radius, 0.022 + 0.025 * t, sin(angle) * radius)
		if i > 0:
			Props3D._cyl(g, last, point, 0.018, 0.018, rubber, 6, false)
		last = point
	Props3D._cyl(g, last, last + Vector3(0.12, 0, 0.08), 0.023, 0.023, Props3D._c("a38f5c"), 8)
	return g.commit()


## Flat spanner and screwdriver, batched together on an actual support surface.
static func _hand_tools() -> ArrayMesh:
	var g := Props3D.Character.Mesher.new(false)
	var steel := Props3D._c("a4a69a")
	Props3D._box(g, Vector3(0, 0.014, -0.07), Vector3(0.21, 0.018, 0.027), steel, 0.0)
	for side in [-1.0, 1.0]:
		for i in 9:
			var a := -PI * 0.65 + float(i) * PI * 1.3 / 9.0
			var b := -PI * 0.65 + float(i + 1) * PI * 1.3 / 9.0
			var center := Vector3(side * 0.12, 0.014, -0.07)
			Props3D._cyl(g, center + Vector3(-side * cos(a) * 0.036, 0, sin(a) * 0.036),
				center + Vector3(-side * cos(b) * 0.036, 0, sin(b) * 0.036), 0.012, 0.012, steel, 6)
	Props3D._cyl(g, Vector3(-0.12, 0.022, 0.075), Vector3(0.02, 0.022, 0.075), 0.022, 0.019, Props3D._c("624431"), 8)
	Props3D._cyl(g, Vector3(0.02, 0.022, 0.075), Vector3(0.16, 0.022, 0.075), 0.006, 0.006, steel, 6)
	return g.commit()


static func _drip_pan() -> ArrayMesh:
	var g := Props3D.Character.Mesher.new(false)
	var steel := Props3D._c("484f49")
	Props3D._box(g, Vector3(0, 0.01, 0), Vector3(0.52, 0.018, 0.37), steel)
	for x in [-0.255, 0.255]:
		Props3D._box(g, Vector3(x, 0.045, 0), Vector3(0.018, 0.07, 0.37), steel)
	for z in [-0.175, 0.175]:
		Props3D._box(g, Vector3(0, 0.045, z), Vector3(0.52, 0.07, 0.018), steel)
	return g.commit()


static func _steam(world) -> CPUParticles3D:
	var steam := KitchenSteam.new()
	steam.name = "GentleKitchenSteam"
	steam.world = world
	steam.amount = 7
	steam.lifetime = 1.8
	steam.preprocess = 0.8
	steam.use_fixed_seed = true
	steam.seed = 471
	steam.local_coords = true
	steam.direction = Vector3.UP
	steam.spread = 16.0
	steam.gravity = Vector3(0.025, 0.04, 0)
	steam.initial_velocity_min = 0.12
	steam.initial_velocity_max = 0.22
	steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	steam.emission_sphere_radius = 0.035
	steam.visibility_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 1.7, 1.2))
	steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var fade := Gradient.new()
	fade.set_color(0, Color(0.87, 0.88, 0.85, 0.0))
	fade.add_point(0.18, Color(0.87, 0.88, 0.85, 0.3))
	fade.set_color(2, Color(0.87, 0.88, 0.85, 0.0))
	steam.color_ramp = fade
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.35))
	grow.add_point(Vector2(1, 1.0))
	steam.scale_amount_curve = grow
	var alpha := Gradient.new()
	alpha.set_color(0, Color.WHITE)
	alpha.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.width = 32
	texture.height = 32
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1, 0.5)
	texture.gradient = alpha
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = texture
	var puff := QuadMesh.new()
	puff.size = Vector2(0.25, 0.32)
	puff.material = material
	steam.mesh = puff
	return steam


class KitchenSteam extends CPUParticles3D:
	var world
	var _until_check := 0.0

	func _process(delta: float) -> void:
		_until_check -= delta
		if _until_check > 0.0:
			return
		_until_check = 0.5
		if world == null or world.player == null:
			emitting = false
			return
		var hour := float(world.game.clock())
		emitting = hour >= 8.0 and hour < 21.0 and global_position.distance_squared_to(world.player.global_position) < 324.0
