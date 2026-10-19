extends RefCounted
## Toàn bộ luật chơi của Lên Phố: trạng thái, hành động, sự kiện, cuối ngày và kết thúc.
## Không phụ thuộc giao diện, nên chạy được cả trong bản mô phỏng headless (tests/sim.gd).
## Số liệu và nội dung nằm trong data/*.json; file này chỉ đọc và xử lý.

signal changed
signal notes_changed

const SKILLS := {
	"tayNghe": "Tay nghề", "tinHoc": "Tin học", "ngoaiNgu": "Ngoại ngữ",
	"giaoTiep": "Giao tiếp", "phapLy": "Pháp lý",
}
const REPS := {"coSau": "Cô Sáu", "chuBay": "Chú Bảy", "vy": "Vy", "tuan": "Tuấn", "ongTu": "Ông Tư"}
const WEEKDAYS := ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
const GROUPS := {"work": "Làm việc", "study": "Học", "life": "Sinh hoạt"}
const DAY_START := 6.0
const DAY_HOURS := 16.0
const LAST_DAY := 30

var cfg: Dictionary = {}
var events: Array = []
var story: Dictionary = {}
## Hội thoại với nhân vật, theo khóa trong REPS (data/talks.json).
var talks: Dictionary = {}
## Việc nhờ nhiều bước (data/quests.json): danh sách quest và tên các món đồ của quest.
var quests: Array = []
var quest_items: Dictionary = {}
## Trạng thái ván chơi. Rỗng nghĩa là chưa bắt đầu (đang ở màn mở đầu).
var s: Dictionary = {}
## Sổ tay của Minh: giữ lại qua các lần thua.
var notes: Array = []
var _event_data: Dictionary = {}


# ---------------------------------------------------------------- dữ liệu

func load_data(dir := "res://data") -> void:
	cfg = _read_json(dir + "/config.json")
	events = _read_json(dir + "/events.json")
	story = _read_json(dir + "/story.json")
	talks = _read_json(dir + "/talks.json")
	talks.erase("_ghi_chu")
	if FileAccess.file_exists(dir + "/quests.json"):
		var q: Dictionary = _read_json(dir + "/quests.json")
		quests = q.get("quests", [])
		quest_items = q.get("items", {})


static func _read_json(path: String) -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("Không đọc được file dữ liệu: " + path)
	return data


# ---------------------------------------------------------------- bắt đầu ván

func new_game(item: String) -> void:
	_event_data = {}
	s = {
		"day": 1, "used": 0.0, "money": int(cfg.startMoney),
		"health": 100.0, "mood": 80.0, "health_max": 100.0, "mood_max": 100.0,
		"xp": {"tayNghe": 0.0, "tinHoc": 0.0, "ngoaiNgu": 0.0, "giaoTiep": 0.0, "phapLy": 0.0},
		"rep": {"coSau": 10, "chuBay": 0, "vy": 0, "tuan": 40, "ongTu": 0},
		"flags": {}, "room": "", "food": "com_bui", "focus": "tinHoc", "item": item,
		"debt": int(cfg.milestones.day30), "interest_paid": 0, "evidence": 0, "smuggle": 0, "held": 0,
		"counts": {}, "today": {"list": []}, "yesterday": {"list": []}, "last_random": {},
		"queue": [], "log": [], "history": [], "choices": [], "skip_reason": "", "over": {},
		"stats": {"earned": 0, "spent": 0, "faints": 0}, "talks_done": [],
		"quests": {}, "qitems": {},
	}
	# Nhu cầu cơ thể (đói, vệ sinh, quần áo) kiểu Nobody: ăn uống tự mua ở quán thay vì gói ăn theo ngày.
	if cfg.has("needs"):
		s["needs"] = cfg.needs.start.duplicate()
		s["needs_t"] = DAY_START
		s["food"] = "tu_lo"
		s["inv"] = {}
	apply_effects(story.items[item].get("effects", {}))
	_morning()
	_commit()


func reset() -> void:
	s = {}
	_event_data = {}
	changed.emit()


# ---------------------------------------------------------------- truy vấn

func is_started() -> bool:
	return not s.is_empty()


func is_over() -> bool:
	return is_started() and not s.over.is_empty()


func day() -> int:
	return int(s.day)


func level(k: String) -> int:
	var per := float(cfg.xpPerLevel)
	return mini(int(cfg.maxLevel), int(floor(float(s.xp.get(k, 0.0)) / per + 0.000001)))


func max_skill() -> int:
	var best := 0
	for k in SKILLS:
		best = maxi(best, level(k))
	return best


func clock() -> float:
	return DAY_START + float(s.used)


func day_end() -> float:
	return 22.0 - float(cfg.food[s.food].get("hours", 0))


func hours_left() -> float:
	return maxf(0.0, day_end() - clock())


func is_weekend(d: int) -> bool:
	return d % 7 == 6 or d % 7 == 0


func weekday_name() -> String:
	return WEEKDAYS[day() % 7]


func next_milestone() -> Dictionary:
	if day() <= 10:
		return {"day": 10, "label": "Khoa thu lãi", "amount": int(cfg.milestones.day10)}
	if day() <= 20:
		return {"day": 20, "label": "Học phí của Lan", "amount": int(cfg.milestones.day20)}
	return {"day": 30, "label": "Trả nợ Hưng Sẹo", "amount": int(s.debt)}


# ---------------------------------------------------------------- thay đổi chỉ số

func add_log(text: String, kind := "info") -> void:
	s.log.append({"day": day(), "t": text, "k": kind})


func earn(n: int, why: String) -> void:
	s["money"] = int(s.money) + n
	s.stats["earned"] = int(s.stats.earned) + n
	add_log("+%s · %s" % [fmt_money(n), why], "plus")


func spend(n: int, why: String) -> int:
	var taken := mini(n, int(s.money))
	s["money"] = int(s.money) - taken
	s.stats["spent"] = int(s.stats.spent) + taken
	add_log("−%s · %s" % [fmt_money(taken), why], "minus")
	return taken


func adj(stat: String, d: float) -> void:
	s[stat] = clampf(float(s[stat]) + d, 0.0, float(s[stat + "_max"]))


func add_rep(k: String, d: float) -> void:
	s.rep[k] = clampi(int(s.rep.get(k, 0)) + int(d), 0, 100)


func add_xp(k: String, d: float) -> void:
	var cap := float(cfg.maxLevel) * float(cfg.xpPerLevel)
	s.xp[k] = minf(cap, float(s.xp.get(k, 0.0)) + d)


func clamp_all() -> void:
	s["health"] = clampf(float(s.health), 0.0, float(s.health_max))
	s["mood"] = clampf(float(s.mood), 0.0, float(s.mood_max))


