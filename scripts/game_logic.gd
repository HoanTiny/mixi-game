extends RefCounted
## Luật chơi "Trước mùa mưa": tiền mặt tách khỏi tiền phải thu và phải trả, Mệt, tuyến nghề,
## sổ lời hứa, sổ gia đình, sự kiện theo ngày và lát cắt ngày 18–22.
## Chương 2 · Mùa mưa (ngày 31–60) chơi tiếp sau màn kết chương 1, giữ mọi thứ đã chọn: nội dung nằm ở
## events2.json, story2.json, talks2.json, quests2.json; số liệu ở chapter2 trong config.json.
## Thêm các cơ chế kiểu Nobody: nhu cầu cơ thể và Phong độ, trò chơi nhỏ khi làm, app giao hàng,
## lục ve chai, nói chuyện với nhân vật, việc nhờ nhiều bước.
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
## Hội thoại với nhân vật, theo khóa trong story.reps (data/talks.json).
var talks: Dictionary = {}
## Việc nhờ nhiều bước (data/quests.json): danh sách quest và tên các món đồ của quest.
var quests: Array = []
var quest_items: Dictionary = {}
## Chương 2: kết thúc, thẻ hậu truyện, đồ giữ lại, đoạn "sau đó", nhân vật mới (data/story2.json).
var story2: Dictionary = {}
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
	talks = _read_json(dir + "/talks.json")
	talks.erase("_ghi_chu")
	if FileAccess.file_exists(dir + "/quests.json"):
		var q: Dictionary = _read_json(dir + "/quests.json")
		quests = q.get("quests", [])
		quest_items = q.get("items", {})
	# Chương 2 nằm ở file riêng: gộp sự kiện, hội thoại, việc nhờ; lời hé lộ ngày mai và tên nhân vật mới
	# đi chung với chương 1.
	if FileAccess.file_exists(dir + "/events2.json"):
		events.append_array(_read_json(dir + "/events2.json"))
	if FileAccess.file_exists(dir + "/config2.json"):
		cfg.actions.append_array(_read_json(dir + "/config2.json").get("actions", []))
	if FileAccess.file_exists(dir + "/story2.json"):
		story2 = _read_json(dir + "/story2.json")
		story.teasers.merge(story2.get("teasers", {}))
		story.reps.merge(story2.get("reps", {}))
	if FileAccess.file_exists(dir + "/talks2.json"):
		var t2: Dictionary = _read_json(dir + "/talks2.json")
		t2.erase("_ghi_chu")
		for npc in t2:
			if not talks.has(npc):
				talks[npc] = {"story": [], "chat": []}
			talks[npc].story.append_array(t2[npc].get("story", []))
			talks[npc].chat.append_array(t2[npc].get("chat", []))
	if FileAccess.file_exists(dir + "/quests2.json"):
		var q2: Dictionary = _read_json(dir + "/quests2.json")
		quests.append_array(q2.get("quests", []))
		quest_items.merge(q2.get("items", {}))


static func _read_json(path: String) -> Variant:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("Không đọc được file dữ liệu: " + path)
	return data


# ---------------------------------------------------------------- bắt đầu

## mode "full": chơi đủ 30 ngày từ ngày 1 (cfg.full). "A", "B", "C": lát cắt ngày 18–22
## với trạng thái dựng sẵn của tuyến đó (cfg.presets).
func new_game(mode: String) -> void:
	var full := mode == "full"
	var p: Dictionary = cfg.full if full else cfg.presets[mode]
	_event_data = {}
	s = {
		"mode": "full" if full else "slice",
		"day": 1 if full else int(cfg.sliceStartDay), "used": 0.0, "route": "" if full else mode,
		"cash": int(p.cash), "fatigue": float(p.fatigue), "warn_days": 0, "rest_skips": 0,
		"progress": int(p.progress), "progress_need": int(p.progressNeed),
		"receivables": [], "payables": [], "promises": [], "family": [],
		"respect": 0, "linh": {"wish": p.get("linhWish", "xa"), "decision": "", "contact": ""},
		"rep": p.rep.duplicate(), "flags": {}, "counts": {},
		"today": {"list": []}, "yesterday": {"list": []},
		"queue": [], "log": [], "history": [], "choices": [], "over": {},
		"stats": {"earned": 0, "spent": 0, "start_cash": int(p.cash)},
		"talks_done": [], "quests": {}, "qitems": {}, "inv": {}, "job_last": {},
		"housing": {"state": "none", "place": "", "paid": 0, "seen": []},
		"scenes": [], "scenes_done": [], "missed": [], "diary": [],
	}
	# Nhu cầu cơ thể kiểu Nobody: tự ăn ở quán, tắm, giặt đồ ở xóm trọ.
	if cfg.has("needs"):
		s["needs"] = cfg.needs.start.duplicate()
		s["needs_t"] = float(cfg.dayStart)
	for r in p.receivables:
		_add_receivable(r)
	for x in p.payables:
		_add_payable(x)
	for pr in p.promises:
		_add_promise(pr)
	add_log(("Bắt đầu: " if full else "Bắt đầu lát cắt: ") + str(p.name), "event")
	if full:
		s.queue.append({"id": "mo_dau", "data": {}})
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


## Đang chơi đủ 30 ngày (không phải lát cắt ngày 18–22).
func is_full() -> bool:
	return is_started() and s.get("mode", "slice") == "full"


func last_day() -> int:
	if not is_full():
		return int(cfg.sliceEndDay)
	return 60 if chapter() == 2 else 30


## 1: ba mươi ngày trước mùa mưa; 2: mùa mưa ở chỗ mới (ngày 31–60).
func chapter() -> int:
	return int(s.get("chapter", 1)) if is_started() else 1


## Màn kết chương 1 có thể chơi tiếp sang chương 2 (đã có nội dung chương 2).
func can_continue() -> bool:
	return is_over() and str(s.over.get("kind", "")) == "full" and chapter() == 1 and not story2.is_empty()


## Địa điểm An ngủ và sinh hoạt: xóm trọ Bờ Me ở chương 1, chỗ ở lúc vào chương 2 (giữ nguyên suốt chương;
## ở nhờ dì Năm mà đặt cọc phòng mới thì dọn sau giỗ, sau ngày 60).
func home_loc() -> String:
	if chapter() == 2 and s.has("home2"):
		return str(s.home2.loc)
	return "xom_bo_me"


