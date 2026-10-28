extends SceneTree
## Pure presentation regression; add -- --demo --street-demo --integration to
## exercise the real player, final path segment, mount/reset and night light.
const Motion := preload("res://scripts/vehicles/player_motion.gd")
const Props := preload("res://scripts/world/props3d.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _run() -> void:
	_pure_motion()
	if "--integration" in OS.get_cmdline_user_args():
		await _world_motion()
	if failures.is_empty():
		print("PASS: frame-independent facing, actual planar travel, stopped wheels, bounded signed bank, shared contacts, reset and invalid delta", "; world path/mount/light integration" if "--integration" in OS.get_cmdline_user_args() else "")
	quit(0 if failures.is_empty() else 1)

func _pure_motion() -> void:
	# Exact exponential response is independent of frame count for a held heading.
	for riding in [false, true]:
		var results: Array[float] = []
		for fps in [30, 60, 120]:
			var motion := Motion.new()
			var yaw := -0.6
			var dt := 1.0 / float(fps)
			for frame in fps / 2:
				yaw = motion.advance(Vector3(3.0 * dt, 0.0, 4.0 * dt), dt, yaw, riding)
			results.append(yaw)
			_check(absf(motion.speed - 5.0) < 0.0001, "Actual speed must use planar distance/delta")
			_check(absf(motion.distance - (2.5 if riding else 0.0)) < 0.0001, "Walking must not accumulate wheel travel")
		_check(absf(results[0] - results[1]) < 0.00001 and absf(results[1] - results[2]) < 0.00001, "Facing differs at 30/60/120 FPS")
	var left := Motion.new()
	var right := Motion.new()
	left.advance(Vector3(-0.6, 0, 0.0), 0.1, 0.0, true)
	right.advance(Vector3(0.6, 0, 0.0), 0.1, 0.0, true)
	_check(left.bank > 0.0 and right.bank < 0.0, "Bank must oppose signed yaw for a left/right turn")
	_check(is_equal_approx(left.bank, -right.bank), "Mirrored steering should produce mirrored bank")
	for i in 100:
		right.advance(Vector3(10.0, 0, 0), 0.01, 0.0, true)
		_check(absf(right.bank) <= Motion.MAX_BANK + 0.000001, "Sharp turns exceeded the bank safety limit")
	# A contact represented in each local frame must remain coincident after bank.
	var base := Vector3(0, 0, Props.RIDER_Z)
	var bike_pose := right.visual_transform(Vector3.ZERO)
	var rider_pose := right.visual_transform(base)
	for contact in [Vector3(0.3, 1.095, 0.325), Vector3(-0.18, 0.43, 0.24), Vector3(0, 0.93, -0.15)]:
		_check((bike_pose * contact).distance_to(rider_pose * (contact - base)) < 0.000001, "Shared roll separated rider contact from vehicle")
	_check((bike_pose * Vector3(0, 0.27, 0)).is_equal_approx(Vector3(0, 0.27, 0)), "Roll pivot must remain at axle height")
	var distance := right.distance
	for frame in 120:
		right.advance(Vector3.ZERO, 1.0 / 60.0, 0.4, true)
	_check(right.distance == distance and right.speed == 0.0, "Stopped vehicle must not advance wheel distance")
	_check(absf(right.bank) < 0.0001 and absf(right.turn) < 0.0001, "Stopped vehicle must settle upright")
	right.advance(Vector3(0, 5.0, 0), 0.1, 0.4, true)
	_check(right.distance == distance and right.speed == 0.0, "Ground-height correction must not spin wheels")
	for bad_delta in [0.0, -0.1, NAN, INF]:
		var saved := [right.speed, right.turn, right.bank, right.distance]
		var yaw := right.advance(Vector3(1, 0, 1), bad_delta, 0.4, true)
		_check(is_finite(yaw) and is_equal_approx(yaw, 0.4), "Invalid delta must preserve finite heading")
		_check(saved == [right.speed, right.turn, right.bank, right.distance], "Invalid delta mutated presentation state")
	right.reset()
	_check([right.speed, right.turn, right.bank, right.distance] == [0.0, 0.0, 0.0, 0.0], "Mount/dismount reset left stale motion")
	right.advance(Vector3(NAN, 0, 0), 0.1, 0.4, true)
	_check(right.distance == 0.0 and right.speed == 0.0, "Non-finite travel must not poison motion")
	_check(right.visual_transform(Vector3.ZERO).is_equal_approx(Transform3D.IDENTITY), "Reset must restore unbanked vehicle")

func _world_motion() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var game = world.game
	game.s.queue.clear()
	game.s.used = 10.0 - float(game.cfg.dayStart)
	game.cfg.idleMinutesPerSecond = 0.0
	game.s["tips_seen"] = game.story.get("tips", []).map(func(t): return str(t.id))
	game.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	var avatar = world.player_body
	var marker: Node3D = null
	for child in world.player.get_children():
		if child is MeshInstance3D and child.mesh is CylinderMesh:
			marker = child
	_check(marker != null, "Player ground marker missing")
	var marker_pose: Transform3D = marker.transform if marker != null else Transform3D.IDENTITY
	var destination: Vector3 = world.door_of("tiem_sau")
	var offer: Dictionary = game.delivery_offer("com_hanh", "Cơm Hạnh", "Khách phố mẫu", destination.x, 120.0, destination.z)
	game.delivery_accept(offer)
	world._update_ride()
	_check(world._riding and world._ride_bike.visible and world.player_body == avatar, "Mount changed the avatar or failed to show bike")
	_check(not world._ride_headlight.visible, "Daytime mount must not flash an initially enabled headlight")
	_check(world._ride_headlight.get_parent() == world._ride_bike, "Player light must follow only its own vehicle")
	world.player.position = world.loc_point("com_hanh", 0.0, 1.2)
	world.player.rotation.y = 0.0
	world._update_player_motion(Vector3(0.6, 0, 0), 0.1)
	_check(world._player_motion.bank < 0.0, "World steering did not reach shared bank")
	_check(world._ride_bike.transform.basis.is_equal_approx(avatar.transform.basis), "Bike and rider are not banked together")
	if marker != null:
		_check(marker.transform.is_equal_approx(marker_pose), "Bank tilted or moved the ground marker")
	var wheel_material := world._ride_bike.get_surface_override_material(0) as ShaderMaterial
	_check(is_equal_approx(float(wheel_material.get_shader_parameter("wheel_distance")), 0.6), "World did not pass actual wheel distance")
	# Run the real _process path-final branch: it moves directly and returns ZERO.
	var start: Vector3 = world.player.position
	world._path = PackedVector2Array([Vector2(start.x, start.z), Vector2(start.x + 0.08, start.z)])
	world._path_i = 1
	world._target = start + Vector3(0.08, 0, 0)
	world._target_loc = ""
	var before: float = world._player_motion.distance
	world._process(0.02)
	_check(absf(world.player.position.x - start.x - 0.08) < 0.0001, "Final path segment did not arrive exactly")
	_check(absf(world._player_motion.distance - before - 0.08) < 0.0001, "Final path snap was omitted from wheel travel")
	var stopped: float = world._player_motion.distance
	for frame in 60:
		world._update_player_motion(Vector3.ZERO, 1.0 / 60.0)
	_check(world._player_motion.distance == stopped and absf(world._player_motion.bank) < 0.0001, "World stop rotated wheels or retained bank")
	world._update_lighting(12.0)
	world._update_player_motion(Vector3.ZERO, 1.0 / 60.0)
	_check(not world._ride_headlight.visible, "Player headlight should be off at noon")
	world._update_lighting(21.0)
	world._update_player_motion(Vector3.ZERO, 1.0 / 60.0)
	_check(world._ride_headlight.visible, "Player headlight should illuminate while riding at night")
	var light_forward: Vector3 = -world._ride_headlight.transform.basis.z
	_check(light_forward.z > 0.9 and light_forward.y < 0.0, "Headlight must aim forward and downward")
	game.delivery_cancel()
	world._update_ride()
	_check(not world._ride_headlight.visible, "Dismount must hide the light immediately")
	world._update_player_motion(Vector3.ZERO, 1.0 / 60.0)
	_check(not world._riding and not world._ride_bike.visible and not world._ride_headlight.visible, "Dismount left bike/light active")
	_check(avatar.transform.is_equal_approx(Transform3D.IDENTITY), "Dismount left avatar offset or banked")
	_check(world._player_motion.distance == 0.0 and float(wheel_material.get_shader_parameter("wheel_distance")) == 0.0, "Dismount did not reset wheel phase")
	world.queue_free()
	await process_frame
