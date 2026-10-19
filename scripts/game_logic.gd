extends RefCounted
## Luật chơi "Trước mùa mưa": tiền mặt tách khỏi tiền phải thu và phải trả, Mệt, tuyến nghề,
## sổ lời hứa, sổ gia đình, sự kiện theo ngày và lát cắt ngày 18–22.
## Không phụ thuộc giao diện, nên chạy được cả trong bản mô phỏng headless (tests/sim.gd).
## Số liệu và nội dung nằm trong data/*.json; file này chỉ đọc và xử lý.

signal changed
signal notes_changed

const WEEKDAYS := ["Chủ Nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy"]
const GROUPS := {"work": "Kiếm tiền", "life": "Sinh hoạt", "optional": "Việc tùy chọn"}
const ROUTES := ["A", "B", "C"]
const PROMISE_STATUS := {"open": "Đang giữ", "done": "Đã xong", "late": "Báo trễ", "overdue": "Quá hạn", "renegotiated": "Thỏa thuận lại"}
const FAMILY_KIND := {"support": "Hỗ trợ", "pressure": "Ép quyết định", "conceal": "Che giấu", "time_lost": "Bớt giờ ở nhà"}

var cfg: Dictionary = {}
var events: Array = []
var story: Dictionary = {}
## Trạng thái ván chơi. Rỗng nghĩa là chưa bắt đầu (đang ở màn chọn tuyến).
var s: Dictionary = {}
## Ghi chú giữ lại qua các lượt (chưa dùng trong lát cắt, để dành cho Sổ tay).
var notes: Array = []
var _event_data: Dictionary = {}


# ---------------------------------------------------------------- dữ liệu

func load_data(dir := "res://data") -> void:
	cfg = _read_json(dir + "/config.json")
	events = _read_json(dir + "/events.json")
	story = _read_json(dir + "/story.json")


static func _read_json(path: String) -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("Không đọc được file dữ liệu: " + path)
	return data


# ---------------------------------------------------------------- bắt đầu

## Bắt đầu lát cắt ở ngày 18 với trạng thái dựng sẵn của tuyến A, B hoặc C.
func new_game(route: String) -> void:
	var p: Dictionary = cfg.presets[route]
	_event_data = {}
	s = {
		"day": int(cfg.sliceStartDay), "used": 0.0, "route": route,
		"cash": int(p.cash), "fatigue": float(p.fatigue), "warn_days": 0, "rest_skips": 0,
		"progress": int(p.progress), "progress_need": int(p.progressNeed),
		"receivables": [], "payables": [], "promises": [], "family": [],
		"respect": 0, "linh": {"wish": p.get("linhWish", "xa"), "decision": "", "contact": ""},
		"rep": p.rep.duplicate(), "flags": {}, "counts": {},
		"today": {"list": []}, "yesterday": {"list": []},
		"queue": [], "log": [], "history": [], "choices": [], "over": {},
		"stats": {"earned": 0, "spent": 0, "start_cash": int(p.cash)},
	}
	for r in p.receivables:
		_add_receivable(r)
	for x in p.payables:
		_add_payable(x)
	for pr in p.promises:
		_add_promise(pr)
	add_log("Bắt đầu lát cắt: " + str(p.name), "event")
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


func clock() -> float:
	return float(cfg.dayStart) + float(s.used)


func day_end() -> float:
	return float(cfg.dayEnd)


func hours_left() -> float:
	return maxf(0.0, day_end() - clock())


func weekday_name() -> String:
	return WEEKDAYS[day() % 7]


func rep_name(k: String) -> String:
	return str(story.reps.get(k, k))


func fatigue_warn() -> bool:
	return float(s.fatigue) >= float(cfg.fatigue.warn)


func progress_ready() -> bool:
	return int(s.progress) >= int(s.progress_need)


## Tổng tiền phải thu còn chờ, chia theo hạn: đến hết ngày `until` (bao gồm).
func receivable_sum(from_day: int, until_day: int) -> int:
	var total := 0
	for r in s.receivables:
		if r.status == "pending" and int(r.due) >= from_day and int(r.due) <= until_day:
			total += int(r.amount)
	return total