## Đổi chỗ "home" trong dữ liệu (cảnh, việc nhờ, hành động sinh hoạt) thành địa điểm thật.
func loc_of(loc: String) -> String:
	return home_loc() if loc == "home" else loc


func action_loc(a: Dictionary) -> String:
	return loc_of(str(a.get("location", "")))


func housing() -> Dictionary:
	if not s.has("housing"):
		s["housing"] = {"state": "none", "place": "", "paid": 0, "seen": []}
	return s.housing


## Số tiền còn phải chi để vào ở chỗ k (trừ phần cọc đã đặt ở chính chỗ đó).
func housing_cost(k: String) -> int:
	var h := housing()
	var cost := int(cfg.housing[k].cost)
	if h.place == k:
		cost -= int(h.get("paid", 0))
	return maxi(0, cost)


## Đã có chỗ thuê dài hạn (đã ký, không phải ở tạm).
func has_long_home() -> bool:
	var h := housing()
	return h.state == "signed" and not bool(cfg.housing.get(h.place, {}).get("temp", false))


## Số lần che giấu hoặc ép quyết định với gia đình (từ ngày from_day), mỗi ngày tính một lần.
func hidden_marks(from_day := 0) -> int:
	var days := {}
	for f in s.family:
		if (f.kind == "conceal" or f.kind == "pressure") and int(f.day) >= from_day:
			days[int(f.day)] = true
	return days.size()


## Có lời hứa quá hạn, khoản phải trả chưa trả hoặc báo xong sai: những việc cần sửa ở ngày 30.
func has_broken() -> bool:
	if s.flags.get("falseCompletion", false) and not s.flags.get("suaSai", false):
		return true
	for p in s.promises:
		if p.status == "overdue":
			return true
	for x in s.payables:
		if x.status == "unpaid":
			return true
	return hidden_marks() >= 2


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
	total -= living_cost() * maxi(0, target - day())
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
				if v is Array:
					for sp in v:
						_special(str(sp))
				else:
					_special(str(v))
			"log":
				add_log(fill(str(v)), "event")
			"diary":
				add_diary(fill(str(v)))
			"route":
				_set_route(str(v))
			"receivables":
				for x in v:
					_add_receivable(x)
					add_log("Thêm khoản phải thu: %s %s, hạn ngày %d" % [x.label, fmt_money(int(x.amount)), int(x.due)], "event")
			"rested":
				if v:
					s.today["rested"] = true
			"receivable_remove":
				var r = _find(s.receivables, str(v))
				if r != null:
					s.receivables.erase(r)
			"receivable_due":
				var r = _find(s.receivables, str(v.id))
				if r != null:
					r["due"] = int(v.due)
					add_log("Dời hạn %s sang ngày %d" % [r.label, int(v.due)], "warn")
			"collect":
				collect(str(v))
			"payable_status":
				var x = _find(s.payables, str(v.id))
				if x != null:
					x["status"] = str(v.status)
			"pay":
				# Đóng sớm một khoản phải trả (tiền nhà tháng sau…) nếu đủ tiền mặt.
				var x = _find(s.payables, str(v))
				if x != null and x.status == "pending" and int(s.cash) >= int(x.amount):
					x["status"] = "paid"
					spend(int(x.amount), str(x.label))
			"housing":
				_take_housing(str(v), false)
			"housing_owed":
				_take_housing(str(v), true)
			"housing_reserve":
				_reserve_housing(str(v))
			"housing_seen":
				if not housing().seen.has(str(v)):
					housing().seen.append(str(v))
			"quest_start":
				var qa: Dictionary = v if v is Dictionary else {"id": str(v)}
				if quest_state(str(qa.id)) == "":
					quest_accept(str(qa.id), qa)
			"linh_wish":
				s.linh["wish"] = str(v)
			"queue":
				s.queue.append({"id": str(v), "data": {}})
			_:
				if key.begins_with("rep."):
					add_rep(key.substr(4), float(v))
				elif key.begins_with("need."):
					need_adj(key.substr(5), float(v))
				elif key.begins_with("item."):
					_add_item(key.substr(5), int(v))
				elif key.begins_with("flag."):
					if v:
						s.flags[key.substr(5)] = true
					else:
						s.flags.erase(key.substr(5))
				elif key.begins_with("score."):
					# Điểm cộng dồn của một mạch (má muốn ở lại tới đâu…), so bằng điều kiện score.X / score_lt.
					if not s.has("scores"):
						s["scores"] = {}
					s.scores[key.substr(6)] = int(s.scores.get(key.substr(6), 0)) + int(v)
				else:
					push_warning("Hiệu ứng không rõ: " + str(key))


