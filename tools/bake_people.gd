extends SceneTree
## Nướng người thật (Rocketbox, assets/rb) thành lưới tĩnh nhẹ cho đám đông (crowd.gd) và người lái xe (traffic.gd):
## dựng người, chạy động tác tới một khung, lấy lưới theo tư thế đó, bớt tam giác (còn chừng TARGET_TRIS), bỏ đỉnh thừa,
## lưu assets/rb/crowd/<id người>_<tư thế>.res (người theo Character.CROWD). Ảnh thân, mặt, tóc của mọi người gom vào
## một tấm atlas.png (ô 512 cho thân, ô 256 cho mặt và tóc), mỗi người một mặt lưới duy nhất dùng chung vật liệu
## crowd_mat.tres: đám đông, dòng xe vẽ mỗi nhóm một lần (web đỡ giật).
## Tư thế: stand (đứng), talk (đứng nói, tay đưa), sit (ngồi ghế, hông 0,6 m), walk (giữa bước), ride (lái xe máy:
## hông ở Props3D.SEAT_H, RIDER_Z, hai tay nắm tay lái, đội mũ bảo hiểm), back (ngồi sau xe, đội mũ).
## Chạy hai bước (lần đầu làm atlas, nhập ảnh, rồi nướng):
##   godot --headless --path . -s res://tools/bake_people.gd -- --atlas
##   godot --headless --path . --import
##   xvfb-run godot --path . --rendering-driver opengl3 -s res://tools/bake_people.gd

const Human := preload("res://scripts/world/human.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
const OUT := "res://assets/rb/crowd"
const TARGET_TRIS := 900
const Character := preload("res://scripts/world/character.gd")
## Độ cao khớp hông lúc ngồi ghế đẩu cao (0,42 m) và ghế đẩu thấp (0,27 m) ở quán cóc (street_dress.gd).
const SEAT_HIP := {"sit": 0.52, "low": 0.37}
## Tay lái xe máy (hai tay nắm) theo dáng xe trong props3d.gd.
const GRIP := Vector3(0.3, 1.08, 0.38)
const ATLAS := OUT + "/atlas.png"
const ATLAS_MAT := OUT + "/crowd_mat.tres"
const ATLAS_SIZE := 2048
## Ô của từng ảnh trong atlas: "người|phần|tóc" -> Rect2i (điểm ảnh).
var _tiles := {}
var _mat: Material


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var looks: Array = Character.CROWD + [Character.CROWD_CHILD]
	_layout(looks)
	if "--atlas" in OS.get_cmdline_user_args():
		_make_atlas()
		quit()
		return
	if not ResourceLoader.exists(ATLAS_MAT):
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(ATLAS)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.45
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.8
		ResourceSaver.save(m, ATLAS_MAT)
	_mat = load(ATLAS_MAT)
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
	# Mọi mặt lưới (thân, mặt, tóc; cả đầu ghép) gộp thành một, UV dời vào ô của ảnh đó trong atlas.
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
		var xf: Transform3D = h.global_transform.affine_inverse() * (mi as MeshInstance3D).global_transform
		xf = Transform3D(Basis(), off) * xf
		for i in baked.get_surface_count():
			var part := Human._part(src, i)
			var owner := str(look.rb) if part == "body" or has_body else str(look.get("head", look.rb))
			var tile: Rect2i = _tiles[_key(owner, part, "" if part == "body" else str(look.get("hair_tone", "")))]
			var arrays := _simplify(baked.surface_get_arrays(i), xf, float(TARGET_TRIS) / 7500.0)
			var base: int = (merged[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			merged[Mesh.ARRAY_VERTEX].append_array(arrays[Mesh.ARRAY_VERTEX])
			merged[Mesh.ARRAY_NORMAL].append_array(arrays[Mesh.ARRAY_NORMAL])
			for uv in arrays[Mesh.ARRAY_TEX_UV]:
				var u := (uv as Vector2).clamp(Vector2.ZERO, Vector2.ONE)
				merged[Mesh.ARRAY_TEX_UV].append((Vector2(tile.position) + u * Vector2(tile.size)) / float(ATLAS_SIZE))
			for k in arrays[Mesh.ARRAY_INDEX]:
				merged[Mesh.ARRAY_INDEX].append(base + int(k))
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, merged)
	out.surface_set_material(0, _mat)
	var tris: int = (merged[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	if pose in ["ride", "back"]:
		_helmet(out, sk, h, off)
	var path := "%s/%s_%s.res" % [OUT, name, pose]
	ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
	print("%s  tam giác %d" % [path, tris])
	h.queue_free()
	await process_frame


static func _key(avatar: String, part: String, hair: String) -> String:
	return "%s|%s|%s" % [avatar, part, hair if part != "body" else ""]


## Chia ô atlas: thân mỗi người một ô 512, mặt và tóc ô 256 (bốn ô nhỏ trong một ô lớn).
func _layout(looks: Array) -> void:
	var big := []
	var small := []
	for look in looks:
		var b := _key(str(look.rb), "body", "")
		if b not in big:
			big.append(b)
		var head := str(look.get("head", look.rb))
		for part in ["head", "opacity"]:
			var k := _key(head, part, str(look.get("hair_tone", "")))
			if k not in small and (part != "opacity" or _file(head, part, "") != ""):
				small.append(k)
	var slot := 0
	for k in big:
		_tiles[k] = Rect2i((slot % 4) * 512, (slot / 4) * 512, 512, 512)
		slot += 1
	for j in small.size():
		var s2 := slot + j / 4
		var sub := j % 4
		_tiles[small[j]] = Rect2i((s2 % 4) * 512 + (sub % 2) * 256, (s2 / 4) * 512 + (sub / 2) * 256, 256, 256)
	assert(slot + ceili(small.size() / 4.0) <= 16, "atlas đầy")


## File ảnh của một phần (tóc bạc nếu có), "" nếu không có.
func _file(avatar: String, part: String, hair: String) -> String:
	var dir := "res://assets/rb/%s/" % avatar
	var names: Array = {"body": ["body_color.jpg"], "head": ["head_color.jpg"], "opacity": ["opacity_color.png"]}[part]
	if hair == "grey":
		names = {"body": ["body_color.jpg"], "head": ["head_grey.jpg", "head_color.jpg"], "opacity": ["opacity_grey.png", "opacity_color.png"]}[part]
	for n in names:
		if FileAccess.file_exists(dir + n):
			return dir + n
	return "" if part == "opacity" else dir + "body_color.jpg"


## Ghép atlas (thân, mặt kênh trong suốt đầy; tóc giữ kênh trong suốt), lưu atlas.png và vật liệu dùng chung.
func _make_atlas() -> void:
	var img := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.5, 0.5, 0.5, 0.0))
	for k in _tiles:
		var parts: PackedStringArray = str(k).split("|")
		var path := _file(parts[0], parts[1], parts[2])
		var src := Image.load_from_file(ProjectSettings.globalize_path(path))
		src.convert(Image.FORMAT_RGBA8)
		var r: Rect2i = _tiles[k]
		src.resize(r.size.x, r.size.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(src, Rect2i(Vector2i.ZERO, r.size), r.position)
	img.save_png(ProjectSettings.globalize_path(ATLAS))
	print("atlas: %d ô" % _tiles.size())


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
