extends RefCounted
## Local activities: every command is revalidated before spending money/time.
const Quest := preload("res://scripts/quest_guide.gd")
const HOURS := {"tiem_sau":[8,18],"cho_cau_nho":[7,19],"com_hanh":[10,20],"ben_xe_6":[7,18],"ben_can":[8,18],"tiem_toc":[8,19],"xom_bo_me":[6,22]}
const JOBS := [
	{"name":"Quạt của cô Duyên","symptom":"Quạt ù, cánh quay chậm. Rút điện trước khi mở vỏ.","part":"Tụ quạt","reading":"Tụ chỉ còn 0,3 µF; định mức 1,5 µF. Dây nguồn vẫn thông mạch.","fix":"Thay tụ đúng điện dung","price":30000,"pay":230000},
	{"name":"Ấm của khách chợ","symptom":"Ấm không nóng dù đèn nguồn sáng. Cần kiểm tra mạch bảo vệ.","part":"Cầu chì nhiệt","reading":"Cầu chì nhiệt hở mạch, điện trở đun còn tốt. Không nối tắt bảo vệ.","fix":"Thay cầu chì đúng ngưỡng","price":25000,"pay":260000}
]
static func migrate(s: Dictionary) -> void:
	if not s.has("street"):
		s.street = {"xp":0,"tool":false,"parts":{},"job":{},"completed":0,"accepted_day":0,"seen":{},"route":"Đang thử việc"}
static func schedule(name: String, hour: float) -> String:
	match name:
		"Chú Sáu": return "tiem_sau" if hour >= 8 and hour < 18 else "xom_bo_me"
		"Chị Hạnh": return "com_hanh" if hour >= 10 and hour < 20 else "cho_cau_nho"
		"Bà Tư": return "cho_cau_nho" if hour >= 7 and hour < 10 else "xom_bo_me"
		"Linh": return "ben_xe_6" if hour >= 8 and hour < 17 else "xom_bo_me"
	return ""
static func option(id: String, name: String, hours: float, cost := 0, hint := "") -> Dictionary:
	return {"id":id,"name":name,"hours":hours,"cost":cost,"hint":hint,"reason":""}
