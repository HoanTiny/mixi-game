extends "res://tests/opening_visual.gd"
## Âm thanh màn phố (data/sounds.json, scripts/world/audio.gd): mọi file nạp được, tiếng rao khớp người bán
## rong trong schedules.json; chưa có bản thu thì chỉ hiện chữ, có thì phát từ chính người bán và im khi đứng
## quá xa; trời mưa thì bước chân ướt.
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/street_sounds.gd -- --demo --demo-full
const Audio := preload("res://scripts/world/audio.gd")


func _paths(e: Dictionary) -> Array:
	return e.get("paths", [e.get("path", "")])


## Cấu hình và file, không cần màn phố. Tách riêng để các stream tạm được giải phóng trước khi thoát.
func check_config() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sounds.json"))
	var sched: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/schedules.json"))
	var vendors := {}
	for v in sched.vendors:
		vendors[str(v.id)] = v
	for group in ["ambience", "sfx"]:
		for k in cfg[group]:
			for p in _paths(cfg[group][k]):
				check(Audio._load(str(p), false) != null, "%s %s loads %s" % [group, k, p])
	for k in cfg.ambience:
		var bed = Audio._load(str(cfg.ambience[k].path), true)
		check(bed is AudioStreamOggVorbis and bed.loop, "ambience %s is a looping ogg" % k)
	for c in cfg.calls:
		var id := str(c.vendor)
		check(vendors.has(id), "call belongs to a scheduled vendor: " + id)
		for p in c.get("paths", []):
			check(Audio._load(str(p), false) is AudioStreamOggVorbis, "call %s is a light ogg: %s" % [id, p])
		check(not c.has("paths") or c.texts.size() == c.paths.size(), "one text per call recording: " + id)
		if vendors.has(id):
			var vh: Array = vendors[id].hours
			check(float(c.hours[0]) >= float(vh[0]) and float(c.hours[1]) <= float(vh[1]), "call hours inside vendor hours: " + id)
	check(cfg.calls.size() >= vendors.size() - 1, "every vendor but the balloon seller calls out")


func _call_labels(world) -> int:
	return world.get_children().filter(func(n): return n is Label3D and n.text.begins_with("♪")).size()


func run() -> void:
	if root.get_node("GameState")._persist:
		push_error("Street sounds: run with -- --demo --demo-full so the test cannot save over player progress")
		quit(1)
		return
	create_timer(90).timeout.connect(func(): push_error("Street sounds: did not finish"); quit(1))
	check_config()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await process_frame
	world.set_process(false)
	var g = world.game
	settle(g)
	g.cfg.idleMinutesPerSecond = 0.0
	g.s.used = 1.0
	g.s.today["rain"] = false
	g._commit()
	world.hud._close_tip()
	world.life._update_vendors(0.1)
	var node: Node3D = world.life.vendor_node("banh_mi")
	check(node != null, "bread vendor is out at 7:00")
	var call: Dictionary = {}
	for c in world.audio._calls:
		if str(c.cfg.vendor) == "banh_mi":
			call = c
	check(not call.is_empty() and call.variants.size() == 2 and call.variants.all(func(v): return v.stream == null and v.text != ""), "bread call: two lines of text, no synthetic voice")
	if node != null and not call.is_empty():
		world.player.position = node.position + Vector3(5, 0, 0)
		var before := _call_labels(world)
		world.audio._call(call)
		check(_call_labels(world) == before + 1, "call text floats over the vendor")
		check(node.find_children("*", "AudioStreamPlayer3D", false, false).is_empty(), "no voice without a recording")
		# Khi có bản thu thật: tiếng phát từ người bán, đi theo họ, xa thì im.
		var recorded := {"cfg": call.cfg, "variants": [{"stream": Audio._load("res://assets/sounds/step_1.ogg", false), "text": ""}]}
		world.audio._call(recorded)
		var players: Array = node.find_children("*", "AudioStreamPlayer3D", false, false)
		check(players.size() == 1 and players[0].playing, "recorded call plays from the vendor and follows them")
		if players.size() == 1:
			check(players[0].max_distance == Audio.CALL_RANGE and players[0].unit_size == Audio.CALL_UNIT, "call fades with distance")
			players[0].queue_free()
		await process_frame
		world.player.position = node.position + Vector3(Audio.CALL_RANGE + 20.0, 0, 0)
		world.audio._call(recorded)
		check(node.find_children("*", "AudioStreamPlayer3D", false, false).is_empty(), "no call heard from far away")
	g.s.used = 15.0
	g._commit()
	world.life._update_vendors(0.1)
	check(world.life.vendor_node("banh_mi") == null, "bread vendor gone at 21:00, call silent")
	var dry: Array = world.audio._sfx_streams.step
	var wet: Array = world.audio._sfx_streams.step_wet
	check(dry.size() == 4 and wet.size() == 4, "four footstep variants each")
	g.s.today["rain"] = true
	world.audio._step_t = 0.0
	world.audio.step(0.0)
	check(wet.has(world.audio._sfx.step_wet.stream), "rain plays wet footsteps")
	print("Street sounds: ", "OK" if failures == 0 else "%d failure(s)" % failures)
	quit(1 if failures else 0)
