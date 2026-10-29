extends RefCounted
## s.rep is the canonical affection score; relationships adds trust, distinct
## meal days and a dated lunch, without creating a competing story reputation.

static func data(g) -> Dictionary:
	return g.cfg.get("relationships", {})

static func register(g) -> void:
	var lunch: Dictionary = data(g).get("lunch", {})
	g.quest_items[str(lunch.get("item", "com_hop_cua_ba"))] = "Cơm hộp bà Thoa chuẩn bị"
	for a in [
		{"id":"nho_ba_com_hop", "group":"life", "location":"home", "name":"Nhờ bà nấu cơm hộp mang đi làm", "hours":float(lunch.get("hours",0.25)), "perDay":1, "effects":{}, "note":"Một hộp miễn phí mỗi ngày, ăn trong ngày ở khu khác"},
		{"id":"an_com_hop", "group":"life", "location":"any_zone", "portable":true, "name":"Ăn cơm hộp bà chuẩn bị", "hours":float(lunch.get("hours",0.25)), "perDay":1, "effects":{"need.fed":float(lunch.get("fed",55))}, "note":"Không tốn tiền · dùng một hộp · chỉ ở khu khác"}
	]:
		if g.get_action(str(a.id)).is_empty(): g.cfg.actions.append(a)

static func migrate(g) -> void:
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