func payable_sum(until_day: int) -> int:
	var total := 0
	for x in s.payables:
		if x.status == "pending" or x.status == "unpaid":
			if int(x.due) <= until_day:
				total += int(x.amount)
	return total


## Tiền mặt dự kiến vào sáng ngày `target`: tiền đang có, cộng khoản phải thu chắc chắn tới hạn,
## trừ khoản phải trả và tiền sinh hoạt các đêm còn lại. Đợt nghiệm thu chỉ tính khi đủ tiến độ.
func projected_cash(target: int) -> int:
	var total := int(s.cash)
	for r in s.receivables:
		if r.status != "pending" or int(r.due) >= target:
			continue
		if r.get("needsProgress", false) and not progress_ready():
			continue
		total += int(r.amount)
	total -= payable_sum(target - 1)
	total -= int(cfg.livingCostPerDay) * maxi(0, target - day())
	return total


## Chỗ ở đắt nhất mà tiền dự kiến ngày chốt đủ trả.
func best_housing(amount: int) -> String:
	var best := ""
	var best_cost := -1
	for k in cfg.housing:
		var c := int(cfg.housing[k].cost)
		if amount >= c and c > best_cost:
			best = k
			best_cost = c
	return best


func count_family(who: String, kind: String) -> int:
	var n := 0
	for f in s.family:
		if (who == "" or f.who == who) and f.kind == kind:
			n += 1
	return n


# ---------------------------------------------------------------- thay đổi

func add_log(text: String, kind := "info") -> void:
	s.log.append({"day": day(), "t": text, "k": kind})


func earn(n: int, why: String) -> void:
	s["cash"] = int(s.cash) + n
	s.stats["earned"] = int(s.stats.earned) + n
	add_log("+%s · %s" % [fmt_money(n), why], "plus")


func spend(n: int, why: String) -> int:
	var taken := mini(n, int(s.cash))
	s["cash"] = int(s.cash) - taken
	s.stats["spent"] = int(s.stats.spent) + taken
	add_log("−%s · %s" % [fmt_money(taken), why], "minus")
	return taken


func add_fatigue(d: float) -> void:
	s["fatigue"] = clampf(float(s.fatigue) + d, 0.0, float(cfg.fatigue.max))


func add_rep(k: String, d: float) -> void:
	s.rep[k] = clampi(int(s.rep.get(k, 50)) + int(d), 0, 100)


func _find(list: Array, id: String) -> Variant:
	for item in list:
		if item.id == id:
			return item
	return null


func _add_receivable(r: Dictionary) -> void:
	var old = _find(s.receivables, r.id)
	if old != null:
		s.receivables.erase(old)
	var item := r.duplicate()
	item["amount"] = int(r.amount)
	item["due"] = int(r.due)
	item["status"] = "pending"
	s.receivables.append(item)


func _add_payable(x: Dictionary) -> void:
	var old = _find(s.payables, x.id)
	if old != null:
		s.payables.erase(old)
	var item := x.duplicate()
	item["amount"] = int(x.amount)
	item["due"] = int(x.due)
	item["status"] = "pending"
	s.payables.append(item)


func _add_promise(p: Dictionary) -> void:
	var old = _find(s.promises, p.id)
	if old != null:
		s.promises.erase(old)
	var item := p.duplicate()
	item["due"] = int(p.due)
	item["status"] = "open"
	item["made"] = day()
	s.promises.append(item)


## Nhận một khoản phải thu thành tiền mặt.
func collect(id: String) -> void:
	var r = _find(s.receivables, id)
	if r == null or r.status != "pending":
		return
	r["status"] = "collected"
	earn(int(r.amount), str(r.label))


