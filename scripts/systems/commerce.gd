extends RefCounted
## Kinh tế buôn bán (data/systems/commerce.json, cfg.commerce; kiểu dữ liệu ở docs/schema/commerce.d.ts).
##   - Thị trường: mỗi ngày mỗi mặt hàng có hệ số giá nhập (đi theo xu hướng có quán tính, kéo dần về 1) và hệ số cầu;
##     sự kiện (mưa, rằm, cuối tuần) nhân thêm và có dòng tin hiện trong app.
##   - Hàng là các lô {good, qty, cost, day, bin}: bin "cart" là xe đẩy mang theo (sức chứa theo Thể chất), "kho" là
##     kho thuê. Lấy hàng ra bán theo lô cũ trước. Hoa héo sau perishDays; hàng dễ mốc trong kho chưa có quạt thì hỏng dần.
##   - Bán hàng rong: việc "Bày bán" ở điểm bán; mỗi giờ tính khách qua × phần để ý × cầu (món, điểm, giờ, thời tiết,
##     thị trường) × tỷ lệ chốt (mức giá, Nhạy bén, Tâm trạng). Điểm không được phép bán thì mỗi giờ có thể bị trật tự đô
##     thị bắt: thu một phần hàng, phạt tiền, tụt Tâm trạng, dừng bán.
##   - Livestream Shippy: live_begin() dựng buổi, live_beat() chạy từng nhịp theo thao tác người chơi (voucher, deal
##     chớp nhoáng, trả lời bình luận, đổi món), live_end() trả lương, tính đơn trễ do đóng gói không kịp và đưa đơn vào
##     hàng chờ. Sau returns.days ngày đơn thành công (nhận tiền sau phí sàn) hay bị hoàn (mất phí ship hai chiều, hàng về
##     kho), uy tín shop lên xuống theo đó.
## GameLogic gọi tick() mỗi lần _commit, register() lúc nạp dữ liệu (sinh việc ở chợ, kho, điểm bán, chỗ lên sóng),
## refresh() khi bảng địa điểm cần giá mới, effect()/check() cho khóa "biz", "biz_*", "rain_today".
## s.biz: xem BizSave trong docs/schema/commerce.d.ts.


static func data(g) -> Dictionary:
	return g.cfg.get("commerce", {})


static func goods(g) -> Dictionary:
	return data(g).get("goods", {})


static func good(g, gid: String) -> Dictionary:
	return goods(g).get(gid, {})


static func biz(g) -> Dictionary:
	return g.s.get("biz", {})


static func migrate(g) -> void:
	if not g.is_started() or data(g).is_empty() or g.s.has("biz"):
		return
	g.s["biz"] = {"lots": [], "marketDay": -1, "market": {}, "tier": "cho",
		"warehouse": {"rented": false, "paidTo": 0, "vent": false}, "staff": {"closer": 0, "packer": 0},
		"rep": float(data(g).get("returns", {}).get("repStart", 50)), "orders": [], "banUntil": 0, "next": 1,
		"stats": {"streetSold": 0, "streetRevenue": 0, "liveOrders": 0, "returned": 0, "fined": 0}, "last": {}}
	_new_day(g)


static func tick(g) -> void:
	if not g.is_started() or not g.s.has("biz"):
		return
	if int(biz(g).marketDay) != g.day():
		_new_day(g)


# ---------------------------------------------------------------- thị trường theo ngày

static func _rain(g) -> bool:
	return bool(g.s.get("today", {}).get("rain", false))


static func _weekend(g) -> bool:
	return g.day() % 7 in [0, 6]


static func _event_ok(g, when: Dictionary) -> bool:
	for k in when:
		match k:
			"rain":
				if _rain(g) != bool(when[k]):
					return false
			"weekend":
				if _weekend(g) != bool(when[k]):
					return false
			"dayMod":
				if g.day() % int(when[k][0]) != int(when[k][1]):
					return false
	return true


