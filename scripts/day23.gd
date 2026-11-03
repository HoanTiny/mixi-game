extends RefCounted
## Customer repair shares street.job/bench; family appointments are saved separately.
static func enabled(g) -> bool:
	return g.is_started() and g.is_full() and g.chapter()==1 and g.s.flags.get("opening_fan_met",false)

static func migrate(g) -> void:
	if not enabled(g) or g.day()<2 or g.day()>3 or g.s.has("day23"): return
	g.s.day23={"meeting":"invited","hour":12.0,"order":"offered","debrief":false,"apology":false}
	if not g.s.scenes_done.has("ngay3"): g.s.scenes_done.append("ngay3")
	g.add_log("Linh nhắn: Chủ phòng ngõ Gạch rảnh lúc 12 giờ hoặc 16 giờ hôm nay. Anh về chốt giờ nhé. Chú Sơn cũng đang giữ một chiếc ấm của hàng nước.","event")

static func promise(g, status: String) -> void:
	for p in g.s.promises:
		if p.id=="day23_room": p.status=status

static func tick(g, end_day := false) -> void:
	migrate(g)
	if not enabled(g) or not g.s.has("day23"): return
	var a: Dictionary=g.s.day23
	if a.meeting in ["invited","promised"] and (g.day()>2 or end_day or g.clock()>float(a.hour)+0.25):
		var promised: bool=a.meeting=="promised"
		a.meeting="solo"
		a.delegated=not promised
		promise(g,"overdue")
		if promised: g.add_rep("LINH",-5)
		g.s.flags.day23_linh_solo=true
		g.add_log("Linh: Em đi xem phòng rồi. Bậc cửa cao, bà phải bước cẩn thận; chỗ phơi có nắng. Tối em mang ảnh về."+(" Em đã chờ anh mười lăm phút." if promised else ""),"warn" if promised else "event")
	if g.day()>3 and a.order=="offered": a.order="expired"
	if owns_job(g) and (g.day()>3 or (end_day and g.day()==3)):
		a.order="cancelled"
		g.add_rep("SAU",-2)
		_close_order(g)
		g.add_log("Hết ngày 3, chú Sơn nhận lại chiếc ấm để khách có đồ dùng. An chưa được tính công; khoản ứng linh kiện vẫn cần hoàn.","warn")
	if g.day()>=3 and not a.get("morning_note",false):
		a.morning_note=true
		g.add_log("Ngày mới: khách chờ một câu trả lời, cả nhà chờ một chỗ ở. Tới quán Hạnh, cùng Linh chốt việc tiếp theo.","event")
	advance_order(g)

static func option(id: String, name: String, hours: float, hint := "", cost := 0) -> Dictionary:
	return {"id":id,"name":name,"hours":hours,"cost":cost,"hint":hint,"reason":""}

static func guard(g, out: Array, loc: String) -> Array:
	var hours: Array={"tiem_sau":[8,18],"cho_cau_nho":[7,19],"hem_dua":[8,18],"com_hanh":[10,20]}.get(loc,[6,22])
	for o in out:
		if o.reason!="": continue
		if g.is_over() or not g.s.queue.is_empty(): o.reason="Còn cuộc trò chuyện cần giải quyết"
		elif g.clock()<hours[0] or g.clock()+float(o.hours)>hours[1]: o.reason="Chưa mở cửa hoặc không đủ giờ trước khi đóng cửa"
		elif g.hours_left()<float(o.hours): o.reason="Không đủ giờ hôm nay"
		elif int(g.s.cash)<int(o.cost): o.reason="Không đủ tiền; có thể nhờ tiệm ứng linh kiện mới"
		elif loc=="tiem_sau" and g.s.fatigue>=90 and o.id not in ["arc_delay","arc_cancel"]: o.reason="Quá mệt; nghỉ trước khi sửa"
	return out

