extends SceneTree
## Kiểm thử logic quan hệ NPC (relationships.gd) và kinh tế buôn bán (commerce.gd), không cần màn 3D.
## Chạy: Godot --headless --path . -s res://tests/relationships_commerce.gd

const GameLogic := preload("res://scripts/game_logic.gd")
const Rel := preload("res://scripts/systems/relationships.gd")
const Biz := preload("res://scripts/systems/commerce.gd")

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
	return g


func _drain(g: GameLogic) -> Array:
	var seen := []
	while not g.s.queue.is_empty():
		seen.append(str(g.s.queue[0].id))
		g.resolve_choice(0)
	return seen


func _init() -> void:
	seed(7)
	_relationships()
	_commerce()
	print("\n%s" % ("TẤT CẢ ĐẠT" if fails == 0 else "%d MỤC HỎNG" % fails))
	quit(1 if fails > 0 else 0)


func _relationships() -> void:
	print("== Quan hệ NPC")
	var g := _new()
	_ok(int(g.s.rep.get("HAN", -1)) == 20, "Hân bắt đầu ở 20 điểm, bậc " + str(Rel.tier(g, "HAN").name))
	g.add_rep("HAN", 16)
	g._commit()
	_ok(g.s.rel.unlocked.has("han_xin_so"), "qua 35 điểm: mở tin nhắn xin số")
	g.s["used"] = 21.0 - float(g.cfg.dayStart)
	g._commit()
	_ok(Rel.unread(g) >= 1, "tin nhắn tới máy sau 20:00 (chưa đọc: %d)" % Rel.unread(g))
	var th := Rel.thread(g, "HAN")
	var before := int(g.s.rep.HAN)
	_ok(Rel.reply(g, int(th[0].i), 1) == "", "trả lời tin nhắn")
	_ok(int(g.s.rep.HAN) > before, "trả lời được cộng điểm (%d → %d)" % [before, int(g.s.rep.HAN)])
	_ok(Rel.reply(g, int(th[0].i), 0) != "", "không trả lời lại lần hai")
	g.add_rep("HAN", 14)
	g._commit()
	var ev := _drain(g)
	_ok(ev.has("rel_han_chuot"), "qua 50 điểm: cảnh bắt chuột ở kho hoa (%s)" % str(ev))
	g.add_rep("HAN", 10)
	g._commit()
	ev = _drain(g)
	_ok(ev.has("rel_han_con_do") and g.s.flags.get("phoHanQuaChuyen", false), "qua 65: cảnh phí đứng đường, đặt cờ")
	g.s.rep["HAN"] = 84
	g._commit()
	ev = _drain(g)
	_ok(ev.has("rel_han_to_tinh"), "qua 82: cảnh tỏ tình")
	_ok(Rel.status(g, "HAN") == "cap_doi" and g.Survival.has(g, "cap_doi"), "chọn nói thật: thành Cặp đôi, có trạng thái cap_doi")
	_ok(g.mod("regen.mood") > 0.0 and g.mod("fatigue.rate") < 0.0, "buff: regen.mood %+.1f/giờ, fatigue.rate %+.2f" % [g.mod("regen.mood"), g.mod("fatigue.rate")])
	# Hồi Tâm trạng theo giờ: so hai lượt, có và không có buff.
	var g2 := _new()
	for gg in [g, g2]:
		gg.s.needs["mood"] = 50.0
		gg.s["needs_t"] = gg.clock()
		gg.s["used"] = float(gg.s.used) + 4.0
		gg._tick_needs()
	_ok(g.need("mood") > g2.need("mood") + 5.0, "4 giờ: Tâm trạng có người thương %.1f so với %.1f" % [g.need("mood"), g2.need("mood")])
	var f1 := float(g.s.fatigue)
	var f2 := float(g2.s.fatigue)
	g.add_fatigue(20.0)
	g2.add_fatigue(20.0)
	_ok(float(g.s.fatigue) - f1 < float(g2.s.fatigue) - f2, "mệt chậm hơn (+%.1f so với +%.1f)" % [float(g.s.fatigue) - f1, float(g2.s.fatigue) - f2])
	# Phai nhạt: 7 ngày không gặp thì tụt, dưới 60 thì mất Cặp đôi và có cảnh nguội lạnh.
	g.s.rep["HAN"] = 66
	g.s.rel.seen["HAN"] = g.day()
	for i in 7:
		g.s["day"] = int(g.s.day) + 1
		g._commit()
	ev = _drain(g)
	_ok(int(g.s.rep.HAN) < 66, "7 ngày không gặp: Hân %d" % int(g.s.rep.HAN))
	_ok(Rel.status(g, "HAN") == "" and not g.Survival.has(g, "cap_doi") and ev.has("rel_han_nguoi"), "nguội đi: mất Cặp đôi, gỡ buff, có cảnh")
	_ok(not Rel.npcs_at(g, "vendor:hoa").is_empty(), "xe hoa có thẻ nói chuyện với Hân")


