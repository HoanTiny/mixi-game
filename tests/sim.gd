extends SceneTree
## Tự chơi lát cắt ngày 18–22, cả 30 ngày, 60, 90, 120 ngày (chơi tiếp chương 2, 3, 4) cho ba tuyến × các
## cách đối xử với gia đình, in bảng kết quả.
## Bản 30 ngày bỏ qua đường đi bộ: tới giờ là mở cảnh chính, làm việc nhờ, đi làm, ăn, tắm, giặt.
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/sim.gd

const GameLogic := preload("res://scripts/game_logic.gd")

## Lựa chọn theo ngày cho từng cách chơi. Bị khóa thì lấy lựa chọn đầu tiên còn mở.
## Bản 30 ngày có thêm hai cách chơi: "giấu" (làm việc đàng hoàng nhưng giấu chuyện và ép người nhà ở các cảnh gia đình)
## và "ít việc" (chọn như lắng nghe nhưng mỗi ngày chỉ làm một việc ngắn), để thử kết E5 và E7.
const HIDE_PICKS := {"ngay1": 1, "ngay9": 2, "ngay12_bc": 2, "ngay12_a": 2, "ngay19": 2, "ngay22": 2, "ngay25": 2,
	"ngay33": 1, "ngay36": 2, "ngay40": 1, "ngay44_linh": 1, "ngay47": 2, "ngay49": 2, "ngay50_kham": 1, "ngay52": 1, "ngay55": 1, "ngay56": 2,
	"ngay68": 1, "ngay69": 1, "ngay72": 1, "ngay74": 1, "ngay76": 2, "ngay77": 1, "ngay82": 1, "ngay85": 1,
	"ngay99_hoc": 2, "ngay99_to": 1, "ngay99_xa": 1, "ngay101": 2, "ngay107": 2, "ngay109": 1, "ngay110": 1, "ngay111": 1,
	"ngay112": 2, "ngay117": 1}
const FULL_POLICIES := ["lắng nghe", "giữ tiếp", "áp đặt", "gồng", "giấu", "ít việc", "để má chọn"]
## "để má chọn" (pick 6): như lắng nghe, nhưng ngày 53 không giữ chỗ cho máy may của má (thử kết K2, K1 ở chương 2),
## ngày 80 không nhận tiệm, để chú Sáu tự chọn người (lựa chọn cuối, thử kết L1 ở chương 3). Số âm: đếm từ cuối.
const LET_GO_PICKS := {"ngay53": 1, "ngay80": -1, "ngay116": 2}
## Chương 3, cách chơi lắng nghe và để má chọn: ghé nói chuyện với những người này khi họ có đoạn mạch chuyện đang mở.
const TALK3 := ["KHA", "TRAM", "MA", "LINH", "SAU", "TIN", "LUA", "ONG_BA", "BA_TU", "QUAN", "MAI", "HANH", "MINH", "DUYEN"]

## Bảng 90 ngày có thêm cách chơi "một mình": như lắng nghe nhưng chương 3 không ghé nói chuyện với ai (thử kết L2).
var _talk3 := true
## Lựa chọn ép riêng cho một lượt thử {id cảnh: lựa chọn thứ mấy}, số âm đếm từ cuối.
var _override := {}
const POLICIES := {
	"lắng nghe": {"ngay18_bc": 0, "ngay18_a": 0, "ngay19": 0, "ngay20_bc": 0, "ngay20_a": 0, "ngay21": 0, "ngay22": 0},
	"giữ tiếp": {"ngay18_bc": 1, "ngay18_a": 1, "ngay19": 1, "ngay20_bc": 1, "ngay20_a": 1, "ngay21": 1, "ngay22": 1},
	"áp đặt": {"ngay18_bc": 2, "ngay18_a": 2, "ngay19": 2, "ngay20_bc": 2, "ngay20_a": 2, "ngay21": 2, "ngay22": 2},
}


