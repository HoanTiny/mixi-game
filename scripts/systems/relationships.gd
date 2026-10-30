extends RefCounted
## Quan hệ NPC (data/systems/relationships.json, cfg.relationships; kiểu dữ liệu ở docs/schema/relationships.d.ts).
## Điểm thân thiết 0..100 vẫn là s.rep[npc]; file này thêm:
##   - bậc quan hệ theo điểm (tiers), đặt riêng được cho từng người (tuyến tình cảm có bậc riêng);
##   - mốc: qua điểm at lần đầu (và thỏa when) thì mở tin nhắn, đẩy sự kiện truyện vào hàng chờ, chạy effects;
##   - trạng thái quan hệ (Cặp đôi): bật kèm một trạng thái của survival.json nên buff đi qua đường sẵn có
##     (regen.mood: hồi Tâm trạng mỗi giờ, fatigue.rate: mệt chậm hơn); điểm tụt dưới breakBelow thì mất;
##   - tin nhắn trên điện thoại (app Tin nhắn): tới máy khi thỏa when hay được mốc mở, sau giờ after; trả lời thì
##     chạy effects của lựa chọn và tính như đã gặp;
##   - phai nhạt: người có decays lâu không gặp quá graceDays thì mỗi ngày tụt perDay, không dưới floor.
## GameLogic gọi tick() mỗi lần _commit, touch() khi điểm của ai đó tăng, effect()/check() cho các khóa rel_*.
## s.rel: {"fired": [], "status": {}, "seen": {}, "unlocked": [], "inbox": [], "day": ngày đã tính phai nhạt}.


static func data(g) -> Dictionary:
	return g.cfg.get("relationships", {})


static func npc_def(g, npc: String) -> Dictionary:
	return data(g).get("npcs", {}).get(npc, {})


static func migrate(g) -> void:
	_migrate_lunch(g)
	if not g.is_started() or data(g).is_empty() or g.s.has("rel"):
		return
	g.s["rel"] = {"fired": [], "status": {}, "seen": {}, "unlocked": [], "inbox": [], "day": g.day()}
	var npcs: Dictionary = data(g).get("npcs", {})
	for npc in npcs:
		if npcs[npc].has("start") and not g.s.rep.has(npc):
			g.s.rep[npc] = int(npcs[npc].start)
		g.s.rel.seen[npc] = g.day()


static func rel(g) -> Dictionary:
	return g.s.get("rel", {})


static func score(g, npc: String) -> int:
	return int(g.s.rep.get(npc, 0))


## Bậc hiện tại {name, color, min}: bậc cao nhất có min ≤ điểm, bậc riêng của người này nếu có.
static func tier(g, npc: String) -> Dictionary:
	var tiers: Array = npc_def(g, npc).get("tiers", data(g).get("tiers", []))
	var best := {"name": "", "color": "e8e2d2", "min": 0}
	for t in tiers:
		if score(g, npc) >= int(t.min) and int(t.min) >= int(best.min):
			best = t
	return best


## Bậc kế tiếp (để hiện "còn x điểm nữa"), rỗng nếu đã cao nhất.
static func next_tier(g, npc: String) -> Dictionary:
	var tiers: Array = npc_def(g, npc).get("tiers", data(g).get("tiers", []))
	var best := {}
	for t in tiers:
		if int(t.min) > score(g, npc) and (best.is_empty() or int(t.min) < int(best.min)):
			best = t
	return best


static func status(g, npc: String) -> String:
	return str(rel(g).get("status", {}).get(npc, ""))


static func status_def(g, npc: String, id: String) -> Dictionary:
	return npc_def(g, npc).get("statuses", {}).get(id, {})


static func status_name(g, npc: String) -> String:
	var id := status(g, npc)
	return "" if id == "" else str(status_def(g, npc, id).get("name", id))


## Đặt hay gỡ trạng thái quan hệ ("" là gỡ). Trạng thái có condition thì bật/tắt trạng thái sinh tồn tương ứng.
static func set_status(g, npc: String, id: String) -> void:
	if not g.s.has("rel"):
		return
	var old := status(g, npc)
	if old == id:
		return
	if old != "":
		var cond_old := str(status_def(g, npc, old).get("condition", ""))
		if cond_old != "":
			g.Survival.clear(g, cond_old)
		g.s.rel.status.erase(npc)
	if id != "":
		g.s.rel.status[npc] = id
		var cond := str(status_def(g, npc, id).get("condition", ""))
		if cond != "":
			g.Survival.add(g, cond, 0.0, "rel:" + npc)
		g.add_log("%s và An: %s" % [g.rep_name(npc), str(status_def(g, npc, id).get("name", id))], "event")
	touch(g, npc)