static func social_options(g, loc: String) -> Array:
	if not enabled(g) or not g.s.has("day23"): return []
	var a: Dictionary=g.s.day23
	var out: Array=[]
	if g.day()==2:
		if loc=="xom_bo_me" and a.meeting=="invited":
			out.append(option("arc_meet_noon","Hẹn Linh xem phòng lúc 12 giờ",0.1,"Gặp tại phòng ngõ Gạch; xem phòng mất 30 phút, chưa đặt cọc"))
			out.append(option("arc_meet_late","Hẹn Linh xem phòng lúc 16 giờ",0.1,"Dành buổi sáng sửa ấm; chủ phòng giữ giờ đến 16:15"))
			out.append(option("arc_solo","Nhờ Linh xem trước, tối cùng xem ảnh",0.1,"Nói rõ từ đầu, không bị trừ tình cảm vì thất hẹn"))
		if a.meeting=="promised" and float(a.hour)==12.0 and g.clock()<11.5:
			out.append(option("arc_move_meeting","Nhắn Linh đổi giờ xem phòng sang 16:00",0.1,"Báo trước 11:30; Linh xác nhận với chủ phòng, chỉ đổi một lần"))
		if loc=="hem_dua" and a.meeting=="promised":
			out.append(option("arc_attend","Cùng Linh xem phòng và đo bậc cửa",0.5,"Ghi nhận nắng, bậc cửa và giá 5.000.000đ vào ở; chưa trả tiền"))
			if g.clock()<float(a.hour)-0.25 or g.clock()>float(a.hour)+0.25:
				out[-1].reason="Hẹn %s · có mặt trong vòng 15 phút trước/sau giờ hẹn"%g.hh(a.hour)
			if g.clock()<float(a.hour)-0.25:
				out.append(option("arc_wait_linh","Đợi Linh tới giờ xem phòng",float(a.hour)-g.clock(),"Đồng hồ và nhu cầu vẫn trôi; có thể quay lại sau"))
	if a.meeting=="solo" and loc=="xom_bo_me" and not a.apology:
		out.append(option("arc_apology","Xem ảnh phòng Linh chụp, nhận phần việc cho bà" if a.get("delegated",false) else "Nghe Linh kể, nhận phần việc tìm đường cho bà",0.25,"Ảnh và thông tin phòng được lưu; cùng tính bậc cửa cho bà"))
	var debrief_loc := "com_hanh" if g.day()==3 else "xom_bo_me"
	if g.day()>=3 and loc==debrief_loc and not a.debrief:
		out.append(option("arc_debrief","Ngồi với Linh, chốt việc ngày mai",0.5,"Không gọi thêm món; nhìn lại đơn ấm và chuyện phòng trọ"))
		if g.clock()<17.0: out[-1].reason="Linh hẹn sau 17 giờ, khi đã xong việc trong ngày"
	return guard(g,out,loc)

static func owns_job(g) -> bool:
	return str(g.s.get("street",{}).get("job",{}).get("arc",""))=="day23"

