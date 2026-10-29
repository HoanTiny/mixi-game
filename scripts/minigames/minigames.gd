extends RefCounted
## Tầng luật của trò chơi nhỏ (data/systems/minigames.json, cfg.minigame_catalog). Không vẽ gì, chạy được headless.
##   register()   lúc nạp dữ liệu: mỗi trò sinh một việc (cfg.actions) ở địa điểm của nó, tên vật phẩm thưởng.
##   view_cfg()   khi mở cảnh: params đã nhân theo thuộc tính, tay nghề, kèm lời giới thiệu (chi phí, thưởng, rủi ro).
##   normalize()  đầu do_action: kết quả thô của cảnh {score, fails} thành {ratio, bonus, win, label} để tính tiền công.
##   on_action()  cuối do_action: thưởng theo mục outcomes, EXP thuộc tính, EXP nghề, chấn thương ngẫu nhiên.
## Điều kiện vào (require, cert, cost, khung giờ, trạng thái chặn việc) đi qua action_status như mọi việc.
## Cảnh vẽ nằm ở scripts/minigames/views/ (chọn theo view trong registry.gd), chỉ trả kết quả thô.

const Survival := preload("res://scripts/systems/survival.gd")
const Attributes := preload("res://scripts/systems/attributes.gd")
const Careers := preload("res://scripts/systems/careers.gd")
const NEED_NAMES := {"fed": "Độ no", "clean": "Vệ sinh", "mood": "Tâm trạng", "neat": "Quần áo"}


static func data(g) -> Dictionary:
	return g.cfg.get("minigame_catalog", {})


static func def(g, id: String) -> Dictionary:
	return data(g).get("games", {}).get(id, {})


## Nạp danh mục: tên vật phẩm vào quest_items, việc tự sinh vào cfg.actions, cấu hình gốc vào cfg.minigames.
static func register(g) -> void:
	for k in data(g).get("items", {}):
		g.quest_items[k] = str(data(g).items[k])
	if not g.cfg.has("minigames"):
		g.cfg["minigames"] = {}
	for id in data(g).get("games", {}):
		var d: Dictionary = data(g).games[id]
		g.cfg.actions.append(action_of(id, d))
		g.cfg.minigames[id] = d.get("params", {}).merged({"view": str(d.get("view", ""))})


## Việc tự sinh của trò id: nhóm theo type, giờ, phí, tiền công, điều kiện (gộp bằng cấp), tag, Mệt cố định của ca.
static func action_of(id: String, d: Dictionary) -> Dictionary:
	var a: Dictionary = d.get("action", {}).duplicate(true)
	a["id"] = str(a.get("id", id))
	a["group"] = "work" if str(d.get("type", "")) == "labor" else "life"
	a["minigame"] = id
	a["hours"] = float(d.get("hours", 1.0))
	if int(d.get("cost", 0)) > 0:
		a["cost"] = int(d.cost)
	if int(d.get("pay", 0)) > 0:
		a["pay"] = int(d.pay)
	var req: Dictionary = d.get("require", {}).duplicate()
	if d.has("cert"):
		req["cert"] = d.cert
	if not req.is_empty():
		a["require"] = req
	if d.has("tags"):
		a["tags"] = d.tags
	a["effects"] = d.get("effects", {})
	# EXP thuộc tính tính theo kết quả (outcomes), không theo bảng actionXp của attributes.json.
	a["xp"] = {}
	return a


## Hệ số nhân của một luật scaling: 1 + Σ hệ số × (cấp − 1); mg.time nhân phần thêm giờ (Nhanh nhẹn, ngón tay đau…).
static func scale(g, rule: Dictionary, prof: String) -> float:
	var m := 1.0
	for k in rule:
		var c := float(rule[k])
		if k == "mg.time":
			m += c * g.mod("mg.time")
		elif k == "prof":
			m += c * float(Careers.level(g, prof) - 1)
		elif str(k).begins_with("stat."):
			m += c * float(Attributes.level(g, str(k).substr(5)) - 1)
	return maxf(0.2, m)