## Áp một bộ hiệu ứng viết trong JSON, ví dụ {"money": -300000, "rep.tuan": 10, "flag.tamTru": true}.
func apply_effects(eff: Dictionary) -> void:
	var label: String = eff.get("money_label", "")
	for key in eff:
		var v = eff[key]
		match key:
			"money_label":
				pass
			"money":
				if int(v) >= 0:
					earn(int(v), label)
				else:
					spend(-int(v), label)
			"health", "mood":
				adj(key, float(v))
			"mood_max":
				s["mood_max"] = float(s.mood_max) + float(v)
			"hours":
				s["used"] = float(s.used) + float(v)
			"skip_day":
				if v:
					s["used"] = DAY_HOURS
			"debt":
				s["debt"] = int(s.debt) + int(v)
			"evidence":
				s["evidence"] = int(s.evidence) + int(v)
			"room":
				_set_room(str(v))
			"special":
				_special(str(v))
			"log":
				add_log(fill(str(v)), "event")
			_:
				if key.begins_with("xp."):
					add_xp(key.substr(3), float(v))
				elif key.begins_with("rep."):
					add_rep(key.substr(4), float(v))
				elif key.begins_with("item."):
					_add_item(key.substr(5), int(v))
				elif key.begins_with("need."):
					need_adj(key.substr(5), float(v))
				elif key.begins_with("flag."):
					if v:
						s.flags[key.substr(5)] = true
					else:
						s.flags.erase(key.substr(5))
				else:
					push_warning("Hiệu ứng không rõ: " + str(key))
	clamp_all()


func _set_room(k: String) -> void:
	s["room"] = k
	var room: Dictionary = cfg.rooms[k]
	spend(int(room.rent), "Tiền trọ: " + str(room.name))


func _special(name: String) -> void:
	match name:
		"lose_held_wages":
			if int(s.held) > 0:
				add_log("Mất %s tiền công bị quỵt" % fmt_money(int(s.held)), "minus")
				s.flags["wageLost"] = true
			s["held"] = 0
		"smuggle_trip":
			s["used"] = float(s.used) + float(cfg.smuggle.hours)
			s["smuggle"] = int(s.smuggle) + 1
			earn(int(cfg.smuggle.pay), "Chạy hàng cho Tuấn")
		"raise_debt":
			s["debt"] = int(s.debt) + int(cfg.milestones.raiseDay21)
		"pickpocket":
			spend(int(_event_data.get("amt", 0)), "Bị móc túi")
		"rain":
			s.today["rain"] = true
		"count_faint":
			s.stats["faints"] = int(s.stats.faints) + 1
		_:
			push_warning("Hiệu ứng đặc biệt không rõ: " + name)


# ---------------------------------------------------------------- điều kiện

## Trả về "" nếu thỏa điều kiện, ngược lại trả về lý do để hiện cho người chơi.
func check(req: Dictionary, texts: Dictionary = {}) -> String:
	for key in req:
		var v = req[key]
		var fail := ""
		if key.begins_with("skill."):
			var k: String = key.substr(6)
			if level(k) < int(v):
				fail = "Cần %s %d" % [SKILLS.get(k, k), int(v)]
		elif key.begins_with("rep."):
			var k: String = key.substr(4)
			var have := int(s.rep.get(k, 0))
			if have < int(v):
				fail = "Cần thân với %s (%d/%d)" % [REPS.get(k, k), have, int(v)]
		elif key.begins_with("flag."):
			if bool(s.flags.get(key.substr(5), false)) != bool(v):
				fail = "Chưa mở"
		elif key == "from_day":
			if day() < int(v):
				fail = "Mở từ ngày %d" % int(v)
		elif key == "room":
			if s.room != v:
				fail = "Cần ở phòng riêng của cô Sáu"
		elif key == "money_min":
			if int(s.money) < int(v):
				fail = "Không đủ tiền"
		elif key == "afford_room":
			if int(s.money) < int(cfg.rooms[v].rent):
				fail = "Không đủ tiền"
		elif key == "hours_left":
			if float(s.used) + float(v) > DAY_HOURS:
				fail = "Không đủ giờ"
		elif key == "health_below":
			if float(s.health) >= float(v):
				fail = "-"
		elif key == "held_min":
			if int(s.held) < int(v):
				fail = "-"
		elif key == "smuggle_min":
			if int(s.smuggle) < int(v):
				fail = "-"
		elif key == "smuggle_below_trips":
			if int(s.smuggle) >= int(cfg.smuggle.tripsForBadEnding):
				fail = "-"
		elif key == "did_yesterday_any":
			var hit := false
			for x in v:
				if s.yesterday.get("list", []).has(x):
					hit = true
			if not hit:
				fail = "-"
		else:
			push_warning("Điều kiện không rõ: " + str(key))
		if fail != "":
			return texts.get(key, fail)
	return ""


# ---------------------------------------------------------------- hành động trong ngày

func get_action(id: String) -> Dictionary:
	for a in cfg.actions:
		if a.id == id:
			return a
	return {}


func count(id: String) -> int:
	return int(s.counts.get(id, 0))


func today_count(id: String) -> int:
	return int(s.today.get(id, 0))


func action_money(a: Dictionary) -> int:
	var need := int(a.get("cost", 0))
	if a.has("fee") and count(a.id) == 0:
		need += int(a.fee)
	return need


func is_hidden(a: Dictionary) -> bool:
	if a.has("days") and (day() < int(a.days[0]) or day() > int(a.days[1])):
		return true
	if a.has("show_if_flag") and not s.flags.get(a.show_if_flag, false):
		return true
	if a.has("max_times") and count(a.id) >= int(a.max_times) and (a.has("days") or a.has("set_flag")):
		return true
	return false


func visible_actions(group: String) -> Array:
	var out := []
	for a in cfg.actions:
		if a.group == group and not is_hidden(a):
			out.append(a)
	return out


