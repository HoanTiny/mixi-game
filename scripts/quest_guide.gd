extends RefCounted
## Mục tiêu theo đúng bước của đơn sửa đang nhận (không có bộ đếm tiến độ riêng).
static func active(g) -> Dictionary:
	if not g.is_started() or g.is_over() or not g.s.has("street"): return {}
	var st: Dictionary = g.s.street
	var job: Dictionary = st.job
	if job.is_empty(): return {}
	var steps := {"inspect":"Đo kiểm món khách gửi","part":"Tìm linh kiện thay thế","repair":"Lắp linh kiện trên bàn sửa 3D","test":"Chạy thử trước khi trả khách","deliver":"Trả món và nhận tiền công"}
	var location := "tiem_sau"
	var hint := "Hẹn ngày %d · 17:00" % int(job.due)
	if job.stage=="part":
		if int(st.parts.get(job.part,0))==0: location="cho_cau_nho"
		hint="Mua ở chợ rẻ hơn 20.000đ; có thể dùng đồ tiệm"
	return {"title":str(job.name),"step":steps[job.stage],"hint":hint,"location":location}
static func notice(g, title: String, text: String) -> void:
	g.s.quest_notice={"id":str(g.day())+":"+str(g.s.log.size()),"title":title,"text":text}
