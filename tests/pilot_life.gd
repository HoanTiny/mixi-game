extends SceneTree
## godot --headless --path . -s res://tests/pilot_life.gd
## Exercises the authored actor/furniture contract without constructing the city.
const PilotLife := preload("res://scripts/world/pilot_life.gd")

class Clock extends RefCounted:
	var hour := 13.0
	func clock() -> float:
		return hour

class WorldFixture extends Node3D:
	var city := {"locs": {
		"com_hanh": {"center": Vector2(0, 0), "normal": Vector2(0, 1), "w": 8.0, "d": 8.0},
		"tiem_sau": {"center": Vector2(15, 0), "normal": Vector2(1, 0), "w": 9.0, "d": 8.0},
		"xom_bo_me": {"center": Vector2(30, 0), "normal": Vector2(0, -1), "w": 13.0, "d": 8.0}
	}}
	var game := Clock.new()
	var player := Node3D.new()
	func _ready() -> void:
		add_child(player)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := WorldFixture.new()
	root.add_child(world)
	var life := PilotLife.new()
	world.add_child(life)
	life.set_process(false)
	life.setup(world)
	await process_frame
	var snap := life.activity_snapshot()
	assert(snap.size() == 6, "All six Rocketbox ambient actors should load")
	assert(life.get_child_count() == 6, "No duplicated props or named quest NPCs")
	var reservations := PilotLife.reservation_points(world.city)
	assert(reservations.size() == 30, "Every actor has a reserved footprint")
	for i in snap.size():
		var row: Dictionary = snap[i]
		var actor = life.get_child(i)
		assert(actor.get_meta("ambient_only", false), "An actor must be noninteractive")
		assert(actor.find_children("*", "Skeleton3D", true, false).size() == 1, "Real rig required")
		assert(actor.find_children("*", "Label3D", true, false).is_empty(), "Ambient actors need no labels")
		assert(row.visible, "Midday should show all three activity groups")
		assert(reservations[i * 5].is_equal_approx(Vector2(row.position.x, row.position.z)))
		if row.location == "com_hanh":
			assert(row.pose == "sit", "Diners must use the real seated clip")
			assert(is_equal_approx(row.local.z, -1.12), "Diners must stay aligned with stools")
			actor._sk.force_update_all_bone_transforms()
			var hip: int = actor._sk.find_bone("Bip01 Pelvis")
			var hip_y: float = (actor._sk.global_transform * actor._sk.get_bone_global_pose(hip).origin).y
			assert(hip_y > 0.55 and hip_y < 0.82, "Seat hip should be above the .59m stool top")
		if row.location == "xom_bo_me":
			assert(absf(row.local.x) >= 2.0, "Home central passage must remain clear")
			assert(row.local.z < -4.0 and row.local.z > -7.7, "Residents must occupy the rear courtyard")
	# Different facing directions must transform the local desk/home anchors correctly.
	assert((snap[2].position as Vector3).is_equal_approx(Vector3(12.35, 0.15, -2.16)))
	assert((snap[4].position as Vector3).is_equal_approx(Vector3(27.9, 0.15, 5.25)))
	for test in [[6.0, 0], [8.0, 4], [13.0, 6], [15.0, 4], [19.5, 4], [22.0, 0]]:
		world.game.hour = test[0]
		life._refresh()
		var visible_count := 0
		for row in life.activity_snapshot():
			visible_count += 1 if row.visible else 0
		assert(visible_count == test[1], "Wrong number of residents at hour " + str(test[0]))
	world.game.hour = 13.0
	life._elapsed = 0.0
	life._refresh()
	snap = life.activity_snapshot()
	assert(snap[2].pose == "talk" and snap[3].pose == "idle", "First conversation turn")
	life._elapsed = 8.0
	life._refresh()
	snap = life.activity_snapshot()
	assert(snap[2].pose == "idle" and snap[3].pose == "talk", "Customer conversation turn")
	world.player.position = Vector3(1000, 0, 1000)
	life._refresh()
	for row in life.activity_snapshot():
		assert(not row.animated, "Distant rigs must stop advancing")
	life.setup(world)
	assert(life.get_child_count() == 6, "Repeated setup must not duplicate residents")
	world.queue_free()
	await process_frame
	await process_frame
	print("PASS: pilot life 6 real rigs, stool alignment, courtyard clearance, schedule, talk turns, reservations and distance budget")
	quit()
