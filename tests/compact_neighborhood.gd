extends SceneTree
## Topology/pacing regression for layout 2. No rendering or player save access.
const City := preload("res://scripts/world/real_city.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var city := City.new("hn_pho_co")
	check(city.layout_version == 2, "Compact map version missing")
	check(city.locs.size() == 19, "Story destinations were dropped")
	check(city.bounds.size.x <= 250 and city.bounds.size.y <= 220, "World still has old empty extent")
	check(city.homes.size() >= 30 and city.homes.size() < 300, "Delivery homes not regenerated for local district")
	check(city.bins.size() >= 12, "Collectible-can quest lacks bins")
	check(city.story.questAreas.meo_be_bap.radius <= 40, "Cat search still spans old wide city")
	var legs := []
	var loop := ["xom_bo_me", "tiem_sau", "cho_cau_nho", "tiem_sau", "com_hanh", "xom_bo_me"]
	var total := 0.0
	for i in loop.size() - 1:
		var a: Vector2 = city.loc_door(loop[i])
		var b: Vector2 = city.loc_door(loop[i + 1])
		var metres: float = city.path_length(a, b)
		check(metres <= 60, "Core leg too long: " + loop[i] + " -> " + loop[i + 1])
		total += metres
		legs.append({"from":loop[i], "to":loop[i + 1], "metres":snappedf(metres,0.1)})
	check(total >= 100 and total <= 160, "Repair loop outside 100–160 m target: " + str(total))
	var housing: float = city.path_length(city.loc_door("cho_cau_nho"),city.loc_door("hem_dua"))
	check(housing <= 60, "Ngõ Gạch is not near the market")
	var meal_delivery: float = city.path_length(city.loc_door("com_hanh"),city.loc_door("ben_xe_6"))
	var delivery_hours := meal_delivery * float(city.story.walkHoursPerMeter)
	check(delivery_hours < 0.45, "Day-6 meal delivery consumes almost all 0.67-hour window")
	# The normal arrival offset must not place An in a passing traffic lane.
	var bus_arrival: Vector2 = city.loc_door("ben_xe_6") + city.locs.ben_xe_6.normal * 1.2
	var bus_road: Dictionary = city._nearest_road(bus_arrival, 2.5, "Phố Trần Nhật Duật")
	var bus_clearance: float = bus_arrival.distance_to(bus_road.q) - float(bus_road.road.width) / 2.0
	check(bus_clearance >= 0.6, "Bus arrival is too close to the traffic lane")
	check(absf(bus_arrival.y) >= 6.0, "Bus arrival overlaps Hàng Chiếu junction")
	# No two named structures may overlap. Large visual shells otherwise hide
	# destinations or force a path through another shop's collision footprint.
	var ids: Array = city.locs.keys()
	for i in ids.size():
		var first: Rect2 = City.footprint(city.locs[ids[i]])
		for j in range(i+1,ids.size()):
			var second: Rect2 = City.footprint(city.locs[ids[j]])
			check(not first.grow(-0.1).intersects(second.grow(-0.1)), "Overlapping story plots: " + str(ids[i]) + " / " + str(ids[j]))
	var report := {"layout":city.layout_version,"bounds":[city.bounds.size.x,city.bounds.size.y],
		"houses":city.data.buildings.size(),"homes":city.homes.size(),"bins":city.bins.size(),
		"repair_loop_metres":snappedf(total,0.1),"repair_loop_seconds_at_1_7":snappedf(total/1.7,0.1),
		"repair_loop_game_minutes":snappedf(total*float(city.story.walkHoursPerMeter)*60,0.1),
		"market_housing_metres":snappedf(housing,0.1),"meal_bus_metres":snappedf(meal_delivery,0.1),
		"meal_bus_game_minutes":snappedf(delivery_hours*60,0.1),"bus_arrival_lane_clearance":snappedf(bus_clearance,0.1),"legs":legs,"failures":failures}
	DirAccess.make_dir_recursive_absolute("res://build")
	FileAccess.open("res://build/compact-neighborhood-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("COMPACT_NEIGHBORHOOD ", "PASS " if failures.is_empty() else "FAIL ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