static func options(g, loc: String) -> Array:
	var out := []
	var st: Dictionary = g.s.street
	var job: Dictionary = st.job
	if loc == "tiem_sau":
		if job.is_empty():
			var kind: int = (g.day()-1) % 2 if int(st.xp) >= 2 else 0
			out.append(option("accept", "Nhận: " + JOBS[kind].name,0.25,0,"Tiền công %s · hẹn 17:00 ngày mai" % g.fmt_money(JOBS[kind].pay)))
			if int(st.accepted_day) == g.day(): out[-1].reason = "Đã nhận đơn hôm nay; mai có khách mới"
		else:
			match str(job.stage):
				"inspect": out.append(option("inspect","Rút điện · đo kiểm",0.25 if st.tool else 0.5,0,job.symptom))
				"part":
					out.append(option("own_part","Dùng linh kiện đã mua",0.1,0,job.reading))
					if int(st.parts.get(job.part,0)) < 1: out[-1].reason = "Cần mua " + str(job.part) + " ở chợ"
					out.append(option("shop_part","Dùng linh kiện của tiệm",0.1,int(job.price)+20000,job.reading))
				"repair":
					if int(st.xp)>=3: out.append(option("quick_fix","Sửa nhanh lỗi đã thành thạo",0.4,0,job.reading))
					out.append(option("fix_cap","Thay tụ đúng điện dung",0.75,0,"Đọc kết quả đo trước khi chọn"))
					out.append(option("fix_fuse","Thay cầu chì đúng ngưỡng",0.75,0,"Không nối tắt mạch bảo vệ"))
				"test": out.append(option("test","Lắp vỏ · chạy thử và kiểm tra an toàn",0.25))
				"deliver": out.append(option("deliver","Trả món cho khách",0.25,0,"Trễ hẹn: giảm 20% tiền công và uy tín"))
			out.append(option("cancel","Xin trả lại đơn chưa hoàn thành",0.1,0,"Uy tín −3; linh kiện đã dùng không hoàn lại"))
		if int(st.xp) >= 3 and job.is_empty() and st.route != "Thợ sửa độc lập":
			out.append(option("route_repair","Chọn hướng: thợ sửa độc lập",0.25,0,"Đơn mới tăng 10% tiền công; cần uy tín Sáu ≥55"))
			if float(g.s.rep.get("SAU",0))<55: out[-1].reason = "Cần uy tín với chú Sáu từ 55"
			for promise in g.s.promises:
				if promise.status in ["open","overdue"]: out[-1].reason = "Giải quyết cam kết đang giữ trước khi đổi hướng nghề"
	if loc == "cho_cau_nho":
		for i in JOBS.size():
			var item: Dictionary = JOBS[i]
			out.append(option("part_"+str(i),"Mua " + item.part,0.25,int(item.price),"Tồn kho mỗi loại: %d" % (2-int(g.s.today.get("part_"+str(i),0)))))
			if int(g.s.today.get("part_"+str(i),0)) >= 2: out[-1].reason = "Hết hàng hôm nay"
		if not st.tool:
			out.append(option("tool","Mua đồng hồ đo đã kiểm định",0.25,180000,"Đo kiểm còn 15 phút; quầy đồ cũ bán ngày lẻ"))
			if g.day()%2 == 0: out[-1].reason = "Hôm nay quầy không có đồng hồ; quay lại ngày lẻ"
	if loc == "com_hanh":
		out.append(option("shift","Bảng việc: phụ quán ca trưa",2,0,"10:00–14:00 · nhận 130.000đ · cần vệ sinh ≥25"))
		if g.clock()<10 or g.clock()+2>14: out[-1].reason = "Ca trưa 10:00–14:00"
		elif float(g.s.hygiene)<25: out[-1].reason = "Tắm trước khi phụ bếp"
		elif g.s.today.has("shift"): out[-1].reason = "Đã làm ca hôm nay"
		out.append(option("delivery","Bảng việc: giao một lượt cơm",1,0,"11:00–14:00 · nhận 70.000đ"))
		if g.clock()<11 or g.clock()+1>14: out[-1].reason = "Giao cơm 11:00–14:00"
		elif g.s.today.has("delivery"): out[-1].reason = "Đã giao lượt hôm nay"
	if loc == "xom_bo_me":
		out.append(option("help","Giúp bà Tư đóng đồ",0.75,0,"18:00–21:00 · tinh thần +10; bà tự quyết món giữ lại"))
		if g.clock()<18 or g.clock()+0.75>21: out[-1].reason = "Bà rảnh buổi tối 18:00–21:00"
		elif g.s.today.has("help"): out[-1].reason = "Tối nay đã giúp bà"
		if not st.seen.has("linh"):
			out.append(option("linh","Hỏi Linh về bộ hồ sơ trên bàn",0.5,0,"Lắng nghe lựa chọn học nghề của em"))
			if g.clock()<17: out[-1].reason = "Linh đi học; về sau 17:00"
		if int(g.s.cash)<30000 and not st.seen.has("advance"):
			out.append(option("advance","Mượn bà 100.000đ để xoay sở",0.25,0,"Trả ngày 5; ghi vào Sổ phải trả"))
	out.append(option("wait","Chờ một giờ / quan sát khu phố",1))
	var window: Array = HOURS.get(loc,[6,22])
	var residents: Dictionary = g.s.get("npc_routes",{})
	for o in out:
		if not o.reason.is_empty(): continue
		var person: String = "Linh" if o.id=="linh" else ("Bà Tư" if o.id in ["help","advance"] else "")
		if residents.has(person) and residents[person].current != loc:
			o.reason = person + " đang trên đường; đợi tới nơi để nói chuyện"
			continue
		if g.is_over() or not g.s.queue.is_empty(): o.reason = "Còn việc cần giải quyết"
		elif o.id != "wait" and (g.clock()<float(window[0]) or g.clock()+o.hours>float(window[1])): o.reason = "Mở %02d:00–%02d:00; cần đủ giờ" % [window[0],window[1]]
		elif g.hours_left()<o.hours: o.reason = "Không đủ giờ"
		elif int(g.s.cash)<int(o.cost): o.reason = "Không đủ tiền"
		elif o.id != "wait" and (loc=="tiem_sau" or o.id in ["shift","delivery"]) and float(g.s.fatigue)>=90: o.reason = "Quá mệt; nghỉ trước khi sửa"
	return out
