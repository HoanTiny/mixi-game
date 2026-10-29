extends SceneTree
## Skin deformation, grounded scale, wheel pivots and the live world factory.
## Run with --headless --path . -s tests/higgsfield_assets.gd -- --demo
const Hero := preload("res://scripts/world/named_character.gd")
const Review := preload("res://tools/review_runtime_asset.gd")
const Cart := preload("res://assets/higgsfield/street_food_cart/cart.tscn")
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(Hero.available("HANH"), "Hanh must load as an imported asset, including exported builds")
	check(not Hero.available("SAU"), "Unfinished characters must keep their existing factory")
	var hanh := Hero.make("HANH")
	root.add_child(hanh)
	await process_frame
	hanh.animate(0.25, 0.0)
	var meshes: Array = hanh.model.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "Hero must have one shared skinned mesh")
	var sk: Skeleton3D = hanh.skeleton
	check(sk.get_bone_count() == 24, "Expected the verified 24-bone rig")
	var tris := 0
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var arrays: Array = mesh.mesh.surface_get_arrays(surface)
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			tris += arrays[Mesh.ARRAY_INDEX].size() / 3
			for vertex in weights.size() / 4:
				var sum := 0.0
				for slot in 4:
					var index := vertex * 4 + slot
					sum += weights[index]
					check(weights[index] >= 0.0 and weights[index] <= 1.0 and is_finite(weights[index]), "Invalid skin weight")
					check(bones[index] < mesh.skin.get_bind_count(), "Weight references missing bone")
				check(absf(sum - 1.0) < 0.002, "Skin weights must sum to one")
	check(tris <= 18000, "Hero triangle budget exceeded")
	var idle_bounds := Review._skin_bounds(meshes[0])
	check(idle_bounds.size.y > 1.48 and idle_bounds.size.y < 1.68, "Skinned height must be human sized; do not double-apply centimetre scale")
	check(absf(idle_bounds.position.y) < 0.035, "Idle shoes must touch the ground")
	var feet := []
	for name in ["LeftFoot", "RightFoot"]:
		feet.append(sk.get_bone_global_pose(sk.find_bone(name)).origin)
	for frame in 120:
		hanh.animate(0.05, 0.0)
		sk.force_update_all_bone_transforms()
		for i in 2:
			var foot := sk.get_bone_global_pose(sk.find_bone(["LeftFoot", "RightFoot"][i])).origin
			check(foot.distance_to(feet[i]) < 0.005, "Idle breathing must not slide the planted feet")
	var walk_bounds := []
	for sample in 8:
		for frame in 10:
			hanh.animate(1.0 / 60.0, 1.0)
		var bounds := Review._skin_bounds(meshes[0])
		walk_bounds.append(str(bounds))
		check(bounds.position.is_finite() and bounds.size.is_finite(), "Walking skin contains invalid vertices")
		check(bounds.size.x < 1.0 and bounds.size.z < 1.1 and bounds.size.y < 1.75, "Walk deforms outside a human silhouette")
		check(bounds.position.y > -0.09, "Walking feet sink through pavement")
	check(hanh.position == Vector3.ZERO and hanh.model.position == Vector3.ZERO, "In-place animation must not move the gameplay root")
	for frame in 30:
		hanh.animate(1.0 / 60.0, 0.0)
	check(hanh.animation.current_animation == hanh.idle_clip, "Stopping must blend back to idle")
	var cart := Cart.instantiate()
	root.add_child(cart)
	var left: Node3D = cart.find_child("WheelLeft", true, false)
	var right: Node3D = cart.find_child("WheelRight", true, false)
	check(left != null and right != null, "Both cart wheels must have independent pivots")
	var wheel_origin := left.position
	cart.roll(0.294 * PI / 2.0)
	check(absf(left.rotation.x - PI / 2.0) < 0.001 and left.rotation.is_equal_approx(right.rotation), "Cart wheels must roll around their axle")
	check(left.position == wheel_origin, "Rolling must not orbit or move the cart wheels")
	check(cart.has_node("BodyCollision/Shape"), "Cart requires a simple body collider")
	var report := {"failures": failures, "hero_triangles": tris, "bones": sk.get_bone_count(), "idle_bounds": str(idle_bounds), "walk_bounds": walk_bounds, "wheel_pivots": 2}
	FileAccess.open("res://build/higgsfield-assets-test.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("HIGGSFIELD_ASSETS ", "PASS" if failures.is_empty() else "FAIL", " ", JSON.stringify(report))
	hanh.queue_free()
	cart.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
