extends Node
## Phố sống theo giờ (data/schedules.json):
## - Nhân vật có việc riêng: tới giờ thì rời chỗ quen, đi bộ thật trên đường tới nơi khác (bà Tư đi chợ, Linh ra bến xe
##   đi học, Minh chở cơm xuống Bến Cạn…), xong việc thì về. Đang ở đâu thì nói chuyện ở đó; chỗ quen ghi "đi đâu, mấy giờ về".
## - Người bán rong đẩy xe vòng qua các hẻm trong khung giờ của mình; tiếng rao (audio.gd) phát ra từ chính chiếc xe.
## Nhân vật ở xa An thì đổi chỗ ngay, chỉ đi bộ từng bước khi An có thể nhìn thấy.

const CityMap := preload("res://scripts/world/city_map.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
const WALK_SPEED := 1.6
const VENDOR_SPEED := 1.0
## Trong bán kính này (mét) mới cho nhân vật đi bộ thật; xa hơn thì đổi chỗ ngay.
const SEE_RANGE := 45.0
const VENDOR_STOP := 5.0

var world
var game
var errands: Array = []
## npc id -> {node, body, name, home, home_pos, home_rot, state, errand, path, i}
var npcs := {}
var vendors: Array = []


func setup(w) -> void:
	world = w
	game = w.game
	var data := {}
	if FileAccess.file_exists("res://data/schedules.json"):
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://data/schedules.json"))
		if d is Dictionary:
			data = d
	errands = data.get("errands", [])
	var slots := {}
	for e in errands:
		var to := str(e.to)
		slots[to] = int(slots.get(to, 0)) + 1
		e["slot"] = slots[to] - 1
	for id in w.npc_nodes:
		var n: Dictionary = w.npc_nodes[id]
		var node: Node3D = n.node
		npcs[id] = {"node": node, "body": n.body, "name": n.name, "home": n.loc,
			"home_pos": node.global_position, "home_rot": node.global_rotation.y,
			"state": "home", "errand": {}, "path": PackedVector2Array(), "i": 0}
	for v in data.get("vendors", []):
		_add_vendor(v)


# ---------------------------------------------------------------- nhân vật

## Việc riêng đang tới giờ của nhân vật (rỗng nếu đang ở chỗ quen).
func _errand_now(id: String) -> Dictionary:
	if not game.is_started() or game.is_over():
		return {}
	var hour: float = game.clock()
	var wd: int = game.day() % 7
	var rain: bool = game.s.today.get("rain", false)
	for e in errands:
		if str(e.npc) != id:
			continue
		if hour < float(e.hours[0]) or hour >= float(e.hours[1]):
			continue
		if e.has("weekdays") and not (e.weekdays as Array).has(float(wd)):
			continue
		if e.get("noRain", false) and rain:
			continue
		return e
	return {}


## Chỗ đứng ở nơi tới: bên trái cửa, mỗi người một chỗ.
func _spot(e: Dictionary) -> Vector3:
	return world.loc_point(str(e.to), -1.8 - float(e.slot) * 1.0, 0.35)


func _spot_rot(e: Dictionary) -> float:
	return CityMap.rot_y(world.city.locs[str(e.to)].normal) + PI


func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	for id in npcs:
		_update_npc(id, delta)
	_update_vendors(delta)


func _update_npc(id: String, delta: float) -> void:
	var n: Dictionary = npcs[id]
	var node: Node3D = n.node
	var want: Dictionary = _errand_now(id)
	var state := str(n.state)
	var near: bool = node.global_position.distance_to(world.player.position) < SEE_RANGE
	var cur: Dictionary = n.errand
	# Đổi ý: đang đi mà hết giờ (hay sang việc khác) thì quay về.
	if not want.is_empty() and (state == "home" or state == "returning"):
		n["errand"] = want
		if near:
			_start_walk(n, _v2(node.global_position), _v2(_spot(want)), "going")
		else:
			_arrive(n, "going")
	elif want.is_empty() and state in ["going", "there", "away"]:
		var from := node.global_position
		if state == "away":
			from = _spot(cur)
			node.global_position = from
			node.visible = true
		if from.distance_to(world.player.position) < SEE_RANGE:
			_start_walk(n, _v2(from), _v2(n.home_pos), "returning")
		else:
			_arrive(n, "returning")
	elif not want.is_empty() and state in ["going", "there", "away"] and want != cur:
		n["errand"] = want
		_arrive(n, "going")
	if str(n.state) in ["going", "returning"]:
		_step(n, delta)
	node.global_position.y = world.city.ground_y(_v2(node.global_position))


func _start_walk(n: Dictionary, a: Vector2, b: Vector2, state: String) -> void:
	n["state"] = state
	n["path"] = world.city.path(a, b)
	n["i"] = 0
	var body: Node3D = n.node.get_child(0)
	world.idlers.erase(body)
	n.body.set_meta("loc", str(n.errand.to) if state == "going" else str(n.home))


func _step(n: Dictionary, delta: float) -> void:
	var node: Node3D = n.node
	var path: PackedVector2Array = n.path
	var left := WALK_SPEED * delta
	while left > 0.0 and int(n.i) < path.size():
		var p := _v2(node.global_position)
		var goal: Vector2 = path[int(n.i)]
		var d := p.distance_to(goal)
		if d <= left:
			node.global_position = Vector3(goal.x, 0, goal.y)
			n["i"] = int(n.i) + 1
			left -= d
		else:
			var dir := (goal - p) / d
			node.global_position += Vector3(dir.x, 0, dir.y) * left
			node.global_rotation.y = atan2(dir.x, dir.y)
			left = 0.0
	var body: Node3D = node.get_child(0)
	if body.has_method("animate"):
		body.animate(delta, WALK_SPEED / 4.0)
	if int(n.i) >= path.size():
		_arrive(n, str(n.state))


## Tới nơi (hay đổi chỗ ngay khi ở xa An).
func _arrive(n: Dictionary, state: String) -> void:
	var node: Node3D = n.node
	var body: Node3D = node.get_child(0)
	if not world.idlers.has(body) and body.has_method("animate"):
		world.idlers.append(body)
	if state == "going":
		var e: Dictionary = n.errand
		node.global_position = _spot(e)
		node.global_rotation.y = _spot_rot(e)
		var away: bool = e.get("away", false)
		node.visible = not away
		n["state"] = "away" if away else "there"
		n.body.set_meta("loc", str(e.to))
	else:
		node.global_position = n.home_pos
		node.global_rotation.y = n.home_rot
		node.visible = true
		n["state"] = "home"
		n["errand"] = {}
		n.body.set_meta("loc", str(n.home))


## Nhân vật đang ở địa điểm nào để nói chuyện ("" nếu đang đi đường hay đi khỏi phường).
func npc_where(id: String) -> String:
	if not npcs.has(id):
		return ""
	var n: Dictionary = npcs[id]
	match str(n.state):
		"home":
			return str(n.home)
		"there":
			return str(n.errand.to)
	return ""


## Những người đang có mặt ở một địa điểm: [{id, name}], người quen của chỗ đó trước.
func npcs_at(loc: String) -> Array:
	var out := []
	for id in npcs:
		if npc_where(id) == loc:
			out.append({"id": id, "name": npcs[id].name})
	return out


## Người quen của chỗ này đang vắng: "Bà Tư đi chợ Cầu Nhỏ" kèm giờ về.
func notes_at(loc: String) -> Array:
	var out := []
	for id in npcs:
		var n: Dictionary = npcs[id]
		if str(n.home) != loc or npc_where(id) == loc or n.errand.is_empty():
			continue
		out.append({"name": n.name, "what": str(n.errand.get("what", "")), "back": float(n.errand.hours[1])})
	return out


# ---------------------------------------------------------------- người bán rong

func _add_vendor(v: Dictionary) -> void:
	var pts := PackedVector2Array()
	var route: Array = v.get("route", [])
	# Map thật: tuyến của người bán rong đặt theo hẻm thật trong file đặt truyện.
	if world.real:
		route = []
		for p in world.city.vendor_routes.get(str(v.id), PackedVector2Array()):
			route.append([p.x, p.y])
		if route.size() < 2:
			return
	for k in route.size() - 1:
		var a := Vector2(float(route[k][0]), float(route[k][1]))
		var b := Vector2(float(route[k + 1][0]), float(route[k + 1][1]))
		var seg: PackedVector2Array = world.city.path(a, b)
		if seg.is_empty():
			continue
		if pts.is_empty():
			pts.append(world.city.nearest_walkable(a))
		pts.append_array(seg)
	if pts.size() < 2:
		return
	var root := Node3D.new()
	root.visible = false
	world.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(v.id))
	var who: Node3D = world._character("people", Color.from_hsv(rng.randf(), 0.25, 0.7), Color("3a3a40"), rng, str(v.get("hat", "")))
	root.add_child(who)
	var body: Node3D = who.get_child(0)
	var sign_at := Vector3(0, 2.15, 0)
	if str(v.get("carry", "cart")) == "ganh" and body.has_method("add_item"):
		# Gánh trên vai: đòn gánh tre, hai thúng.
		body.add_item("chest", Props3D.ganh())
		body.hold("carry")
	else:
		# Xe đẩy theo món (props3d.gd), người bán đứng sau, hai tay nắm tay đẩy.
		var cart := Props3D.instance(Props3D.cart(str(v.id)), Color(str(v.get("cart", "8a6a4a"))))
		cart.position = Vector3(0, 0, 0.48 - Props3D.CART_GRIP_Z)
		root.add_child(cart)
		if body.has_method("hold"):
			body.hold("push")
		sign_at = Vector3(0, 1.75, cart.position.z)
	var sign: Label3D = world._label3d(str(v.get("name", "")).to_upper(), sign_at, 20)
	sign.modulate = Color("ffe7a8")
	root.add_child(sign)
	var length := 0.0
	for k in pts.size() - 1:
		length += pts[k].distance_to(pts[k + 1])
	vendors.append({"id": str(v.id), "cfg": v, "node": root, "body": who.get_child(0), "pts": pts,
		"length": length, "s": rng.randf() * length, "wait": 0.0, "stops": _stops(pts, route)})


