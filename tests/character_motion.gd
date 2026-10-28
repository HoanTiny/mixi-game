extends SceneTree
## Motion contracts: grounded idle, stable cadence, and fixed ride contacts while
## the upper body/gaze respond. Run headless; close render review is separate.
const An := preload("res://scripts/world/an_character.gd")
const Human := preload("res://scripts/world/human.gd")
const Character := preload("res://scripts/world/character.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var an := An.new()
	root.add_child(an)
	an.setup(Color.WHITE, Color.WHITE)
	await process_frame
	an.animation.play(an.idle_clip)
	an.animation.advance(0.0)
	an.animation.seek(0.0, true)
	var ankles := [_bone(an, "LeftFoot").origin, _bone(an, "RightFoot").origin]
	var chest := _bone(an, "Spine").basis
	an.animation.seek(2.0, true)
	assert(_bone(an, "LeftFoot").origin.distance_to(ankles[0]) < 0.001)
	assert(_bone(an, "RightFoot").origin.distance_to(ankles[1]) < 0.001)
	assert(not _bone(an, "Spine").basis.is_equal_approx(chest), "Idle settles through the torso, not sliding feet")
	for frame in 30:
		an.animate_motion(3.0, 1.0 / 60.0)
		if frame == 0:
			assert(an.animation.speed_scale > 0.78 and an.animation.speed_scale < 1.25, "Walk cadence should accelerate without snapping")
	var fast_60 := an.animation.speed_scale
	an.animate_motion(0.0, 0.016)
	for frame in 15:
		an.animate_motion(3.0, 1.0 / 30.0)
	assert(absf(an.animation.speed_scale - fast_60) < 0.0001, "Cadence response must not depend on framerate")
	an.animate_motion(0.06, 0.016)
	assert(an.walking, "Tiny input change must not repeatedly restart gait")
	an.animate_motion(0.03, 0.016)
	assert(not an.walking)
	an.animate_motion(0.06, 0.016)
	assert(not an.walking, "Idle must ignore subthreshold jitter")
	an.animate_motion(0.09, 0.016)
	assert(an.walking)
	an.sit(true, 0.93)
	an.set_ride_motion(7.0, 1.0)
	for frame in 90:
		an.animation.advance(1.0 / 60.0)
		an._ride_pose.advance_motion(1.0 / 60.0)
		an._ride_pose._apply()
		for side in ["Left", "Right"]:
			var sign := 1.0 if side == "Left" else -1.0
			for pair in [["Hand", Vector3(sign * 0.30, 1.095, 0.475)], ["Foot", Vector3(sign * 0.18, 0.43, 0.39)]]:
				assert(_bone(an, side + pair[0]).origin.distance_to(pair[1]) < 0.025, "Riding response cannot pull hands/feet from controls")
			var palm := _bone(an, side + "Hand").basis.orthonormalized()
			assert(palm.z.y > 0.97, "Palm must lie across the bar, not retain source scan hand roll")
	var gaze := _bone(an, "Head").basis.z.normalized()
	assert(gaze.z > 0.95 and gaze.x > 0.04, "Rider should glance slightly into turn while keeping road ahead visible")
	an.set_ride_motion(0.0, 1.0)
	for frame in 90:
		an.animation.advance(1.0 / 60.0)
		an._ride_pose.advance_motion(1.0 / 60.0)
		an._ride_pose._apply()
	assert(an._ride_pose.turn < 0.001 and an._ride_pose.speed < 0.002, "Stationary rider must settle rather than lean forever")
	an.sit(false, 0.93)
	assert(an._ride_pose.turn == 0.0 and an._ride_pose.speed == 0.0)
	assert(an.model.position.y == 0.0)
	var npc := Human.make(Character.LOOKS.SAU)
	root.add_child(npc)
	npc.animate(0.016, 1.0)
	assert(npc._state == "walk" and npc._ap.speed_scale > 0.85 and npc._ap.speed_scale < 1.6)
	npc.animate(0.016, 0.08)
	assert(npc._state == "walk")
	npc.animate(0.016, 0.0)
	assert(npc._state == "idle")
	npc.animate(0.016, 0.08)
	assert(npc._state == "idle")
	print("PASS character motion: planted idle, framerate-independent cadence, hysteresis, riding response/contact/gaze, dismount reset, NPC gait")
	quit()

func _bone(an: Node3D, name: String) -> Transform3D:
	return an.skeleton.global_transform * an.skeleton.get_bone_global_pose(an.skeleton.find_bone(name))
