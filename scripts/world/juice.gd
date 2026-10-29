extends Node3D
## Phản hồi trực quan ("game juice") của màn phố, tách khỏi world.gd:
##   - pop(): chữ nổi trên đầu An, nảy lên (TRANS_BACK), bay lên rồi mờ; nhiều dòng cùng lúc thì xếp chồng.
##   - track(): mỗi khung so tiền, No bụng, Vệ sinh, Tâm trạng, Thể lực với lần trước, đổi từ ngưỡng trở lên thì pop.
##   - shake(): rung máy quay bằng h_offset/v_offset (không đụng vị trí máy quay mà world.gd đang lerp).
##   - burst(): hạt bung (đồng xu vàng, tia sáng) tại một điểm, dùng khi xong trò chơi nhỏ.
##   - Trạng thái trên người An: Độ no hay Tâm trạng dưới 30 thì đám mây đen lơ lửng trên đầu; Vệ sinh dưới 30 thì
##     hơi bốc mùi xanh vàng bay lên và người đi ngang hiện câu né ("Eo…"), người đi bộ né xa hơn (crowd.gd).

const POP_RISE := 1.1
const POP_TIME := 1.5
## Đổi từ chừng này trở lên mới hiện chữ (nhu cầu tụt đều theo giờ thì không hiện từng chút).
const NEED_STEP := 3.0
const NEED_NAMES := {"fed": ["No bụng", "e8b45a"], "clean": ["Vệ sinh", "7fc8e8"], "mood": ["Tâm trạng", "e88aa8"]}
const AVOID_LINES := ["Eo…", "Mùi gì thế?", "Hôi quá!", "Tránh ra tí…", "Ối giời…"]

var world
var _stack: Array = []
var _last := {}
var _shake_t := 0.0
var _shake_amp := 0.0
var _cloud: Sprite3D
var _stink: CPUParticles3D
var _cloud_t := 0.0
var _avoid_t := 0.0
var _avoided := {}


func setup(w) -> void:
	world = w
	_cloud = Sprite3D.new()
	_cloud.texture = _cloud_texture()
	_cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_cloud.pixel_size = 0.009
	_cloud.no_depth_test = true
	_cloud.render_priority = 4
	_cloud.visible = false
	add_child(_cloud)
	_stink = _stink_particles()
	add_child(_stink)


# ---------------------------------------------------------------- chữ nổi

func pop(text: String, color: Color, at := Vector3.INF) -> void:
	if world == null or world.player == null:
		return
	var base: Vector3 = (world.player.position + Vector3(0, 2.15, 0)) if at == Vector3.INF else at
	_stack = _stack.filter(func(l) -> bool: return is_instance_valid(l))
	var l := Label3D.new()
	l.text = text
	l.font = preload("res://scripts/ui/ui_kit.gd").text_font()
	l.font_size = 40
	l.outline_size = 12
	l.outline_modulate = Color(0.05, 0.04, 0.03, 0.9)
	l.modulate = color
	l.pixel_size = 0.0042
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 6
	l.position = base + Vector3(0, 0.34 * _stack.size(), 0)
	l.scale = Vector3.ONE * 0.35
	add_child(l)
	_stack.append(l)
	var tw := create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.12, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(l, "position:y", l.position.y + POP_RISE, POP_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw2.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(POP_TIME - 0.6)
	tw2.tween_property(l, "outline_modulate:a", 0.0, 0.6).set_delay(POP_TIME - 0.6)
	tw2.chain().tween_callback(l.queue_free)


## So số liệu với khung hình trước: chỉ thao tác (ăn, tắm, làm việc, mua bán) làm số đổi một lúc từ ngưỡng trở lên mới
## hiện chữ; phần tụt dần theo giờ thì không. Game chưa bắt đầu thì quên mốc cũ.
func track(game) -> void:
	if not game.is_started():
		_last = {}
		return
	var now := {"cash": int(game.s.cash), "stamina": 100.0 - float(game.s.fatigue)}
	for k in NEED_NAMES:
		now[k] = game.need(k)
	if _last.is_empty():
		_last = now
		return
	var d_cash: int = int(now.cash) - int(_last.cash)
	if d_cash != 0:
		pop(("+" if d_cash > 0 else "−") + game.fmt_money(absi(d_cash)), Color("8fe08a") if d_cash > 0 else Color("ff8a7a"))
		world.audio.play("earn" if d_cash > 0 else "spend")
	for k in NEED_NAMES:
		var d: float = float(now[k]) - float(_last[k])
		if absf(d) >= NEED_STEP:
			pop("%s %s%d" % [NEED_NAMES[k][0], "+" if d > 0 else "−", int(round(absf(d)))], Color(NEED_NAMES[k][1]) if d > 0 else Color("ff9a7a"))
	var ds: float = float(now.stamina) - float(_last.stamina)
	if absf(ds) >= 5.0:
		pop("Thể lực %s%d" % ["+" if ds > 0 else "−", int(round(absf(ds)))], Color("a3e08a") if ds > 0 else Color("ffb27a"))
	_last = now


# ---------------------------------------------------------------- rung máy quay, hạt

func shake(amp := 0.12, time := 0.35) -> void:
	_shake_amp = maxf(_shake_amp, amp)
	_shake_t = maxf(_shake_t, time)


func burst(at: Vector3, win := true) -> void:
	for spec in [[Color("f2c14e"), 46, Vector2(0.07, 0.11), 6.0], [Color("fff4d0"), 30, Vector2(0.025, 0.05), 8.0]]:
		var p := CPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = int(spec[1]) if win else int(spec[1]) / 3
		p.lifetime = 1.2
		p.explosiveness = 0.92
		p.direction = Vector3.UP
		p.spread = 55.0
		p.initial_velocity_min = float(spec[3]) * 0.55
		p.initial_velocity_max = float(spec[3])
		p.gravity = Vector3(0, -11.0, 0)
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.3
		var q := QuadMesh.new()
		q.size = spec[2]
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.albedo_color = spec[0]
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		q.material = m
		p.mesh = q
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1))
		ramp.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = ramp
		p.position = at + Vector3(0, 1.2, 0)
		add_child(p)
		p.emitting = true
		get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## Xong trò chơi nhỏ: hạt bung, rung nhẹ, chữ khen.
