extends Node3D
## Authored wheel pivots are in metres. A parked cart does no per-frame work.
const WHEEL_RADIUS := 0.294

func roll(distance_m: float) -> void:
	for side in ["WheelLeft", "WheelRight"]:
		var wheel := $Visual.find_child(side, true, false) as Node3D
		if wheel:
			wheel.rotation.x = fposmod(wheel.rotation.x + distance_m / WHEEL_RADIUS, TAU)
