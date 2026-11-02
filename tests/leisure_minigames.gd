extends SceneTree
## Ba trò giải trí: cờ tướng thế cờ tàn (luật, thế sinh ra luôn có nước chiếu bí), karaoke (bản nhạc, chấm nốt), máy gắp
## thú (xác suất giữ), và việc sinh ra ở đúng địa điểm, có phí, có thưởng.
## Chạy: Godot --headless --path . -s res://tests/leisure_minigames.gd -- --demo

const GameLogic := preload("res://scripts/game_logic.gd")
const X := preload("res://scripts/minigames/views/xiangqi_view.gd")
const Karaoke := preload("res://scripts/minigames/views/karaoke_view.gd")
const Claw := preload("res://scripts/minigames/views/claw_view.gd")

var failures := 0


func check(ok: bool, what: String) -> void:
	print(("  ✓ " if ok else "  ✗ ") + what)
	if not ok:
		failures += 1


func _initialize() -> void:
	# Luật cờ cơ bản.
	var b := {Vector2i(4, 0): "bK", Vector2i(4, 9): "rK", Vector2i(4, 5): "rR"}
	check(X.in_check(b, "b"), "xe cùng cột chiếu tướng")
	b = {Vector2i(4, 0): "bK", Vector2i(4, 9): "rK"}
	check(X.in_check(b, "b") and X.in_check(b, "r"), "hai tướng lộ mặt là phạm luật")
	b = {Vector2i(4, 0): "bK", Vector2i(4, 9): "rK", Vector2i(4, 4): "bP", Vector2i(4, 6): "rC"}
	check(X.in_check(b, "b") and not X.moves(b, Vector2i(4, 6)).has(Vector2i(4, 4)), "pháo cách ngòi chiếu tướng, không ăn được quân làm ngòi")
	b = {Vector2i(3, 0): "bK", Vector2i(5, 9): "rK", Vector2i(4, 2): "rN", Vector2i(4, 1): "bA"}
	check(not X.moves(b, Vector2i(4, 2)).has(Vector2i(3, 0)) and not X.moves(b, Vector2i(4, 2)).has(Vector2i(5, 0)), "mã bị cản chân thì không nhảy qua")
	# Thế mẫu: hai xe, một xe chặn hàng 1, xe kia chiếu hàng 0 là bí.
	b = {Vector2i(4, 0): "bK", Vector2i(3, 9): "rK", Vector2i(0, 1): "rR", Vector2i(8, 5): "rR"}
	var ms := X.mates(b)
	check(ms.size() >= 1, "thế hai xe có nước chiếu bí (%d nước)" % ms.size())
	# Thế sinh ngẫu nhiên: luôn có 1–2 nước bí, không ai đang bị chiếu.
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var good := 0
	var t0 := Time.get_ticks_msec()
	for i in 12:
		var p := X.make_puzzle(rng, 1)
		if not p.is_empty() and not X.in_check(p, "b") and not X.in_check(p, "r"):
			var n := X.mates(p).size()
			if n >= 1 and n <= 2:
				good += 1
	check(good == 12, "12 thế sinh ra đều giải được (%d/12, %d ms)" % [good, Time.get_ticks_msec() - t0])
	# Cảnh cờ: đi đúng nước bí là giải được thế.
	var v = X.new()
	v.cfg = {"puzzles": 1, "seconds": 60.0, "tries": 2}
	v._setup()
	v.state = "play"
	v._begin()
	var m: Array = X.mates(v.board)[0]
	v._click(m[0])
	v._click(m[1])
	check(v.solved == 1, "bấm quân đỏ rồi ô chiếu bí: giải được thế")
	v.free()

	# Karaoke: bấm đúng mọi nốt thì đủ điểm, không bấm thì trượt hết.
	var k = Karaoke.new()
	k.cfg = {"seconds": 20.0, "bpm": 96, "window": 0.18}
	k.state = "play"
	k._begin()
	var notes: Array = k.notes
	check(notes.size() >= 15, "bài 20 giây có %d nốt" % notes.size())
	var guard := 0
	while k.state == "play" and guard < 2000:
		guard += 1
		for n in k.notes:
			if int(n.state) == 0 and absf(float(n.t) - k._t) < 0.02:
				k._press(int(n.lane))
		k._play(0.02)
	check(float(k.result().score) > 0.95, "hát đúng nhịp: %.0f%% nốt" % (float(k.result().score) * 100.0))
	k.free()

	# Máy gắp: thả lệch quá ngàm thì không giữ được; đúng tâm thì phần lớn giữ được.
	check(Claw.hold_chance(0.1, 0.55, 0.06) == 0.0 and Claw.hold_chance(0.0, 0.55, 0.06) > 0.5, "máy gắp: lệch thì tuột, đúng tâm thì dễ giữ")

	# Việc sinh ra ở địa điểm, phí và thưởng.
	var g = GameLogic.new()
	g.load_data()
	g.new_game("full")
	for id in [["giai_the_co", "ho_guom"], ["karaoke", "quan_bia"], ["gap_thu", "quan_net"]]:
		var a: Dictionary = g.get_action(id[0])
		check(not a.is_empty() and str(a.location) == id[1] and str(a.minigame) == id[0], "%s ở %s" % [id[0], id[1]])
	g.s["cash"] = 200000
	g.need_adj("mood", -200.0)
	g.Survival.update(g)
	g.s["used"] = 19.0 - float(g.cfg.dayStart)
	var guard_q := 0
	while not g.s.queue.is_empty() and guard_q < 20:
		guard_q += 1
		g.resolve_first_available()
	g.s["used"] = 19.0 - float(g.cfg.dayStart)
	var st: Dictionary = g.action_status(g.get_action("karaoke"))
	check(st.ok, "trầm cảm vẫn đi hát được (%s)" % str(st.get("reason", "")))
	g.do_action("karaoke", {"score": 0.8, "fails": 2})
	check(int(g.s.cash) == 140000 and g.need("mood") >= 39.0 and not g.Survival.has(g, "tram_cam"), "karaoke 60k: Tâm trạng +40, hết trầm cảm")
	print("Leisure minigames: %s failures=%d" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
