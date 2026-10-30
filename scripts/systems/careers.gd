extends RefCounted
## Tay nghề theo nghề, bằng cấp, học nghề buổi tối và cây kỹ năng (data/systems/careers.json, cfg.careers).
##   - s.prof: {nghề: {"lv": 1, "xp": 0.0}}, chỉ có nghề đã từng làm. Điều kiện "prof.X": cấp tối thiểu; hiệu ứng
##     "prof.X": cộng EXP nghề. Việc có prof, profXp cộng EXP khi làm xong và được trả thêm theo cấp nghề.
##   - s.certs: [bằng cấp]. Điều kiện "cert": id, [id…] (đủ cả) hay "a|b" (một trong); hiệu ứng "cert.X": true trao bằng.
##     Cờ truyện trong flagCerts tự đổi thành bằng (lớp điện lạnh chương 5).
##   - s.courses: {lớp: {"state": "studying" | "done", "progress", "tries"}}. register() sinh việc ghi danh, đi học,
##     thi ở chỗ học và việc tự ôn; tiến độ mỗi buổi tăng theo Trí tuệ; thi đỗ thì có bằng.
##   - s.talents: {"earned", "spent", "owned"}. Điểm kỹ năng có được khi nghề lên cấp, khi có bằng, cộng điểm của lịch
##     sự kiện (s.scheduler.skill_points); học kỹ năng thì mods cộng vào GameLogic.mod().


static func data(g) -> Dictionary:
	return g.cfg.get("careers", {})


static func migrate(g) -> void:
	if not g.is_started() or data(g).is_empty():
		return
	for k in ["prof", "courses"]:
		if not g.s.has(k):
			g.s[k] = {}
	if not g.s.has("certs"):
		g.s["certs"] = []
	if not g.s.has("talents"):
		g.s["talents"] = {"earned": 0, "spent": 0, "owned": []}
	var fc: Dictionary = data(g).get("flagCerts", {})
	for f in fc:
		if g.s.flags.get(f, false) and not has_cert(g, str(fc[f])):
			grant_cert(g, str(fc[f]))


# ---------------------------------------------------------------- nạp: việc học và việc cần bằng

## Sinh việc của các lớp học đêm, việc tự ôn và việc cần bằng vào cfg.actions. Gọi một lần trong load_data.
static func register(g) -> void:
	var school: Dictionary = data(g).get("school", {})
	for id in data(g).get("courses", {}):
		var c: Dictionary = data(g).courses[id]
		var loc := str(school.get("location", ""))
		var enroll_req: Dictionary = c.get("require", {}).duplicate()
		g.cfg.actions.append({"id": "ghi_danh_" + id, "group": "life", "location": loc, "hours": 0.5, "cost": int(c.get("fee", 0)),
			"name": "Ghi danh %s buổi tối (%s)" % [c.name, g.fmt_money(int(c.get("fee", 0)))], "window": [8, 20],
			"require": enroll_req, "showIf": {"course_open": id}, "effects": {"course_enroll." + id: true}, "desc": str(c.get("desc", ""))})
		var eff: Dictionary = c.get("effects", {}).duplicate()
		eff["course_study." + id] = true
		for k in c.get("xp", {}):
			eff["xp." + k] = c.xp[k]
		g.cfg.actions.append({"id": "hoc_" + id, "group": "life", "location": loc, "hours": float(c.get("hours", 2.5)), "perDay": 1,
			"name": "Đi học %s" % c.name, "window": c.get("window", [18, 21]), "require": {"weekend": false},
			"showIf": {"course_studying": id}, "effects": eff})
		g.cfg.actions.append({"id": "thi_" + id, "group": "life", "location": loc, "hours": 2.0, "perDay": 1, "cost": int(c.get("examFee", 0)),
			"name": "Thi lấy %s" % cert_name(g, str(c.cert)).to_lower(), "window": [8, 17], "require": {"weekend": false},
			"showIf": {"course_ready": id}, "effects": {"course_exam." + id: true}})
	var r: Dictionary = data(g).get("review", {})
	if not r.is_empty():
		var eff := {"course_review": float(r.get("progress", 0))}
		for k in r.get("xp", {}):
			eff["xp." + k] = r.xp[k]
		g.cfg.actions.append({"id": str(r.id), "group": "life", "location": str(r.location), "name": str(r.name), "hours": float(r.get("hours", 1)),
			"cost": int(r.get("cost", 0)), "perDay": 1, "showIf": {"course_studying_any": true}, "effects": eff})
	for j in data(g).get("jobs", []):
		var a: Dictionary = j.duplicate(true)
		# EXP thuộc tính lấy từ trường xp của việc, không theo bảng actionXp.
		a["xp"] = j.get("xp", {})
		g.cfg.actions.append(a)


# ---------------------------------------------------------------- nghề

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


