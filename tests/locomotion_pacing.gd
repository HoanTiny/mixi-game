extends SceneTree
## Headless regression for metre-based start/stop envelopes and path braking.
const Pace := preload("res://scripts/vehicles/travel_pace.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world_script = load("res://scripts/world/world.gd")
	assert(is_equal_approx(world_script.SPEED, 1.7), "Default walk must remain a human walking pace")
	assert(is_equal_approx(world_script.SPEED * world_script.SPRINT, 3.15), "Shift should remain a purposeful jog")
	assert(is_equal_approx(world_script.SPEED * world_script.RIDE_SPEED, 4.8), "Delivery bike cap must suit the narrow streets")
	for riding in [false, true]:
		var speed := 4.8 if riding else 1.7
		var brake := Pace.RIDE_BRAKE if riding else Pace.WALK_BRAKE
		var accel := Pace.RIDE_ACCEL if riding else Pace.WALK_ACCEL
		var totals: Array[float] = []
		for fps in [30, 60, 120]:
			var pace := Pace.new()
			var delta := 1.0 / float(fps)
			var distance := 0.0
			for frame in fps * 3:
				var step := pace.advance(Vector3.RIGHT, speed, delta, riding)
				assert(step >= 0.0 and step <= speed * delta + 0.00001)
				if frame == 0:
					assert(step > 0.0 and step < speed * delta * 0.15, "First frame should respond without an instant full-speed step")
				distance += step
			assert(absf(distance - (3.0 * speed - speed * speed / (2.0 * accel))) < 0.0001)
			var release := 0.0
			for frame in fps:
				release += pace.advance(Vector3.ZERO, speed, delta, riding)
			assert(pace.speed == 0.0, "Releasing movement must reach rest")
			assert(absf(release - speed * speed / (2.0 * brake)) < 0.0001, "Stop distance changed with framerate")
			assert(release < (1.5 if riding else 0.18), "Key release drift is too large near a doorway")
			assert(pace.advance(Vector3.ZERO, speed, delta, riding) == 0.0)
			totals.append(distance + release)
			# A short click must arrive without overshoot, including routes shorter
			# than one full-speed frame. No direct position snap bypasses navigation.
			for length: float in [0.005, 0.08, 0.3, 3.0, 12.0]:
				pace.reset()
				var travelled := 0.0
				for frame in fps * 20:
					var remaining := length - travelled
					var step := pace.advance(Vector3.RIGHT, speed, delta, riding, remaining)
					assert(step <= remaining + 0.00001 and step >= 0.0, "Braking crossed the destination")
					travelled += step
					if absf(travelled - length) < 0.000001:
						break
				assert(absf(travelled - length) < 0.000001, "Braking stalled before its target")
		assert(absf(totals[0] - totals[1]) < 0.0001 and absf(totals[1] - totals[2]) < 0.0001)
	var blocked := Pace.new()
	blocked.advance(Vector3.RIGHT, 1.7, 1.0, false)
	blocked.reconcile(0.17, 0.0, 0.1)
	assert(blocked.speed == 0.0, "Collision stored stale speed")
	assert(blocked.advance(Vector3.RIGHT, 1.7, 0.02, false) < 0.002)
	blocked.reset()
	for delta in [0.0, -0.1, NAN, INF]:
		assert(blocked.advance(Vector3.RIGHT, 1.7, delta, false) == 0.0)
		assert(blocked.speed == 0.0)
	print("PASS pacing: 1.7 m/s walk, 3.15 jog, 4.8 ride; frame-independent acceleration/braking, bounded release drift, short-path arrival, collision reset")
	quit()
