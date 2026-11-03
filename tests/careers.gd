extends SceneTree
## Học nghề buổi tối, bằng cấp, việc cần bằng và cây kỹ năng (scripts/systems/careers.gd, data/systems/careers.json).
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/careers.gd
const Logic := preload("res://scripts/game_logic.gd")
const Careers := preload("res://scripts/systems/careers.gd")
const Attributes := preload("res://scripts/systems/attributes.gd")
const MiniGames := preload("res://scripts/minigames/minigames.gd")
var failures := 0
var finished_parts := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
## Ván mới, ngày thường (thứ Hai), đủ tiền, nhu cầu ổn.
func fresh(hour := 10.0, day := 8):
	var g=Logic.new()
	g.load_data(); g.new_game("full")
	for i in 40:
		if g.s.queue.is_empty(): break
		g.resolve_first_available()
	g.s.day=day
	for k in g.s.needs: g.s.needs[k]=80.0
	g.s.fatigue=0.0; g.s.cash=5000000
	clock(g,hour)
	return g
func clock(g, hour: float) -> void:
	g.s.used=hour-6.0; g.s.needs_t=hour; g.s.queue=[]
	g._commit()
func visible(g, id: String) -> bool:
	return not g.is_hidden(g.get_action(id))

func _init() -> void:
	await process_frame
	courses()
	talents()
	check(finished_parts==2,"every part ran to the end")
	print("Careers: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)

func courses() -> void:
	var g=fresh()
	for id in ["ghi_danh_han","hoc_han","thi_han","ghi_danh_ke_toan","on_bai_net","han_khung_sat","bao_duong_dieu_hoa","so_sach_tieu_thuong"]:
		check(not g.get_action(id).is_empty(),"action registered: "+id)
	check(g.s.has("courses") and g.s.has("talents") and g.s.certs.is_empty(),"new game has empty career state")

	# Ghi danh: cần Thể chất 2, trả học phí, rồi mới thấy việc đi học.
	check(visible(g,"ghi_danh_han") and not visible(g,"hoc_han") and not visible(g,"thi_han"),"only enrolment shows before joining")
	check("Thể chất" in str(g.action_status(g.get_action("ghi_danh_han")).reason),"enrolment needs strength 2")
	check("Cần Chứng chỉ thợ hàn" == str(g.action_status(g.get_action("han_khung_sat")).reason),"welding job needs the certificate")
	g.s.attr.str.lv=2
	g.do_action("ghi_danh_han")
	check(g.s.cash==5000000-1800000 and str(g.s.courses.han.state)=="studying","enrolment charges the fee")
	check(not visible(g,"ghi_danh_han") and visible(g,"hoc_han") and visible(g,"on_bai_net"),"studying shows class and review")

	# Buổi học tối ngày thường: tiến độ theo Trí tuệ, cộng EXP, mỗi ngày một buổi; cuối tuần không có lớp.
	clock(g,18.0)
	var str_xp: float=Attributes.xp(g,"str")
	g.do_action("hoc_han")
	var per_session: float=14.0*(1.0+0.12)
	check(is_equal_approx(float(g.s.courses.han.progress),per_session),"session progress scales with intelligence (%s)" % g.s.courses.han.progress)
	check(Attributes.xp(g,"str")>str_xp,"class trains strength")
	check(not g.action_status(g.get_action("hoc_han")).ok,"one class per day")
	g=fresh(18.0,13); g.s.attr.str.lv=2; g.apply_effects({"course_enroll.han":true}); g._commit()
	check("Chỉ thứ Bảy" in str(g.action_status(g.get_action("hoc_han")).reason) or not g.action_status(g.get_action("hoc_han")).ok,"no class at the weekend")

	# Tự ôn ở quán net cộng thêm tiến độ.
	g=fresh(); g.s.attr.str.lv=2; g.do_action("ghi_danh_han")
	g.do_action("on_bai_net")
	check(is_equal_approx(float(g.s.courses.han.progress),5.0*1.12),"review at the net café adds progress")

	# Đủ tiến độ thì thôi đi học, mở việc thi; thi đỗ có bằng, điểm kỹ năng, mở việc cần bằng.
	g.s.courses.han.progress=99.0
	g.apply_effects({"course_study.han":true}); g._commit()
	check(not visible(g,"hoc_han") and visible(g,"thi_han"),"full progress opens the exam")
	var passed := false
	var failed := false
	for d in range(8, 60):
		if passed and failed: break
		g=fresh(10.0,d)
		if d % 7 in [0,6]: continue
		g.s.attr.str.lv=2; g.apply_effects({"course_enroll.han":true}); g.s.courses.han.progress=100.0; g._commit()
		var mood: float=g.need("mood"); var cash: int=g.s.cash
		g.do_action("thi_han")
		check(g.s.cash==cash-200000,"exam fee is charged")
		if Careers.has_cert(g,"han") and not passed:
			passed=true
			check(Careers.points(g)==1 and str(g.s.courses.han.state)=="done","passing grants a talent point")
			check(not visible(g,"thi_han") and not visible(g,"ghi_danh_han"),"certified course is closed")
			check(g.action_status(g.get_action("han_khung_sat")).ok,"certificate opens the welding job")
			var before: int=g.s.cash
			g.do_action("han_khung_sat")
			check(g.s.cash>before+300000 and Careers.xp(g,"han")>=22.0,"welding job pays well and trains the trade")
		elif not Careers.has_cert(g,"han") and not failed:
			failed=true
			check(g.need("mood")<mood and visible(g,"thi_han"),"failing costs mood and allows a retake")
	check(passed and failed,"exams can pass and fail")
	check(is_equal_approx(Careers.pass_chance(fresh(),"han"),0.78),"pass chance follows intelligence")

	# Tay nghề cao thì việc của nghề đó trả thêm.
	g=fresh(); g.apply_effects({"cert.han":true}); g.s.prof.han={"lv":3,"xp":0.0}; g._commit()
	var c0: int=g.s.cash
	g.do_action("han_khung_sat")
	check(g.s.cash==c0+g.round_k(340000.0*1.1),"trade level 3 pays 10%% more (got %d)" % (g.s.cash-c0))

	# Lớp điện lạnh của chương 5 (cờ hocXong) đổi thành bằng, kể cả bản lưu cũ.
	g=fresh(); g.s.flags.hocXong=true; g._commit()
	check(Careers.has_cert(g,"dien_lanh") and g.action_status(g.get_action("bao_duong_dieu_hoa")).ok,"story course grants the AC certificate")
	finished_parts+=1

func talents() -> void:
	var g=fresh()
	check(Careers.points(g)==0 and Careers.talent_lock(g,"khang_chan_thuong")!="","no points at start")
	# Điểm từ lịch sự kiện dùng được; nghề lên cấp thì thêm điểm.
	g.EventScheduler.state(g).skill_points=1
	g.s.attr.str.lv=2
	var risk: float=MiniGames.injury_chance(g,"be_gach",4)
	check(g.learn_talent("khang_chan_thuong") and Careers.points(g)==0,"scheduler points buy a talent")
	check(MiniGames.injury_chance(g,"be_gach",4)<risk*0.5,"injury resistance halves risk or better")
	check(not g.learn_talent("khang_chan_thuong"),"a talent is learnt once")
	Careers.gain(g,"boc_vac",80.0)
	check(Careers.points(g)==1,"trade level-up earns a point")
	check("Thể chất cấp 3" in Careers.talent_lock(g,"lung_thep"),"tier two needs its own requirement")
	g.s.attr.str.lv=3
	check(Careers.talent_lock(g,"lung_thep")=="Cần 2 điểm kỹ năng","tier two costs two points")

	# Mặt dày tiếp thị: tỷ lệ chốt bán hàng ×1,25. Bàn tay khéo léo: thêm giờ trong ca có chỉ tiêu.
	g=fresh(); g.s.talents.earned=5; g.s.attr.per.lv=2; g.s.attr.agi.lv=2
	var close: float=g.Commerce.street_close(g)
	var secs: float=float(MiniGames.view_cfg(g,"be_gach").seconds)
	g.learn_talent("mat_day_tiep_thi"); g.learn_talent("ban_tay_kheo")
	check(is_equal_approx(g.Commerce.street_close(g),minf(0.95,close*1.25)),"sales talent raises close rate")
	check(float(MiniGames.view_cfg(g,"be_gach").seconds)>secs*1.15,"dexterity adds minigame time")
	check(Careers.talent_lock(g,"tho_lanh_nghe")=="Cần một bằng nghề","master needs any certificate")
	g.apply_effects({"cert.ke_toan":true}); g._commit()
	check(g.learn_talent("tho_lanh_nghe"),"any certificate unlocks master")
	var c0: int=g.s.cash
	g.do_action("so_sach_tieu_thuong")
	check(g.s.cash==c0+g.round_k(280000.0*1.15),"master adds 15%% to certificate jobs (got %d)" % (g.s.cash-c0))
	var rows: Array=Careers.talent_rows(g)
	check(rows.size()==6 and rows.filter(func(t): return t.owned).size()==3,"talent rows report ownership")

	# Lưu, nạp.
	var copy=Logic.new(); copy.load_data(); copy.s=JSON.parse_string(JSON.stringify(g.s)); copy.migrate_save()
	check(Careers.owns(copy,"tho_lanh_nghe") and Careers.has_cert(copy,"ke_toan") and Careers.points(copy)==Careers.points(g),"careers survive save/load")
	copy.s.erase("talents"); copy.s.erase("courses"); copy._commit()
	check(copy.s.has("talents") and copy.s.has("courses"),"legacy saves gain career state")
	finished_parts+=1
