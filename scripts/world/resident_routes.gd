extends RefCounted
## A small sidewalk graph around the street's tables, crates and utility poles.
var graph := AStarGrid2D.new()
var world
var obstacles: Array[Rect2] = []
func _init(owner_world) -> void:
	world = owner_world
	graph.region = Rect2i(0,0,513,11)
	graph.cell_size = Vector2(0.25,0.25)
	graph.offset = Vector2(-68,-4.5)
	graph.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	graph.update()
	for loc in world.LOCATIONS.values():
		var x := float(loc.x)
		obstacles.append(Rect2(Vector2(x-3.55,-4.33),Vector2(2.1,1.26)))
		obstacles.append(Rect2(Vector2(x-3.08,-3.45),Vector2(1.16,1.1)))
		obstacles.append(Rect2(Vector2(x-4.6,-5.08),Vector2(1.2,1.16)))
	for x in range(-60,58,14):
		obstacles.append(Rect2(Vector2(x-0.44,-3.74),Vector2(0.88,0.88)))
	for x in range(graph.region.size.x):
		for y in range(graph.region.size.y):
			var cell := Vector2i(x,y)
			var point := graph.get_point_position(cell)
			for box in obstacles:
				if box.has_point(point): graph.set_point_solid(cell,true)
func cell_at(pos: Vector3) -> Vector2i:
	var base := Vector2i(roundi((pos.x+68)*4),roundi((pos.z+4.5)*4))
	base.x = clampi(base.x,0,512)
	base.y = clampi(base.y,0,10)
	var best := base
	var distance := INF
	for dx in range(-5,6):
		for dy in range(-5,6):
			var cell := base + Vector2i(dx,dy)
			if not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): continue
			var d := graph.get_point_position(cell).distance_squared_to(Vector2(pos.x,pos.z))
			if d < distance: best = cell; distance = d
	return best
func refresh() -> void:
	if not world.game.is_started(): return
	var s: Dictionary = world.game.s
	var initialize: bool = not s.has("npc_routes")
	if initialize: s.npc_routes = {}
	var reserved: Array[Vector2i] = []
	for index in world.residents.size():
		var r: Dictionary = world.residents[index]
		var destination: String = world.game.Street.schedule(r.name,world.game.clock())
		if destination.is_empty(): destination = r.home
		var target: Vector3 = world.door_of(destination) + Vector3(0.8+index*1.0,0,0)
		var end: Vector2i = r.end if r.get("destination","")==destination and r.has("end") else available_end(cell_at(target),r.node,reserved)
		reserved.append(end)
		if initialize or not r.has("path"):
			var initial := graph.get_point_position(end)
			if s.npc_routes.has(r.name):
				var saved: Array = s.npc_routes[r.name].position
				r.node.global_position = Vector3(float(saved[0]),0,float(saved[1]))
			else: world.crowd.place(r.node,Vector3(initial.x,0,initial.y))
			r.path = []
			r.destination = ""
		if r.destination != destination:
			r.destination = destination
			r.end = end
			r.retry = 0.0
			r.path = []
			for point in graph.get_point_path(cell_at(r.node.global_position),end):
				r.path.append(Vector3(point.x,0,point.y))
			# A missing route must never turn into a teleport or a false arrival.
			r.reachable = not r.path.is_empty()
			if r.body.has_meta("loc"): r.body.remove_meta("loc")
			r.body.set_meta("travelling",r.name + " đang đi tới " + world.location_info(destination).name)
		store(r)
func store(r: Dictionary) -> void:
	world.game.s.npc_routes[r.name] = {"position":[r.node.global_position.x,r.node.global_position.z],"destination":r.destination,"current":r.destination if r.path.is_empty() and r.get("reachable",false) else ""}