func _special(name: String) -> void:
	match name:
		"end_game":
			s["end_now"] = true
		"fix_broken":
			# Ngày 30 sửa lời hứa đổ vỡ: khoản chưa trả được hẹn lại lịch, báo sai được nhận lại. Vẫn để dấu vết (kết E4).
			for x in s.payables:
				if x.status == "unpaid":
					x["status"] = "renegotiated"
			for p in s.promises:
				if p.status == "overdue":
					p["status"] = "renegotiated"
			s.flags["suaSai"] = true
			s.flags["suaSaiGiaDinh"] = true
			if s.flags.get("falseCompletion", false):
				s.flags["thuHepCuoi"] = true
		"rain":
			s.today["rain"] = true
		"client_buys_materials":
			# Khách tự mua vật tư: bỏ các khoản vật tư phải trả, tính lại giá dịch vụ (8,4tr − 4tr vật tư = 4,4tr)
			# theo cùng tỉ lệ 40/30/30. Phần ứng khi ký đã nhận dư thì hoàn lại cho anh Phúc.
			var removed := 0
			for x in s.payables.duplicate():
				if str(x.id).begins_with("vat_tu") and x.status == "pending":
					removed += int(x.amount)
					s.payables.erase(x)
			var service := int(cfg.contract.total) - int(cfg.contract.materials)
			var sign = _find(s.receivables, "hd_ky")
			var new_sign := round_k(service * 0.4)
			if sign != null and sign.status == "collected" and int(sign.amount) > new_sign:
				_add_payable({"id": "hoan_ung", "to": "PHUC", "label": "Hoàn phần ứng vật tư cho anh Phúc", "amount": int(sign.amount) - new_sign, "due": day() + 1})
			for id in ["hd_giua", "hd_cuoi"]:
				var r = _find(s.receivables, id)
				if r != null and r.status == "pending":
					r["amount"] = round_k(service * 0.3)
			s.flags["khachMuaVatTu"] = true
			add_log("Khách tự mua vật tư: bỏ %s vật tư phải trả, giá dịch vụ còn %s" % [fmt_money(removed), fmt_money(service)], "event")
		"narrow_final":
			# Bàn giao phần đã đạt, thu hẹp phần chưa làm: đợt cuối tính theo tiến độ thật, phần dở hẹn trả dần sau ngày 30.
			var last = _find(s.receivables, "hd_cuoi")
			if last != null and last.status == "pending":
				var ratio := minf(1.0, float(s.progress) / maxf(1.0, float(s.progress_need)))
				last["amount"] = round_k(float(last.amount) * ratio * 0.8)
			s["progress_need"] = int(s.progress)
			s.flags["thuHepCuoi"] = true
			for p in s.promises:
				if p.get("doneIf", "") == "progress_ready" and p.status == "open":
					p["status"] = "renegotiated"
			add_log("Thu hẹp phần cuối: bàn giao phần đạt, phần dở ghi lịch trả lại", "event")
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
		"rent_next":
			# Chuyển vào chỗ thuê dài hạn ở chương 2: tiền nhà tháng sau tính theo chỗ mới, hạn tối ngày 60.
			var rent := int(cfg.get("chapter2", {}).get("rent", {}).get(str(housing().place), 0))
			var old = _find(s.payables, "tien_nha_t2")
			if old != null:
				s.payables.erase(old)
			if rent > 0:
				_add_payable({"id": "tien_nha_t2", "to": "", "label": "Tiền nhà tháng sau · " + str(cfg.housing[housing().place].name),
					"amount": rent, "due": int(cfg.chapter2.rentDue)})
		"ma_decides":
			# Má tự chọn đi hay ở. Má đi lặng lẽ khi thấy mình chỉ là khách hay người trả tiền trong nhà (điểm maO âm,
			# hoặc chưa từng có cuộc nói thật mà điểm còn thấp, hoặc An giấu, ép người nhà nhiều ngày).
			# Còn lại là ý riêng của má: được hỏi ý (ngày 52), mắt bà đã mổ mà má chưa có chỗ làm gần nhà thì má quay lại
			# nghề chuyền trưởng ở xa, có hẹn gọi về; bà chưa mổ, má có góc may, hay chưa ai hỏi má thì má ở lại.
			var stay := int(s.get("scores", {}).get("maO", 0))
			var honest: bool = s.flags.get("maConNoiThat", false)
			var d := "o_lai"
			if stay < 0 or (not honest and stay < 2) or (not honest and hidden_marks(31) >= int(cfg.chapter2.distantMarks)):
				d = "di_im"
			elif s.flags.get("daMo", false) and not s.flags.get("sapCoMa", false) and s.flags.get("maDuocHoi", false):
				d = "di_xa"
			s["ma"] = {"decision": d}
			s.flags["maOLai"] = d == "o_lai"
			s.flags["maDiXa"] = d == "di_xa"
			s.flags["maDiIm"] = d == "di_im"
			s.queue.push_front({"id": "ma_quyet", "data": {}})
		"linh_decides":
			# Linh tự quyết theo mong muốn của em. Thái độ của An chỉ đổi cách em báo tin.
			if s.flags.get("linhLoHoSo", false) and not s.flags.get("diCungLinh", false):
				s.linh["wish"] = "hoan"
			s.linh["decision"] = s.linh.wish
			s.linh["contact"] = "lanh" if count_family("LINH", "pressure") >= 2 else "binh_thuong"
			s.queue.push_front({"id": "linh_quyet", "data": {}})
		_:
			push_warning("Hiệu ứng đặc biệt không rõ: " + name)


## Chọn tuyến nghề ở ngày 11. Tuyến B, C nhận hợp đồng Bến Cạn: các khoản thu, chi, lời hứa trong cfg.contracts.
func _set_route(r: String) -> void:
	s["route"] = r
	add_log("Chọn tuyến " + {"A": "A · làm công", "B": "B · tổ đội", "C": "C · dịch vụ riêng"}.get(r, r), "event")
	var c: Dictionary = cfg.get("contracts", {}).get(r, {})
	if c.is_empty():
		return
	for x in c.get("receivables", []):
		_add_receivable(x)
	for x in c.get("payables", []):
		_add_payable(x)
	for x in c.get("promises", []):
		_add_promise(x)
	s["progress_need"] = int(s.progress) + int(c.progressNeed)


## Vào ở chỗ k: trả phần còn thiếu. owed: ở tạm nhà dì Năm chưa đủ tiền thì ghi khoản góp sau.
func _take_housing(k: String, owed: bool) -> void:
	var h := housing()
	var cost := housing_cost(k)
	var name := str(cfg.housing[k].name)
	if owed and int(s.cash) < cost:
		_add_payable({"id": "gop_di_nam", "to": "", "label": "Góp tiền ở nhờ nhà dì Năm", "amount": cost, "due": 33})
	else:
		spend(cost, "Vào ở: " + name)
	h["state"] = "signed"
	h["place"] = k
	h["paid"] = int(cfg.housing[k].cost)
	add_log("Chốt chỗ ở: " + name, "event")


