extends SceneTree
const Logic = preload("res://scripts/game_logic.gd")
const Scheduler = preload("res://scripts/systems/EventSchedulerSystem.gd")
const Rel = preload("res://scripts/systems/relationships.gd")
var failures := 0

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1

func at(g, day: int, hour: float) -> void:
	g.s.day = day
	g.s.used = hour-float(g.cfg.dayStart)
	g.s.queue.clear()
	Scheduler.tick(g)

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var g = Logic.new()
	g.load_data()
	g.new_game("full")
	at(g, 2, 5.99)
	var old_day = g.s.scheduler.offer_day
	check(old_day != 2, "no refresh before 06:00")
	at(g, 2, 6)
	check(g.s.scheduler.offer_day == 2, "refresh at 06:00")
	var offers: Dictionary = g.s.scheduler.offers.duplicate()
	check(offers.values().filter(func(v): return v > 0).size() == 2, "two distinct bonus jobs")
	at(g, 2, 12)
	check(offers == g.s.scheduler.offers, "offers stable throughout day")
	var restored = Logic.new()
	restored.load_data()
	restored.s = JSON.parse_string(JSON.stringify(g.s))
	restored.migrate_save()
	check(offers.keys().all(func(k): return int(restored.s.scheduler.offers[k]) == int(offers[k])), "offers survive save round-trip")
	check(restored.get_action("daily_carry_bricks").get("pay",0)>0, "loading a save immediately restores job pay")
	for hour in [17.99,18.0,22.99,23.0]:
		at(g,2,hour)
		check(Scheduler.night_open(g) == (hour >= 18 and hour < 23), "night boundary "+str(hour))
	check(g.get_action("scheduler_night_sell").hours == g.cfg.commerce.vending.hours, "selling simulation and clock use same duration")
	at(g,4,6)
	check(not Scheduler.job_lock(g,g.get_action("daily_carry_bricks")).is_empty(), "construction closed before story seen")
	check(not Scheduler.job_lock(g,g.get_action("be_gach")).is_empty(), "legacy construction job also closed")
	check(not Scheduler.enter_zone(g,"Zone3_IndustrialAndLogistics"), "story waits until 07:00")
	at(g,4,7)
	check(not Scheduler.enter_zone(g,"Zone1_SlumAndNightMarket"), "wrong zone does not trigger")
	check(Scheduler.enter_zone(g,"Zone3_IndustrialAndLogistics"), "correct day zone hour triggers")
	check(not g.s.flags.get("wholesale_scrap_trading",false), "effects await choice")
	g.resolve_choice(0)
	check(g.s.flags.get("wholesale_scrap_trading",false), "story unlock effect applied")
	g.s.queue.clear()
	check(not Scheduler.enter_zone(g,"Zone3_IndustrialAndLogistics"), "story cannot repeat")
	at(g,5,7)
	check(Scheduler.job_lock(g,g.get_action("daily_carry_bricks")).is_empty(), "construction reopens next day")
	at(g,37,8)
	check(Scheduler.enter_zone(g,"Zone4_CommercialDistrict"), "Han story triggers")
	g.resolve_choice(0)
	check(not Rel.message_def(g,"HAN","scheduler_contact_HAN").is_empty(), "Han contact has real phone content")
	check(g.s.rel.inbox.any(func(m): return m.msg == "scheduler_contact_HAN"), "Han phone message delivered")
	at(g,10,12)
	check(Scheduler.enter_zone(g,"Zone1_SlumAndNightMarket"), "scam story triggers")
	var event: Dictionary = g.current_event()
	g.s.attr.per.lv=1
	check(not g.check(event.choices[0].require).is_empty(), "reporting scam requires perception level two")
	g.s.attr.per.lv=2
	check(g.check(event.choices[0].require).is_empty(), "reporting unlocks at perception two")
	g.resolve_choice(1)
	at(g,57,6)
	check(Scheduler.enter_zone(g,"Zone4_CommercialDistrict"), "flower shop robbery triggers")
	g.resolve_choice(0)
	check(g.s.flags.get("scheduler_confession",false), "confession flag applied")
	var worker = Logic.new()
	worker.load_data()
	worker.new_game("full")
	at(worker,2,6)
	var points: int = worker.s.scheduler.skill_points
	worker.do_action("daily_handout_flyers")
	check(worker.today_count("daily_handout_flyers")==1, "scheduled job completes through existing action pipeline")
	check(worker.s.scheduler.skill_points==points+1, "job skill point awarded once")
	worker.s.queue.clear()
	worker.do_action("daily_handout_flyers")
	check(worker.s.scheduler.skill_points==points+1, "per-day job cannot award twice")
	print("Scheduler failures: ", failures)
	quit(1 if failures else 0)
