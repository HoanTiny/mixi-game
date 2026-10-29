class_name BaseMiniGame
extends Control
## Khung chung cho cảnh trò chơi nhỏ 2D (tầng giao diện). Màn đầu hiện luật chơi và các dòng cfg.info do
## scripts/minigames/minigames.gd soạn (chi phí, thưởng, rủi ro); màn cuối hiện kết quả thô. Esc ở màn đầu là thôi,
## giữa chừng là dừng và tính tới lúc đó. Cảnh con chỉ vẽ và điều khiển, trả về kết quả thô qua result():
## {"score": phần chỉ tiêu đạt được 0..1+, "fails": số lần hỏng, …}; tiền, thưởng, chấn thương do tầng luật tính.
## Cùng giao diện với work_site.gd, billiards.gd: cfg, kind, last, title, phát finished(result), {} nếu bỏ.
## Cảnh con ghi đè: rules(), _setup(), _begin(), _play(delta), _play_input(event), result(), summary(r), _draw().

signal finished(result: Dictionary)

const UI := preload("res://scripts/ui/ui_kit.gd")

var cfg: Dictionary = {}
var kind := ""
var last: Dictionary = {}
var title := ""
## "intro" (màn đầu), "play", "end" (màn kết quả).
var state := "intro"
var font: Font
var _overlay: CenterContainer
var _first_button: Button
var _submitted := false
var _sealed_result: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	theme = UI.make_theme()
	font = UI.text_font()
	_setup()
	var body := [rules()]
	var info: Array = cfg.get("info", [])
	if not info.is_empty():
		body.append("\n".join(info))
	var buttons := [["Bắt đầu  (Space)", start]]
	# Ca lao động đã làm rồi thì cho làm nhanh như lần trước (cùng kết quả, không chơi lại).
	if str(cfg.get("type", "")) == "labor" and bool(cfg.get("allowAuto", true)) and last.has("ratio"):
		buttons.append(["Làm như lần trước (%d%%)" % int(float(last.ratio) * 100.0), func() -> void:
			_complete_once({"ratio": float(last.ratio), "bonus": int(last.get("bonus", 0)), "auto": true})])
	buttons.append(["Thôi  (Esc)", cancel])
	_show_panel(title, "\n\n".join(body), buttons)


## Vào ván: đóng màn đầu, gọi _begin() của cảnh con.
func start() -> void:
	if state != "intro":
		return
	_close_panel()
	state = "play"
	_begin()
	grab_focus()


## Hết ván (hết giờ, hết lượt hay bấm Esc): hiện kết quả thô, bấm Xong thì phát finished.
func end() -> void:
	if state != "play":
		return
	state = "end"
	_sealed_result = result().duplicate(true)
	if cfg.has("session"):
		_sealed_result["session"] = str(cfg.session)
	_sealed_result["completed"] = true
	_show_panel("Hết lượt", summary(_sealed_result), [["Xong  (Space)", submit]])
	queue_redraw()


## A completed round is immutable; rapid clicks/keys cannot emit a second payout.
func submit() -> void:
	if state == "end":
		_complete_once(_sealed_result)


func cancel() -> void:
	if state == "intro":
		_complete_once({})
	elif state == "play":
		end()


func _complete_once(value: Dictionary) -> void:
	if _submitted:
		return
	_submitted = true
	state = "submitted"
	finished.emit(value.duplicate(true))


func _process(delta: float) -> void:
	if state == "play":
		_play(delta)
	queue_redraw()


## Phím đi qua đây; chuột, chạm đi qua _gui_input (không nhận hai lần).
func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	if event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			cancel()
			get_viewport().set_input_as_handled()
			return
		if state != "play" and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and is_instance_valid(_first_button):
			_first_button.pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if state == "play":
		_play_input(event)
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if state == "play" and (event is InputEventMouseButton or event is InputEventScreenTouch):
		_play_input(event)
		accept_event()


# ---------------------------------------------------------------- cảnh con ghi đè

func rules() -> String:
	return ""


func _setup() -> void:
	pass


func _begin() -> void:
	pass


func _play(_delta: float) -> void:
	pass


func _play_input(_event: InputEvent) -> void:
	pass


func result() -> Dictionary:
	return {"score": 0.0, "fails": 0}


func summary(r: Dictionary) -> String:
	return "Đạt %d%% chỉ tiêu" % int(float(r.get("score", 0.0)) * 100.0)


# ---------------------------------------------------------------- khung chữ, nút

func _show_panel(head: String, body: String, buttons: Array) -> void:
	_close_panel()
	_overlay = CenterContainer.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.09, 0.08, 0.94), UI.TIM, 12, 22))
	p.custom_minimum_size.x = minf(600.0, size.x - 40.0)
	_overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(UI.label(head, 26, UI.GOLD))
	var b := UI.label(body, 15, UI.INK)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size.x = p.custom_minimum_size.x - 44.0
	v.add_child(b)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 10)
	v.add_child(row)
	_first_button = null
	for bt in buttons:
		var btn := Button.new()
		btn.text = str(bt[0])
		btn.custom_minimum_size = Vector2(150, 42)
		btn.pressed.connect(bt[1])
		row.add_child(btn)
		if _first_button == null:
			_first_button = btn


func _close_panel() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_first_button = null


# ---------------------------------------------------------------- vẽ chung

## Chữ canh giữa tại center (đường chân chữ ở center.y).
func text_at(center: Vector2, t: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, center - Vector2(w / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Thanh ngang: nền, phần đầy theo ratio 0..1.
func bar_at(r: Rect2, ratio: float, col: Color) -> void:
	draw_rect(r, Color(0, 0, 0, 0.55))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(ratio, 0.0, 1.0), r.size.y)), col)
	draw_rect(r, Color(1, 1, 1, 0.35), false, 1.5)
