extends SceneTree
## Nướng một khu thật thành map cố định cho truyện (người chơi không cần mạng):
##   Godot --headless --path . -s res://tools/bake_map.gd -- --id=q8_tau_hu --bbox=10.7462,106.6795,10.7540,106.6885 \
##       [--osm=/đường/dẫn/overpass.json] [--name="Quận 8, ven kênh Tàu Hủ"]
## Không có --osm thì tự hỏi Overpass (theo data/realmap.json). Open Buildings đọc theo byte từ data.source.coop.
## Ghép nhà như chế độ Dựng khu thật (OSM ưu tiên, bỏ nhà Open Buildings tin cậy dưới 0,7, trùng OSM, trên đường, trên nước),
## cắt theo khung, ghi data/maps/<id>.json. Đặt địa điểm truyện ở data/maps/<id>_story.json (viết tay).
## Máy đi qua proxy: đặt SSL_CERT_FILE tới chứng chỉ gốc của proxy.

const Geo := preload("res://scripts/realmap/geo.gd")
const Fetcher := preload("res://scripts/realmap/fetcher.gd")
const Fgb := preload("res://scripts/realmap/fgb_reader.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			args[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	if not args.has("id") or not args.has("bbox"):
		print("Cần --id=… và --bbox=nam,tây,bắc,đông")
		quit(1)
		return
	var bb: Array = Array(str(args.bbox).split(",")).map(func(v): return float(v))
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/realmap.json"))
	var fetcher := Fetcher.new(cfg)
	root.add_child(fetcher)
	var lat := (float(bb[0]) + float(bb[2])) / 2.0
	var lon := (float(bb[1]) + float(bb[3])) / 2.0
	var geo := Geo.new(lat, lon)
	var osm = null
	if args.has("osm"):
		osm = JSON.parse_string(FileAccess.get_file_as_string(str(args.osm)))
	else:
		var r: Dictionary = await fetcher.overpass(AreaData.query(bb))
		osm = r.json
	if not (osm is Dictionary):
		print("Không có dữ liệu OSM")
		quit(1)
		return
	var d := AreaData.new(geo, cfg)
	d.parse_osm(osm)
	print("OSM: %d đối tượng, %d nhà" % [(osm.elements as Array).size(), d.buildings.size()])
	var ob: Dictionary = cfg.openBuildings
	var reader := Fgb.new(str(ob.url).replace("{iso3}", "VNM"), fetcher, int(ob.get("mergeGapBytes", 65536)))
	if await reader.open():
		var feats: Array = await reader.read_bbox(float(bb[1]), float(bb[0]), float(bb[3]), float(bb[2]), 40000)
		d.merge_open_buildings(feats)
		print("Open Buildings: đọc %d byte, %d nhà; thống kê %s" % [reader.bytes_read, feats.size(), d.stats])
	else:
		print("Open Buildings lỗi: ", reader.error)
	var a := geo.to_local(float(bb[1]), float(bb[2]))
	var b := geo.to_local(float(bb[3]), float(bb[0]))
	var clip := PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)])
	d.clip_to(clip)
	var out := {"id": str(args.id), "name": str(args.get("name", args.id)), "center": [lat, lon], "bbox": bb,
		"clip": AreaData._flat(clip), "baked": Time.get_date_string_from_system(),
		"sources": "© Những người đóng góp OpenStreetMap (ODbL); Open Buildings: Google (CC BY 4.0), Microsoft (ODbL), bản gộp VIDA",
		"data": d.to_dict()}
	DirAccess.make_dir_recursive_absolute("res://data/maps")
	var path := "res://data/maps/%s.json" % str(args.id)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out))
	f.close()
	print("Đã ghi %s: %d nhà, %d đường, %d mặt nước, %d công viên, %d cây" % [path, d.buildings.size(), d.roads.size(), d.water.size(), d.parks.size(), d.trees.size()])
	quit()
