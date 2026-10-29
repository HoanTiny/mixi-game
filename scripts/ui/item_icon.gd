extends Control
## Biểu tượng đồ vật vẽ bằng nét và mảng màu (không cần ảnh): điện thoại, túi đồ nghề, căn cước, quạt, áo, chai, lon,
## bìa giấy, chậu cây, tấm hình, giấy tờ, hộp cơm, mèo… Vẽ trong khung 100×100 rồi co theo cỡ ô.

var kind := ""
var tint := Color("d9d2c3")


func _init(k := "", t := Color("d9d2c3")) -> void:
	kind = k
	tint = t
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Đoán hình cho đồ trong truyện (đồ việc nhờ, kỷ vật) theo mã.
static func kind_for(id: String) -> String:
	var map := {"quat": "fan", "com_suat": "rice", "com_tang_ca": "rice", "meo": "cat", "chau_hung": "plant", "hung": "plant",
		"hung_moi": "plant", "ho_so": "paper", "bap": "child", "chai": "bottle", "lon": "can", "giay": "cardboard",
		"tui": "toolbag", "tien_cho": "money", "nha_moi": "key", "mo_let": "key", "chia_linh": "key", "bang": "paper"}
	if map.has(id):
		return map[id]
	if id.begins_with("hinh") or id.begins_with("canh"):
		return "photo"
	if id.begins_with("phieu") or id.contains("ky"):
		return "paper"
	return "box"