## {"ok": bool, "reason": String, "start": giờ bắt đầu nếu làm được}
func action_status(a: Dictionary) -> Dictionary:
	if is_over() or not s.queue.is_empty():
		return {"ok": false, "reason": ""}
	var reason := check(a.get("require", {}), a.get("lock_text", {}))
	if reason != "":
		return {"ok": false, "reason": reason}
	if a.get("weekend", false) and not is_weekend(day()):
		return {"ok": false, "reason": "Chỉ có vào Thứ Bảy, Chủ Nhật"}
	if a.get("outdoor", false) and s.today.get("rain", false):
		return {"ok": false, "reason": "Mưa ngập, nghỉ hôm nay"}
	if a.get("needs_phone", false) and s.flags.get("phoneBroken", false):
		return {"ok": false, "reason": "Điện thoại đang hỏng"}
	if a.has("max_times") and count(a.id) >= int(a.max_times):
		return {"ok": false, "reason": "Đã học đủ số buổi"}
	if today_count(a.id) >= int(a.get("per_day", 1)):
		return {"ok": false, "reason": "Hôm nay đã làm rồi"}
	var need := action_money(a)
	if need > int(s.money):
		return {"ok": false, "reason": "Không đủ tiền (cần %s)" % fmt_k(need)}
	if float(s.health) <= 0.0 and a.group != "life":
		return {"ok": false, "reason": "Kiệt sức, cần nghỉ"}
	var start := clock()
	var limit := day_end()
	if a.has("window"):
		start = maxf(start, float(a.window[0]))
		limit = minf(float(a.window[1]), limit)
	if start + float(a.hours) > limit + 0.001:
		if a.has("window"):
			return {"ok": false, "reason": "Chỉ trong khung %s–%s" % [hh(a.window[0]), hh(a.window[1])]}
		return {"ok": false, "reason": "Không đủ giờ hôm nay"}
	return {"ok": true, "reason": "", "start": start}


## result: kết quả trò chơi nhỏ khi tự làm {"ratio": 0..1 phần chỉ tiêu, "bonus": tiền thưởng}.
## Không truyền thì tính đủ công như trước (làm tự động hoặc mô phỏng).
func do_action(id: String, result: Dictionary = {}) -> void:
	var a := get_action(id)
	if a.is_empty() or is_hidden(a):
		return
	var st := action_status(a)
	if not st.ok:
		return
	var start: float = st.start
	s["used"] = start - DAY_START + float(a.hours)
	if a.has("fee") and count(id) == 0:
		spend(int(a.fee), "Học phí " + str(a.name))
	if a.has("cost"):
		spend(int(a.cost), str(a.name))
	var pay := 0
	if a.has("pay"):
		pay = int(a.pay)
	if a.has("pay_range"):
		if randf() < float(a.get("fail_chance", 0.0)):
			pay = 0
		else:
			pay = round_k(randf_range(float(a.pay_range[0]), float(a.pay_range[1])))
	if a.has("tip"):
		pay += round_k(randf_range(float(a.tip[0]), float(a.tip[1])))
	if not result.is_empty():
		pay = round_k(float(pay) * float(result.get("ratio", 1.0))) + int(result.get("bonus", 0))
		if not s.has("job_last"):
			s["job_last"] = {}
		if not bool(result.get("auto", false)):
			s.job_last[id] = {"ratio": float(result.get("ratio", 1.0)), "bonus": int(result.get("bonus", 0))}
	if a.group == "work" and pay > 0 and pay_mult() < 1.0:
		pay = round_k(float(pay) * pay_mult())
		add_log("Phong độ kém, chỉ được %d%% tiền công" % int(pay_mult() * 100.0), "warn")
	for k in a.get("dirty", {}):
		need_adj(k, float(a.dirty[k]))
	var label := "%s %s" % [hh(start), a.name]
	if a.has("hold_days") and day() >= int(a.hold_days[0]) and day() <= int(a.hold_days[1]):
		s["held"] = int(s.held) + pay
		add_log("%s: chủ thầu hẹn cuối tuần trả %s" % [label, fmt_money(pay)], "warn")
	elif pay > 0:
		earn(pay, label)
	elif a.has("pay_range"):
		add_log(label + ": hôm nay không bán được gì", "warn")
	else:
		add_log(label)
	apply_effects(a.get("effects", {}))
	if a.has("focus_xp"):
		add_xp(s.focus, float(a.focus_xp))
	if id == "goi_ve" and s.flags.get("aoKhoac", false):
		adj("mood", 5.0)
	if a.has("set_flag"):
		s.flags[a.set_flag] = true
	if a.has("clear_flag"):
		s.flags.erase(a.clear_flag)
	s.counts[id] = count(id) + 1
	s.today[id] = today_count(id) + 1
	s.today.list.append(id)
	_quest_on_action(id, result)
	_commit()


## Thời gian trôi khi đi bộ trên phố. Không vượt quá giờ đi ngủ.
func walk(hours: float) -> void:
	if not is_started() or is_over() or not s.queue.is_empty() or hours <= 0.0:
		return
	s["used"] = minf(float(s.used) + hours, day_end() - DAY_START)
	_commit()


## Đã hết giờ trong ngày, phải đi ngủ.
func is_out_of_time() -> bool:
	return is_started() and not is_over() and hours_left() <= 0.001


## Hết giờ mà chưa về phòng trọ: ngủ gục ngoài đường, bị phạt rồi sang ngày mới.
func sleep_outside() -> void:
	if not is_started() or is_over() or not s.queue.is_empty():
		return
	add_log("Không kịp về phòng trọ, ngủ gục ngoài đường.", "warn")
	finish_day(false)
	# Trừ sau khi ngủ, nếu không phần hồi sức khi ngủ sẽ xóa mất hình phạt.
	if not is_over():
		var pen: Dictionary = cfg.get("sleepOutside", {})
		adj("health", float(pen.get("health", 0)))
		adj("mood", float(pen.get("mood", 0)))
		s.queue.push_front({"id": "ngu_gat", "data": {}})
		_commit()


func set_food(k: String) -> void:
	if is_started() and float(s.used) == 0.0 and cfg.food.has(k):
		s["food"] = k
		_commit()


func set_focus(k: String) -> void:
	if is_started() and SKILLS.has(k):
		s["focus"] = k
		_commit()


# ---------------------------------------------------------------- sự kiện

func find_event(id: String) -> Dictionary:
	if id.begins_with("q"):
		var qe := _quest_event(id)
		if not qe.is_empty():
			return qe
	for e in events:
		if e.id == id:
			return e
	if id == "talk_chat":
		return {"id": id, "title": "{npc}", "text": "{line}", "choices": [{"label": "Chào rồi đi", "hint": "{npc} +{chat_rep}"}]}
	for npc in talks:
		for b in talks[npc].get("story", []):
			if b.id == id:
				var e: Dictionary = b.duplicate()
				e["who"] = REPS.get(npc, npc)
				return e
	return {}


# ---------------------------------------------------------------- giao đồ ăn

## "" nếu bật app giao hàng nhận đơn được, ngược lại là lý do.
func delivery_lock() -> String:
	if not is_started() or is_over():
		return "-"
	if s.flags.get("phoneBroken", false):
		return "Điện thoại đang hỏng"
	if hours_left() < 0.5:
		return "Sắp hết ngày"
	return ""


func delivery_active() -> Dictionary:
	return s.get("delivery", {})


## Giờ cao điểm bữa trưa, bữa tối thì đơn nổ liên tục.
func delivery_rush() -> bool:
	for r in cfg.delivery.rush:
		if clock() >= float(r[0]) and clock() < float(r[1]):
			return true
	return false