## Đã gặp, nói chuyện hay làm gì đó cho người này hôm nay: dời mốc phai nhạt.
static func touch(g, npc: String) -> void:
	if g.s.has("rel"):
		g.s.rel.seen[npc] = g.day()


## Mỗi lần _commit: phai nhạt (một lần mỗi ngày), mốc, trạng thái mất khi điểm tụt, tin nhắn tới máy.
static func tick(g) -> void:
	if not g.is_started() or not g.s.has("rel"):
		return
	var r: Dictionary = g.s.rel
	var npcs: Dictionary = data(g).get("npcs", {})
	if int(r.get("day", g.day())) != g.day():
		r["day"] = g.day()
		_decay(g, npcs)
	for npc in npcs:
		var d: Dictionary = npcs[npc]
		for m in d.get("milestones", []):
			var key := "%s:%s" % [npc, m.id]
			if r.fired.has(key) or score(g, npc) < int(m.at) or g.check(m.get("when", {})) != "":
				continue
			r.fired.append(key)
			for msg in m.get("unlockMessages", []):
				if not r.unlocked.has(msg):
					r.unlocked.append(msg)
			if m.has("event"):
				g.s.queue.append({"id": str(m.event), "data": {}})
			g.apply_effects(m.get("effects", {}))
		var st := status(g, npc)
		if st != "" and score(g, npc) < int(status_def(g, npc, st).get("breakBelow", -1)):
			var ev := str(status_def(g, npc, st).get("breakEvent", ""))
			set_status(g, npc, "")
			if ev != "":
				g.s.queue.append({"id": ev, "data": {}})
		for msg in d.get("messages", []):
			_deliver(g, npc, msg)


static func _decay(g, npcs: Dictionary) -> void:
	var dc: Dictionary = data(g).get("decay", {})
	for npc in npcs:
		if not npcs[npc].get("decays", false) or not g.s.rep.has(npc):
			continue
		var idle: int = g.day() - int(g.s.rel.seen.get(npc, g.day()))
		if idle > int(dc.get("graceDays", 3)) and score(g, npc) > int(dc.get("floor", 30)):
			g.s.rep[npc] = maxi(int(dc.get("floor", 30)), score(g, npc) - int(dc.get("perDay", 2)))
			if idle == int(dc.get("graceDays", 3)) + 1:
				g.add_log("Lâu rồi An không gặp %s" % g.rep_name(npc), "warn")


static func _has_msg(g, id: String) -> bool:
	for e in rel(g).get("inbox", []):
		if e.msg == id:
			return true
	return false


static func _deliver(g, npc: String, msg: Dictionary) -> void:
	var id := str(msg.id)
	if _has_msg(g, id) or g.clock() < float(msg.get("after", 0.0)):
		return
	if msg.get("unlockOnly", false):
		if not rel(g).unlocked.has(id):
			return
	elif not rel(g).unlocked.has(id) and (not msg.has("when") or g.check(msg.when) != ""):
		return
	g.s.rel.inbox.append({"npc": npc, "msg": id, "at": g.now_abs(), "read": false, "replied": -1})
	g.add_log("Tin nhắn mới từ " + g.rep_name(npc), "event")


static func message_def(g, npc: String, id: String) -> Dictionary:
	for m in npc_def(g, npc).get("messages", []):
		if m.id == id:
			return m
	return {}


static func unread(g) -> int:
	var n := 0
	for e in rel(g).get("inbox", []):
		if not e.read or (int(e.replied) < 0 and not message_def(g, e.npc, e.msg).get("replies", []).is_empty()):
			n += 1
	return n


## Danh sách cuộc trò chuyện cho app Tin nhắn, mới nhất trước: [{npc, name, last, unread, at}].
static func threads(g) -> Array:
	var by := {}
	for e in rel(g).get("inbox", []):
		var t: Dictionary = by.get(e.npc, {"npc": e.npc, "name": g.rep_name(e.npc), "last": "", "unread": 0, "at": 0.0})
		var lines: Array = message_def(g, e.npc, e.msg).get("lines", [])
		t["last"] = str(lines[lines.size() - 1]) if not lines.is_empty() else ""
		t["at"] = float(e.at)
		if not e.read or (int(e.replied) < 0 and not message_def(g, e.npc, e.msg).get("replies", []).is_empty()):
			t["unread"] = int(t.unread) + 1
		by[e.npc] = t
	var out := by.values()
	out.sort_custom(func(a, b) -> bool: return float(a.at) > float(b.at))
	return out