func _draw() -> void:
	var k := minf(size.x, size.y) / 100.0
	draw_set_transform((size - Vector2(100, 100) * k) / 2.0, 0.0, Vector2(k, k))
	var ink := Color(0.07, 0.06, 0.05)
	var w := 3.0
	match kind:
		"note":
			draw_line(Vector2(42,68),Vector2(42,24),tint,6,true)
			draw_line(Vector2(42,24),Vector2(76,16),tint,6,true)
			draw_line(Vector2(76,16),Vector2(76,60),tint,6,true)
			draw_circle(Vector2(32,72),12,tint)
			draw_circle(Vector2(66,64),12,tint)
		"phone":
			_rrect(Rect2(30, 10, 40, 80), Color("2a2d33"), ink, w)
			draw_rect(Rect2(34, 18, 32, 60), Color("5b7c99"))
			draw_line(Vector2(36, 22), Vector2(60, 40), Color(1, 1, 1, 0.35), 2)
			draw_line(Vector2(52, 60), Vector2(64, 72), Color(1, 1, 1, 0.5), 1.5)
			draw_circle(Vector2(50, 84), 2.5, Color("8a8f99"))
		"toolbag":
			draw_arc(Vector2(50, 36), 16, PI, TAU, 16, ink, 5)
			_rrect(Rect2(16, 36, 68, 48), Color("6b5a3e"), ink, w)
			draw_line(Vector2(16, 50), Vector2(84, 50), Color("4e4130"), 3)
			draw_rect(Rect2(28, 26, 4, 16), Color("c0392b"))
			draw_rect(Rect2(64, 22, 5, 20), Color("e8b45a"))
			draw_line(Vector2(44, 24), Vector2(48, 42), Color("9aa3ad"), 4)
		"card":
			_rrect(Rect2(12, 26, 76, 50), Color("e9ecef"), ink, w)
			draw_rect(Rect2(18, 34, 22, 28), Color("b9c4cf"))
			draw_circle(Vector2(29, 44), 6, Color("8a6a52"))
			for i in 3:
				draw_line(Vector2(46, 38 + i * 9), Vector2(80 - i * 8, 38 + i * 9), Color("6c757d"), 3)
			draw_rect(Rect2(12, 26, 76, 6), Color("c0392b"))
		"fan":
			draw_line(Vector2(50, 54), Vector2(50, 84), ink, 5)
			_rrect(Rect2(30, 82, 40, 8), Color("e7e2d6"), ink, 2)
			draw_circle(Vector2(50, 40), 30, ink)
			draw_circle(Vector2(50, 40), 27, Color("cfd8dc"))
			for i in 3:
				var a := i * TAU / 3.0 + 0.4
				draw_circle(Vector2(50, 40) + Vector2(cos(a), sin(a)) * 13, 10, Color("5d8aa8"))
			draw_circle(Vector2(50, 40), 5, ink)
			for i in 6:
				var a2 := i * TAU / 6.0
				draw_line(Vector2(50, 40), Vector2(50, 40) + Vector2(cos(a2), sin(a2)) * 27, Color(0, 0, 0, 0.25), 1)
		"key":
			draw_circle(Vector2(32, 50), 16, ink)
			draw_circle(Vector2(32, 50), 13, Color("e8b45a"))
			draw_circle(Vector2(32, 50), 5, Color("1b1b1b"))
			draw_rect(Rect2(44, 46, 42, 8), Color("e8b45a"))
			draw_rect(Rect2(72, 54, 6, 10), Color("e8b45a"))
			draw_rect(Rect2(80, 54, 5, 7), Color("e8b45a"))
		"tshirt", "shirt", "raincoat", "jacket":
			var body: Color = {"tshirt": Color("2b2b2e"), "shirt": Color("b8322c"), "raincoat": Color("4e9fd6", 0.85), "jacket": Color("4f5b52")}[kind]
			var pts := PackedVector2Array([Vector2(34, 14), Vector2(42, 20), Vector2(58, 20), Vector2(66, 14), Vector2(88, 28),
				Vector2(80, 44), Vector2(70, 38), Vector2(70, 88), Vector2(30, 88), Vector2(30, 38), Vector2(20, 44), Vector2(12, 28)])
			if kind == "raincoat":
				pts = PackedVector2Array([Vector2(50, 8), Vector2(66, 18), Vector2(94, 64), Vector2(70, 60), Vector2(68, 92),
					Vector2(32, 92), Vector2(30, 60), Vector2(6, 64), Vector2(34, 18)])
			draw_colored_polygon(pts, body)
			pts.append(pts[0])
			draw_polyline(pts, ink, w)
			if kind == "shirt":
				for x in [38, 46, 54, 62]:
					draw_line(Vector2(x, 22), Vector2(x, 88), Color("5e1612"), 2)
				for y in [36, 48, 60, 72]:
					draw_line(Vector2(30, y), Vector2(70, y), Color("5e1612"), 2)
				draw_line(Vector2(50, 22), Vector2(50, 88), Color("e7e2d6"), 2)
				draw_colored_polygon(PackedVector2Array([Vector2(42, 20), Vector2(50, 30), Vector2(58, 20)]), Color("e7e2d6"))
			elif kind == "jacket":
				draw_line(Vector2(50, 22), Vector2(50, 88), Color("c9ced3"), 3)
				draw_rect(Rect2(36, 60, 10, 10), Color("3b453e"))
				draw_rect(Rect2(54, 60, 10, 10), Color("3b453e"))
				draw_rect(Rect2(30, 82, 40, 6), Color("3d5a80"))
			elif kind == "tshirt":
				draw_rect(Rect2(30, 84, 40, 4), Color("3d5a80"))
		"pants":
			var pts := PackedVector2Array([Vector2(30,14),Vector2(70,14),Vector2(76,90),Vector2(55,90),Vector2(50,46),Vector2(45,90),Vector2(24,90)])
			draw_colored_polygon(pts,Color("526b7e"))
			pts.append(pts[0]); draw_polyline(pts,ink,w)
			draw_line(Vector2(30,23),Vector2(70,23),Color("a1a99d"),2)
			draw_line(Vector2(50,24),Vector2(50,44),ink,2)
			draw_line(Vector2(33,32),Vector2(40,40),Color("8495a1"),2)
			draw_line(Vector2(67,32),Vector2(60,40),Color("8495a1"),2)
		"bottle":
			_rrect(Rect2(36, 30, 28, 60), Color("a8d8ea", 0.8), ink, w)
			draw_rect(Rect2(42, 12, 16, 20), Color("a8d8ea", 0.8))
			draw_rect(Rect2(41, 8, 18, 7), Color("2e86c1"))
			draw_rect(Rect2(36, 50, 28, 16), Color("27ae60"))
		"can":
			_rrect(Rect2(32, 18, 36, 70), Color("c9ced3"), ink, w)
			draw_rect(Rect2(32, 36, 36, 30), Color("c0392b"))
			draw_line(Vector2(36, 50), Vector2(64, 50), Color(1, 1, 1, 0.6), 3)
		"cardboard":
			draw_colored_polygon(PackedVector2Array([Vector2(14, 40), Vector2(50, 26), Vector2(86, 40), Vector2(86, 78), Vector2(50, 92), Vector2(14, 78)]), Color("b8875a"))
			draw_polyline(PackedVector2Array([Vector2(14, 40), Vector2(50, 54), Vector2(86, 40)]), Color("8a6240"), 3)
			draw_line(Vector2(50, 54), Vector2(50, 92), Color("8a6240"), 3)
			draw_polyline(PackedVector2Array([Vector2(14, 40), Vector2(50, 26), Vector2(86, 40), Vector2(86, 78), Vector2(50, 92), Vector2(14, 78), Vector2(14, 40)]), ink, w)
		"plant":
			draw_colored_polygon(PackedVector2Array([Vector2(28, 56), Vector2(72, 56), Vector2(64, 90), Vector2(36, 90)]), Color("8d5a3b"))
			draw_rect(Rect2(26, 52, 48, 8), Color("a0694a"))
			for p in [Vector2(40, 34), Vector2(58, 30), Vector2(50, 20), Vector2(34, 46), Vector2(66, 44)]:
				draw_line(Vector2(50, 52), p, Color("2e7d32"), 2)
				draw_circle(p, 8, Color("43a047"))
		"photo":
			draw_set_transform((size - Vector2(100, 100) * k) / 2.0 + Vector2(50, 50) * k, -0.12, Vector2(k, k))
			_rrect(Rect2(-36, -30, 72, 60), Color("f4efe4"), ink, w)
			draw_rect(Rect2(-30, -24, 60, 40), Color("7fa7bd"))
			draw_colored_polygon(PackedVector2Array([Vector2(-30, 16), Vector2(-8, -6), Vector2(8, 8), Vector2(18, 0), Vector2(30, 16)]), Color("5b7f4b"))
			draw_circle(Vector2(16, -12), 5, Color("f2c14e"))
		"paper":
			_rrect(Rect2(24, 12, 52, 76), Color("f4efe4"), ink, w)
			for i in 6:
				draw_line(Vector2(32, 26 + i * 9), Vector2(68 - (i % 3) * 6, 26 + i * 9), Color("6c757d"), 2)
			draw_circle(Vector2(62, 76), 7, Color("c0392b", 0.75))
		"rice":
			draw_colored_polygon(PackedVector2Array([Vector2(14, 50), Vector2(86, 50), Vector2(76, 84), Vector2(24, 84)]), Color("e7e2d6"))
			draw_arc(Vector2(50, 50), 30, PI, TAU, 18, Color("faf6ec"), 18)
			draw_rect(Rect2(40, 34, 22, 8), Color("b5651d"))
			draw_polyline(PackedVector2Array([Vector2(14, 50), Vector2(86, 50), Vector2(76, 84), Vector2(24, 84), Vector2(14, 50)]), ink, w)
		"cat":
			draw_circle(Vector2(50, 62), 26, Color("1f1f22"))
			draw_circle(Vector2(50, 36), 18, Color("1f1f22"))
			draw_colored_polygon(PackedVector2Array([Vector2(34, 30), Vector2(36, 12), Vector2(46, 22)]), Color("1f1f22"))
			draw_colored_polygon(PackedVector2Array([Vector2(66, 30), Vector2(64, 12), Vector2(54, 22)]), Color("1f1f22"))
			draw_circle(Vector2(43, 36), 3.5, Color("e8d44d"))
			draw_circle(Vector2(57, 36), 3.5, Color("e8d44d"))
			draw_arc(Vector2(78, 80), 14, -PI / 2, PI / 2, 10, Color("1f1f22"), 5)
		"child":
			draw_circle(Vector2(50, 28), 14, Color("c99a74"))
			draw_arc(Vector2(50, 26), 14, PI, TAU, 12, Color("1f1f22"), 8)
			draw_colored_polygon(PackedVector2Array([Vector2(32, 46), Vector2(68, 46), Vector2(72, 80), Vector2(28, 80)]), Color("e67e22"))
			draw_rect(Rect2(36, 80, 10, 12), Color("2c3e50"))
			draw_rect(Rect2(54, 80, 10, 12), Color("2c3e50"))
		"money":
			for i in 3:
				_rrect(Rect2(16 + i * 4, 30 + i * 8, 64, 34), Color("7bb38a") if i < 2 else Color("e8a0b0"), ink, 2)
			draw_circle(Vector2(56, 63), 8, Color(1, 1, 1, 0.5))
		# Biểu tượng nhu cầu ở cột phải.
		"bowl":
			var pts := PackedVector2Array()
			for i in 17:
				var a := PI * i / 16.0
				pts.append(Vector2(50, 48) + Vector2(cos(a) * 38, sin(a) * 34))
			draw_colored_polygon(pts, Color("e7e2d6"))
			draw_rect(Rect2(10, 44, 80, 6), Color("faf6ec"))
			draw_circle(Vector2(50, 42), 20, Color("faf6ec"))
			draw_rect(Rect2(28, 42, 44, 6), Color("faf6ec"))
			draw_line(Vector2(56, 8), Vector2(78, 40), Color("b5651d"), 4)
			draw_line(Vector2(66, 6), Vector2(86, 38), Color("b5651d"), 4)
		"drop":
			draw_colored_polygon(PackedVector2Array([Vector2(50, 10), Vector2(74, 52), Vector2(70, 72), Vector2(50, 88), Vector2(30, 72), Vector2(26, 52)]), Color("4fa3d9"))
			draw_circle(Vector2(50, 62), 24, Color("4fa3d9"))
			draw_arc(Vector2(50, 62), 14, PI * 0.6, PI * 1.1, 8, Color(1, 1, 1, 0.7), 4)
		"moon":
			draw_circle(Vector2(50, 50), 32, Color("f2d27a"))
			draw_circle(Vector2(64, 40), 28, Color("2b2b2e"))
			draw_circle(Vector2(30, 30), 3, Color("f2d27a"))
			draw_circle(Vector2(78, 76), 2.5, Color("f2d27a"))
		"heart":
			draw_circle(Vector2(34, 38), 18, Color("e85d75"))
			draw_circle(Vector2(66, 38), 18, Color("e85d75"))
			draw_colored_polygon(PackedVector2Array([Vector2(17, 46), Vector2(83, 46), Vector2(50, 86)]), Color("e85d75"))
			draw_circle(Vector2(30, 32), 5, Color(1, 1, 1, 0.5))
		"bolt":
			draw_colored_polygon(PackedVector2Array([Vector2(58, 6), Vector2(22, 56), Vector2(46, 56), Vector2(38, 94), Vector2(78, 40),
				Vector2(54, 40)]), Color("f2c14e"))
			draw_polyline(PackedVector2Array([Vector2(58, 6), Vector2(22, 56), Vector2(46, 56), Vector2(38, 94), Vector2(78, 40),
				Vector2(54, 40), Vector2(58, 6)]), Color(0.3, 0.2, 0.05), 3)
		# Biểu tượng nét mảnh trên thanh trên cùng (màu tint).
		"person":
			draw_arc(Vector2(50, 32), 15, 0, TAU, 24, tint, 6)
			draw_arc(Vector2(50, 92), 34, PI * 1.12, PI * 1.88, 20, tint, 6)
		"book":
			draw_polyline(PackedVector2Array([Vector2(50, 26), Vector2(14, 18), Vector2(14, 80), Vector2(50, 88), Vector2(86, 80), Vector2(86, 18), Vector2(50, 26), Vector2(50, 88)]), tint, 6)
			for y in [40, 54]:
				draw_line(Vector2(24, y - 6), Vector2(42, y - 2), tint, 4)
				draw_line(Vector2(58, y - 2), Vector2(76, y - 6), tint, 4)
		"list":
			draw_polyline(PackedVector2Array([Vector2(24, 12), Vector2(76, 12), Vector2(76, 90), Vector2(24, 90), Vector2(24, 12)]), tint, 6)
			for y in [32, 50, 68]:
				draw_line(Vector2(36, y), Vector2(64, y), tint, 5)
		"phone_line":
			draw_polyline(PackedVector2Array([Vector2(32, 8), Vector2(68, 8), Vector2(68, 92), Vector2(32, 92), Vector2(32, 8)]), tint, 6)
			draw_line(Vector2(44, 80), Vector2(56, 80), tint, 5)
		"map":
			var m := PackedVector2Array([Vector2(10, 22), Vector2(36, 12), Vector2(64, 22), Vector2(90, 12), Vector2(90, 78), Vector2(64, 88),
				Vector2(36, 78), Vector2(10, 88), Vector2(10, 22)])
			draw_polyline(m, tint, 6)
			draw_line(Vector2(36, 12), Vector2(36, 78), tint, 4)
			draw_line(Vector2(64, 22), Vector2(64, 88), tint, 4)
		"zoom":
			draw_arc(Vector2(42, 42), 26, 0, TAU, 28, tint, 6)
			draw_line(Vector2(62, 62), Vector2(88, 88), tint, 9)
			draw_line(Vector2(30, 42), Vector2(54, 42), tint, 5)
		"house":
			draw_polyline(PackedVector2Array([Vector2(8, 50), Vector2(50, 12), Vector2(92, 50)]), tint, 7)
			draw_polyline(PackedVector2Array([Vector2(20, 42), Vector2(20, 88), Vector2(80, 88), Vector2(80, 42)]), tint, 6)
			draw_rect(Rect2(42, 60, 16, 28), tint)
		"cash":
			draw_polyline(PackedVector2Array([Vector2(8, 28), Vector2(92, 28), Vector2(92, 76), Vector2(8, 76), Vector2(8, 28)]), tint, 6)
			draw_arc(Vector2(50, 52), 12, 0, TAU, 20, tint, 5)
			draw_line(Vector2(20, 18), Vector2(84, 18), tint, 4)
		_:
			_rrect(Rect2(20, 30, 60, 54), Color("b8875a"), ink, w)
			draw_rect(Rect2(46, 30, 8, 54), Color("c0392b"))
			draw_rect(Rect2(20, 52, 60, 8), Color("c0392b"))


func _rrect(r: Rect2, fill: Color, line: Color, width: float) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = line
	sb.set_border_width_all(int(width))
	sb.set_corner_radius_all(int(minf(r.size.x, r.size.y) * 0.14))
	draw_style_box(sb, r)