func _commerce() -> void:
	print("== Kinh tế buôn bán")
	var g := _new()
	g.s["cash"] = 5000000
	var p0 := Biz.buy_price(g, "hoa_hong")
	_ok(p0 > 0 and Biz.sell_price(g, "hoa_hong") > p0, "giá nhập %s < giá bán %s" % [GameLogic.fmt_money(p0), GameLogic.fmt_money(Biz.sell_price(g, "hoa_hong"))])
	# Giá biến động qua 20 ngày, nằm trong khung.
	var lo := 9.0
	var hi := 0.0
	var gx := _new()
	for i in 20:
		gx.s["day"] = int(gx.s.day) + 1
		gx._commit()
		var m: Dictionary = Biz.market(gx, "quat_mini")
		lo = minf(lo, float(m.base))
		hi = maxf(hi, float(m.base))
	_ok(hi - lo > 0.05 and lo >= 0.7 and hi <= 1.5, "giá quạt mini đi trong [%.2f, %.2f]" % [lo, hi])
	# Nhập sỉ ở chợ Long Biên.
	Biz.refresh(g)
	var cash0 := int(g.s.cash)
	g.s["used"] = 13.0 - float(g.cfg.dayStart)
	g.do_action("biz_nhap_hoa_hong")
	_ok(Biz.qty(g, "hoa_hong", "cart") == 50 and int(g.s.cash) == cash0 - p0 * 50, "nhập 50 bông, trả %s" % GameLogic.fmt_money(cash0 - int(g.s.cash)))
	var lock: String = g.action_status(g.get_action("biz_nhap_ao_mua")).reason
	_ok(lock != "", "xe đẩy %d chỗ đã có 50 bông: khóa nhập thêm lô 30 áo mưa (%s)" % [Biz.cart_cap(g), lock])
	# Bày bán ở bờ hồ buổi tối.
	g.s["used"] = 19.0 - float(g.cfg.dayStart)
	var cash1 := int(g.s.cash)
	var had := Biz.qty(g, "", "cart")
	g.do_action("biz_ban_ho_guom")
	var sold := had - Biz.qty(g, "", "cart")
	print("    " + str(g.s.biz.last.text))
	_ok(sold > 0 and (int(g.s.cash) > cash1 or int(g.s.biz.stats.fined) > 0), "bán được %d món ở bờ hồ, tiền %s" % [sold, GameLogic.fmt_money(int(g.s.cash) - cash1)])
	# Trật tự đô thị: 40 lượt bán ở bờ hồ, phải có lượt bị bắt.
	var caught := 0
	var revenue := 0
	for i in 40:
		var gt := _new()
		gt.s["cash"] = 2000000
		gt.s["used"] = 13.0 - float(gt.cfg.dayStart)
		Biz.refresh(gt)
		gt.do_action("biz_nhap_hoa_hong")
		gt.s["used"] = 19.0 - float(gt.cfg.dayStart)
		var c := int(gt.s.cash)
		gt.do_action("biz_ban_ho_guom")
		caught += int(gt.s.biz.stats.fined)
		revenue += int(gt.s.cash) - c
	_ok(caught > 2 and caught < 25, "40 tối bán ở bờ hồ: %d lần bị trật tự đô thị bắt, trung bình thu %s" % [caught, GameLogic.fmt_money(revenue / 40)])
	# Hoa héo sau 2 ngày.
	var gh := _new()
	gh.s["cash"] = 1000000
	Biz.refresh(gh)
	gh.s["used"] = 8.0 - float(gh.cfg.dayStart)
	gh.do_action("biz_nhap_hoa_hong")
	for i in 2:
		gh.s["day"] = int(gh.s.day) + 1
		gh._commit()
	_ok(Biz.qty(gh, "hoa_hong") == 0, "hoa để 2 ngày thì héo hết")
	# Áo mưa ngày mưa ở điểm xe buýt.
	var dry := _rain_sale(false)
	var wet := _rain_sale(true)
	_ok(wet > dry * 2, "áo mưa ở điểm xe buýt lúc tan tầm: trời khô bán %d, trời mưa bán %d" % [dry, wet])
	# Livestream: khóa khi chưa học, chưa có kho.
	var gl := _new()
	gl.s["cash"] = 5000000
	_ok(Biz.live_lock(gl) != "", "chưa học chị Vy: khóa live (%s)" % Biz.live_lock(gl))
	gl.s.flags["phoVyLive"] = true
	gl.s.attr.per.lv = 2
	_ok(Biz.live_lock(gl) == "Cần thuê kho trước", "học rồi nhưng chưa có kho: " + Biz.live_lock(gl))
	gl.s["used"] = 8.0 - float(gl.cfg.dayStart)
	gl.do_action("biz_thue_kho")
	Biz.refresh(gl)
	for i in 3:
		gl.do_action("biz_nhap_ao_thun")
	gl.do_action("biz_cat_kho")
	_ok(Biz.qty(gl, "ao_thun", "kho") == 30, "thuê kho, nhập 30 áo phông, cất vào kho")
	_ok(Biz.live_lock(gl) == "", "đủ điều kiện lên sóng")
	# Màn live chạy tay: voucher đúng lúc đỉnh, so với voucher lúc mở sóng.
	var peak_orders := _live_orders(true)
	var early_orders := _live_orders(false)
	_ok(peak_orders > early_orders, "voucher lúc đông người xem chốt nhiều hơn lúc mở sóng (%d so với %d đơn, trung bình 20 lượt)" % [peak_orders, early_orders])
	gl.s["used"] = 19.0 - float(gl.cfg.dayStart)
	var st := Biz.live_begin(gl, "xa_kho", 1, 0)
	while not Biz.live_done(st):
		Biz.live_beat(gl, st, {"reply": true, "voucher": int(st.beat) == int(st.peak)})
	Biz.live_store(gl, st)
	var cash2 := int(gl.s.cash)
	gl.do_action("biz_live_xom_bo_me")
	_ok(gl.s.biz.orders.size() > 0 and int(gl.s.cash) < cash2, "live xả kho: %d đơn chờ giao, trả công người chốt đơn" % int(st.total))
	print("    " + str(gl.s.biz.last.text))
	var rep0 := float(gl.s.biz.rep)
	var cash3 := int(gl.s.cash)
	for i in 3:
		gl.s["day"] = int(gl.s.day) + 1
		gl._commit()
	_ok(gl.s.biz.orders.is_empty(), "sau 2 ngày mọi đơn có kết quả")
	print("    tiền về %s, hoàn %d món, uy tín %.1f → %.1f" % [GameLogic.fmt_money(int(gl.s.cash) - cash3), int(gl.s.biz.stats.returned), rep0, float(gl.s.biz.rep)])
	# Tỷ lệ hoàn: xả kho nhiều hơn review thật thà.
	var rx := _return_rate("xa_kho", 0)
	var rr := _return_rate("review", 0)
	var rl := _return_rate("ke_chuyen", 99)
	_ok(rx > rr, "tỷ lệ hoàn: xả kho %.0f%% > review %.0f%%" % [rx * 100, rr * 100])
	var rk := _return_rate("ke_chuyen", 0)
	_ok(rl > rk, "đóng gói không kịp: tỷ lệ hoàn %.0f%% so với giao đúng hẹn %.0f%%" % [rl * 100, rk * 100])
	# Kho không quạt hút ẩm: áo mốc dần ngày mưa.
	var gm := _new()
	gm.s["cash"] = 3000000
	gm.do_action("biz_thue_kho")
	Biz.refresh(gm)
	gm.do_action("biz_nhap_ao_thun")
	gm.do_action("biz_cat_kho")
	for i in 5:
		gm.s["day"] = int(gm.s.day) + 1
		gm.s.today["rain"] = true
		gm._commit()
	_ok(Biz.qty(gm, "ao_thun") < 10, "5 ngày mưa không có quạt hút ẩm: còn %d/10 áo" % Biz.qty(gm, "ao_thun"))


