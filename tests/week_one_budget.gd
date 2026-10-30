extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
var rows := []
func _initialize() -> void:
	for job in ["ca_phu_quan","ca_kho","sua_do_le"]:
		for ratio in [1.0,0.7,0.4]:
			var g := Logic.new()
			g.load_data(); g.new_game("full")
			g.events=[]; g.quests=[]; g.s.queue=[]; g.s.scenes=[]; g.s.receivables=[]
			g.s.seed=12345
			g.s.neighborhood.stage="done"
			var blocked := []
			for day in 7:
				g.s.queue=[]; g.s.scenes=[]
				for id in ["banh_mi",job,"tra_tro_dem","com_voi_ba","nghi","tam_rua","giat_tiem"]:
					var a := g.get_action(id)
					var status := g.action_status(a)
					if status.ok and not g.is_hidden(a):
						g.do_action(id,{"ratio":ratio} if id==job else {})
					else: blocked.append({"day":g.day(),"action":id,"reason":status.get("reason","")})
				g.s.queue=[]
				g.finish_day()
			rows.append({"job":job,"ratio":ratio,"cash":g.s.cash,"fund":g.Economy.fund(g),"rent_debt_nights":g.s.hard.debt,"fatigue":g.s.fatigue,"fed":g.need("fed"),"blocked":blocked})
	var file := FileAccess.open("res://build/week-budget.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	print("Week budget: ",rows.size()," schedules recorded; excludes story rewards and old wages")
	quit()