## Đặt cọc giữ chỗ k: tiền cọc không còn là tiền tiêu được, chưa phải đã vào ở được.
func _reserve_housing(k: String) -> void:
	var h := housing()
	var dep := int(cfg.housing[k].get("deposit", 0))
	spend(dep, "Đặt cọc giữ chỗ: " + str(cfg.housing[k].name))
	h["state"] = "reserved"
	h["place"] = k
	h["paid"] = dep


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
		elif key == "to_day":
			if day() > int(v):
				fail = "Chỉ tới ngày %d" % int(v)
		elif key == "linh_decided":
			if (s.linh.decision != "") != bool(v):
				fail = "-"
		elif key == "linh_decision":
			if not (s.linh.decision in v if v is Array else s.linh.decision == v):
				fail = "-"
		elif key == "rep_lt":
			# Ngược với rep.X: chỉ thỏa khi độ thân thiết còn dưới mức (đoạn chuyện cho quan hệ chưa tốt).
			for k in v:
				if int(s.rep.get(k, 0)) >= int(v[k]):
					fail = "-"
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
		elif key == "mode":
			if s.get("mode", "slice") != v:
				fail = "-"
		elif key == "afford_housing":
			if int(s.cash) < housing_cost(v):
				fail = "Cần %s tiền mặt (đang có %s)" % [fmt_money(housing_cost(v)), fmt_money(int(s.cash))]
		elif key == "housing_state":
			var hs: String = housing().state
			if not (hs in v if v is Array else hs == v):
				fail = "-"
		elif key == "long_home":
			if has_long_home() != bool(v):
				fail = "-"
		elif key == "housing_seen":
			if not housing().seen.has(v):
				fail = "Chưa đi xem chỗ này"
		elif key == "receivable_pending":
			var r = _find(s.receivables, str(v))
			if r == null or r.status != "pending":
				fail = "-"
		elif key == "fatigue_min":
			if float(s.fatigue) < float(v):
				fail = "-"
		elif key == "fatigue_max":
			if float(s.fatigue) > float(v):
				fail = "Đang quá mệt"
		elif key == "quest_done":
			if quest_state(str(v)) != "done":
				fail = "-"
		elif key == "quest_failed":
			if quest_state(str(v)) != "failed":
				fail = "-"
		elif key == "broken":
			if has_broken() != bool(v):
				fail = "Không có lời hứa nào cần sửa" if bool(v) else "-"
		elif key == "hidden_min":
			if hidden_marks() < int(v):
				fail = "-"
		elif key == "flag_any":
			var any := false
			for f in v:
				if s.flags.get(f, false):
					any = true
			if not any:
				fail = "-"
		elif key == "support_min":
			if count_family(str(v.who), "support") < int(v.n):
				fail = "-"
		elif key.begins_with("score."):
			if int(s.get("scores", {}).get(key.substr(6), 0)) < int(v):
				fail = "-"
		elif key == "score_lt":
			for k in v:
				if int(s.get("scores", {}).get(k, 0)) >= int(v[k]):
					fail = "-"
		elif key == "cash_max":
			if int(s.cash) > int(v):
				fail = "-"
		elif key == "chapter":
			if chapter() != int(v):
				fail = "-"
		elif key == "home":
			var place: String = str(s.get("home2", {}).get("place", housing().place))
			if not (place in v if v is Array else place == v):
				fail = "-"
		elif key == "weekend":
			if (day() % 7 in [0, 6]) != bool(v):
				fail = "Chỉ thứ Bảy, Chủ Nhật" if bool(v) else "-"
		elif key == "can_pay":
			var x = _find(s.payables, str(v))
			if x == null or x.status != "pending":
				fail = "-"
			elif int(s.cash) < int(x.amount):
				fail = "Cần %s tiền mặt (đang có %s)" % [fmt_money(int(x.amount)), fmt_money(int(s.cash))]
		elif key == "count_min":
			# Số lần đã làm một việc (nhỏ thuốc cho bà…), ví dụ {"nho_thuoc": 6}.
			for k in v:
				if count(k) < int(v[k]):
					fail = "-"
		elif key == "linh_away":
			# Linh đi thực tập xa: chỉ có ở nhà ngày thứ Bảy, Chủ Nhật.
			var away: bool = s.linh.decision == "xa" and not (day() % 7 in [0, 6])
			if away != bool(v):
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
	if a.has("showIfFlag") and not s.flags.get(a.showIfFlag, false):
		return true
	if a.has("showIf") and check(a.showIf) != "":
		return true
	if a.has("hideIfFlag") and s.flags.get(a.hideIfFlag, false):
		return true
	if a.get("noRain", false) and s.today.get("rain", false):
		return true
	if a.get("onlyRain", false) and not s.today.get("rain", false):
		return true
	# Việc phụ còn chờ một lựa chọn trước đó thì giấu luôn, khỏi hiện thẻ khóa "Chưa mở".
	if a.get("group", "") == "optional" and a.has("require"):
		for k in a.require:
			if str(k).begins_with("flag.") and check({k: a.require[k]}) != "":
				return true
	if a.get("showIfSeenAny", false) and housing().seen.is_empty():
		return true
	if a.has("hideIfSeen") and housing().seen.has(str(a.hideIfSeen)):
		return true
	if a.has("showIfPromise"):
		var p = _find(s.promises, str(a.showIfPromise))
		if p == null or p.status != "open":
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
		if action_loc(a) == location and not is_hidden(a):
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
			var latest := limit - float(a.hours)
			if clock() > latest and latest >= float(a.window[0]):
				return {"ok": false, "reason": "Trễ rồi: phải bắt đầu trước %s mới xong trong khung %s–%s" % [hh(latest), hh(a.window[0]), hh(a.window[1])]}
			return {"ok": false, "reason": "Chỉ trong khung %s–%s" % [hh(a.window[0]), hh(a.window[1])]}
		return {"ok": false, "reason": "Không đủ giờ hôm nay"}
	return {"ok": true, "reason": "", "start": start}


## result: kết quả trò chơi nhỏ khi tự làm {"ratio": 0..1 phần chỉ tiêu, "bonus": tiền thưởng, "auto": làm tự động}.
## Không truyền thì tính đủ công (mô phỏng, bảng cân bằng).
func do_action(id: String, result: Dictionary = {}) -> void:
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
	var pay := int(a.get("pay", 0))
	if a.has("rainPay") and s.today.get("rain", false):
		pay = int(a.rainPay)
	if not result.is_empty():
		pay = round_k(float(pay) * float(result.get("ratio", 1.0))) + int(result.get("bonus", 0))
		if not bool(result.get("auto", false)):
			s.job_last[id] = {"ratio": float(result.get("ratio", 1.0)), "bonus": int(result.get("bonus", 0))}
	if a.group == "work" and pay > 0 and pay_mult() < 1.0:
		pay = round_k(float(pay) * pay_mult())
		add_log("Phong độ kém, chỉ được %d%% tiền công" % int(pay_mult() * 100.0), "warn")
	for k in a.get("dirty", {}):
		need_adj(k, float(a.dirty[k]))
	if pay > 0:
		earn(pay, label)
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
	_quest_on_action(id, result)
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
	add_fatigue(float(cfg.fatigue.sleepOutside))
	add_log("Không kịp về xóm trọ, ngủ gục ngoài đường.", "warn")
	finish_day()
	if not is_over():
		s.queue.push_front({"id": "ngu_gat", "data": {}})
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
	if id.begins_with("missed:"):
		var base := _merge_variants(find_event(id.substr(7)))
		if base.is_empty():
			return {}
		return {"id": id, "eyebrow": "Hôm qua An không tới", "title": base.title, "who": base.get("who", ""),
			"text": base.get("missed", "Việc hôm qua đã có người khác lo."),
			"choices": base.get("missed_choices", [{"label": "Tiếp tục", "effects": base.get("missed_effects", {})}])}
	for npc in talks:
		for b in talks[npc].get("story", []):
			if b.id == id:
				var e: Dictionary = b.duplicate()
				e["who"] = rep_name(npc)
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
	var e := _merge_variants(base)
	if not e.has("choices"):
		e["choices"] = [{"label": "Tiếp tục"}]
	# Lựa chọn có showIf chỉ hiện khi thỏa (ví dụ món đồ An đã giữ được trong tháng).
	var shown := []
	for c in e.choices:
		if check(c.get("showIf", {})) == "":
			shown.append(c)
	e["choices"] = shown
	if not e.has("eyebrow"):
		e["eyebrow"] = "Ngày %d · %s" % [day(), weekday_name()]
	return e


