extends SceneTree
## Sinh tồn đa tầng và bốn thuộc tính (scripts/systems/survival.gd, attributes.gd, game_clock.gd).
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/survival_attributes.gd
const Logic := preload("res://scripts/game_logic.gd")
const Survival := preload("res://scripts/systems/survival.gd")
const Attributes := preload("res://scripts/systems/attributes.gd")
const GameClock := preload("res://scripts/systems/game_clock.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func settle(g) -> void:
	for i in 40:
		if g.s.queue.is_empty(): return
		g.resolve_first_available()
func fresh():
	var g=Logic.new()
	g.load_data(); g.new_game("full"); settle(g)
	for k in g.s.needs: g.s.needs[k]=80.0
	g.s.fatigue=0.0
	g._commit()
	return g
func clock(g, hour: float) -> void:
	g.s.used=hour-6.0; g.s.needs_t=hour
	g._commit()
## Việc thử: cùng giờ, cùng Mệt, chỉ khác tag.
func add_test_actions(g) -> void:
	for t in [["t_plain",[]],["t_heavy",["heavy"]],["t_service",["service"]],["t_rest",[]]]:
		g.cfg.actions.append({"id":t[0],"group":"life" if t[0]=="t_rest" else "work","location":"x","name":t[0],"hours":2,"pay":0,"perDay":9,
			"tags":t[1],"effects":{"fatigue":10}})

func _init() -> void:
	var g=fresh(); add_test_actions(g)
	check(g.s.has("conds") and g.s.conds.is_empty(),"new game starts with no conditions")
	check(Attributes.level(g,"str")==1 and Attributes.level(g,"int")==2,"attributes start from config")
	check(Survival.hunger(g)==g.need("fed") and g.need("hunger")==g.need("fed") and g.need("hygiene")==g.need("clean"),"design names alias stored needs")

	# Đồng hồ 24 giờ.
	clock(g,13.5)
	check(GameClock.hour(g)==13.5 and GameClock.text(g)=="13:30" and GameClock.period(g)=="chiều","clock reads hour, text and period")
	check(GameClock.sleep_hours(g)+GameClock.awake_hours(g)==24.0,"awake and sleep hours make a 24h day")
	check(GameClock.abs_hours(g)==float(g.day())*24.0+13.5,"absolute hours count across days")

	# Tụt theo giờ.
	clock(g,8.0); for k in g.s.needs: g.s.needs[k]=80.0
	g.walk(2.0); g._commit()
	check(is_equal_approx(g.need("fed"),80.0+2.0*float(g.cfg.needs.perHour.fed)),"hunger drains per hour")

	# Độ no < 20: suy nhược, đi chậm, không nhận việc nặng; ăn xong hồi lên 25 thì hết.
	g=fresh(); add_test_actions(g); clock(g,8.0)
	g.s.needs.fed=15.0; g._commit()
	check(Survival.has(g,"suy_nhuoc"),"low hunger adds weakness")
	check(is_equal_approx(g.move_mult(),0.7),"weakness slows walking by 30%")
	var st: Dictionary=g.action_status(g.get_action("t_heavy"))
	check(not st.ok and "Đói" in str(st.reason),"weakness blocks heavy work with a reason")
	check(g.action_status(g.get_action("t_plain")).ok,"weakness keeps light work open")
	g.s.needs.fed=22.0; g._commit()
	check(Survival.has(g,"suy_nhuoc"),"hysteresis keeps weakness below release")
	g.need_adj("fed",30.0); g._commit()
	check(not Survival.has(g,"suy_nhuoc"),"eating clears weakness")

	# Vệ sinh < 30: bốc mùi, không nhận việc phục vụ, tán gẫu không thân thêm.
	g.s.needs.clean=20.0; g._commit()
	check(Survival.has(g,"hoi"),"low hygiene adds smell")
	check(not g.action_status(g.get_action("t_service")).ok,"smell blocks service work")
	check(g.mod("talk_rep")<=-1.0,"smell cancels chat friendship")
	g.need_adj("clean",100.0); g._commit()
	check(not Survival.has(g,"hoi"),"washing clears smell")

	# Tâm trạng chạm đáy: trầm cảm, không nhận việc nào, vẫn nghỉ được; hồi lên 30 thì hết.
	g.s.needs.mood=0.0; g._commit()
	check(Survival.has(g,"tram_cam"),"mood at bottom adds depression")
	check(not g.action_status(g.get_action("t_plain")).ok,"depression blocks every work action")
	check(g.action_status(g.get_action("t_rest")).ok,"depression keeps rest open")
	check(g.delivery_lock()!="","depression blocks delivery offers")
	g.do_action("t_plain")
	check(g.today_count("t_plain")==0,"blocked action does not run")
	g.s.needs.mood=29.0; g._commit()
	check(Survival.has(g,"tram_cam"),"depression stays until mood recovers")
	g.s.needs.mood=30.0; g._commit()
	check(not Survival.has(g,"tram_cam"),"recovered mood clears depression")

	# Việc nặng hao No thêm; Thể chất cao thì bớt hao và bớt Mệt.
	g=fresh(); add_test_actions(g); clock(g,8.0)
	g.do_action("t_plain"); var fed_plain: float=g.need("fed"); var fat_plain: float=g.s.fatigue
	g=fresh(); add_test_actions(g); clock(g,8.0)
	g.do_action("t_heavy")
	check(is_equal_approx(fed_plain-g.need("fed"),4.0),"heavy work drains 2 hunger per hour extra")
	check(is_equal_approx(g.s.fatigue,fat_plain),"level 1 strength gives no fatigue relief")
	g=fresh(); add_test_actions(g); clock(g,8.0); g.s.attr.str.lv=3
	g.do_action("t_heavy")
	check(is_equal_approx(fed_plain-g.need("fed"),4.0*0.8),"strength 3 cuts heavy drain by 20%")
	var passive := -float(Survival.decay_rates(g).get("stamina",0.0))*2.0
	check(is_equal_approx(g.s.fatigue,passive+(fat_plain-passive)*0.9),"strength 3 cuts heavy action fatigue by 10%, not passive time decay")

	# Hôm mưa, việc ngoài trời làm bẩn thêm.
	g=fresh(); add_test_actions(g); clock(g,8.0)
	g.get_action("t_plain").tags=["outdoor"]; g.do_action("t_plain"); var dry: float=g.need("clean")
	g=fresh(); add_test_actions(g); clock(g,8.0); g.s.today.rain=true
	g.get_action("t_plain").tags=["outdoor"]; g.do_action("t_plain")
	check(is_equal_approx(dry-g.need("clean"),6.0),"rain makes outdoor work dirtier")

	# Buff có hạn: dưỡng sinh làm Tâm trạng tụt chậm một nửa trong 6 giờ rồi tự hết.
	g=fresh(); clock(g,6.0)
	g.do_action("duong_sinh")
	check(Survival.has(g,"khi_huyet"),"exercise grants a timed buff")
	var m: float=g.need("mood"); g.walk(2.0); g._commit()
	check(is_equal_approx(m-g.need("mood"),2.0*-float(g.cfg.needs.perHour.mood)*0.5),"buff halves mood drain")
	clock(g,13.5)
	check(not Survival.has(g,"khi_huyet"),"buff expires after six hours")
	g.apply_effects({"cond.khi_huyet":2}); g._commit()
	check(Survival.has(g,"khi_huyet"),"effect key adds a condition")
	g.apply_effects({"cond_clear.khi_huyet":true}); g._commit()
	check(not Survival.has(g,"khi_huyet"),"effect key clears a condition")
	check(g.check({"no_cond":"suy_nhuoc"})=="" and g.check({"has_cond":"suy_nhuoc"})!="","condition checks in requirements")

	# XP và lên cấp.
	g=fresh(); clock(g,8.0)
	var mood_before: float=g.need("mood")
	check(Attributes.gain(g,"str",60.0)==1 and Attributes.level(g,"str")==2,"60 XP lifts strength to level 2")
	check(g.need("mood")>mood_before,"level up lifts mood")
	check(g.check({"stat.str":2})=="" and g.check({"stat.str":3})!="","stat requirement checks level")
	var before: float=Attributes.xp(g,"per")
	g.apply_effects({"xp.per":10})
	check(Attributes.xp(g,"per")>before+10.0,"intelligence speeds learning")
	g.s.attr.agi.lv=5
	check(is_equal_approx(g.move_mult(),1.1) and is_equal_approx(g.mod("mg.time"),0.16),"agility speeds walking and minigame time")
	Attributes.gain(g,"agi",9999.0)
	check(Attributes.level(g,"agi")==5 and Attributes.xp(g,"agi")==0.0,"level is capped")
	g=fresh(); clock(g,8.0)
	g.do_action("ca_kho",{"ratio":1.0,"bonus":0})
	check(Attributes.xp(g,"str")>0.0,"warehouse shift trains strength")

	# Lưu, nạp, bản lưu cũ.
	g.s.needs.fed=10.0; g._commit()
	var copy=Logic.new(); copy.load_data()
	copy.s=JSON.parse_string(JSON.stringify(g.s)); copy.migrate_save()
	check(Survival.has(copy,"suy_nhuoc") and Attributes.xp(copy,"str")==Attributes.xp(g,"str"),"conditions and attributes survive save/load")
	copy.s.erase("conds"); copy.s.erase("attr"); copy._commit()
	check(copy.s.has("conds") and Attributes.level(copy,"int")==2 and Survival.has(copy,"suy_nhuoc"),"legacy saves gain the new state")

	print("Survival & attributes: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
