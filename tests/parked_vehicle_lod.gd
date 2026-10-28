extends SceneTree
## Run with a real Compatibility renderer, because native visibility ranges
## and MultiMesh readback are not exercised by the headless dummy renderer.
const AreaBuilder := preload("res://scripts/realmap/area_builder.gd")
const Props := preload("res://scripts/world/props3d.gd")
var failed := false

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, why: String) -> void:
	if not ok:
		failed = true
		push_error(why)

func stats() -> Dictionary:
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	return {"draws": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"tris": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)}

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Parked vehicle LOD test needs a real renderer.")
		quit(1)
		return
	var area := AreaBuilder.new()
	root.add_child(area)
	# Far from origin, but inside one small tile: tests the actual AABB centre.
	var items := [[Vector2(1000, 1000), Vector2.RIGHT], [Vector2(1004, 1000), Vector2.RIGHT]]
	area._vehicle_mm(items, Props.motorbike("tay_ga", false), [Color("783c36"), Color("40596a")], Props.motorbike("tay_ga", true))
	var far: MultiMeshInstance3D = area.get_child(0)
	var near: MultiMeshInstance3D = area.get_child(1)
	check(area.get_child_count() == 2, "One paired batch for one occupied parking tile")
	check(far.multimesh.instance_count == items.size() and near.multimesh.instance_count == items.size(), "Near and far preserve parking population")
	check(far.multimesh.custom_aabb == near.multimesh.custom_aabb, "Both levels share the exact switch centre")
	check(far.multimesh.custom_aabb.get_center().distance_to(Vector3(1002, 1, 1000)) < 2.0, "AABB centre follows the remote tile, not world origin")
	check(far.visibility_range_begin == 48.0 and near.visibility_parent == near.get_path_to(far), "Near detail depends on the far batch's native visibility range")
	for i in items.size():
		check(far.multimesh.get_instance_transform(i) == near.multimesh.get_instance_transform(i), "Parked LOD keeps orientation and position")
		check(far.multimesh.get_instance_custom_data(i) == near.multimesh.get_instance_custom_data(i), "Parked LOD keeps paint")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 8.0
	camera.far = 1000
	var center := near.multimesh.custom_aabb.get_center()
	camera.position = center + Vector3(0, 5, 10)
	camera.look_at(center)
	camera.current = true
	var close_stats := await stats()
	# Disable the far batch explicitly: near view must already have culled it.
	far.visible = false
	var close_only := await stats()
	check(close_stats == close_only, "Near camera renders no coarse duplicate")
	far.visible = true
	camera.position = center + Vector3(0, 5, 65)
	camera.look_at(center)
	var far_stats := await stats()
	near.visible = false
	var far_only := await stats()
	check(far_stats == far_only, "Far camera renders no detailed duplicate")
	check(close_stats.tris > far_stats.tris * 2.0 and far_stats.draws > 0, "Real renderer switches to the lightweight mesh at distance")
	near.visible = true
	for distance in [47.99, 48.0, 48.01]:
		camera.position = center + Vector3(0, 0, distance)
		camera.look_at(center)
		var edge := await stats()
		check(edge == close_stats or edge == far_stats, "Switch boundary has exactly one visible mesh at %.2fm" % distance)
	camera.position = center + Vector3(0, 92, 64)
	camera.look_at(center)
	var overview := await stats()
	check(overview == far_stats, "Overview camera uses far geometry")
	print("PARKED_LOD near=", close_stats, " far=", far_stats, " overview=", overview)
	# Two distant occupied tiles must not become one huge AABB around origin.
	var remote := AreaBuilder.new()
	root.add_child(remote)
	remote._vehicle_mm([[Vector2(-1000, -1000), Vector2.RIGHT], [Vector2(1000, 1000), Vector2.RIGHT]], Props.car(false), [Color.WHITE], Props.car(true))
	check(remote.get_child_count() == 4, "Independent small tiles for distant parking spots")
	for node in remote.get_children():
		check(node.multimesh.custom_aabb.size.length() < 8.0, "No world-sized vehicle culling bounds")
	remote.free()
	area.free()
	camera.free()
	print("PASS: parked population, transforms, paint, tile bounds and actual exclusive near/far/overview rendering" if not failed else "FAIL: parked vehicle LOD")
	quit(1 if failed else 0)