## Đơn mới: lấy ở tiệm shop, giao tới dest; meters là quãng đường cả đi lấy lẫn đi giao.
func delivery_offer(shop: String, shop_name: String, dest: String, dest_x: float, meters: float) -> Dictionary:
	var d: Dictionary = cfg.delivery
	var walk_h := meters * float(cfg.get("walkHoursPerMeter", 0.004))
	return {
		"shop": shop, "shop_name": shop_name, "item": str(d.shops[shop]), "dest": dest, "dest_x": dest_x,
		"pay": round_k(float(d.base) + meters * float(d.perMeter)),
		"deadline": clock() + walk_h * float(d.slackFactor) + float(d.cookHours) + float(d.slackHours),
		"picked": false,
	}


func delivery_accept(o: Dictionary) -> void:
	if delivery_lock() != "" or not delivery_active().is_empty():
		return
	var a := o.duplicate()
	a["given"] = clock()
	s["delivery"] = a
	add_log("Nhận đơn: %s → %s" % [a.item, a.dest])
	_commit()


## Tới quán: chờ quán làm món rồi cầm đi.
func delivery_pickup() -> void:
	var o := delivery_active()
	if o.is_empty() or o.picked:
		return
	o["picked"] = true
	s["used"] = float(s.used) + float(cfg.delivery.cookHours)
	_commit()


## Tới nhà khách: trả tiền theo giờ giao, sớm thì có tip, trễ thì bị trừ.
## Trả về {"pay", "tip", "late"} để hiện cho người chơi.
func delivery_drop() -> Dictionary:
	var o := delivery_active()
	if o.is_empty() or not o.picked:
		return {}
	var d: Dictionary = cfg.delivery
	var late := clock() > float(o.deadline)
	var pay := round_k(float(o.pay) * pay_mult())
	var tip := 0
	if late:
		pay = round_k(float(pay) * float(d.latePay))
		adj("mood", float(d.lateMood))
	elif (float(o.deadline) - clock()) / maxf(0.01, float(o.deadline) - float(o.given)) >= float(d.tipIfLeft):
		tip = round_k(randf_range(float(d.tip[0]), float(d.tip[1])))
	adj("health", float(d.health))
	adj("mood", float(d.mood))
	earn(pay + tip, "Giao %s tới %s%s" % [o.item, o.dest, " (trễ)" if late else (" · tip %s" % fmt_k(tip) if tip > 0 else "")])
	s.counts["giao_hang"] = count("giao_hang") + 1
	s.today["giao_hang"] = today_count("giao_hang") + 1
	s.erase("delivery")
	clamp_all()
	_commit()
	return {"pay": pay, "tip": tip, "late": late}


func delivery_cancel() -> void:
	if delivery_active().is_empty():
		return
	adj("mood", float(cfg.delivery.cancelMood))
	add_log("Hủy đơn giao hàng, bị khách đánh giá 1 sao", "warn")
	s.erase("delivery")
	_commit()


# ---------------------------------------------------------------- nói chuyện

## "" nếu nói chuyện được với nhân vật, ngược lại là lý do khóa.
func talk_lock(npc: String) -> String:
	if not is_started() or is_over() or not s.queue.is_empty() or not talks.has(npc):
		return "-"
	if today_count("talk_" + npc) > 0:
		return "Hôm nay đã nói chuyện rồi"
	if hours_left() < float(cfg.get("talkHours", 0.5)):
		return "Không đủ giờ"
	return ""


## Nói chuyện: kể đoạn mạch chuyện kế tiếp nếu đã mở, không thì tán gẫu vài câu.
func talk(npc: String) -> void:
	if talk_lock(npc) != "":
		return
	s["used"] = float(s.used) + float(cfg.get("talkHours", 0.5))
	s.today["talk_" + npc] = 1
	if not s.has("talks_done"):
		s["talks_done"] = []
	var who: String = REPS.get(npc, npc)
	for b in talks[npc].get("story", []):
		if not s.talks_done.has(b.id) and check(b.get("when", {})) == "":
			s.talks_done.append(b.id)
			s.queue.append({"id": b.id, "data": {}})
			add_log("Nói chuyện với " + who)
			_commit()
			return
	var lines := []
	for c in talks[npc].get("chat", []):
		if check(c.get("when", {})) == "":
			lines.append(c.text)
	add_rep(npc, float(cfg.get("chatRep", 2)))
	s.queue.append({"id": "talk_chat", "data": {"npc": who, "line": lines.pick_random() if not lines.is_empty() else "..."}})
	add_log("Tán gẫu với " + who)
	_commit()


## Sự kiện đang chờ người chơi chọn, đã gộp biến thể phù hợp. Rỗng nếu không có.
func current_event() -> Dictionary:
	if not is_started() or s.queue.is_empty():
		return {}
	var q: Dictionary = s.queue[0]
	_event_data = q.get("data", {})
	var base := find_event(q.id)
	if base.is_empty():
		push_error("Không tìm thấy sự kiện: " + str(q.id))
		return {}
	var e := base.duplicate()
	for variant in base.get("variants", []):
		if check(variant.get("when", {})) == "":
			for k in variant:
				if k != "when":
					e[k] = variant[k]
			break
	if not e.has("choices"):
		e["choices"] = [{"label": "Tiếp tục"}]
	if not e.has("eyebrow"):
		e["eyebrow"] = "Ngày %d" % day()
	return e


func choice_lock(c: Dictionary) -> String:
	return check(c.get("require", {}))


func resolve_choice(i: int) -> void:
	var e := current_event()
	if e.is_empty():
		return
	var choices: Array = e.choices
	if i < 0 or i >= choices.size():
		return
	var c: Dictionary = choices[i]
	if choice_lock(c) != "":
		return
	s.queue.pop_front()
	s.choices.append({"day": day(), "event": e.id, "choice": fill(c.label)})
	apply_effects(c.get("effects", {}))
	for b in c.get("bonus", []):
		if check(b.get("when", {})) == "":
			apply_effects(b.get("effects", {}))
	_quest_choice(str(e.id), c)
	_event_data = {}
	_commit()


## Chọn lựa chọn đầu tiên chưa bị khóa của sự kiện đang chờ (dùng cho chế độ demo và mô phỏng).
func resolve_first_available() -> void:
	var e := current_event()
	if e.is_empty():
		return
	for i in e.choices.size():
		if choice_lock(e.choices[i]) == "":
			resolve_choice(i)
			return