func _init() -> void:
	# -- trace <tuyến> <cách chơi 0..6>: in các lựa chọn và sổ tay chương 2 của một lượt chơi.
	var args := OS.get_cmdline_user_args()
	if args.size() >= 3 and args[0] == "trace":
		_trace(str(args[1]), int(args[2]), int(args[3]) if args.size() >= 4 else 2)
		quit()
		return
	# -- di_nam: chỉ chạy phần vào chương 3 khi còn ở nhờ nhà dì Năm.
	if args.size() >= 1 and args[0] == "di_nam":
		for case in ["o_nho", "da_tra", "con_no"]:
			_from_di_nam("A", case)
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
	print("\n90 NGÀY (chơi tiếp chương 3 từ màn kết ngày 60)")
	print("Tuyến  Cách chơi   Kết 1  Kết 2  Kết 3  Chỗ ở      Tiền cuối    Tiền nhà  Cọc tiệm  Linh      Ông Ba    Tín       Mệt  Cảnh báo/bỏ nghỉ  Giấu/ép  Việc nhờ  Bỏ lỡ")
	var tally3 := {}
	for route in GameLogic.ROUTES:
		for i in FULL_POLICIES.size() + 1:
			var pi := i if i < FULL_POLICIES.size() else 0
			_talk3 = i < FULL_POLICIES.size()
			var g := GameLogic.new()
			g.load_data()
			_full(g, route, pi)
			var key1 := str(g.s.over.get("key", "?"))
			g.start_chapter2()
			_days(g, route, pi)
			var key2 := str(g.s.over.get("key", "?"))
			g.start_chapter3()
			var missed := _days(g, route, pi)
			var over: Dictionary = g.s.over
			var cards: Dictionary = over.get("cards", {})
			var done := 0
			for q in g.s.quests:
				if g.s.quests[q].state == "done" and int(g.quest_def(q).get("days", [0])[0]) >= 61:
					done += 1
			var rent = g._find(g.s.payables, "tien_nha_t3")
			var shop = g._find(g.s.payables, "coc_tiem")
			tally3[over.get("key", "?")] = int(tally3.get(over.get("key", "?"), 0)) + 1
			print("%-6s %-11s %-6s %-6s %-6s %-10s %-12s %-9s %-9s %-9s %-9s %-9s %-4d %-17s %-8d %-9d %d" % [
				route, FULL_POLICIES[pi] if _talk3 else "một mình", key1, key2, over.get("key", "?"), str(g.home_info().get("place", g.housing().place)),
				GameLogic.fmt_money(int(g.s.cash)), "-" if rent == null else str(rent.status), "-" if shop == null else str(shop.status),
				cards.get("linh", "?"), cards.get("ong_ba", "?"), cards.get("tin", "?"), int(g.s.fatigue),
				"%d/%d" % [int(g.s.warn_days), int(g.s.rest_skips)], g.hidden_marks(61), done, missed])
	print("Phân bố kết chương 3: ", tally3)
	_talk3 = true
	print("\n120 NGÀY (chơi tiếp chương 4 từ màn kết ngày 90; \"một mình\" ngày 92 nhận đơn trường vừa sức)")
	print("Tuyến  Cách chơi   Kết 3  Kết 4  Chỗ ở      Tiền cuối    Tiền nhà  Mặt bằng  Đơn trường  Tín        Anh Quân     Mệt  Cảnh báo/bỏ nghỉ  Giấu/ép  Việc nhờ  Bỏ lỡ")
	var tally4 := {}
	for route in GameLogic.ROUTES:
		for i in FULL_POLICIES.size() + 1:
			var pi := i if i < FULL_POLICIES.size() else 0
			_talk3 = i < FULL_POLICIES.size()
			_override = {} if _talk3 else {"ngay92": 2}
			var g := GameLogic.new()
			g.load_data()
			_full(g, route, pi)
			g.start_chapter2()
			_days(g, route, pi)
			g.start_chapter3()
			_days(g, route, pi)
			var key3 := str(g.s.over.get("key", "?"))
			g.start_chapter4()
			var missed := _days(g, route, pi)
			var over: Dictionary = g.s.over
			var cards: Dictionary = over.get("cards", {})
			var done := 0
			for q in g.s.quests:
				if g.s.quests[q].state == "done" and (str(q).begins_with("don_truong") or int(g.quest_def(q).get("days", [0])[0]) >= 91):
					done += 1
			var rent = g._find(g.s.payables, "tien_nha_t4")
			var shop = g._find(g.s.payables, "mat_bang_t9")
			var order := "trễ" if g.s.flags.get("treDonTruong", false) else ("xong" if g.s.flags.get("donTruongXong", false) else "-")
			tally4[over.get("key", "?")] = int(tally4.get(over.get("key", "?"), 0)) + 1
			print("%-6s %-11s %-6s %-6s %-10s %-12s %-9s %-9s %-11s %-10s %-12s %-4d %-17s %-8d %-9d %d" % [
				route, FULL_POLICIES[pi] if _talk3 else "một mình", key3, over.get("key", "?"), str(g.home_info().get("place", g.housing().place)),
				GameLogic.fmt_money(int(g.s.cash)), "-" if rent == null else str(rent.status), "-" if shop == null else str(shop.status), order,
				cards.get("tin", "?"), cards.get("quan", "?"), int(g.s.fatigue),
				"%d/%d" % [int(g.s.warn_days), int(g.s.rest_skips)], g.hidden_marks(91), done, missed])
	print("Phân bố kết chương 4: ", tally4)
	_talk3 = true
	_override = {}
	print("\nCHƯƠNG 3 KHI CÒN Ở NHỜ NHÀ DÌ NĂM (tuyến A, lắng nghe)")
	for case in ["o_nho", "da_tra", "con_no"]:
		_from_di_nam("A", case)
	quit()


