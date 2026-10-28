extends RefCounted
## Một nguồn mục tiêu cho HUD, dấu trên phố và bản đồ. Chỉ đọc tiến độ đang có;
## không lưu thêm bản sao trạng thái nhiệm vụ.
static func active(g) -> Dictionary:
	var all := targets(g)
	return {} if all.is_empty() else all[0]


static func targets(g) -> Array:
	if not g.is_started() or g.is_over() or not g.s.get("queue", []).is_empty():
		return []
	var out := []
	var repair := _repair(g)
	for id in g.quests_active():
		var step: Dictionary = g.quest_step(id)
		var target: Dictionary = g.quest_target(id)
		if target.is_empty(): continue
		var state: Dictionary = g.s.quests[id]
		var deadline := minf(float(state.get("deadline", INF)), float(state.get("step_deadline", INF)))
		if deadline < g.now_abs(): continue
		var item := _entry("quest:" + str(id), str(g.quest_def(id).title), g.quest_progress_text(id), str(target.get("loc", "")), 100)
		item["quest_id"] = str(id)
		item.hint = g.quest_deadline_text(id)
		if target.has("area"): item["area"] = target.area
		# The story fan and the daily repair share their existing order state.
		if str(step.get("kind", "")) == "repair" and not repair.is_empty():
			item.merge(repair, true)
			item.id = "quest:" + str(id)
			item.title = str(g.quest_def(id).title)
			item.priority = 100
			item.quest_id = str(id)
			item.hint = g.quest_deadline_text(id) + (" · " + str(repair.hint) if not str(repair.hint).is_empty() else "")
		elif str(step.get("kind", "")) == "visit":
			var lock: String = g.quest_step_lock(id)
			if lock != "": _blocked(item, lock)
			elif g.quest_step_wait(id) > 0.0:
				item.hint += " · tới nơi chờ đến " + g.hh(float(step.window[0]))
		elif str(step.get("kind", "")) == "action":
			var action: Dictionary = g.get_action(str(step.action))
			if not action.is_empty(): _action_availability(g, item, action)
		if deadline - g.now_abs() <= 2.0: item.priority += 80
		out.append(item)
	# A quest-backed order already appears above; never give it a second target.
	if not repair.is_empty() and str(g.s.street.job.get("quest_id", "")) == "":
		out.append(repair)
	for id in g.scenes_today():
		var event: Dictionary = g.scene_info(id)
		var loc := str(event.get("loc", ""))
		if loc == "": continue
		# Missed scenes cannot be visited today; the morning recap owns them.
		if event.has("window") and g.clock() > float(event.window[1]): continue
		var item := _entry("scene:" + str(id), g.fill(str(event.title)), "Gặp " + str(event.get("who", "người hẹn")), loc, 80)
		var lock: String = g.scene_lock(id)
		if lock != "": _blocked(item, lock)
		if event.has("window"):
			item.hint = "%s–%s" % [g.hh(float(event.window[0])), g.hh(float(event.window[1]))]
			if float(event.window[1]) - g.clock() <= 2.0: item.priority += 90
			if g.scene_wait(id) > 0.0: item.hint += " · tới nơi có thể chờ"
		out.append(item)
	if g.has_method("neighborhood_target"):
		var follow: Dictionary = g.neighborhood_target()
		var superseded: bool = str(follow.get("street_action", "")) == "accept" and not g.s.get("street", {}).get("job", {}).is_empty()
		if not follow.is_empty() and not superseded:
			var item := _entry(str(follow.get("id", "neighborhood")), str(follow.title), str(follow.step), str(follow.get("location", "")), 30 if follow.get("optional", false) else 90)
			item.merge(follow, true)
			if not str(item.get("reason", "")).is_empty(): _blocked(item, str(item.reason))
			if follow.has("action"):
				var action: Dictionary = g.get_action(str(follow.action))
				if not action.is_empty(): _action_availability(g, item, action)
			elif follow.has("street_action"):
				var option := _street_option(g, str(item.location), str(follow.street_action))
				if option.is_empty():
					_blocked(item, "Chưa có việc này lúc này")
				elif str(option.reason) != "":
					_blocked(item, str(option.reason))
					if str(item.location) == "tiem_sau" and g.clock() < 8.0:
						item.hint += " · chờ tiệm mở lúc 08:00"
			out.append(item)
	# An actionable next step beats a closed shop, while the blocked commitment
	# stays in the expanded list with its reason.
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a.navigable) != bool(b.navigable): return bool(a.navigable)
		return int(a.priority) > int(b.priority))
	return out