## Áp một bộ hiệu ứng viết trong JSON, ví dụ {"cash": -300000, "rep.LINH": 5, "flag.baoGia": true}.
func apply_effects(eff: Dictionary) -> void:
	var label: String = eff.get("cash_label", "")
	for key in eff:
		var v = eff[key]
		match key:
			"cash_label":
				pass
			"cash":
				if int(v) >= 0:
					earn(int(v), label)
				else:
					spend(-int(v), label)
			"hours":
				s["used"] = float(s.used) + float(v)
			"fatigue":
				add_fatigue(float(v))
			"progress":
				s["progress"] = int(s.progress) + int(v)
			"progress_need":
				s["progress_need"] = int(s.progress_need) + int(v)
			"respect":
				s["respect"] = int(s.respect) + int(v)
			"receivable":
				_add_receivable(v)
				add_log("Thêm khoản phải thu: %s %s, hạn ngày %d" % [v.label, fmt_money(int(v.amount)), int(v.due)], "event")
			"payable":
				_add_payable(v)
				add_log("Thêm khoản phải trả: %s %s, hạn ngày %d" % [v.label, fmt_money(int(v.amount)), int(v.due)], "warn")
			"promise":
				_add_promise(v)
				add_log("Lời hứa mới: %s (hạn ngày %d)" % [v.text, int(v.due)], "warn")
			"promise_status":
				var p = _find(s.promises, v.id)
				if p != null:
					p["status"] = v.status
			"family":
				var f: Dictionary = v.duplicate()
				f["day"] = day()
				s.family.append(f)
			"special":
				_special(str(v))
			"log":
				add_log(fill(str(v)), "event")
			_:
				if key.begins_with("rep."):
					add_rep(key.substr(4), float(v))
				elif key.begins_with("flag."):
					if v:
						s.flags[key.substr(5)] = true
					else:
						s.flags.erase(key.substr(5))
				else:
					push_warning("Hiệu ứng không rõ: " + str(key))


func _special(name: String) -> void:
	match name:
		"narrow_contract":
			# Nhận phần đã nghiệm thu theo tiến độ thật, thu hẹp phần còn lại.
			var mid = _find(s.receivables, "hd_giua")
			if mid != null and mid.status == "pending":
				var ratio := minf(1.0, float(s.progress) / maxf(1.0, float(s.progress_need)))
				mid["amount"] = round_k(float(mid.amount) * ratio)
				collect("hd_giua")
			var last = _find(s.receivables, "hd_cuoi")
			if last != null:
				last["amount"] = 1000000
			var team = _find(s.payables, "cong_doi")
			if team != null and team.status == "pending":
				team["amount"] = maxi(0, int(team.amount) - 400000)
			s["progress_need"] = int(s.progress)
			s.flags["thuHep"] = true
			for p in s.promises:
				if p.get("doneIf", "") == "progress_ready" and p.status == "open":
					p["status"] = "renegotiated"
			add_log("Thu hẹp hợp đồng: đợt cuối còn 1.000.000đ, công đội giảm 400.000đ", "event")
		"linh_decides":
			# Linh tự quyết theo mong muốn của em. Thái độ của An chỉ đổi cách em báo tin.
			s.linh["decision"] = s.linh.wish
			s.linh["contact"] = "lanh" if count_family("LINH", "pressure") >= 2 else "binh_thuong"
			s.queue.push_front({"id": "linh_quyet", "data": {}})
		_:
			push_warning("Hiệu ứng đặc biệt không rõ: " + name)


# ---------------------------------------------------------------- điều kiện

