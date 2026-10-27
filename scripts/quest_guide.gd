extends RefCounted
## First playable quest follows the actual order state; no parallel progress counter.
static func active(g) -> Dictionary:
	if not g.is_started() or g.is_over() or g.s.get("mode","")!="pilot": return {}
	var st: Dictionary = g.s.street
	var job: Dictionary = st.job
	if job.is_empty():
		if int(st.completed)>0: return {}
		return {"title":"Chiếc quạt trước mùa mưa","step":"Ghé Tiệm Sáu nhận món sửa đầu tiên","hint":"Chú Sáu mở cửa 08:00–18:00","location":"tiem_sau"}
	var steps := {"inspect":"Đo kiểm món khách gửi","part":"Tìm linh kiện thay thế","repair":"Lắp linh kiện trên bàn sửa 3D","test":"Chạy thử trước khi trả khách","deliver":"Trả món và nhận tiền công"}
	var location := "tiem_sau"
	var hint := "Hẹn ngày %d · 17:00" % int(job.due)
	if job.stage=="part":
		if int(st.parts.get(job.part,0))==0: location="cho_cau_nho"
		hint="Mua ở chợ rẻ hơn 20.000đ; có thể dùng đồ tiệm"
	return {"title":str(job.name),"step":steps[job.stage],"hint":hint,"location":location}
static func notice(g, title: String, text: String) -> void:
	g.s.quest_notice={"id":str(g.day())+":"+str(g.s.log.size()),"title":title,"text":text}