static func repair_options(g, loc: String) -> Array:
	if not enabled(g) or not g.s.has("day23"): return []
	var a: Dictionary=g.s.day23
	var j: Dictionary=g.s.street.job
	var out: Array=[]
	if not owns_job(g):
		if a.order=="offered" and g.day()<=3 and loc=="tiem_sau":
			out.append(option("arc_accept","Nhận chiếc ấm của hàng nước",0.15,"Khách cần lúc 14:00 ngày 2. Đo đủ rồi báo giá; nếu muộn, phải thương lượng giờ trả."))
			if not j.is_empty(): out[-1].reason="Hoàn thành đơn đang giữ trước"
			out.append(option("arc_decline","Báo chưa nhận được chiếc ấm",0.1,"Chú Sơn lo đơn này; An vẫn có thể phụ quán và đi xem phòng"))
		return guard(g,out,loc)
	if loc=="tiem_sau":
		match str(j.stage):
			"measure":
				for spec in [["wire","Đo thông mạch dây nguồn"],["heater","Đo điện trở mâm nhiệt"],["fuse","Đo cầu chì nhiệt"]]:
					if not j.measurements.has(spec[0]): out.append(option("arc_measure_"+spec[0],spec[1],0.15,"Rút phích cắm, dùng đồng hồ của tiệm"))
			"diagnose":
				out.append(option("arc_diagnose_fuse","Cầu chì hở: thay đúng ngưỡng",0.1,"Đọc ba số đo; không nối tắt mạch bảo vệ"))
				out.append(option("arc_diagnose_heater","Nghi mâm nhiệt hỏng: đo đối chứng",0.25,"Mất thêm thời gian; chưa mua linh kiện hoặc tính phí khách"))
			"quote":
				out.append(option("arc_quote_new","Báo giá 180.000đ, dùng cầu chì mới",0.1,"Linh kiện 25.000đ ở chợ / 45.000đ tiệm; khách xác nhận sau 15 phút"))
				out.append(option("arc_quote_used","Báo giá 175.000đ, kiểm tra cầu chì tồn kho cũ",0.1,"10.000đ một túi ở chợ; lời hơn 10.000đ nhưng mất thêm 30 phút kiểm tra"))
			"approval":
				out.append(option("arc_wait_reply","Đợi khách xác nhận báo giá",maxf(0.0,float(j.reply_at)-g.now_abs()),"Có thể rời tiệm lo việc khác; đồng hồ và nhu cầu vẫn trôi"))
			"part":
				if j.source=="new":
					out.append(option("arc_shop_part","Lấy cầu chì mới tại tiệm",0.1,"Giữ nguyên giá đã báo khách",45000))
					out.append(option("arc_credit_part","Nhờ Sơn ứng cầu chì mới",0.1,"45.000đ trừ lúc trả hàng; hủy đơn vẫn phải hoàn khoản ứng"))
			"check_part": out.append(option("arc_check_used","Kiểm tra trị số và nhãn linh kiện cũ",0.5,"Hai mẫu trong túi: chỉ lắp mẫu đúng ngưỡng và đo đạt"))
			"used_choice":
				out.append(option("arc_use_184","Chọn mẫu 184°C / 10A, đo 0,2 Ω",0.05,"Đối chiếu với cầu chì gốc và loại mẫu còn lại"))
				out.append(option("arc_use_216","Chọn mẫu 216°C / 10A, đo 0,2 Ω",0.1,"Thông mạch chưa đủ; cần đúng ngưỡng bảo vệ"))
				out.append(option("arc_requote","Báo lại khách để chuyển sang linh kiện mới",0.1,"Giữ khoản túi linh kiện đã mua; gửi báo giá mới và chờ xác nhận"))
			"repair": out.append(option("fix_fuse","Thay cầu chì trên bàn sửa 3D",1.5,"Tháo cách điện, lắp cầu chì và siết vít · 90 phút; có thể rời bàn giữ tiến độ"))
			"test": out.append(option("test","Đun thử, kiểm tra ngắt và cách điện",0.25,"Thử xong mang ấm ra hàng nước ở chợ"))
	if loc=="cho_cau_nho":
		if j.stage=="part": out.append(option("arc_buy_part","Mua cầu chì mới" if j.source=="new" else "Mua túi cầu chì tồn kho cũ",0.25,"Đồ tồn kho cần mang về đo và đọc nhãn trước",25000 if j.source=="new" else 10000))
		if j.stage=="deliver": out.append(option("arc_deliver","Trả ấm cho cô hàng nước",0.15,"Đúng hẹn nhận đủ giá báo; trễ không báo giảm 20% và uy tín"))
	if loc in ["tiem_sau","cho_cau_nho"]:
		if not j.get("reported",false): out.append(option("arc_delay","Gọi khách xin trả lúc 17 giờ",0.1,"Báo trước hạn giữ uy tín. Báo muộn vẫn bị giảm 10% tiền công."))
		out.append(option("arc_cancel","Báo khách, trả lại chiếc ấm chưa xong",0.1,"Uy tín −2; hoàn linh kiện tiệm đã ứng"))
	return guard(g,out,loc)

