extends SceneTree
## Kiểm thử áp lực sinh tồn chương 1 (scripts/systems/hardship.gd): tiền khởi đầu, tiền trọ, tắm nước lạnh, giặt đồ,
## việc thưởng nóng, mục tiêu ngắn hạn, tổng kết ngày. Chạy: Godot --headless --path . -s res://tests/hardship.gd

const GameLogic := preload("res://scripts/game_logic.gd")
const Hardship := preload("res://scripts/systems/hardship.gd")

var fails := 0


func _ok(cond: bool, what: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + what)
	if not cond:
		fails += 1


func _new() -> GameLogic:
	var g := GameLogic.new()
	g.load_data()
	g.new_game("full")
	g.s.queue.clear()
	g._commit()
	return g


func _init() -> void:
	seed(5)
	var g := _new()
	_ok(int(g.s.cash) == 50000, "ngày 1 trong túi 50.000đ (đang %s)" % GameLogic.fmt_money(int(g.s.cash)))
	_ok(g.living_cost() == 0, "chương 1 bỏ tiền sinh hoạt cả nhà tự trừ mỗi tối")
	var nghi: Dictionary = g.get_action("nghi")
	_ok(str(g.action_status(nghi).reason).begins_with("Chưa trả tiền trọ"), "chưa trả tiền trọ: khóa Nghỉ ở phòng (%s)" % g.action_status(nghi).reason)
	_ok(Hardship.sleep_lock(g) != "", "chưa trả tiền trọ: khóa đi ngủ")
	var tra: Dictionary = g.get_action("tra_tien_tro")
	_ok(not g.is_hidden(tra) and int(tra.cost) == 60000, "có việc trả tiền trọ 60.000đ ở chỗ ở")
	_ok(g.action_status(tra).reason != "", "50.000đ chưa đủ tiền trọ: phải đi làm trước (%s)" % g.action_status(tra).reason)
	g.s["cash"] = 50000 + 120000
	g.do_action("tra_tien_tro")
	_ok(Hardship.paid(g) and int(g.s.cash) == 110000 and g.action_status(nghi).ok and Hardship.sleep_lock(g) == "", "đi làm có 170.000đ, trả 60.000đ: mở khóa nghỉ, đi ngủ")
	_ok(g.is_hidden(tra), "trả rồi thì ẩn việc trả tiền trọ")
	# Tắm nước lạnh: +40 Vệ sinh, cảm lạnh khoảng 25%.
	var colds := 0
	var gain := 0.0
	for i in 200:
		var gt := _new()
		gt.s["seed"] = i
		gt.s.needs["clean"] = 10.0
		gt.do_action("tam_rua")
		gain += gt.need("clean") - 10.0
		if gt.Survival.has(gt, "cam_lanh"):
			colds += 1
	_ok(absf(gain / 200.0 - 40.0) < 3.0, "tắm nước lạnh hồi khoảng 40 Vệ sinh (%.1f)" % (gain / 200.0))
	_ok(colds > 30 and colds < 75, "200 lần tắm: %d lần cảm lạnh (khoảng 25%%)" % colds)
	# Giặt: cần xà phòng hay gửi tiệm.
	var gg := _new()
	gg.s["cash"] = 200000
	_ok(gg.action_status(gg.get_action("giat_do")).reason != "", "chưa có xà phòng: khóa tự giặt (%s)" % gg.action_status(gg.get_action("giat_do")).reason)
	gg.s.needs["neat"] = 20.0
	gg.do_action("giat_tiem")
	_ok(gg.need("neat") >= 99.0 and int(gg.s.cash) == 180000, "gửi tiệm giặt 20.000đ: quần áo sạch")
	gg.s["used"] = 8.0 - float(gg.cfg.dayStart)
	gg.do_action("mua_xa_phong")
	_ok(int(gg.s.qitems.get("xa_phong", 0)) == 3, "mua xà phòng 15.000đ được 3 lần giặt")
	# Hết ngày chưa trả, không đủ tiền: nợ một đêm.
	var gd := _new()
	gd.s["cash"] = 20000
	var mood0: float = gd.need("mood")
	var duyen0 := int(gd.s.rep.get("DUYEN", 0))
	gd.finish_day()
	_ok(int(gd.s.hard.debt) == 1 and int(gd.s.rep.get("DUYEN", 0)) < duyen0, "không đủ tiền trọ: nợ một đêm, cô Duyên không vui")
	# Đủ tiền mà quên trả: tự trừ lúc qua đêm.
	var ga := _new()
	ga.s["cash"] = 100000
	ga.finish_day()
	_ok(int(ga.s.hard.debt) == 0 and int(ga.s.cash) == 40000, "quên trả mà đủ tiền: tự trừ 60.000đ lúc qua đêm")
	# Việc thưởng nóng.
	var hot := Hardship.hot(ga)
	_ok(hot != "", "sáng ngày 2 có việc thưởng nóng: " + hot)
	if hot != "":
		var a: Dictionary = ga.get_action(hot)
		ga.s["cash"] = 0
		ga.s["used"] = float(a.get("window", [ga.cfg.dayStart])[0]) - float(ga.cfg.dayStart)
		var st: Dictionary = ga.action_status(a)
		if st.ok:
			ga.do_action(hot)
			_ok(int(ga.s.cash) >= int(a.pay) * 2 * 0.5, "làm việc thưởng nóng %s: nhận %s (lương gốc %s)" % [hot, GameLogic.fmt_money(int(ga.s.cash)), GameLogic.fmt_money(int(a.pay))])
		else:
			print("    (việc thưởng nóng chưa làm được lúc này: %s)" % st.reason)
	# Mục tiêu ngắn hạn.
	var goal := Hardship.goal(g)
	_ok(str(goal.get("id", "")) == "phong" and int(goal.need) == 1800000, "mục tiêu đầu: %s %s" % [goal.get("name", ""), GameLogic.fmt_money(int(goal.get("need", 0)))])
	g.housing()["state"] = "reserved"
	_ok(str(Hardship.goal(g).get("id", "")) == "dien_thoai", "cọc phòng xong thì sang mục tiêu smartphone")
	# Tổng kết ngày.
	var gs := _new()
	gs.s["used"] = 13.0 - float(gs.cfg.dayStart)
	gs.do_action("phat_to_roi")
	var sm := Hardship.day_summary(gs)
	_ok(int(sm.earned) > 0 and not sm["in"].is_empty(), "tổng kết ngày: thu %s, %d khoản thu" % [GameLogic.fmt_money(int(sm.earned)), sm["in"].size()])
	# Lát cắt (không chơi đủ) giữ luật cũ.
	var sl := GameLogic.new()
	sl.load_data()
	sl.new_game("B")
	_ok(not Hardship.on(sl) and int(sl.s.cash) > 1000000 and Hardship.paid(sl), "lát cắt ngày 18–22 giữ luật cũ")
	print("\n%s" % ("TẤT CẢ ĐẠT" if fails == 0 else "%d MỤC HỎNG" % fails))
	quit(1 if fails > 0 else 0)