func celebrate(win: bool, text := "") -> void:
	if world == null:
		return
	burst(world.player.position, win)
	shake(0.16 if win else 0.08, 0.4)
	if text != "":
		pop(text, Color("f2c14e") if win else Color("e8e2d2"))


# ---------------------------------------------------------------- trạng thái trên người An

func update(delta: float, game) -> void:
	track(game)
	var cam: Camera3D = world.camera
	if _shake_t > 0.0:
		_shake_t -= delta
		var a := _shake_amp * clampf(_shake_t / 0.35, 0.0, 1.0)
		cam.h_offset = randf_range(-a, a)
		cam.v_offset = randf_range(-a, a)
		if _shake_t <= 0.0:
			_shake_amp = 0.0
			cam.h_offset = 0.0
			cam.v_offset = 0.0
	var started: bool = game.is_started() and not game.is_over() and world.player.visible
	var low: bool = started and game.low_spirits()
	var smelly: bool = started and game.smelly()
	_cloud_t += delta
	_cloud.visible = low
	if low:
		_cloud.position = world.player.position + Vector3(sin(_cloud_t * 0.9) * 0.08, 2.35 + sin(_cloud_t * 1.7) * 0.05, 0)
		_cloud.modulate.a = 0.85 + sin(_cloud_t * 2.3) * 0.1
	_stink.emitting = smelly
	_stink.position = world.player.position + Vector3(0, 1.1, 0)
	if world.player_body != null and world.player_body.has_method("set_mood_pose"):
		world.player_body.set_mood_pose(1.0 if low else 0.0)
	if world.crowd != null and "dodge_mult" in world.crowd:
		world.crowd.dodge_mult = 1.8 if smelly else 1.0
	_avoid_t -= delta
	if smelly and _avoid_t <= 0.0:
		_avoid_t = 0.6
		_react_nearby()


## Người đứng gần An lúc An bốc mùi: hiện câu né trên đầu (mỗi người tối đa một lần mỗi 10 giây).
func _react_nearby() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var me := Vector2(world.player.position.x, world.player.position.z)
	var nodes: Array = []
	for id in world.npc_nodes:
		nodes.append(world.npc_nodes[id].node)
	if world.crowd != null:
		nodes.append_array(world.crowd.live_people())
	for n in nodes:
		if not is_instance_valid(n) or not n.is_visible_in_tree():
			continue
		var q := Vector2(n.global_position.x, n.global_position.z)
		if q.distance_to(me) > 2.6 or now - float(_avoided.get(n.get_instance_id(), -99.0)) < 10.0:
			continue
		_avoided[n.get_instance_id()] = now
		pop(AVOID_LINES[randi() % AVOID_LINES.size()], Color("c8e08a"), n.global_position + Vector3(0, 2.05, 0))
		break


static func _cloud_texture() -> ImageTexture:
	var w := 96
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Đám mây: vài hình tròn chồng nhau, viền mực, có hai hạt mưa.
	var blobs := [[30, 34, 17], [50, 26, 20], [68, 36, 15], [44, 40, 15], [20, 40, 10], [78, 42, 9]]
	for pass_i in 2:
		for b in blobs:
			var r: float = float(b[2]) + (2.5 if pass_i == 0 else 0.0)
			var col := Color(0.06, 0.05, 0.05, 1.0) if pass_i == 0 else Color(0.32, 0.31, 0.34, 1.0)
			for y in range(maxi(0, int(b[1] - r)), mini(h, int(b[1] + r) + 1)):
				for x in range(maxi(0, int(b[0] - r)), mini(w, int(b[0] + r) + 1)):
					if Vector2(x - b[0], y - b[1]).length() <= r:
						img.set_pixel(x, y, col)
	for drop in [[36, 56], [56, 58], [70, 55]]:
		for y in range(drop[1] - 4, mini(h, drop[1] + 3)):
			for x in range(drop[0] - 1, drop[0] + 2):
				img.set_pixel(x, y, Color(0.45, 0.6, 0.8, 1.0))
	return ImageTexture.create_from_image(img)


static func _stink_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 22
	p.lifetime = 2.2
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0, 0.15, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.45
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.38)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _wave_texture()
	q.material = m
	p.mesh = q
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.72, 0.28, 0.0))
	ramp.add_point(0.25, Color(0.62, 0.72, 0.28, 0.85))
	ramp.set_color(ramp.get_point_count() - 1, Color(0.5, 0.55, 0.25, 0.0))
	p.color_ramp = ramp
	return p


## Nét sóng (mùi) vẽ tay: một đường lượn dọc trên nền trong.
static func _wave_texture() -> ImageTexture:
	var img := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 32:
		var x := 8.0 + sin(float(y) / 32.0 * TAU * 1.5) * 4.0
		for dx in range(-1, 2):
			var px := int(x) + dx
			if px >= 0 and px < 16:
				img.set_pixel(px, y, Color(1, 1, 1, 1.0 - absf(float(dx)) * 0.4))
	return ImageTexture.create_from_image(img)
