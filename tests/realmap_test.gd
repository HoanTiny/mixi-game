extends SceneTree
## Thử chế độ Dựng khu thật với máy chủ giả (không cần mạng ngoài):
##   python3 tests/realmap_fixtures/make_area.py <thư mục>   (tạo overpass.json, nominatim.json, ob/VNM.fgb; cần pyogrio)
##   python3 tests/realmap_fixtures/server.py <thư mục> 8765
##   Godot --headless --path . -s res://tests/realmap_test.gd
## Kiểm: luật hỏi thêm Overpass sau 7 s, nhà Open Buildings giữ lại đều đúng luật (không có nhà tin cậy thấp,
## trùng OSM, trên đường, trên nước), đường đi bộ không xuyên nhà.

const Geo := preload("res://scripts/realmap/geo.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene: Node3D = load("res://scenes/realmap.tscn").instantiate()
	# Cấu hình máy chủ giả và tên khu mẫu truyền qua đối số giả lập.
	scene.set_meta("test_args", true)
	root.add_child(scene)
	scene.cfg = scene._load_cfg()
	scene._deep_merge(scene.cfg, JSON.parse_string(FileAccess.get_file_as_string("res://tests/realmap_local.json")))
	scene.fetcher.cfg = scene.cfg
	scene._query.text = "Khu Mẫu"
	var t0 := Time.get_ticks_msec()
	await scene._auto()
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var fails := []
	if scene.builder == null:
		print("FAIL: chưa dựng được khu")
		quit(1)
		return
	var d = scene.builder.data
	var why := {}
	for b in d.buildings:
		if b.src == "ob":
			var w := str(b.props.get("test_why", "?"))
			why[w] = int(why.get(w, 0)) + 1
			if w != "keep":
				fails.append("giữ nhầm nhà OB loại " + w)
	# Đường đi bộ không đi qua ô nằm trong nhà.
	var a := Vector2(-150, -60)
	var b2 := Vector2(120, 30)
	var pth: PackedVector2Array = scene.builder.path(a, b2)
	if pth.size() < 2:
		fails.append("không tìm được đường đi")
	for i in pth.size() - 1:
		for k in 21:
			var p := pth[i].lerp(pth[i + 1], k / 20.0)
			for bd in d.buildings:
				if Geo.bounds(bd.poly).has_point(p) and Geometry2D.is_point_in_polygon(p, bd.poly) and _edge_dist(p, bd.poly) > 0.2:
					fails.append("đường đi xuyên nhà ở %s" % p)
					break
	print("thời gian %.1f s · OB giữ lại theo nhãn: %s · thống kê %s · đường đi %d điểm" % [secs, why, d.stats, pth.size()])
	if secs < 7.0:
		fails.append("không thấy chờ 7 s trước khi hỏi máy Overpass khác")
	print("OK" if fails.is_empty() else "FAIL: " + ", ".join(fails.slice(0, 5)))
	quit(0 if fails.is_empty() else 1)


static func _edge_dist(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		best = minf(best, Geo.seg_dist(p, poly[i], poly[(i + 1) % poly.size()]))
	return best
