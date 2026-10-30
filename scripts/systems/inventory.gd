extends RefCounted
## Consumables share the existing qitems stack store; clothing inventory and scrap
## retain their existing schemas. No duplicated counts, including grandma's lunch.

static func data(g) -> Dictionary:
	return g.cfg.get("consumables", {})

static func definitions(g) -> Dictionary:
	return data(g).get("items", {})

static func definition(g, id: String) -> Dictionary:
	return definitions(g).get(id, {})

static func register(g) -> void:
	for id in definitions(g): g.quest_items[id] = str(definitions(g)[id].name)
	if g.get_action("mua_tap_hoa").is_empty():
		g.cfg.actions.append({"id":"mua_tap_hoa", "name":"Mua hàng tạp hóa", "group":"life", "location":"xom_bo_me", "hours":0.0, "perDay":999999, "uiOnly":true, "effects":{}, "note":"Mua bánh mì, nước và đồ dùng mang theo. Trừ tiền và 5 phút khi mua."})

static func migrate(g) -> void:
	if not g.is_started(): return
	if not g.s.has("qitems"): g.s.qitems = {}
	# Older quest counts stay intact. Only normalize known consumable stacks.
	for id in definitions(g):
		if not g.s.qitems.has(id): continue
		var n := maxi(0, int(g.s.qitems[id]))
		if n == 0: g.s.qitems.erase(id)
		else: g.s.qitems[id] = n

static func owned(g) -> Array:
	var out: Array = []
	for id in definitions(g):
		var count: int = g.item_count(id)
		if count > 0:
			var row: Dictionary = definition(g,id).duplicate(true)
			row["count"] = count
			out.append(row)
	return out

static func common_block(g) -> String:
	if not g.is_started() or g.is_over(): return "Chưa trong ngày chơi"
	if not g.s.queue.is_empty(): return "Nói chuyện xong trước đã"
	if not g._minigame_sessions.is_empty(): return "Hoàn tất hoặc đóng mini-game trước"
	return ""

static func use_reason(g, id: String) -> String:
	var reason := common_block(g)
	if reason != "": return reason
	var item := definition(g,id)
	if item.is_empty(): return "Vật phẩm này không dùng được"
	if g.item_count(id) <= 0: return "Đã hết vật phẩm"
	if item.has("action"):
		return str(g.action_status(g.get_action(str(item.action))).get("reason", ""))
	if g.hours_left() + 0.00001 < float(item.minutes)/60.0: return "Không đủ thời gian sử dụng hôm nay"
	return ""

static func use(g, id: String) -> bool:
	if use_reason(g,id) != "": return false
	var item := definition(g,id)
	if item.has("action"):
		var before: int = g.item_count(id)
		g.do_action(str(item.action))
		return g.item_count(id) < before
	# Time/decay first, restoration second; commit emits one coherent save/UI update.
	g._add_item(id,-1)
	g.elapse(float(item.minutes)/60.0)
	g._tick_needs()
	for key in item.effects:
		if key == "stamina": g.add_fatigue(-float(item.effects[key]))
		else: g.need_adj(key,float(item.effects[key]))
	g.add_log("Dùng %s · %d phút" % [item.name,int(item.minutes)],"event")
	g._commit()
	return true

static func shop_reason(g) -> String:
	var reason := common_block(g)
	if reason != "": return reason
	if g.MapManager.current(g) != str(data(g).get("shopZone","phuc_tan")): return "Quầy tạp hóa ở Hẻm trọ Phúc Tân"
	return ""

static func buy_reason(g, id: String, count := 1) -> String:
	var reason := shop_reason(g)
	if reason != "": return reason
	var item := definition(g,id)
	if item.is_empty() or not bool(item.get("purchasable",true)): return "Không bán vật phẩm này"
	if count <= 0 or count > int(data(g).get("maxStack",99)): return "Số lượng không hợp lệ"
	if g.item_count(id) + count > int(data(g).get("maxStack",99)): return "Ngăn này đã đầy (tối đa 99 món)"
	if int(g.s.cash) < int(item.price)*count: return "Không đủ tiền mặt"
	if g.hours_left()+0.00001 < float(data(g).get("purchaseMinutes",5))/60.0: return "Không đủ thời gian mua hôm nay"
	return ""

static func buy(g, id: String, count := 1) -> bool:
	if buy_reason(g,id,count) != "": return false
	var item := definition(g,id)
	g.spend(int(item.price)*count,"Mua %d × %s" % [count,item.name])
	g._add_item(id,count)
	g.elapse(float(data(g).get("purchaseMinutes",5))/60.0)
	g._commit()
	return true

static func effects_text(item: Dictionary) -> String:
	var names := {"stamina":"Thể lực","fed":"Độ no","mood":"Tâm trạng","clean":"Vệ sinh"}
	var parts: Array[String] = []
	for key in item.get("effects",{}):
		parts.append("%s %+d" % [names.get(key,key),int(item.effects[key])])
	parts.append("%d phút" % int(item.get("minutes",5)))
	return " · ".join(parts)