## Cộng EXP nghề id (đã nhân tốc độ học của Trí tuệ). Trả về số cấp vừa lên; mỗi cấp thêm điểm kỹ năng.
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
		_earn_points(g, ups * int(data(g).get("talentPoints", {}).get("perProfLevel", 0)))
	return ups


## Hiệu ứng k theo cấp của nghề id: (cấp − 1) × perLevel.
static func mod(g, id: String, k: String) -> float:
	return float(level(g, id) - 1) * float(data(g).get("perLevel", {}).get(k, 0.0))


## Hệ số tiền công của việc a theo cấp nghề và kỹ năng "việc cần bằng" (việc có trò chơi nhỏ đã cộng ở minigames.gd).
static func pay_mult(g, a: Dictionary) -> float:
	if a.has("minigame"):
		return 1.0
	var m := 1.0
	if a.has("prof"):
		m += mod(g, str(a.prof), "pay")
	if a.get("require", {}).has("cert"):
		m += talent_mod(g, "pay.cert")
	return m


## Sau khi làm xong việc a: EXP nghề nếu việc có prof, profXp.
static func on_action(g, a: Dictionary) -> void:
	if a.has("prof") and a.has("profXp"):
		gain(g, str(a.prof), float(a.profXp))


# ---------------------------------------------------------------- bằng cấp

static func has_cert(g, id: String) -> bool:
	return g.s.get("certs", []).has(id)


static func cert_name(g, id: String) -> String:
	return str(data(g).get("certs", {}).get(id, {}).get("name", id))


static func grant_cert(g, id: String) -> void:
	if not g.s.has("certs") or has_cert(g, id):
		return
	g.s.certs.append(id)
	g.add_log("Có %s" % cert_name(g, id), "event")
	_earn_points(g, int(data(g).get("talentPoints", {}).get("perCert", 0)))


# ---------------------------------------------------------------- học nghề

static func course(g, id: String) -> Dictionary:
	return data(g).get("courses", {}).get(id, {})


static func course_state(g, id: String) -> Dictionary:
	return g.s.get("courses", {}).get(id, {})


## Tiến độ một buổi học lớp id: perSession × (1 + intBonus × (Trí tuệ − 1)).
static func session_progress(g, id: String) -> float:
	var c := course(g, id)
	return float(c.get("perSession", 10)) * (1.0 + float(c.get("intBonus", 0.0)) * float(g.Attributes.level(g, "int") - 1))


## Xác suất thi đỗ lớp id.
static func pass_chance(g, id: String) -> float:
	var c := course(g, id)
	return clampf(float(c.get("pass", 0.7)) + float(c.get("passPerInt", 0.0)) * float(g.Attributes.level(g, "int") - 1), 0.0, 0.95)


static func _study(g, id: String, amount: float) -> void:
	var st := course_state(g, id)
	if st.is_empty() or st.state != "studying":
		return
	var need := float(course(g, id).get("need", 100))
	var before := float(st.progress)
	st["progress"] = minf(need, before + amount)
	if before < need and float(st.progress) >= need:
		g.add_log("Học xong %s, đăng ký thi được rồi" % str(course(g, id).name), "event")


static func _exam(g, id: String) -> void:
	var st := course_state(g, id)
	if st.is_empty():
		return
	st["tries"] = int(st.get("tries", 0)) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([g.day(), int(st.tries), int(g.s.get("seed", 7)), id, "thi"])
	if rng.randf() < pass_chance(g, id):
		st["state"] = "done"
		grant_cert(g, str(course(g, id).cert))
		g.need_adj("mood", 12.0)
	else:
		g.add_log("Thi trượt %s, ôn thêm rồi thi lại hôm khác" % cert_name(g, str(course(g, id).cert)).to_lower(), "warn")
		g.need_adj("mood", -8.0)


# ---------------------------------------------------------------- cây kỹ năng

static func talent(g, id: String) -> Dictionary:
	return data(g).get("talents", {}).get(id, {})


static func owns(g, id: String) -> bool:
	return g.s.get("talents", {}).get("owned", []).has(id)


## Điểm kỹ năng còn dùng được: điểm có được + điểm của lịch sự kiện − điểm đã dùng.
static func points(g) -> int:
	var t: Dictionary = g.s.get("talents", {})
	return int(t.get("earned", 0)) + int(g.s.get("scheduler", {}).get("skill_points", 0)) - int(t.get("spent", 0))


static func _earn_points(g, n: int) -> void:
	if n <= 0 or not g.s.has("talents"):
		return
	g.s.talents["earned"] = int(g.s.talents.earned) + n
	g.add_log("Có thêm %d điểm kỹ năng (bảng Nhân vật)" % n, "event")


