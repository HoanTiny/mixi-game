extends "res://scripts/minigames/base_minigame.gd"
## One attempt per tray arrival prevents spam-clicking. Render/input share the same hit window.

var time_left := 30.0
var elapsed := 0.0
var phase := 0.0
var served := 0
var fails := 0
var attempted := false
var feedback := "Đợi cốc trượt vào vùng xanh"
var feedback_color := Color("e8d7b4")


func rules() -> String:
	return "Dọn %d cốc trong %d giây. Mỗi lượt, bấm Space hoặc chạm nút DỌN CỐC khi vạch sáng nằm trong vùng xanh. Mỗi lượt chỉ được bấm một lần; bấm sớm hoặc bỏ lỡ sẽ đổ cốc.\nPerfect: đạt từ 90%% sau khi trừ lỗi; Good: từ 60%%; còn lại Fail.\nThoát trước khi bắt đầu không mất gì. Dừng giữa ca vẫn tính thời gian làm và kết quả hiện tại." % [int(cfg.get("target",12)), int(cfg.get("seconds",30))]


func _setup() -> void:
	time_left = maxf(1.0,float(cfg.get("seconds",30)))


func _play(delta: float) -> void:
	if state != "play": return
	var step := minf(maxf(delta,0.0),time_left)
	var period := maxf(0.5,float(cfg.get("beatSeconds",2.0)))
	var previous_beat := int(floor(elapsed/period))
	elapsed += step
	time_left = maxf(0.0,time_left-step)
	var current_beat := int(floor(elapsed/period))
	if current_beat > previous_beat:
		if not attempted: fails += 1
		fails += maxi(0,current_beat-previous_beat-1)
		attempted = false
		feedback = "Đợi cốc trượt vào vùng xanh"
		feedback_color = Color("e8d7b4")
	phase = fposmod(elapsed,period)/period
	if time_left <= 0.0: end()


func hit() -> void:
	if state != "play" or attempted or time_left <= 0.0: return
	attempted = true
	var left := float(cfg.get("windowStart",0.4))
	var right := float(cfg.get("windowEnd",0.7))
	if phase >= left and phase <= right:
		served += 1
		feedback = "Gọn rồi! +1 cốc"
		feedback_color = Color("9fc29a")
	else:
		fails += 1
		feedback = "Vội quá, đổ cốc!" if phase < left else "Chậm rồi!"
		feedback_color = Color("e79876")
	if served >= int(cfg.get("target",12)): end()
	queue_redraw()


func _play_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
		hit()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if button_rect().has_point(event.position): hit()
	elif event is InputEventScreenTouch and event.pressed:
		if button_rect().has_point(event.position): hit()


func result() -> Dictionary:
	var target := maxi(1,int(cfg.get("target",12)))
	var score := clampf(float(served)/target - fails*float(cfg.get("missPenalty",0.035)),0.0,1.0)
	return {"score":score,"served":served,"target":target,"fails":fails,"elapsed":elapsed}


func summary(r: Dictionary) -> String:
	var grade := "Perfect" if float(r.score)>=0.9 else ("Good" if float(r.score)>=0.6 else "Fail")
	var line := "%s · Dọn %d/%d cốc · %d lỗi" % [grade,int(r.served),int(r.target),int(r.fails)]
	var preview: Dictionary = cfg.get("gradePreview", {}).get(grade, {})
	if not preview.is_empty():
		line += "\nTiền công cơ bản %s (còn áp dụng phong độ).\nThể lực −%d · Vệ sinh %d, chưa gồm hao theo giờ của ca." % [str(preview.pay),int(preview.effects.get("fatigue",0)),int(preview.effects.get("need.clean",0))]
	else:
		line += "\nTiền công, Vệ sinh và Thể lực được tính theo kết quả này khi kết thúc ca."
	return line


func button_rect() -> Rect2:
	var w := minf(360.0,size.x*0.8)
	return Rect2(Vector2((size.x-w)*0.5,size.y*0.8),Vector2(w,56))


