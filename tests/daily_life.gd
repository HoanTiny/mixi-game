extends SceneTree
## Nhịp sinh hoạt trên logic (lát cắt tuyến A, ngày 18): ăn, tắm, nghỉ, đi bộ khi đói, ngủ, ngủ ngoài đường, nạp bản lưu cũ.
## Chạy: Godot --headless --path . -s res://tests/daily_life.gd

const Logic = preload("res://scripts/game_logic.gd")
const Zones = preload("res://scripts/systems/map_manager.gd")
var failures := 0

func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fresh():
	var game = Logic.new()
	game.load_data()
	game.new_game("A")
	for i in 30:
		if game.s.queue.is_empty(): break
		game.resolve_first_available()
	expect(game.s.queue.is_empty(), "opening dialogue settles")
	return game

## Giờ trong ngày h (06:00 là đầu ngày), nhu cầu tính từ lúc đó.
func at(g, hour: float) -> void:
	g.s.used = hour - float(g.cfg.dayStart)
	g.s.needs_t = hour
	g._commit()

func _initialize() -> void:
	# A script error aborts _initialize before quit(); fail instead of idling forever.
	create_timer(60).timeout.connect(func(): push_error("Daily life: did not finish"); quit(1))
	var g = fresh()
	at(g, 11.0)
	var before := int(g.s.cash)
	g.s.needs.fed = 20.0
	var hungry = fresh()
	at(hungry, 11.0)
	hungry.s.needs.fed = 20.0
	hungry.walk(float(g.get_action("an_com").hours))
	g.do_action("an_com")
	expect(int(g.s.cash) == before - 30000, "Meal charged once")
	expect(is_equal_approx(g.need("fed"), hungry.need("fed") + 60.0), "Meal time consumes hunger before restoring food")
	g.s.needs.clean = 10.0
	g.do_action("tam_rua")
	expect(g.need("clean") > 45.0, "Bath restores cleanliness")
	g.s.fatigue = 75.0
	g.do_action("nghi")
	expect(float(g.s.fatigue) < 75, "Rest restores energy")
	g.s.cash = 0
	var time_before := float(g.s.used)
	g.do_action("an_com")
	expect(float(g.s.used) == time_before, "Cannot buy food without cash")
	g.do_action("tam_rua")
	expect(float(g.s.used) > time_before, "Bath is available without cash")
	g.s.needs.fed = 1.0
	g.s.fatigue = 0.0
	g.walk(1.0)
	expect(float(g.s.fatigue) > 0, "Hunger during travel causes fatigue")
	g.s.cash = 100000
	at(g, 10.5)
	expect(not g.action_status(g.get_action("banh_mi")).ok, "Breakfast stall respects closing hours")
	at(g, 22.0)
	g.s.fatigue = 70.0
	for k in ["fed", "clean", "mood"]: g.s.needs[k] = 70.0
	var recovery := float(g.night_preview().recover)
	g.finish_day()
	expect(g.day() == 19 and g.clock() == 6.0, "Sleep advances to next morning")
	expect(is_equal_approx(float(g.s.fatigue), 70.0 - recovery), "Sleep preview matches actual recovery")
	g = fresh()
	at(g, 22.0)
	g.s.fatigue = 70.0
	var bed = fresh()
	at(bed, 22.0)
	bed.s.fatigue = 70.0
	bed.finish_day()
	g.sleep_outside()
	expect(g.day() == 19 and is_equal_approx(float(g.s.fatigue), float(bed.s.fatigue) + float(g.cfg.fatigue.sleepOutside)), "Outside sleep costs extra fatigue over a bed")
	# Bản lưu cũ chưa có Tâm trạng: chỉ số mới bắt đầu từ mức đầu ván, tiền giữ nguyên.
	g.s.needs.erase("mood")
	before = int(g.s.cash)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(g.s))
	g = Logic.new()
	g.load_data()
	g.s = saved
	g.migrate_save()
	expect(int(g.s.cash) == before and is_equal_approx(g.need("mood"), float(g.cfg.needs.start.mood)), "Old save migration preserves economy and starts new needs")
	# A practical full day: breakfast at home, paid warehouse shift, dinner, wash, rest, bed.
	g = fresh()
	at(g, 6.0)
	g.do_action("com_voi_ba")
	expect(Zones.travel(g, "cho_dau_moi"), "travel to the warehouse district")
	var cash := int(g.s.cash)
	g.do_action("ca_kho")
	expect(int(g.s.cash) > cash, "warehouse shift pays")
	expect(Zones.travel(g, "phuc_tan"), "travel home")
	g.do_action("com_voi_ba")
	g.do_action("tam_rua")
	g.do_action("nghi")
	g.finish_day()
	expect(g.day() == 19 and g.need("fed") > 20 and float(g.s.fatigue) < 40, "Complete daily routine is sustainable")
	print("Daily life tests: ", "PASS" if failures == 0 else "FAIL (%d)" % failures)
	quit(1 if failures else 0)
