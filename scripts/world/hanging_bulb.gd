extends Node3D
var phase := 0.0
var lamp: OmniLight3D
var game
func _process(delta: float) -> void:
	phase += delta
	rotation.z = sin(phase*0.85)*0.035
	if lamp != null:
		var hour: float = game.clock() if game != null and game.is_started() else 18.0
		lamp.light_energy = 0.85 if hour >= 17 or hour < 7 else 0.12
