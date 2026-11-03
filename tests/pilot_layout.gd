extends SceneTree
## Run twice: godot --headless --path . -s tests/pilot_layout.gd -- --demo
## and append --street-demo to verify the authored layout as well as the base map.
const City = preload("res://scripts/world/real_city.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var city = City.new("hn_pho_co")
	if not city.pilot_active:
		check(city.pilot_plots.is_empty(), "normal mode has no pilot fillers")
		check(city.locs.xom_bo_me.center.x > 150.0, "normal lodging position preserved")
		check(city.locs.com_hanh.center.x > 90.0, "normal food position preserved")
		check(is_zero_approx(city.ground_y(Vector2(65, -142.3))), "normal map has no pilot raised floor")
	else:
		check(city.pilot_plots.size() == 5, "five filler plots")
		for entry in city.pilot_definition.locations:
			var location: Dictionary = city.locs[str(entry.id)]
			check(location.kind == str(entry.kind) and location.seed == int(entry.seed), "core architecture metadata: %s" % entry.id)
		for key in city.pilot_walk_points:
			var p: Vector2 = city.pilot_walk_points[key]
			check(city.walkable(p), "walk point %s %s" % [key, p])
			check(city.nearest_walkable(p).distance_to(p) < 0.05, "no endpoint snapping: %s" % key)
			var floor_height := 0.14 if key in ["alley", "courtyard", "courtyard_left", "courtyard_right"] else 0.0
			check(is_equal_approx(city.ground_y(p), floor_height), "correct floor height: %s" % key)
		for p in city.pilot_plots:
			check(not city.walkable(p.center - p.normal * 3.0), "filler body blocked: %s" % p.id)
		var route := ["home", "food", "repair", "courtyard", "courtyard_left", "courtyard_right", "home"]
		for i in range(1, route.size()):
			var start: Vector2 = city.pilot_walk_points[route[i - 1]]
			var end: Vector2 = city.pilot_walk_points[route[i]]
			var path: PackedVector2Array = city.path(start, end)
			var label := "%s -> %s" % [route[i - 1], route[i]]
			check(path.size() >= 2, "path exists: " + label)
			if path.size() >= 2:
				check(path[0].distance_to(start) < 0.05 and path[-1].distance_to(end) < 0.05, "path reaches exact endpoints: " + label)
				for segment in range(1, path.size()):
					var steps := ceili(path[segment - 1].distance_to(path[segment]) / 0.2)
					for step in range(steps + 1):
						var sample := path[segment - 1].lerp(path[segment], float(step) / maxi(steps, 1))
						check(city.walkable(sample), "path segment stays walkable: " + label)
			print("ROUTE ", label, " ", path)
		var lodging: Dictionary = city.locs.xom_bo_me
		for local in [Vector2(-4, -2), Vector2(4, -2), Vector2(-5, -5), Vector2(5, -5), Vector2(0, -7.85)]:
			check(not city.walkable(lodging.center + local), "lodging wall blocked: %s" % local)
		check(is_equal_approx(city.locs.nha_di_nam.center.x, 80.0), "neighbor story lot unchanged")
	print("PILOT_LAYOUT mode=", city.pilot_active, " failures=", failures)
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, detail: String) -> void:
	if not ok and not failures.has(detail):
		failures.append(detail)
