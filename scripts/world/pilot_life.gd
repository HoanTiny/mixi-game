extends Node3D
## Six unnamed residents for the authored street slice. These use the shipped
## Rocketbox sit/idle/talk clips; there are no invented eating/repair/laundry clips.
## Keep their anchors in sync with StreetPrototype furniture, behind the frontage.
## World creates this only when city.pilot_active, before/after crowd respectively:
##   Crowd.build(..., blocked + PilotLife.reservation_points(city))
##   var life = PilotLife.new(); add_child(life); life.setup(self)
const Human := preload("res://scripts/world/human.gd")
const Character := preload("res://scripts/world/character.gd")
const CityMap := preload("res://scripts/world/city_map.gd")

const ANIMATION_RANGE := 12.0
const UPDATE_INTERVAL := 0.25
const FLOOR_Y := 0.15
const LOCATIONS := ["com_hanh", "tiem_sau", "xom_bo_me"]

var world
var _actors: Array = []
var _elapsed := 0.0
var _until_update := 0.0


## Descriptions have stable IDs for diagnostics, never labels or quest targets.
## Local +z faces the road. Home x >= 2.1 keeps the entire 3 m corridor open.
static func _anchors(city) -> Array:
	var result: Array = []
	for location in LOCATIONS:
		if not city.locs.has(location):
			continue
		var p: Dictionary = city.locs[location]
		var w := float(p.w)
		match location:
			"com_hanh":
				for i in 2:
					var side := -1.0 if i == 0 else 1.0
					result.append({"id": "diner_%d" % i, "location": location,
						"local": Vector3(-w * 0.3 + side * 0.78, FLOOR_Y, -1.12),
						"yaw": -side * PI / 2.0, "look": 0 if i == 0 else 5,
						"activity": "seated_meal", "seated": true, "turn": i})
			"tiem_sau":
				# Desk at x=.24w,z=-1.65: a helper behind it and a waiting customer
				# in front. The spool belongs beside the bench, outside these anchors.
				result.append({"id": "bench_helper", "location": location,
					"local": Vector3(w * 0.24, FLOOR_Y, -2.65), "yaw": 0.0,
					"look": 1, "activity": "workbench_conversation", "seated": false, "turn": 0})
				result.append({"id": "repair_customer", "location": location,
					"local": Vector3(w * 0.24, FLOOR_Y, -0.65), "yaw": PI,
					"look": 3, "activity": "waiting_for_repair", "seated": false, "turn": 1})
			"xom_bo_me":
				# The lodging wings are closed until local z=-4. Both people stand
				# in the open rear courtyard, not inside a room or the entry passage.
				var a := Vector3(2.1, FLOOR_Y, -5.25)
				var b := Vector3(2.8, FLOOR_Y, -6.1)
				for i in 2:
					var pos := a if i == 0 else b
					var face := b - a if i == 0 else a - b
					result.append({"id": "courtyard_resident_%d" % i, "location": location,
						"local": pos, "yaw": atan2(face.x, face.z), "look": 6 if i == 0 else 8,
						"activity": "courtyard_conversation", "seated": false, "turn": i})
	return result


static func _position(city, entry: Dictionary) -> Vector3:
	var p: Dictionary = city.locs[entry.location]
	var n: Vector2 = p.normal
	var along := Vector2(n.y, -n.x)
	var local: Vector3 = entry.local
	var point: Vector2 = p.center + along * local.x + n * local.z
	return Vector3(point.x, local.y, point.y)


## Pass to Crowd.build's blocked array before it places any random groups.
## Reserve a small footprint as well as the root so a walking extra cannot clip
## through the occupied stool or stand shoulder-to-shoulder with a resident.
static func reservation_points(city) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for entry in _anchors(city):
		var p := _position(city, entry)
		var center := Vector2(p.x, p.z)
		points.append(center)
		for offset in [Vector2(0.35, 0), Vector2(-0.35, 0), Vector2(0, 0.35), Vector2(0, -0.35)]:
			points.append(center + offset)
	return points


