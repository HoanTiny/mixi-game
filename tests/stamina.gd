extends SceneTree
## Hơi khi chạy (scripts/world/stamina.gd): tụt khi chạy, hụt hơi, phải nghỉ hồi tới mức mới chạy lại.
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/stamina.gd
const Stamina := preload("res://scripts/world/stamina.gd")
const Logic := preload("res://scripts/game_logic.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func fresh() -> Stamina:
	var g=Logic.new(); g.load_data()
	var s := Stamina.new(); s.setup(g.cfg.get("stamina", {}))
	return s
## Chạy tới khi hụt hơi, trả về số giây đã chạy.
func run_out(s: Stamina, strength := 1, tired := false) -> float:
	var t := 0.0
	while t < 60.0:
		t += 1.0 / 60.0
		if s.step(1.0 / 60.0, true, true, strength, tired):
			return t
	return t

func _initialize() -> void:
	var s := fresh()
	check(is_equal_approx(float(s.cfg.drain), 12.0) and s.can_run() and is_equal_approx(s.ratio(), 1.0),"stamina reads config and starts full")
	var secs := run_out(s)
	check(secs > 7.5 and secs < 9.5,"about eight seconds of running (%s)" % secs)
	check(s.winded and not s.can_run() and is_equal_approx(s.walk_mult(), 0.85),"empty stamina means out of breath and slower walking")
	s.step(0.1, true, true)
	check(s.value == 0.0 and s.winded,"holding Shift while winded does not run")

	# Đứng nghỉ: chưa hồi ngay khi vừa dừng, rồi hồi tới recoverAt mới chạy lại được.
	s.step(0.3, false, false)
	check(s.value == 0.0,"breath does not come back instantly")
	var t := 0.3
	while s.winded and t < 30.0:
		s.step(1.0 / 60.0, false, false); t += 1.0 / 60.0
	check(t > 4.0 and t < 6.0 and s.value >= 45.0 and s.can_run(),"standing still recovers in about five seconds (%s)" % t)

	# Đi bộ thì hồi chậm hơn đứng yên.
	var w := fresh(); run_out(w); t = 0.0
	while w.winded and t < 30.0:
		w.step(1.0 / 60.0, false, true); t += 1.0 / 60.0
	check(t > 9.0,"walking recovers slower than resting (%s)" % t)

	# Thể chất cao chạy được lâu hơn, đang Mệt thì hụt hơi sớm hơn.
	check(run_out(fresh(), 3) > secs * 1.15,"strength extends running")
	check(run_out(fresh(), 1, true) < secs * 0.75,"fatigue shortens running")

	# Chưa hết hơi thì chạy tiếp được; reset về đầy.
	var p := fresh()
	for i in 120: p.step(1.0 / 60.0, true, true)
	check(p.can_run() and p.value < 80.0 and not p.winded,"partial run keeps running available")
	p.reset()
	check(is_equal_approx(p.ratio(), 1.0) and not p.winded,"reset refills")
	print("Stamina: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
