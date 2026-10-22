extends SceneTree
## Tự chơi lát cắt ngày 18–22, cả 30 ngày, và 60 ngày (chơi tiếp chương 2) cho ba tuyến × các cách đối xử với gia đình, in bảng kết quả.
## Bản 30 ngày bỏ qua đường đi bộ: tới giờ là mở cảnh chính, làm việc nhờ, đi làm, ăn, tắm, giặt.
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/sim.gd

const GameLogic := preload("res://scripts/game_logic.gd")

## Lựa chọn theo ngày cho từng cách chơi. Bị khóa thì lấy lựa chọn đầu tiên còn mở.
## Bản 30 ngày có thêm hai cách chơi: "giấu" (làm việc đàng hoàng nhưng giấu chuyện và ép người nhà ở các cảnh gia đình)
## và "ít việc" (chọn như lắng nghe nhưng mỗi ngày chỉ làm một việc ngắn), để thử kết E5 và E7.
const HIDE_PICKS := {"ngay1": 1, "ngay9": 2, "ngay12_bc": 2, "ngay12_a": 2, "ngay19": 2, "ngay22": 2, "ngay25": 2,
	"ngay33": 1, "ngay36": 2, "ngay40": 1, "ngay44_linh": 1, "ngay47": 2, "ngay49": 2, "ngay50_kham": 1, "ngay52": 1, "ngay55": 1, "ngay56": 2}
const FULL_POLICIES := ["lắng nghe", "giữ tiếp", "áp đặt", "gồng", "giấu", "ít việc", "để má chọn"]
## "để má chọn" (pick 6): như lắng nghe, nhưng ngày 53 không giữ chỗ cho máy may của má (thử kết K2, K1 ở chương 2).
const LET_GO_PICKS := {"ngay53": 1}
const POLICIES := {
	"lắng nghe": {"ngay18_bc": 0, "ngay18_a": 0, "ngay19": 0, "ngay20_bc": 0, "ngay20_a": 0, "ngay21": 0, "ngay22": 0},
	"giữ tiếp": {"ngay18_bc": 1, "ngay18_a": 1, "ngay19": 1, "ngay20_bc": 1, "ngay20_a": 1, "ngay21": 1, "ngay22": 1},
	"áp đặt": {"ngay18_bc": 2, "ngay18_a": 2, "ngay19": 2, "ngay20_bc": 2, "ngay20_a": 2, "ngay21": 2, "ngay22": 2},
}


