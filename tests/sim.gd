extends SceneTree
## Tự chơi lát cắt ngày 18–22 cho cả ba tuyến và hai cách đối xử với gia đình, in bảng kết quả.
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/sim.gd

const GameLogic := preload("res://scripts/game_logic.gd")

## Lựa chọn theo ngày cho từng cách chơi. Bị khóa thì lấy lựa chọn đầu tiên còn mở.
const POLICIES := {
	"lắng nghe": {"ngay18_bc": 0, "ngay18_a": 0, "ngay19": 0, "ngay20_bc": 0, "ngay20_a": 0, "ngay21": 0, "ngay22": 0},
	"giữ tiếp": {"ngay18_bc": 1, "ngay18_a": 1, "ngay19": 1, "ngay20_bc": 1, "ngay20_a": 1, "ngay21": 1, "ngay22": 1},
	"áp đặt": {"ngay18_bc": 2, "ngay18_a": 2, "ngay19": 2, "ngay20_bc": 2, "ngay20_a": 2, "ngay21": 2, "ngay22": 2},
}


func _init() -> void:
	print("Tuyến  Cách chơi   Tiền cuối    Dự kiến ngày 26  Đủ cho        Phải thu sau 30  Mệt  Cảnh báo  Linh       Bà Tư  Lời hứa quá hạn")
	for route in GameLogic.ROUTES:
		for policy in POLICIES:
			var g := GameLogic.new()
			g.load_data()
			_play(g, route, POLICIES[policy])
			var r: Dictionary = g.slice_report()
			var overdue := 0
			for p in r.promises:
				if p.status == "overdue":
					overdue += 1
			print("%-6s %-11s %-12s %-16s %-13s %-16s %-4d %-9d %-10s %-6s %d" % [
				route, policy, GameLogic.fmt_money(r.cash), GameLogic.fmt_money(r.proj_deadline),
				r.housing if r.housing != "" else "-", GameLogic.fmt_money(r.recv_after_30),
				int(r.fatigue), r.warn_days, r.linh_card, r.ba_tu_card, overdue])
	quit()


func _play(g, route: String, picks: Dictionary) -> void:
	g.new_game(route)
	var guard := 0
	while not g.is_over() and guard < 20:
		guard += 1
		_answer(g, picks)
		if g.is_over():
			break
		for id in _plan(g):
			g.do_action(id)
		g.finish_day()
	_answer(g, picks)


func _answer(g, picks: Dictionary) -> void:
	var safety := 0
	while not g.s.queue.is_empty() and safety < 20:
		safety += 1
		var e: Dictionary = g.current_event()
		var before: int = g.s.queue.size()
		g.resolve_choice(int(picks.get(e.id, 0)))
		if g.s.queue.size() == before and g.s.queue[0].id == e.id:
			g.resolve_first_available()


## Một ngày làm việc điển hình của từng tuyến: lo tiến độ hợp đồng trước, rồi kiếm tiền trả ngay, mệt thì nghỉ.
func _plan(g) -> Array:
	var p := []
	if g.fatigue_warn():
		p.append("nghi")
	match str(g.s.route):
		"A":
			p.append_array(["ca_kho", "ca_phu_quan", "sua_do_le"])
		"B":
			if not g.progress_ready():
				p.append("ben_can_b")
			p.append_array(["giao_com", "ca_phu_quan", "sua_do_le"])
		"C":
			if not g.progress_ready():
				p.append("ben_can_c")
			p.append_array(["sua_do_le", "ca_phu_quan"])
	p.append("com_voi_ba")
	return p