## Các tin của một người theo thứ tự tới máy, đánh dấu đã đọc: [{i: chỉ số trong inbox, lines, replies, replied, answer}].
static func thread(g, npc: String) -> Array:
	var out := []
	var inbox: Array = rel(g).get("inbox", [])
	for i in inbox.size():
		var e: Dictionary = inbox[i]
		if e.npc != npc:
			continue
		e["read"] = true
		var m := message_def(g, npc, e.msg)
		var replies: Array = m.get("replies", [])
		var picked: int = int(e.replied)
		out.append({"i": i, "lines": m.get("lines", []), "replies": replies, "replied": picked,
			"mine": str(replies[picked].label) if picked >= 0 and picked < replies.size() else "",
			"answer": str(replies[picked].get("answer", "")) if picked >= 0 and picked < replies.size() else "",
			"at": float(e.at)})
	return out


## Trả lời tin thứ i trong inbox bằng lựa chọn k. Trả về "" nếu được, lý do nếu không.
static func reply(g, i: int, k: int) -> String:
	var inbox: Array = rel(g).get("inbox", [])
	if i < 0 or i >= inbox.size() or int(inbox[i].replied) >= 0:
		return "-"
	var e: Dictionary = inbox[i]
	var replies: Array = message_def(g, e.npc, e.msg).get("replies", [])
	if k < 0 or k >= replies.size():
		return "-"
	var lock: String = g.check(replies[k].get("require", {}))
	if lock != "":
		return lock
	e["replied"] = k
	e["read"] = true
	g.add_rep(e.npc, float(data(g).get("replyRep", 1)))
	g.apply_effects(replies[k].get("effects", {}))
	touch(g, e.npc)
	g.add_log("Nhắn lại cho " + g.rep_name(e.npc))
	g._commit()
	return ""


## Người có anchor ở chỗ loc (xe hàng rong) để bảng địa điểm thêm thẻ nói chuyện: [{id, name}].
static func npcs_at(g, loc: String) -> Array:
	var out := []
	var npcs: Dictionary = data(g).get("npcs", {})
	for npc in npcs:
		if str(npcs[npc].get("anchor", "")) == loc and g.talks.has(npc):
			out.append({"id": npc, "name": g.rep_name(npc)})
	return out


## Dòng cho bảng Nhân vật: bậc, trạng thái, điểm còn thiếu tới bậc sau.
static func card(g, npc: String) -> Dictionary:
	var t := tier(g, npc)
	var nt := next_tier(g, npc)
	return {"tier": str(t.get("name", "")), "color": str(t.get("color", "e8e2d2")), "status": status_name(g, npc),
		"next": "" if nt.is_empty() else "%s ở %d" % [str(nt.name), int(nt.min)], "romance": npc_def(g, npc).get("romance", false)}


## Khóa hiệu ứng: "rel_status.X": id trạng thái ("" để gỡ); "rel_unlock": id tin nhắn. true nếu đã xử lý.
static func effect(g, k: String, v) -> bool:
	if k.begins_with("rel_status."):
		set_status(g, k.substr(11), str(v))
		return true
	if k == "rel_unlock":
		if g.s.has("rel") and not g.s.rel.unlocked.has(str(v)):
			g.s.rel.unlocked.append(str(v))
		return true
	return false


## Khóa điều kiện: "rel_status.X": id trạng thái phải có; "rel_tier.X": tên bậc tối thiểu theo min; "has_item": món đồ
## đang giữ (s.qitems). null nếu không phải khóa của file này.
static func check(g, k: String, v) -> Variant:
	if k.begins_with("rel_status."):
		return "" if status(g, k.substr(11)) == str(v) else "-"
	if k == "has_item":
		var have := int(g.s.get("qitems", {}).get(str(v), 0)) + int(g.s.get("inv", {}).get(str(v), 0))
		return "" if have > 0 else "Chưa có %s" % g.item_name(str(v)).to_lower()
	return null


static func register(g) -> void:
	var lunch: Dictionary = data(g).get("lunch", {})
	g.quest_items[str(lunch.get("item", "com_hop_cua_ba"))] = "Cơm hộp bà Thoa chuẩn bị"
	for a in [
		{"id":"nho_ba_com_hop", "group":"life", "location":"home", "name":"Nhờ bà nấu cơm hộp mang đi làm", "hours":float(lunch.get("hours",0.25)), "perDay":1, "effects":{}, "note":"Một hộp miễn phí mỗi ngày, ăn trong ngày ở khu khác"},
		{"id":"an_com_hop", "group":"life", "location":"any_zone", "portable":true, "name":"Ăn cơm hộp bà chuẩn bị", "hours":float(lunch.get("hours",0.25)), "perDay":1, "effects":{"need.fed":float(lunch.get("fed",55))}, "note":"Không tốn tiền · dùng một hộp · chỉ ở khu khác"}
	]:
		if g.get_action(str(a.id)).is_empty(): g.cfg.actions.append(a)

