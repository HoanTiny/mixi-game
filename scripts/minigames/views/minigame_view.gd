extends "res://scripts/minigames/base_minigame.gd"
## Lớp chung cho các cảnh trò chơi nhỏ vẽ 2D (ném vòng, bê gạch, hàn, sổ sách, nạp ga, cờ tướng, karaoke, máy gắp).
## Thêm vài hàm vẽ cho cảnh trông thật hơn: vật liệu ảnh (Poly Haven CC0, assets/ph/textures), dải chuyển màu, bóng đổ
## mềm, quầng sáng, đĩa nổi khối, tối góc màn hình.

const TEX_STEEL := preload("res://assets/ph/textures/metal_plate/metal_plate_diff.jpg")
const TEX_WOOD := preload("res://assets/ph/textures/fine_grained_wood/fine_grained_wood_diff.jpg")
const TEX_DARK_WOOD := preload("res://assets/ph/textures/dark_wood/dark_wood_diff.jpg")
const TEX_RUSTY := preload("res://assets/ph/textures/rusty_metal_02/rusty_metal_02_diff.jpg")
const TEX_CONCRETE := preload("res://assets/ph/textures/concrete_floor_worn_001/concrete_floor_worn_001_diff.jpg")


func _enter_tree() -> void:
	# Vật liệu ảnh lặp theo ô (tex_fill, đa giác có uv) cần bật lặp texture cho cảnh.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## Vật liệu ảnh phủ kín r, lặp theo cỡ ô tile (điểm ảnh), nhuộm màu tint.
func tex_fill(r: Rect2, tex: Texture2D, tint := Color.WHITE, tile := 256.0) -> void:
	var src := Rect2(Vector2.ZERO, r.size / tile * Vector2(tex.get_size()))
	draw_texture_rect_region(tex, r, src, tint, false, true)


## Hình chữ nhật dải màu dọc (top → bottom) hay ngang (left → right).
func grad_rect(r: Rect2, a: Color, b: Color, vertical := true) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var cols := PackedColorArray([a, a, b, b]) if vertical else PackedColorArray([a, b, b, a])
	draw_polygon(pts, cols)


## Bóng đổ mềm của một hình chữ nhật (vài lớp mờ dần quanh mép), lệch off.
func soft_shadow(r: Rect2, off := Vector2(6, 10), spread := 14.0, alpha := 0.45) -> void:
	for i in 6:
		var k := float(i) / 5.0
		draw_rect(Rect2(r.position + off * 0.6, r.size).grow(spread * k), Color(0, 0, 0, alpha * (1.0 - k) * 0.3), true)
	draw_rect(Rect2(r.position + off, r.size), Color(0, 0, 0, alpha * 0.5))


## Bóng đổ mềm hình tròn.
func soft_shadow_circle(c: Vector2, rad: float, alpha := 0.4) -> void:
	for i in 5:
		var k := float(i) / 4.0
		draw_circle(c, rad * (1.0 + 0.25 * k), Color(0, 0, 0, alpha * (1.0 - k) * 0.4))


## Quầng sáng mịn: ảnh gradient tròn (sáng ở tâm, trong suốt ở mép) phóng theo bán kính, nhuộm màu col.
static var _glow_tex: GradientTexture2D


func glow(c: Vector2, rad: float, col: Color, _layers := 0) -> void:
	if _glow_tex == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.14), Color(1, 1, 1, 0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = gr
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	draw_texture_rect(_glow_tex, Rect2(c - Vector2(rad, rad), Vector2(rad, rad) * 2.0), false, col)


## Đĩa nổi khối (quân cờ, nút bấm, nắp chai): mặt trên sáng dần, viền tối, ánh phản chiếu.
func disc(c: Vector2, rad: float, base: Color, rim: Color) -> void:
	draw_circle(c + Vector2(0, rad * 0.12), rad, base.darkened(0.45))
	draw_circle(c, rad, rim)
	draw_circle(c, rad * 0.9, base)
	for i in 6:
		var k := float(i) / 6.0
		draw_circle(c - Vector2(rad * 0.18, rad * 0.22) * k, rad * 0.9 * (1.0 - k * 0.55), base.lightened(0.05 + 0.05 * k))
	draw_arc(c, rad * 0.78, PI * 1.05, PI * 1.6, 16, Color(1, 1, 1, 0.35), rad * 0.08)


## Tối góc cả khung (ảnh gradient tròn: giữa trong suốt, mép đen) cho cảnh có chiều sâu như ảnh chụp.
static var _vig_tex: GradientTexture2D


func vignette(strength := 0.55) -> void:
	if _vig_tex == null:
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		gr.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.25), Color(0, 0, 0, 1)])
		_vig_tex = GradientTexture2D.new()
		_vig_tex.gradient = gr
		_vig_tex.fill = GradientTexture2D.FILL_RADIAL
		_vig_tex.fill_from = Vector2(0.5, 0.5)
		_vig_tex.fill_to = Vector2(1.05, 1.05)
		_vig_tex.width = 256
		_vig_tex.height = 256
	draw_texture_rect(_vig_tex, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, strength))


## Ống cong (dây cáp, dây ga): đường Bezier bậc hai dày, có viền và vệt sáng.
func hose(a: Vector2, ctrl: Vector2, b: Vector2, width: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		pts.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	draw_polyline(pts, col.darkened(0.5), width + 3.0, true)
	draw_polyline(pts, col, width, true)
	var hl := PackedVector2Array()
	for p in pts:
		hl.append(p + Vector2(-width * 0.18, -width * 0.18))
	draw_polyline(hl, col.lightened(0.35), maxf(1.0, width * 0.22), true)
