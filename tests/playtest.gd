extends SceneTree
## Người chơi máy chơi lát cắt ngày 18–22 trên màn phố thật: đi bộ tới từng nơi, làm việc qua thanh thời gian
## (trò chơi nhỏ coi như đủ chỉ tiêu), ăn, tắm, giặt, lục ve chai, nói chuyện, về xóm trọ ngủ, chọn sự kiện.
## In nhật ký từng ngày và bảng tổng kết để xem nhịp chơi.
## Chạy: Godot --headless --fixed-fps 60 --path . -s res://tests/playtest.gd -- --demo [--full] [--route=B] [--talk] [--seed=1]
##   --full: chơi đủ 30 ngày từ ngày 1 (tới cảnh chính, làm việc nhờ, ngày 11 chọn tuyến theo --route)
##   --talk: nói chuyện với nhân vật khi có mạch chuyện mới
##   --ch2: hết ngày 30 thì bấm "Chơi tiếp" sang chương 2, chơi tới giỗ ông ngày 60
##   --fast1: chương 1 chơi nhanh bằng logic (không đi bộ), chỉ chương 2 chơi trên phố
##   --ch3: chương 1, chương 2 chơi nhanh bằng logic, rồi chơi tiếp chương 3 (tháng Bảy, ngày 61–90) trên phố
##   --ch4: ba chương đầu chơi nhanh bằng logic, rồi chơi tiếp chương 4 (tháng Tám, ngày 91–120) trên phố
##   --ch5: bốn chương đầu chơi nhanh bằng logic, rồi chơi tiếp chương 5 (tháng Chín, ngày 121–150) trên phố

const GameLogic := preload("res://scripts/game_logic.gd")

## Thứ tự lựa chọn ưu tiên cho từng sự kiện: người chơi biết lắng nghe (lựa chọn đầu tiên là cách nói rõ, hỏi ý).
const PICKS := {}
const NPC_LOC := {"BA_TU": "xom_bo_me", "LINH": "xom_bo_me", "DUYEN": "xom_bo_me", "HANH": "com_hanh", "MINH": "com_hanh",
	"SAU": "tiem_sau", "TRAM": "ben_can", "PHUC": "ben_can", "MA": "home", "ONG_BA": "home", "KHA": "cho_cau_nho",
	"TIN": "cho_cau_nho", "LUA": "cho_cau_nho", "QUAN": "ben_xe_6", "MAI": "cho_cau_nho", "PHONG": "ben_xe_6"}

var w
var game
var hud
var talk := false
var route := "B"
var full := false
var ch2 := false
var ch3 := false
var ch4 := false
var ch5 := false
var fast1 := false
var stats := {"walk": 0.0, "work": 0.0, "talk": 0.0, "sleep_out": 0, "talks": 0, "chats": 0, "stuck": 0}
var _day_log := []


func _initialize() -> void:
	var seed_v := 1
	for a in OS.get_cmdline_user_args():
		if a == "--talk":
			talk = true
		elif a == "--full":
			full = true
		elif a == "--ch2":
			full = true
			ch2 = true
		elif a == "--fast1":
			fast1 = true
		elif a == "--ch3":
			full = true
			ch3 = true
		elif a == "--ch4":
			full = true
			ch3 = true
			ch4 = true
		elif a == "--ch5":
			full = true
			ch3 = true
			ch4 = true
			ch5 = true
		elif a.begins_with("--route="):
			route = a.substr(8)
		elif a.begins_with("--seed="):
			seed_v = int(a.substr(7))
	seed(seed_v)
	_run.call_deferred()


