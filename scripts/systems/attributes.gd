extends RefCounted
## Bốn thuộc tính nền tảng (data/systems/attributes.json, cfg.attributes): Thể chất (str), Trí tuệ (int), Nhanh nhẹn (agi),
## Nhạy bén (per). Mỗi thuộc tính có cấp 1..maxLevel và XP; làm việc, tán gẫu, giao hàng, lục ve chai thì có XP.
## Hiệu ứng bị động cộng theo cấp (perLevel) và đọc qua GameLogic.mod(): tốc độ đi, thêm giờ trong trò chơi nhỏ, bớt
## hao khi làm nặng, học nhanh, bán đồng nát được giá. Điều kiện "stat.X": cấp tối thiểu, hiệu ứng "xp.X": cộng XP.
## s.attr: {"str": {"lv": 1, "xp": 0.0}, …}.


static func data(g) -> Dictionary:
	return g.cfg.get("attributes", {})


static func order(g) -> Array:
	return data(g).get("order", [])


static func migrate(g) -> void:
	if not g.is_started() or data(g).is_empty() or g.s.has("attr"):
		return
	var attr := {}
	for k in order(g):
		attr[k] = {"lv": int(data(g).get("start", {}).get(k, 1)), "xp": 0.0}
	g.s["attr"] = attr


static func level(g, k: String) -> int:
	return int(g.s.get("attr", {}).get(k, {}).get("lv", 1))


static func xp(g, k: String) -> float:
	return float(g.s.get("attr", {}).get(k, {}).get("xp", 0.0))


static func max_level(g) -> int:
	return int(data(g).get("maxLevel", 5))


## XP cần để lên từ cấp lv, 0 nếu đã tối đa.
static func next_xp(g, lv: int) -> int:
	var arr: Array = data(g).get("xpToNext", [])
	return int(arr[lv - 1]) if lv < max_level(g) and lv - 1 < arr.size() else 0


static func stat_name(g, k: String) -> String:
	return str(data(g).get("stats", {}).get(k, {}).get("name", k))


## Cộng XP cho thuộc tính k (đã nhân tốc độ học của Trí tuệ). Trả về số cấp vừa lên.
static func gain(g, k: String, amount: float) -> int:
	if amount <= 0.0 or not g.s.get("attr", {}).has(k):
		return 0
	var st: Dictionary = g.s.attr[k]
	var lv := int(st.lv)
	var have := float(st.xp) + amount * maxf(0.0, 1.0 + g.mod("xp"))
	var ups := 0
	while next_xp(g, lv) > 0 and have >= float(next_xp(g, lv)):
		have -= float(next_xp(g, lv))
		lv += 1
		ups += 1
	st["lv"] = lv
	st["xp"] = 0.0 if next_xp(g, lv) == 0 else have
	if ups > 0:
		g.add_log("%s lên cấp %d" % [stat_name(g, k), lv], "event")
		if g.has_needs():
			g.need_adj("mood", float(data(g).get("levelUpMood", 0)) * ups)
	return ups


## Cộng XP theo bảng {thuộc tính: số}, nhân mult.
static func grant(g, table: Dictionary, mult := 1.0) -> void:
	for k in table:
		gain(g, str(k), float(table[k]) * mult)


## Sau khi làm xong việc a: XP theo trường xp của việc hay bảng actionXp, nhân theo kết quả trò chơi nhỏ (0,5..1,25).
static func on_action(g, a: Dictionary, result: Dictionary) -> void:
	var table: Dictionary = a.get("xp", data(g).get("actionXp", {}).get(str(a.get("id", "")), {}))
	var mult := 1.0 if result.is_empty() else clampf(float(result.get("ratio", 1.0)), 0.5, 1.25)
	grant(g, table, mult)


## XP của các việc ngoài cfg.actions: "talk", "delivery", "scavenge".
static func notify(g, kind: String) -> void:
	grant(g, data(g).get(kind, {}))


## Tổng hiệu ứng bị động k của các thuộc tính: (cấp − 1) × perLevel.
static func mod(g, k: String) -> float:
	var total := 0.0
	var per: Dictionary = data(g).get("perLevel", {})
	for a in per:
		total += float(level(g, a) - 1) * float(per[a].get(k, 0.0))
	return total


## Khóa hiệu ứng "xp.X": cộng XP. true nếu đã xử lý.
static func effect(g, k: String, v) -> bool:
	if k.begins_with("xp."):
		gain(g, k.substr(3), float(v))
		return true
	return false


## Khóa điều kiện "stat.X": cấp tối thiểu. null nếu không phải khóa của file này.
static func check(g, k: String, v) -> Variant:
	if not k.begins_with("stat."):
		return null
	var a := k.substr(5)
	if level(g, a) < int(v):
		return "Cần %s cấp %d (đang %d)" % [stat_name(g, a), int(v), level(g, a)]
	return ""


## Dòng cho giao diện: [{id, name, icon, desc, lv, xp, next}], next = 0 khi đã tối đa.
static func rows(g) -> Array:
	var out := []
	for k in order(g):
		var info: Dictionary = data(g).get("stats", {}).get(k, {})
		out.append({"id": k, "name": stat_name(g, k), "icon": str(info.get("icon", "person")), "desc": str(info.get("desc", "")),
			"lv": level(g, k), "xp": xp(g, k), "next": next_xp(g, level(g, k))})
	return out
