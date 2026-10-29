extends SceneTree
## Khung trò chơi nhỏ (scripts/minigames/minigames.gd), ném vòng cổ chai và bê gạch (scripts/minigames/views/).
## Chạy: Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/minigames.gd
const Logic := preload("res://scripts/game_logic.gd")
const MiniGames := preload("res://scripts/minigames/minigames.gd")
const Survival := preload("res://scripts/systems/survival.gd")
const Careers := preload("res://scripts/systems/careers.gd")
const Attributes := preload("res://scripts/systems/attributes.gd")
## Cảnh nạp lúc chạy (registry kéo theo work_site.gd cần autoload GameState).
var Registry: GDScript
var RingToss: GDScript
var BrickBalance: GDScript
var failures := 0
## Lỗi giữa chừng làm hàm dừng mà không báo; chỉ PASS khi cả hai phần chạy hết.
var finished_parts := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func fresh(hour := 9.0):
	var g=Logic.new()
	g.load_data(); g.new_game("full")
	for i in 40:
		if g.s.queue.is_empty(): break
		g.resolve_first_available()
	for k in g.s.needs: g.s.needs[k]=80.0
	g.s.fatigue=0.0; g.s.cash=1000000
	g.s.used=hour-6.0; g.s.needs_t=hour
	g._commit()
	return g

