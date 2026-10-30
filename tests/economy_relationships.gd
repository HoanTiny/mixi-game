extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
const Survival := preload("res://scripts/systems/survival.gd")
const Relationships := preload("res://scripts/systems/relationships.gd")
const Economy := preload("res://scripts/systems/economy.gd")
const Zones := preload("res://scripts/systems/map_manager.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func fresh():
	var g = Logic.new(); g.load_data(); g.new_game("full")
	# Isolate repeatable systems from authored events, contracts and one-off
	# rewards; finish_day and all action/needs/money rules stay real.
	g.cfg.hardship={} # Isolated legacy economy benchmark; 1.13 survival is tested separately.
	g.events=[]; g.quests=[]; g.s.queue=[]; g.s.scenes=[]; g.s.receivables=[]; g.s.payables=[]; g.s.promises=[]; g.s.route="A"
	g.s.used=0.0; g.s.needs_t=6.0
	for k in g.s.needs: g.s.needs[k]=80.0
	g.s.fatigue=0.0; g._commit()
	return g

func _init() -> void:
	var g=fresh()
	check(int(g.s.cash)==46000 and Economy.fund(g)==1400000,"new normal game separates wallet and locked deposit fund")
	g.s.cash=765432; g.migrate_save()
	check(int(g.s.cash)==765432,"migration preserves existing cash")
	var before: Dictionary=g.s.needs.duplicate(); var f: float=g.s.fatigue
	g._commit(); g._commit()
	check(g.s.needs==before and is_equal_approx(g.s.fatigue,f),"zero-time commits do not decay")
	g.walk(1.0)
	check(is_equal_approx(g.need("fed"),74) and is_equal_approx(g.need("clean"),78) and is_equal_approx(g.need("mood"),78.8) and is_equal_approx(g.s.fatigue,.75),"all four hourly rates applied")
	for pair in [[20,80],[80,20],[20,20]]:
		g=fresh(); g.s.needs.fed=pair[0]; g.s.needs.clean=pair[1]; g._commit(); g.walk(1.0)
		check(is_equal_approx(g.need("mood"),77.6),"either/both neglected needs yield exactly double mood decay")
	g=fresh(); g.s.needs.fed=36.0; g.walk(2.0)
	check(is_equal_approx(g.need("mood"),76.4),"only second hour is below threshold")
	var split=fresh(); split.s.needs.fed=36.0
	for i in 120: split.walk(1.0/60.0)
	check(absf(split.need("mood")-g.need("mood"))<.001,"one long action and minute ticks agree at boundary")
	g=fresh(); g.s.needs.fed=6.0; g.walk(2.0)
	check(is_equal_approx(g.s.fatigue,4.5),"starvation fatigue charged only after actual zero crossing")
	g=fresh(); g.s.needs.fed=24.0; var mood: float=g.need("mood")
	g.do_action("com_voi_ba")
	check(absf(g.need("mood")-(mood-2.4+float(g.cfg.needs.moodRest)))<.001,"meal recovery follows elapsed hungry hour")
	check(Relationships.trust(g,"BA_TU")==58 and g.s.relationships.mealDays.size()==1,"shared meal grants trust once")
	g.do_action("com_voi_ba")
	check(Relationships.trust(g,"BA_TU")==58,"same-day repeat cannot farm trust")
	g=fresh()
	for d in range(1,8):
		g.s.day=d; g.s.used=0.0; g.s.needs_t=6.0; g.s.today={"list":[]}; g.s.queue=[]
		g.do_action("com_voi_ba")
	check(Relationships.unlocked(g) and not g.is_hidden(g.get_action("nho_ba_com_hop")),"seven distinct meals unlock packed lunch")
	var saved: Dictionary=g.s.duplicate(true)
	var reloaded=fresh(); reloaded.s=saved; reloaded.migrate_save()
	check(Relationships.unlocked(reloaded),"relationship milestone persists across save reload")
	g.do_action("nho_ba_com_hop")
	check(g.item_count("com_hop_cua_ba")==1,"one actual lunch item prepared")
	check(not g.action_status(g.get_action("an_com_hop")).ok,"cannot consume portable lunch at home")
	check(Zones.travel(g,"ta_hien"),"travel to another area")
	g.s.needs.fed=20.0; var cash: int=g.s.cash
	g.do_action("an_com_hop")
	check(g.need("fed")>70 and int(g.s.cash)==cash and g.item_count("com_hop_cua_ba")==0,"lunch recovers hunger away for no money and consumes item")
	var fed: float=g.need("fed"); g.do_action("an_com_hop")
	check(is_equal_approx(g.need("fed"),fed),"consumed lunch cannot replay")
	g=fresh(); g.s.relationships.lunchDay=g.day(); g.s.qitems.com_hop_cua_ba=1; g.s.day+=1; g.migrate_save()
	check(g.item_count("com_hop_cua_ba")==0,"lunch expires next morning")
	g=fresh(); g.s.cash=180000; cash=g.s.cash; Economy.nightly(g); Economy.nightly(g)
	check(cash-int(g.s.cash)==60000,"rent exactly60k and nightly callback idempotent")
	g=fresh(); g.s.cash=10000; Economy.nightly(g)
	check(g.s.economy.rentArrears==50000,"unpaid rent is retained, not forgiven")
	g.s.day+=1; g.s.cash=200000; Economy.nightly(g)
	check(g.s.cash==90000 and g.s.economy.rentArrears==0,"next night pays arrears plus current rent")
	g=fresh(); g.s.today.list.append("ngu_giuong_tang"); cash=g.s.cash
	# Resolve whichever real paid lodging action is configured.
	g.s.today.list=[]
	for a in g.cfg.actions:
		if a.has("sleepAway"): g.s.today.list.append(a.id); break
	Economy.nightly(g)
	check(g.s.cash==cash,"sleep-away lodging not charged room rent again")
	# Repeatable 3D repair orders have their own payout path, so their quoted
	# contract must also use economy data instead of bypassing wage balancing.
	for kind in [0,1]:
		g=fresh(); g.s.day=5 if kind==0 else 4; g.s.used=2.0; g.s.needs_t=8.0
		g.s.street.xp=3; g.s.street.route="Thợ sửa độc lập"; g.s.flags.day23_reliable=true
		var quote: int=g.Street.repair_quote(g,kind)
		check(quote==(119000 if kind==0 else 141000),"new repair quote includes balanced base,10% trade and20k loyalty")
		var offers: Array=g.Street.options(g,"tiem_sau").filter(func(o): return o.id=="accept")
		check(offers.size()==1 and str(offers[0].hint).contains(g.fmt_money(quote)),"offer UI displays exact accepted repair quote")
		check(g.Street.act(g,"tiem_sau","accept") and int(g.s.street.job.pay)==quote,"new order saves the quoted payment")
		g.s.street.job.pay=260000; g.s.street.job.stage="deliver"; g.s.street.job.due=g.day()+1
		g.cfg.economy.repairBasePay={"fan":1,"kettle":1}
		g.migrate_save()
		check(g.s.street.job.pay==260000,"existing accepted order retains contracted payment after balance change")
		cash=g.s.cash
		check(g.Street.act(g,"tiem_sau","deliver") and g.s.cash-cash==260000,"legacy accepted order actually pays original contract")
	var without:=simulate(false); var with_lunch:=simulate(true)
	print("Economy warehouse benchmark: without lunch day=",without,"; with family lunch day=",with_lunch)
	check(without>=1 and without<=26 and with_lunch>=1 and with_lunch<=26,"funded opening can reach deposit before housing deadline")
	print("Economy & relationships: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)

func act(g, id: String) -> void:
	var a: Dictionary=g.get_action(id); var st: Dictionary=g.action_status(a)
	check(st.ok,"day%d %s allowed: %s" % [g.day(),id,st.get("reason","")])
	if st.ok: g.do_action(id,{"ratio":1.0} if a.has("minigame") else {})

func simulate(use_lunch: bool) -> int:
	var g=fresh()
	# Exercise the shipped economy, including the locked fund and daily rent.
	var live=Logic.new(); live.load_data()
	g.cfg.hardship=live.cfg.hardship.duplicate(true)
	# The same 8-hour warehouse schedule uses real travel, two household tasks,
	# two hours rest, a family meal and a full-quality minigame result each day.
	for d in range(1,31):
		if use_lunch and Relationships.unlocked(g): act(g,"nho_ba_com_hop")
		check(Zones.travel(g,"cho_dau_moi"),"benchmark outbound travel")
		act(g,"an_com_hop" if use_lunch and g.item_count("com_hop_cua_ba")>0 else "banh_mi")
		act(g,"ca_kho")
		check(Zones.travel(g,"phuc_tan"),"benchmark return travel")
		act(g,"tra_tro_dem"); act(g,"com_voi_ba"); act(g,"nghi"); act(g,"tam_rua"); act(g,"giat_tiem")
		var before_day: int=g.day(); g.finish_day()
		g.s.queue=[]; g.s.scenes=[]
		print("budget lunch=",use_lunch," day=",before_day," cash=",g.s.cash," fatigue=",g.s.fatigue," fed=",g.need("fed"))
		if Economy.savings(g)>=int(g.cfg.economy.depositTarget): return before_day
	return -1
