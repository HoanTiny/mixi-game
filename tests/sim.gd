extends SceneTree
## Tự chơi nhiều ván để kiểm tra cân bằng, không cần mở giao diện.
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/sim.gd

const GameLogic := preload("res://scripts/game_logic.gd")
const RUNS := 100

## Lựa chọn ưu tiên cho từng sự kiện; nếu bị khóa thì lấy lựa chọn đầu tiên còn mở.
const PICKS := {"xe_om": 0, "phong_tro": 1, "chu_bay": 0, "be_bin": 0, "vi_ong_tu": 1, "tuan_ru": 2}


func _init() -> void:
	for strategy in ["labor", "skilled"]:
		var endings := {}
		var money_total := 0
		var earned_total := 0
		for i in RUNS:
			var g := GameLogic.new()
			g.load_data()
			_play(g, strategy)
			var key: String = g.s.over.key
			endings[key] = int(endings.get(key, 0)) + 1
			money_total += int(g.s.money)
			earned_total += int(g.s.stats.earned)
		print("%-8s %s  tiền cuối TB %s  tổng kiếm TB %s" % [
			strategy, endings, GameLogic.fmt_money(money_total / RUNS), GameLogic.fmt_money(earned_total / RUNS)])
	quit()


func _play(g, strategy: String) -> void:
	g.new_game("do_nghe")
	# Mô phỏng giữ luật ăn uống cũ (gói ăn theo ngày), không mô phỏng đói, tắm, giặt.
	g.s.erase("needs")
	g.s["food"] = "com_bui"
	var guard := 0
	while not g.is_over() and guard < 200:
		guard += 1
		_answer_events(g)
		if g.is_over():
			break
		for id in _plan(g, strategy):
			g.do_action(id)
		g.finish_day(float(g.s.health) > (70.0 if strategy == "labor" else 75.0))
		_answer_events(g)


func _answer_events(g) -> void:
	var safety := 0
	while not g.s.queue.is_empty() and safety < 20:
		safety += 1
		var e: Dictionary = g.current_event()
		var want: int = PICKS.get(e.id, 0)
		var before: int = g.s.queue.size()
		g.resolve_choice(want)
		if g.s.queue.size() == before:
			for i in e.choices.size():
				g.resolve_choice(i)
				if g.s.queue.size() < before:
					break


func _plan(g, strategy: String) -> Array:
	var p := []
	if float(g.s.health) < 45.0:
		p.append("nghi")
	if strategy == "labor":
		p.append_array(["phu_ho", "rua_bat", "thu_ngan", "phat_to_roi"])
	elif g.day() <= 10:
		p.append_array(["phu_ho", "phu_chu_bay", "rua_bat", "phat_to_roi"])
	elif g.level("tayNghe") < 4:
		p.append_array(["hop_dong_12", "khoa_dien_lanh", "hoc_viec", "tho_phu", "rua_bat", "phat_to_roi"])
	else:
		p.append_array(["hop_dong_12", "tho_chinh", "tho_phu", "gia_su", "rua_bat", "phat_to_roi"])
	if float(g.s.mood) < 40.0:
		p.append("goi_ve")
	return p
