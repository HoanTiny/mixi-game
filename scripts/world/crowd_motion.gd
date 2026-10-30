extends RefCounted
## Ground-plane kinematic bodies. Every displacement is checked against people and props.
## The 10 cm substeps prevent crossing a body even during a long frame.
const RADIUS := 0.32
const GAP := RADIUS*2.0+0.025
var actors: Array[Node3D] = []
var obstacles: Array[Rect2] = []
var velocities := {}
var stalls := {}
var yielding := {}
func register(node: Node3D) -> void:
	if not actors.has(node): actors.append(node)
func free_at(point: Vector3, actor: Node3D, origin: Vector3) -> bool:
	if point.x < -67.6 or point.x > 59.6 or point.z < -4.6 or point.z > 4.5: return false
	var p := Vector2(point.x,point.z)
	var from := Vector2(origin.x,origin.z)
	for box in obstacles:
		if box.has_point(p):
			if not box.has_point(from) or edge_distance(box,p)>=edge_distance(box,from)-0.00001: return false
	for other in actors:
		if other==actor or not is_instance_valid(other): continue
		var distance := p.distance_squared_to(Vector2(other.global_position.x,other.global_position.z))
		if distance < GAP*GAP:
			# Older saves may already overlap. Permit separating, never deeper penetration.
			if distance <= from.distance_squared_to(Vector2(other.global_position.x,other.global_position.z))+0.000001: return false
	return true
func edge_distance(box: Rect2, point: Vector2) -> float:
	return minf(minf(point.x-box.position.x,box.end.x-point.x),minf(point.y-box.position.y,box.end.y-point.y))
func fraction(actor: Node3D, direction: Vector3, distance: float) -> float:
	if distance<0.00001: return 1.0
	var origin := actor.global_position
	var count := maxi(1,ceili(distance/0.10))
	var previous := origin
	for i in range(1,count+1):
		var point := origin+direction*(distance*float(i)/count)
		if not free_at(point,actor,previous): return float(i-1)/count
		previous=point
	return 1.0
func move(actor: Node3D, desired: Vector3, delta: float, steer := true, goal_distance := INF) -> Vector3:
	var speed := desired.length()
	if speed<0.001:
		velocities[actor.get_instance_id()] = Vector3.ZERO
		return Vector3.ZERO
	var direction := desired/speed
	var chosen := direction
	if steer:
		var best := -INF
		var previous: Vector3 = velocities.get(actor.get_instance_id(),Vector3.ZERO)
		# Prefer the right-hand side consistently; head-on walkers choose opposite lanes.
		for degrees in [0.0,20.0,-20.0,40.0,-40.0,65.0,-65.0,90.0,-90.0]:
			var candidate := direction.rotated(Vector3.UP,deg_to_rad(degrees))
			var clear := fraction(actor,candidate,minf(minf(speed*0.85,1.4),goal_distance))
			var immediate := fraction(actor,candidate,speed*minf(delta,0.25))
			var score := candidate.dot(direction)*3.0+clear*6.0
			if previous.length()>0.1: score += candidate.dot(previous.normalized())*0.35
			if degrees<0: score-=0.15
			if immediate<0.5: score-=12
			if score>best: best=score; chosen=candidate
	var key := actor.get_instance_id()
	var retreat := float(yielding.get(key,0.0))
	if steer and retreat>0:
		chosen=-direction
		yielding[key]=maxf(0,retreat-delta)
	var distance := speed*minf(delta,0.25)
	var amount := fraction(actor,chosen,distance)
	var movement := chosen*distance*amount
	if not steer and amount<1.0:
		# WASD slides along a body but does not autonomously steer around it.
		for axis in [Vector3(direction.x,0,0),Vector3(0,0,direction.z)]:
			var candidate: Vector3 = axis*distance
			if candidate.length()>movement.length() and fraction(actor,candidate.normalized(),candidate.length())>=1:
				movement=candidate
	if steer:
		stalls[key]=float(stalls.get(key,0.0))+delta if movement.length()<distance*0.2 else 0.0
		if float(stalls[key])>0.8:
			for other in actors:
				if other!=actor and actors.find(other)<actors.find(actor) and actor.global_position.distance_to(other.global_position)<1.25:
					yielding[key]=1.2
					stalls[key]=0.0
					break
	actor.global_position += movement
	velocities[actor.get_instance_id()] = movement/maxf(delta,0.001)
	return movement
func place(actor: Node3D, wanted: Vector3) -> void:
	# Only used on spawn or morning reset, never to resolve a collision while walking.
	for ring in range(0,16):
		for turn in range(16):
			var angle := TAU*turn/16.0
			var p := wanted+Vector3(cos(angle),0,sin(angle))*(ring*0.25)
			if free_at(p,actor,p):
				actor.global_position=p
				return
