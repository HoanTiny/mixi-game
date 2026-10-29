extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
const Guide := preload("res://scripts/quest_guide.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func settle(g) -> void:
	for i in 30:
		if g.s.queue.is_empty(): return
		g.resolve_first_available()
	check(false,"queue terminates")
func fresh():
	var g=Logic.new()
	g.load_data()
	g.new_game("full")
	settle(g)
	g.do_action("pho_chao_son")
	check(g.current_event().id=="opening_fan","first morning introduces an actual customer")
	return g
func reload_game(g):
	var copy=Logic.new()
	copy.load_data()
	copy.s=JSON.parse_string(JSON.stringify(g.s))
	copy.migrate_save()
	return copy
func act(g, id: String, loc := "tiem_sau") -> void:
	check(g.Street.act(g,loc,id),"action succeeds: "+id)
func _initialize() -> void:
	for use_market in [true,false]:
		var g=fresh()
		g.resolve_choice(0 if use_market else 1)
		check(g.quest_state("quat_trai_cay")=="active","first-day quest accepted")
		check(g.quest_target("quat_trai_cay").loc=="tiem_sau","shop diagnosis target")
		var before: int=g.s.cash
		act(g,"inspect")
		check(g.s.street.job.stage=="diagnose","measurement needs interpretation")
		act(g,"diagnose_wire")
		check(g.s.street.job.stage=="diagnose" and g.s.cash==before,"wrong diagnosis does not buy a part")
		g=reload_game(g)
		check(Guide.active(g).step=="Đọc số đo, chọn nguyên nhân","diagnosis survives save and guides correctly")
		act(g,"diagnose_cap")
		if use_market:
			act(g,"part_0","cho_cau_nho")
			act(g,"own_part")
		else: act(g,"shop_part")
		var token := str(g.s.street.accepted_day)+":0"
		g.Street.bench_action(g,"open",0,token)
		check(g.Street.bench_action(g,"remove",0,token)=="","remove actual part")
		g=reload_game(g)
		check(g.Street.bench_action(g,"install",1,token)!="","wrong component rejected")
		check(g.Street.bench_action(g,"install",0,token)=="","correct component fitted")
		for screw in 2: check(g.Street.bench_action(g,"screw",screw,token)=="","tighten actual screw")
		act(g,"test")
		check(g.item_count("quat")==1,"tested fan can be carried")
		g.quest_visit("quat_trai_cay")
		check(g.quest_state("quat_trai_cay")=="done","customer receives repaired fan")
		check(g.s.cash==before+120000-(30000 if use_market else 50000),"one payment, actual part cost")
		check(g.s.flags.get("opening_mango",false),"customer sends fruit home")
		settle(g)
		var cash: int=g.s.cash
		g._quest_finish("quat_trai_cay",true)
		check(g.s.cash==cash and g.s.street.completed==1,"no duplicate money/XP")
		g.do_action("com_voi_ba")
		check(g.neighborhood_target().action=="opening_mango","meal leads to a specific family moment")
		g.do_action("opening_mango")
		check(g.s.flags.opening_home_shared and g.s.neighborhood.stage=="done","family closes the first day")
		g.finish_day()
		settle(g)
		check(not g.scenes_today().has("ngay2"),"no repeat fan introduction")
		check(g.scenes_today().has("opening_customer_returns"),"customer remembers An the next day")
	var g=fresh()
	g.resolve_choice(2)
	check(g.quest_state("quat_trai_cay")=="" and g.neighborhood_target().action=="ca_phu_quan","declining has an alternative")
	g=fresh()
	g.resolve_choice(0)
	act(g,"inspect")
	act(g,"diagnose_cap")
	g.s.cash=0
	act(g,"credit_part")
	act(g,"cancel")
	check(g.quest_state("quat_trai_cay")=="failed","abandoning order releases bench")
	check(not g.s.street.has("story_part_credit"),"advance settled once")
	settle(g)
	check(g.neighborhood_target().action=="ca_phu_quan","failed order remains recoverable")
	g=fresh()
	g.resolve_choice(0)
	g.s.used=6.1
	g._commit()
	check(g.quest_state("quat_trai_cay")=="failed","missed noon deadline fails safely")
	print("Opening slice: ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