## Vào chương 3 khi còn ở nhờ nhà dì Năm (hết chương 1 cho ở dì Năm): "o_nho" ngày 40 xin ở thêm, chưa giữ phòng nào (đặt
## cọc trong tháng Bảy), "da_tra" ngày 40 đặt cọc phòng Cầu Tre, ngày 58 trả đủ (dọn ngày 61), "con_no" đặt cọc mà ngày 58
## xin giấy hẹn (trả nốt trước tối ngày 70, dọn mùng một tháng Tám).
func _from_di_nam(route: String, case: String) -> void:
	_override = {"o_nho": {"ngay40_di_nam": 2}, "da_tra": {"ngay40_di_nam": 1}, "con_no": {"ngay40_di_nam": 1, "ngay58": -1}}[case]
	var g := GameLogic.new()
	g.load_data()
	_full(g, route, 0)
	g.s["housing"] = {"state": "signed", "place": "di_nam", "paid": 500000, "seen": []}
	g.start_chapter2()
	_days(g, route, 0)
	var key2 := str(g.s.over.get("key", "?"))
	g.start_chapter3()
	var home := g.home_loc()
	_days(g, route, 0)
	var debts := []
	for x in g.s.payables:
		if int(x.due) >= 61:
			debts.append("%s %s" % [x.id, x.status])
	print("%-7s kết 2 %s · ở %s · nhà lúc kết %s %s · kết 3 %s · tiền %s · %s" % [case, key2, home, g.housing().place, g.housing().state,
		g.s.over.get("key", "?"), GameLogic.fmt_money(int(g.s.cash)), ", ".join(debts)])
	_override = {}


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
		if g.chapter() >= 3 and pick in [0, 6]:
			# Chương 3: ai có chuyện để kể (hỏi góp tiệm ngày 67–80, nói thật với người nhà) thì ghé nói, để thấy kết L3, L1;
			# ai nhờ việc thì nhận. Cách chơi "một mình" không hỏi ai, để thấy kết L2.
			for npc in TALK3 if _talk3 else []:
				if _has_beat(g, npc):
					g.talk(npc)
					_answer_full(g, route, pick)
			for q in g.quest_offers():
				g.quest_offer(str(q.id))
				_answer_full(g, route, pick)
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


