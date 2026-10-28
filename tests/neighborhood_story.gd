extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures+=1
		push_error(message)

func settle(g) -> void:
	var guard := 0
	while not g.s.queue.is_empty() and guard<30:
		guard+=1
		g.resolve_first_available()
	check(guard<30,"dialogue queue terminates")

func fresh():
	var g = Logic.new()
	g.load_data()
	g.new_game("full")
	settle(g)
	return g

func day2(choice := 1):
	var g = fresh()
	g.finish_day()
	settle(g)
	g.open_scene("ngay2")
	g.resolve_choice(choice)
	return g

func reload_game(g):
	var copy = Logic.new()
	copy.load_data()
	copy.s=JSON.parse_string(JSON.stringify(g.s))
	copy.migrate_save()
	return copy

func street(g, action: String, loc := "tiem_sau") -> void:
	check(g.Street.act(g,loc,action),"Street action "+action+" at "+str(g.clock()))

func bench(g) -> void:
	var token := str(g.s.street.accepted_day)+":"+str(int(g.s.street.job.kind))
	check(g.Street.bench_action(g,"install",0,token)!="","cannot install before removal")
	check(g.Street.bench_action(g,"remove",0,token)=="","remove component")
	check(g.Street.bench_action(g,"install",1,token)!="","wrong part rejected")
	check(g.Street.bench_action(g,"install",0,token)=="","install correct component")
	check(g.Street.bench_action(g,"screw",0,token)=="","first screw")
	check(g.Street.bench_action(g,"screw",0,token)!="","same screw cannot advance twice")
	check(g.Street.bench_action(g,"screw",1,token)=="","complete assembly")
	check(g.s.street.job.stage=="test","assembly needs test")