func _init() -> void:
	# -- trace <tuyến> <cách chơi 0..6>: in các lựa chọn và sổ tay chương 2 của một lượt chơi.
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "trace":
		_trace(str(args[1]), int(args[2]))
		quit()
		return
	print("Tuyến  Cách chơi   Tiền cuối    Dự kiến ngày 26  Đủ cho        Phải thu sau 30  Mệt  Cảnh báo  Linh       Bà Tư  Lời hứa quá hạn")
	for route in GameLogic.ROUTES:
		for policy in POLICIES:
			var g := GameLogic.new()
			g.load_data()
			_play(g, route, POLICIES[policy])
			var r: Dictionary = g.slice_report()
			var overdue := 0
			for p in r.promises:
				if p.status == "overdue":
					overdue += 1
			print("%-6s %-11s %-12s %-16s %-13s %-16s %-4d %-9d %-10s %-6s %d" % [
				route, policy, GameLogic.fmt_money(r.cash), GameLogic.fmt_money(r.proj_deadline),
				r.housing if r.housing != "" else "-", GameLogic.fmt_money(r.recv_after_30),
				int(r.fatigue), r.warn_days, r.linh_card, r.ba_tu_card, overdue])
	print("\n30 NGÀY")
	print("Tuyến  Cách chơi   Kết   Chỗ ở      Tiền cuối    Phải thu sau 30  Mệt  Cảnh báo/bỏ nghỉ  Che giấu  Linh   Bà Tư    Việc nhờ xong  Cảnh bỏ lỡ")
	var tally := {}
	for route in GameLogic.ROUTES:
		for pi in FULL_POLICIES.size():
			var g := GameLogic.new()
			g.load_data()
			var missed := _full(g, route, pi)
			var over: Dictionary = g.s.over
			var done := 0
			for q in g.s.quests:
				if g.s.quests[q].state == "done":
					done += 1
			tally[over.get("key", "?")] = int(tally.get(over.get("key", "?"), 0)) + 1
			print("%-6s %-11s %-5s %-10s %-12s %-16s %-4d %-17s %-9d %-6s %-8s %-14d %d" % [
				route + ("" if g.s.route == route else ">" + str(g.s.route)), FULL_POLICIES[pi], over.get("key", "?"), str(g.housing().place),
				GameLogic.fmt_money(int(g.s.cash)), GameLogic.fmt_money(g.receivable_sum(31, 999)), int(g.s.fatigue),
				"%d/%d" % [int(g.s.warn_days), int(g.s.rest_skips)], g.hidden_marks(), over.get("linh", "?"), over.get("ba_tu", "?"), done, missed])
	print("Phân bố kết thúc: ", tally)
	print("\n60 NGÀY (chơi tiếp chương 2 từ màn kết ngày 30)")
	print("Tuyến  Cách chơi   Kết 1  Kết 2  Chỗ ở      Tiền cuối    Tiền nhà  Má      Bà Tư     Linh     Mệt  Cảnh báo/bỏ nghỉ  Giấu/ép  Việc nhờ  Bỏ lỡ")
	var tally2 := {}
	for route in GameLogic.ROUTES:
		for pi in FULL_POLICIES.size():
			var g := GameLogic.new()
			g.load_data()
			_full(g, route, pi)
			var key1 := str(g.s.over.get("key", "?"))
			g.start_chapter2()
			var missed := _days(g, route, pi)
			var over: Dictionary = g.s.over
			var done := 0
			for q in g.s.quests:
				if g.s.quests[q].state == "done":
					done += 1
			var rent = g._find(g.s.payables, "tien_nha_t2")
			tally2[over.get("key", "?")] = int(tally2.get(over.get("key", "?"), 0)) + 1
			print("%-6s %-11s %-6s %-6s %-10s %-12s %-9s %-7s %-9s %-8s %-4d %-17s %-8d %-9d %d" % [
				route, FULL_POLICIES[pi], key1, over.get("key", "?"), str(g.housing().place),
				GameLogic.fmt_money(int(g.s.cash)), "-" if rent == null else str(rent.status), over.get("ma", "?"),
				over.get("ba_tu", "?"), over.get("linh", "?"), int(g.s.fatigue),
				"%d/%d" % [int(g.s.warn_days), int(g.s.rest_skips)], g.hidden_marks(31), done, missed])
	print("Phân bố kết chương 2: ", tally2)
	quit()


## Chơi đủ 30 ngày. pick: 0 lắng nghe, 1 giữ tiếp, 2 áp đặt (lựa chọn thứ mấy trong mỗi cảnh); ngày 11 chọn theo tuyến.
## Trả về số cảnh chính bị bỏ lỡ.
func _full(g, route: String, pick: int) -> int:
	g.new_game("full")
	return _days(g, route, pick)


## Chơi từng ngày tới màn kết của chương đang chơi. Trả về số cảnh chính bị bỏ lỡ.
func _days(g, route: String, pick: int) -> int:
	var missed := 0
	var guard := 0
	while not g.is_over() and guard < 40:
		guard += 1
		_answer_full(g, route, pick)
		if g.is_over():
			break
		var scenes: Array = g.scenes_today()
		scenes.sort_custom(func(a, b) -> bool: return _start_of(g, a) < _start_of(g, b))
		var late := []
		for id in scenes:
			if _start_of(g, id) >= 15.0:
				late.append(id)
			else:
				missed += _scene(g, id, route, pick)
		_quests(g)
		for id in _plan_full(g, pick):
			_care(g)
			if g.get_action(id).has("minigame"):
				g.do_action(id, {"ratio": 1.0, "bonus": 0})
			else:
				g.do_action(id)
			_quests(g)
			if g.hours_left() < 3.0 and not late.is_empty():
				break
		for id in late:
			missed += _scene(g, id, route, pick)
		_quests(g)
		for a in g.visible_actions("optional"):
			if a.has("showIfPromise") or (pick in [0, 6] and a.get("rest", false)):
				g.do_action(a.id)
		_care(g)
		_answer_full(g, route, pick)
		if not g.is_over():
			g.finish_day()
	return missed