func _run() -> void:
	w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	await process_frame
	game = root.get_node("GameState").game
	hud = w.hud
	# --demo đã tự chọn sự kiện mở đầu; chơi lại từ đầu để tự chọn như người chơi.
	game.new_game("full" if full else route)
	await process_frame
	print("== Người chơi máy · %s · tuyến %s · %s · %s" % ["30 ngày" if full else "lát cắt", route, "có nói chuyện" if talk else "không nói chuyện", str(OS.get_cmdline_user_args())])
	var guard := 0
	if fast1 or ch3:
		_fast_chapter()
	if ch3 and game.can_continue():
		game.start_chapter2()
		_fast_chapter()
		if ch4:
			game.start_chapter3()
			_fast_chapter()
			if ch5:
				game.start_chapter4()
				_fast_chapter()
				print("\n== Chơi tiếp chương 5 · chỗ ở %s %s" % [game.housing().place, game.housing().state])
				game.continue_chapter()
			else:
				print("\n== Chơi tiếp chương 4 · chỗ ở %s %s" % [game.housing().place, game.housing().state])
				game.start_chapter4()
		else:
			print("\n== Chơi tiếp chương 3 · chỗ ở %s %s" % [game.housing().place, game.housing().state])
			game.start_chapter3()
		await process_frame
	while not game.is_over() and guard < 40:
		guard += 1
		await _play_day()
	_report()
	if ch2 and game.can_continue():
		# Như người chơi bấm nút "Chơi tiếp: Chương 2 · Mùa mưa" ở màn kết.
		print("\n== Chơi tiếp chương 2 · chỗ ở %s" % game.housing().place)
		stats = {"walk": 0.0, "work": 0.0, "talk": 0.0, "sleep_out": 0, "talks": 0, "chats": 0, "stuck": 0}
		game.start_chapter2()
		await process_frame
		guard = 0
		while not game.is_over() and guard < 40:
			guard += 1
			await _play_day()
		_report()
	quit()


## Chương đang chơi chơi nhanh không đi bộ: mỗi ngày làm việc theo tuyến, ăn, tắm, nghỉ khi mệt, lựa chọn đầu tiên còn mở.
func _fast_chapter() -> void:
	var guard := 0
	while not game.is_over() and guard < 3000:
		guard += 1
		if not game.s.queue.is_empty():
			var e: Dictionary = game.current_event()
			if str(e.id) in ["ngay11", "missed:ngay11"]:
				game.resolve_choice(GameLogic.ROUTES.find(route))
			else:
				game.resolve_first_available()
			continue
		for id in game.scenes_today():
			var info: Dictionary = game.scene_info(id)
			if info.has("window") and game.clock() < float(info.window[0]):
				game.walk(float(info.window[0]) - game.clock())
			game.open_scene(id)
			break
		if not game.s.queue.is_empty():
			continue
		for id in _plan():
			if game.has_needs():
				if game.need("fed") < 45.0:
					game.do_action("an_com_quen" if game.s.flags.get("comQuen", false) else "an_com")
				if game.need("clean") < 30.0:
					game.do_action("tam_rua")
				if game.need("neat") < 30.0:
					game.do_action("giat_do")
			game.do_action(id, {"ratio": 1.0, "bonus": 0} if game.get_action(id).has("minigame") else {})
		if game.s.queue.is_empty():
			game.finish_day()
	print("Chương %d chơi nhanh: kết %s · tiền %s · chỗ ở %s" % [game.chapter(), str(game.s.over.get("key", "?")), GameLogic.fmt_money(int(game.s.cash)), game.housing().place])


