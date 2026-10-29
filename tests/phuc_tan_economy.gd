extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
var failures := 0
func check(ok: bool, text: String) -> void:
	if not ok: failures+=1; push_error(text)
func _init() -> void:
	var g=Logic.new(); g.load_data(); g.new_game("full"); g.s.queue=[]
	check(g.s.cash==46000 and g.Economy.fund(g)==1400000,"opening separates spendable money")
	check(not g.action_status(g.get_action("tra_tro_dem")).ok,"cannot pay rent from locked savings")
	var initial: Dictionary=g.s.duplicate(true)
	g.do_action("tra_tro_dem")
	check(g.s==initial,"unaffordable rent leaves all state unchanged")
	g.earn(20000,"Ca phụ"); g.do_action("tra_tro_dem")
	check(g.s.cash==6000 and g.today_count("tra_tro_dem")==1,"manual rent charges exactly 60k")
	check(g.Economy.rent_due(g)==0,"manual payment removes tonight's charge")
	g.Economy.nightly(g)
	check(g.s.cash==6000 and g.Economy.fund(g)==1400000,"nightly rent never charges twice or uses fund")
	g.s=JSON.parse_string(JSON.stringify(g.s)); g.migrate_save()
	check(g.s.cash==6000 and g.Economy.rent_due(g)==0,"rent and fund persist through reload")
	g.s.erase("fund_version"); g.s.erase("housing_fund"); g.s.cash=1446000
	g.migrate_save(); g.migrate_save()
	check(g.s.cash==46000 and g.Economy.fund(g)==1400000,"legacy day-one balance splits exactly once")
	g.s.cash=400000
	var place := "cau_tre"
	var choice := {"require":{"cash_min":1800000},"effects":{"housing_reserve":place}}
	check(g.choice_lock(choice)=="","housing choice accepts designated savings")
	g._reserve_housing(place)
	check(g.s.cash==0 and g.Economy.fund(g)==0 and g.housing().paid==1800000,"deposit consumes fund once plus wallet difference")
	g._reserve_housing(place)
	check(g.s.cash==0 and g.housing().paid==1800000,"repeat deposit cannot charge again")
	print("Phuc Tan economy: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
