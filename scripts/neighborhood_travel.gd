extends RefCounted
## Chuyến xe trong câu chuyện. Giá và thời lượng là cân bằng game, không phải lịch xe thật.
const HUB := "ben_xe_6"
const ROUTES := {
	"cau_tre": {"name": "Phòng Ngọc Thụy", "cost": 7000, "minutes": 20, "day": 3},
	"ben_can": {"name": "Phố Tạ Hiện", "cost": 5000, "minutes": 12, "day": 10},
	"ho_guom": {"name": "Hồ Gươm", "cost": 7000, "minutes": 18, "day": 3},
}

static func enabled(city) -> bool:
	return city.id == "hn_pho_co" and int(city.story.get("layoutVersion", 1)) >= 2

static func options(g, from: String) -> Array:
	if not g.is_started() or g.is_over():
		return []
	var out: Array = []
	if from == HUB:
		for destination in ROUTES:
			var row: Dictionary = ROUTES[destination].duplicate()
			row["destination"] = destination
			row["reason"] = reason(g, from, destination)
			out.append(row)
	elif ROUTES.has(from):
		var row: Dictionary = ROUTES[from].duplicate()
		row["name"] = "Điểm xe Long Biên · về khu trọ"
		row["destination"] = HUB
		row["reason"] = reason(g, from, HUB)
		out.append(row)
	return out

static func reason(g, from: String, destination: String) -> String:
	if not g.is_started() or g.is_over():
		return "Chưa trong ngày chơi"
	if not g.s.queue.is_empty():
		return "Nói chuyện xong rồi lên xe"
	var route := _route(from, destination)
	if route.is_empty():
		return "Không có chuyến từ đây"
	# Luôn có chuyến về, kể cả khi đi bộ tới một khu chưa được giới thiệu.
	if destination != HUB and g.day() < int(route.day):
		return "Từ ngày %d · hiện vẫn có thể đi bộ" % int(route.day)
	if not g.delivery_active().is_empty():
		return "Giao xong đơn đang nhận trước khi lên xe"
	if int(g.s.cash) < int(route.cost):
		return "Chưa đủ tiền xe · vẫn có thể đi bộ"
	if g.hours_left() < float(route.minutes) / 60.0:
		return "Không đủ giờ cho chuyến này"
	return ""

static func _route(from: String, destination: String) -> Dictionary:
	if from == HUB and ROUTES.has(destination):
		return ROUTES[destination]
	if destination == HUB and ROUTES.has(from):
		return ROUTES[from]
	return {}

## World kiểm tra đứng tại điểm xe và đích đi được trước khi trả tiền.
## Chưa commit ở đây để world đặt An xuống xe trước khi phát changed.
static func pay(g, from: String, destination: String) -> bool:
	if reason(g, from, destination) != "":
		return false
	var route := _route(from, destination)
	var name := "Long Biên" if destination == HUB else str(route.name)
	g.spend(int(route.cost), "Chuyến xe tới " + name)
	g.elapse(float(route.minutes) / 60.0)
	g.add_log("Xuống xe tại %s · %d phút. Đi bộ tiếp từ điểm dừng." % [name, int(route.minutes)])
	return true