func _play_day() -> void:
	var d: int = game.day()
	var m0: int = int(game.s.cash)
	_day_log = []
	await _events()
	if game.is_over():
		return
	# Cảnh chính buổi sáng trước (như người chơi nhìn bảng mục tiêu), rồi mới đi nói chuyện.
	var late := []
	for id in _sorted_scenes():
		if _start_of(id) >= 15.0:
			late.append(id)
		else:
			await _scene(id)
	if talk:
		for npc in _talk_plan():
			if game.day() == d:
				await _talk(npc)
		# Ai nhờ việc thì nhận (như người chơi thấy dấu ! trên phố); các bước đi tới nơi do _quests() lo.
		for q in game.quest_offers():
			if game.day() == d and game.s.queue.is_empty():
				game.quest_offer(str(q.id))
				_day_log.append("nhận việc nhờ %s" % q.id)
				await _events()
	await _quests()
	for id in _plan():
		if game.day() != d or game.is_over():
			break
		# Việc có khung giờ (nấu cơm với má từ 17 giờ…) thì tính từ giờ bắt đầu thật, khỏi lỡ cảnh chiều.
		var a: Dictionary = game.get_action(id)
		var begin: float = maxf(game.clock(), float(a.window[0])) if a.has("window") else game.clock()
		if not late.is_empty() and begin + float(a.get("hours", 0)) > _start_of(late[0]) + 1.0:
			continue
		await _care()
		await _do(id)
		await _quests()
	for id in late:
		if game.day() == d and not game.is_over():
			await _scene(id)
	await _quests()
	await _scrap(d)
	if game.day() == d and not game.is_over():
		var t0: float = game.clock()
		await _walk(w.home)
		stats.walk += game.clock() - t0
		if game.day() == d and game.s.queue.is_empty():
			hud.dialogs.open_night()
			hud.dialogs._end_day()
	var out := "" if game.day() != d or game.is_over() else " (chưa sang ngày!)"
	print("Ngày %2d | %s → %s | Mệt %3d PĐ %3d | %s%s" % [d, GameLogic.fmt_k(m0), GameLogic.fmt_k(int(game.s.cash)),
		int(game.s.fatigue), int(game.phong_do()), ", ".join(_day_log), out])


func _sorted_scenes() -> Array:
	var out: Array = game.scenes_today()
	out.sort_custom(func(a, b) -> bool: return _start_of(a) < _start_of(b))
	return out


func _start_of(id: String) -> float:
	var e: Dictionary = game.scene_info(id)
	return float(e.window[0]) if e.has("window") else float(game.cfg.dayStart)


## Đi tới nơi có cảnh chính; tới sớm thì ngồi chờ (thời gian trôi), quá khung giờ thì bỏ lỡ.
func _scene(id: String) -> void:
	var e: Dictionary = game.scene_info(id)
	var d: int = game.day()
	await _walk(str(e.loc))
	if game.day() != d:
		return
	if e.has("window") and game.clock() < float(e.window[0]):
		game.walk(float(e.window[0]) - game.clock())
	if game.scene_lock(id) != "":
		_day_log.append("lỡ cảnh %s (%s)" % [id, game.scene_lock(id)])
		return
	_day_log.append("%s cảnh %s" % [GameLogic.hh(game.clock()), id])
	game.open_scene(id)
	await _events()


## Việc nhờ đang làm: đi tới chỗ cần tới, lục thùng rác đúng khúc phố, làm việc được yêu cầu.
func _quests() -> void:
	for n in 3:
		for id in game.quests_active():
			var step: Dictionary = game.quest_step(id)
			var d: int = game.day()
			match str(step.get("kind", "")):
				"visit":
					if step.has("window") and game.clock() < float(step.window[0]) - 1.5:
						continue
					await _walk(str(step.loc))
					if game.day() != d:
						return
					if step.has("window") and game.clock() < float(step.window[0]):
						game.walk(float(step.window[0]) - game.clock())
					if not step.get("auto", false) and game.quest_step_lock(id) == "":
						game.quest_visit(id)
						_day_log.append("việc nhờ %s" % id)
						await _events()
				"find":
					for b in w.bins:
						if game.in_area(step.area, b.pos.x, b.pos.z) and game.scrap_lock(b.id) == "" and game.quest_state(id) == "active" and game.quest_step(id) == step:
							hud.close_location()
							w.walk_to(b.pos)
							var f := 0
							while w._target != null and f < 3000 and game.day() == d:
								f += 1
								await process_frame
							w._scavenge(b.id)
				"action":
					# Việc buổi tối (lớp học, trực đêm) thì chờ tới gần giờ mới đi, không đứng chờ cả ngày.
					var act: Dictionary = game.get_action(str(step.action))
					if act.has("window") and float(act.window[0]) >= 17.0 and game.clock() < float(act.window[0]) - 1.5:
						continue
					await _do(str(step.action))
		await process_frame


