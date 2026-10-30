extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
const Travel := preload("res://scripts/neighborhood_travel.gd")

class TinyCity:
	extends RefCounted
	var id := "hn_pho_co"
	var story := {"layoutVersion": 2}
	var locs := {"xom_bo_me": Vector2(0,24), "com_hanh": Vector2(24,24), "tiem_sau": Vector2(0,0), "cho_cau_nho": Vector2(24,0)}
	func loc_door(key: String) -> Vector2:
		return locs[key]
	func walkable(p: Vector2) -> bool:
		return p.is_finite() and p.x < 100
	func path(a: Vector2, b: Vector2) -> PackedVector2Array:
		return PackedVector2Array([a,Vector2(b.x,a.y),b]) if walkable(b) else PackedVector2Array()

var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func fresh():
	var g := Logic.new()
	g.load_data()
	g.new_game("full")
	g.s.queue.clear()
	g.s.day = 3
	g.s.used = 4.0
	return g

func _initialize() -> void:
	var g = fresh()
	check(Travel.options(g,"com_hanh").is_empty(),"Only actual stops offer travel")
	check(Travel.options(g,"ben_xe_6").size()==3,"Hub exposes destinations and locks")
	check(Travel.reason(g,"ben_xe_6","cau_tre")=="","Room visit transport available on day3")
	check(Travel.reason(g,"ben_xe_6","ben_can")!="","Late district waits for introduction")
	check(Travel.reason(g,"ben_can","ben_xe_6")=="","Early explorers can return home")
	var cash := int(g.s.cash)
	var used := float(g.s.used)
	check(Travel.pay(g,"ben_xe_6","cau_tre"),"Valid ride")
	check(int(g.s.cash)==cash-7000 and is_equal_approx(float(g.s.used),used+1.0/3.0),"Charge fare and minutes exactly once")
	g._commit()
	var roundtrip = fresh()
	roundtrip.s=JSON.parse_string(JSON.stringify(g.s))
	roundtrip.migrate_save()
	check(Travel.pay(roundtrip,"cau_tre","ben_xe_6"),"Can return after save/load")
	check(int(roundtrip.s.cash)==cash-14000,"Return fare survives reload")
	g.s.cash=0
	used=float(g.s.used)
	check(not Travel.pay(g,"ben_xe_6","cau_tre") and is_equal_approx(float(g.s.used),used),"No money does not charge time")
	g.s.cash=100000
	g.s.used=float(g.cfg.dayEnd)-float(g.cfg.dayStart)-0.1
	check(not Travel.pay(g,"ben_xe_6","cau_tre"),"Cannot travel beyond day end")
	g.s.used=4.0
	g.s.queue=[{"id":"ngay1"}]
	check(not Travel.pay(g,"ben_xe_6","cau_tre"),"Dialogue must finish before travel")
	g.s.queue.clear()
	g.s.delivery={"shop":"com_hanh","picked":false}
	check(not Travel.pay(g,"ben_xe_6","cau_tre"),"A delivery cannot teleport by transit")
	g.s.erase("delivery")
	check(not Travel.pay(g,"com_hanh","cau_tre"),"Reject nonexistent departure route")
	var city := TinyCity.new()
	var locations := {"xom_bo_me":{"name":"Nhà trọ"},"com_hanh":{"name":"Cơm Hạnh"},"tiem_sau":{"name":"Tiệm Sơn"},"cho_cau_nho":{"name":"Chợ"}}
	var homes := [{"name":"Nhà 12 Phúc Tân","pos":Vector3(18,0,24)}]
	g=fresh()
	g.cfg.walkHoursPerMeter=0.0032
	var offer: Dictionary=g.delivery_offer("com_hanh","Cơm Hạnh","Nhà 12 Phúc Tân",245,400,290)
	g.delivery_accept(offer)
	var pay := int(g.s.delivery.pay)
	var deadline := float(g.s.delivery.deadline)
	cash=int(g.s.cash)
	check(Travel.migrate_layout(g,city,homes,locations),"Old layout migration runs")
	check(Vector2(g.s.delivery.dest_x,g.s.delivery.dest_z)==Vector2(18,24),"Saved delivery relocated to current address")
	check(int(g.s.delivery.pay)==pay and int(g.s.cash)==cash,"Migration neither pays nor penalizes")
	check(float(g.s.delivery.deadline)>=deadline,"Migration preserves or extends deadline")
	var serialized := JSON.stringify(g.s)
	check(not Travel.migrate_layout(g,city,homes,locations) and JSON.stringify(g.s)==serialized,"Migration idempotent")
	g.s.erase("world_layout")
	g.s.delivery.dest="Nhà cũ đã tháo"
	g.s.delivery.dest_x=2000
	check(Travel.migrate_layout(g,city,homes,locations),"Deleted address migration runs")
	check(not g.delivery_active().is_empty() and float(g.s.delivery.dest_x)<100,"Removed address gets a reachable pickup point")
	g.s.erase("delivery")
	g.s.day=1
	for i in 12:
		var local: Dictionary=Travel.make_offer(g,city,Vector2(0,24),homes,locations)
		check(not local.is_empty(),"Early delivery available nearby")
		if local.is_empty(): continue
		var sp: Vector2=city.loc_door(local.shop)
		check(Travel.route_length(city,Vector2(0,24),sp)<=55.0,"Pickup bounded by route distance")
		check(Travel.route_length(city,sp,Vector2(local.dest_x,local.dest_z))<=60.0,"First delivery stays in core")
	check(Travel.make_offer(g,city,Vector2(200,200),homes,locations).is_empty(),"No offer invites a distant pickup")
	print("PASS neighborhood travel: fare/time, gates, return, shortage, reload, idempotent delivery relocation, bounded early jobs" if failures.is_empty() else "FAIL neighborhood travel: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