## Sang ngày mới: giá đi tiếp, hoa héo, hàng mốc, hết hạn kho, đơn tới hạn có kết quả.
static func _new_day(g) -> void:
	var b := biz(g)
	var m: Dictionary = data(g).get("market", {})
	var lo := float(m.get("clamp", [0.7, 1.5])[0])
	var hi := float(m.get("clamp", [0.7, 1.5])[1])
	var rng := RandomNumberGenerator.new()
	for gid in goods(g):
		var gd := good(g, gid)
		var st: Dictionary = b.market.get(gid, {"base": 1.0, "trend": 0.0})
		rng.seed = hash([int(g.s.get("seed", 0)), g.day(), gid])
		var trend := clampf(float(st.trend) * 0.7 + rng.randfn(0.0, float(m.get("drift", 0.04))), -0.12, 0.12)
		var base := float(st.base) * (1.0 + trend + rng.randf_range(-1.0, 1.0) * float(gd.get("volatility", 0.1)) * 0.5)
		base = clampf(lerpf(base, 1.0, float(m.get("revert", 0.15))), lo, hi)
		var buy := base
		var demand := 1.0
		var news := ""
		for e in m.get("events", []):
			if str(e.good) == gid and _event_ok(g, e.get("when", {})):
				buy *= float(e.get("buy", 1.0))
				demand *= float(e.get("demand", 1.0))
				news = str(e.text)
		b.market[gid] = {"base": base, "trend": trend, "buy": buy, "demand": demand, "news": news}
	var first := int(b.marketDay) < 0
	b["marketDay"] = g.day()
	if first:
		return
	_spoil(g)
	var w: Dictionary = b.warehouse
	if w.rented and int(w.paidTo) < g.day():
		w["rented"] = false
		if qty(g, "", "kho") > 0:
			g.add_log("Hết hạn thuê kho: hàng trong kho bị khóa tới khi gia hạn", "warn")
	elif w.rented and int(w.paidTo) == g.day():
		g.add_log("Hôm nay là ngày cuối thuê kho", "warn")
	_resolve_orders(g)


static func _spoil(g) -> void:
	var b := biz(g)
	var wh: Dictionary = data(g).get("warehouse", {})
	var lost := {}
	for lot in b.lots.duplicate():
		var gd := good(g, lot.good)
		if gd.has("perishDays") and g.day() - int(lot.day) >= int(gd.perishDays):
			lost[lot.good] = int(lost.get(lot.good, 0)) + int(lot.qty)
			b.lots.erase(lot)
		elif gd.get("mold", false) and lot.bin == "kho" and not b.warehouse.vent:
			var frac := float(wh.get("moldRain", 0.08)) if _rain(g) else float(wh.get("moldDry", 0.02))
			var n := int(floor(float(lot.qty) * frac + randf()))
			if n > 0:
				lot["qty"] = int(lot.qty) - n
				lost[lot.good] = int(lost.get(lot.good, 0)) + n
				if int(lot.qty) <= 0:
					b.lots.erase(lot)
	for gid in lost:
		var gd := good(g, gid)
		g.add_log("%d %s %s %s" % [int(lost[gid]), gd.unit, str(gd.name).to_lower(), "héo, phải bỏ" if gd.has("perishDays") else "mốc trong kho"], "warn")


static func market(g, gid: String) -> Dictionary:
	return biz(g).get("market", {}).get(gid, {"base": 1.0, "trend": 0.0, "buy": 1.0, "demand": 1.0, "news": ""})


static func _round(v: float, step: int) -> int:
	return int(round(v / float(step))) * step


## Giá nhập sỉ một đơn vị hôm nay; quen chị Hạnh (phoSiHanh) thì áo mưa bớt 10%.
static func buy_price(g, gid: String) -> int:
	var p := float(good(g, gid).get("buyBase", 0)) * float(market(g, gid).get("buy", 1.0))
	if gid == "ao_mua" and g.s.flags.get("phoSiHanh", false):
		p *= 0.9
	return maxi(500, _round(p, 500))


## Giá bán lẻ một đơn vị ở mức giá tier (mặc định mức đang chọn). Giá lẻ đi chậm hơn giá sỉ.
static func sell_price(g, gid: String, tier := "") -> int:
	if tier == "":
		tier = str(biz(g).get("tier", "cho"))
	var t: Dictionary = data(g).get("vending", {}).get("priceTiers", {}).get(tier, {"price": 1.0})
	var p := float(good(g, gid).get("sellBase", 0)) * (0.6 + 0.4 * float(market(g, gid).get("base", 1.0))) * float(t.price)
	return maxi(1000, _round(p, 1000))


# ---------------------------------------------------------------- kho, xe đẩy

static func qty(g, gid := "", bin := "") -> int:
	var n := 0
	for lot in biz(g).get("lots", []):
		if (gid == "" or lot.good == gid) and (bin == "" or lot.bin == bin):
			n += int(lot.qty)
	return n


static func cart_cap(g) -> int:
	var v: Dictionary = data(g).get("vending", {})
	return int(v.get("cartBase", 40)) + int(v.get("cartPerStr", 15)) * (g.Attributes.level(g, "str") - 1)


static func kho_cap(g) -> int:
	return int(data(g).get("warehouse", {}).get("capacity", 300)) if biz(g).get("warehouse", {}).get("rented", false) else 0


static func _add(g, gid: String, n: int, cost: int, bin: String, day := -1) -> void:
	if n <= 0:
		return
	biz(g).lots.append({"good": gid, "qty": n, "cost": cost, "day": g.day() if day < 0 else day, "bin": bin})


