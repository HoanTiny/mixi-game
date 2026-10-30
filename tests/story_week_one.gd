extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
const SafeSave := preload("res://scripts/safe_save.gd")
const Guide := preload("res://scripts/quest_guide.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func fresh(d: int):
	var g = Logic.new()
	g.load_data()
	g.new_game("full")
	g.events = []
	g.s.queue = []
	g.s.scenes = []
	g.s.day = d
	g.s.used = 2.0
	g.s.needs_t = 8.0
	for key in g.s.needs: g.s.needs[key] = 100.0
	g.s.fatigue = 0.0
	g._commit()
	return g
func _init() -> void:
	var exhausted = fresh(2)
	exhausted.s.cash=0; exhausted.s.fatigue=90
	check(exhausted.action_status(exhausted.get_action("nghi_san_tro")).ok,"cashless unpaid player can recover in courtyard")
	check(Guide.active(exhausted).id=="recovery:nghi_san_tro","guide points exhausted player to recovery")
	exhausted.do_action("nghi_san_tro")
	check(exhausted.s.cash==0 and exhausted.s.fatigue<90,"rest does not need or mint money")
	check(not exhausted.action_status(exhausted.get_action("nghi_san_tro")).ok,"courtyard recovery limited once a day")
	exhausted.s.needs.fed=10
	check(Guide.active(exhausted).id=="recovery:com_voi_ba","guide offers family meal when hungry and cashless")
	for id in ["ngay5_xem_phong", "ngay5_ca_hanh", "ngay5_hai_hen", "ngay6_chia_tuyen", "ngay6_phan_gan"]:
		var g = fresh(5 if id.begins_with("ngay5") else 6)
		var before: int = g.s.cash
		g.quest_accept(id)
		check(g.s.cash == before, id + ": accepting does not pay")
		if id in ["ngay5_ca_hanh", "ngay5_hai_hen"]:
			var action: String = id + "_lam"
			g.do_action(action, {"auto":true, "ratio":1.0})
			check(g.s.quests[id].step == 0 and g.clock() == 8.0, "cannot automate authored shift")
			g.do_action(action, {"ratio":0.1})
			check(g.s.quests[id].step == 0 and not g.is_hidden(g.get_action(action)), "failed attempt can retry")
			g.do_action(action, {"ratio":0.8, "bonus":50000})
			check(g.s.quests[id].step == 1 and g.s.cash == before, "shift waits for handover and cannot mint bonus")
			check(g.is_hidden(g.get_action(action)), "finished shift cannot repeat")
		# Reload mid-quest; do not reset step, inventory, or accepted deadline.
		var saved: Dictionary = JSON.parse_string(JSON.stringify(g.s))
		var resumed = fresh(g.day())
		resumed.s = saved
		resumed.migrate_save()
		g = resumed
		var guard := 0
		while g.quest_state(id) == "active" and guard < 6:
			guard += 1
			check(g.quest_step_lock(id) == "", id + ": next handover reachable")
			g.quest_visit(id)
		check(g.quest_state(id) == "done", id + ": completed through steps")
		var paid: int = g.s.cash
		check(paid-before == int(g.quest_def(id).reward.get("cash",0)), id + ": exact contract wage")
		g.s.queue = []
		g.quest_visit(id)
		g._quest_finish(id,true)
		g.quest_accept(id)
		check(g.s.cash == paid, id + ": cannot replay settlement")
	var late = fresh(6)
	late.quest_accept("ngay6_chia_tuyen")
	late.quest_visit("ngay6_chia_tuyen")
	late.s.used += 2.0
	late._commit()
	check(late.quest_state("ngay6_chia_tuyen") == "failed", "missed delivery expires")
	check(late.item_count("com_chia_minh") == 0 and late.s.cash == 46000, "expired delivery clears cargo without paying")
	var path := "user://story-save-test.json"
	check(SafeSave.write_data(path,{"step":1}) == OK, "first staged save")
	check(SafeSave.write_data(path,{"step":2}) == OK, "replace existing save")
	check(SafeSave.read_data(path).step == 2, "primary save readable")
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string("broken{")
	file.close()
	check(SafeSave.read_data(path).step == 1, "corrupt primary recovers backup")
	check(SafeSave.write_data(path,{"step":3}) == OK, "repair corrupt primary")
	check(JSON.parse_string(FileAccess.get_file_as_string(path+".bak")).step == 1, "recovery retains valid backup")
	print("Week-one contracts and safe save: failures=",failures)
	quit(0 if failures == 0 else 1)