## Sự kiện đã gộp biến thể đầu tiên thỏa điều kiện.
func _merge_variants(base: Dictionary) -> Dictionary:
	var e := base.duplicate()
	for variant in base.get("variants", []):
		if check(variant.get("when", {})) == "":
			for k in variant:
				if k != "when":
					e[k] = variant[k]
			break
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
	if s.get("end_now", false):
		s.erase("end_now")
		s["queue"] = []
		finish_day()
		return
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
		"npc": str(_event_data.get("npc", "")),
		"line": str(_event_data.get("line", "")),
		"chat_rep": str(int(cfg.get("chatRep", 2))),
		"cash": fmt_money(int(s.get("cash", 0))),
		"cost_hem_dua": fmt_money(housing_cost("hem_dua")) if is_started() else "",
		"cost_cau_tre": fmt_money(housing_cost("cau_tre")) if is_started() else "",
		"rent": fmt_money(_rent_due()),
	}
	for k in vals:
		text = text.replace("{" + k + "}", vals[k])
	return text


## Tiền sinh hoạt mỗi tối; chương 2 nhà đông hơn (má về) và giá chợ mùa mưa lên.
func living_cost() -> int:
	if chapter() == 2:
		return int(cfg.get("chapter2", {}).get("livingCostPerDay", cfg.livingCostPerDay))
	return int(cfg.livingCostPerDay)


## Tiền nhà chương 2 còn phải đóng tối ngày 60: tiền nhà tháng sau, hay phần còn lại của phòng đã đặt cọc.
func _rent_due() -> int:
	for id in ["tien_nha_t2", "phong_moi"]:
		var x = _find(s.get("payables", []), id)
		if x != null and x.status == "pending":
			return int(x.amount)
	return 0


## Sự kiện cố định của ngày d. Sự kiện có "loc" là cảnh chính ở một địa điểm: không bật lên buổi sáng
## mà chờ An tới nơi (thẻ ★ ở địa điểm, dấu trên phố); bỏ lỡ thì sáng hôm sau có tin "Hôm qua An không tới".
func _events_for_day(d: int) -> Array:
	var out := []
	for e in events:
		if e.get("system", false):
			continue
		var on: bool = e.has("day") and int(e.day) == d
		if not on or (e.has("mode") and e.mode != s.get("mode", "slice")):
			continue
		if e.has("loc"):
			s.scenes.append(str(e.id))
		elif check(e.get("when", {})) == "":
			out.append({"id": e.id, "data": {}})
	return out


func _morning() -> void:
	if not s.has("scenes"):
		s["scenes"] = []
		s["scenes_done"] = []
		s["missed"] = []
	s["scenes"] = []
	for id in s.missed:
		s.queue.append({"id": "missed:" + str(id), "data": {}})
	s["missed"] = []
	if is_full():
		for d in cfg.get("rainDays", []):
			if int(d) == day():
				s.today["rain"] = true
		# Hợp đồng Bến Cạn chỉ giữ tới hết ngày 12: chưa chọn tuyến thì đi theo đường làm công.
		if s.route == "" and day() >= 13:
			_set_route("A")
	s.queue.append_array(_events_for_day(day()))


## Cảnh chính hôm nay còn chờ (đã thỏa điều kiện, chưa xem).
func scenes_today() -> Array:
	var out := []
	for id in s.get("scenes", []):
		if not s.scenes_done.has(id) and check(find_event(id).get("when", {})) == "":
			out.append(id)
	return out


## Cảnh chính đã gộp biến thể (tên, địa điểm, khung giờ có thể đổi theo tuyến); "home" là chỗ ở hiện tại.
func scene_info(id: String) -> Dictionary:
	var e := _merge_variants(find_event(id))
	if e.has("loc"):
		e["loc"] = loc_of(str(e.loc))
	return e


func scene_cards_at(loc: String) -> Array:
	var out := []
	for id in scenes_today():
		if str(scene_info(id).loc) == loc:
			out.append(id)
	return out


func scene_lock(id: String) -> String:
	if not is_started() or is_over() or not s.queue.is_empty():
		return "-"
	var e := scene_info(id)
	# Tới sớm thì vẫn vào được: An ngồi chờ tới giờ (như các việc có khung giờ). Quá giờ thì lỡ.
	if e.has("window") and clock() > float(e.window[1]):
		return "Đã quá khung %s–%s" % [hh(float(e.window[0])), hh(float(e.window[1]))]
	if hours_left() < float(e.get("hours", 0.5)) + maxf(0.0, scene_wait(id)):
		return "Không đủ giờ hôm nay"
	return ""


## Số giờ phải ngồi chờ trước khi cảnh bắt đầu (0 nếu đã tới giờ).
func scene_wait(id: String) -> float:
	var e := scene_info(id)
	if e.has("window"):
		return maxf(0.0, float(e.window[0]) - clock())
	return 0.0


## Tới nơi và mở cảnh chính: tốn một chút thời gian, rồi hiện hộp thoại lựa chọn.
func open_scene(id: String) -> void:
	if scene_lock(id) != "":
		return
	s.scenes_done.append(id)
	s["used"] = float(s.used) + scene_wait(id) + float(scene_info(id).get("hours", 0.5))
	s.queue.append({"id": id, "data": {}})
	_commit()


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
		"living": living_cost(), "free_hours": hours_left(),
		"recover": -(float(cfg.fatigue.sleep) + hours_left() * float(cfg.fatigue.freeHour)),
		"due_pay": due_pay, "due_recv": due_recv,
		"slice_end": day() >= last_day(),
	}


