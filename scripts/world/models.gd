extends RefCounted
## Nạp mô hình thật (.glb, .gltf, .tscn) theo data/models.json. Thiếu file thì trả về null
## để world.gd dựng khối hình tạm như cũ, nên game luôn chạy được dù chưa có mô hình nào.
##
## Mỗi mục: {"path": "res://assets/...", "rot": độ xoay quanh trục đứng, "fit": cách co giãn,
##           "size": kích thước đích (mét), "anims": {"idle": "...", "walk": "...", "sit": "..."}}
## fit: "height" khớp chiều cao, "length" khớp chiều dài (trục x), "width" khớp bề ngang nhà,
##      "none" giữ nguyên (nhân thêm "scale" nếu có).

var cfg: Dictionary = {}


func _init(path := "res://data/models.json") -> void:
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			cfg = data


## Mục cấu hình theo đường dẫn chấm, ví dụ "npc.coSau" hay "buildings.quan_com". Mảng thì chọn ngẫu nhiên theo rng.
func entry(key: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var v = cfg
	for part in key.split("."):
		if not (v is Dictionary) or not v.has(part):
			return {}
		v = v[part]
	if v is Array:
		var ok: Array = v.filter(func(e) -> bool: return e is Dictionary and ResourceLoader.exists(str(e.get("path", ""))))
		if ok.is_empty():
			return {}
		return ok[rng.randi() % ok.size()] if rng else ok[0]
	return v if v is Dictionary else {}


func has(key: String) -> bool:
	var e := entry(key)
	return not e.is_empty() and ResourceLoader.exists(str(e.get("path", "")))


## Dựng mô hình đã co giãn. Gốc tọa độ nằm ở giữa đáy mô hình; với nhà thì ở giữa mép trước.
## Trả về null nếu chưa có file.
func spawn(key: String, rng: RandomNumberGenerator = null, target := Vector3.ZERO) -> Node3D:
	var e := entry(key, rng)
	var path := str(e.get("path", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var scene = load(path)
	if not (scene is PackedScene):
		push_warning("Không phải mô hình: " + path)
		return null
	var model: Node3D = scene.instantiate()
	model.rotation.y = deg_to_rad(float(e.get("rot", 0)))
	var pivot := Node3D.new()
	pivot.name = "Model"
	pivot.add_child(model)

	var box := _bounds(model, model.transform)
	var size: Vector3 = target
	if e.has("size"):
		size = Vector3(e.size[0], e.size[1], e.size[2]) if e.size is Array else Vector3.ONE * float(e.size)
	var k := float(e.get("scale", 1.0))
	if box.size != Vector3.ZERO:
		match str(e.get("fit", "none")):
			"height":
				k *= size.y / box.size.y if size.y > 0.0 else 1.0
			"length":
				k *= size.x / box.size.x if size.x > 0.0 else 1.0
			"width":
				# Khớp bề ngang mặt tiền; phía sau nhà là đất trống nên sâu hơn lô đất cũng được.
				k *= size.x / box.size.x if size.x > 0.0 else 1.0
	model.scale *= k
	box = _bounds(model, model.transform)
	# Đặt đáy chạm đất, giữa theo trục x; nhà thì mép trước nằm ở z = 0, người và xe thì giữa theo z.
	var front := str(e.get("fit", "")) == "width"
	model.position -= Vector3(box.get_center().x, box.position.y, box.end.z if front else box.get_center().z)
	var anims: Dictionary = e.get("anims", {})
	pivot.set_meta("anims", anims)
	pivot.set_meta("height", box.size.y)
	var player := _find_player(model)
	if player:
		pivot.set_meta("player", player)
		_loop(player, anims)
		play(pivot, "idle")
	return pivot


## Phát hoạt cảnh theo vai ("idle", "walk", "sit"). Không có thì thôi.
static func play(pivot: Node, role: String) -> bool:
	if pivot == null or not pivot.has_meta("player"):
		return false
	var p: AnimationPlayer = pivot.get_meta("player")
	var name := str(pivot.get_meta("anims", {}).get(role, role))
	if not p.has_animation(name):
		return false
	if p.current_animation != name:
		p.play(name, 0.2)
	return true


static func has_anim(pivot: Node) -> bool:
	return pivot != null and pivot.has_meta("player")


static func _find_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var p := _find_player(c)
		if p:
			return p
	return null


## Bật lặp cho hoạt cảnh đứng, đi, ngồi (file glb thường để chế độ chạy một lần).
static func _loop(p: AnimationPlayer, anims: Dictionary) -> void:
	for role in ["idle", "walk", "sit"]:
		var name := str(anims.get(role, role))
		if p.has_animation(name):
			p.get_animation(name).loop_mode = Animation.LOOP_LINEAR


## Hộp bao của mọi lưới bên dưới n, tính trong hệ tọa độ cha của n (xform là transform của n).
static func _bounds(n: Node, xform: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	if n is GeometryInstance3D:
		out = xform * n.get_aabb()
		first = false
	for c in n.get_children():
		if c is Node3D:
			var b := _bounds(c, xform * c.transform)
			if b.size == Vector3.ZERO and b.position == Vector3.ZERO:
				continue
			out = b if first else out.merge(b)
			first = false
	return out