## Nhân vật còn đoạn mạch chuyện chưa kể mà đã mở (nói chuyện lúc này là nghe chuyện, không phải tán gẫu).
func _has_beat(g, npc: String) -> bool:
	for b in g.talks.get(npc, {}).get("story", []):
		if not g.s.get("talks_done", []).has(b.id) and g.check(b.get("when", {})) == "":
			return true
	return false


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
		want = int(_override.get(str(e.id), want))
		if want < 0:
			want += e.choices.size()
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
	if g.chapter() == 4 and pick in [0, 4, 6]:
		# Chương 4, các cách chơi có nghỉ: mở tiệm (hay làm khoán ở tiệm) là chính, đơn quạt của trường lo ở _quests().
		return p + ["lam_tiem", "tho_khoan", "kiem_tra_dien_nguoi_gia", "nhan_may_bao_hanh", "com_voi_ba", "com_ma_nau", "coc_cau_tre_t9"]
	if g.chapter() == 3 and pick in [0, 4, 6]:
		# Chương 3, các cách chơi có nghỉ: làm ở tiệm Sáu là chính (sửa đồ lẻ buổi sáng, trông tiệm buổi chiều), thêm một
		# nhà người già với tổ của Trâm, tối ăn cơm với bà, với má.
		# Còn ở nhờ dì Năm thì đặt cọc phòng Cầu Tre, hẹn dọn mùng một tháng Tám (ẩn nếu đã có chỗ).
		return p + ["sua_do_le", "trong_tiem_chieu", "kiem_tra_dien_nguoi_gia", "com_voi_ba", "com_ma_nau", "coc_cau_tre_t8"]
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
	if g.chapter() >= 2:
		# Chương 2: hợp đồng Bến Cạn đã xong; thêm bảo trì sau mưa, sửa máy bơm ngày ngập, chạy ứng dụng nếu đã đăng ký.
		p.append_array(["bao_tri_ben_can", "sua_may_bom"])
		if pick in [1, 2, 3]:
			p.append_array(["app_tho", "app_tho_cuoi_tuan"])
	if g.chapter() == 4:
		p.append_array(["lam_tiem", "tho_khoan", "kiem_tra_dien_nguoi_gia"])
	if g.chapter() == 3:
		# Chương 3, các cách chơi không nghỉ: làm như chương 2 rồi nhận thêm việc ở tiệm và với tổ của Trâm nếu còn giờ.
		p.append_array(["trong_tiem_chieu", "kiem_tra_dien_nguoi_gia"])
	if pick in [0, 4, 6]:
		p.append("com_voi_ba")
		if g.chapter() >= 2:
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


## chapter 2: in chương 2; chapter 3 (4): chơi tiếp tới hết chương đó rồi in chương đó.
func _trace(route: String, pick: int, chapter := 2) -> void:
	var g := GameLogic.new()
	g.load_data()
	_full(g, route, pick)
	print("Kết 1: ", g.s.over.get("key", "?"), " · tiền ", GameLogic.fmt_money(int(g.s.cash)), " · chỗ ở ", g.housing().place)
	g.start_chapter2()
	_days(g, route, pick)
	if chapter >= 3:
		print("Kết 2: ", g.s.over.get("key", "?"), " · tiền ", GameLogic.fmt_money(int(g.s.cash)), " · chỗ ở ", g.housing().place, " ", g.housing().state)
		g.start_chapter3()
		_days(g, route, pick)
	if chapter >= 4:
		print("Kết 3: ", g.s.over.get("key", "?"), " · tiền ", GameLogic.fmt_money(int(g.s.cash)), " · chỗ ở ", g.housing().place, " ", g.housing().state)
		g.start_chapter4()
		_days(g, route, pick)
	var first := 30 * (chapter - 1) + 1
	for c in g.s.choices:
		if int(c.day) >= first:
			print("%d  %-14s %s" % [int(c.day), str(c.event), str(c.choice)])
	print("\nSỔ TAY")
	for d in range(first, first + 30):
		for line in g.diary_of(d):
			print("%d  %s" % [d, line])
	print("\nKết %d: " % chapter, g.s.over, " · tiền ", GameLogic.fmt_money(int(g.s.cash)), " · điểm ", g.s.get("scores", {}), " · việc nhờ ", g.s.get("quests", {}).keys())
	if chapter >= 3:
		for h in g.s.history:
			if int(h.day) >= first:
				print("  ngày %d  tiền %s  Mệt %d  %s" % [int(h.day), GameLogic.fmt_money(int(h.cash)), int(h.fatigue), ", ".join(h.actions)])
		for x in g.s.payables:
			if int(x.due) >= first:
				print("  phải trả ", x.id, " ", GameLogic.fmt_money(int(x.amount)), " hạn ", x.due, " ", x.status)
		var fl := []
		for k in g.s.flags:
			if g.s.flags[k]:
				fl.append(k)
		print("  cờ: ", ", ".join(fl))

