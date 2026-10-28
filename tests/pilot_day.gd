extends SceneTree
## Focused current-data logic smoke, not a work-minigame playtest.
## godot --headless --path . -s res://tests/pilot_day.gd -- --demo --street-demo
const Logic = preload("res://scripts/game_logic.gd")
const City = preload("res://scripts/world/real_city.gd")
var errors: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	if not ok: errors.append(label)
func digest(path: String) -> String:
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "absent"
func run() -> void:
	if "--demo" not in OS.get_cmdline_user_args():
		push_error("Run this isolated smoke with --demo")
		quit(1)
		return
	var saves := {}
	for path in ["user://save.json", "user://notes.json"]: saves[path] = digest(path)
	check(not root.get_node("GameState")._persist, "demo disables save persistence")
	var g = Logic.new()
	g.load_data()
	g.new_game("B")
	var guard := 0
	while not g.s.queue.is_empty() and guard < 20:
		g.resolve_first_available()
		guard += 1
	check(g.day() == 18, "demo slice begins day18")
	check(g.s.queue.is_empty(), "opening choices resolved")
	var actions_before := JSON.stringify(g.cfg.actions)
	var city = City.new("hn_pho_co")
	for id in ["com_hanh", "tiem_sau", "xom_bo_me"]:
		check(city.locs.has(id), "original location id: " + id)
	g.s.needs.fed = 20.0
	g.s.needs.clean = 10.0
	g.s.fatigue = 30.0
	var cash := int(g.s.cash)
	var used := float(g.s.used)
	check(g.action_status(g.get_action("an_com")).ok, "meal available")
	g.do_action("an_com")
	check(int(g.s.cash) == cash - 30000, "meal costs30000 exactly")
	check(float(g.s.needs.fed) > 20.0 and float(g.s.used) > used, "meal restores hunger and advances time")
	check(g.action_loc(g.get_action("an_com")) == "com_hanh", "meal location id")
	cash = int(g.s.cash)
	used = float(g.s.used)
	var tired := float(g.s.fatigue)
	check(g.action_status(g.get_action("sua_do_le")).ok, "repair work available")
	g.do_action("sua_do_le")
	check(int(g.s.cash) > cash and float(g.s.used) > used, "work pays and advances time")
	check(float(g.s.fatigue) > tired and g.count("sua_do_le") == 1, "work increases fatigue and counts once")
	check(g.action_loc(g.get_action("sua_do_le")) == "tiem_sau", "work location id")
	check(g.action_status(g.get_action("tam_rua")).ok, "wash available")
	g.do_action("tam_rua")
	check(float(g.s.needs.clean) > 90.0 and g.count("tam_rua") == 1, "wash restores cleanliness")
	tired = float(g.s.fatigue)
	check(g.action_status(g.get_action("nghi")).ok, "rest available")
	g.do_action("nghi")
	check(float(g.s.fatigue) < tired and bool(g.s.today.get("rested", false)), "rest reduces fatigue and records rest")
	check(JSON.stringify(g.cfg.actions) == actions_before, "action definitions unchanged")
	for path in saves: check(digest(path) == saves[path], "save untouched: " + path)
	print("CURRENT_LIFE_SMOKE day=", g.day(), " clock=", g.clock(), " cash=", g.s.cash, " fatigue=", g.s.fatigue, " needs=", g.s.needs, " failures=", errors)
	quit(0 if errors.is_empty() else 1)