static func act(g, loc: String, id: String) -> bool:
	var chosen: Dictionary={}
	for o in social_options(g,loc)+repair_options(g,loc):
		if o.id==id: chosen=o
	if chosen.is_empty() or chosen.reason!="": return false
	var a: Dictionary=g.s.day23
	var j: Dictionary=g.s.street.job
	var start: float=g.now_abs()
	g.spend(int(chosen.cost),chosen.name)
	g.elapse(float(chosen.hours),loc=="tiem_sau")
	g.s.today.list.append(id)
	g.add_log(chosen.name,"event")
	match id:
		"arc_meet_noon","arc_meet_late":
			a.meeting="promised"
			a.hour=12.0 if id=="arc_meet_noon" else 16.0
			g._add_promise({"id":"day23_room","text":"Cùng Linh xem phòng ngày 2 lúc "+g.hh(a.hour),"to":"LINH","due":2})
		"arc_move_meeting":
			a.hour=16.0
			for p in g.s.promises:
				if p.id=="day23_room": p.text="Đã báo đổi: cùng Linh xem phòng ngày 2 lúc 16:00"
			g.add_log("Linh: Vâng, em đã hỏi lại chủ phòng. Bốn giờ gặp anh ở cửa ngõ Gạch.","event")
		"arc_solo": a.meeting="solo"; a.delegated=true; g.s.flags.day23_linh_solo=true
		"arc_attend":
			a.meeting="attended"
			promise(g,"done")
			g.add_rep("LINH",5)
			g.s.flags.day23_room_together=true
			if not g.housing().seen.has("hem_dua"): g.housing().seen.append("hem_dua")
			g.add_diary("Cùng Linh đo bậc cửa phòng ngõ Gạch. Gần tiệm, có nắng phơi, nhưng bậc cao bất tiện cho bà. Cần 5 triệu vào ở; chưa đặt cọc.")
		"arc_apology":
			a.apology=true; g.add_rep("LINH",2)
			if not g.housing().seen.has("hem_dua"): g.housing().seen.append("hem_dua")
			g.add_log("Linh đưa ảnh: Chủ phòng giữ giá năm triệu. Anh xem giúp em cái bậc cao này, bà bước có khó không?" if a.get("delegated",false) else "Linh đưa ảnh: Em không cần anh bỏ việc. Lần sau biết không tới thì nhắn em trước. An nhận tìm cách làm bậc thấp cho bà.","event")
		"arc_debrief":
			a.debrief=true
			g.s.flags.day23_debrief=true
			var family := "Hai anh em đã cùng xem phòng." if a.meeting=="attended" else "Linh tự đi xem phòng; việc của em vẫn tiếp tục."
			var work := "Khách đã có ấm, giới thiệu An cho hàng bên." if a.order=="done" else "Còn đơn ấm chưa giải quyết." if a.order=="accepted" else "Đơn ấm đã nhường lại; An có thể chọn việc khác."
			if a.order=="done" and a.get("order_late",false): work="Khách đã nhận ấm nhưng chưa giới thiệu việc; cô nhắc An lần sau báo sớm."
			g.add_diary(family+" "+work+" Cần 5 triệu cho phòng gần; ngày mai tới chỗ ở khác so đường đi, chưa đặt cọc vội.")
			g.add_log(family+" "+work,"event")
			g.s.queue.append({"id":"day23_evening","data":{"family_result":family,"work_result":work}})
		"arc_accept":
			a.order="accepted"
			g.s.street.job={"arc":"day23","name":"Ấm của cô hàng nước","kind":1,"part":"Cầu chì nhiệt","price":25000,"pay":180000,"stage":"measure","due":2,"due_hour":14.0,"measurements":{},"reading":"Chưa đo. Khách nói đèn sáng nhưng nước không nóng.","symptom":"Rút điện trước khi kiểm tra.","credit":0}
			g.s.street.accepted_day=g.day()
		"arc_decline": a.order="declined"
		"arc_measure_wire","arc_measure_heater","arc_measure_fuse":
			var key:=id.trim_prefix("arc_measure_")
			j.measurements[key]={"wire":"Dây nguồn: 0,2 Ω, còn thông.","heater":"Mâm nhiệt: 32 Ω, không đứt.","fuse":"Cầu chì: OL, hở mạch; nhãn 184°C / 10A."}[key]
			j.reading="\n".join(j.measurements.values())
			if j.measurements.size()==3: j.stage="diagnose"
		"arc_diagnose_fuse": j.stage="quote"; j.erase("feedback")
		"arc_diagnose_heater": j.feedback="Đo lại vẫn 32 Ω. Mâm nhiệt chưa đứt; cầu chì OL mới là điểm hở. Không tính phí đo lại cho khách."
		"arc_quote_new","arc_quote_used":
			j.source="new" if id=="arc_quote_new" else "used"
			j.pay=180000 if j.source=="new" else 175000
			j.reply_at=g.now_abs()+0.25; j.stage="approval"
			g.add_log("Đã gửi báo giá. Chờ khách xác nhận trước khi mua linh kiện.","event")
		"arc_buy_part","arc_shop_part","arc_credit_part":
			j.stage="check_part" if j.source=="used" else "repair"
			if id=="arc_credit_part": j.credit=45000
		"arc_check_used":
			j.stage="used_choice"
			j.reading+="\nTúi cũ: một mẫu 216°C / 10A và một mẫu 184°C / 10A. Cả hai đo 0,2 Ω. Cầu chì gốc ghi 184°C / 10A."
		"arc_use_184": j.stage="repair"; j.erase("feedback")
		"arc_use_216": j.feedback="Mẫu này thông nhưng ngưỡng 216°C cao hơn nhãn gốc. Không lắp; chọn lại hoặc báo khách đổi sang mới."
		"arc_requote": j.stage="quote"
		"fix_fuse": j.stage="test"; g.add_fatigue(8)
		"test": j.stage="deliver"; g.s.flags.day23_carry_kettle=true
		"arc_delay":
			j.reported=true
			j.reported_late=start>float(j.due)*24.0+float(j.due_hour)
			j.due=g.day(); j.due_hour=17.0
			g.add_log("Khách: Cô mượn ấm hàng bên rồi. Cháu trả trước 17 giờ nhé. Không kịp nữa thì mang lại cô.","event")
		"arc_deliver":
			var late: bool=g.now_abs()>float(j.due)*24.0+float(j.due_hour)
			var factor:=0.8 if late else (0.9 if j.get("reported_late",false) else 1.0)
			g.earn(roundi(float(j.pay)*factor),"Tiền sửa ấm theo báo giá")
			g.add_rep("SAU",-3 if late else 4)
			g.s.street.xp+=1; g.s.street.completed+=1
			a.order="done"; a.order_late=late or j.get("reported_late",false)
			g.s.flags.day23_kettle_delivered=true
			g.s.flags.day23_reliable=not a.order_late
			_close_order(g)
			g.add_log("Cô bật ấm ngay tại sạp: Có nước pha trà rồi. Cảm ơn An."+(" Lần sau nhớ báo cô sớm." if a.order_late else " Mai cô giới thiệu cháu cho hàng bên."),"event")
		"arc_cancel":
			a.order="cancelled"; g.add_rep("SAU",-2); _close_order(g)
	g._commit()
	return true

