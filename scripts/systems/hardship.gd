extends RefCounted
## Áp lực sinh tồn chương 1 khi chơi đủ 30 ngày (data/systems/hardship.json, cfg.hardship):
##   - An vào game với startCash (50.000đ): đủ một bữa, phải đi làm ngay để tối có tiền trọ.
##   - Tiền trọ nightRent mỗi đêm trả cô Duyên ở chỗ ở (việc "tra_tien_tro"); chưa trả thì không ngủ, không nghỉ ở phòng
##     được (block). Hết ngày chưa trả: đủ tiền thì tự trừ, thiếu thì nợ một đêm (unpaid).
##   - Tiền sinh hoạt cả nhà mỗi tối của chương 1 thay bằng livingCost (ăn uống tự trả từng bữa).
##   - Mỗi sáng một việc thưởng nóng (hotJob): việc đó trả mult lần; điện thoại báo lúc 06:00.
##   - Mục tiêu ngắn hạn (goals) và số liệu đầu ngày để màn Tổng kết cuối ngày so sánh.
## Chỉ bật khi chơi đủ (is_full) ở chương 1; lát cắt và các chương sau giữ luật cũ.
## s.hard: {"day": ngày đã chuẩn bị, "start": {cash, needs, rep, attr}, "debt": số đêm nợ}; s.today.rent_paid, s.today.hot.


static func data(g) -> Dictionary:
	return g.cfg.get("hardship", {})


static func on(g) -> bool:
	return not data(g).is_empty() and g.is_started() and g.is_full() and g.chapter() == 1


static func rent(g) -> int:
	return int(data(g).get("nightRent", 0)) if on(g) else 0


static func paid(g) -> bool:
	return not on(g) or bool(g.s.today.get("rent_paid", false))


## Lúc tạo ván mới (chơi đủ): tiền khởi đầu.
static func new_game(g) -> void:
	if not data(g).is_empty() and g.is_full() and data(g).has("startCash"):
		g.s["cash"] = int(data(g).startCash)
		g.s.stats["start_cash"] = int(data(g).startCash)


## Tiền sinh hoạt mỗi tối của chương 1 khi bật áp lực sinh tồn; -1 nếu giữ luật cũ.
static func living_cost(g) -> int:
	return int(data(g).get("livingCost", 0)) if on(g) else -1


static func migrate(g) -> void:
	if g.is_started() and not g.s.has("hard"):
		g.s["hard"] = {"day": -1, "start": {}, "debt": 0}


## Mỗi lần _commit: sang ngày mới thì ghi số liệu đầu ngày và chọn việc thưởng nóng.
static func tick(g) -> void:
	if not g.s.has("hard") or int(g.s.hard.day) == g.day():
		return
	g.s.hard["day"] = g.day()
	g.s.hard["start"] = snapshot(g)
	g.s.today.erase("hot")
	if not on(g):
		return
	var pool: Array = data(g).get("hotJob", {}).get("pool", [])
	var ok := []
	for id in pool:
		var a: Dictionary = g.get_action(str(id))
		if not a.is_empty() and not g.is_hidden(a) and g.check(a.get("require", {})) == "" and int(a.get("pay", 0)) > 0:
			ok.append(str(id))
	if not ok.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([int(g.s.get("seed", 0)), g.day(), "hot"])
		g.s.today["hot"] = ok[rng.randi() % ok.size()]


static func snapshot(g) -> Dictionary:
	var rep := 0
	for k in g.s.rep:
		rep += int(g.s.rep[k])
	return {"cash": int(g.s.cash), "fatigue": float(g.s.fatigue), "needs": g.s.get("needs", {}).duplicate(),
		"rep": rep, "earned": int(g.s.stats.get("earned", 0)), "spent": int(g.s.stats.get("spent", 0))}


static func hot(g) -> String:
	return str(g.s.today.get("hot", ""))


## Hệ số tiền công của việc id (thưởng nóng).
static func pay_mult(g, id: String) -> float:
	return float(data(g).get("hotJob", {}).get("mult", 2)) if on(g) and id == hot(g) else 1.0


## Lý do việc a bị chặn vì chưa trả tiền trọ, "" nếu không.
static func block(g, a: Dictionary) -> String:
	if not on(g) or paid(g):
		return ""
	if data(g).get("lockActions", []).has(str(a.get("id", ""))):
		return "Chưa trả tiền trọ đêm nay (%s)" % g.fmt_money(rent(g))
	return ""