## Thay {chỗ_trống} trong văn bản bằng số liệu hiện tại.
func fill(text: String) -> String:
	var vals := {
		"day": str(day()),
		"held": fmt_money(int(s.get("held", 0))),
		"amt": fmt_money(int(_event_data.get("amt", 0))),
		"amount": fmt_money(int(_event_data.get("amount", 0))),
		"smuggle": str(int(s.get("smuggle", 0))),
		"trips": str(int(cfg.smuggle.tripsForBadEnding)),
		"smuggle_pay": fmt_k(int(cfg.smuggle.pay)),
		"smuggle_hours": str(int(cfg.smuggle.hours)),
		"debt_after_raise": fmt_k(int(s.get("debt", 0)) + int(cfg.milestones.raiseDay21)),
		"room_ghep": str(cfg.rooms.ghep.name),
		"room_rieng": str(cfg.rooms.rieng.name),
		"rent_ghep": fmt_money(int(cfg.rooms.ghep.rent)),
		"rent_rieng": fmt_money(int(cfg.rooms.rieng.rent)),
		"sleep_out_health": str(int(cfg.get("sleepOutside", {}).get("health", 0))),
		"sleep_out_mood": str(int(cfg.get("sleepOutside", {}).get("mood", 0))),
		"fail_health": str(int(cfg.milestones.failDay10Health)),
		"fail_debt": fmt_money(int(cfg.milestones.failDay10DebtAdd)),
		"npc": str(_event_data.get("npc", "")),
		"line": str(_event_data.get("line", "")),
		"chat_rep": str(int(cfg.get("chatRep", 2))),
	}
	for k in vals:
		text = text.replace("{" + k + "}", vals[k])
	return text


func _events_for_day(d: int) -> Array:
	var out := []
	for e in events:
		if e.get("random", false) or e.get("system", false):
			continue
		var on: bool = e.has("day") and int(e.day) == d
		for x in e.get("days", []):
			if int(x) == d:
				on = true
		if on and check(e.get("when", {})) == "":
			out.append({"id": e.id, "data": {}})
	return out


func _roll_random() -> Variant:
	var cands := []
	for e in events:
		if not e.get("random", false) or check(e.get("when", {})) != "":
			continue
		if day() - int(s.last_random.get(e.id, -99)) <= 3:
			continue
		cands.append(e)
	cands.shuffle()
	for e in cands:
		var p := float(cfg.random.get(e.id, 0.0))
		if s.room == "ghep" and cfg.random.has(e.id + "_phong_ghep"):
			p = float(cfg.random[e.id + "_phong_ghep"])
		if randf() < p:
			s.last_random[e.id] = day()
			var data := {}
			if e.id == "moc_tui":
				data["amt"] = round_k(float(s.money) * randf_range(0.1, 0.3))
			return {"id": e.id, "data": data}
	return null


func _morning() -> void:
	if s.skip_reason != "":
		s.queue.append({"id": "skip_" + str(s.skip_reason), "data": {}})
		s["skip_reason"] = ""
	if day() % 7 == 0:
		adj("mood", float(cfg.letterMood))
		add_log(story.letter, "event")
	var fixed := _events_for_day(day())
	s.queue.append_array(fixed)
	if fixed.is_empty() and day() >= 2 and s.queue.is_empty():
		var r = _roll_random()
		if r != null:
			s.queue.append(r)


# ---------------------------------------------------------------- cuối ngày

func night_preview() -> Dictionary:
	var food: Dictionary = cfg.food[s.food]
	var decay := float(cfg.moodDecay)
	if s.room == "ghep":
		decay += float(cfg.sharedRoomMoodDecay)
	return {
		"food_name": food.name, "food_cost": int(food.cost),
		"free_hours": hours_left(), "free_health": hours_left() * float(cfg.freeHourHealth),
		"sleep_health": float(cfg.sleepHealth), "mood_decay": decay,
		"milestone_tonight": day() in [10, 20, 30],
	}


func finish_day(night_shift: bool) -> void:
	if not is_started() or is_over() or not s.queue.is_empty():
		return
	if not delivery_active().is_empty():
		add_log("Hết ngày, đơn giao hàng đang chạy bị hủy", "warn")
		s.erase("delivery")
	_tick_needs()
	if has_needs():
		for k in cfg.needs.overnight:
			need_adj(k, float(cfg.needs.overnight[k]))
		s["needs_t"] = DAY_START
	var food: Dictionary = cfg.food[s.food]
	spend(int(food.cost), "Ăn uống: " + str(food.name))
	adj("health", float(food.get("health", 0)))
	adj("mood", float(food.get("mood", 0)))
	var free_hours := hours_left()
	if night_shift:
		var n: Dictionary = cfg.nightShift
		earn(int(n.pay), str(n.name))
		adj("health", float(n.health))
		adj("mood", float(n.mood))
		s.today.list.append("boc_vac")
	adj("health", float(cfg.sleepHealth) + free_hours * float(cfg.freeHourHealth))
	var decay := float(cfg.moodDecay)
	if s.room == "ghep":
		decay += float(cfg.sharedRoomMoodDecay)
	adj("mood", -decay)

	if day() == 10:
		var amount := int(cfg.milestones.day10)
		if int(s.money) >= amount:
			spend(amount, "Mốc 1: trả lãi cho Khoa")
			s["interest_paid"] = int(s.interest_paid) + amount
			s.queue.append({"id": "moc_10_ok", "data": {"amount": amount}})
		else:
			adj("health", float(cfg.milestones.failDay10Health))
			s["debt"] = int(s.debt) + int(cfg.milestones.failDay10DebtAdd)
			add_log("Không đủ tiền lãi. Bị đánh, nợ tăng.", "warn")
			s.queue.append({"id": "moc_10_fail", "data": {"amount": amount}})
	if day() == 20:
		var amount := int(cfg.milestones.day20)
		if int(s.money) >= amount:
			spend(amount, "Mốc 2: học phí cho Lan")
			s.flags["lanNhapHoc"] = true
			s.queue.append({"id": "moc_20_ok", "data": {"amount": amount}})
		else:
			adj("mood", float(cfg.milestones.failDay20Mood))
			s.flags["lanBaoLuu"] = true
			add_log("Không đủ học phí. Lan phải bảo lưu.", "warn")
			s.queue.append({"id": "moc_20_fail", "data": {"amount": amount}})

	s.history.append({
		"day": day(), "money": int(s.money), "health": float(s.health), "mood": float(s.mood),
		"actions": s.today.list.duplicate(), "held": int(s.held),
	})

	if day() >= LAST_DAY:
		_resolve_ending()
		_commit()
		return

	if float(s.health) <= 0.0:
		s["skip_reason"] = "ngat"
		s["health"] = 30.0
		s.stats["faints"] = int(s.stats.faints) + 1
		add_log("Sức khỏe về 0: ngày mai mất trắng.", "warn")
	elif float(s.mood) <= 0.0:
		s["skip_reason"] = "chan_nan"
		s["mood"] = 30.0
		add_log("Tinh thần về 0: ngày mai mất trắng.", "warn")

	s["yesterday"] = s.today
	s["today"] = {"list": []}
	s["used"] = 0.0
	s["day"] = day() + 1
	_morning()
	_commit()