## Trả về "" nếu thỏa điều kiện, ngược lại trả về lý do để hiện cho người chơi.
func check(req: Dictionary) -> String:
	for key in req:
		var v = req[key]
		var fail := ""
		if key.begins_with("rep."):
			var k: String = key.substr(4)
			var have := int(s.rep.get(k, 0))
			if have < int(v):
				fail = "Cần thân với %s (%d/%d)" % [rep_name(k), have, int(v)]
		elif key.begins_with("flag."):
			if bool(s.flags.get(key.substr(5), false)) != bool(v):
				fail = "Chưa mở"
		elif key == "route":
			var ok: bool = s.route in v if v is Array else s.route == v
			if not ok:
				fail = "Không thuộc tuyến này"
		elif key == "from_day":
			if day() < int(v):
				fail = "Mở từ ngày %d" % int(v)
		elif key == "cash_min":
			if int(s.cash) < int(v):
				fail = "Cần tiền mặt từ %s" % fmt_money(int(v))
		elif key == "hours_left":
			if hours_left() < float(v):
				fail = "Không đủ giờ hôm nay"
		elif key == "pressure_min":
			if count_family("LINH", "pressure") < int(v):
				fail = "-"
		elif key == "linh_wish":
			if s.linh.wish != v:
				fail = "-"
		elif key == "progress_ready":
			if progress_ready() != bool(v):
				fail = "-"
		else:
			push_warning("Điều kiện không rõ: " + str(key))
		if fail != "":
			return fail
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
	return int(a.get("cost", 0))


func is_hidden(a: Dictionary) -> bool:
	if a.has("days") and (day() < int(a.days[0]) or day() > int(a.days[1])):
		return true
	if a.has("require") and a.require.has("route") and check({"route": a.require.route}) != "":
		return true
	if a.has("maxTimes") and count(a.id) >= int(a.maxTimes):
		return true
	return false


func visible_actions(group: String) -> Array:
	var out := []
	for a in cfg.actions:
		if a.group == group and not is_hidden(a):
			out.append(a)
	return out


func actions_at(location: String) -> Array:
	var out := []
	for a in cfg.actions:
		if a.get("location", "") == location and not is_hidden(a):
			out.append(a)
	return out


## {"ok": bool, "reason": String, "start": giờ bắt đầu nếu làm được}
func action_status(a: Dictionary) -> Dictionary:
	if is_over() or not s.queue.is_empty():
		return {"ok": false, "reason": ""}
	var reason := check(a.get("require", {}))
	if reason != "":
		return {"ok": false, "reason": reason}
	if today_count(a.id) >= int(a.get("perDay", 1)):
		return {"ok": false, "reason": "Hôm nay đã làm rồi"}
	if action_money(a) > int(s.cash):
		return {"ok": false, "reason": "Không đủ tiền mặt"}
	if a.group == "work" and float(s.fatigue) >= float(cfg.fatigue.max):
		return {"ok": false, "reason": "Quá mệt, cần nghỉ trước"}
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


func do_action(id: String) -> void:
	var a := get_action(id)
	if a.is_empty() or is_hidden(a):
		return
	var st := action_status(a)
	if not st.ok:
		return
	var start: float = st.start
	var finish := start + float(a.hours)
	s["used"] = finish - float(cfg.dayStart)
	if a.has("cost"):
		spend(int(a.cost), str(a.name))
	var label := "%s %s" % [hh(start), a.name]
	if a.has("pay"):
		earn(int(a.pay), label)
	else:
		add_log(label)
	apply_effects(a.get("effects", {}))
	if a.group == "work" and finish > float(cfg.lateHour) + 0.001:
		add_fatigue(float(cfg.lateFatigue))
		add_log("Làm tới cuối tối: Mệt +%d" % int(cfg.lateFatigue), "warn")
	if a.get("rest", false):
		s.today["rested"] = true
	s.counts[id] = count(id) + 1
	s.today[id] = today_count(id) + 1
	s.today.list.append(id)
	_commit()


## Thời gian trôi khi đi bộ trên phố. Không vượt quá giờ đi ngủ.
func walk(hours: float) -> void:
	if not is_started() or is_over() or not s.queue.is_empty() or hours <= 0.0:
		return
	s["used"] = minf(float(s.used) + hours, day_end() - float(cfg.dayStart))
	_commit()


func is_out_of_time() -> bool:
	return is_started() and not is_over() and hours_left() <= 0.001


## Hết giờ mà chưa về xóm trọ: ngủ gục ngoài đường, Mệt tăng rồi sang ngày mới.
func sleep_outside() -> void:
	if not is_started() or is_over() or not s.queue.is_empty():
		return