static func sleep_lock(g) -> String:
	if paid(g):
		return ""
	return "Chưa trả tiền trọ đêm nay (%s)" % g.fmt_money(rent(g))


## Trả tiền trọ đêm nay. "" nếu được.
static func pay_rent(g) -> String:
	if paid(g):
		return ""
	if int(g.s.cash) < rent(g):
		return "Không đủ %s tiền trọ" % g.fmt_money(rent(g))
	g.spend(rent(g), "Tiền trọ đêm nay (cô Duyên)")
	g.s.today["rent_paid"] = true
	g._commit()
	return ""


## Trước khi qua đêm (finish_day): chưa trả thì tự trừ nếu đủ, thiếu thì nợ một đêm.
static func night(g, slept_away := false) -> void:
	if not on(g) or paid(g) or slept_away:
		return
	if int(g.s.cash) >= rent(g):
		g.spend(rent(g), "Tiền trọ đêm nay (cô Duyên)")
		g.s.today["rent_paid"] = true
		return
	var u: Dictionary = data(g).get("unpaid", {})
	g.s.hard["debt"] = int(g.s.hard.get("debt", 0)) + 1
	g.add_rep(str(data(g).get("rentTo", "DUYEN")), float(u.get("rep", -4)))
	if g.has_needs():
		g.need_adj("mood", float(u.get("mood", -8)))
	g.add_fatigue(float(u.get("fatigue", 6)))
	g.add_log(str(u.get("log", "Nợ tiền trọ một đêm")), "warn")


## Mục tiêu ngắn hạn đang theo: {name, have, need, pct, hint}; rỗng nếu không bật hay đã xong hết.
static func goal(g) -> Dictionary:
	if not on(g):
		return {}
	for gl in data(g).get("goals", []):
		if g.check(gl.get("done", {})) == "":
			continue
		var have := maxi(0, int(g.s.cash))
		var need := int(gl.need)
		return {"id": str(gl.id), "name": str(gl.name), "have": have, "need": need, "pct": clampf(float(have) / float(need), 0.0, 1.0),
			"hint": str(gl.get("hint", ""))}
	return {}


## Tổng kết ngày (màn khi đi ngủ): thu, chi, chênh lệch nhu cầu và quan hệ so với đầu ngày, việc thưởng nóng.
static func day_summary(g) -> Dictionary:
	var st: Dictionary = g.s.get("hard", {}).get("start", {})
	if st.is_empty():
		st = snapshot(g)
	var lines_in := []
	var lines_out := []
	for e in g.s.get("log", []):
		if int(e.get("day", -1)) != g.day():
			continue
		var t := str(e.t)
		if t.begins_with("+"):
			lines_in.append(t.substr(1))
		elif t.begins_with("−"):
			lines_out.append(t.substr(1))
	var rep := 0
	for k in g.s.rep:
		rep += int(g.s.rep[k])
	var needs := {}
	for k in ["fed", "clean", "mood"]:
		needs[k] = g.need(k) - float(st.get("needs", {}).get(k, g.need(k)))
	return {"day": g.day(), "earned": int(g.s.stats.get("earned", 0)) - int(st.get("earned", 0)),
		"spent": int(g.s.stats.get("spent", 0)) - int(st.get("spent", 0)), "cash": int(g.s.cash), "cash0": int(st.get("cash", g.s.cash)),
		"in": lines_in, "out": lines_out, "needs": needs, "rep": rep - int(st.get("rep", rep)), "fatigue": float(g.s.fatigue),
		"rent": rent(g), "paid": paid(g), "goal": goal(g)}


## Khóa điều kiện: "rent_paid": bool; "housing_state": trạng thái chỗ ở (hay danh sách). null nếu không phải.
static func check(g, k: String, v) -> Variant:
	match k:
		"rent_paid":
			return "" if paid(g) == bool(v) else ("Chưa trả tiền trọ đêm nay" if bool(v) else "Đã trả tiền trọ")
		"housing_state":
			var st := str(g.housing().state)
			return "" if (st in v if v is Array else st == str(v)) else "-"
	return null


## Khóa hiệu ứng: "rent_pay": true trả tiền trọ đêm nay. true nếu đã xử lý.
static func effect(g, k: String, v) -> bool:
	if k == "rent_pay":
		if bool(v) and on(g) and not paid(g):
			g.s.today["rent_paid"] = true
		return true
	return false
