extends RefCounted
## Tay nghề theo nghề và bằng cấp (data/systems/careers.json, cfg.careers). s.prof: {nghề: {"lv": 1, "xp": 0.0}}, chỉ có
## nghề đã từng làm; s.certs: [bằng cấp đã có]. Điều kiện "prof.X": cấp nghề tối thiểu, "cert": bằng cấp cần có; hiệu ứng
## "prof.X": cộng EXP nghề, "cert.X": true trao bằng. Hiệu ứng theo cấp nghề (perLevel) đọc qua mod().


static func data(g) -> Dictionary:
	return g.cfg.get("careers", {})


static func migrate(g) -> void:
	if not g.is_started() or data(g).is_empty():
		return
	if not g.s.has("prof"):
		g.s["prof"] = {}
	if not g.s.has("certs"):
		g.s["certs"] = []


static func prof_name(g, id: String) -> String:
	return str(data(g).get("profs", {}).get(id, {}).get("name", id))


static func level(g, id: String) -> int:
	return int(g.s.get("prof", {}).get(id, {}).get("lv", 1))


static func xp(g, id: String) -> float:
	return float(g.s.get("prof", {}).get(id, {}).get("xp", 0.0))


## EXP cần để lên từ cấp lv, 0 nếu đã tối đa.
static func next_xp(g, lv: int) -> int:
	var arr: Array = data(g).get("xpToNext", [])
	return int(arr[lv - 1]) if lv - 1 < arr.size() else 0


## Cộng EXP nghề id (đã nhân tốc độ học của Trí tuệ). Trả về số cấp vừa lên.
static func gain(g, id: String, amount: float) -> int:
	if amount <= 0.0 or not g.s.has("prof"):
		return 0
	if not g.s.prof.has(id):
		g.s.prof[id] = {"lv": 1, "xp": 0.0}
	var st: Dictionary = g.s.prof[id]
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
		g.add_log("Tay nghề %s lên cấp %d" % [prof_name(g, id).to_lower(), lv], "event")
	return ups


## Hiệu ứng k theo cấp của nghề id: (cấp − 1) × perLevel.
static func mod(g, id: String, k: String) -> float:
	return float(level(g, id) - 1) * float(data(g).get("perLevel", {}).get(k, 0.0))


static func has_cert(g, id: String) -> bool:
	return g.s.get("certs", []).has(id)


static func cert_name(g, id: String) -> String:
	return str(data(g).get("certs", {}).get(id, {}).get("name", id))


static func effect(g, k: String, v) -> bool:
	if k.begins_with("prof."):
		gain(g, k.substr(5), float(v))
		return true
	if k.begins_with("cert."):
		var id := k.substr(5)
		if bool(v) and g.s.has("certs") and not has_cert(g, id):
			g.s.certs.append(id)
			g.add_log("Có %s" % cert_name(g, id), "event")
		elif not bool(v):
			g.s.get("certs", []).erase(id)
		return true
	return false


static func check(g, k: String, v) -> Variant:
	if k == "cert":
		for id in (v if v is Array else [v]):
			if not has_cert(g, str(id)):
				return "Cần %s" % cert_name(g, str(id))
		return ""
	if k.begins_with("prof."):
		var id := k.substr(5)
		if level(g, id) < int(v):
			return "Cần tay nghề %s cấp %d (đang %d)" % [prof_name(g, id).to_lower(), int(v), level(g, id)]
		return ""
	return null


## Dòng cho giao diện: [{id, name, lv, xp, next}] của các nghề đã làm.
static func rows(g) -> Array:
	var out := []
	for id in g.s.get("prof", {}):
		out.append({"id": id, "name": prof_name(g, id), "lv": level(g, id), "xp": xp(g, id), "next": next_xp(g, level(g, id))})
	return out