func _draw() -> void:
	if font == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("171f20"))
	# Worn plaster, dark timber and amber lamps echo the Tạ Hiện storefront.
	draw_rect(Rect2(0,size.y*0.12,size.x,size.y*0.45),Color("44463b"))
	for i in 12:
		var x := float(i)*size.x/11.0
		draw_line(Vector2(x,0),Vector2(x,size.y*0.58),Color("252f2c"),3)
	for i in 5:
		var x := size.x*(0.1+i*0.2)
		draw_line(Vector2(x,0),Vector2(x,size.y*0.16),Color("151b1b"),2)
		draw_circle(Vector2(x,size.y*0.16),13,Color("caab68"))
	draw_rect(Rect2(0,size.y*0.47,size.x,size.y*0.25),Color("6d5944"))
	for i in 9:
		var y := size.y*(0.48+i*0.027)
		draw_line(Vector2(0,y),Vector2(size.x,y),Color("534333"),2)
	text_at(Vector2(size.x/2,42),"TẠ HIỆN · CHẠY BÀN QUÁN BIA",clampi(int(size.x/28),16,26),Color("e6cd97"))
	text_at(Vector2(size.x/2,76),"Còn %02d giây  ·  Dọn %d/%d cốc  ·  Lỗi %d" % [int(ceil(time_left)),served,int(cfg.get("target",12)),fails],17,Color("ede6d6"))
	var total := maxi(1,int(cfg.get("target",12)))
	for i in mini(total,12):
		var x := size.x*(0.12+float(i%6)*0.15)
		var y := size.y*(0.33+floori(float(i)/6.0)*0.14)
		_cup(Vector2(x,y),minf(1.0,size.x/850.0),i<served)
	var track := Rect2(size.x*0.12,size.y*0.64,size.x*0.76,34)
	draw_rect(track,Color("222c2b"))
	var left := float(cfg.get("windowStart",0.4))
	var right := float(cfg.get("windowEnd",0.7))
	draw_rect(Rect2(track.position+Vector2(track.size.x*left,0),Vector2(track.size.x*(right-left),34)),Color("617f59"))
	var cursor := track.position.x+track.size.x*phase
	draw_line(Vector2(cursor,track.position.y-6),Vector2(cursor,track.end.y+6),Color("ffdf9a"),5)
	text_at(Vector2(size.x/2,size.y*0.76),feedback,18,feedback_color)
	var button := button_rect()
	draw_style_box(UI.box(Color("36483e") if not attempted else Color("303632"),Color("9e936f"),8,12),button)
	text_at(button.position+Vector2(button.size.x/2,35),"DỌN CỐC  ·  Space / Chạm",18,Color("f1e8ce"))
	text_at(Vector2(size.x/2,size.y*0.95),"Mỗi lượt một lần bấm · Esc: kết thúc ca với kết quả hiện tại",13,Color("a9afa4"))


func _cup(at: Vector2,scale_factor: float,done: bool) -> void:
	var col := Color("9eb9a0") if done else Color("bcc9c3")
	var s := scale_factor
	draw_circle(at+Vector2(0,8*s),24*s,Color(0,0,0,0.18))
	var outline := PackedVector2Array([at+Vector2(-15,-39)*s,at+Vector2(15,-39)*s,at+Vector2(11,0)*s,at+Vector2(-11,0)*s])
	draw_colored_polygon(outline,Color(col,0.25))
	draw_polyline(PackedVector2Array([outline[0],outline[1],outline[2],outline[3],outline[0]]),col,2.0,true)
	if not done:
		draw_colored_polygon(PackedVector2Array([at+Vector2(-12,-24)*s,at+Vector2(12,-24)*s,at+Vector2(10,-3)*s,at+Vector2(-10,-3)*s]),Color("a17a39"))
		draw_line(at+Vector2(-11,-24)*s,at+Vector2(11,-24)*s,Color("ded8bb"),4*s)
	else:
		draw_polyline(PackedVector2Array([at+Vector2(-7,-22)*s,at+Vector2(-1,-16)*s,at+Vector2(9,-31)*s]),Color("c7e0bb"),3.0,true)