## Lấy n đơn vị gid từ các ngăn bins, lô cũ trước. Trả về {qty, cost: tổng giá vốn}.
static func _take(g, gid: String, n: int, bins: Array) -> Dictionary:
	var lots: Array = biz(g).lots.filter(func(l) -> bool: return l.good == gid and bins.has(l.bin))
	lots.sort_custom(func(a, b) -> bool: return int(a.day) < int(b.day))
	var got := 0
	var cost := 0
	for lot in lots:
		if got >= n:
			break
		var k := mini(n - got, int(lot.qty))
		got += k
		cost += k * int(lot.cost)
		lot["qty"] = int(lot.qty) - k
		if int(lot.qty) <= 0:
			biz(g).lots.erase(lot)
	return {"qty": got, "cost": cost}


static func _room_reason(g, gid: String) -> String:
	var n := int(good(g, gid).get("lot", 0))
	var room := cart_cap(g) - qty(g, "", "cart") + kho_cap(g) - qty(g, "", "kho")
	if room >= n:
		return ""
	return "Xe đẩy đã đầy (%d/%d)%s" % [qty(g, "", "cart"), cart_cap(g), "" if kho_cap(g) > 0 else ". Thuê kho để chứa thêm"]


static func _buy(g, gid: String) -> void:
	var n := int(good(g, gid).get("lot", 0))
	var price := buy_price(g, gid)
	var to_cart := mini(n, cart_cap(g) - qty(g, "", "cart"))
	_add(g, gid, to_cart, price, "cart")
	_add(g, gid, n - to_cart, price, "kho")
	g.add_log("Nhập %d %s %s, %s/%s%s" % [n, good(g, gid).unit, str(good(g, gid).name).to_lower(), g.fmt_money(price), good(g, gid).unit,
		"" if to_cart == n else " (%d để kho)" % (n - to_cart)])


## Dồn hàng sang ngăn to ("cart" hay "kho") tới khi đầy.
static func _move(g, to: String) -> void:
	var from := "kho" if to == "cart" else "cart"
	var room := (cart_cap(g) - qty(g, "", "cart")) if to == "cart" else (kho_cap(g) - qty(g, "", "kho"))
	var moved := 0
	for lot in biz(g).lots:
		if room <= 0:
			break
		if lot.bin != from:
			continue
		var k := mini(room, int(lot.qty))
		if k == int(lot.qty):
			lot["bin"] = to
		else:
			lot["qty"] = int(lot.qty) - k
			_add(g, lot.good, k, int(lot.cost), to, int(lot.day))
		room -= k
		moved += k
	g.add_log("Chuyển %d món %s" % [moved, "ra xe đẩy" if to == "cart" else "vào kho"])


# ---------------------------------------------------------------- bán hàng rong

## Hệ số cầu của món gid ở điểm spot lúc hour (giờ trong ngày).
static func demand(g, gid: String, spot: Dictionary, hour: float) -> float:
	var d: Dictionary = good(g, gid).get("demand", {})
	var f := float(spot.get("demand", {}).get(gid, 0.6)) * float(market(g, gid).get("demand", 1.0))
	f *= float(d.get("rain", 1.0)) if _rain(g) else float(d.get("dry", 1.0))
	if _weekend(g):
		f *= float(d.get("weekend", 1.0))
	if hour >= 17.0:
		f *= float(d.get("evening", 1.0))
	if hour < 10.0:
		f *= float(d.get("morning", 1.0))
	return f


static func traffic(spot: Dictionary, hour: float) -> float:
	for t in spot.get("traffic", []):
		if hour >= float(t[0]) and hour < float(t[1]):
			return float(t[2])
	return 0.0


## Tỷ lệ chốt khi bán rong: mức giá × (1 + Nhạy bén) × Tâm trạng × buff (biz.close: xem bói, mặt dày tiếp thị…).
static func street_close(g) -> float:
	var v: Dictionary = data(g).get("vending", {})
	var t: Dictionary = v.get("priceTiers", {}).get(str(biz(g).get("tier", "cho")), {"close": 1.0})
	var c: float = float(v.get("baseClose", 0.3)) * float(t.close) * (1.0 + float(v.get("closePerPer", 0.06)) * (g.Attributes.level(g, "per") - 1))
	if g.has_needs() and g.need("mood") < float(v.get("lowMood", 30)):
		c *= float(v.get("closeLowMood", 0.7))
	return clampf(c * (1.0 + g.mod("biz.close")), 0.0, 0.95)


static func _draw(expect: float) -> int:
	return int(floor(expect)) + (1 if randf() < expect - floor(expect) else 0)


