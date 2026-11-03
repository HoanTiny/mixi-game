extends SceneTree

const Logic := preload("res://scripts/game_logic.gd")
const MiniGames := preload("res://scripts/minigames/minigames.gd")
var Beer: GDScript
var failures := 0
var parts := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)

func fresh():
	var g = Logic.new()
	g.load_data(); g.new_game("full")
	for i in 40:
		if g.s.queue.is_empty(): break
		g.resolve_first_available()
	g.s.zone = "ta_hien"; g.s.zone_navigation = true
	for k in g.s.needs: g.s.needs[k] = 100.0
	g.s.fatigue = 0.0; g.s.cash = 500000
	g.s.used = 16.0 - float(g.cfg.dayStart); g.s.needs_t = 16.0
	g._commit()
	return g

func _init() -> void:
	await process_frame
	Beer = load("res://scripts/minigames/views/beer_service_view.gd")
	logic()
	await views()
	check(parts == 2, "Both test sections completed")
	print("Beer service: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)

func logic() -> void:
	var g = fresh()
	var a: Dictionary = g.get_action("bia_service")
	check(a.location == "ben_can" and a.minigame == "bia_service", "Work action is at Tạ Hiện")
	check(not MiniGames.view_cfg(g,"bia_service").allowAuto, "Service work requires manual round")
	var clock_before: float = g.clock()
	g.do_action("bia_service")
	check(g.s.cash == 500000 and g.clock() == clock_before, "No empty-result default payout")
	for case in [[1.0,140000,"Perfect"],[0.75,110000,"Good"],[0.2,30000,"Fail"]]:
		g = fresh()
		var token: String = g.start_minigame("bia_service")
		check(token != "", "Eligible shift obtains token")
		var r := {"session":token,"score":case[0],"fails":0,"completed":true,"ratio":99,"bonus":999999}
		g.do_action("bia_service",r)
		check(g.s.cash == 500000+int(case[1]), "Grade-only payout %s got %s expected %s" % [str(case[2]),str(g.s.cash-500000),str(case[1])])
		check(is_equal_approx(g.clock(),20.0), "Accepted round consumes 4 hours")
		check(str(g.last_minigame.get("grade","")) == case[2], "Grade returned to main state")
		var cash: int = g.s.cash; var time: float = g.clock()
		# Remove per-day guard to prove it is the consumed token that prevents replay.
		g.s.today.erase("bia_service")
		g.do_action("bia_service",r)
		check(g.s.cash == cash and g.clock() == time, "Duplicate callback cannot pay again")
	g = fresh()
	var token: String = g.start_minigame("bia_service")
	g.cancel_minigame(token)
	g.do_action("bia_service",{"session":token,"score":1.0,"completed":true})
	check(g.s.cash == 500000 and g.clock() == 16.0, "Cancelled intro cannot settle")
	g = fresh(); token = g.start_minigame("bia_service")
	g.do_action("bia_service",{"session":token,"score":1.0,"auto":true})
	check(g.s.cash == 500000, "Automatic repeat forbidden for service")
	var p = fresh(); token = p.start_minigame("bia_service")
	p.do_action("bia_service",{"session":token,"score":1.0,"completed":true})
	var f = fresh(); token = f.start_minigame("bia_service")
	f.do_action("bia_service",{"session":token,"score":0.0,"completed":true})
	check(p.need("clean") > f.need("clean") and p.s.fatigue < f.s.fatigue, "Failures drain more hygiene and stamina: perfect=%s/%s fail=%s/%s" % [p.need("clean"),p.s.fatigue,f.need("clean"),f.s.fatigue])
	parts += 1

func scene():
	var v = Beer.new()
	v.cfg = {"session":"test-session","seconds":30,"target":12,"beatSeconds":2.0,"type":"labor","allowAuto":false}
	v.title = "Chạy bàn quán bia"
	v.last = {"ratio":1.0,"bonus":0}
	root.add_child(v)
	v.set_process(false)
	return v

func views() -> void:
	var v = scene()
	if OS.get_cmdline_user_args().has("--service-preview"):
		root.size = Vector2i(1280,720)
		await snap("intro")
	var got := {"count":0,"result":{}}
	v.finished.connect(func(r): got.count += 1; got.result = r)
	v.cancel(); v.cancel()
	check(got.count == 1 and got.result.is_empty(), "Intro cancellation emits once with no result")
	v.queue_free()
	v = scene(); v.start()
	v._play(0.2); v.hit(); v.hit(); v.hit()
	check(v.fails == 1 and v.served == 0, "Early click fails and spam cannot retry same cup")
	v._play(1.8); v._play(1.0); v.hit(); v.hit()
	check(v.served == 1, "Window hit scores only once")
	if OS.get_cmdline_user_args().has("--service-preview"): await snap("play")
	v._play(27.0)
	check(v.state == "end" and v.time_left == 0.0, "Timer ends the round even at low frame rate")
	check(v.fails >= 13, "Skipped opportunities count as missed cups")
	v.queue_free()
	v = scene(); got = {"count":0,"result":{}}
	v.finished.connect(func(r): got.count += 1; got.result = r)
	v.start()
	for i in 12:
		v._play(1.0 if i == 0 else 2.0)
		if i % 2 == 0:
			var key := InputEventKey.new(); key.pressed = true; key.keycode = KEY_SPACE
			v._play_input(key)
		else:
			var touch := InputEventScreenTouch.new(); touch.pressed = true; touch.position = v.button_rect().get_center()
			v._play_input(touch)
	check(v.state == "end" and v.served == 12 and v.fails == 0, "Keyboard and touch can clear target")
	check(float(v.result().score) == 1.0, "All clean hits produce Perfect score")
	v.submit(); v.submit(); v.cancel()
	check(got.count == 1 and got.result.session == "test-session", "Completion delivers session only once")
	check(bool(got.result.completed), "Sealed result marks completed round")
	v.queue_free()
	await process_frame
	parts += 1

func snap(label: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/service-preview"))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/service-preview/"+label+".png")