func _start_of(g, id: String) -> float:
	var e: Dictionary = g.scene_info(id)
	return float(e.window[0]) if e.has("window") else float(g.cfg.dayStart)


## Chờ tới khung giờ của cảnh rồi mở; quá khung thì coi như bỏ lỡ.
func _scene(g, id: String, route: String, pick: int) -> int:
	var e: Dictionary = g.scene_info(id)
	if e.has("window"):
		if g.clock() > float(e.window[1]):
			return 1
		if g.clock() < float(e.window[0]):
			g.s["used"] = float(e.window[0]) - float(g.cfg.dayStart)
	if g.scene_lock(id) != "":
		return 1
	g.open_scene(id)
	_answer_full(g, route, pick)
	return 0


func _answer_full(g, route: String, pick: int) -> void:
	var safety := 0
	while not g.s.queue.is_empty() and safety < 20 and not g.is_over():
		safety += 1
		var e: Dictionary = g.current_event()
		var want := 1 if pick == 3 else (0 if pick >= 4 else pick)
		if pick == 4:
			want = int(HIDE_PICKS.get(str(e.id), 0))
		elif pick == 6:
			want = int(LET_GO_PICKS.get(str(e.id), 0))
		if str(e.id) in ["ngay11", "missed:ngay11"]:
			want = GameLogic.ROUTES.find(route)
		elif str(e.id) in ["ngay26", "missed:ngay26", "ngay30"]:
			# Chỗ ở: lấy chỗ tốt nhất đủ tiền. Ngày 30: không tự sửa sai để thấy hậu quả của cách chơi.
			want = 0
		var before: int = g.s.queue.size()
		if want < e.choices.size() and g.choice_lock(e.choices[want]) == "":
			g.resolve_choice(want)
		else:
			g.resolve_first_available()
		if not g.s.queue.is_empty() and g.s.queue.size() == before and g.s.queue[0].id == e.id:
			g.resolve_first_available()


## Việc nhờ đang làm: tới nơi là xong (bỏ qua đường đi), lục thùng rác đúng khúc phố, làm việc theo yêu cầu.
func _quests(g) -> void:
	for n in 4:
		for id in g.quests_active():
			var step: Dictionary = g.quest_step(id)
			match str(step.get("kind", "")):
				"visit":
					if g.quest_step_lock(id) == "":
						g.quest_visit(id)
						_answer_full(g, "A", 1)
				"find":
					g.scavenge("q%d_%d" % [g.day(), n], (float(step.area[0]) + float(step.area[2])) / 2.0, (float(step.area[1]) + float(step.area[3])) / 2.0)
				"action":
					g.do_action(str(step.action), {"ratio": 1.0, "bonus": 0})