static func _entry(id: String, title: String, step: String, location: String, priority: int) -> Dictionary:
	return {"id": id, "title": title, "step": step, "hint": "", "location": location, "priority": priority, "navigable": true, "reason": ""}


static func _blocked(item: Dictionary, reason: String) -> void:
	item.navigable = false
	item.reason = reason


static func _action_availability(g, item: Dictionary, action: Dictionary) -> void:
	var status: Dictionary = g.action_status(action)
	if not status.ok:
		_blocked(item, str(status.reason))
	elif float(status.start) > g.clock():
		item.hint = str(item.hint) + " · tới nơi chờ đến " + g.hh(float(status.start))


static func _repair(g) -> Dictionary:
	var st: Dictionary = g.s.get("street", {})
	var job: Dictionary = st.get("job", {})
	if job.is_empty(): return {}
	var steps := {"inspect":"Đo kiểm món khách gửi","part":"Tìm linh kiện thay thế","repair":"Lắp linh kiện trên bàn sửa 3D","test":"Chạy thử trước khi trả khách","deliver":"Trả món và nhận tiền công"}
	var stage := str(job.get("stage", ""))
	if not steps.has(stage): return {}
	var item := _entry("repair", str(job.name), steps[stage], "tiem_sau", 95)
	var due_hour := float(job.get("due_hour", 17.0))
	item.hint = "" if job.has("quest_id") else "Hẹn ngày %d · %s" % [int(job.get("due", g.day())), g.hh(due_hour)]
	var option_id: String = {"inspect":"inspect", "repair":"fix_cap" if int(job.get("kind", 0)) == 0 else "fix_fuse", "test":"test", "deliver":"deliver"}.get(stage, "")
	if stage == "part":
		if int(st.get("parts", {}).get(job.part, 0)) > 0:
			option_id = "own_part"
			item.step = "Mang linh kiện đã mua về tiệm"
		else:
			item.location = "cho_cau_nho"
			option_id = "part_" + str(int(job.get("kind", 0)))
			item.hint = "Mua ở chợ rẻ hơn 20.000đ; có thể dùng đồ tiệm"
			var market := _street_option(g, str(item.location), option_id)
			var shop := _street_option(g, "tiem_sau", "shop_part")
			if not market.is_empty() and str(market.reason) != "" and not shop.is_empty() and str(shop.reason) == "":
				item.location = "tiem_sau"
				option_id = "shop_part"
				item.step = "Dùng linh kiện ở tiệm"
				item.hint = "Quầy chợ chưa mua được · linh kiện tiệm đắt hơn 20.000đ"
			elif not market.is_empty() and str(market.reason) != "":
				var credit := _street_option(g, "tiem_sau", "credit_part")
				if not credit.is_empty() and str(credit.reason) == "":
					item.location = "tiem_sau"
					option_id = "credit_part"
					item.step = "Hỏi chú Sơn ứng linh kiện"
					item.hint = str(credit.hint)
	var option := _street_option(g, str(item.location), option_id)
	if option.is_empty():
		_blocked(item, "Đơn đang chuyển bước; xem lại việc ở tiệm")
	elif str(option.reason) != "":
		_blocked(item, str(option.reason))
	if int(job.get("due", g.day())) < g.day() or (int(job.get("due", g.day())) == g.day() and g.clock() > due_hour):
		item.hint += " · đã trễ, vẫn có thể hoàn thành với tiền công giảm"
	return item


static func _street_option(g, loc: String, id: String) -> Dictionary:
	for option in g.Street.options(g, loc):
		if str(option.id) == id: return option
	return {}


static func notice(g, title: String, text: String) -> void:
	g.s.quest_notice={"id":str(g.day())+":"+str(g.s.log.size()),"title":title,"text":text}
