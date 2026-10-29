extends RefCounted
## Onboarding and a chosen room visit use saved game facts, not HUD-owned progress.
const VISITS := {
	"hem_dua": {"place":"hem_dua","loc":"hem_dua","action":"xem_hem_dua"},
	"cau_tre": {"place":"cau_tre","loc":"cau_tre","action":"xem_cau_tre"},
	"di_nam": {"place":"di_nam","loc":"nha_di_nam","action":"hoi_di_nam"},
}

static func migrate(g) -> void:
	if not g.is_started(): return
	g.Street.migrate(g.s)
	if not g.s.has("neighborhood"):
		var stage := "done"
		if g.is_full() and g.chapter()==1 and g.day()<=3:
			stage = "meal" if int(g.s.stats.get("earned",0))>0 else "intro"
		g.s.neighborhood = {"stage":stage,"version":1}
	var h: Dictionary = g.housing()
	if h.has("visit_target") and (h.seen.has(str(h.visit_target.get("place",""))) or g.day()>25):
		h.erase("visit_target")
	# Legacy saves already carrying the fan keep their delivery progress and reward.
	if g.quest_state("quat_trai_cay")=="active":
		var quest: Dictionary = g.s.quests.quat_trai_cay
		if int(quest.step)==0 and g.item_count("quat")>0: quest.step=1
		if int(quest.step)==0:
			g.Street.start_story(g)
			# The old diagnosis dialog belongs to the retired menu-only repair step.
			g.s.queue = g.s.queue.filter(func(e): return str(e.id)!="q:quat_trai_cay")
		elif not g.s.street.job.is_empty() and str(g.s.street.job.get("quest_id",""))!="quat_trai_cay":
			g.Street.pause_daily(g)
	elif str(g.s.street.job.get("quest_id",""))=="quat_trai_cay" or g.s.street.has("paused_job"):
		g.Street.end_story(g)

static func earned(g, amount: int) -> void:
	if amount<=0 or not g.s.has("neighborhood"): return
	if str(g.s.neighborhood.stage) in ["intro","work"]:
		g.s.neighborhood.stage="meal"
		g.add_log("Đã có khoản thu đầu tiên. Ghé quán Hạnh ăn một bữa hoặc về ăn cùng bà, rồi bàn tiếp tiền chuyển trọ.","event")

static func action_done(g, action: Dictionary) -> void:
	if not g.s.has("neighborhood"): return
	var id := str(action.id)
	if id=="pho_chao_son" and g.s.neighborhood.stage=="intro":
		g.s.neighborhood.stage="work"
		# Introduce the existing fan quest in person on the first morning.
		# Late arrivals and older saves keep the original day-two encounter.
		if g.is_full() and g.day()==1 and g.clock()<=10.5 and g.quest_state("quat_trai_cay")=="":
			g.s.flags.opening_fan_met=true
			if not g.s.scenes_done.has("ngay2"): g.s.scenes_done.append("ngay2")
			g.s.queue.append({"id":"opening_fan","data":{}})
	if g.s.neighborhood.stage=="meal" and float(action.get("effects",{}).get("need.fed",0))>0:
		g.s.neighborhood.stage="home"
	if id=="pho_ban_thu_chi":
		g.s.neighborhood.stage="done"
		g.s.flags.neighborhood_debrief=true
	if id=="anh_cho_ba": g.housing().erase("visit_return")
	if id=="opening_mango": g.s.neighborhood.stage="done"

static func plan_visit(g, place: String) -> void:
	if not VISITS.has(place): return
	if g.housing().seen.has(place):
		g.housing().visit_return=true
		return
	g.housing().visit_target=VISITS[place].duplicate()
	g.add_log("Đã hẹn xem chỗ ở. Tới tận nơi xem bậc cửa, chỗ phơi và đường đi rồi về bàn với bà.","event")

static func room_seen(g, place: String) -> void:
	var h: Dictionary = g.housing()
	if str(h.get("visit_target",{}).get("place",""))==place: h.erase("visit_target")
	if not g.count("anh_cho_ba"): h.visit_return=true