func _initialize() -> void:
	var g = fresh()
	check(g.neighborhood_target().action=="pho_chao_son","day1 has workshop introduction")
	# Late arrival retains the ordinary daily-order path; the early fan is covered separately.
	g.s.used=5.0
	g.do_action("pho_chao_son")
	check(g.clock()>=8 and g.s.neighborhood.stage=="work","introduction waits until shop opens")
	street(g,"accept")
	check(g.is_hidden(g.get_action("sua_do_le")),"parallel repair menu hidden while order active")
	street(g,"inspect")
	street(g,"shop_part")
	bench(g)
	street(g,"test")
	street(g,"deliver")
	check(g.s.neighborhood.stage=="meal","income leads to meal suggestion")
	check(g.neighborhood_target().optional,"meal is optional")
	g.do_action("an_com")
	check(g.s.neighborhood.stage=="home","meal leads home")
	g=reload_game(g)
	check(g.neighborhood_target().action=="pho_ban_thu_chi","home followup survives save")
	g.do_action("pho_ban_thu_chi")
	check(g.s.neighborhood.stage=="done","day1 loop has a conclusion")
	var cash := int(g.s.cash)
	check(not g.Street.act(g,"tiem_sau","deliver"),"completed daily job cannot pay again")
	check(g.s.cash==cash,"no duplicate daily payment")

	# Choosing another job and going home hungry/cashless must not require repair.
	g=fresh()
	g.do_action("ca_phu_quan")
	check(g.s.neighborhood.stage=="meal","alternative livelihood enters same followup")
	g.s.cash=0
	check(g.neighborhood_target().action=="com_voi_ba","cashless player has free home meal")
	g.do_action("com_voi_ba")
	g.do_action("pho_ban_thu_chi")
	check(g.s.neighborhood.stage=="done","alternative livelihood completes onboarding")
	g=fresh()
	g.s.used=2
	street(g,"accept")
	street(g,"cancel")
	check(g.neighborhood_target().action=="ca_phu_quan","cancelled first order points to other available work")
	g.s.fatigue=95
	check(g.neighborhood_target().action=="nghi","exhausted newcomer gets a rest option")

	# Narrative fan shares the real bench, delivers only at the market and pays once.
	g=day2(2)
	check(g.quest_state("quat_trai_cay")=="active","day2 starts fan quest")
	check(g.s.street.job.quest_id=="quat_trai_cay","narrative owns the repair order")
	check(g.quest_step("quat_trai_cay").kind=="repair","no old menu-only diagnosis")
	check(g.quest_target("quat_trai_cay").loc=="tiem_sau","diagnosis target is workshop")
	street(g,"inspect")
	check(g.quest_target("quat_trai_cay").loc=="cho_cau_nho","missing part target is market")
	var before := int(g.s.cash)
	street(g,"part_0","cho_cau_nho")
	g=reload_game(g)
	check(g.quest_target("quat_trai_cay").loc=="tiem_sau","owned part sends player back to bench")
	street(g,"own_part")
	bench(g)
	g=reload_game(g)
	check(g.s.street.job.stage=="test","assembled fan survives reload")
	street(g,"test")
	check(g.s.street.job.is_empty() and g.item_count("quat")==1,"tested fan becomes delivery item once")
	check(g.quest_target("quat_trai_cay").loc=="cho_cau_nho","customer delivery is market")
	check(not g.Street.act(g,"tiem_sau","accept"),"no competing new order before fan delivery")
	g=reload_game(g)
	g.quest_visit("quat_trai_cay")
	check(g.quest_state("quat_trai_cay")=="done" and g.s.flags.get("quatTot",false),"fan story finishes after real delivery")
	check(g.s.cash==before+90000,"one120k narrative reward less30k purchased part")
	check(g.s.street.xp==1 and g.s.street.completed==1,"narrative gives one skill completion")
	check(g.s.promises.filter(func(p): return p.id=="quat_truoc_trua")[0].status=="done","honest deadline promise preserved")
	cash=int(g.s.cash)
	settle(g)
	g.quest_visit("quat_trai_cay")
	g._quest_finish("quat_trai_cay",true)
	check(g.s.cash==cash and g.s.street.xp==1,"no repeat narrative reward or xp")
	g.open_scene("ngay2")
	check(g.s.queue.is_empty(),"resolved day2 scene cannot reopen for diagnosis pay")

	# No money for a component still offers a viable choice, settled after pay.
	g=day2()
	g.s.cash=0
	street(g,"inspect")
	street(g,"credit_part")
	street(g,"fix_cap")
	street(g,"test")
	g.quest_visit("quat_trai_cay")
	check(g.s.cash==70000 and not g.s.street.has("story_part_credit"),"part advance deducted once from120k")

	# Missing the deadline fails cleanly and keeps future jobs available.
	g=day2(2)
	g.s.used=12.1-float(g.cfg.dayStart)
	g._commit()
	check(g.quest_state("quat_trai_cay")=="failed" and g.s.street.job.is_empty(),"late fan fails and releases bench")
	settle(g)
	g.finish_day()
	settle(g)
	g.s.used=2
	check(g.Street.act(g,"tiem_sau","accept"),"missed fan does not lock future repair jobs")

	# Legacy completed-repair saves do not lose their fan or receive another one.
	g=day2()
	g.s.street.job={}
	g.s.quests.quat_trai_cay.step=1
	g.s.qitems.quat=1
	g=reload_game(g)
	check(g.s.street.job.is_empty() and g.quest_step("quat_trai_cay").kind=="visit","legacy delivery step preserved")
	g.quest_visit("quat_trai_cay")
	check(g.quest_state("quat_trai_cay")=="done","legacy fan delivers")

	g=fresh()
	g.s.used=2
	street(g,"accept")
	street(g,"inspect")
	g.s.day=2
	g.s.quests.quat_trai_cay={"state":"active","step":1,"day":2,"deadline":63.0,"progress":0,"misses":0}
	g.s.qitems.quat=1
	g=reload_game(g)
	check(g.s.street.job.is_empty() and g.s.street.paused_job.stage=="part","legacy daily order pauses while ready fan awaits delivery")
	g.quest_visit("quat_trai_cay")
	check(g.s.street.job.stage=="part","legacy daily order resumes after market handoff")

	# An unfinished paid ordinary order is preserved while story work takes priority.
	g=fresh()
	g.s.used=2
	street(g,"accept")
	street(g,"inspect")
	street(g,"shop_part")
	g.finish_day()
	settle(g)
	g.open_scene("ngay2")
	g.resolve_choice(1)
	check(g.s.street.paused_job.stage=="repair","unfinished daily assembly is paused intact")
	g=reload_game(g)
	street(g,"cancel")
	check(g.s.street.job.stage=="repair" and int(g.s.street.job.due)==3,"paused daily job restored with extended due date")
	check(not g.s.street.has("paused_job"),"restored order no longer has duplicate backup")

	# Day3 selection books a real visit; no virtual travel debit or seen flag.
	for choice in 3:
		g=fresh()
		for day in 2:
			g.finish_day()
			settle(g)
		g.open_scene("ngay3")
		var clock_before: float = g.clock()
		g.resolve_choice(choice)
		check(g.housing().seen.is_empty(),"day3 menu cannot mark visited")
		check(is_equal_approx(g.clock(),clock_before),"day3 selection does not charge journey time")
		g=reload_game(g)
		var visit: Dictionary = g.housing().visit_target
		var target: Dictionary = g.neighborhood_target()
		check(target.action==visit.action and not target.optional,"booked visit stays primary after reload")
		g.do_action(str(visit.action))
		check(g.housing().seen.has(visit.place) and not g.housing().has("visit_target"),"only destination inspection completes visit")
		check(g.neighborhood_target().action=="anh_cho_ba","room inspection leads back to family")
		g.do_action("anh_cho_ba")
		check(not g.housing().get("visit_return",false),"family review completes housing followup")
		for day in range(4,8):
			g.finish_day()
			settle(g)
		check(g.day()==7 and not g.is_over(),"first week remains playable after housing branch")

	print("Neighborhood story: ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