## Rebase một đơn đang giao khi map đổi layout. Không trả thưởng, không phạt hủy.
## Vị trí người chơi cũ vốn không được lưu: world hiện An ở cửa nhà khi nạp.
static func migrate_layout(g, city, homes: Array, locations: Dictionary) -> bool:
	if not g.is_started() or not enabled(city):
		return false
	var tag := "%s:%d" % [city.id, int(city.story.layoutVersion)]
	if str(g.s.get("world_layout", "")) == tag:
		return false
	var order: Dictionary = g.delivery_active()
	if not order.is_empty():
		var shop := str(order.get("shop", ""))
		var destination := Vector2.INF
		var label := str(order.get("dest", ""))
		for id in locations:
			if str(locations[id].name) == label:
				destination = city.loc_door(id)
				break
		if not destination.is_finite():
			for home in homes:
				if str(home.name) == label:
					destination = Vector2(home.pos.x, home.pos.z)
					break
		# Địa chỉ cũ không còn: khách hẹn nhận ở một cửa hoạt động gần quán.
		if city.locs.has(shop) and not destination.is_finite():
			var best := INF
			for id in locations:
				if id == shop:
					continue
				var pos: Vector2 = city.loc_door(id)
				var length := route_length(city, city.loc_door(shop), pos)
				if length >= 15.0 and length < best:
					best = length
					destination = pos
					label = "Khách hẹn trước " + str(locations[id].name)
		if city.locs.has(shop) and destination.is_finite() and city.walkable(destination):
			order["dest_x"] = destination.x
			order["dest_z"] = destination.y
			order["dest"] = label
			var start: Vector2 = city.loc_door(g.home_loc() if city.locs.has(g.home_loc()) else "xom_bo_me")
			var length := route_length(city, start, destination) if bool(order.get("picked", false)) else route_length(city, start, city.loc_door(shop)) + route_length(city, city.loc_door(shop), destination)
			if is_finite(length):
				var hours := length * float(g.cfg.get("walkHoursPerMeter", 0.0032)) * float(g.cfg.delivery.slackFactor) + float(g.cfg.delivery.slackHours)
				if not bool(order.get("picked", false)):
					hours += float(g.cfg.delivery.cookHours)
				order["deadline"] = maxf(float(order.get("deadline", g.clock())), g.clock() + hours)
				g.add_log("Phố đã sắp xếp lại: cập nhật điểm giao và thời hạn của đơn đang nhận; giữ nguyên tiền công.")
			else:
				g.s.erase("delivery")
				g.add_log("Địa chỉ giao cũ không còn đường tới; hủy đơn không phạt khi cập nhật phố.")
		else:
			g.s.erase("delivery")
			g.add_log("Địa chỉ giao cũ không còn; hủy đơn không phạt khi cập nhật phố.")
	g.s["world_layout"] = tag
	return true

static func route_length(city, from: Vector2, to: Vector2) -> float:
	if from.distance_to(to) < 0.05:
		return 0.0
	var path: PackedVector2Array = city.path(from, to)
	if path.size() < 2 or path[-1].distance_to(to) > 0.1:
		return INF
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length

## Filtrer theo đường thực đi, cả chuyến lấy món và giao. Đơn đầu ở gần người.
static func make_offer(g, city, position: Vector2, homes: Array, locations: Dictionary) -> Dictionary:
	if g.delivery_lock() != "":
		return {}
	var nearby: Array = []
	var pickup_limit := 55.0 if g.day() <= 3 else 100.0
	for id in g.cfg.delivery.shops:
		if not city.locs.has(id) or not locations.has(id):
			continue
		var distance := route_length(city, position, city.loc_door(id))
		if distance <= pickup_limit:
			nearby.append({"id": id, "distance": distance})
	nearby.sort_custom(func(a, b): return a.distance < b.distance)
	for pickup in nearby:
		var shop := str(pickup.id)
		var sp: Vector2 = city.loc_door(shop)
		var candidates: Array = []
		for home in homes:
			candidates.append({"name": str(home.name), "pos": Vector2(home.pos.x, home.pos.z)})
		for id in locations:
			if id != shop:
				candidates.append({"name": str(locations[id].name), "pos": city.loc_door(id)})
		candidates.shuffle()
		var limit := 60.0 if g.day() <= 3 else 100.0
		for candidate in candidates:
			var dp: Vector2 = candidate.pos
			# Loại xa trước khi chạy AStar cho mỗi địa chỉ.
			if sp.distance_to(dp) < 12.0 or sp.distance_to(dp) > limit:
				continue
			var length := route_length(city, sp, dp)
			if length < 15.0 or length > limit:
				continue
			return g.delivery_offer(shop, str(locations[shop].name), str(candidate.name), dp.x, float(pickup.distance) + length + 4.0, dp.y)
	return {}