func _resolve_ending() -> void:
	# Kết ẩn: trả đủ tiền gốc hợp pháp; tiền lãi đã đóng ở mốc ngày 10 thì mất, không được trừ vào gốc.
	var legal := int(cfg.legalDebt)
	var key := ""
	if int(s.smuggle) >= int(cfg.smuggle.tripsForBadEnding):
		key = "duong_tat"
	elif level("phapLy") >= 3 and int(s.evidence) >= int(cfg.get("legalEvidence", 2)) and int(s.money) >= legal:
		spend(legal, "Trả phần gốc hợp pháp")
		key = "cong_ly"
	elif int(s.money) >= int(s.debt):
		spend(int(s.debt), "Mốc cuối: trả nợ Hưng Sẹo")
		key = "dat_lanh" if s.flags.get("lanNhapHoc", false) and max_skill() >= 4 else "trang_tay"
	else:
		key = "game_over"
	var new_notes := []
	if key == "game_over":
		if s.flags.get("wageLost", false):
			new_notes.append("quyt_luong")
		new_notes.append("tang_lai")
		new_notes.append("hoc_nghe")
		if not s.flags.get("phapLyMo", false):
			new_notes.append("vy_luat")
		if int(s.rep.chuBay) < 20:
			new_notes.append("chu_bay")
		var added := false
		for n in new_notes:
			if not notes.has(n):
				notes.append(n)
				added = true
		if added:
			notes_changed.emit()
	s["over"] = {
		"key": key, "short": maxi(0, int(s.debt) - int(s.money)),
		"legal": legal, "new_notes": new_notes,
	}


func _commit() -> void:
	_tick_needs()
	_check_quests()
	clamp_all()
	changed.emit()


# ---------------------------------------------------------------- nhu cầu cơ thể

func has_needs() -> bool:
	return s.has("needs")


func need(k: String) -> float:
	return float(s.needs.get(k, 100.0)) if has_needs() else 100.0


func need_adj(k: String, d: float) -> void:
	if has_needs():
		s.needs[k] = clampf(float(s.needs.get(k, 0.0)) + d, 0.0, 100.0)


## Đói, bẩn dần theo giờ đã trôi; nhịn tới 0 thì mất Sức khỏe.
func _tick_needs() -> void:
	if not has_needs() or not is_started():
		return
	var dt := clock() - float(s.get("needs_t", DAY_START))
	if dt <= 0.0:
		return
	s["needs_t"] = clock()
	var starving := need("fed") <= 0.0
	for k in cfg.needs.perHour:
		need_adj(k, float(cfg.needs.perHour[k]) * dt)
	if starving or need("fed") <= 0.0:
		s["health"] = float(s.health) - float(cfg.needs.starveHealthPerHour) * dt


## Phong độ 0..100 gộp từ no bụng, vệ sinh, quần áo và tinh thần (kiểu "Cool" của Nobody).
func phong_do() -> float:
	if not has_needs():
		return 100.0
	var w: Dictionary = cfg.needs.weights
	var mood_pct := float(s.mood) / maxf(1.0, float(s.mood_max)) * 100.0
	return need("fed") * float(w.fed) + need("clean") * float(w.clean) + need("neat") * float(w.neat) + mood_pct * float(w.mood)


## Hệ số tiền công theo phong độ: đủ thì 100%, kém thì 70%, tệ thì 50%.
func pay_mult() -> float:
	if not has_needs():
		return 1.0
	var p := phong_do()
	for tier in cfg.needs.payTiers:
		if p >= float(tier[0]):
			return float(tier[1])
	return 0.5


# ---------------------------------------------------------------- việc nhờ

## Giờ tuyệt đối (ngày × 24 + giờ) để so hạn chót kéo qua nhiều ngày.
func now_abs() -> float:
	return float(day()) * 24.0 + clock()


func quest_def(id: String) -> Dictionary:
	for q in quests:
		if q.id == id:
			return q
	return {}


func _qs() -> Dictionary:
	if not s.has("quests"):
		s["quests"] = {}
	return s.quests


func quest_state(id: String) -> String:
	return str(_qs().get(id, {}).get("state", ""))


func _is_scrap(k: String) -> bool:
	return cfg.scrap.has(k) and cfg.scrap[k] is Dictionary


## Số món đang mang: ve chai nằm trong s.inv, đồ của việc nhờ nằm trong s.qitems.
func item_count(k: String) -> int:
	if _is_scrap(k):
		return int(s.get("inv", {}).get(k, 0))
	return int(s.get("qitems", {}).get(k, 0))


func item_name(k: String) -> String:
	if _is_scrap(k):
		return str(cfg.scrap[k].name)
	return str(quest_items.get(k, k))


func _add_item(k: String, n: int) -> void:
	var key := "inv" if _is_scrap(k) else "qitems"
	if not s.has(key):
		s[key] = {}
	var bag: Dictionary = s[key]
	bag[k] = maxi(0, int(bag.get(k, 0)) + n)
	if int(bag[k]) == 0:
		bag.erase(k)


func quest_offerable(q: Dictionary) -> bool:
	if not is_started() or is_over():
		return false
	var st: Dictionary = _qs().get(q.id, {})
	if not st.is_empty() and not (st.state == "declined" and day() > int(st.day)):
		return false
	if q.has("days") and (day() < int(q.days[0]) or day() > int(q.days[1])):
		return false
	if q.has("offer_window") and (clock() < float(q.offer_window[0]) or clock() > float(q.offer_window[1])):
		return false
	return check(q.get("when", {})) == ""


## Các việc nhờ đang chờ người nhận, tất cả hoặc chỉ ở một địa điểm.
func quest_offers(loc := "") -> Array:
	var out := []
	for q in quests:
		if (loc == "" or q.giver == loc) and quest_offerable(q):
			out.append(q)
	return out


func quests_active() -> Array:
	var out := []
	for q in quests:
		if quest_state(q.id) == "active":
			out.append(str(q.id))
	return out


func quest_step(id: String) -> Dictionary:
	if quest_state(id) != "active":
		return {}
	return quest_def(id).steps[int(s.quests[id].step)]


## Chỗ cần tới của bước hiện tại: {"loc": id địa điểm} hoặc {"x": [từ, tới]} với bước lục thùng rác.
func quest_target(id: String) -> Dictionary:
	var step := quest_step(id)
	match str(step.get("kind", "")):
		"visit":
			return {"loc": str(step.loc)}
		"action":
			return {"loc": str(get_action(str(step.action)).get("location", ""))}
		"find":
			return {"x": step.x}
	return {}