## Chỉ nói chuyện khi có mạch chuyện mới mở.
func _talk_plan() -> Array:
	var out := []
	for npc in NPC_LOC:
		for b in game.talks[npc].story:
			if not game.s.get("talks_done", []).has(b.id) and game.check(b.get("when", {})) == "":
				out.append(npc)
				break
	return out


## Cuối ngày còn giờ thì lục vài thùng rác gần đó; đủ hàng thì mang ra vựa bán.
func _scrap(d: int) -> void:
	if not game.has_needs() or game.fatigue_warn():
		return
	var near: Array = w.bins.duplicate()
	var pp := Vector2(w.player.position.x, w.player.position.z)
	near.sort_custom(func(a, b) -> bool: return Vector2(a.pos.x, a.pos.z).distance_to(pp) < Vector2(b.pos.x, b.pos.z).distance_to(pp))
	var done := 0
	for b in near:
		if done >= 3 or game.day() != d or game.hours_left() < 1.5:
			break
		if game.scrap_lock(b.id) != "":
			continue
		hud.close_location()
		w.walk_to(b.pos)
		var f := 0
		while w._target != null and f < 3000 and game.day() == d:
			f += 1
			await process_frame
		w._scavenge(b.id)
		done += 1
	if done > 0:
		_day_log.append("lục %d thùng rác" % done)
	if game.scrap_value() >= 60000 and game.hours_left() > 1.2 and game.day() == d:
		await _walk("cho_cau_nho")
		var v: int = game.sell_scrap()
		_day_log.append("bán ve chai %s" % GameLogic.fmt_k(v))


## Trước mỗi việc: đói thì ăn, bẩn thì tắm, đồ dơ thì giặt, như người chơi thật.
func _care() -> void:
	if not game.has_needs():
		return
	if game.need("fed") < 45.0:
		await _do("banh_mi" if game.clock() < 10.0 else ("an_com_quen" if game.s.flags.get("comQuen", false) else "an_com"))
	if game.need("clean") < 30.0:
		await _do("tam_rua")
	if game.need("neat") < 30.0:
		await _do("giat_do")


## Giống tests/sim.gd: lo tiến độ hợp đồng trước, rồi kiếm tiền trả ngay, mệt thì nghỉ.
func _plan() -> Array:
	var p := []
	if game.fatigue_warn():
		p.append("nghi")
	match str(game.s.route):
		"A", "":
			p.append_array(["ca_kho", "sua_do_le"])
		"B":
			if not game.progress_ready():
				p.append("ben_can_b")
			p.append_array(["giao_com", "ca_phu_quan", "sua_do_le"])
		"C":
			if not game.progress_ready():
				p.append("ben_can_c")
			p.append_array(["sua_do_le", "ca_phu_quan"])
	if game.chapter() == 5:
		# Chương 5: như chương 4; đau lưng thì đi khám, tối đi học lớp điện lạnh, trực đêm cho ông Ba nếu đã nhận.
		p = ["nghi"] if game.fatigue_warn() else []
		p.append_array(["kham_lung", "lam_tiem", "tho_khoan", "kiem_tra_dien_nguoi_gia", "nhan_may_bao_hanh", "hoc_dien_lanh",
			"truc_dem_benh_vien", "com_ma_nau", "com_voi_ba"])
		return p
	if game.chapter() == 4:
		# Chương 4: mở tiệm (hay làm khoán ở tiệm) là chính, thêm một nhà người già, nhận máy bảo hành nếu đã nhận làm.
		p = ["nghi"] if game.fatigue_warn() else []
		p.append_array(["lam_tiem", "tho_khoan", "day_tin", "kiem_tra_dien_nguoi_gia", "nhan_may_bao_hanh", "com_ma_nau", "com_voi_ba"])
		return p
	if game.chapter() == 3:
		# Chương 3: trông tiệm Sáu buổi chiều là việc chính, thêm một nhà người già với tổ của Trâm, chỉ Tín tháo ráp một món.
		p = ["nghi"] if game.fatigue_warn() else []
		p.append_array(["sua_do_le", "trong_tiem_chieu", "day_tin", "kiem_tra_dien_nguoi_gia", "com_ma_nau", "com_voi_ba"])
		return p
	if game.chapter() == 2:
		# Chương 2: việc mới theo những gì đã nhận (ứng dụng, điện chợ, đơn sau mưa), sửa máy bơm ngày ngập, nhỏ thuốc cho bà.
		p.append_array(["bao_tri_ben_can", "dien_cho", "don_mua", "don_mua_het", "don_mua_sau", "app_tho", "sua_may_bom", "ban_sau_thu_bay"])
		p.append_array(["nho_thuoc", "com_ma_nau"])
	p.append("com_voi_ba")
	return p


