extends SceneTree
var failures := 0
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	seed(51)
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	world.game.s.used=2.0
	world.game.changed.emit()
	world.crowd.place(world.player,world.door_of("tiem_sau"))
	world.walk_to_location("xom_bo_me")
	var minimum := INF
	for i in range(800):
		world._physics_process(0.05)
		var actors: Array = world.crowd.actors
		for a in actors.size():
			for b in range(a+1,actors.size()): minimum=minf(minimum,actors[a].global_position.distance_to(actors[b].global_position))
		if world._target==null: break
	expect(world._target==null,"An could not walk home through the crowd")
	expect(minimum>=world.crowd.GAP-0.002,"Live crowd overlap: "+str(minimum))
	world.hud.close_location()
	world.walk_to_location("tiem_sau")
	for i in range(900):
		world._physics_process(0.05)
		if world._target==null: break
	expect(world._target==null,"An could not return to the shop")
	print("Live crowd: ","PASS" if failures==0 else "FAIL", " clearance=",minimum, " position=",world.player.position)
	quit(0 if failures==0 else 1)