static func _migrate_lunch(g) -> void:
	if not g.is_started(): return
	if not g.s.has("relationships"):
		g.s.relationships = {"version":1, "npcs":{}, "mealDays":[], "lunchDay":-1, "preparedDay":-1, "usedDay":-1}
	var rel: Dictionary = g.s.relationships
	for k in {"npcs":{}, "mealDays":[], "lunchDay":-1, "preparedDay":-1, "usedDay":-1}:
		if not rel.has(k): rel[k] = {"npcs":{}, "mealDays":[], "lunchDay":-1, "preparedDay":-1, "usedDay":-1}[k]
	for id in data(g).get("npcs", {}):
		if not rel.npcs.has(id): rel.npcs[id] = {"trust":float(data(g).npcs[id].get("trust",50))}
		rel.npcs[id].affection = clampf(float(g.s.rep.get(id,50)),0,100)
		rel.npcs[id].trust = clampf(float(rel.npcs[id].get("trust",50)),0,100)
	if int(rel.lunchDay) >= 0 and int(rel.lunchDay) != g.day():
		rel.lunchDay = -1
		g.s.qitems.erase(str(data(g).get("lunch",{}).get("item","com_hop_cua_ba")))
	var was: bool = g.s.flags.get("ba_com_hop",false)
	if unlocked(g):
		g.s.flags.ba_com_hop = true
		if not was: g.add_log("Bà Thoa: Sáng ghé bà, bà gói cơm mang đi. Đừng vì làm mà bỏ bữa.","event")

static func affection(g, npc: String) -> float:
	return float(g.s.rep.get(npc,50))

static func trust(g, npc: String) -> float:
	return float(g.s.get("relationships",{}).get("npcs",{}).get(npc,{}).get("trust",0))

static func unlocked(g) -> bool:
	var lunch: Dictionary = data(g).get("lunch",{})
	return affection(g,"BA_TU") >= float(lunch.get("affection",75)) and trust(g,"BA_TU") >= float(lunch.get("trust",70)) and g.s.get("relationships",{}).get("mealDays",[]).size() >= int(lunch.get("meals",7))

static func hidden(g, a: Dictionary) -> bool:
	match str(a.get("id","")):
		"nho_ba_com_hop": return not unlocked(g)
		"an_com_hop": return int(g.s.get("relationships",{}).get("lunchDay",-1)) != g.day()
	return false

static func block(g, a: Dictionary) -> String:
	var id := str(a.get("id",""))
	if id not in ["nho_ba_com_hop","an_com_hop"]: return ""
	if not g.s.has("relationships"): return "Chưa có cơm hộp"
	var rel: Dictionary = g.s.relationships
	if id == "nho_ba_com_hop":
		if not unlocked(g): return "Cùng bà ăn cơm nhiều ngày để thân thiết hơn"
		if str(g.s.get("zone","phuc_tan")) != "phuc_tan": return "Về hẻm trọ gặp bà trước"
		if int(rel.preparedDay) == g.day(): return "Bà đã chuẩn bị một hộp hôm nay rồi"
	else:
		if int(rel.lunchDay) != g.day() or g.item_count(str(data(g).lunch.item)) <= 0: return "Không có hộp cơm dùng được hôm nay"
		if str(g.s.get("zone","phuc_tan")) == "phuc_tan": return "Để dành cơm hộp khi đi làm ở khu khác"
		if int(rel.usedDay) == g.day(): return "Hôm nay đã ăn hộp cơm rồi"
	return ""

static func on_action(g, a: Dictionary) -> void:
	migrate(g)
	var rel: Dictionary = g.s.relationships
	var id := str(a.get("id",""))
	if id == str(data(g).get("meal",{}).get("action","com_voi_ba")) and not rel.mealDays.has(g.day()):
		rel.mealDays.append(g.day())
		rel.npcs.BA_TU.trust = minf(100.0,trust(g,"BA_TU")+float(data(g).get("meal",{}).get("trustGain",3)))
	# Existing relationship effects also build trust for Linh/Duyen, bounded by
	# one granted interaction per NPC per day to prevent repeated-menu farming.
	for npc in ["LINH","DUYEN"]:
		if float(a.get("effects",{}).get("rep."+npc,0)) > 0 and int(rel.npcs[npc].get("trustDay",-1)) != g.day():
			rel.npcs[npc].trust = minf(100.0,trust(g,npc)+2.0)
			rel.npcs[npc].trustDay = g.day()
	if id == "nho_ba_com_hop":
		rel.preparedDay = g.day(); rel.lunchDay = g.day()
		g.s.qitems[str(data(g).lunch.item)] = 1
	elif id == "an_com_hop":
		rel.usedDay = g.day(); rel.lunchDay = -1
		g.s.qitems.erase(str(data(g).lunch.item))
	migrate(g)