func _do(id: String) -> void:
	var a: Dictionary = game.get_action(id)
	if a.is_empty() or game.is_hidden(a) or not game.action_status(a).ok:
		return
	var d: int = game.day()
	var t0: float = game.clock()
	await _walk(game.action_loc(a))
	stats.walk += game.clock() - t0
	if game.day() != d:
		return
	if not game.action_status(a).ok:
		_day_log.append("%s: tới nơi thì không làm được (%s)" % [id, game.action_status(a).reason])
		stats.stuck += 1
		return
	var t1: float = game.clock()
	hud._perform(id)
	# Trò chơi nhỏ (xếp hàng ở kho, rửa bát): coi như làm đủ chỉ tiêu, không thưởng.
	if hud.minigame != null:
		hud.minigame.finished.emit({"ratio": 1.0, "bonus": 0})
		await process_frame
	while hud._working:
		await process_frame
	stats.work += game.clock() - t1
	_day_log.append("%s %s" % [GameLogic.hh(t1), id])
	await _events()


func _talk(npc: String) -> void:
	var d: int = game.day()
	var t0: float = game.clock()
	# Nhân vật có thể đang đi việc riêng (schedules.json): tới chỗ người đó đang ở, đang đi đường thì để lúc khác.
	var where: String = w.npc_where(npc)
	if where == "":
		return
	await _walk(where)
	stats.walk += game.clock() - t0
	if game.day() != d or game.talk_lock(npc) != "":
		return
	var t1: float = game.clock()
	game.talk(npc)
	var e: Dictionary = game.current_event()
	if e.id == "talk_chat":
		stats.chats += 1
	else:
		stats.talks += 1
	_day_log.append("%s nói chuyện %s (%s)" % [GameLogic.hh(t1), npc, e.id])
	stats.talk += game.clock() - t1
	await _events()


## Đi tới địa điểm như người chơi bấm vào cửa tiệm, chờ tới nơi (bảng địa điểm mở).
func _walk(loc: String) -> void:
	await _events()
	if hud.location_open() == loc:
		return
	hud.close_location()
	var d: int = game.day()
	w.walk_to_location(loc)
	var frames := 0
	while hud.location_open() != loc and frames < 3000 and game.day() == d and not game.is_over():
		frames += 1
		await process_frame
		if not game.s.queue.is_empty():
			await _events()
			if game.day() == d:
				w.walk_to_location(loc)
	if game.day() != d:
		stats.sleep_out += 1
		_day_log.append("hết giờ giữa đường, ngủ ngoài đường")


func _events() -> void:
	var safety := 0
	while not game.s.queue.is_empty() and safety < 20 and not game.is_over():
		safety += 1
		var e: Dictionary = game.current_event()
		var before: int = game.s.queue.size()
		var order: Array = PICKS.get(e.id, [])
		if str(e.id) in ["ngay11", "missed:ngay11"]:
			order = [GameLogic.ROUTES.find(route)]
		for i in order + range(e.choices.size()):
			if i < e.choices.size() and game.choice_lock(e.choices[i]) == "":
				if not str(e.id).begins_with("talk") and not game.talks.has(e.get("who", "")):
					_day_log.append("[%s → %s]" % [e.id, game.fill(e.choices[i].label)])
				game.resolve_choice(i)
				break
		if game.s.queue.size() >= before:
			break
		await process_frame
	if game.is_over():
		hud.dialogs.refresh()


