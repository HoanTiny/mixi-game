extends SceneTree
## Nướng người thật (Rocketbox, assets/rb) thành lưới tĩnh nhẹ cho đám đông (crowd.gd) và người lái xe (traffic.gd):
## dựng người, chạy động tác tới một khung, lấy lưới theo tư thế đó, bớt tam giác (còn chừng TARGET_TRIS), bỏ đỉnh thừa,
## lưu assets/rb/crowd/<id người>_<tư thế>.res (người theo Character.CROWD) kèm vật liệu ảnh thật.
## Tư thế: stand (đứng), talk (đứng nói, tay đưa), sit (ngồi ghế, hông 0,6 m), walk (giữa bước), ride (lái xe máy:
## hông ở Props3D.SEAT_H, RIDER_Z, hai tay nắm tay lái, đội mũ bảo hiểm), back (ngồi sau xe, đội mũ).
## Chạy: godot --headless --path . -s res://tools/bake_people.gd

const Human := preload("res://scripts/world/human.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
const OUT := "res://assets/rb/crowd"
const TARGET_TRIS := 1800
const Character := preload("res://scripts/world/character.gd")
## Độ cao khớp hông lúc ngồi ghế đẩu cao (0,42 m) và ghế đẩu thấp (0,27 m) ở quán cóc (street_dress.gd).
const SEAT_HIP := {"sit": 0.52, "low": 0.37}
## Tay lái xe máy (hai tay nắm) theo dáng xe trong props3d.gd.
const GRIP := Vector3(0.3, 1.08, 0.38)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for look in Character.CROWD:
		for pose in ["stand", "talk", "sit", "low", "walk", "ride", "back"]:
			await _bake(look, pose)
	await _bake(Character.CROWD_CHILD, "walk")
	await _bake(Character.CROWD_CHILD, "stand")
	quit()


func _bake(look: Dictionary, pose: String) -> void:
	var name := str(look.id)
	var h: Node3D = Human.make(look)
	var hip: float = Human.SIT_HIP * float(look.get("scale", 1.0))
	root.add_child(h)
	var anim: String = {"stand": "idle", "talk": "talk", "sit": "sit", "low": "sit", "walk": "walk", "ride": "sit", "back": "sit"}[pose]
	var ap: AnimationPlayer = h._ap
	ap.play("rb/" + anim)
	ap.seek({"walk": 0.3, "talk": 1.2}.get(pose, 0.5), true)
	var off := Vector3.ZERO
	if pose == "ride":
		off = Vector3(0, Props3D.SEAT_H - hip, Props3D.RIDER_Z)
	elif pose == "back":
		off = Vector3(0, Props3D.SEAT_H - hip + 0.04, Props3D.BACK_Z)
	elif pose in SEAT_HIP:
		off = Vector3(0, SEAT_HIP[pose] - hip, 0)
	h.position = off
	await process_frame
	var sk: Skeleton3D = h._sk
	if pose == "ride":
		for side in ["L", "R"]:
			var s := 1.0 if side == "L" else -1.0
			_reach(sk, h, ["%s UpperArm", "%s Forearm", "%s Hand"], side, Vector3(s * GRIP.x, GRIP.y, GRIP.z), Vector3(s * 0.6, -1.0, 0.0), false)
	elif pose in SEAT_HIP:
		# Ghế thấp hơn ghế trong động tác: co gối lên, bàn chân đặt trên mặt đất trước ghế.
		for side in ["L", "R"]:
			var s := 1.0 if side == "L" else -1.0
			_reach(sk, h, ["%s Thigh", "%s Calf", "%s Foot"], side, Vector3(s * 0.14, 0.09, 0.4), Vector3(0.0, 1.0, 1.0), true)
	await process_frame
	var surfaces := []
	for mi in sk.find_children("*", "MeshInstance3D", true, false):
		var baked: ArrayMesh = (mi as MeshInstance3D).bake_mesh_from_current_skeleton_pose()
		var xf: Transform3D = h.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		xf = Transform3D(Basis(), off) * xf
		for i in baked.get_surface_count():
			surfaces.append([baked.surface_get_arrays(i), (mi as MeshInstance3D).get_surface_override_material(i), xf])
	var out := ArrayMesh.new()
	var tris := 0
	for s in surfaces:
		var arrays := _simplify(s[0], s[2], float(TARGET_TRIS) / 7500.0)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(out.get_surface_count() - 1, s[1])
		tris += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if pose in ["ride", "back"]:
		_helmet(out, sk, h, off)
	var path := "%s/%s_%s.res" % [OUT, name, pose]
	ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
	print("%s  tam giác %d" % [path, tris])
	h.queue_free()
	await process_frame


## Bớt tam giác một mặt lưới (meshoptimizer qua ImporterMesh), dời theo xf, chỉ giữ đỉnh còn dùng.
func _simplify(arrays: Array, xf: Transform3D, ratio: float) -> Array:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var clean := []
	clean.resize(Mesh.ARRAY_MAX)
	clean[Mesh.ARRAY_VERTEX] = verts
	clean[Mesh.ARRAY_NORMAL] = norms
	clean[Mesh.ARRAY_TEX_UV] = uvs
	clean[Mesh.ARRAY_INDEX] = idx
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, clean)
	im.generate_lods(25.0, 60.0, [])
	var best := idx
	for l in im.get_surface_lod_count(0):
		var li := im.get_surface_lod_indices(0, l)
		if li.size() >= int(idx.size() * ratio) or best.size() > int(idx.size() * ratio) * 2:
			best = li
		if li.size() < int(idx.size() * ratio):
			break
	var remap := {}
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	var ni := PackedInt32Array()
	for v in best:
		if not remap.has(v):
			remap[v] = nv.size()
			nv.append(xf * verts[v])
			nn.append((xf.basis * norms[v]).normalized())
			nu.append(uvs[v])
		ni.append(remap[v])
	var res := []
	res.resize(Mesh.ARRAY_MAX)
	res[Mesh.ARRAY_VERTEX] = nv
	res[Mesh.ARRAY_NORMAL] = nn
	res[Mesh.ARRAY_TEX_UV] = nu
	res[Mesh.ARRAY_INDEX] = ni
	return res