static func act(g, loc: String, id: String) -> bool:
	var chosen := {}
	for o in options(g,loc):
		if o.id == id: chosen = o
	if chosen.is_empty() or chosen.reason != "": return false
	var st: Dictionary = g.s.street
	g.spend(int(chosen.cost),chosen.name)
	g.elapse(chosen.hours,loc=="tiem_sau" or id in ["shift","delivery"])
	g.s.today.list.append(id)
	g.s.today[id] = int(g.s.today.get(id,0))+1
	g.add_log(chosen.name,"event")
	match id:
		"accept":
			var kind: int = (g.day()-1)%2 if int(st.xp)>=2 else 0
			st.job = JOBS[kind].duplicate(true)
			if st.route == "Thợ sửa độc lập": st.job.pay = int(st.job.pay * 1.1)
			st.job.merge({"kind":kind,"stage":"inspect","due":g.day()+1})
			st.accepted_day = g.day()
			Quest.notice(g,"Nhận việc · "+str(st.job.name),"Đo kiểm trước, rồi cân nhắc tiền linh kiện và giờ hẹn.")
			if int(st.completed)==0: g.add_log("Chú Sáu: Cô Duyên dùng chiếc quạt này ở phòng trọ. Con làm cẩn thận, cô còn giới thiệu khách cho.","event")
		"inspect": st.job.stage = "part"; g.add_log(st.job.reading)
		"shop_part", "own_part":
			if id=="own_part": st.parts[st.job.part] = int(st.parts[st.job.part])-1
			st.job.stage = "repair"
		"fix_cap", "fix_fuse":
			if (id=="fix_cap" and int(st.job.kind)==0) or (id=="fix_fuse" and int(st.job.kind)==1):
				st.job.stage = "test"
			else: g.add_log("Thao tác không khớp kết quả đo. Chưa sửa xong; xem lại chẩn đoán.","warn")
			g.add_fatigue(8)
		"quick_fix": st.job.stage = "test"; g.add_fatigue(4)
		"test": st.job.stage = "deliver"; g.add_log("Máy chạy ổn định, cách điện và bảo vệ đạt. Có thể trả khách.")
		"deliver":
			var late: bool = g.day()>int(st.job.due) or (g.day()==int(st.job.due) and g.clock()>17)
			g.earn(int(float(st.job.pay)*(0.8 if late else 1.0)),st.job.name)
			g.add_rep("SAU",-3 if late else 3)
			st.xp = int(st.xp)+1
			st.completed = int(st.completed)+1
			Quest.notice(g,"Đã trả món · "+str(st.job.name),"Trễ hẹn: tiền công giảm 20%, uy tín −3" if late else "Đúng hẹn · Uy tín +3 · Khách đã nhận lại đồ")
			if int(st.completed)==1:
				g.adjust_need("mood",5)
				g.add_log("Cô Duyên mang quạt về phòng. Chú Sáu nhắc: có tiền rồi nhớ ăn một bữa, đừng nhận việc tới kiệt sức.","event")
			st.job = {}
		"cancel": st.job = {}; g.add_rep("SAU",-3)
		"tool": st.tool = true
		"shift": g.earn(130000,"Ca phụ quán"); g.add_fatigue(15)
		"delivery": g.earn(70000,"Giao cơm"); g.add_fatigue(8)
		"help": g.adjust_need("mood",10); g.add_rep("BA_TU",3); g.s.family.append({"who":"BA_TU","kind":"support","day":g.day(),"text":"Giúp đóng đồ, để bà chọn món giữ lại"})
		"linh": st.seen.linh = true; g.add_rep("LINH",5); g.s.linh.contact = "lang_nghe"; g.add_log("Linh muốn học nghề xa nhà. Em tự chọn nơi học và ngày nộp hồ sơ.")
		"advance":
			st.seen.advance = true
			g.earn(100000,"Bà Tư cho mượn")
			g._add_payable({"id":"pilot_advance","label":"Trả bà tiền xoay sở","to":"BA_TU","amount":100000,"due":maxi(5,g.day()+1)})
		"route_repair": st.route = "Thợ sửa độc lập"
	if id.begins_with("part_"):
		var part: String = JOBS[int(id.trim_prefix("part_"))].part
		st.parts[part] = int(st.parts.get(part,0))+1
	g.changed.emit()
	return true