## Việc nhờ có bước phải bấm thẻ ở địa điểm loc (không tính bước tự xong khi tới nơi).
func quest_cards_at(loc: String) -> Array:
	var out := []
	for id in quests_active():
		var step := quest_step(id)
		if step.get("kind", "") == "visit" and step.loc == loc and not step.get("auto", false):
			out.append(id)
	return out


## "" nếu làm được bước tới-nơi hiện tại của việc nhờ id, ngược lại là lý do.
func quest_step_lock(id: String) -> String:
	if not is_started() or is_over() or not s.queue.is_empty():
		return "-"
	var step := quest_step(id)
	if step.get("kind", "") != "visit":
		return "-"
	if step.has("window") and (clock() < float(step.window[0]) or clock() > float(step.window[1])):
		return "Chỉ trong khung %s–%s" % [hh(float(step.window[0])), hh(float(step.window[1]))]
	for k in step.get("need_items", {}):
		var need := int(step.need_items[k])
		if item_count(k) < need:
			if need == 1:
				return "Chưa có: " + item_name(k).to_lower()
			return "Cần %d %s (đang có %d)" % [need, item_name(k), item_count(k)]
	if hours_left() < float(step.get("hours", 0.0)):
		return "Không đủ giờ"
	return ""


## Bấm vào người nhờ: hiện lời nhờ để nhận hay từ chối.
func quest_offer(id: String) -> void:
	var q := quest_def(id)
	if q.is_empty() or not quest_offerable(q) or not s.queue.is_empty():
		return
	s.queue.append({"id": "qo:" + id, "data": {}})
	_commit()


## Làm bước tới-nơi: tốn giờ, trao đồ nếu cần, mở hộp thoại của bước (nếu có) rồi sang bước sau.
func quest_visit(id: String) -> void:
	if quest_step_lock(id) != "":
		return
	var step := quest_step(id)
	s["used"] = float(s.used) + float(step.get("hours", 0.0))
	if step.get("consume", false):
		for k in step.need_items:
			_add_item(k, -int(step.need_items[k]))
	apply_effects(step.get("effects", {}))
	if step.has("scene"):
		s.queue.append({"id": "q:" + id, "data": {}})
	else:
		_quest_advance(id)
	_commit()


func _quest_deadline(q: Dictionary, from_day: int) -> float:
	return float(from_day + int(q.get("deadline_days", 0))) * 24.0 + float(q.get("deadline_hour", 22.0))


func _abs_text(t: float) -> String:
	var d := int(floor(t / 24.0))
	var h := t - float(d) * 24.0
	if d == day():
		return "%s hôm nay" % hh(h)
	if d == day() + 1:
		return "%s ngày mai" % hh(h)
	return "%s ngày %d" % [hh(h), d]


## Hạn của bước hoặc của cả việc nhờ, viết cho người chơi đọc.
func quest_deadline_text(id: String) -> String:
	var st: Dictionary = _qs().get(id, {})
	if st.has("step_deadline"):
		return "còn %d phút" % maxi(0, roundi((float(st.step_deadline) - now_abs()) * 60.0))
	return "hạn " + _abs_text(float(st.get("deadline", 0.0)))


func quest_progress_text(id: String) -> String:
	var step := quest_step(id)
	var t := str(step.get("text", ""))
	if step.get("kind", "") == "visit":
		for k in step.get("need_items", {}):
			if int(step.need_items[k]) > 1:
				t += " · %d/%d" % [mini(item_count(k), int(step.need_items[k])), int(step.need_items[k])]
	elif step.get("kind", "") == "action" and int(step.get("count", 1)) > 1:
		t += " · %d/%d" % [int(s.quests[id].progress), int(step.count)]
	return t