## "" nếu học được kỹ năng id, ngược lại là lý do.
static func talent_lock(g, id: String) -> String:
	var t := talent(g, id)
	if t.is_empty():
		return "-"
	if owns(g, id):
		return "Đã học"
	var reason: String = g.check(t.get("require", {}))
	if reason != "":
		return reason
	if points(g) < int(t.get("cost", 1)):
		return "Cần %d điểm kỹ năng" % int(t.get("cost", 1))
	return ""


static func learn(g, id: String) -> bool:
	if talent_lock(g, id) != "":
		return false
	g.s.talents["spent"] = int(g.s.talents.spent) + int(talent(g, id).get("cost", 1))
	g.s.talents.owned.append(id)
	g.add_log("Học kỹ năng %s" % str(talent(g, id).name), "event")
	return true


## Tổng hiệu ứng k của các kỹ năng đã học.
static func talent_mod(g, k: String) -> float:
	var total := 0.0
	for id in g.s.get("talents", {}).get("owned", []):
		total += float(talent(g, id).get("mods", {}).get(k, 0.0))
	return total


# ---------------------------------------------------------------- khóa hiệu ứng, điều kiện

static func effect(g, k: String, v) -> bool:
	if k.begins_with("prof."):
		gain(g, k.substr(5), float(v))
		return true
	if k.begins_with("cert."):
		if bool(v):
			grant_cert(g, k.substr(5))
		else:
			g.s.get("certs", []).erase(k.substr(5))
		return true
	if k.begins_with("course_enroll."):
		if g.s.has("courses"):
			g.s.courses[k.substr(14)] = {"state": "studying", "progress": 0.0, "tries": 0, "day": g.day()}
			g.add_log("Ghi danh %s" % str(course(g, k.substr(14)).get("name", "")), "event")
		return true
	if k.begins_with("course_study."):
		_study(g, k.substr(13), session_progress(g, k.substr(13)))
		return true
	if k == "course_review":
		for id in g.s.get("courses", {}):
			_study(g, id, float(v) * (1.0 + float(course(g, id).get("intBonus", 0.0)) * float(g.Attributes.level(g, "int") - 1)))
		return true
	if k.begins_with("course_exam."):
		_exam(g, k.substr(12))
		return true
	return false


static func check(g, k: String, v) -> Variant:
	match k:
		"cert":
			if v is String and v.contains("|"):
				for id in v.split("|"):
					if has_cert(g, id):
						return ""
				return "Cần một bằng nghề"
			for id in (v if v is Array else [v]):
				if not has_cert(g, str(id)):
					return "Cần %s" % cert_name(g, str(id))
			return ""
		"talent":
			return "" if owns(g, str(v)) else "Cần kỹ năng %s" % str(talent(g, str(v)).get("name", v))
		"course_open":
			return "" if course_state(g, str(v)).is_empty() and not has_cert(g, str(course(g, str(v)).get("cert", ""))) else "-"
		"course_studying":
			var st := course_state(g, str(v))
			return "" if not st.is_empty() and st.state == "studying" and float(st.progress) < float(course(g, str(v)).get("need", 100)) else "-"
		"course_ready":
			var st := course_state(g, str(v))
			return "" if not st.is_empty() and st.state == "studying" and float(st.progress) >= float(course(g, str(v)).get("need", 100)) else "-"
		"course_studying_any":
			for id in g.s.get("courses", {}):
				if check(g, "course_studying", id) == "":
					return "" if bool(v) else "-"
			return "-" if bool(v) else ""
	if k.begins_with("prof."):
		var id := k.substr(5)
		if level(g, id) < int(v):
			return "Cần tay nghề %s cấp %d (đang %d)" % [prof_name(g, id).to_lower(), int(v), level(g, id)]
		return ""
	return null


# ---------------------------------------------------------------- giao diện

## Dòng nghề: [{id, name, lv, xp, next}] của các nghề đã làm.
static func rows(g) -> Array:
	var out := []
	for id in g.s.get("prof", {}):
		out.append({"id": id, "name": prof_name(g, id), "lv": level(g, id), "xp": xp(g, id), "next": next_xp(g, level(g, id))})
	return out


## Lớp đang học: [{id, name, progress, need, ready}].
static func course_rows(g) -> Array:
	var out := []
	for id in g.s.get("courses", {}):
		var st := course_state(g, id)
		if st.state == "studying":
			var need := float(course(g, id).get("need", 100))
			out.append({"id": id, "name": str(course(g, id).get("name", id)), "progress": float(st.progress), "need": need,
				"ready": float(st.progress) >= need})
	return out


## Cây kỹ năng theo nhánh: [{id, name, branch, cost, desc, owned, lock}].
static func talent_rows(g) -> Array:
	var out := []
	for id in data(g).get("talents", {}):
		var t: Dictionary = data(g).talents[id]
		out.append({"id": id, "name": str(t.name), "branch": str(t.get("branch", "")), "cost": int(t.get("cost", 1)), "desc": str(t.get("desc", "")),
			"owned": owns(g, id), "lock": talent_lock(g, id)})
	return out
