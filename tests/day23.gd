extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
const Guide := preload("res://scripts/quest_guide.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func settle(g) -> void:
	for i in 40:
		if g.s.queue.is_empty(): return
		g.resolve_first_available()
	check(false,"queue terminates")
func fresh():
	var g=Logic.new()
	g.load_data(); g.new_game("full"); settle(g)
	g.s.flags.opening_fan_met=true
	g.s.scenes_done.append("ngay2")
	g.s.day=2; g.s.used=2.0
	g._commit()
	return g
func reload_game(g):
	var copy=Logic.new()
	copy.load_data()
	copy.s=JSON.parse_string(JSON.stringify(g.s))
	copy.migrate_save()
	return copy
func act(g, id: String, loc := "tiem_sau") -> void:
	check(g.Day23.act(g,loc,id),"action succeeds "+id)
func clock(g, hour: float) -> void:
	g.s.used=hour-6.0
	g._commit()
func measured(g) -> void:
	act(g,"arc_accept")
	check(not g.Day23.act(g,"cho_cau_nho","arc_buy_part"),"cannot buy before diagnosis/approval")
	for part in ["wire","heater","fuse"]: act(g,"arc_measure_"+part)
	var now: float=g.now_abs()
	act(g,"arc_diagnose_heater")
	check(g.s.street.job.stage=="diagnose" and g.now_abs()>now,"wrong diagnosis takes time, does not buy")
	act(g,"arc_diagnose_fuse")
func bench(g) -> void:
	var token := str(g.s.street.accepted_day)+":1"
	for step in [["remove",0],["install",1],["screw",0],["screw",1]]:
		check(g.Street.bench_action(g,step[0],step[1],token)=="","saved 3D bench "+str(step))
	check(g.s.street.job.stage=="test","bench completed")
	check(g.Street.act(g,"tiem_sau","test"),"bench test dispatches into story")
func _initialize() -> void:
	for used in [false,true]:
		var g=fresh()
		act(g,"arc_meet_late" if used else "arc_meet_noon","xom_bo_me")
		var cash: int=g.s.cash
		measured(g)
		act(g,"arc_quote_used" if used else "arc_quote_new")
		check(g.s.street.job.stage=="approval","must wait for consent")
		check(not g.Day23.act(g,"cho_cau_nho","arc_buy_part"),"no spending before consent")
		g=reload_game(g)
		act(g,"arc_wait_reply")
		act(g,"arc_buy_part","cho_cau_nho")
		g.elapse(0.25); g._commit() # walking back
		if used:
			check(g.s.street.job.stage=="check_part","used stock requires checking")
			act(g,"arc_check_used")
			act(g,"arc_use_216")
			check(g.s.street.job.stage=="used_choice","wrong safety rating rejected")
			g=reload_game(g)
			act(g,"arc_use_184")
			act(g,"arc_delay")
		bench(g)
		check(g.s.flags.day23_carry_kettle,"tested kettle appears in hands")
		if not used:
			act(g,"arc_wait_linh","hem_dua")
			act(g,"arc_attend","hem_dua")
		g.elapse(0.25); g._commit()
		act(g,"arc_deliver","cho_cau_nho")
		check(g.s.cash==cash+(165000 if used else 155000),"agreed quote minus actual material costs")
		var earned: int=g.s.cash
		check(not g.Day23.act(g,"cho_cau_nho","arc_deliver") and g.s.cash==earned,"cannot collect twice")
		if used:
			act(g,"arc_wait_linh","hem_dua")
			act(g,"arc_attend","hem_dua")
		check(g.s.day23.meeting=="attended","two schedules can keep both commitments")
		check(g.s.flags.day23_reliable and not g.s.flags.has("day23_carry_kettle"),"reliable referral and carry cleared")
		g.finish_day(); settle(g)
		check(g.day()==3 and not g.scenes_today().has("ngay3"),"no duplicate housing introduction")
		clock(g,17.5)
		act(g,"arc_debrief","com_hanh")
		check(g.current_event().id=="day23_evening","outcome becomes an actual conversation")
		check(not "{" in g.fill(g.current_event().text),"outcome text is readable")
		g.resolve_choice(1)
		check(g.housing().visit_target.place=="cau_tre","player chooses tomorrow's room visit")
		g=reload_game(g)
		check(g.s.day23.debrief,"debrief survives reload")
		check(not g.Day23.act(g,"com_hanh","arc_debrief"),"no duplicate debrief")
	var g=fresh()
	act(g,"arc_meet_noon","xom_bo_me")
	act(g,"arc_move_meeting","tiem_sau")
	check(not g.Day23.act(g,"tiem_sau","arc_move_meeting"),"reschedule only once")
	var rep: float=g.s.rep.LINH
	clock(g,16.3)
	check(g.s.day23.meeting=="solo" and g.s.rep.LINH==rep-5,"Linh goes without An after grace period")
	g._commit(); g=reload_game(g); g._commit()
	check(g.s.rep.LINH==rep-5,"no repeated missed-appointment penalty")
	act(g,"arc_apology","xom_bo_me")
	check(g.housing().seen.has("hem_dua") and g.s.rep.LINH==rep-3,"repair relationship without erasing consequence")
	g=fresh()
	measured(g); act(g,"arc_quote_new"); act(g,"arc_wait_reply")
	g.s.cash=0; act(g,"arc_credit_part"); act(g,"arc_cancel")
	check(g.s.day23.order=="cancelled" and g.s.payables.any(func(p): return p.id=="day23_parts" and p.amount==45000),"cancel retains real debt")
	g=fresh()
	act(g,"arc_decline")
	act(g,"arc_solo","xom_bo_me")
	check(g.s.day23.order=="declined" and g.s.day23.meeting=="solo","declining both leaves other jobs available")
	g=fresh(); measured(g); act(g,"arc_quote_new"); act(g,"arc_wait_reply"); act(g,"arc_shop_part"); bench(g)
	clock(g,15.0)
	var late_cash: int=g.s.cash
	act(g,"arc_deliver","cho_cau_nho")
	check(g.s.cash==late_cash+144000 and not g.s.flags.day23_reliable,"unannounced late return loses 20% and referral")
	g.s.day=3; clock(g,17.5); act(g,"arc_debrief","com_hanh")
	check("chưa giới thiệu" in g.fill(g.current_event().text),"conversation remembers late delivery")
	var old=Logic.new(); old.load_data(); old.new_game("full"); settle(old)
	old.s.day=3; old.migrate_save()
	check(not old.s.has("day23"),"legacy saves retain original chapter flow")
	g=fresh(); measured(g); act(g,"arc_quote_new"); act(g,"arc_wait_reply")
	g.s.cash=0; act(g,"arc_credit_part")
	g.s.day=3; g.s.used=12; g._commit()
	g.finish_day(); settle(g)
	check(g.s.street.job.is_empty() and g.s.day23.order=="cancelled","unfinished order handed back after day three")
	check(g.s.payables.any(func(p): return p.id=="day23_parts"),"takeover does not erase material debt")
	print("Day 2–3: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