## Bày bán ở điểm sid trong hours giờ vừa qua (đồng hồ đã chạy tới cuối buổi). Ghi kết quả vào s.biz.last.
static func _sell(g, sid: String, hours: float) -> void:
	var spot: Dictionary = data(g).get("spots", {}).get(sid, {})
	var v: Dictionary = data(g).get("vending", {})
	var start: float = g.clock() - hours
	if int(spot.get("fee", 0)) > 0:
		g.spend(int(spot.fee), "Vé chợ")
	var close := street_close(g)
	var sold := {}
	var revenue := 0
	var cost := 0
	var caught := false
	var h := start
	while h < start + hours - 0.001:
		var span := minf(1.0, start + hours - h)
		var visitors := traffic(spot, h) * span * (0.6 if _rain(g) else 1.0)
		for gid in goods(g):
			if not good(g, gid).get("channels", []).has("street") or qty(g, gid, "cart") <= 0:
				continue
			var n := mini(_draw(visitors * float(v.get("interest", 0.1)) * demand(g, gid, spot, h) * close), qty(g, gid, "cart"))
			if n <= 0:
				continue
			var got := _take(g, gid, n, ["cart"])
			sold[gid] = int(sold.get(gid, 0)) + int(got.qty)
			revenue += int(got.qty) * sell_price(g, gid)
			cost += int(got.cost)
		var ins: Dictionary = spot.get("inspector", {})
		if not spot.get("legal", true) and not ins.is_empty() and h >= float(ins.hours[0]) and h < float(ins.hours[1]):
			var p := float(ins.perHour) * span * maxf(0.1, 1.0 + float(v.fine.get("perPerLevel", -0.15)) * (g.Attributes.level(g, "per") - 1))
			if randf() < p:
				caught = true
				break
		h += span
	var b := biz(g)
	if revenue > 0:
		g.earn(revenue, "Bán hàng rong ở " + str(spot.name))
	b.stats["streetSold"] = int(b.stats.streetSold) + _sum(sold)
	b.stats["streetRevenue"] = int(b.stats.streetRevenue) + revenue
	var parts := []
	for gid in sold:
		parts.append("%d %s" % [int(sold[gid]), str(good(g, gid).name).to_lower()])
	var text := "Bán được %s · thu %s, lãi %s" % [", ".join(parts) if not parts.is_empty() else "không món nào", g.fmt_money(revenue), g.fmt_money(revenue - cost)]
	if caught:
		var lostn := 0
		for gid in goods(g):
			var n := int(floor(float(qty(g, gid, "cart")) * float(v.fine.get("confiscate", 0.5))))
			lostn += int(_take(g, gid, n, ["cart"]).qty)
		var fine := mini(int(v.fine.get("money", 150000)), maxi(0, int(g.s.cash)))
		if fine > 0:
			g.spend(fine, "Phạt bán hàng rong sai chỗ")
		g.need_adj("mood", float(v.fine.get("mood", -10)))
		b.stats["fined"] = int(b.stats.fined) + 1
		text += ". Trật tự đô thị tới: bị thu %d món, phạt %s" % [lostn, g.fmt_money(fine)]
		g.add_log("Bị trật tự đô thị thu hàng ở " + str(spot.name), "minus")
	b["last"] = {"kind": "street", "text": text}
	g.add_log(text, "plus" if revenue > 0 else "info")
	g.Attributes.grant(g, {"per": 2.0 + float(_sum(sold)) / 10.0, "agi": 1.0})


static func _sum(d: Dictionary) -> int:
	var n := 0
	for k in d:
		n += int(d[k])
	return n


# ---------------------------------------------------------------- livestream Shippy

static func live_goods(g) -> Array:
	var out := []
	for gid in goods(g):
		if good(g, gid).get("channels", []).has("live") and qty(g, gid) > 0:
			out.append(gid)
	return out


static func live_lock(g) -> String:
	var lv: Dictionary = data(g).get("live", {})
	var r: String = g.check(lv.get("unlock", {}))
	if r != "":
		return "Chưa biết cách livestream" if r == "Chưa mở" else r
	if not biz(g).warehouse.rented:
		return "Cần thuê kho trước"
	if g.day() < int(biz(g).get("banUntil", 0)):
		return "Kênh bị khóa tới ngày %d" % int(biz(g).banUntil)
	if live_goods(g).is_empty():
		return "Không còn hàng bán live được"
	return ""


## Dựng buổi live: kịch bản script, số người chốt đơn, đóng gói (trả lương lúc kết thúc).
static func live_begin(g, script: String, closer: int, packer: int) -> Dictionary:
	var lv: Dictionary = data(g).get("live", {})
	var lg := live_goods(g)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return {"script": script, "closer": closer, "packer": packer, "beat": 0, "beats": int(lv.get("beats", 12)),
		"peak": rng.randi_range(int(lv.get("beats", 12)) / 3, int(lv.get("beats", 12)) * 2 / 3), "boost": 0.0, "cooldown": 0,
		"voucher": false, "voucherLeft": 0, "voucherMult": 1.0, "featured": lg[0] if not lg.is_empty() else "", "orders": {},
		"total": 0, "banned": false, "viewers": 0, "history": []}


