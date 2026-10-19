extends SceneTree
## Người chơi máy chơi trên màn phố thật: đi bộ tới tiệm, làm việc qua thanh thời gian, nói chuyện,
## về phòng trọ ngủ, chọn sự kiện. In nhật ký từng ngày để xem nhịp chơi.
## Chạy: Godot --headless --fixed-fps 60 --path . -s res://tests/playtest.gd -- --demo [--talk] [--seed=1]
##   --talk: nói chuyện với nhân vật (kể mạch chuyện, tán gẫu Vy và Tuấn để mở tuyến)

const GameLogic := preload("res://scripts/game_logic.gd")

## Thứ tự lựa chọn ưu tiên cho từng sự kiện, như một người chơi thận trọng.
const PICKS := {
	"xe_om": [1, 2, 0], "phong_tro": [1, 0], "chu_bay": [0, 1], "be_bin": [0], "lan_goi": [0],
	"vi_ong_tu": [1], "tuan_ru": [2, 1], "tuan_ru_tiep": [1], "tang_lai": [0], "tuan_nan": [0],
	"vy_bai_tap": [1, 0], "cs_mot_minh": [1, 0],
}
const NPC_LOC := {"coSau": "phong_tro", "chuBay": "tiem_chu_bay", "vy": "quan_ca_phe", "tuan": "cong_trinh", "ongTu": "tra_da"}

var w
var game
var hud
var talk := false
var stats := {"walk": 0.0, "work": 0.0, "talk": 0.0, "sleep_out": 0, "talks": 0, "chats": 0, "stuck": 0}
var _day_log := []


func _initialize() -> void:
	var seed_v := 1
	for a in OS.get_cmdline_user_args():
		if a == "--talk":
			talk = true
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
	# --demo đã tự chọn sự kiện ngày 1 theo lựa chọn đầu tiên; chơi lại từ đầu để tự chọn như người chơi.
	game.new_game("do_nghe")
	await process_frame
	print("== Người chơi máy · %s · seed %s" % ["có nói chuyện" if talk else "không nói chuyện", str(OS.get_cmdline_user_args())])
	var guard := 0
	while not game.is_over() and guard < 40:
		guard += 1
		await _play_day()
	_report()
	quit()


func _play_day() -> void:
	var d: int = game.day()
	var m0: int = int(game.s.money)
	_day_log = []
	await _events()
	if game.is_over():
		return
	if talk:
		for npc in _talk_plan():
			await _talk(npc)
	for id in _plan():
		if game.day() != d or game.is_over():
			break
		await _care()
		await _do(id)
	await _scrap(d)
	if game.day() == d and not game.is_over():
		var t0: float = game.clock()
		await _walk("phong_tro")
		stats.walk += game.clock() - t0
		if game.day() == d and game.s.queue.is_empty():
			hud.dialogs.open_night()
			hud.dialogs._end_day(float(game.s.health) > 75.0)
	var out := "" if game.day() != d else " (chưa sang ngày!)"
	print("Ngày %2d | %s → %s | SK %3d TT %3d | %s%s" % [d, GameLogic.fmt_k(m0), GameLogic.fmt_k(int(game.s.money)),
		int(game.s.health), int(game.s.mood), ", ".join(_day_log), out])


## Mạch chuyện đang mở thì kể; tán gẫu thêm với Vy, Tuấn để kịp mở tuyến pháp lý và cứu Tuấn.
func _talk_plan() -> Array:
	var out := []
	for npc in ["vy", "tuan", "chuBay", "coSau", "ongTu"]:
		var beat := false
		for b in game.talks[npc].story:
			if not game.s.get("talks_done", []).has(b.id) and game.check(b.get("when", {})) == "":
				beat = true
				break
		var grind: bool = (npc == "vy" and game.day() <= 18 and int(game.s.rep.vy) < 40) \
			or (npc == "tuan" and game.day() < 15 and int(game.s.rep.tuan) < 50)
		if beat or grind:
			out.append(npc)
	return out