func finish_day() -> void:
	if not is_started() or is_over() or not s.queue.is_empty():
		return
	var tonight := []
	if not delivery_active().is_empty():
		add_log("Hết ngày, đơn giao hàng đang chạy bị hủy", "warn")
		s.erase("delivery")
	_tick_needs()
	if has_needs():
		for k in cfg.needs.overnight:
			need_adj(k, float(cfg.needs.overnight[k]))
		s["needs_t"] = float(cfg.dayStart)
	spend(living_cost(), "Sinh hoạt cả nhà")

	# Mệt: đếm ngày ở mức cảnh báo và những lần bỏ qua cơ hội nghỉ, rồi hồi qua đêm.
	# Mệt cuối ngày dùng cho kết E6; sáng ngày 30 kết thúc ngay nên giữ số của tối ngày 29.
	if not (is_full() and day() >= last_day()):
		s["fatigue_end"] = float(s.fatigue)
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
				_contract_phase2()

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
			apply_effects(p.get("onOverdue", {}))

	s.history.append({
		"day": day(), "cash": int(s.cash), "fatigue": float(s.fatigue),
		"proj26": projected_cash(int(cfg.housingDeadline)), "actions": s.today.list.duplicate(),
	})

	# Cảnh chính chưa tới thì sáng mai có tin kể lại (không tự hoàn thành thay người chơi).
	for id in s.get("scenes", []):
		if not s.scenes_done.has(id) and check(find_event(id).get("when", {})) == "" and find_event(id).has("missed"):
			s.missed.append(id)
			add_diary("Không kịp tới cảnh «%s». Ngày trôi qua mà chuyện đó vẫn còn đó." % fill(str(scene_info(id).title)))

	if day() >= last_day():
		s["queue"] = tonight
		if is_full() and chapter() == 2:
			_end_chapter2()
		elif is_full():
			_end_full()
		else:
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


## Sau nghiệm thu giữa kỳ (chơi đủ 30 ngày): giai đoạn cuối cần thêm buổi làm, bàn giao trước ngày 27.
func _contract_phase2() -> void:
	if not is_full():
		return
	var c: Dictionary = cfg.get("contracts", {}).get(s.route, {})
	if c.is_empty() or s.flags.get("thuHep", false):
		return
	s["progress_need"] = int(s.progress_need) + int(c.phase2Need)
	_add_promise({"id": "ban_giao_cuoi", "text": "Bàn giao giai đoạn cuối cho dãy Bến Cạn", "to": "PHUC", "due": 27, "doneIf": "progress_ready"})
	add_log("Giai đoạn cuối: cần thêm %d buổi làm, bàn giao trước tối ngày 27" % int(c.phase2Need), "event")


## Hết ngày 30: chưa có chỗ nào thì cả nhà sang chỗ tạm đã gieo từ ngày 3, rồi chọn kết thúc.
func _end_full() -> void:
	var h := housing()
	if h.state != "signed":
		var where := "di_nam"
		add_log("Chưa chốt được phòng: cả nhà sang ở nhờ nhà dì Năm như đã hỏi từ trước", "warn")
		_take_housing(where, true)
		s.flags["tamTuDong"] = true
	var key := ending_key()
	s["over"] = {"kind": "full", "key": key, "linh": linh_card(), "ba_tu": ba_tu_card(), "npc": npc_card()}
	add_log("Kết thúc: " + str(story.endings[key].title), "event")


## Chơi tiếp chương 2 từ màn kết chương 1: giữ chỗ ở, tuyến nghề, tiền, độ thân thiết, cờ, sổ tay; đếm Mệt
## lại từ đầu cho kết chương 2; thêm tiền nhà tháng sau (hạn tối ngày 60) và độ thân thiết của nhân vật mới.
func start_chapter2() -> void:
	if not can_continue():
		return
	var c2: Dictionary = cfg.get("chapter2", {})
	s["ch1"] = {"key": str(s.over.get("key", "")), "warn_days": int(s.warn_days), "rest_skips": int(s.rest_skips), "cash": int(s.cash)}
	var place := str(housing().place)
	s["home2"] = {"place": place, "loc": str(cfg.housing[place].loc) if cfg.housing.has(place) else "xom_bo_me"}
	s["chapter"] = 2
	s["over"] = {}
	s["day"] = int(c2.get("startDay", 31))
	s["used"] = 0.0
	s["warn_days"] = 0
	s["rest_skips"] = 0
	s.erase("fatigue_end")
	s["yesterday"] = s.today
	s["today"] = {"list": []}
	s["missed"] = []
	for k in c2.get("rep", {}):
		if not s.rep.has(k):
			s.rep[k] = int(c2.rep[k])
	if has_long_home():
		_special("rent_next")
		var util := int(c2.get("utilities", 0))
		if util > 0:
			_add_payable({"id": "dien_nuoc_t1", "to": "", "label": "Điện nước tháng đầu ở chỗ mới", "amount": util, "due": int(c2.get("utilitiesDue", 45))})
	if has_needs():
		s["needs_t"] = float(cfg.dayStart)
	add_log("Chương 2 · Mùa mưa", "event")
	s["queue"] = [{"id": "c2_mo_dau", "data": {}}]
	_morning()
	_commit()


## Hết ngày 60: chọn kết chương 2 và các thẻ hậu truyện.
func _end_chapter2() -> void:
	var key := ending2_key()
	s["over"] = {"kind": "full2", "key": key, "ma": ma_card(), "ba_tu": ba_tu_card2(), "linh": linh_card2()}
	add_log("Kết chương 2: " + str(story2.endings[key].title), "event")


