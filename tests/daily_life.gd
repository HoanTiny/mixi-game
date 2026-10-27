extends SceneTree

const Logic = preload("res://scripts/game_logic.gd")
var failures := 0

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var game = Logic.new()
	game.load_data()
	game.new_game("A")
	while not game.s.queue.is_empty():
		game.resolve_first_available()
	return game

func _initialize() -> void:
	var g = fresh()
	var before := int(g.s.cash)
	g.s.satiety = 20.0
	g.do_action("com_phan")
	expect(int(g.s.cash) == before - 35000, "Meal charged once")
	expect(is_equal_approx(float(g.s.satiety), 83.0), "Meal time consumes hunger before restoring food")
	g.s.hygiene = 10.0
	g.do_action("tam")
	expect(float(g.s.hygiene) > 85, "Bath restores cleanliness")
	g.s.fatigue = 75.0
	g.do_action("nghi")
	expect(float(g.s.fatigue) < 75, "Rest restores energy")
	g.s.cash = 0
	var time_before := float(g.s.used)
	g.do_action("com_phan")
	expect(float(g.s.used) == time_before, "Cannot buy food without cash")
	g.do_action("tam")
	expect(float(g.s.used) > time_before, "Bath is available without cash")
	g.s.satiety = 1.0
	g.s.fatigue = 0.0
	g.walk(1.0)
	expect(float(g.s.fatigue) > 0, "Hunger during travel causes fatigue")
	g.s.used = 15.8
	expect(not g.action_status(g.get_action("com_phan")).ok, "Meals respect closing hours")
	g.s.used = 16.0
	g.s.fatigue = 70.0
	g.s.satiety = 70.0
	g.s.hygiene = 70.0
	var recovery := float(g.night_preview().recover)
	g.finish_day()
	expect(g.day() == 19 and g.clock() == 6.0, "Sleep advances to next morning")
	expect(is_equal_approx(float(g.s.fatigue), 70.0 - recovery), "Sleep preview matches actual recovery")
	g = fresh()
	g.s.used = 16.0
	g.s.fatigue = 70.0
	g.sleep_outside()
	expect(float(g.s.fatigue) == 85.0, "Outside sleep does not receive bed recovery")
	g.s.erase("satiety")
	g.s.erase("hygiene")
	g.s.erase("mood")
	before = int(g.s.cash)
	g.migrate_save()
	expect(g.s.has("satiety") and int(g.s.cash) == before, "Old save migration preserves economy")
	# A practical full day: breakfast, paid shift, dinner, wash, rest, bed.
	g = fresh()
	g.do_action("com_voi_ba")
	g.do_action("ca_kho")
	g.do_action("com_voi_ba")
	g.do_action("tam")
	g.do_action("nghi")
	g.finish_day()
	expect(g.day() == 19 and float(g.s.satiety) > 20 and float(g.s.fatigue) < 40, "Complete daily routine is sustainable")
	print("Daily life tests: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