## Hai đoạn xương (cánh tay, cẳng tay hay đùi, cẳng chân) đưa đầu mút tới đích (không gian người); khớp giữa chĩa về
## phía pole; keep_end: bàn chân giữ hướng của động tác, không thì bàn tay nối theo cẳng tay.
func _reach(sk: Skeleton3D, h: Node3D, names: Array, side: String, target_h: Vector3, pole_h: Vector3, keep_end: bool) -> void:
	var to_sk: Transform3D = sk.global_transform.affine_inverse() * h.global_transform
	var target := to_sk * (target_h - h.position)
	var iu := sk.find_bone("Bip01 " + str(names[0]) % side)
	var iff := sk.find_bone("Bip01 " + str(names[1]) % side)
	var ih := sk.find_bone("Bip01 " + str(names[2]) % side)
	var ru := sk.get_bone_global_rest(iu)
	var rf := sk.get_bone_global_rest(iff)
	var rh := sk.get_bone_global_rest(ih)
	var lu := ru.origin.distance_to(rf.origin)
	var lf := rf.origin.distance_to(rh.origin)
	var end_basis := sk.get_bone_global_pose(ih).basis
	var sh := sk.get_bone_global_pose(iu).origin
	var d := (target - sh)
	var dist := clampf(d.length(), 0.05, (lu + lf) * 0.999)
	var dir := d.normalized()
	var pole := (to_sk.basis * pole_h).normalized()
	pole = (pole - dir * pole.dot(dir)).normalized()
	var a := (lu * lu + dist * dist - lf * lf) / (2.0 * dist)
	var hgt := sqrt(maxf(lu * lu - a * a, 0.0))
	var mid := sh + dir * a + pole * hgt
	var tip := sh + dir * dist
	var d1 := (mid - sh).normalized()
	var d2 := (tip - mid).normalized()
	sk.set_bone_global_pose(iu, Transform3D(Basis(Quaternion(ru.basis.x.normalized(), d1)) * ru.basis, sh))
	sk.set_bone_global_pose(iff, Transform3D(Basis(Quaternion(rf.basis.x.normalized(), d2)) * rf.basis, mid))
	var hb := end_basis if keep_end else Basis(Quaternion(rh.basis.x.normalized(), d2)) * rh.basis
	sk.set_bone_global_pose(ih, Transform3D(hb, tip))


## Mũ bảo hiểm (lưới của character.gd) đặt theo đầu; màu sơn theo màu đỉnh, phủ vật liệu màu đỉnh.
func _helmet(out: ArrayMesh, sk: Skeleton3D, h: Node3D, off: Vector3) -> void:
	var Character = load("res://scripts/world/character.gd")
	var mesh: Mesh = Character._acc("helmet")
	var head := sk.find_bone("Bip01 Head")
	var hp: Vector3 = (h.global_transform.affine_inverse() * sk.global_transform * sk.get_bone_global_pose(head)).origin + off
	var xf := Transform3D(Basis(), hp - Human.OLD_BONE_POS.head + Vector3(0, 0.045, 0.01))
	for i in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		for k in v.size():
			v[k] = xf * v[k]
		a[Mesh.ARRAY_VERTEX] = v
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color("c0392b")
		m.roughness = 0.4
		out.surface_set_material(out.get_surface_count() - 1, m)
