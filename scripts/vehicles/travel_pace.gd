extends RefCounted
## Translation envelope in metres/seconds. Navigation still chooses each step
## and owns collision; presentation reads the distance actually accepted.
const WALK_ACCEL := 5.4
const WALK_BRAKE := 8.5
const RIDE_ACCEL := 2.8
const RIDE_BRAKE := 8.0

var speed := 0.0
var direction := Vector3.ZERO

func reset() -> void:
	speed = 0.0
	direction = Vector3.ZERO

func advance(wanted: Vector3, top_speed: float, delta: float, riding: bool, remaining := -1.0) -> float:
	if not is_finite(delta) or delta <= 0.0 or not wanted.is_finite() or not is_finite(top_speed):
		return 0.0
	var goal := maxf(top_speed, 0.0) * minf(wanted.length(), 1.0)
	if wanted.length_squared() > 0.000001:
		direction = wanted.normalized()
	var brake := RIDE_BRAKE if riding else WALK_BRAKE
	if remaining >= 0.0:
		goal = minf(goal, sqrt(2.0 * brake * remaining))
	var rate := (RIDE_ACCEL if riding else WALK_ACCEL) if goal > speed else brake
	# Integrate both the ramp and any time spent at its target. Multiplying the
	# end-of-frame speed by delta would make starts/stops differ with refresh rate.
	var ramp_time := minf(delta, absf(goal - speed) / rate)
	var end_speed := move_toward(speed, goal, rate * delta)
	var distance := (speed + end_speed) * 0.5 * ramp_time + goal * (delta - ramp_time)
	speed = end_speed
	if remaining >= 0.0 and distance >= remaining:
		distance = remaining
		speed = 0.0
	return distance

func reconcile(requested: float, accepted: float, delta: float) -> void:
	# Hitting a person/wall must not store full speed for an explosive restart.
	if requested > 0.00001 and accepted < requested * 0.25:
		speed = minf(speed, maxf(accepted, 0.0) / maxf(delta, 0.001))
