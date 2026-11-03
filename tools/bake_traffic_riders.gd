extends "res://tools/bake_people.gd"
## Close traffic riders: same licensed Rocketbox source/atlas, preserved folds
## and deliberately posed hands/feet. Run with a real renderer (hidden is fine),
## never the dummy headless renderer which cannot bake a skeleton mesh.
const DETAIL_OUT := "res://assets/rb/riders_detail"
const DETAIL_RATIO := 0.43
var failed := false


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Traffic rider baking requires an actual renderer.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DETAIL_OUT))
	_layout(Character.CROWD + [Character.CROWD_CHILD])
	_mat = (load(ATLAS_MAT) as Material).duplicate()
	_mat.albedo_color = Color("e0dfd9")
	_mat.roughness = 0.88
	_mat.metallic_specular = 0.22
	for look in Character.CROWD:
		for kind in ["tay_ga", "xe_so"]:
			await _bake_detail(look, "ride", kind)
		await _bake_detail(look, "back", "tay_ga")
	print("PASS: 27 posed traffic riders, hand/foot targets verified" if not failed else "FAIL: rider bake")
	quit(1 if failed else 0)


func _bake_detail(look: Dictionary, pose: String, kind: String) -> void:
	var h: Node3D = Human.make(look)
	root.add_child(h)
	var ap: AnimationPlayer = h._ap
	ap.play("rb/sit")
	ap.seek(0.5, true)
	await process_frame
	# Freeze BEFORE IK; waiting another frame with the animation active used to
	# silently restore the chair pose (hands on knees) in the old rider assets.
	ap.active = false
	var sk: Skeleton3D = h._sk
	var hip_local := (h.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Bip01 Pelvis"))).origin
	var desired := Vector3(0, Props3D.SEAT_H + (0.04 if pose == "back" else 0.0), Props3D.BACK_Z if pose == "back" else Props3D.RIDER_Z)
	var off := desired - hip_local
	h.position = off
	if pose == "ride":
		# The chair clip keeps the trunk upright, too far from a scooter handlebar
		# for the shorter rigs. Lean from the waist, then keep the gaze level.
		var spine := sk.find_bone("Bip01 Spine")
		var neck := sk.find_bone("Bip01 Neck")
		var axis := sk.global_transform.basis.inverse() * Vector3.RIGHT
		var bend := Basis(axis.normalized(), 0.48)
		var spine_pose := sk.get_bone_global_pose(spine)
		sk.set_bone_global_pose(spine, Transform3D(bend * spine_pose.basis, spine_pose.origin))
		sk.force_update_all_bone_transforms()
		if neck >= 0:
			var neck_pose := sk.get_bone_global_pose(neck)
			sk.set_bone_global_pose(neck, Transform3D(bend.inverse() * neck_pose.basis, neck_pose.origin))
	for side in ["L", "R"]:
		var sign_x := 1.0 if side == "L" else -1.0
		if pose == "ride":
			# Wrist is just behind the rubber grip so fingers wrap over the bar.
			_reach(sk, h, ["%s UpperArm", "%s Forearm", "%s Hand"], side,
				Vector3(sign_x * 0.30, 1.08, 0.32), Vector3(sign_x * 0.65, -0.5, -0.15), false)
		var foot := Vector3(sign_x * 0.16, 0.40, 0.10) if kind == "tay_ga" else Vector3(sign_x * 0.24, 0.41, 0.20)
		if pose == "back":
			foot = Vector3(sign_x * 0.25, 0.44, -0.30)
		_reach(sk, h, ["%s Thigh", "%s Calf", "%s Foot"], side, foot,
			Vector3(sign_x * 0.12, 0.35, 1.0), true)
	sk.force_update_all_bone_transforms()
	await process_frame
	await RenderingServer.frame_post_draw
	# Verify the final render pose after the animation/modifier frame, not just
	# the transient pose immediately following the IK setters.
	var to_world := sk.global_transform
	for side in ["L", "R"]:
		var sign_x := 1.0 if side == "L" else -1.0
		if pose == "ride":
			var hand := to_world * sk.get_bone_global_pose(sk.find_bone("Bip01 %s Hand" % side)).origin
			if hand.distance_to(Vector3(sign_x * 0.30, 1.08, 0.32)) > 0.045:
				push_error("Grip failed: %s %s %s %s" % [look.id, kind, side, hand])
				failed = true
		var expected_foot := Vector3(sign_x * 0.16, 0.40, 0.10) if kind == "tay_ga" else Vector3(sign_x * 0.24, 0.41, 0.20)
		if pose == "back":
			expected_foot = Vector3(sign_x * 0.25, 0.44, -0.30)
		var actual_foot := to_world * sk.get_bone_global_pose(sk.find_bone("Bip01 %s Foot" % side)).origin
		if actual_foot.distance_to(expected_foot) > 0.045:
			push_error("Footrest failed: %s %s %s %s %s" % [look.id, pose, kind, side, actual_foot])
			failed = true
	var merged := []
	merged.resize(Mesh.ARRAY_MAX)
	merged[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	merged[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	merged[Mesh.ARRAY_TEX_UV] = PackedVector2Array()
	merged[Mesh.ARRAY_INDEX] = PackedInt32Array()
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var src: Mesh = (mi as MeshInstance3D).mesh
		var has_body := false
		for i in src.get_surface_count():
			has_body = has_body or Human._part(src, i) == "body"
		var baked: ArrayMesh = (mi as MeshInstance3D).bake_mesh_from_current_skeleton_pose()
		var xf: Transform3D = (mi as MeshInstance3D).global_transform
		for i in baked.get_surface_count():
			var part := Human._part(src, i)
			var owner := str(look.rb) if part == "body" or has_body else str(look.get("head", look.rb))
			var tile: Rect2i = _tiles[_key(owner, part, "" if part == "body" else str(look.get("hair_tone", "")))]
			var arrays := _simplify(baked.surface_get_arrays(i), xf, DETAIL_RATIO)
			var base: int = merged[Mesh.ARRAY_VERTEX].size()
			merged[Mesh.ARRAY_VERTEX].append_array(arrays[Mesh.ARRAY_VERTEX])
			merged[Mesh.ARRAY_NORMAL].append_array(arrays[Mesh.ARRAY_NORMAL])
			for uv in arrays[Mesh.ARRAY_TEX_UV]:
				var u := (uv as Vector2).clamp(Vector2.ZERO, Vector2.ONE)
				merged[Mesh.ARRAY_TEX_UV].append((Vector2(tile.position) + u * Vector2(tile.size)) / float(ATLAS_SIZE))
			for index in arrays[Mesh.ARRAY_INDEX]:
				merged[Mesh.ARRAY_INDEX].append(base + int(index))
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
	out.surface_set_material(0, _mat)
	_helmet(out, sk, h, off)
	out.set_meta("source", "Microsoft Rocketbox, MIT; see assets/rb/NGUON.md")
	out.set_meta("pose", pose)
	out.set_meta("vehicle_kind", kind)
	out.set_meta("hand_target", Vector3(0.30, 1.08, 0.32))
	var suffix := "%s_%s" % [pose, kind] if pose == "ride" else "back"
	var path := "%s/%s_%s.res" % [DETAIL_OUT, look.id, suffix]
	if ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS) != OK:
		failed = true
	print("Baked %s: %d triangles" % [path, merged[Mesh.ARRAY_INDEX].size() / 3])
	h.queue_free()
	await process_frame