## Một nhịp live. inp: {voucher, flash, reply: bool}. Trả về {viewers, orders, peak, banned, voucher, ask}.
static func live_beat(g, st: Dictionary, inp: Dictionary) -> Dictionary:
	var lv: Dictionary = data(g).get("live", {})
	var sc: Dictionary = lv.get("scripts", {}).get(str(st.script), {"close": 1.0, "returns": 1.0, "viewers": 1.0, "risk": 0.0})
	var beat := int(st.beat)
	var near_peak: bool = absi(beat - int(st.peak)) <= 1
	if inp.get("reply", false):
		st["boost"] = float(st.boost) + float(lv.get("reply", {}).get("viewers", 0.12))
	var curve := 0.55 + 1.45 * exp(-pow(float(beat - int(st.peak)) / 2.5, 2.0))
	var viewers := float(lv.get("baseViewers", 60)) * (0.5 + float(biz(g).rep) / 100.0) * float(sc.viewers) * (1.0 + float(st.boost)) * curve * randf_range(0.9, 1.1)
	var close: float = float(lv.get("baseClose", 0.35)) * float(sc.close) * (1.0 + float(data(g).vending.get("closePerPer", 0.06)) * (g.Attributes.level(g, "per") - 1))
	close *= 1.0 + g.mod("biz.close")
	if inp.get("voucher", false) and not st.voucher:
		var vc: Dictionary = lv.get("voucher", {})
		st["voucher"] = true
		st["voucherLeft"] = 2
		st["voucherMult"] = float(vc.get("close", 1.5)) * (1.0 + float(vc.get("peakBonus", 1.0)) if near_peak else 1.0)
	var discount := 0.0
	if int(st.voucherLeft) > 0:
		close *= float(st.voucherMult)
		discount = float(lv.get("voucher", {}).get("discount", 0.1))
		st["voucherLeft"] = int(st.voucherLeft) - 1
	if inp.get("flash", false) and int(st.cooldown) <= 0:
		close *= float(lv.get("flash", {}).get("close", 1.8))
		st["cooldown"] = int(lv.get("flash", {}).get("cooldownBeats", 3))
		if randf() < float(sc.get("risk", 0.0)):
			st["banned"] = true
	st["cooldown"] = maxi(0, int(st.cooldown) - 1)
	var cap := int(lv.get("closerSolo", 3)) + int(st.closer) * int(lv.get("closerCap", 6))
	var gid := str(st.featured)
	if qty(g, gid) <= 0:
		var lg := live_goods(g)
		gid = lg[0] if not lg.is_empty() else ""
		st["featured"] = gid
	var n := 0
	if gid != "" and not st.banned:
		n = mini(mini(_draw(viewers * float(lv.get("intent", 0.07)) * clampf(close, 0.0, 1.0)), cap), qty(g, gid))
		var got := _take(g, gid, n, ["kho", "cart"])
		n = int(got.qty)
		if n > 0:
			var o: Dictionary = st.orders.get(gid, {"qty": 0, "revenue": 0, "cost": 0})
			o["qty"] = int(o.qty) + n
			o["revenue"] = int(o.revenue) + int(round(float(n * sell_price(g, gid, "cho")) * (1.0 - discount)))
			o["cost"] = int(o.cost) + int(got.cost)
			st.orders[gid] = o
	st["total"] = int(st.total) + n
	st["viewers"] = int(viewers)
	st["beat"] = beat + 1
	var res := {"viewers": int(viewers), "orders": n, "peak": near_peak, "banned": st.banned, "voucher": int(st.voucherLeft) > 0 or discount > 0.0,
		"capped": n >= cap, "good": gid}
	st.history.append(res)
	return res


static func live_done(st: Dictionary) -> bool:
	return bool(st.banned) or int(st.beat) >= int(st.beats)


## Chơi tự động (bot, giả lập): trả lời bình luận mỗi 3 nhịp, voucher lúc đỉnh, không tung deal.
static func live_auto(g, script := "ke_chuyen") -> Dictionary:
	var st := live_begin(g, script, 0, 0)
	while not live_done(st):
		live_beat(g, st, {"reply": int(st.beat) % 3 == 0, "voucher": absi(int(st.beat) - int(st.peak)) <= 0})
	return st