<<<<<<< HEAD
	add_fatigue(float(cfg.fatigue.sleepOutside))
	add_log("Không kịp về xóm trọ, ngủ gục ngoài đường.", "warn")
	finish_day()
=======
	add_log("Không kịp về phòng trọ, ngủ gục ngoài đường.", "warn")
	finish_day(false)
	# Trừ sau khi ngủ, nếu không phần hồi sức khi ngủ sẽ xóa mất hình phạt.
>>>>>>> 16f8961582ba92b62b4b1e298eb9ceea8b2ccda5
	if not is_over():
		var pen: Dictionary = cfg.get("sleepOutside", {})
		adj("health", float(pen.get("health", 0)))
		adj("mood", float(pen.get("mood", 0)))
		s.queue.push_front({"id": "ngu_gat", "data": {}})
		_commit()


# ---------------------------------------------------------------- sự kiện

func find_event(id: String) -> Dictionary:
	for e in events:
		if e.id == id:
			return e
	return {}


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
		e["eyebrow"] = "Ngày %d · %s" % [day(), weekday_name()]
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
	var mid = _find(s.get("receivables", []), "hd_giua")
	var vals := {
		"day": str(day()),
		"progress": str(int(s.get("progress", 0))),
		"need": str(int(s.get("progress_need", 0))),
		"need_left": str(maxi(0, int(s.get("progress_need", 0)) - int(s.get("progress", 0)))),
		"hd_giua": fmt_money(int(mid.amount)) if mid != null else "",
		"proj26": fmt_money(projected_cash(int(cfg.housingDeadline))),
		"amount": fmt_money(int(_event_data.get("amount", 0))),
		"label": str(_event_data.get("label", "")),
		"sleep_out": str(int(cfg.fatigue.sleepOutside)),
	}
	for k in vals:
		text = text.replace("{" + k + "}", vals[k])
	return text


func _events_for_day(d: int) -> Array:
	var out := []
	for e in events:
		if e.get("system", false):
			continue
		var on: bool = e.has("day") and int(e.day) == d
		if on and check(e.get("when", {})) == "":
			out.append({"id": e.id, "data": {}})
	return out


func _morning() -> void:
	s.queue.append_array(_events_for_day(day()))


# ---------------------------------------------------------------- cuối ngày

func night_preview() -> Dictionary:
	var due_pay := 0
	for x in s.payables:
		if x.status == "pending" and int(x.due) == day():
			due_pay += int(x.amount)
	var due_recv := []
	for r in s.receivables:
		if r.status == "pending" and int(r.due) == day():
			due_recv.append(r.label)
	return {
		"living": int(cfg.livingCostPerDay), "free_hours": hours_left(),
		"recover": -(float(cfg.fatigue.sleep) + hours_left() * float(cfg.fatigue.freeHour)),
		"due_pay": due_pay, "due_recv": due_recv,
		"slice_end": day() >= int(cfg.sliceEndDay),
	}


