extends SceneTree
## Verify near/far traffic as one moving vehicle, including re-entry and rebuild.
const Traffic := preload("res://scripts/world/traffic.gd")
var failed := false

func same_paint(a: Color, b: Color) -> bool:
	return Vector3(a.r, a.g, a.b).is_equal_approx(Vector3(b.r, b.g, b.b))

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Traffic MultiMesh readback requires a real renderer; run this test in a hidden graphical process.")
		quit(1)
		return
	var traffic := Traffic.new()
	root.add_child(traffic)
	var roads := [{"small": false, "tunnel": false, "width": 10.0, "kind": "residential",
		"line": PackedVector2Array([Vector2(-70, 0), Vector2(0, 0), Vector2(70, 0)]),
		"name": "Test street", "bridge": false}]
	traffic.build(roads, Vector2.ZERO, 150.0, 2.0)
	check(traffic.counts.bikes > 0 and traffic.counts.cars > 0, "Both vehicle classes must spawn")
	check(traffic.routes.size() == 1, "One continuous traffic route")
	var near_count := 0
	var sample_group: Dictionary = {}
	var sample_index := -1
	for g in traffic.groups:
		check(g.detail_mm != null, "Detailed mesh available for every real traffic group")
		check(g.detail_mm.visible_instance_count == g.detail_count, "GPU only draws the populated detailed prefix")
		var slots := []
		for i in g.mm.instance_count:
			var low: Transform3D = g.mm.get_instance_transform(i)
			check(absf(low.origin.z) < 4.0 and absf(low.origin.z) >= 1.3, "Vehicles stay inside traffic lanes")
			var active_low := absf(low.basis.determinant()) > 0.00001
			var slot: int = g.detail_slot[i]
			var active_high: bool = slot >= 0 and slot < g.detail_mm.visible_instance_count
			if active_high:
				var high: Transform3D = g.detail_mm.get_instance_transform(slot)
				check(low.origin.is_equal_approx(high.origin), "Compacted near/far models occupy the same route position")
				check(same_paint(g.mm.get_instance_custom_data(i), g.detail_mm.get_instance_custom_data(slot)), "Compaction preserves the source vehicle paint RGB")
				check(high == g.poses[i], "Compacted draw pose matches its source vehicle")
				slots.append(slot)
			check(active_low != active_high, "Exactly one geometry version renders per vehicle")
			if g.detail_on[i] == 1:
				near_count += 1
				sample_group = g
				sample_index = i
		check(slots == range(g.detail_count), "Detailed draw slots form a unique contiguous prefix")
	check(near_count > 0, "Nearby vehicles use detailed geometry")
	if sample_index >= 0:
		var p3: Vector3 = sample_group.mm.get_instance_transform(sample_index).origin
		var p := Vector2(p3.x, p3.z)
		traffic._focus = p + Vector2(21, 0)
		traffic._place(sample_group, 0.0)
		check(sample_group.detail_on[sample_index] == 1, "Near LOD retained through hysteresis band")
		traffic._focus = p + Vector2(25, 0)
		traffic._place(sample_group, 0.0)
		check(sample_group.detail_on[sample_index] == 0, "Near geometry leaves at outer range")
		traffic._focus = p + Vector2(21, 0)
		traffic._place(sample_group, 0.0)
		check(sample_group.detail_on[sample_index] == 0, "Far geometry retained through hysteresis band")
		traffic._focus = p + Vector2(19, 0)
		traffic._place(sample_group, 0.0)
		check(sample_group.detail_on[sample_index] == 1, "Detailed geometry returns at inner range")
	# Changing which original indices are nearby must not swap paint/poses when
	# their compact GPU slots are reassigned in subsequent frames.
	for step in 5:
		var phases := []
		for g in traffic.groups:
			phases.append(g.wheel_phase.duplicate())
		traffic.update(1.2, Vector2(-35.0 + step * 17.5, 0))
		for gi in traffic.groups.size():
			var g: Dictionary = traffic.groups[gi]
			var populated := 0
			for i in g.detail_slot.size():
				var expected := fposmod(float(phases[gi][i]) + float(g.speed[i]) * 1.2 / (TAU * float(g.wheel_radius)), 1.0)
				check(absf(float(g.wheel_phase[i]) - expected) < 0.00001, "Wheel turns track traveled distance/radius, both route directions")
				var slot: int = g.detail_slot[i]
				if slot < 0:
					continue
				populated += 1
				check(g.detail_mm.get_instance_transform(slot).is_equal_approx(g.poses[i]), "Reassigned detail slot retains the correct vehicle pose")
				# Compatibility quantizes custom-data storage, so compare against
				# the same source vehicle's GPU colour rather than full CPU precision.
				var custom: Color = g.detail_mm.get_instance_custom_data(slot)
				check(same_paint(custom, g.mm.get_instance_custom_data(i)), "Reassigned detail slot retains the correct vehicle paint RGB")
				check(absf(custom.a - float(g.wheel_phase[i])) < 0.001, "GPU slot keeps that vehicle's current wheel phase")
			check(populated == g.detail_mm.visible_instance_count, "Only active detailed vehicles are submitted after movement")
	traffic.density = 0.0
	traffic.update(0.25, Vector2.ZERO)
	for g in traffic.groups:
		check(g.detail_count == 0 and not g.detail_node.visible, "Rain density hides both near and far vehicles")
		check(g.detail_mm.visible_instance_count == 0, "Zero density submits no detailed vehicle vertices")
		for i in g.mm.instance_count:
			check(g.mm.get_instance_transform(i).basis.get_scale().length() < 0.002, "No visible far duplicate at zero density")
	traffic.density = 1.0
	traffic.update(0.0, Vector2.ZERO)
	traffic.update(10000.0, Vector2(1000, 1000))
	for g in traffic.groups:
		check(not g.detail_node.visible, "Distant clusters cannot leave frozen detailed traffic")
		check(g.detail_mm.visible_instance_count == 0, "Out-of-range clusters submit no detailed vehicle vertices")
		check(not g.detail_on.has(1), "Leaving the update range restores coarse vehicle geometry")
		for i in g.s.size():
			check(g.s[i] >= 0 and g.s[i] < float(traffic.routes[g.rid[i]].len), "Large elapsed time wraps into valid route range")
	traffic.update(0.0, Vector2.ZERO)
	check(traffic.near_vehicle(Vector2.ZERO) != null, "Traffic remains available for positional audio")
	traffic.build(roads, Vector2.ZERO, 150.0, 2.0, 0.0)
	check(traffic.groups.is_empty() and traffic.get_child_count() == 0, "Area rebuild frees both owned LOD batches")
	check(traffic.counts.bikes == 0 and traffic.counts.cars == 0, "Area counts reset on rebuild")
	traffic.free()
	print("PASS: traffic detail swap, lane positions, hysteresis, density, long-frame route wrap and rebuild" if not failed else "FAIL: traffic realism")
	quit(1 if failed else 0)
