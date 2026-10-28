extends RefCounted
## Sinh tồn đa tầng (data/systems/survival.json, cfg.survival): ba chỉ số chính Độ no (fed), Vệ sinh (clean), Tâm trạng
## (mood) 0..100 vẫn nằm ở s.needs như cũ; file này thêm trạng thái (s.conds) và phần hao theo việc đang làm.
##   - Trạng thái theo ngưỡng (need, below, release): tự bật khi chỉ số tụt dưới below, tự tắt khi hồi tới release.
##   - Trạng thái có hạn (hours): buff, ốm; tắt khi qua mốc until (giờ tuyệt đối, game_clock.gd).
##   - mods của trạng thái: move (tốc độ), rate.<nhu cầu> (nhân tốc độ tụt), talk_rep, talk_mood; blocks: tag hay nhóm
##     việc bị chặn, kèm lý do hiện trên thẻ việc.
##   - activity: hao thêm mỗi giờ khi làm việc có tag (heavy, outdoor hôm mưa, workshop ở bàn sửa).
## GameLogic gọi update() mỗi lần _commit, on_action() sau mỗi việc, block() khi xét việc có làm được không.
## s.conds: {id: {"since": giờ tuyệt đối, "until": giờ tuyệt đối hay -1 nếu theo ngưỡng, "src": nguồn}}.


static func data(g) -> Dictionary:
	return g.cfg.get("survival", {})


## Tên gọi theo tài liệu thiết kế (hunger, hygiene) đổi sang khóa nhu cầu của bản này.
static func key(g, k: String) -> String:
	return str(data(g).get("aliases", {}).get(k, k))


static func hunger(g) -> float:
	return g.need("fed")


static func hygiene(g) -> float:
	return g.need("clean")


static func mood(g) -> float:
	return g.need("mood")


static func migrate(g) -> void:
	if g.is_started() and g.has_needs() and not g.s.has("conds"):
		g.s["conds"] = {}


static func conds(g) -> Dictionary:
	return g.s.get("conds", {})


static func def(g, id: String) -> Dictionary:
	return data(g).get("conditions", {}).get(id, {})


static func has(g, id: String) -> bool:
	return conds(g).has(id)


## Bật trạng thái id. hours > 0 thì có hạn từ bây giờ (đang có thì gia hạn tới mốc xa hơn); 0 thì lấy hours trong
## định nghĩa, không có thì giữ tới khi ngưỡng tắt hay bị gỡ.
static func add(g, id: String, hours := 0.0, src := "") -> void:
	var d := def(g, id)
	if d.is_empty() or not g.s.has("conds"):
		return
	if hours <= 0.0:
		hours = float(d.get("hours", 0.0))
	var until: float = g.now_abs() + hours if hours > 0.0 else -1.0
	var c: Dictionary = conds(g).get(id, {})
	if not c.is_empty():
		var old := float(c.get("until", -1.0))
		until = -1.0 if old < 0.0 or until < 0.0 else maxf(old, until)
	else:
		g.add_log("%s: %s" % [d.name, d.get("desc", "")], "event" if d.get("tone", "bad") == "good" else "warn")
	g.s.conds[id] = {"since": float(c.get("since", g.now_abs())), "until": until, "src": src}


static func clear(g, id: String) -> void:
	if conds(g).has(id):
		conds(g).erase(id)
		g.add_log("Hết %s" % str(def(g, id).get("name", id)).to_lower(), "event")


## Bỏ trạng thái hết hạn, bật/tắt trạng thái theo ngưỡng. Gọi mỗi lần _commit (sau khi nhu cầu đã tụt theo giờ).
static func update(g) -> void:
	if not g.is_started() or not g.has_needs() or not g.s.has("conds"):
		return
	var now: float = g.now_abs()
	for id in conds(g).keys():
		var until := float(conds(g)[id].get("until", -1.0))
		if until >= 0.0 and now >= until:
			clear(g, id)
	var defs: Dictionary = data(g).get("conditions", {})
	for id in defs:
		var d: Dictionary = defs[id]
		if not d.has("need"):
			continue
		var v: float = g.need(str(d.need))
		if not has(g, id) and v < float(d.below):
			add(g, id, 0.0, "need")
		elif has(g, id) and str(conds(g)[id].get("src", "")) == "need" and v >= float(d.get("release", d.below)):
			clear(g, id)


## Tổng một hiệu ứng (mods) của các trạng thái đang có.
static func mod(g, k: String) -> float:
	var total := 0.0
	for id in conds(g):
		total += float(def(g, id).get("mods", {}).get(k, 0.0))
	return total