static func target(g) -> Dictionary:
	if not g.is_started() or g.is_over() or not g.s.queue.is_empty(): return {}
	var h: Dictionary = g.housing()
	if h.has("visit_target"):
		var visit: Dictionary = h.visit_target
		var a: Dictionary = g.get_action(str(visit.action))
		if not a.is_empty() and not g.is_hidden(a):
			return _action_target(g,a,"Đi xem chỗ ở","Xem bậc cửa, chỗ phơi và quãng đi làm; chưa đặt cọc",false)
	if h.get("visit_return",false) and g.day()<=25:
		var a: Dictionary = g.get_action("anh_cho_ba")
		if not g.is_hidden(a): return _action_target(g,a,"Bàn chỗ ở với gia đình","Đưa bà xem chỗ vừa khảo sát; cùng cân nhắc tiền và đường đi",true)
	if not g.s.has("neighborhood") or g.chapter()!=1 or g.day()>7: return {}
	match str(g.s.neighborhood.stage):
		"intro":
			if g.is_full() and g.day()==1 and g.clock()<=10.5:
				return _action_target(g,g.get_action("pho_chao_son"),"Có người cần một người thợ","Cô bán hoa quả đang mang chiếc quạt hỏng tới tiệm Sơn. Ghé nghe cô cần gì",true)
			return _action_target(g,g.get_action("pho_chao_son"),"Tìm việc quanh xóm","Chú Sơn có việc đầu tiên. Bạn cũng có thể chọn ca phụ quán hoặc bốc vác",true)
		"work":
			if g.s.flags.get("opening_fan_declined",false) or g.quest_state("quat_trai_cay")=="failed":
				return _action_target(g,g.get_action("ca_phu_quan"),"Một cách kiếm sống khác","Chị Hạnh đang cần người phụ quán; vẫn có thể bắt đầu lại hôm nay",true)
			if float(g.s.fatigue)>=90:
				return _action_target(g,g.get_action("nghi"),"Nghỉ trước khi nhận việc","Quá mệt để sửa an toàn; nghỉ ở nhà rồi chọn việc tiếp",true)
			if int(g.s.street.get("accepted_day",0))==g.day() and g.s.street.job.is_empty():
				for action_id in ["ca_phu_quan","thu_dong_nat","giao_com"]:
					var alternative: Dictionary = g.get_action(action_id)
					if not alternative.is_empty() and not g.is_hidden(alternative) and g.action_status(alternative).ok:
						return _action_target(g,alternative,"Thử một việc khác hôm nay","Đã trả lại đơn sửa; vẫn còn cách kiếm tiền quanh khu phố",true)
				return _action_target(g,g.get_action("com_voi_ba"),"Về nhà trước, mai chọn việc tiếp","Hôm nay chưa có khoản thu; ăn và nghỉ để bắt đầu lại",true)
			if g.clock()>=17.75:
				return _action_target(g,g.get_action("com_voi_ba"),"Tiệm đã nghỉ, về nhà trước","Mai có thể quay lại nhận việc; hôm nay vẫn có thể ăn và nghỉ",true)
			return {"title":"Khoản thu đầu tiên","step":"Nhận một đơn ở bàn chú Sơn","hint":"Có thể chọn nghề khác; tiền công đầu tiên sẽ giúp tính khoản chuyển trọ","location":"tiem_sau","optional":true,"street_action":"accept"}
		"meal":
			var id := "an_com_quen" if g.s.flags.get("comQuen",false) else "an_com"
			var a: Dictionary = g.get_action(id)
			if g.clock()<10 or g.clock()>=19.5 or int(g.s.cash)<g.action_money(a) or not g.action_status(a).ok:
				a=g.get_action("com_voi_ba")
			return _action_target(g,a,"Ăn một bữa sau khi làm","Gợi ý sinh hoạt; có thể về ăn cùng bà miễn phí",true)
		"home":
			if g.s.flags.get("opening_mango",false) and not g.count("opening_mango"):
				return _action_target(g,g.get_action("opening_mango"),"Hai quả xoài mang về","Cô bán hàng gửi bà phần quà. Về kể chuyện chiếc quạt đầu tiên",true)
			return _action_target(g,g.get_action("pho_ban_thu_chi"),"Về nhà bàn khoản chuyển trọ","Ghi khoản đã kiếm, tiền đã chi và việc ngày mai cùng gia đình",true)
	return {}

static func _action_target(g, a: Dictionary, title: String, hint: String, optional: bool) -> Dictionary:
	if a.is_empty() or g.is_hidden(a): return {}
	var st: Dictionary = g.action_status(a)
	return {"title":title,"step":str(a.name),"hint":hint,"location":g.action_loc(a),"action":str(a.id),"optional":optional,"navigable":bool(st.ok),"reason":str(st.get("reason",""))}