## Cấu hình cho cảnh của trò id: params đã nhân scaling, view, type, info (các dòng giới thiệu).
## Trò cũ ngoài danh mục (ca kho, quán cơm, bi-a) chỉ được cộng giờ theo mg.time.
static func view_cfg(g, id: String) -> Dictionary:
	var d := def(g, id)
	if d.is_empty():
		var old: Dictionary = g.cfg.get("minigames", {}).get(id, {}).duplicate()
		if old.has("seconds") and g.mod("mg.time") != 0.0:
			old["seconds"] = float(old.seconds) * maxf(0.2, 1.0 + g.mod("mg.time"))
		return old
	var p: Dictionary = d.get("params", {}).duplicate()
	for k in d.get("scaling", {}):
		if p.has(k):
			p[k] = float(p[k]) * scale(g, d.scaling[k], str(d.get("prof", "")))
	p["view"] = str(d.get("view", ""))
	p["type"] = str(d.get("type", ""))
	p["info"] = info(g, id)
	return p


## Mục outcomes đầu tiên có score ≥ atLeast.
static func outcome(d: Dictionary, score: float) -> Dictionary:
	for o in d.get("outcomes", []):
		if score >= float(o.get("atLeast", 0.0)) - 0.0001:
			return o
	return {}


## Kết quả thô của cảnh → kết quả cho do_action. Có sẵn ratio (cảnh cũ, làm nhanh như lần trước) thì giữ tiền công đó.
static func normalize(g, a: Dictionary, raw: Dictionary) -> Dictionary:
	var d := def(g, str(a.get("minigame", "")))
	if raw.is_empty() or d.is_empty():
		return raw
	var r := raw.duplicate()
	if not r.has("score"):
		r["score"] = float(r.get("ratio", 1.0))
	var o := outcome(d, float(r.score))
	r["win"] = bool(o.get("win", false))
	r["label"] = str(o.get("label", ""))
	if raw.has("ratio"):
		return r
	var ratio := clampf(float(r.score), 0.0, 1.25)
	if r.win:
		ratio = maxf(ratio, float(d.get("minRatio", 0.0)))
	r["ratio"] = ratio
	# Tay nghề cao thì được trả thêm (careers.json perLevel.pay).
	r["bonus"] = 0
	if d.has("prof") and int(a.get("pay", 0)) > 0:
		r["bonus"] = g.round_k(float(a.pay) * ratio * Careers.mod(g, str(d.prof), "pay"))
	return r


## Cuối do_action: thưởng theo kết quả, EXP, chấn thương; ghi báo cáo vào g.last_minigame cho giao diện.
## Không có kết quả (mô phỏng, bảng cân bằng) thì tính như vừa đủ chỉ tiêu.
static func on_action(g, a: Dictionary, result: Dictionary) -> void:
	var id := str(a.get("minigame", ""))
	var d := def(g, id)
	if d.is_empty():
		return
	var score := float(result.get("score", result.get("ratio", 1.0))) if not result.is_empty() else 1.0
	var o := outcome(d, score)
	g.apply_effects(o.get("effects", {}))
	Attributes.grant(g, o.get("xp", {}))
	if d.has("prof"):
		Careers.gain(g, str(d.prof), float(o.get("prof", 0)))
	var hurt := roll_injury(g, id, int(result.get("fails", 0)))
	var parts := [str(o.get("label", ""))]
	var gains := reward_text(g, o)
	if gains != "":
		parts.append(gains)
	g.add_log("%s: %s" % [a.name, " · ".join(parts)], "event" if o.get("win", false) else "warn")
	g.last_minigame = {"id": id, "win": bool(o.get("win", false)), "text": " · ".join(parts),
		"injury": str(Survival.def(g, str(hurt.get("cond", ""))).get("name", "")) if not hurt.is_empty() else ""}


## Xác suất chấn thương sau ca: base + perFail × số lần hỏng (+ tired khi đang mệt), nhân theo mod injury (Thể chất).
static func injury_chance(g, id: String, fails := 0) -> float:
	var r: Dictionary = def(g, id).get("risk", {})
	if r.is_empty():
		return 0.0
	var p := float(r.get("base", 0.0)) + float(r.get("perFail", 0.0)) * fails
	if g.fatigue_warn():
		p += float(r.get("tired", 0.0))
	p *= maxf(0.0, 1.0 + g.mod("injury"))
	return clampf(p, 0.0, float(r.get("max", 1.0)))