## Kết thúc buổi live: lương nhân viên, đơn trễ do đóng gói, đưa đơn vào hàng chờ, bị khóa kênh nếu nói hớ.
static func live_end(g, st: Dictionary) -> void:
	var lv: Dictionary = data(g).get("live", {})
	var rt: Dictionary = data(g).get("returns", {})
	var sc: Dictionary = lv.get("scripts", {}).get(str(st.script), {"returns": 1.0, "name": ""})
	var b := biz(g)
	var wage := int(st.closer) * int(lv.staff.closer.wage) + int(st.packer) * int(lv.staff.packer.wage)
	if wage > 0:
		g.spend(wage, "Trả công phụ live")
	var pack := int(lv.get("packerSolo", 10)) + int(st.packer) * int(lv.get("packerCap", 25))
	var total := int(st.total)
	var late_frac := 0.0 if total <= pack else float(total - pack) / float(total)
	var rep_cut := float(rt.get("repProtect", 0.1)) * float(b.rep) / 100.0
	for gid in st.orders:
		var o: Dictionary = st.orders[gid]
		var late_n := int(round(float(o.qty) * late_frac))
		for part in [[int(o.qty) - late_n, false], [late_n, true]]:
			var q: int = part[0]
			if q <= 0:
				continue
			var share := float(q) / float(o.qty)
			var risk := clampf(float(rt.get("base", 0.12)) * float(sc.get("returns", 1.0)) + (float(rt.get("late", 0.18)) if part[1] else 0.0) - rep_cut, 0.01, 0.9)
			b.orders.append({"id": int(b.next), "good": gid, "qty": q, "price": int(round(float(o.revenue) * share)),
				"cost": int(round(float(o.cost) * share)), "due": g.day() + int(rt.get("days", 2)), "late": part[1], "risk": risk})
			b["next"] = int(b.next) + 1
	b.stats["liveOrders"] = int(b.stats.liveOrders) + total
	var text := "Live %s: %d đơn chờ giao%s" % [str(sc.get("name", "")), total, "" if late_frac <= 0.0 else ", %d%% đóng gói không kịp sẽ giao trễ" % int(late_frac * 100.0)]
	if st.banned:
		b["banUntil"] = g.day() + int(lv.get("banDays", 2))
		b["rep"] = clampf(float(b.rep) - 5.0, 0.0, 100.0)
		text += ". Nói hớ lúc tung deal: kênh bị khóa %d ngày" % int(lv.get("banDays", 2))
		g.add_log("Kênh Shippy bị khóa vì vi phạm lúc live", "minus")
	b["last"] = {"kind": "live", "text": text}
	g.add_log(text, "event")
	g.Attributes.grant(g, {"per": 4.0 + float(total) / 8.0, "int": 3.0})


## Đơn tới hạn: thành công (nhận tiền sau phí sàn) hay bị hoàn (mất ship hai chiều, hàng về kho), uy tín đổi theo.
static func _resolve_orders(g) -> void:
	var b := biz(g)
	var lv: Dictionary = data(g).get("live", {})
	var rt: Dictionary = data(g).get("returns", {})
	var paid := 0
	var ok := 0
	var back := 0
	for o in b.orders.duplicate():
		if int(o.due) > g.day():
			continue
		b.orders.erase(o)
		# Mỗi món trong đơn là một khách: hoàn hay nhận theo xác suất riêng.
		var q := int(o.qty)
		var r := 0
		for i in q:
			if randf() < float(o.risk):
				r += 1
		var unit_cost := int(o.cost) / maxi(1, q)
		if r > 0:
			back += r
			g.spend(2 * r * int(lv.get("shipFee", 18000)), "Ship hai chiều đơn bị hoàn")
			if not good(g, str(o.good)).has("perishDays"):
				_add(g, str(o.good), r, unit_cost, "kho" if b.warehouse.rented else "cart")
			b["rep"] = clampf(float(b.rep) + float(rt.get("repPerReturn", -1.5)) * r, 0.0, 100.0)
			b.stats["returned"] = int(b.stats.returned) + r
		if q - r > 0:
			ok += q - r
			paid += int(round(float(o.price) * float(q - r) / float(q) * (1.0 - float(lv.get("feeRate", 0.08)))))
			b["rep"] = clampf(float(b.rep) + float(rt.get("repPerGood", 0.4)) * (q - r), 0.0, 100.0)
	if paid > 0:
		g.earn(paid, "Shippy trả tiền %d đơn" % ok)
	if back > 0:
		g.add_log("%d món bị khách hoàn (boom hàng), uy tín shop còn %d" % [back, int(b.rep)], "minus")


# ---------------------------------------------------------------- việc sinh từ dữ liệu