func _quest_event(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size() != 2:
		return {}
	var q := quest_def(parts[1])
	if q.is_empty():
		return {}
	match parts[0]:
		"qo":
			return {"id": id, "eyebrow": "Việc nhờ · Ngày %d" % day(), "title": q.title, "who": q.get("who", ""), "text": q.intro,
				"choices": [
					{"label": q.get("accept", "Nhận lời"), "hint": "Hạn %s · %s" % [_abs_text(_quest_deadline(q, day())), q.get("reward_hint", "")], "q_accept": true},
					{"label": q.get("decline", "Để khi khác"), "effects": q.get("decline_effects", {})},
				]}
		"q":
			var step := quest_step(parts[1])
			if not step.has("scene"):
				return {"id": id, "title": q.title, "text": "", "choices": [{"label": "Tiếp tục", "goto": "stay"}]}
			var e: Dictionary = step.scene.duplicate()
			e["id"] = id
			e["eyebrow"] = "Việc nhờ · " + str(q.title)
			return e
		"qd":
			return {"id": id, "eyebrow": "Xong việc nhờ", "title": q.title, "who": q.get("who", ""), "text": q.get("reward_text", ""),
				"choices": [{"label": "Tiếp tục", "hint": q.get("reward_hint", "")}]}
		"qf":
			return {"id": id, "eyebrow": "Hỏng việc nhờ", "title": q.title, "who": q.get("who", ""), "text": q.get("fail_text", ""),
				"choices": [{"label": "Tiếp tục"}]}
	return {}


func quest_accept(id: String) -> void:
	var q := quest_def(id)
	_qs()[id] = {"state": "active", "step": 0, "day": day(), "deadline": _quest_deadline(q, day()), "progress": 0, "misses": 0}
	add_log("Nhận việc nhờ: " + str(q.title), "event")
	apply_effects(q.get("accept_effects", {}))
	_quest_start_step(id)


func _quest_start_step(id: String) -> void:
	var st: Dictionary = s.quests[id]
	st["progress"] = 0
	st["misses"] = 0
	var step := quest_step(id)
	if step.has("within"):
		st["step_deadline"] = now_abs() + float(step.within)
	else:
		st.erase("step_deadline")


## Sang bước sau (hoặc tới bước có id goto); hết bước thì xong việc.
func _quest_advance(id: String, goto := "next") -> void:
	var q := quest_def(id)
	var st: Dictionary = s.quests[id]
	var next := int(st.step) + 1
	if goto != "next":
		for i in q.steps.size():
			if str(q.steps[i].get("id", "")) == goto:
				next = i
	if next >= q.steps.size():
		_quest_finish(id, true)
		return
	st["step"] = next
	add_log("Việc nhờ «%s»: %s" % [q.title, q.steps[next].text], "event")
	_quest_start_step(id)


func _quest_finish(id: String, ok: bool) -> void:
	var q := quest_def(id)
	var st: Dictionary = s.quests[id]
	st["state"] = "done" if ok else "failed"
	st.erase("step_deadline")
	apply_effects(q.get("reward" if ok else "fail", {}))
	s.queue.append({"id": ("qd:" if ok else "qf:") + id, "data": {}})
	add_log(("Xong việc nhờ: " if ok else "Hỏng việc nhờ: ") + str(q.title), "plus" if ok else "warn")


func _quest_choice(eid: String, c: Dictionary) -> void:
	if eid.begins_with("qo:"):
		var id := eid.substr(3)
		if c.get("q_accept", false):
			quest_accept(id)
		else:
			_qs()[id] = {"state": "declined", "day": day()}
	elif eid.begins_with("q:"):
		var id := eid.substr(2)
		if quest_state(id) != "active":
			return
		var goto := str(c.get("goto", "next"))
		match goto:
			"stay":
				pass
			"end":
				s.quests[id]["state"] = "ended"
				add_log("Thôi việc nhờ: " + str(quest_def(id).title), "warn")
			"fail":
				_quest_finish(id, false)
			_:
				_quest_advance(id, goto)


func _quest_on_action(action_id: String, result: Dictionary) -> void:
	for id in quests_active():
		var step := quest_step(id)
		if step.get("kind", "") != "action" or step.get("action", "") != action_id:
			continue
		if step.get("manual", false) and (result.is_empty() or result.get("auto", false)):
			add_log("Việc nhờ «%s» cần tự tay làm, làm tự động không tính" % quest_def(id).title, "warn")
			continue
		if float(result.get("ratio", 1.0)) < float(step.get("min_ratio", 0.0)) - 0.001:
			add_log(str(step.get("short_text", "Chưa đạt yêu cầu của việc nhờ")), "warn")
			continue
		s.quests[id]["progress"] = int(s.quests[id].progress) + 1
		if int(s.quests[id].progress) >= int(step.get("count", 1)):
			_quest_advance(id)


## Lục thùng rác đúng khúc phố của bước "find": có xác suất ra đồ, xui ba lần liền thì lần sau chắc chắn ra.
func _quest_on_scavenge(x: float) -> String:
	for id in quests_active():
		var step := quest_step(id)
		if step.get("kind", "") != "find" or x < float(step.x[0]) or x > float(step.x[1]):
			continue
		var st: Dictionary = s.quests[id]
		if randf() < float(step.get("chance", 1.0)) or int(st.get("misses", 0)) >= 3:
			_add_item(str(step.item), 1)
			var t := str(step.get("found_text", "Tìm thấy rồi!"))
			add_log(t, "event")
			_quest_advance(id)
			return t
		st["misses"] = int(st.get("misses", 0)) + 1
	return ""


## Quá hạn thì hỏng việc (trừ khi đang mở hộp thoại của chính việc đó).
func _check_quests() -> void:
	if not is_started() or is_over() or not s.has("quests"):
		return
	var t := now_abs()
	for id in quests_active():
		var busy := false
		for e in s.queue:
			if str(e.id) == "q:" + id:
				busy = true
		if busy:
			continue
		var st: Dictionary = s.quests[id]
		if t > float(st.deadline) + 0.001 or (st.has("step_deadline") and t > float(st.step_deadline) + 0.001):
			_quest_finish(id, false)


# ---------------------------------------------------------------- ve chai

func scrap_lock(bin_id: String) -> String:
	if not is_started() or is_over() or not s.queue.is_empty():
		return "-"
	if today_count("bin_" + bin_id) > 0:
		return "Thùng này hôm nay lục rồi"
	if hours_left() < float(cfg.scrap.binHours):
		return "Không đủ giờ"
	return ""


## Lục một thùng rác: mất ít phút, bẩn người, được vài chai, lon, bìa giấy. Trả về số món nhặt được.
## x: vị trí thùng dọc phố, để việc nhờ kiểu "tìm trong thùng rác cuối phố" biết thùng nào đúng chỗ.
func scavenge(bin_id: String, x := INF) -> Dictionary:
	if scrap_lock(bin_id) != "":
		return {}
	var c: Dictionary = cfg.scrap
	s["used"] = float(s.used) + float(c.binHours)
	s.today["bin_" + bin_id] = 1
	var got := {"chai": randi_range(0, 3), "lon": randi_range(0, 2), "giay": 1 if randf() < 0.4 else 0}
	if not s.has("inv"):
		s["inv"] = {}
	var parts := []
	for k in got:
		if int(got[k]) > 0:
			s.inv[k] = int(s.inv.get(k, 0)) + int(got[k])
			parts.append("%d %s" % [int(got[k]), c[k].name])
	for k in c.dirty:
		need_adj(k, float(c.dirty[k]))
	adj("mood", float(c.mood))
	add_log("Lục thùng rác: " + (", ".join(parts) if not parts.is_empty() else "không có gì"))
	var found := _quest_on_scavenge(x)
	if found != "":
		got["_quest"] = found
	_commit()
	return got


func scrap_value() -> int:
	var total := 0
	for k in s.get("inv", {}):
		total += int(s.inv[k]) * int(cfg.scrap[k].price)
	if s.flags.get("veChaiQuen", false):
		total = int(round(total * float(cfg.scrap.get("friendMult", 1.0)) / 1000.0)) * 1000
	return total


func sell_scrap() -> int:
	var v := scrap_value()
	if v <= 0:
		return 0
	earn(v, "Bán ve chai")
	s["inv"] = {}
	_commit()
	return v


## Kết quả lượt chơi dạng JSON để dán ra ngoài phân tích cân bằng.
func summary() -> String:
	if not is_started():
		return "{}"
	var skills := {}
	for k in SKILLS:
		skills[k] = level(k)
	return JSON.stringify({
		"ending": s.over.get("key", null), "day": day(), "money": int(s.money),
		"item": s.item, "room": s.room, "skills": skills, "rep": s.rep, "stats": s.stats, "talks": s.get("talks_done", []),
		"history": s.history, "choices": s.choices,
	}, " ")


# ---------------------------------------------------------------- định dạng

static func fmt_money(n: int) -> String:
	var neg := n < 0
	var t := str(absi(n))
	var out := ""
	while t.length() > 3:
		out = "." + t.substr(t.length() - 3) + out
		t = t.substr(0, t.length() - 3)
	return ("-" if neg else "") + t + out + "đ"


static func fmt_k(n: int) -> String:
	if absi(n) >= 1000000:
		return String.num(n / 1000000.0, 2).replace(".", ",") + " tr"
	return str(int(round(n / 1000.0))) + "k"


static func num(x: float) -> String:
	return String.num(x, 1).replace(".", ",")


static func hh(h: float) -> String:
	var hours := int(floor(h))
	var minutes := int(round((h - hours) * 60.0))
	return "%02d:%02d" % [hours, minutes]


static func round_k(x: float) -> int:
	return int(round(x / 10000.0)) * 10000