func tick(delta: float) -> void:
	if not world.game.is_started() or world.game.is_over(): return
	var arrived := false
	for r in world.residents:
		if not r.has("path"): continue
		var before: Vector3 = r.node.global_position
		var speed := 1.15 if r.name=="Bà Tư" else 1.65
		while not r.path.is_empty() and r.node.global_position.distance_to(r.path[0])<0.08: r.path.pop_front()
		if not r.path.is_empty():
			var to: Vector3 = r.path[0]-r.node.global_position
			world.crowd.move(r.node,to.normalized()*minf(speed,to.length()/maxf(delta,0.001)),delta,true,to.length())
			r.retry = float(r.get("retry",0.0))+delta
			if r.retry>1.5:
				r.retry=0.0
				repath(r)
		var movement: Vector3 = r.node.global_position-before
		if movement.length()>0.001:
			r.node.rotation.y = lerp_angle(r.node.rotation.y,atan2(movement.x,movement.z),minf(1,delta*9))
		elif r.path.is_empty() and r.get("reachable",false):
			if not r.body.has_meta("loc"): arrived = true
			r.body.set_meta("loc",r.destination)
			if r.body.has_meta("travelling"): r.body.remove_meta("travelling")
		r.node.animate_motion(movement.length()/maxf(delta,0.001),delta)
		store(r)
	if arrived: world.game.changed.emit()

func repath(r: Dictionary) -> void:
	var goal := graph.get_point_position(r.end)
	if not world.crowd.free_at(Vector3(goal.x,0,goal.y),r.node,Vector3(goal.x,0,goal.y)):
		var reserved: Array[Vector2i] = []
		for other in world.residents:
			if other!=r and other.has("end"): reserved.append(other.end)
		r.end=available_end(r.end,r.node,reserved)
	var start := cell_at(r.node.global_position)
	var marked: Array[Vector2i] = []
	for actor in world.crowd.actors:
		if actor==r.node or actor.global_position.distance_to(r.node.global_position)>5.0: continue
		var cell := cell_at(actor.global_position)
		for dx in range(-3,4):
			for dy in range(-2,3):
				var candidate := cell+Vector2i(dx,dy)
				if not graph.is_in_boundsv(candidate) or candidate==r.end or graph.is_point_solid(candidate): continue
				var p := graph.get_point_position(candidate)
				if p.distance_to(Vector2(actor.global_position.x,actor.global_position.z))<world.crowd.GAP+0.06:
					graph.set_point_solid(candidate,true)
					marked.append(candidate)
	start = cell_at(r.node.global_position)
	var points := graph.get_point_path(start,r.end)
	for cell in marked: graph.set_point_solid(cell,false)
	if points.is_empty(): return # Wait rather than inventing a path through a person.
	r.path=[]
	for p in points: r.path.append(Vector3(p.x,0,p.y))

func available_end(wanted: Vector2i, actor: Node3D, reserved: Array[Vector2i]) -> Vector2i:
	var best := wanted
	var score := INF
	for dx in range(-3,4):
		for dy in range(-2,3):
			var cell := wanted+Vector2i(dx,dy)
			if not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): continue
			var point := graph.get_point_position(cell)
			var free: bool = world.crowd.free_at(Vector3(point.x,0,point.y),actor,Vector3(point.x,0,point.y))
			for taken in reserved:
				if graph.get_point_position(taken).distance_to(point)<world.crowd.GAP: free=false
			if not free: continue
			var distance := point.distance_squared_to(graph.get_point_position(wanted))
			if distance<score: best=cell; score=distance
	return best


func route_for(actor: Node3D, wanted: Vector3) -> Array:
	var reserved: Array[Vector2i] = []
	var end := available_end(cell_at(wanted),actor,reserved)
	var marked: Array[Vector2i] = []
	for other in world.crowd.actors:
		if other==actor: continue
		var center := cell_at(other.global_position)
		for dx in range(-3,4):
			for dy in range(-3,4):
				var cell := center+Vector2i(dx,dy)
				if cell==end or not graph.is_in_boundsv(cell) or graph.is_point_solid(cell): continue
				if graph.get_point_position(cell).distance_to(Vector2(other.global_position.x,other.global_position.z))<world.crowd.GAP+0.04:
					marked.append(cell)
					graph.set_point_solid(cell,true)
	var points := graph.get_point_path(cell_at(actor.global_position),end)
	for cell in marked: graph.set_point_solid(cell,false)
	var result := []
	for p in points: result.append(Vector3(p.x,0,p.y))
	return result