static func _close_order(g) -> void:
	var credit: int=g.s.street.job.get("credit",0)
	if credit>0:
		var paid: int=g.spend(credit,"Hoàn ứng cầu chì cho Sơn")
		if paid<credit: g._add_payable({"id":"day23_parts","label":"Cầu chì tiệm Sơn đã ứng","amount":credit-paid,"due":g.day()+1})
	g.s.street.job={}
	g.s.flags.erase("day23_carry_kettle")

static func advance_order(g) -> void:
	if not owns_job(g): return
	var j: Dictionary=g.s.street.job
	if j.stage=="approval" and g.now_abs()>=float(j.reply_at):
		j.stage="part"
		g.add_log("Khách xác nhận: Cô đồng ý giá %s. Cháu cứ làm, giữ đúng bảo vệ nhé."%g.fmt_money(j.pay),"event")

static func targets(g) -> Array:
	if not enabled(g) or not g.s.has("day23"): return []
	var a: Dictionary=g.s.day23
	var out: Array=[]
	if g.day()==2 and a.meeting=="invited": out.append(_target("Hẹn một giờ với Linh","xom_bo_me","Chọn 12 giờ, 16 giờ hoặc nhờ Linh xem trước",105))
	if g.day()==2 and a.meeting=="promised": out.append(_target("Gặp Linh lúc "+g.hh(a.hour),"hem_dua","Có mặt trong vòng 15 phút · xem phòng mất 30 phút",180 if float(a.hour)-g.clock()<1.25 else 96))
	if a.order=="offered" and g.day()<=3: out.append(_target("Chiếc ấm ở tiệm Sơn","tiem_sau","Nhận hoặc từ chối; đo trước, báo giá sau",94))
	if a.meeting=="solo" and not a.apology: out.append(_target("Linh đã mang ảnh phòng về","xom_bo_me","Nghe Linh kể và bàn việc giúp bà",64))
	if g.day()>=3 and not a.debrief:
		var t := _target("Cùng Linh tính việc ngày mai","com_hanh" if g.day()==3 else "xom_bo_me","Sau 17 giờ · không cần gọi thêm món",65)
		if g.clock()<17.0:
			t.navigable=false
			t.reason="Linh đang bận; gặp sau 17 giờ"
		out.append(t)
	return out

static func _target(title: String, loc: String, hint: String, priority: int) -> Dictionary:
	return {"id":"day23:"+loc,"title":title,"step":title,"location":loc,"hint":hint,"priority":priority,"navigable":true,"reason":""}

static func linh_errand(g) -> Dictionary:
	if not enabled(g) or not g.s.has("day23"): return {}
	var a: Dictionary=g.s.day23
	if g.day()==2 and g.clock()>=float(a.hour)-0.6 and g.clock()<float(a.hour)+1.0:
		return {"npc":"LINH","to":"hem_dua","hours":[float(a.hour)-0.6,float(a.hour)+1.0],"slot":0,"what":"đi xem phòng ngõ Gạch"}
	if g.day()==3 and g.clock()>=16.5 and g.clock()<20 and not a.debrief:
		return {"npc":"LINH","to":"com_hanh","hours":[16.5,20],"slot":1,"what":"hẹn An bàn chỗ ở"}
	return {}