## Hệ số tốc độ tụt mỗi giờ của nhu cầu k (1 = bình thường).
static func rate(g, k: String) -> float:
	return maxf(0.0, 1.0 + mod(g, "rate." + k))


## Hệ số tốc độ đi do trạng thái: lấy mức chậm nhất, không cộng dồn (đói lả và trầm cảm cùng lúc vẫn chỉ chậm 30%).
static func move_factor(g) -> float:
	var f := 1.0
	for id in conds(g):
		f = minf(f, 1.0 + float(def(g, id).get("mods", {}).get("move", 0.0)))
	return f


## Tag của việc: trường tags trong config, không có thì tra bảng actionTags.
static func tags(g, a: Dictionary) -> Array:
	return a.get("tags", data(g).get("actionTags", {}).get(str(a.get("id", "")), []))


## Lý do việc a bị chặn bởi trạng thái, "" nếu không.
static func block(g, a: Dictionary) -> String:
	var t := tags(g, a)
	for id in conds(g):
		var d := def(g, id)
		for b in d.get("blocks", []):
			if b == a.get("group", "") or t.has(b):
				return str(d.get("reason", d.get("name", id)))
	return ""


## Lý do không nhận được việc kiếm tiền nói chung (đơn giao hàng, việc không có trong cfg.actions).
static func block_work(g) -> String:
	return block(g, {"group": "work"})


## Hao thêm theo tag trong hours giờ làm. Việc nặng bớt hao theo Thể chất (activity.heavy); việc ngoài trời chỉ hao
## thêm hôm mưa. Nhân nhịp đói, bẩn của độ khó như phần tụt theo giờ.
static func activity(g, tag_list: Array, hours: float) -> void:
	if not g.has_needs() or hours <= 0.0:
		return
	var prof: Dictionary = data(g).get("activity", {})
	var rate_k := float(g._diff().get("needsRate", 1.0))
	for t in tag_list:
		var key_t := str(t)
		if key_t == "outdoor":
			if not g.s.today.get("rain", false):
				continue
			key_t = "rain"
		var mult := rate_k * maxf(0.0, 1.0 + g.mod("activity." + key_t))
		for k in prof.get(key_t, {}):
			g.need_adj(k, float(prof[key_t][k]) * hours * mult)


## Sau khi làm xong việc a (hours giờ): hao thêm theo tag và bật các trạng thái việc đó mang lại (actionConds).
static func on_action(g, a: Dictionary, hours: float) -> void:
	activity(g, tags(g, a), hours)
	var given: Dictionary = data(g).get("actionConds", {}).get(str(a.get("id", "")), {})
	for id in given:
		add(g, id, float(given[id]), str(a.id))


## Hiệu ứng của việc a sau khi tính Thể chất: việc nặng thì Mệt cộng thêm ít hơn (fatigue.heavy).
static func action_effects(g, a: Dictionary) -> Dictionary:
	var eff: Dictionary = a.get("effects", {})
	if not tags(g, a).has("heavy") or float(eff.get("fatigue", 0.0)) <= 0.0:
		return eff
	var out := eff.duplicate()
	out["fatigue"] = float(eff.fatigue) * maxf(0.0, 1.0 + g.mod("fatigue.heavy"))
	return out


## Khóa hiệu ứng: "cond.X": số giờ (true: theo định nghĩa, false: gỡ), "cond_clear.X": gỡ. true nếu đã xử lý.
static func effect(g, k: String, v) -> bool:
	if k.begins_with("cond."):
		if v is bool and not v:
			clear(g, k.substr(5))
		else:
			add(g, k.substr(5), 0.0 if v is bool else float(v), "effect")
		return true
	if k.begins_with("cond_clear."):
		clear(g, k.substr(11))
		return true
	return false


## Khóa điều kiện: "has_cond": id, "no_cond": id hay [id…]. null nếu không phải khóa của file này.
static func check(g, k: String, v) -> Variant:
	match k:
		"has_cond":
			return "" if has(g, str(v)) else "-"
		"no_cond":
			for id in (v if v is Array else [v]):
				if has(g, str(id)):
					return "Đang %s" % str(def(g, str(id)).get("name", id)).to_lower()
			return ""
	return null


## Trạng thái đang có cho giao diện: [{id, name, tone, icon, desc, left: số giờ còn lại hay -1}].
static func active(g) -> Array:
	var out := []
	for id in conds(g):
		var d := def(g, id)
		var until := float(conds(g)[id].get("until", -1.0))
		out.append({"id": id, "name": str(d.get("name", id)), "tone": str(d.get("tone", "bad")), "icon": str(d.get("icon", "heart")),
			"desc": str(d.get("desc", "")), "left": until - g.now_abs() if until >= 0.0 else -1.0})
	return out