func _rain_sale(rain: bool) -> int:
	var total := 0
	for i in 20:
		var g := _new()
		g.s["cash"] = 2000000
		g.s.today["rain"] = rain
		g.s["marketDay"] = -1
		g.s.biz["marketDay"] = -1
		g._commit()
		Biz.refresh(g)
		g.s["used"] = 15.5 - float(g.cfg.dayStart)
		g.do_action("biz_nhap_ao_mua")
		g.s["used"] = 16.0 - float(g.cfg.dayStart)
		var before := Biz.qty(g, "ao_mua")
		g.do_action("biz_ban_ben_xe_6")
		total += before - Biz.qty(g, "ao_mua")
	return total / 20


func _live_orders(at_peak: bool) -> int:
	var total := 0
	for i in 20:
		var g := _new()
		g.s.flags["phoVyLive"] = true
		g.s.attr.per.lv = 2
		g.s.biz.warehouse.rented = true
		g.s.biz.warehouse.paidTo = 99
		g.s.biz.lots.append({"good": "ao_thun", "qty": 200, "cost": 45000, "day": g.day(), "bin": "kho"})
		var st := Biz.live_begin(g, "ke_chuyen", 2, 0)
		while not Biz.live_done(st):
			var v: bool = (int(st.beat) == int(st.peak)) if at_peak else (int(st.beat) == 0)
			Biz.live_beat(g, st, {"voucher": v})
		total += int(st.total)
	return total / 20


func _return_rate(script: String, extra_orders: int) -> float:
	var back := 0
	var all := 0
	for i in 30:
		var g := _new()
		g.s.biz.warehouse.rented = true
		g.s.biz.warehouse.paidTo = 99
		g.s.biz.lots.append({"good": "ao_thun", "qty": 300, "cost": 45000, "day": g.day(), "bin": "kho"})
		var st := Biz.live_begin(g, script, 2, 0)
		while not Biz.live_done(st):
			Biz.live_beat(g, st, {})
		st["total"] = int(st.total) + extra_orders
		Biz.live_end(g, st)
		for k in 3:
			g.s["day"] = int(g.s.day) + 1
			g._commit()
		back += int(g.s.biz.stats.returned)
		all += int(st.total) - extra_orders
	return float(back) / maxf(1.0, float(all))
