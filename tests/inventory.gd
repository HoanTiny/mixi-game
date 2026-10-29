extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
var failures := 0
func check(ok: bool, label: String) -> void:
	if not ok: failures+=1; push_error(label)
func fresh():
	var g=Logic.new(); g.load_data(); g.new_game("full")
	g.s.queue=[]; g.s.scenes=[]; g.s.used=0.0; g.s.needs_t=6.0
	g.s.cash=200000; g.s.fatigue=30.0
	for key in g.s.needs: g.s.needs[key]=60.0
	g._commit()
	return g
func _init() -> void:
	var g=fresh()
	check(g.Inventory.owned(g).is_empty(),"new bag starts empty")
	check(g.buy_item("banh_mi",2),"buy a stack")
	check(g.item_count("banh_mi")==2 and g.s.cash==170000,"purchase stores exact quantity and price")
	check(is_equal_approx(g.clock(),6.0+5.0/60),"purchase advances five minutes")
	check(g.buy_item("banh_mi"),"buy more of same item")
	check(g.Inventory.owned(g).size()==1 and g.item_count("banh_mi")==3,"same item stacks in one cell")
	var fed: float=g.need("fed"); var mood: float=g.need("mood"); var time: float=g.clock()
	check(g.use_item("banh_mi"),"use bread")
	check(g.item_count("banh_mi")==2 and is_equal_approx(g.clock()-time,5.0/60),"use removes one and advances time")
	check(absf(g.need("fed")-(fed+20-.5))<.001 and absf(g.need("mood")-(mood+5-.1))<.001,"effects applied after hourly decay")
	g.s.qitems["story_keepsake"]=3
	g.s.inventory={"old_shirt":{"slot":"shirt"}}
	var reloaded=Logic.new(); reloaded.load_data(); reloaded.s=JSON.parse_string(JSON.stringify(g.s)); reloaded.migrate_save()
	check(reloaded.item_count("banh_mi")==2 and reloaded.s.inventory.has("old_shirt") and reloaded.item_count("story_keepsake")==3,"save reload preserves stacks, clothing, quest objects")
	check(not g.use_item("story_keepsake") and not g.buy_item("com_hop_cua_ba"),"quest objects cannot be consumed and grandma lunch cannot be purchased")
	var before: Dictionary=g.s.duplicate(true)
	check(not g.buy_item("banh_mi",0) and not g.buy_item("banh_mi",-1) and not g.buy_item("banh_mi",999999),"invalid purchase quantities rejected")
	check(g.s==before,"rejected transaction does not change state")
	g.s.cash=0; before=g.s.duplicate(true)
	check(not g.buy_item("nuoc_loc") and g.s==before,"insufficient cash is atomic")
	g.s.cash=200000; g.s.zone="ta_hien"; before=g.s.duplicate(true)
	check(not g.buy_item("nuoc_loc") and g.s==before,"cannot shop outside Phuc Tan")
	check(g.use_item("banh_mi"),"carried food usable away from shop")
	g.s.qitems.banh_mi=1
	check(g.use_item("banh_mi") and not g.use_item("banh_mi") and not g.s.qitems.has("banh_mi"),"last item consumed exactly once, empty stack removed")
	g.s.zone="phuc_tan"; g.s.cash=1000000; g.s.qitems.nuoc_loc=99
	check(not g.buy_item("nuoc_loc"),"stack limit enforced")
	g.s.qitems.nuoc_loc=1
	var fatigue: float=g.s.fatigue
	check(g.use_item("nuoc_loc") and absf(g.s.fatigue-(fatigue-5+.75/12))<.001,"water restores inverse stamina correctly")
	g.s.qitems.khan_uot=1; var clean: float=g.need("clean")
	check(g.use_item("khan_uot") and absf(g.need("clean")-(clean+15-2.0/12))<.001,"hygiene consumable works")
	g.s.qitems.thuoc_cam=1; g.s.fatigue=0; g.s.needs.mood=99
	check(g.use_item("thuoc_cam") and g.s.fatigue==0 and g.need("mood")==100,"stats clamp at limits")
	g.s.qitems.banh_mi=2; g.s.used=g.day_end()-6.0-0.01; g.s.needs_t=g.clock(); before=g.s.duplicate(true)
	check(not g.use_item("banh_mi") and g.s==before,"too little time cannot consume")
	g=fresh(); g.s.qitems.banh_mi=1; g.s.queue.append({"id":"pending"}); before=g.s.duplicate(true)
	check(not g.use_item("banh_mi") and g.s==before,"dialogue gates item use")
	g.s.queue=[]; g.s.zone="ta_hien"; g.s.used=10.0; g.s.needs_t=16.0
	var token: String=g.start_minigame("bia_service")
	check(token!="" and not g.use_item("banh_mi"),"active minigame gates inventory transactions")
	g.cancel_minigame(token)
	g=fresh(); g.s.rep.BA_TU=90; g.s.relationships.npcs.BA_TU.trust=90; g.s.relationships.mealDays=[1,2,3,4,5,6,7]; g._commit()
	g.do_action("nho_ba_com_hop")
	check(g.item_count("com_hop_cua_ba")==1 and not g.use_item("com_hop_cua_ba"),"same lunch stack visible but cannot eat at home")
	g.MapManager.travel(g,"ta_hien")
	check(g.use_item("com_hop_cua_ba") and not g.use_item("com_hop_cua_ba"),"bag delegates dated lunch to existing one-use action")
	before=g.s.duplicate(true); g.do_action("mua_tap_hoa")
	check(g.s==before,"shop entry itself never spends time or grants effects")
	print("Inventory: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
