extends SceneTree
const Crowd = preload("res://scripts/world/crowd_motion.gd")
var failures := 0
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func actor(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	root.add_child(n)
	n.position=pos
	return n
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var crowd := Crowd.new()
	var a := actor(Vector3(-3,0,0))
	var b := actor(Vector3(3,0,0))
	crowd.register(a)
	crowd.register(b)
	var minimum := INF
	for i in range(900):
		for pair in [[a,Vector3(3,0,0)],[b,Vector3(-3,0,0)]]:
			var to: Vector3 = pair[1]-pair[0].position
			if to.length()>0.06: crowd.move(pair[0],to.normalized()*minf(1.65,to.length()*60),1.0/60,true,to.length())
		minimum=minf(minimum,a.position.distance_to(b.position))
	expect(minimum>=Crowd.GAP-0.001,"Head-on bodies overlapped")
	expect(a.position.distance_to(Vector3(3,0,0))<0.1 and b.position.distance_to(Vector3(-3,0,0))<0.1,"Head-on walkers failed to pass")
	print("Head-on clearance: ",minimum," endpoints ",a.position," / ",b.position)
	a.position=Vector3(-3,0,0)
	b.position=Vector3.ZERO
	for i in range(700):
		var to := Vector3(3,0,0)-a.position
		if to.length()>0.06: crowd.move(a,to.normalized()*1.65,1.0/60,true,to.length())
		expect(a.position.distance_to(b.position)>=Crowd.GAP-0.001,"Walker passed through stationary An")
	expect(a.position.x>2.8,"Walker did not go around An")
	a.position=Vector3(-2,0,0)
	b.position=Vector3.ZERO
	for i in range(150): crowd.move(a,Vector3(3.2,0,0),1.0/60,false)
	expect(a.position.x< -Crowd.GAP+0.001 and b.position==Vector3.ZERO,"An must stop, not push or tunnel through NPC")
	a.position=Vector3(-2,0,0)
	crowd.move(a,Vector3(100,0,0),1.0,false)
	expect(a.position.x< -Crowd.GAP+0.001,"Long frame tunneled through NPC")
	crowd.obstacles=[Rect2(-1,-2,2,1.65),Rect2(-1,0.35,2,1.65)]
	a.position=Vector3(-2,0,0)
	b.position=Vector3(0,0,0)
	for i in range(240): crowd.move(a,Vector3(1.65,0,0),1.0/60,true)
	expect(a.position.distance_to(b.position)>=Crowd.GAP-0.001,"Narrow passage collision")
	a.position=Vector3(-2,0,0)
	b.position=Vector3(2,0,0)
	for i in range(1800):
		for pair in [[a,Vector3(3,0,0)],[b,Vector3(-3,0,0)]]:
			var to: Vector3 = pair[1]-pair[0].position
			if to.length()>0.06: crowd.move(pair[0],to.normalized()*minf(1.65,to.length()*60),1.0/60,true,to.length())
	expect(a.position.x>2.8 and b.position.x< -2.8,"Narrow corridor needs yielding/backtracking")
	print("Crowd tests: ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