static func active_at(location: String, hour: float) -> bool:
	match location:
		"com_hanh":
			return (hour >= 10.5 and hour < 14.5) or (hour >= 17.5 and hour < 21.0)
		"tiem_sau":
			return hour >= 8.0 and hour < 18.0
		"xom_bo_me":
			return hour >= 7.0 and hour < 21.5
	return false


func setup(w) -> void:
	world = w
	for entry in _actors:
		var old: Node3D = entry.actor
		remove_child(old)
		old.queue_free()
	_actors.clear()
	_elapsed = 0.0
	_until_update = 0.0
	for anchor in _anchors(world.city):
		# Duplicate the style before toggling talker: CROWD is shared with other rigs.
		var look: Dictionary = Character.CROWD[int(anchor.look)].duplicate(true)
		if not Human.exists(str(look.rb)):
			push_warning("Pilot ambient person missing: " + str(look.rb))
			continue
		look["talker"] = false
		var actor := Human.make(look)
		actor.name = "Ambient_" + str(anchor.id)
		actor.set_meta("ambient_only", true)
		actor.set_meta("pilot_activity", anchor.activity)
		add_child(actor)
		actor.global_position = _position(world.city, anchor)
		actor.global_rotation.y = CityMap.rot_y(world.city.locs[anchor.location].normal) + float(anchor.yaw)
		if bool(anchor.seated):
			# Stool surface .44 m above the floor, pelvis just above the cushion.
			actor.sit(true, 0.52)
		else:
			actor.animate(0.0, 0.0)
		# Finish the initial transition before freezing an offscreen rig: advancing
		# a zero-time blend would otherwise leave the diner standing on the stool.
		actor._ap.play("rb/" + actor._state, 0.0)
		actor._ap.seek(float(anchor.look) * 0.31, true)
		var entry: Dictionary = anchor.duplicate()
		entry["actor"] = actor
		entry["animated"] = false
		_actors.append(entry)
	_refresh()


func _process(delta: float) -> void:
	if world == null:
		return
	_elapsed += delta
	_until_update -= delta
	if _until_update > 0.0:
		return
	_until_update = UPDATE_INTERVAL
	_refresh()


func _refresh() -> void:
	var hour := float(world.game.clock())
	var focus: Vector3 = world.player.global_position
	for entry in _actors:
		var actor = entry.actor
		var scheduled := active_at(str(entry.location), hour)
		actor.visible = scheduled
		var local_focus := Vector2(focus.x, focus.z)
		var local_actor := Vector2(actor.global_position.x, actor.global_position.z)
		var near := local_focus.distance_squared_to(local_actor) <= ANIMATION_RANGE * ANIMATION_RANGE
		# Alternate the actual talk clip with a listening idle. A small silent gap
		# prevents two gesticulating people from looking like a synchronized loop.
		var phase := fmod(_elapsed + (3.5 if entry.location == "xom_bo_me" else 0.0), 18.0)
		var talking := (phase < 5.0 if int(entry.turn) == 0 else phase >= 7.0 and phase < 12.0)
		var old_pose: String = actor._state
		actor.look["talker"] = talking and not bool(entry.seated)
		actor.animate(0.0, 0.0)
		if old_pose != actor._state:
			actor._ap.advance(0.0)
		var in_view: bool = actor._seen == null or actor._seen.is_on_screen()
		entry.animated = scheduled and near and in_view
		actor._ap.active = bool(entry.animated)


## Read-only QA data; no labels, click targets, quest state or collision bodies.
func activity_snapshot() -> Array:
	var result: Array = []
	for entry in _actors:
		var actor = entry.actor
		result.append({"id": entry.id, "location": entry.location, "activity": entry.activity,
			"position": actor.global_position, "local": entry.local,
			"pose": actor._state, "visible": actor.visible, "animated": entry.animated})
	return result