## Chỗ dừng bán: các điểm của tuyến (đầu hẻm, góc đường), tính theo quãng đường đã đi.
func _stops(pts: PackedVector2Array, route: Array) -> Array:
	var out := []
	var acc := 0.0
	var k := 1
	for i in pts.size() - 1:
		acc += pts[i].distance_to(pts[i + 1])
		if k < route.size() and pts[i + 1].distance_to(Vector2(float(route[k][0]), float(route[k][1]))) < 3.0:
			out.append(acc)
			k += 1
	return out


func _update_vendors(delta: float) -> void:
	var hour: float = game.clock() if game.is_started() else -1.0
	var rain: bool = game.is_started() and bool(game.s.today.get("rain", false))
	for v in vendors:
		var on: bool = game.is_started() and not game.is_over() and not rain and hour >= float(v.cfg.hours[0]) and hour < float(v.cfg.hours[1])
		var node: Node3D = v.node
		node.visible = on
		if not on:
			continue
		var body: Node3D = v.body
		if float(v.wait) > 0.0:
			v["wait"] = float(v.wait) - delta
			if body.has_method("animate"):
				body.animate(delta, 0.0)
		else:
			var before := float(v.s)
			v["s"] = fmod(before + VENDOR_SPEED * delta, float(v.length))
			for st in v.stops:
				if before < float(st) and float(st) <= float(v.s):
					v["wait"] = VENDOR_STOP
			if body.has_method("animate"):
				body.animate(delta, VENDOR_SPEED / 4.0)
		var at := _point_at(v.pts, float(v.s))
		var ahead := _point_at(v.pts, fmod(float(v.s) + 0.6, float(v.length)))
		node.position = Vector3(at.x, 0, at.y)
		if ahead.distance_to(at) > 0.01:
			node.rotation.y = lerp_angle(node.rotation.y, atan2(ahead.x - at.x, ahead.y - at.y), 0.2)


func _point_at(pts: PackedVector2Array, s: float) -> Vector2:
	var acc := 0.0
	for i in pts.size() - 1:
		var d := pts[i].distance_to(pts[i + 1])
		if acc + d >= s:
			return pts[i].lerp(pts[i + 1], (s - acc) / maxf(d, 0.001))
		acc += d
	return pts[pts.size() - 1]


## Chỗ xe bán rong đang ở (null nếu chưa tới giờ ra phố), để phát tiếng rao từ xe.
func vendor_pos(id: String):
	for v in vendors:
		if str(v.id) == id and (v.node as Node3D).visible:
			return (v.node as Node3D).position
	return null


static func _v2(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)