## Thứ tự xét K6 → K5 → K4 → K3 → K2 → K1 (cfg.endings dùng chung ngưỡng Mệt với chương 1).
## K5 đi theo quyết định của má ở ngày 58 (ma_decides đã tính chuyện giấu, ép người nhà).
func ending2_key() -> String:
	var f: Dictionary = s.flags
	var e: Dictionary = cfg.endings
	if int(s.warn_days) >= int(e.exhaustWarnDays) and int(s.rest_skips) >= int(e.exhaustSkips) \
			and float(s.get("fatigue_end", s.fatigue)) >= float(e.exhaustFatigue):
		return "K6"
	if f.get("maDiIm", false):
		return "K5"
	# Ở nhờ dì Năm mà đã đặt cọc phòng mới và trả đủ phần còn lại trước tối ngày 60 thì coi như có chỗ thuê lâu dài.
	var rent = _find(s.payables, "tien_nha_t2")
	var next_room = _find(s.payables, "phong_moi")
	var moving: bool = housing().state == "reserved" and next_room != null and next_room.status == "paid"
	if not (has_long_home() or moving) or (rent != null and rent.status in ["unpaid", "renegotiated"]):
		return "K4"
	if f.get("maOLai", false) and f.get("sapCoMa", false):
		return "K3"
	if f.get("maDiXa", false):
		return "K2"
	return "K1"


## Thẻ của má ở kết chương 2: ở lại, đi xa có hẹn gọi về, hay đi mà không ai tiễn.
func ma_card() -> String:
	return str(s.get("ma", {}).get("decision", "chua"))


## Thẻ của bà ở kết chương 2 theo chuyện đôi mắt: đã mổ, chọn chờ, hay chưa ai hỏi bà.
func ba_tu_card2() -> String:
	if s.flags.get("daMo", false):
		return "nhin_ro"
	if s.flags.get("moDoi", false):
		return "cho_tet"
	return "chua_hoi"


func linh_card2() -> String:
	if s.flags.get("linhBiEp", false):
		return "bi_ep"
	if s.flags.get("linhKyDung", false):
		return "ky_dung"
	return "tu_di"


## Thứ tự xét E8 → E6 → E7 → E5 → E4 → E2 → E3 → E1, dừng ở điều kiện đầu tiên đúng.
func ending_key() -> String:
	var f: Dictionary = s.flags
	var e: Dictionary = cfg.endings
	if f.get("falseCompletion", false) and not f.get("suaSai", false):
		return "E8"
	if int(s.warn_days) >= int(e.exhaustWarnDays) and int(s.rest_skips) >= int(e.exhaustSkips) \
			and float(s.get("fatigue_end", s.fatigue)) >= float(e.exhaustFatigue):
		return "E6"
	if not has_long_home():
		return "E7"
	if hidden_marks() >= int(e.distantMarks) and (f.get("giauNgay25", false) or count_family("LINH", "pressure") >= 2) \
			and not f.get("suaSaiGiaDinh", false):
		return "E5"
	var unpaid := 0
	for x in s.payables:
		if x.status == "unpaid" or x.status == "renegotiated":
			unpaid += 1
	# Thu hẹp gọn ở ngày 20 không tính; E4 là khi còn phần dở hay khoản trả lại phải hẹn lịch.
	if f.get("thuHepCuoi", false) or unpaid > 0:
		return "E4"
	if s.route == "B":
		return "E2"
	if s.route == "C" and int(s.cash) >= int(e.ownTableCash):
		return "E3"
	return "E1"


# ---------------------------------------------------------------- sổ tay, đồ mang theo

## Một dòng trong sổ tay của An: điều đã chọn hôm nay, kể lại bằng giọng của anh.
func add_diary(text: String) -> void:
	if text == "":
		return
	if not s.has("diary"):
		s["diary"] = []
	s.diary.append({"day": day(), "text": text})


func diary_of(d: int) -> Array:
	var out := []
	for x in s.get("diary", []):
		if int(x.day) == d:
			out.append(str(x.text))
	return out


## Lời hé lộ cho ngày d: chuỗi, hoặc mảng {when, text} lấy dòng đầu tiên thỏa.
func teaser(d: int) -> String:
	var t = story.get("teasers", {}).get(str(d), "")
	if t is Array:
		for x in t:
			if check(x.get("when", {})) == "":
				return fill(str(x.text))
		return ""
	return fill(str(t))


## Những món An giữ được trong tháng (mỗi món gắn với một việc đã làm).
func keepsakes() -> Array:
	var out := []
	for k in (story2 if chapter() == 2 else story).get("keepsakes", []):
		if check(k.get("when", {})) == "":
			out.append(k)
	return out


## Đoạn kết cho từng người ở xóm và ở phố, không chỉ một người nổi bật nhất.
func npc_lines() -> Array:
	var out := []
	var cards: Dictionary = (story2 if chapter() == 2 else story).get("npcCards", {})
	for k in cards:
		var card: Dictionary = cards[k]
		var good: bool = int(s.rep.get(k, 50)) >= 50
		if k == "TRAM" and s.flags.get("falseCompletion", false):
			good = false
		var text := str(card.good if good else card.bad)
		for x in card.get("extra", []):
			if check(x.get("when", {})) == "":
				text += " " + str(x.text)
				break
		out.append({"who": k, "good": good, "text": text})
	return out


## Những dòng "sau đó" của các mạch riêng (cánh tủ, cuộc gọi cho má…), dòng nào thỏa thì hiện.
func codas() -> Array:
	var out := []
	for x in (story2 if chapter() == 2 else story).get("codas", []):
		if check(x.get("when", {})) == "":
			out.append(fill(str(x.text)))
	return out


func linh_card() -> String:
	if s.linh.contact == "lanh":
		return "lanh"
	if s.linh.decision != "":
		return str(s.linh.decision)
	return "chua"


func ba_tu_card() -> String:
	var joined: bool = s.flags.get("baTuThuDuong", false) or s.flags.get("baTuChonUuTien", false) \
		or count_family("BA_TU", "support") >= 2
	var promise = _find(s.promises, "dua_ba_di_cho")
	if not has_long_home():
		return "ro_nhua" if joined else "lo"
	if promise != null and promise.status == "overdue":
		return "lo"
	if joined:
		return "tot"
	if promise != null:
		return "hua"
	return "lo"