static func morning(g) -> void:
	if g.s.get("mode","") != "pilot": return
	if g.day()==3:
		g.s.linh.decision = "xa"
		g.add_log("Tin nhắn Linh: Em nộp hồ sơ học nghề rồi. Chiều về em kể anh nghe.","event")
	if g.day()==4: g.add_log("Giấy báo ở cửa phòng: nhớ dành khoản dự phòng trước mùa mưa. Mục tiêu ngày 5: 500.000đ.","event")
static func status(g) -> String:
	var st: Dictionary = g.s.street
	var text := "Tay nghề %d · Đã trả %d món · %s" % [st.xp,st.completed,st.route]
	text += "\nDụng cụ: " + ("Đồng hồ đo riêng" if st.tool else "Mượn đồ nghề tiệm")
	for part in st.parts: text += " · %s ×%d" % [part,st.parts[part]]
	if not st.job.is_empty():
		text += "\n%s · %s · hẹn ngày %d lúc 17:00" % [st.job.name,{"inspect":"Chờ đo","part":"Chờ linh kiện","repair":"Chờ sửa","test":"Chờ chạy thử","deliver":"Chờ trả"}[st.job.stage],st.job.due]
		if st.job.stage != "inspect": text += "\n" + str(st.job.reading)
	return text


## Drag/drop progression is saved with the order; only completing assembly charges repair time.
static func bench_action(g, step: String, component: int, token: String) -> String:
	if not g.is_started() or g.is_over(): return "Ván chơi đã kết thúc"
	var job: Dictionary = g.s.street.job
	if job.is_empty() or job.stage != "repair": return "Đơn này không còn ở bước sửa"
	if token != str(g.s.street.accepted_day)+":"+str(int(job.kind)): return "Đơn đã thay đổi; mở lại bàn sửa"
	var allowed := false
	var reason := "Không thể sửa lúc này"
	for offer in options(g,"tiem_sau"):
		if offer.id == ("fix_cap" if int(job.kind)==0 else "fix_fuse"):
			allowed = offer.reason.is_empty()
			reason = offer.reason
	if not allowed: return reason
	var progress: Dictionary = job.get("bench",{"removed":false,"installed":false,"screws":0})
	match step:
		"remove":
			if progress.removed: return "Đã tháo linh kiện hỏng"
			progress.removed = true
		"install":
			if not progress.removed: return "Tháo linh kiện hỏng trước"
			if progress.installed: return "Đã lắp linh kiện mới"
			if component != int(job.kind): return "Sai loại linh kiện; xem kết quả đo"
			progress.installed = true
		"screw":
			if not progress.installed: return "Lắp linh kiện mới trước khi siết vít"
			if component not in [0,1]: return "Không có vít này"
			if int(progress.screws) & (1 << component): return "Vít này đã siết"
			progress.screws = int(progress.screws) | (1 << component)
		_: return "Thao tác không hợp lệ"
	job.bench = progress
	if int(progress.screws)==3:
		act(g,"tiem_sau","fix_cap" if int(job.kind)==0 else "fix_fuse")
	else: g.changed.emit()
	return ""