## Ngày làm việc ở bản 30 ngày: lắng nghe thì nghỉ sớm (Mệt từ 60), hai cách kia chỉ nghỉ khi cảnh báo.
## "gồng" (pick 3): chọn như giữ tiếp nhưng ngày nào cũng thêm ca phụ quán, không bao giờ nghỉ.
func _plan_full(g, pick: int) -> Array:
	var p := []
	if pick != 3 and float(g.s.fatigue) >= (60.0 if pick in [0, 4, 5, 6] else float(g.cfg.fatigue.warn)):
		p.append("nghi")
	if pick == 3:
		p.append("ca_phu_quan")
	if pick == 5:
		return p + ["sua_do_le", "com_voi_ba"]
	match str(g.s.route):
		"B":
			if not g.progress_ready():
				p.append("ben_can_b")
			p.append_array(["giao_com", "sua_do_le"])
		"C":
			if not g.progress_ready():
				p.append("ben_can_c")
			p.append_array(["sua_do_le", "ca_phu_quan"])
		_:
			p.append_array(["ca_kho", "sua_do_le"])
	if g.chapter() == 2:
		# Chương 2: hợp đồng Bến Cạn đã xong; thêm bảo trì sau mưa, sửa máy bơm ngày ngập, chạy ứng dụng nếu đã đăng ký.
		p.append_array(["bao_tri_ben_can", "sua_may_bom"])
		if pick in [1, 2, 3]:
			p.append_array(["app_tho", "app_tho_cuoi_tuan"])
	if pick in [0, 4, 6]:
		p.append("com_voi_ba")
		if g.chapter() == 2:
			p.append("com_ma_nau")
	return p


func _play(g, route: String, picks: Dictionary) -> void:
	g.new_game(route)
	var guard := 0
	while not g.is_over() and guard < 20:
		guard += 1
		_answer(g, picks)
		if g.is_over():
			break
		for id in g.scenes_today():
			if g.scene_lock(id) == "":
				g.open_scene(id)
				_answer(g, picks)
		for id in _plan(g):
			_care(g)
			g.do_action(id)
		_care(g)
		g.finish_day()
	_answer(g, picks)


func _answer(g, picks: Dictionary) -> void:
	var safety := 0
	while not g.s.queue.is_empty() and safety < 20:
		safety += 1
		var e: Dictionary = g.current_event()
		var before: int = g.s.queue.size()
		g.resolve_choice(int(picks.get(e.id, 0)))
		if g.s.queue.size() == before and g.s.queue[0].id == e.id:
			g.resolve_first_available()


## Ăn ở Cơm Hạnh khi đói, tắm và giặt ở xóm trọ khi bẩn (bỏ qua đường đi bộ giữa các nơi).
func _care(g) -> void:
	if not g.has_needs():
		return
	if g.need("fed") < 45.0:
		g.do_action("an_com_quen" if g.s.flags.get("comQuen", false) else "an_com")
	if g.need("clean") < 35.0:
		g.do_action("tam_rua")
	if g.need("neat") < 35.0:
		g.do_action("giat_do")


## Một ngày làm việc điển hình của từng tuyến: lo tiến độ hợp đồng trước, rồi kiếm tiền trả ngay, mệt thì nghỉ.
func _plan(g) -> Array:
	var p := []
	if g.fatigue_warn():
		p.append("nghi")
	match str(g.s.route):
		"A":
			p.append_array(["ca_kho", "ca_phu_quan", "sua_do_le"])
		"B":
			if not g.progress_ready():
				p.append("ben_can_b")
			p.append_array(["giao_com", "ca_phu_quan", "sua_do_le"])
		"C":
			if not g.progress_ready():
				p.append("ben_can_c")
			p.append_array(["sua_do_le", "ca_phu_quan"])
	p.append("com_voi_ba")
	return p


func _trace(route: String, pick: int) -> void:
	var g := GameLogic.new()
	g.load_data()
	_full(g, route, pick)
	print("Kết 1: ", g.s.over.get("key", "?"), " · tiền ", GameLogic.fmt_money(int(g.s.cash)), " · chỗ ở ", g.housing().place)
	g.start_chapter2()
	_days(g, route, pick)
	for c in g.s.choices:
		if int(c.day) >= 31:
			print("%d  %-14s %s" % [int(c.day), str(c.event), str(c.choice)])
	print("\nSỔ TAY")
	for d in range(31, 61):
		for line in g.diary_of(d):
			print("%d  %s" % [d, line])
	print("\nKết 2: ", g.s.over, " · tiền ", GameLogic.fmt_money(int(g.s.cash)), " · điểm ", g.s.get("scores", {}), " · việc nhờ ", g.s.get("quests", {}).keys())

