extends Node
## Autoload ScreenFit: co giao diện theo màn hình và máy.
## - Máy tính: chữ, nút giữ đúng cỡ thiết kế theo mật độ điểm ảnh (màn retina không bé lại); cửa sổ nhỏ hơn
##   DESIGN_SIZE thì thu cả giao diện cho vừa.
## - Màn thấp như điện thoại nằm ngang (cao dưới COMPACT_BELOW điểm CSS): chế độ gọn, giao diện bày cho khoảng
##   COMPACT_SIZE điểm, chữ đủ đọc, nút đủ to cho ngón tay; hud.gd, street_map.gd đổi bố cục theo tín hiệu changed.
## - Máy cảm ứng: ẩn dòng phím tắt, lời nhắc E thành nút chạm; màn dọc thì nhắc xoay ngang.
## - Điện thoại, máy tính bảng: cảnh 3D vẽ ở độ nét thấp hơn (giao diện vẫn nét), bóng nắng nhẹ hơn (world.gd đọc
##   low_power); trình duyệt máy tính màn mật độ cao cũng vẽ cảnh 3D thưa bớt điểm ảnh.

signal changed

const DESIGN_SIZE := Vector2(1280, 720)
const COMPACT_SIZE := Vector2(1100, 520)
const COMPACT_BELOW := 560.0
## Điện thoại: cảnh 3D vẽ chừng này điểm ảnh mỗi điểm CSS (iPhone mật độ 3 thì vẽ một nửa số điểm mỗi chiều).
const PHONE_3D_DENSITY := 1.5
## Trình duyệt máy tính (màn retina, 4K): cảnh 3D vẽ chừng này điểm ảnh mỗi điểm CSS.
const WEB_3D_DENSITY := 1.25

## Mật độ điểm ảnh (window.devicePixelRatio trên web), máy cảm ứng, chế độ gọn, máy yếu (điện thoại, máy tính bảng),
## hệ số co giao diện đang dùng.
var dpr := 1.0
var touch := false
var compact := false
var low_power := false
## Bóng nắng nhẹ (hai tầng, bản đồ bóng nhỏ): máy yếu và mọi trình duyệt (WebGL vẽ lại cả phố cho mỗi tầng bóng).
var light_shadows := false
var ui_scale := 1.0
var _rotate: CanvasLayer
var _rotate_dismissed := false


func _ready() -> void:
	dpr = _device_pixel_ratio()
	touch = DisplayServer.is_touchscreen_available()
	low_power = OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios")
	light_shadows = low_power or OS.has_feature("web")
	for a in OS.get_cmdline_user_args():
		# Thử trên máy tính: --phone giả làm điện thoại (cảm ứng, máy yếu), --dpr=3 giả mật độ điểm ảnh.
		if a == "--phone":
			touch = true
			low_power = true
			light_shadows = true
		elif a == "--web":
			light_shadows = true
		elif a.begins_with("--dpr="):
			dpr = float(a.substr(6))
	get_tree().root.size_changed.connect(_fit)
	_fit()


func _device_pixel_ratio() -> float:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		return maxf(1.0, float(v)) if v != null else 1.0
	return maxf(1.0, DisplayServer.screen_get_scale())


func _fit() -> void:
	var root := get_tree().root
	var win := Vector2(root.size)
	if win.x < 2.0 or win.y < 2.0:
		return
	var css := win / dpr
	compact = css.y < COMPACT_BELOW or css.x < 760.0
	var target := COMPACT_SIZE if compact else DESIGN_SIZE
	ui_scale = maxf(0.5, minf(dpr, minf(win.x / target.x, win.y / target.y)))
	root.content_scale_factor = ui_scale
	if low_power:
		root.scaling_3d_scale = clampf(PHONE_3D_DENSITY / dpr, 0.4, 1.0)
	elif OS.has_feature("web"):
		# Trình duyệt máy tính màn mật độ cao: cảnh 3D vẽ chừng WEB_3D_DENSITY điểm mỗi điểm CSS (giao diện vẫn nét).
		root.scaling_3d_scale = clampf(WEB_3D_DENSITY / dpr, 0.5, 1.0)
	_update_rotate(win)
	changed.emit()


## Kích thước vùng giao diện tính theo điểm thiết kế (sau khi co).
func view_size() -> Vector2:
	return Vector2(get_tree().root.size) / ui_scale


## Màn dọc trên máy cảm ứng: tấm nhắc xoay ngang (có nút chơi luôn màn dọc).
func _update_rotate(win: Vector2) -> void:
	var want := touch and win.y > win.x * 1.1 and not _rotate_dismissed
	if want and _rotate == null:
		_rotate = CanvasLayer.new()
		_rotate.layer = 120
		add_child(_rotate)
		var bg := ColorRect.new()
		bg.color = Color(0.06, 0.07, 0.1, 0.94)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rotate.add_child(bg)
		var center := CenterContainer.new()
		center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_rotate.add_child(center)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 18)
		center.add_child(v)
		# Hình chiếc điện thoại nằm ngang vẽ bằng khung (font chữ không có ký tự mũi tên xoay).
		var icon := Panel.new()
		var frame := StyleBoxFlat.new()
		frame.bg_color = Color(0, 0, 0, 0)
		frame.border_color = Color(0.92, 0.93, 0.96)
		frame.set_border_width_all(4)
		frame.set_corner_radius_all(10)
		icon.add_theme_stylebox_override("panel", frame)
		icon.custom_minimum_size = Vector2(96, 56)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var msg := Label.new()
		msg.text = "Xoay ngang điện thoại để chơi\ncho dễ nhìn phố và bấm nút."
		msg.add_theme_font_size_override("font_size", 22)
		msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(msg)
		var full := Button.new()
		full.text = "Toàn màn hình"
		full.custom_minimum_size = Vector2(260, 56)
		full.pressed.connect(func() -> void: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN))
		v.add_child(full)
		var keep := Button.new()
		keep.text = "Vẫn chơi màn dọc"
		keep.custom_minimum_size = Vector2(260, 56)
		keep.pressed.connect(func() -> void:
			_rotate_dismissed = true
			_rotate.visible = false)
		v.add_child(keep)
	if _rotate != null:
		_rotate.visible = want
