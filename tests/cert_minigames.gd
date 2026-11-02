extends SceneTree
## Trò chơi nhỏ của ba việc cần bằng (hàn, kế toán, điện lạnh): cảnh chơi được headless và trả kết quả hợp lý, tiền công
## theo kết quả cộng thêm theo tay nghề, việc vẫn chỉ mở khi có bằng.
## Chạy: Godot --headless --path . -s res://tests/cert_minigames.gd -- --demo

const GameLogic := preload("res://scripts/game_logic.gd")
const Careers := preload("res://scripts/systems/careers.gd")
const VIEWS := ["weld_bead", "ledger_check", "ac_charge"]
const Weld := preload("res://scripts/minigames/views/weld_bead_view.gd")
const Ledger := preload("res://scripts/minigames/views/ledger_check_view.gd")
const AC := preload("res://scripts/minigames/views/ac_charge_view.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	var g = GameLogic.new()
	g.load_data()
	g.new_game("full")
	for id in ["han_khung_sat", "so_sach_tieu_thuong", "bao_duong_dieu_hoa"]:
		var a: Dictionary = g.get_action(id)
		check(str(a.get("minigame", "")) == id and g.cfg.minigames.has(id), "%s gắn trò chơi nhỏ" % id)
		var count := 0
		for x in g.cfg.actions:
			if str(x.id) == id:
				count += 1
		check(count == 1, "%s không bị sinh trùng việc" % id)
		check(not g.action_status(a).ok, "%s vẫn cần bằng" % id)
		var vc: Dictionary = g.MiniGames.view_cfg(g, id)
		check(VIEWS.has(str(vc.get("view", ""))), "%s có cảnh vẽ %s" % [id, vc.get("view", "")])

	# Cảnh hàn: đầu que bám đúng rãnh suốt ba đường thì gần trọn điểm; lệch hẳn thì cháy phôi.
	var w = Weld.new()
	w.cfg = {"seconds": 6.0, "seams": 3, "tolerance": 0.07, "wobble": 0.13}
	w.state = "play"
	w._begin()
	w.holding = true
	var guard := 0
	while w.state == "play" and guard < 2000:
		guard += 1
		var x := clampf((w._t + 0.05) / 6.0, 0.0, 1.0)
		w.tip_y = Weld.seam_y(w.cfg, w._seed + w.seam * 3.1, x)
		w._play(0.05)
	var r: Dictionary = w.result()
	check(float(r.score) > 0.9 and int(r.fails) == 0, "hàn bám rãnh: đạt %.0f%%, lỗi %d" % [float(r.score) * 100.0, int(r.fails)])
	var w2 = Weld.new()
	w2.cfg = w.cfg
	w2.state = "play"
	w2._begin()
	w2.holding = true
	w2.tip_y = 0.0
	guard = 0
	while w2.state == "play" and guard < 2000:
		guard += 1
		w2.tip_y = 0.0
		w2._play(0.05)
	check(float(w2.result().score) < 0.1 and int(w2.result().burns) >= 3, "hàn lệch rãnh: cháy phôi (%s)" % str(w2.result()))
	w.free()
	w2.free()

	# Sổ sách: đáp án đúng luôn nằm trong ba số; chọn đúng cả thì đủ điểm.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var ok_sheets := true
	for i in 50:
		var sh: Dictionary = Ledger.make_sheet(rng, 4, 1000)
		var sum := 0
		for it in sh.items:
			sum += int(it.v)
		ok_sheets = ok_sheets and sum == int(sh.total) and (sh.options as Array).has(sh.total) and (sh.options as Array).size() == 3
	check(ok_sheets, "bảng kê: số dư đúng luôn nằm trong ba đáp án")
	var l = Ledger.new()
	l.cfg = {"rounds": 3, "lines": 4, "secondsPerSheet": 10.0}
	l._setup()
	l.state = "play"
	l._begin()
	guard = 0
	while l.state == "play" and guard < 500:
		guard += 1
		if l.picked < 0:
			l._choose(l.correct)
		l._play(0.5)
	check(is_equal_approx(float(l.result().score), 1.0), "sổ sách chọn đúng cả 3 tờ: đủ điểm")
	l.free()

	# Điện lạnh: bộ điều khiển giữ kim quanh vùng xanh thì nạp xong cả máy, không xả ga.
	var c = AC.new()
	c.cfg = {"units": 3, "holdSeconds": 3.0, "seconds": 20.0, "band": 0.07}
	c._setup()
	c.state = "play"
	c._begin()
	guard = 0
	while c.state == "play" and guard < 5000:
		guard += 1
		c.holding = c.needle + c.vel * 0.4 < c.target
		c._play(0.03)
	check(int(c.result().done) == 3 and int(c.result().fails) == 0, "điện lạnh giữ kim trong vùng xanh: xong %d máy, xả ga %d" % [int(c.result().done), int(c.result().fails)])
	c.free()

	# Tầng luật: có bằng thì làm được; điểm cao trả hơn giá gốc, điểm thấp chỉ một phần.
	Careers.grant_cert(g, "han")
	var guard_q := 0
	while not g.s.queue.is_empty() and guard_q < 20:
		guard_q += 1
		g.resolve_first_available()
	g.s["used"] = 8.0 - float(g.cfg.dayStart)
	g.need_adj("mood", 100.0)
	g.need_adj("fed", 100.0)
	var a2: Dictionary = g.get_action("han_khung_sat")
	check(g.action_status(a2).ok, "có bằng hàn thì nhận việc hàn được (%s)" % str(g.action_status(a2).get("reason", "")))
	var c0: int = g.s.cash
	g.do_action("han_khung_sat", {"score": 0.92, "fails": 0})
	var hi: int = int(g.s.cash) - c0
	g.finish_day()
	guard_q = 0
	while not g.s.queue.is_empty() and guard_q < 20:
		guard_q += 1
		g.resolve_first_available()
	g.s["used"] = 8.0 - float(g.cfg.dayStart)
	g.need_adj("mood", 100.0)
	g.need_adj("fed", 100.0)
	c0 = g.s.cash
	g.do_action("han_khung_sat", {"score": 0.3, "fails": 4})
	var lo: int = int(g.s.cash) - c0
	check(hi > 340000 and lo < 200000 and lo > 0, "hàn đạt trả %s, hàn hỏng trả %s" % [GameLogic.fmt_money(hi), GameLogic.fmt_money(lo)])
	print("Cert minigames: %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