func _init() -> void:
	await process_frame
	Registry=load("res://scripts/minigames/views/registry.gd")
	RingToss=load("res://scripts/minigames/views/ring_toss_view.gd")
	BrickBalance=load("res://scripts/minigames/views/brick_balance_view.gd")
	logic()
	await views()
	check(finished_parts==2,"every part ran to the end")
	print("Mini-games: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)

func logic() -> void:
	var g=fresh()
	var bg: Dictionary=g.get_action("be_gach"); var nv: Dictionary=g.get_action("nem_vong")
	check(bg.group=="work" and bg.location=="bai_boc_vac" and int(bg.pay)==240000 and bg.tags.has("heavy"),"labor game registers a work action")
	check(nv.group=="life" and int(nv.cost)==20000 and nv.minigame=="nem_vong","leisure game registers a life action")
	check(g.item_name("gau_bong")=="Gấu bông nhỏ","prize names are registered")

	# Số liệu cho cảnh nhân theo thuộc tính; lời giới thiệu có chi phí, thưởng, rủi ro.
	var c1: Dictionary=MiniGames.view_cfg(g,"nem_vong")
	g.s.attr.agi.lv=3
	var c3: Dictionary=MiniGames.view_cfg(g,"nem_vong")
	check(float(c3.sweep)<float(c1.sweep) and c3.view=="ring_toss","agility slows the aiming sweep")
	check(float(MiniGames.view_cfg(g,"be_gach").seconds)>80.0,"agility adds shift time")
	var info: String="\n".join(MiniGames.view_cfg(g,"be_gach").info)
	check("110.000đ" in info and "Rủi ro chấn thương" in info and "tay nghề bốc vác" in info,"intro lists pay, rewards and risk")
	check(MiniGames.view_cfg(g,"bricks").get("kind","bricks")=="bricks" and MiniGames.view_cfg(g,"bricks").has("seconds"),"catalogue-less games keep their old config")
	check(Registry.make({"view":"ring_toss"}).get_script()==RingToss and Registry.make({"kind":"bricks"}).get_script().resource_path.ends_with("work_site.gd"),"registry picks views")

	# Điều kiện vào: tiền, thuộc tính, bằng cấp, khung giờ, trạng thái.
	g=fresh(); g.s.cash=5000
	check(not g.action_status(g.get_action("nem_vong")).ok,"entry fee is required")
	g=fresh(20.5)
	check(g.action_status(g.get_action("nem_vong")).ok and not g.action_status(g.get_action("be_gach")).ok,"time windows apply")
	g=fresh(); g.get_action("be_gach").require={"stat.str":2,"cert":"han"}
	check("Thể chất" in str(g.action_status(g.get_action("be_gach")).reason),"attribute requirement blocks")
	g.s.attr.str.lv=2
	check("Chứng chỉ thợ hàn" in str(g.action_status(g.get_action("be_gach")).reason),"certificate requirement blocks")
	g.apply_effects({"cert.han":true})
	check(g.action_status(g.get_action("be_gach")).ok,"granted certificate opens the job")
	g=fresh(); g.s.needs.fed=10.0; g._commit()
	check(not g.action_status(g.get_action("be_gach")).ok,"weakness blocks brick carrying")

	# Ném vòng: thắng, thắng lớn, thua; trừ phí, giờ, thưởng Tâm trạng và vật phẩm.
	g=fresh(17.0); var mood: float=g.need("mood"); var t0: float=g.clock()
	g.do_action("nem_vong",{"score":0.4,"hits":2,"rings":5,"fails":3})
	check(g.s.cash==980000 and is_equal_approx(g.clock(),t0+0.5),"leisure costs money and time")
	check(g.item_count("moc_khoa_ca")==1 and g.need("mood")>mood+9.0,"a hit gives +10 mood and a prize")
	check(bool(g.last_minigame.win) and "Trúng" in str(g.last_minigame.text),"report carries the outcome")
	g.do_action("nem_vong",{"score":0.6,"hits":3,"rings":5,"fails":2})
	check(g.item_count("gau_bong")==1,"three hits win the big prize")
	g.do_action("nem_vong",{"score":0.0,"hits":0,"rings":5,"fails":5})
	check(not bool(g.last_minigame.win) and g.item_count("moc_khoa_ca")==1,"a miss gives no prize")
	g.do_action("nem_vong",{"score":1.0,"hits":5,"rings":5,"fails":0})
	check(g.today_count("nem_vong")==3 and g.item_count("gau_bong")==1,"daily play limit holds")

	# Bê gạch: tiền công theo phần chỉ tiêu, EXP nghề, EXP Thể chất, tụt mạnh Vệ sinh và Độ no.
	g=fresh(); var cash: int=g.s.cash; var clean: float=g.need("clean"); var fed: float=g.need("fed")
	g.do_action("be_gach",{"score":1.0,"delivered":8,"target":8,"fails":0})
	check(g.s.cash==cash+110000,"full shift pays capped chapter-one wage")
	check(Careers.xp(g,"boc_vac")>=25.0 and Attributes.xp(g,"str")>0.0,"shift trains the trade and strength")
	check(clean-g.need("clean")>=35.0 and fed-g.need("fed")>=20.0,"shift drains hygiene and hunger hard")
	g=fresh(); cash=g.s.cash
	g.do_action("be_gach",{"score":0.5,"fails":2})
	check(g.s.cash==cash+60000 and str(g.last_minigame.text).begins_with("Xong ca"),"half quota pays half of capped base rounded to 10k")
	g=fresh(); cash=g.s.cash
	g.do_action("be_gach",{"score":0.25,"fails":4})
	check(g.s.cash==cash+30000 and not bool(g.last_minigame.win),"missing quota is a loss with partial pay")
	g=fresh(); cash=g.s.cash; g.s.prof={"boc_vac":{"lv":3,"xp":0.0}}
	g.do_action("be_gach",{"score":1.0,"fails":0})
	check(g.s.cash==cash+110000+g.round_k(11000.0),"trade level 3 adds 10%% pay (got %d)" % (g.s.cash-cash))
	g=fresh(); cash=g.s.cash
	g.do_action("be_gach",{"ratio":1.0,"bonus":0,"auto":true})
	check(g.s.cash==cash+110000,"quick repeat keeps the stored pay")
	g=fresh(); cash=g.s.cash
	g.do_action("ca_kho",{"ratio":1.0,"bonus":0})
	check(g.last_minigame.is_empty() and g.s.cash==cash+200000,"old minigame settlement obeys current economy base wage")

	# Chấn thương: xác suất theo lần hỏng, Mệt, Thể chất; trúng thì bật trạng thái, trả viện phí, chặn việc nặng.
	g=fresh()
	check(is_equal_approx(MiniGames.injury_chance(g,"be_gach",0),0.03) and is_equal_approx(MiniGames.injury_chance(g,"be_gach",20),0.4),"risk grows with fails and is capped")
	g.s.attr.str.lv=3
	check(MiniGames.injury_chance(g,"be_gach",2)<0.11,"strength lowers risk")
	check(MiniGames.injury_chance(g,"nem_vong",5)==0.0,"leisure has no injury risk")
	var hurt := false
	for d in range(1, 40):
		g=fresh(); g.s.day=d; g.s.cash=50000; g._commit()
		g.do_action("be_gach",{"score":0.25,"fails":10})
		if g.last_minigame.injury!="":
			hurt=true
			check(Survival.has(g,"treo_lung") or Survival.has(g,"dap_ngon"),"injury adds a condition")
			check(g.s.payables.any(func(p): return str(p.id).begins_with("vien_phi")),"unpaid bill becomes a debt")
			if Survival.has(g,"treo_lung"):
				check(not g.action_status(g.get_action("be_gach")).ok,"strained back blocks heavy work")
			break
	check(hurt,"injuries happen at high risk")
	g=fresh(); g.do_action("be_gach",{"score":0.25,"fails":10}); var first: String=str(g.last_minigame.injury)
	g=fresh(); g.do_action("be_gach",{"score":0.25,"fails":10})
	check(str(g.last_minigame.injury)==first,"injury roll is deterministic")

	# Mô phỏng không có kết quả: tính như đủ chỉ tiêu.
	g=fresh(); cash=g.s.cash
	g.do_action("be_gach")
	check(g.s.cash==cash+110000 and Careers.xp(g,"boc_vac")>=25.0,"simulated shift counts as full quota")

	# Lưu, nạp.
	var copy=Logic.new(); copy.load_data(); copy.s=JSON.parse_string(JSON.stringify(g.s)); copy.migrate_save()
	check(Careers.level(copy,"boc_vac")==Careers.level(g,"boc_vac") and copy.s.has("certs"),"trade progress survives save/load")
	finished_parts+=1

func views() -> void:
	var g=fresh()
	# Ném vòng: với mọi gió vẫn có cách ném trúng, và không phải cú nào cũng trúng.
	var c: Dictionary=MiniGames.view_cfg(g,"nem_vong")
	for w in [-1.0,-0.5,0.0,0.5,1.0]:
		var any := false; var miss := false
		for ai in 9:
			for pi in 41:
				var f: Dictionary=RingToss.flight(c,lerpf(30,62,ai/8.0),pi/40.0,w)
				if int(f.hit)>=0: any=true
				else: miss=true
		check(any and miss,"wind %s leaves a hittable throw" % w)
	var v=Registry.make(c); v.cfg=c; v.title="Ném vòng"
	var got := {"r":null}
	v.finished.connect(func(r): got.r=r)
	root.add_child(v); await process_frame
	check(v.state=="intro" and v._first_button!=null,"intro panel opens")
	v.start()
	for i in int(c.rings):
		v.phase="angle"; v.angle=45.0; v.press()
		v.power=0.5; v.press()
		for k in 400:
			v._play(1.0/60.0)
			if v.phase!="fly": break
		for k in 100:
			if v.state!="play" or v.phase=="angle": break
			v._play(1.0/60.0)
	check(v.state=="end" and v.thrown==int(c.rings),"all rings thrown ends the round")
	v._first_button.pressed.emit()
	check(got.r!=null and got.r.has("score") and int(got.r.rings)==int(c.rings),"view reports a raw result")
	v.queue_free()

	# Bê gạch: người giữ thăng bằng làm được chỉ tiêu, người buông tay đổ liên tục.
	var b: Dictionary=MiniGames.view_cfg(g,"be_gach")
	var skilled=await brick_run(b,true)
	var idle=await brick_run(b,false)
	check(float(skilled.score)>=0.5,"balancing player reaches half the quota (%s)" % skilled.score)
	check(int(idle.fails)>int(skilled.fails) and float(idle.score)<float(skilled.score),"letting go drops bricks")
	print("brick bot: skilled ",skilled," idle ",idle)
	finished_parts+=1

func brick_run(b: Dictionary, skilled: bool) -> Dictionary:
	var v=BrickBalance.new(); v.cfg=b; v.title="Bê gạch"
	root.add_child(v); await process_frame
	v.start()
	var dt := 1.0/60.0
	var react := 0.0
	while v.time_left>0.0:
		v.time_left-=dt
		# Người chơi bấm phím rời rạc, nhìn lại mỗi 0,15 giây; thả khi sọt còn lệch dưới 0,15.
		react-=dt
		if react<=0.0:
			react=0.15
			var lean: float=v.tilt+0.35*v.spin
			v.steer=(-signf(lean) if absf(lean)>0.04 else 0.0) if skilled else 0.0
		v.step(dt)
		if v.phase=="drop" and absf(v.swing_x)<0.15: v.drop()
	var r: Dictionary=v.result()
	v.queue_free()
	return r