## Gieo chấn thương (cố định theo ngày, số lần đã làm, hạt giống ván). Trúng thì bật trạng thái và trả viện phí;
## thiếu tiền thì phần còn lại thành khoản phải trả trạm y tế sau 3 ngày. Trả về mục injuries đã chọn hay {}.
static func roll_injury(g, id: String, fails: int) -> Dictionary:
	var p := injury_chance(g, id, fails)
	var list: Array = def(g, id).get("risk", {}).get("injuries", [])
	if p <= 0.0 or list.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([g.day(), g.count(str(def(g, id).get("action", {}).get("id", id))), int(g.s.get("seed", 7)), id, "chan_thuong"])
	if rng.randf() >= p:
		return {}
	var total := 0.0
	for inj in list:
		total += float(inj.get("w", 1.0))
	var pick := rng.randf() * total
	var chosen: Dictionary = list[list.size() - 1]
	for inj in list:
		pick -= float(inj.get("w", 1.0))
		if pick <= 0.0:
			chosen = inj
			break
	Survival.add(g, str(chosen.cond), 0.0, id)
	g.add_log(str(chosen.get("log", "Bị thương khi làm")), "warn")
	var bill := int(chosen.get("bill", 0))
	if bill > 0:
		var paid: int = g.spend(bill, "Viện phí trạm y tế")
		if paid < bill:
			g._add_payable({"id": "vien_phi_%d_%s" % [g.day(), id], "label": "Nợ viện phí trạm y tế", "amount": bill - paid, "due": g.day() + 3})
	return chosen


## Chữ ngắn cho phần thưởng của một mục outcomes: "Tâm trạng +10 · Móc khóa con cá · Thể chất +14 EXP".
static func reward_text(g, o: Dictionary) -> String:
	var parts := []
	var eff: Dictionary = o.get("effects", {})
	for k in eff:
		var v = eff[k]
		if str(k).begins_with("need."):
			var n := str(k).substr(5)
			parts.append("%s %s" % [NEED_NAMES.get(n, n), _signed(float(v))])
		elif str(k).begins_with("item."):
			parts.append(g.item_name(str(k).substr(5)) + ("" if int(v) == 1 else " ×%d" % int(v)))
		elif k == "fatigue":
			parts.append("Mệt %s" % _signed(float(v)))
		elif str(k).begins_with("rep."):
			parts.append("thân %s %s" % [g.rep_name(str(k).substr(4)), _signed(float(v))])
	for k in o.get("xp", {}):
		parts.append("%s +%d EXP" % [Attributes.stat_name(g, k), int(o.xp[k])])
	return " · ".join(parts)


static func _signed(v: float) -> String:
	return ("+%d" if v >= 0.0 else "−%d") % int(absf(v))


## Lời giới thiệu cho màn đầu của cảnh: chi phí, giờ, tiền công, thưởng từng mức, rủi ro, điều kiện.
static func info(g, id: String) -> Array:
	var d := def(g, id)
	var a: Dictionary = g.get_action(str(d.get("action", {}).get("id", id)))
	var out := []
	var head := "Mất %s" % _hours_text(float(d.get("hours", 1.0)))
	if int(d.get("cost", 0)) > 0:
		head += " · phí %s" % g.fmt_money(int(d.cost))
	if int(d.get("pay", 0)) > 0:
		var extra: float = Careers.mod(g, str(d.get("prof", "")), "pay") if d.has("prof") else 0.0
		head += " · tiền công tới %s%s" % [g.fmt_money(int(d.pay)), " (tay nghề +%d%%)" % int(extra * 100.0) if extra > 0.0 else ""]
	out.append(head)
	for o in d.get("outcomes", []):
		var line := "%s%s: %s" % [str(o.get("label", "")), " (%s)" % o.when if o.has("when") else "", reward_text(g, o)]
		if d.has("prof") and int(o.get("prof", 0)) > 0:
			line += " · tay nghề %s +%d" % [Careers.prof_name(g, str(d.prof)).to_lower(), int(o.prof)]
		out.append(line)
	var risk := injury_chance(g, id)
	if not d.get("risk", {}).is_empty():
		out.append("Rủi ro chấn thương khoảng %d%%, tăng khi làm hỏng%s" % [int(round(risk * 100.0)), ", đang mệt" if g.fatigue_warn() else ""])
	if not a.is_empty():
		var lock: String = g.action_status(a).get("reason", "")
		if lock != "":
			out.append("Chưa làm được: " + lock)
	return out


static func _hours_text(h: float) -> String:
	return ("%d phút" % int(round(h * 60.0))) if h < 1.0 else ("%s giờ" % str(snappedf(h, 0.1)).trim_suffix(".0"))