## Cuối ngày còn giờ thì lục vài thùng rác gần đó; đủ hàng thì mang ra vựa bán.
func _scrap(d: int) -> void:
	if not game.has_needs() or float(game.s.health) < 60.0:
		return
	var near: Array = w.bins.duplicate()
	near.sort_custom(func(a, b) -> bool: return absf(a.pos.x - w.player.position.x) < absf(b.pos.x - w.player.position.x))
	var done := 0
	for b in near:
		if done >= 3 or game.day() != d or game.hours_left() < 1.5:
			break
		if game.scrap_lock(b.id) != "":
			continue
		hud.close_location()
		w._target = b.pos
		var f := 0
		while w._target != null and f < 3000 and game.day() == d:
			f += 1
			await physics_frame
		w._scavenge(b.id)
		done += 1
	if done > 0:
		_day_log.append("lục %d thùng rác" % done)
	if game.scrap_value() >= 60000 and game.hours_left() > 1.2 and game.day() == d:
		await _walk("vua_ve_chai")
		var v: int = game.sell_scrap()
		_day_log.append("bán ve chai %s" % GameLogic.fmt_k(v))


## Trước mỗi việc: đói thì ăn, bẩn thì tắm, đồ dơ thì giặt, như người chơi thật.
func _care() -> void:
	if not game.has_needs():
		return
	if game.need("fed") < 45.0:
		await _do("an_mi_ly" if game.need("fed") > 30.0 else ("banh_mi" if game.clock() < 10.0 else "an_com_tam"))
	if game.need("clean") < 30.0:
		await _do("tam_rua")
	if game.need("neat") < 30.0:
		await _do("giat_do")


func _plan() -> Array:
	var p := []
	if float(game.s.health) < 45.0:
		p.append("nghi")
	if game.day() <= 10:
		p.append_array(["phu_ho", "phu_chu_bay", "rua_bat", "phat_to_roi"])
	elif game.level("tayNghe") < 4:
		p.append_array(["hop_dong_12", "khoa_dien_lanh", "hoc_viec", "tho_phu", "rua_bat", "phat_to_roi"])
	else:
		p.append_array(["hop_dong_12", "tho_chinh", "tho_phu", "gia_su", "rua_bat", "phat_to_roi"])
	if game.s.flags.get("phapLyMo", false):
		p.append("doc_luat")
	if float(game.s.mood) < 40.0:
		p.append("goi_ve")
	return p


func _do(id: String) -> void:
	var a: Dictionary = game.get_action(id)
	if a.is_empty() or game.is_hidden(a) or not game.action_status(a).ok:
		return
	var d: int = game.day()
	var t0: float = game.clock()
	await _walk(str(a.location))
	stats.walk += game.clock() - t0
	if game.day() != d:
		return
	if not game.action_status(a).ok:
		_day_log.append("%s: tới nơi thì không làm được (%s)" % [id, game.action_status(a).reason])
		stats.stuck += 1
		return
	var t1: float = game.clock()
	hud._perform(id)
	while hud._working:
		await process_frame
	stats.work += game.clock() - t1
	_day_log.append("%s %s" % [GameLogic.hh(t1), id])
	await _events()


func _talk(npc: String) -> void:
	var d: int = game.day()
	var t0: float = game.clock()
	await _walk(NPC_LOC[npc])
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
		await physics_frame
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
	print("\nKết thúc: %s · tiền còn %s · nợ %s" % [over.get("key", "?"), GameLogic.fmt_money(int(game.s.money)), GameLogic.fmt_money(int(game.s.debt))])
	var days: float = maxf(1.0, float(game.day()))
	print("Giờ đi bộ %.1f (TB %.2f giờ/ngày) · giờ làm/học %.1f · giờ nói chuyện %.1f · mạch chuyện %d · tán gẫu %d · ngủ ngoài đường %d · tới nơi không làm được %d" % [
		stats.walk, stats.walk / days, stats.work, stats.talk, stats.talks, stats.chats, stats.sleep_out, stats.stuck])
	var skills := []
	for k in GameLogic.SKILLS:
		skills.append("%s %d" % [GameLogic.SKILLS[k], game.level(k)])
	print("Kỹ năng: ", ", ".join(skills), " · Thân thiết: ", game.s.rep)
	print("Cờ: ", game.s.flags.keys(), " · bằng chứng ", game.s.evidence)
