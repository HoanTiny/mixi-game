extends RefCounted
## Persistent logical zones layered over the existing continuous Hanoi street map.
## Rendering and physical arrival stay in World; this module owns atomic travel costs.

static func data(g) -> Dictionary:
	return g.cfg.get("zones", {})

static func definitions(g) -> Dictionary:
	return data(g).get("zones", {})

static func current(g) -> String:
	return str(g.s.get("zone", data(g).get("default", "phuc_tan")))

static func migrate(g) -> void:
	if not g.is_started() or definitions(g).is_empty(): return
	if not definitions(g).has(current(g)) or not g.s.has("zone"):
		g.s["zone"] = str(data(g).get("default", "phuc_tan"))

static func zone_for_location(g, location: String) -> String:
	for id in definitions(g):
		if definitions(g)[id].get("locations", []).has(location): return str(id)
	return ""

static func action_block(g, action: Dictionary) -> String:
	if not bool(g.s.get("zone_navigation", false)): return ""
	var zone := str(action.get("zone", zone_for_location(g, g.action_loc(action))))
	if zone != "" and zone != current(g):
		return "Cần tới " + str(definitions(g).get(zone, {}).get("name", zone))
	return ""

static func minutes(g, destination: String) -> int:
	return int(data(g).get("travelMinutes", {}).get(current(g), {}).get(destination, 25))

static func travel_reason(g, destination: String, pending_hours := 0.0) -> String:
	if not g.is_started() or g.is_over(): return "Chưa trong ngày chơi"
	if not definitions(g).has(destination): return "Khu vực không tồn tại"
	if destination == current(g): return "Bạn đang ở khu này"
	if not g.s.queue.is_empty(): return "Nói chuyện xong rồi chuyển khu"
	if not g.delivery_active().is_empty(): return "Giao xong đơn đang nhận trước khi chuyển khu"
	if g.hours_left() + 0.00001 < float(minutes(g, destination)) / 60.0 + pending_hours:
		return "Không đủ thời gian di chuyển"
	if 100.0 - float(g.s.fatigue) < float(data(g).get("staminaCost", 5)):
		return "Cần nghỉ lấy sức trước khi chuyển khu"
	return ""

static func travel(g, destination: String, commit := true, pending_hours := 0.0) -> bool:
	if travel_reason(g, destination, pending_hours) != "": return false
	var duration := minutes(g, destination)
	g.elapse(float(duration) / 60.0 + pending_hours)
	g.add_fatigue(float(data(g).get("staminaCost", 5)))
	g.s["zone"] = destination
	g.s["zone_navigation"] = true
	g.add_log("Chuyển tới %s · %d phút · Thể lực −%d" % [definitions(g)[destination].name, duration, int(data(g).get("staminaCost", 5))])
	if commit: g._commit()
	return true

static func actions(g, zone := "") -> Array:
	var selected := current(g) if zone == "" else zone
	var out: Array = []
	for a in g.cfg.actions:
		if (bool(a.get("portable", false)) or zone_for_location(g, g.action_loc(a)) == selected) and not g.is_hidden(a): out.append(a)
	var preferred: Array = definitions(g).get(selected, {}).get("quick", [])
	out.sort_custom(func(a, b):
		if bool(a.get("portable", false)) != bool(b.get("portable", false)): return bool(a.get("portable", false))
		var ai := preferred.find(str(a.id)); var bi := preferred.find(str(b.id))
		if ai < 0: ai = 100
		if bi < 0: bi = 100
		return ai < bi)
	return out