## Thẻ quan hệ nghề nổi bật nhất: người có độ thân thiết lệch xa mức 50 nhất.
func npc_card() -> Dictionary:
	var best := ""
	var gap := -1
	for k in story.get("npcCards", {}):
		var d := absi(int(s.rep.get(k, 50)) - 50)
		if d > gap:
			gap = d
			best = k
	if best == "":
		return {}
	var good: bool = int(s.rep.get(best, 50)) >= 50
	if best == "TRAM" and s.flags.get("falseCompletion", false):
		good = false
	return {"who": best, "good": good}


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
	_tick_needs()
	_check_quests()
	changed.emit()


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
func delivery_offer(shop: String, shop_name: String, dest: String, dest_x: float, meters: float, dest_z := 0.0) -> Dictionary:
	var d: Dictionary = cfg.delivery
	var walk_h := meters * float(cfg.get("walkHoursPerMeter", 0.004))
	return {
		"shop": shop, "shop_name": shop_name, "item": str(d.shops[shop]), "dest": dest, "dest_x": dest_x, "dest_z": dest_z,
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
		add_fatigue(float(d.lateFatigue))
	elif (float(o.deadline) - clock()) / maxf(0.01, float(o.deadline) - float(o.given)) >= float(d.tipIfLeft):
		tip = round_k(randf_range(float(d.tip[0]), float(d.tip[1])))
	add_fatigue(float(d.fatigue))
	earn(pay + tip, "Giao %s tới %s%s" % [o.item, o.dest, " (trễ)" if late else (" · tip %s" % fmt_k(tip) if tip > 0 else "")])
	s.counts["giao_hang"] = count("giao_hang") + 1
	s.today["giao_hang"] = today_count("giao_hang") + 1
	s.erase("delivery")
	_commit()
	return {"pay": pay, "tip": tip, "late": late}


func delivery_cancel() -> void:
	if delivery_active().is_empty():
		return
	add_fatigue(float(cfg.delivery.cancelFatigue))
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
	var who := rep_name(npc)
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

# ---------------------------------------------------------------- nhu cầu cơ thể

func has_needs() -> bool:
	return s.has("needs")


func need(k: String) -> float:
	return float(s.needs.get(k, 100.0)) if has_needs() else 100.0


func need_adj(k: String, d: float) -> void:
	if has_needs():
		s.needs[k] = clampf(float(s.needs.get(k, 0.0)) + d, 0.0, 100.0)


## Đói, bẩn dần theo giờ đã trôi; nhịn tới 0 thì Mệt tăng nhanh.
func _tick_needs() -> void:
	if not has_needs() or not is_started():
		return
	var dt := clock() - float(s.get("needs_t", cfg.dayStart))
	if dt <= 0.0:
		return
	s["needs_t"] = clock()
	var starving := need("fed") <= 0.0
	for k in cfg.needs.perHour:
		need_adj(k, float(cfg.needs.perHour[k]) * dt)
	if starving or need("fed") <= 0.0:
		add_fatigue(float(cfg.needs.starveFatiguePerHour) * dt)


## Phong độ 0..100 gộp từ no bụng, vệ sinh, quần áo và độ tỉnh táo (100 − Mệt), kiểu "Cool" của Nobody.
func phong_do() -> float:
	if not has_needs():
		return 100.0
	var w: Dictionary = cfg.needs.weights
	var rested := 100.0 - float(s.fatigue)
	return need("fed") * float(w.fed) + need("clean") * float(w.clean) + need("neat") * float(w.neat) + rested * float(w.rested)


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
	if not q.get("offer", true):
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
		var giver := loc_of(str(q.giver))
		if (loc == "" or giver == loc) and quest_offerable(q):
			var qq: Dictionary = q.duplicate()
			qq["giver"] = giver
			out.append(qq)
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
	var step: Dictionary = quest_def(id).steps[int(s.quests[id].step)]
	if str(step.get("loc", "")) == "home":
		step = step.duplicate()
		step["loc"] = home_loc()
	return step


## Chỗ cần tới của bước hiện tại: {"loc": id địa điểm} hoặc {"x": [từ, tới]} với bước lục thùng rác.
func quest_target(id: String) -> Dictionary:
	var step := quest_step(id)
	match str(step.get("kind", "")):
		"visit":
			return {"loc": str(step.loc)}
		"action":
			return {"loc": action_loc(get_action(str(step.action)))}
		"find":
			return {"area": step.area}
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
	# Tới sớm thì ngồi chờ tới giờ như cảnh chính; quá giờ thì lỡ.
	if step.has("window") and clock() > float(step.window[1]):
		return "Đã quá khung %s–%s" % [hh(float(step.window[0])), hh(float(step.window[1]))]
	for k in step.get("need_items", {}):
		var need := int(step.need_items[k])
		if item_count(k) < need:
			if need == 1:
				return "Chưa có: " + item_name(k).to_lower()
			return "Cần %d %s (đang có %d)" % [need, item_name(k), item_count(k)]
	if hours_left() < float(step.get("hours", 0.0)) + quest_step_wait(id):
		return "Không đủ giờ"
	return ""


## Số giờ phải chờ trước khi làm được bước tới-nơi của việc nhờ id.
func quest_step_wait(id: String) -> float:
	var step := quest_step(id)
	if step.has("window"):
		return maxf(0.0, float(step.window[0]) - clock())
	return 0.0


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
	s["used"] = float(s.used) + quest_step_wait(id) + float(step.get("hours", 0.0))
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


## over: ghi đè hạn khi việc nhờ được mở từ một lựa chọn trong cảnh chính, ví dụ {"deadline_hour": 12}.
func quest_accept(id: String, over: Dictionary = {}) -> void:
	var q := quest_def(id).duplicate()
	for k in ["deadline_days", "deadline_hour"]:
		if over.has(k):
			q[k] = over[k]
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


## Vùng tìm đồ của bước "find": [x0, z0, x1, z1] trên bản đồ phường.
func in_area(area: Array, x: float, z: float) -> bool:
	return x >= float(area[0]) and x <= float(area[2]) and z >= float(area[1]) and z <= float(area[3])


## Lục thùng rác đúng vùng của bước "find": có xác suất ra đồ, xui ba lần liền thì lần sau chắc chắn ra.
func _quest_on_scavenge(x: float, z := INF) -> String:
	for id in quests_active():
		var step := quest_step(id)
		if step.get("kind", "") != "find" or not in_area(step.area, x, z):
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
## x, z: vị trí thùng trên bản đồ, để việc nhờ kiểu "tìm trong thùng rác quanh chợ" biết thùng nào nằm trong vùng.
func scavenge(bin_id: String, x := INF, z := INF) -> Dictionary:
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
	add_fatigue(float(c.fatigue))
	add_log("Lục thùng rác: " + (", ".join(parts) if not parts.is_empty() else "không có gì"))
	var found := _quest_on_scavenge(x, z)
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
	var total := int(round(h * 60.0))
	return "%02d:%02d" % [total / 60, total % 60]


static func round_k(x: float) -> int:
	return int(round(x / 10000.0)) * 10000