func finish_day() -> void:
	if not is_started() or is_over() or not s.queue.is_empty():
		return
	var tonight := []
	spend(int(cfg.livingCostPerDay), "Sinh hoạt cả nhà")

	# Mệt: đếm ngày ở mức cảnh báo và những lần bỏ qua cơ hội nghỉ, rồi hồi qua đêm.
	if fatigue_warn():
		s["warn_days"] = int(s.warn_days) + 1
		if not s.today.get("rested", false):
			s["rest_skips"] = int(s.rest_skips) + 1
	add_fatigue(float(cfg.fatigue.sleep) + hours_left() * float(cfg.fatigue.freeHour))

	# Khoản phải thu đến hạn. Đợt nghiệm thu chỉ về khi đủ tiến độ.
	for r in s.receivables:
		if r.status != "pending" or int(r.due) != day():
			continue
		if r.get("needsProgress", false) and not progress_ready():
			r["due"] = day() + 3
			add_rep("PHUC", -5)
			add_log("Chưa nghiệm thu: %s dời sang ngày %d" % [r.label, int(r.due)], "warn")
			tonight.append({"id": "hd_giua_tre", "data": {}})
		else:
			collect(r.id)
			if r.get("needsProgress", false):
				tonight.append({"id": "hd_giua_ok", "data": {"amount": int(r.amount)}})

	# Khoản phải trả đến hạn.
	for x in s.payables:
		if x.status != "pending" or int(x.due) != day():
			continue
		if int(s.cash) >= int(x.amount):
			x["status"] = "paid"
			spend(int(x.amount), str(x.label))
		else:
			x["status"] = "unpaid"
			if str(x.get("to", "")) != "":
				add_rep(x.to, -15)
			add_log("Không đủ tiền trả: %s %s" % [x.label, fmt_money(int(x.amount))], "warn")
			tonight.append({"id": "khong_du_tra", "data": {"amount": int(x.amount), "label": x.label}})

	# Lời hứa đến hạn.
	for p in s.promises:
		if p.status != "open" or int(p.due) != day():
			continue
		if p.get("doneIf", "") == "progress_ready" and progress_ready():
			p["status"] = "done"
		else:
			p["status"] = "overdue"
			add_rep(p.to, -8)
			add_log("Lời hứa quá hạn: " + str(p.text), "warn")

	s.history.append({
		"day": day(), "cash": int(s.cash), "fatigue": float(s.fatigue),
		"proj26": projected_cash(int(cfg.housingDeadline)), "actions": s.today.list.duplicate(),
	})

	if day() >= int(cfg.sliceEndDay):
		s["queue"] = tonight
		s["over"] = {"kind": "slice"}
		_commit()
		return

	s["yesterday"] = s.today
	s["today"] = {"list": []}
	s["used"] = 0.0
	s["day"] = day() + 1
	s["queue"] = tonight
	_morning()
	_commit()


## Bảng tổng kết lát cắt: dòng tiền, chỗ ở dự kiến, Linh, bà Tư, lời hứa, sổ gia đình.
func slice_report() -> Dictionary:
	var deadline := int(cfg.housingDeadline)
	var proj := projected_cash(deadline)
	var linh_card := "chua"
	if s.linh.contact == "lanh":
		linh_card = "lanh"
	elif s.linh.decision != "":
		linh_card = s.linh.decision
	var ba_card := "lo"
	if s.flags.get("baTuThuDuong", false) or s.flags.get("baTuChonUuTien", false):
		ba_card = "tot"
	elif _find(s.promises, "dua_ba_di_cho") != null:
		ba_card = "hua"
	var promises := []
	for p in s.promises:
		promises.append({"text": p.text, "due": int(p.due), "status": p.status})
	return {
		"route": s.route, "cash": int(s.cash), "fatigue": float(s.fatigue),
		"warn_days": int(s.warn_days), "rest_skips": int(s.rest_skips),
		"progress": int(s.progress), "need": int(s.progress_need),
		"recv_before_30": receivable_sum(0, 30), "recv_after_30": receivable_sum(31, 999),
		"pay_pending": payable_sum(999), "proj_deadline": proj, "housing": best_housing(proj),
		"linh_card": linh_card, "linh_decision": s.linh.decision, "respect": int(s.respect),
		"ba_tu_card": ba_card, "promises": promises,
		"family": {
			"support": count_family("", "support"), "pressure": count_family("", "pressure"),
			"conceal": count_family("", "conceal"), "time_lost": count_family("", "time_lost"),
		},
		"rep": s.rep,
	}


func _commit() -> void:
	changed.emit()


## Kết quả lượt chơi dạng JSON để dán ra ngoài phân tích cân bằng.
func summary() -> String:
	if not is_started():
		return "{}"
	return JSON.stringify({
		"report": slice_report(), "history": s.history, "choices": s.choices,
		"receivables": s.receivables, "payables": s.payables, "family": s.family,
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