func _report() -> void:
	var over: Dictionary = game.s.over
	if str(over.get("kind", "")) in ["full3", "full4", "full5"]:
		var e3: Dictionary = game._merge_variants(game.chapter_story().endings[over.key])
		print("\nKẾT CHƯƠNG %d %s · %s · thẻ %s · tiền %s" % [game.chapter(), over.key, e3.title, str(over.cards), GameLogic.fmt_money(int(game.s.cash))])
		var days3: float = maxf(1.0, float(game.day() - 30 * (game.chapter() - 1)))
		print("Giờ đi bộ %.1f (TB %.2f giờ/ngày) · giờ làm %.1f · giờ nói chuyện %.1f · mạch chuyện %d · tán gẫu %d · ngủ ngoài đường %d · tới nơi không làm được %d" % [
			stats.walk, stats.walk / days3, stats.work, stats.talk, stats.talks, stats.chats, stats.sleep_out, stats.stuck])
		print("Việc nhờ: ", game.s.get("quests", {}).keys(), "\nThân thiết: ", game.s.rep)
		return
	if str(over.get("kind", "")) == "full2":
		var e2: Dictionary = game._merge_variants(game.story2.endings[over.key])
		print("\nKẾT CHƯƠNG 2 %s · %s · má: %s · bà Tư: %s · Linh: %s · tiền %s · điểm %s" % [over.key, e2.title, over.ma, over.ba_tu, over.linh,
			GameLogic.fmt_money(int(game.s.cash)), str(game.s.get("scores", {}))])
		var days2: float = maxf(1.0, float(game.day() - 30))
		print("Giờ đi bộ %.1f (TB %.2f giờ/ngày) · giờ làm %.1f · giờ nói chuyện %.1f · mạch chuyện %d · tán gẫu %d · ngủ ngoài đường %d · tới nơi không làm được %d" % [
			stats.walk, stats.walk / days2, stats.work, stats.talk, stats.talks, stats.chats, stats.sleep_out, stats.stuck])
		print("Việc nhờ: ", game.s.get("quests", {}).keys(), "\nThân thiết: ", game.s.rep)
		return
	if str(over.get("kind", "")) == "full":
		var e: Dictionary = game.story.endings[over.key]
		print("\nKẾT %s · %s · chỗ ở %s · Linh: %s · Bà Tư: %s · thẻ nghề: %s" % [over.key, e.title, game.housing().place, over.linh, over.ba_tu, str(over.npc)])
	var r: Dictionary = game.slice_report()
	print("\nTổng kết tuyến %s · tiền mặt %s · dự kiến ngày %d: %s · đủ cho %s" % [r.route, GameLogic.fmt_money(r.cash),
		int(game.cfg.housingDeadline), GameLogic.fmt_money(r.proj_deadline), r.housing if r.housing != "" else "-"])
	print("Phải thu trước 30: %s · sau 30: %s · phải trả còn treo: %s · tiến độ %d/%d" % [GameLogic.fmt_money(r.recv_before_30),
		GameLogic.fmt_money(r.recv_after_30), GameLogic.fmt_money(r.pay_pending), r.progress, r.need])
	print("Mệt %d · ngày cảnh báo %d · bỏ nghỉ %d · Linh: %s · Bà Tư: %s" % [int(r.fatigue), r.warn_days, r.rest_skips, r.linh_card, r.ba_tu_card])
	var days: float = maxf(1.0, float(game.day() - int(game.cfg.sliceStartDay) + 1))
	print("Giờ đi bộ %.1f (TB %.2f giờ/ngày) · giờ làm %.1f · giờ nói chuyện %.1f · mạch chuyện %d · tán gẫu %d · ngủ ngoài đường %d · tới nơi không làm được %d" % [
		stats.walk, stats.walk / days, stats.work, stats.talk, stats.talks, stats.chats, stats.sleep_out, stats.stuck])
	print("Thân thiết: ", game.s.rep, " · Cờ: ", game.s.flags.keys())