## Sinh việc: nhập sỉ từng món, thuê/gia hạn kho, quạt hút ẩm, chuyển hàng, bày bán ở từng điểm, lên sóng ở từng chỗ.
static func register(g) -> void:
	var d := data(g)
	if d.is_empty():
		return
	var whl := str(d.wholesale.location)
	var wh: Dictionary = d.warehouse
	var acts := []
	for gid in goods(g):
		acts.append({"id": "biz_nhap_" + gid, "group": "optional", "location": whl, "name": "Nhập sỉ " + str(good(g, gid).name).to_lower(),
			"hours": 0.25, "cost": 0, "perDay": 6, "require": {"biz_room": gid}, "effects": {"biz": {"op": "buy", "good": gid}}})
	acts.append({"id": "biz_thue_kho", "group": "optional", "location": str(wh.location), "name": "Thuê " + str(wh.name).to_lower() + " %d ngày" % int(wh.rentDays),
		"hours": 0.25, "cost": int(wh.rentPerDay) * int(wh.rentDays), "showIf": {"biz_kho": false}, "effects": {"biz": {"op": "rent"}},
		"note": "Chứa %d món. Cần kho để livestream" % int(wh.capacity)})
	acts.append({"id": "biz_gia_han_kho", "group": "optional", "location": str(wh.location), "name": "Gia hạn kho thêm %d ngày" % int(wh.rentDays),
		"hours": 0.1, "cost": int(wh.rentPerDay) * int(wh.rentDays), "showIf": {"biz_kho": true}, "effects": {"biz": {"op": "rent"}}})
	acts.append({"id": "biz_quat_kho", "group": "optional", "location": str(wh.location), "name": "Lắp quạt hút ẩm cho kho",
		"hours": 0.5, "cost": int(wh.ventCost), "showIf": {"biz_kho": true, "biz_vent": false}, "effects": {"biz": {"op": "vent"}},
		"note": "Áo, đồ chơi vải không bị mốc khi trời nồm, mưa"})
	acts.append({"id": "biz_lay_kho", "group": "optional", "location": str(wh.location), "name": "Lấy hàng trong kho ra xe đẩy",
		"hours": 0.25, "perDay": 4, "showIf": {"biz_kho": true}, "require": {"biz_has": "kho"}, "effects": {"biz": {"op": "move", "to": "cart"}}})
	acts.append({"id": "biz_cat_kho", "group": "optional", "location": str(wh.location), "name": "Cất hàng trên xe vào kho",
		"hours": 0.25, "perDay": 4, "showIf": {"biz_kho": true}, "require": {"biz_has": "cart"}, "effects": {"biz": {"op": "move", "to": "kho"}}})
	for sid in d.get("spots", {}):
		var sp: Dictionary = d.spots[sid]
		acts.append({"id": "biz_ban_" + sid, "group": "work", "location": str(sp.location), "name": "Bày bán hàng rong %d giờ" % int(d.vending.get("hours", 2)),
			"hours": float(d.vending.get("hours", 2)), "perDay": 3, "tags": ["outdoor"], "require": {"biz_cart": true},
			"effects": {"biz": {"op": "sell", "spot": sid}}, "note": str(sp.get("desc", ""))})
	var lv: Dictionary = d.get("live", {})
	for loc in lv.get("locations", []):
		acts.append({"id": "biz_live_" + str(loc), "group": "work", "location": str(loc), "name": "Lên sóng livestream Shippy",
			"hours": float(lv.get("hours", 2)), "perDay": 1, "require": {"biz_live": true},
			"effects": {"fatigue": float(lv.get("fatigue", 10)), "biz": {"op": "live"}}, "live": true})
	var have := {}
	for a in g.cfg.actions:
		have[a.id] = true
	for a in acts:
		if not have.has(a.id):
			g.cfg.actions.append(a)


## Cập nhật chữ trên thẻ theo giá hôm nay và hàng đang có (gọi trước khi vẽ bảng địa điểm).
static func refresh(g) -> void:
	if not g.s.has("biz"):
		return
	for a in g.cfg.actions:
		var id := str(a.id)
		if id.begins_with("biz_nhap_"):
			var gid := id.substr(9)
			var gd := good(g, gid)
			var p := buy_price(g, gid)
			a["cost"] = p * int(gd.lot)
			a["name"] = "Nhập %d %s %s" % [int(gd.lot), gd.unit, str(gd.name).to_lower()]
			var m := market(g, gid)
			var arrow := "↑" if float(m.buy) > 1.03 else ("↓" if float(m.buy) < 0.97 else "→")
			a["note"] = "%s %s/%s · bán ~%s%s" % [arrow, g.fmt_money(p), gd.unit, g.fmt_money(sell_price(g, gid, "cho")), "" if str(m.news) == "" else " · " + str(m.news)]
		elif id.begins_with("biz_ban_"):
			a["note"] = "%s · %s" % [cart_text(g), str(data(g).vending.priceTiers.get(str(biz(g).tier), {}).get("name", ""))]


