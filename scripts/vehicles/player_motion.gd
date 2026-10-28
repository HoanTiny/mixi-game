extends RefCounted
## Presentation only: navigation owns translation. Drive wheel phase and body
## cadence from the distance actually covered, never from a requested speed.

const WALK_TURN_RATE := 17.260924
const RIDE_TURN_RATE := 10.0
const MAX_BANK := 0.12
var speed := 0.0
var turn := 0.0
var bank := 0.0
var distance := 0.0

func reset() -> void:
	speed = 0.0
	turn = 0.0
	bank = 0.0
	distance = 0.0

func advance(step: Vector3, delta: float, yaw: float, riding: bool) -> float:
	if not is_finite(delta) or delta <= 0.0 or not step.is_finite() or not is_finite(yaw):
		return yaw
	var planar := Vector2(step.x, step.z)
	speed = planar.length() / delta
	var yaw_step := 0.0
	if speed > 0.001:
		var desired := atan2(planar.x, planar.y)
		var rate := RIDE_TURN_RATE if riding else WALK_TURN_RATE
		yaw_step = wrapf(desired - yaw, -PI, PI) * (1.0 - exp(-rate * delta))
	var yaw_rate := yaw_step / delta
	var moving := riding and speed > 0.35
	var turn_goal := clampf(yaw_rate / 3.0, -1.0, 1.0) if moving else 0.0
	turn = lerpf(turn, turn_goal, 1.0 - exp(-10.0 * delta))
	# A small shared bank gives the turn weight, while preserving the exact
	# navigation/collision path. Positive yaw turns right, hence negative roll.
	var bank_goal := clampf(-atan(speed * yaw_rate / 9.81) * 0.24, -MAX_BANK, MAX_BANK) if moving else 0.0
	bank = lerpf(bank, bank_goal, 1.0 - exp(-10.0 * delta)) if riding else 0.0
	if riding:
		distance += planar.length()
	return wrapf(yaw + yaw_step, -PI, PI)

func visual_transform(base: Vector3) -> Transform3D:
	# Roll about the wheel axle height so the body and rider share exactly the
	# same transform; the ground selection marker is not a child of this pose.
	var pivot := Vector3(0, 0.27, 0)
	var basis := Basis(Vector3.BACK, bank)
	return Transform3D(basis, pivot + basis * (base - pivot))
