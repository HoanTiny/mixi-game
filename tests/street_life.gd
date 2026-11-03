extends SceneTree
const Logic = preload("res://scripts/game_logic.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func fresh():
	var g = Logic.new()
	g.load_data()
	g.new_pilot()
	return g
func act(g, id: String, loc := "tiem_sau") -> void:
	check(g.Street.act(g,loc,id),"Action failed: " + id + " at " + str(g.clock()))
func repair(g, market := false) -> void:
	act(g,"accept")
	act(g,"inspect")
	if market:
		act(g,"part_"+str(g.s.street.job.kind),"cho_cau_nho")
		act(g,"own_part")
	else: act(g,"shop_part")
	act(g,"fix_cap" if int(g.s.street.job.kind)==0 else "fix_fuse")
	act(g,"test")
	act(g,"deliver")
func _initialize() -> void:
	var g = fresh()
	check(g.Street.Quest.active(g).location=="tiem_sau","First quest leads to shop")
	check(g.day()==1 and g.s.queue.is_empty() and g.s.receivables.is_empty(),"Pilot setup")
	check(not g.Street.act(g,"tiem_sau","accept"),"Shop closed at 6")
	g.s.used = 2.0
	act(g,"accept")
	check(not g.Street.act(g,"tiem_sau","deliver"),"Cannot skip repair")
	act(g,"inspect")
	g.s.cash = 0
	check(not g.Street.act(g,"tiem_sau","shop_part"),"Cannot buy without money")
	g.s.cash = 180000
	act(g,"shop_part")
	act(g,"fix_fuse")
	check(g.s.street.job.stage=="repair","Wrong diagnosis must not finish")
	act(g,"fix_cap")
	act(g,"test")
	act(g,"deliver")
	check(g.s.cash==360000 and g.s.street.xp==1,"Correct job payout")
	check(g.Street.Quest.active(g).is_empty(),"First quest completes on real delivery")
	check(g.s.quest_notice.title.begins_with("Đã trả món"),"Delivery notification")
	check(not g.Street.act(g,"tiem_sau","deliver"),"No double payout")
	check(not g.Street.act(g,"tiem_sau","accept"),"Daily order cap")
	var loaded = Logic.new()
	loaded.load_data()
	loaded.s = JSON.parse_string(JSON.stringify(g.s))
	loaded.migrate_save()
	check(int(loaded.s.street.xp)==1,"Progress saved")
	for mode in ["repair","mixed"]:
		g = fresh()
		for day in range(1,6):
			g.do_action("com_voi_ba")
			g.s.used = maxf(g.s.used,2.0)
			repair(g,mode=="mixed")
			if mode=="mixed" and g.clock()<=12:
				g.s.used = maxf(g.s.used,4.0)
				act(g,"shift","com_hanh")
			g.do_action("com_phan")
			g.do_action("tam")
			g.s.used = maxf(g.s.used,12.0)
			act(g,"help","xom_bo_me")
			g.finish_day()
			while not g.s.queue.is_empty() and not g.is_over(): g.resolve_first_available()
		check(g.is_over() and g.day()==5 and g.s.history.size()==5,"Five-day finish")
		check(g.s.cash>=500000,"Savings goal reachable: "+mode+" "+str(g.s.cash))
		check(g.s.linh.decision=="xa","Linh autonomous decision")
		print(mode," five days: cash=",g.s.cash," fatigue=",g.s.fatigue," completed=",g.s.street.completed)
	g = fresh()
	g.s.used=2.0
	act(g,"accept")
	act(g,"inspect")
	act(g,"shop_part")
	act(g,"fix_cap")
	act(g,"test")
	g.s.day=3
	act(g,"deliver")
	check(g.s.cash==314000,"Late delivery pays 80 percent")
	check(g.Street.schedule("Linh",12)=="ben_xe_6" and g.Street.schedule("Linh",18)=="xom_bo_me","NPC timetable")
	g = fresh()
	g.s.used=2.0
	g.s.cash=1000000
	act(g,"tool","cho_cau_nho")
	act(g,"accept")
	var before: float = g.clock()
	act(g,"inspect")
	check(is_equal_approx(g.clock()-before,0.25),"Tool shortens inspection")
	var saved = Logic.new()
	saved.load_data()
	saved.s = JSON.parse_string(JSON.stringify(g.s))
	saved.migrate_save()
	check(saved.s.street.job.stage=="part" and saved.s.street.tool,"Pending order survives reload")
	act(g,"part_0","cho_cau_nho")
	act(g,"part_0","cho_cau_nho")
	check(not g.Street.act(g,"cho_cau_nho","part_0"),"Stock limit enforced")
	act(g,"own_part")
	check(g.s.street.parts["Tụ quạt"]==1,"Parts consumed once")
	g.s.street.xp=3
	act(g,"quick_fix")
	act(g,"test")
	act(g,"deliver")
	g.s.rep.SAU=60
	act(g,"route_repair")
	check(g.s.street.route=="Thợ sửa độc lập","Career progression")
	g.finish_day()
	g.s.used=2.0
	act(g,"accept")
	check(int(g.s.street.job.pay)==286000,"Independent rate applied to new order")
	g.s.used=11.9
	check(not g.Street.act(g,"tiem_sau","inspect"),"Cannot finish after closing")
	print("Street life tests: ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