static func cart_text(g) -> String:
	var parts := []
	for gid in goods(g):
		var n := qty(g, gid, "cart")
		if n > 0:
			parts.append("%d %s" % [n, str(good(g, gid).name).to_lower()])
	return ("Trên xe: " + ", ".join(parts)) if not parts.is_empty() else "Xe đẩy trống"


static func set_tier(g, tier: String) -> void:
	if data(g).get("vending", {}).get("priceTiers", {}).has(tier):
		biz(g)["tier"] = tier
		g.changed.emit()


static func hire(g, role: String, n: int) -> void:
	var mx := int(data(g).get("live", {}).get("staff", {}).get(role, {}).get("max", 0))
	biz(g).staff[role] = clampi(n, 0, mx)
	g.changed.emit()


## Dòng cho app Shippy: [{id, name, unit, buy, sell, arrow, news, cart, kho, live}].
static func market_rows(g) -> Array:
	var out := []
	for gid in goods(g):
		var m := market(g, gid)
		out.append({"id": gid, "name": str(good(g, gid).name), "unit": str(good(g, gid).unit), "buy": buy_price(g, gid), "sell": sell_price(g, gid, "cho"),
			"arrow": "↑" if float(m.buy) > 1.03 else ("↓" if float(m.buy) < 0.97 else "→"), "news": str(m.news),
			"cart": qty(g, gid, "cart"), "kho": qty(g, gid, "kho"), "live": good(g, gid).get("channels", []).has("live")})
	return out


## Đơn đang chờ: {count, value, late}.
static func pending(g) -> Dictionary:
	var n := 0
	var v := 0
	var late := 0
	for o in biz(g).get("orders", []):
		n += int(o.qty)
		v += int(o.price)
		if o.late:
			late += int(o.qty)
	return {"count": n, "value": v, "late": late}


# ---------------------------------------------------------------- khóa hiệu ứng, điều kiện

## Khóa hiệu ứng "biz": {"op": buy|rent|vent|move|sell|live, …}. true nếu đã xử lý.
static func effect(g, k: String, v) -> bool:
	if k != "biz" or not g.s.has("biz"):
		return false
	match str(v.get("op", "")):
		"buy":
			_buy(g, str(v.good))
		"rent":
			var w: Dictionary = biz(g).warehouse
			w["paidTo"] = maxi(int(w.paidTo), g.day() - 1) + int(data(g).warehouse.rentDays)
			w["rented"] = true
			g.add_log("Kho thuê tới hết ngày %d" % int(w.paidTo), "event")
		"vent":
			biz(g).warehouse["vent"] = true
		"move":
			_move(g, str(v.to))
		"sell":
			_sell(g, str(v.spot), float(data(g).vending.get("hours", 2)))
		"live":
			var st: Dictionary = biz(g).get("pending_live", {})
			biz(g).erase("pending_live")
			if st.is_empty():
				st = live_auto(g)
			live_end(g, st)
	return true


## Màn live đã chạy xong (giao diện): giữ lại để việc "Lên sóng" chốt khi trừ giờ.
static func live_store(g, st: Dictionary) -> void:
	biz(g)["pending_live"] = st


## Khóa điều kiện: biz_room (món), biz_cart, biz_kho, biz_vent, biz_has (ngăn), biz_live, rain_today. null nếu không phải.
static func check(g, k: String, v) -> Variant:
	match k:
		"rain_today":
			return "" if _rain(g) == bool(v) else "-"
		"biz_room":
			return _room_reason(g, str(v)) if g.s.has("biz") else "-"
		"biz_cart":
			for gid in goods(g):
				if good(g, gid).get("channels", []).has("street") and qty(g, gid, "cart") > 0:
					return ""
			return "Xe đẩy chưa có hàng. Nhập ở chợ Long Biên"
		"biz_kho":
			return "" if bool(biz(g).get("warehouse", {}).get("rented", false)) == bool(v) else "-"
		"biz_vent":
			return "" if bool(biz(g).get("warehouse", {}).get("vent", false)) == bool(v) else "-"
		"biz_has":
			if str(v) == "kho" and qty(g, "", "kho") <= 0:
				return "Kho trống"
			if str(v) == "cart" and qty(g, "", "cart") <= 0:
				return "Xe đẩy trống"
			var full := (cart_cap(g) - qty(g, "", "cart")) if str(v) == "kho" else (kho_cap(g) - qty(g, "", "kho"))
			return "" if full > 0 else ("Xe đẩy đã đầy" if str(v) == "kho" else "Kho đã đầy")
		"biz_live":
			if biz(g).has("pending_live"):
				return ""
			return live_lock(g) if g.s.has("biz") else "-"
	return null
