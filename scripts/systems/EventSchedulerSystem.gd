extends Node
## Data-driven rules shared by GameLogic and the live 3D map. No second clock/save.
## Zone anchors adapt the supplied Node2D design to the existing Node3D city.
## JSON monetary values use money_unit_vnd. Unavailable minigame scenes use timed
## actions; runtime_adapters maps supported games to the existing view registry.
const PATH := "res://data/events_and_jobs.json"
const ATTR := {"strength":"str", "agility":"agi", "intelligence":"int", "perception":"per"}
var world
var night_root: Node3D
var board: Label3D
var timer := 0.0

static func data(g) -> Dictionary:
	return g.cfg.get("event_scheduler", {})

static func state(g) -> Dictionary:
	if not g.s.has("scheduler"):
		g.s.scheduler = {"offer_day":-1, "offers":{}, "fired":[], "disabled":{}, "skill_points":0, "satisfaction":0}
	return g.s.scheduler

static func requirements(raw: Dictionary) -> Dictionary:
	var out := {}
	for k in raw:
		if ATTR.has(k): out["stat." + ATTR[k]] = raw[k]
	return out

static func effects(g, raw: Dictionary) -> Dictionary:
	var out := {}
	for k in raw:
		var v = raw[k]
		match k:
			"money": out.cash = int(v) * int(data(g).get("money_unit_vnd", 1000))
			"hunger": out["need.fed"] = v
			"hygiene": out["need.clean"] = v
			"mood": out["need.mood"] = v
			"reputation": out.respect = v
			"npc_affinity_add":
				for npc in v: out["rep." + str(data(g).runtime_adapters.npc_ids.get(npc,npc))] = v[npc]
			"unlock_feature": out["flag." + str(v)] = true
			"unlock_confession_quest": out["flag.scheduler_confession"] = v
			"unlock_zalo_contact", "disable_job_today", "skill_points", "satisfaction": out["scheduler."+k] = v
			_:
				if k.ends_with("_exp") and ATTR.has(k.trim_suffix("_exp")):
					out["xp."+ATTR[k.trim_suffix("_exp")]] = v
	return out

static func register(g) -> void:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATH)) != OK or not parser.data is Dictionary:
		push_error("Invalid scheduler JSON: " + parser.get_error_message())
		return
	g.cfg.event_scheduler = parser.data
	var d := data(g)
	if g.cfg.has("relationships"):
		g.cfg.relationships.npcs.HAN.messages.append({"id":"scheduler_contact_HAN", "unlockOnly":true, "lines":["Em Hân đây. Cảm ơn anh đã giúp em bắt chuột ở tiệm hoa nhé!"], "replies":[]})
	for e in d.scheduled_story_events:
		var choices := []
		for c in e.get("choices", [{"text":"Tiếp tục", "outcome":e.get("effects",{})}]):
			choices.append({"label":c.text, "require":requirements(c.get("condition",{})), "effects":effects(g,c.get("outcome",{}))})
		g.events.append({"id":"scheduler:"+e.event_id,"system":true,"title":e.title,"text":e.description,"choices":choices})
	for j in d.daily_job_pool:
		var a := {"id":"daily_"+j.job_id,"scheduler_job":j.job_id,"name":j.title,"group":"work",
			"location":d.job_board_location,"hours":j.duration_hours,"window":[6,23],"perDay":1,
			"require":requirements(j.requirements),"effects":effects(g,j.stat_changes).merged(effects(g,j.rewards)),"xp":{}}
		var native: String = d.runtime_adapters.minigames.get(j.job_id,"")
		if not native.is_empty():
			a.minigame = "daily_"+j.job_id
			var def: Dictionary = g.cfg.minigame_catalog.games[native].duplicate(true)
			# Scheduler owns pay, EXP and risk; reuse only the existing playable view.
			def.outcomes = []; def.risk = {}; def.effects = {}; def.prof = ""
			g.cfg.minigame_catalog.games[a.minigame] = def
			g.cfg.minigames[a.minigame] = def.params.merged({"view":def.view})
		g.cfg.actions.append(a)
	var market: Dictionary = d.night_market
	if g.cfg.has("commerce"):
		g.cfg.commerce.spots.scheduler_night = {"location":market.location,"name":"Chợ đêm","legal":true,"fee":0,"traffic":[[market.open_hour,market.close_hour,100]],"demand":{}}
		g.cfg.actions.append({"id":"scheduler_night_sell","name":"Bày bán tại chợ đêm","group":"work","location":market.location,"hours":float(g.cfg.commerce.vending.hours),"perDay":5,"window":[market.open_hour,market.close_hour],"require":{"biz_cart":true},"effects":{"biz":{"op":"sell","spot":"scheduler_night"}}})

static func tick(g) -> void:
	if not g.is_started() or data(g).is_empty(): return
	var s := state(g)
	var d := data(g)
	if g.clock() >= float(d.daily_refresh_hour) and int(s.offer_day) != g.day():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(int(g.s.get("seed",0)))+":"+str(g.day())+":jobs")
		var ids := []
		s.offers = {}; s.disabled = {}; s.offer_day = g.day()
		for j in d.daily_job_pool: ids.append(str(j.job_id)); s.offers[j.job_id] = 0
		for i in mini(int(d.bonus_pay.count),ids.size()):
			var at := rng.randi_range(0,ids.size()-1)
			s.offers[ids[at]] = rng.randi_range(int(d.bonus_pay.percent_range[0]),int(d.bonus_pay.percent_range[1]))
			ids.remove_at(at)
	for j in d.daily_job_pool:
		var a: Dictionary = g.get_action("daily_"+j.job_id)
		var bonus := int(s.offers.get(j.job_id,0))
		a.pay = int(round(float(j.base_pay)*int(d.money_unit_vnd)*(1.0+bonus/100.0)*(1.0-float(j.broker_fee_percent)/100.0)))
		a.name = str(j.title) + (" · Thưởng nóng +%d%%" % bonus if bonus>0 else "")
		a.note = "Nhận %s sau phí môi giới %s%%" % [g.fmt_money(a.pay),str(j.broker_fee_percent)]
		if not a.has("minigame"): a.note += " · Ca tự động; mini-game riêng đang chờ dựng"

static func job_lock(g, a: Dictionary) -> String:
	if a.id == "scheduler_night_sell" and not night_open(g): return "Chợ đêm mở 18:00–23:00"
	var id := str(a.get("scheduler_job", ""))
	# Closure applies across the whole day, even if the player has not seen its story.
	if id.is_empty() and a.id == "be_gach": id = "carry_bricks"
	if id.is_empty(): return ""
	if g.clock() < float(data(g).get("daily_refresh_hour",6)): return "Bảng tuyển dụng mở lúc 6:00"
	if id == "carry_bricks" and g.s.get("conds",{}).has("treo_lung"): return "Đang trẹo lưng, chưa bê vác được"
	if int(state(g).disabled.get(id,-1)) == g.day(): return "Công việc tạm nghỉ hôm nay"
	for e in data(g).get("scheduled_story_events",[]):
		if int(e.day)==g.day() and e.get("effects",{}).get("disable_job_today","")==id: return "Công trường ngừng thi công hôm nay"
	return ""

static func night_open(g) -> bool:
	var n: Dictionary = data(g).get("night_market",{})
	return g.is_started() and g.clock()>=float(n.get("open_hour",18)) and g.clock()<float(n.get("close_hour",23))

static func effect(g, key: String, value) -> bool:
	if not key.begins_with("scheduler."): return false
	var s := state(g)
	match key.trim_prefix("scheduler."):
		"disable_job_today": s.disabled[str(value)] = g.day()
		"skill_points": s.skill_points = int(s.skill_points)+int(value)
		"satisfaction": s.satisfaction = clampi(int(s.satisfaction)+int(value),0,100)
		"unlock_zalo_contact":
			var npc: String = data(g).runtime_adapters.npc_ids.get(str(value),str(value))
			g.s.flags["scheduler_contact_"+npc] = true
			g.apply_effects({"rel_unlock":"scheduler_contact_"+npc})
	return true

static func on_action(g, a: Dictionary) -> void:
	for j in data(g).get("daily_job_pool",[]):
		if j.job_id != a.get("scheduler_job", ""): continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(int(g.s.get("seed",0)))+":"+str(g.day())+":"+str(a.id)+":"+str(g.count(a.id))+":injury")
		if rng.randf()*100.0 < float(j.injury_risk_percent):
			g.apply_effects({"cond.treo_lung":true})
			g.add_log("Chấn thương sau ca làm: trẹo lưng", "warn")

static func enter_zone(g, zone: String) -> bool:
	if not g.is_started() or g.is_over() or not g.s.queue.is_empty(): return false
	var s := state(g)
	for e in data(g).get("scheduled_story_events",[]):
		if int(e.day)!=g.day() or e.trigger_zone!=zone or e.event_id in s.fired: continue
		if g.clock()<float(e.trigger_hour_range[0]) or g.clock()>=float(e.trigger_hour_range[1]): continue
		s.fired.append(e.event_id)
		g.s.queue.append({"id":"scheduler:"+e.event_id,"data":{}})
		g._commit()
		return true
	return false

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	world = get_parent().get_parent()
	if not world.real or not world.city.street_upgrade: set_process(false); return
	var d := data(world.game)
	var zones := Node3D.new(); zones.name="ScheduledZones"; world.add_child(zones)
	for id in d.zones:
		var zone := Node3D.new(); zone.name=id; zones.add_child(zone)
		for loc in d.zones[id].locations:
			if not world.city.locs.has(loc): continue
			var anchor := Marker3D.new(); anchor.name=loc; zone.add_child(anchor); anchor.position=world.door_of(loc)
	board = Label3D.new(); board.name="JobBoard"; board.font_size=28; board.pixel_size=.006
	board.billboard=BaseMaterial3D.BILLBOARD_ENABLED; board.outline_size=6
	world.add_child(board); board.position=world.loc_point(d.job_board_location,-2.3,.4)+Vector3.UP*2.1
	night_root=Node3D.new(); night_root.name="NightMarketSlots"; world.add_child(night_root)
	for offset in d.night_market.slot_offsets:
		var slot := Node3D.new(); night_root.add_child(slot)
		slot.position=world.loc_point(d.night_market.location,float(offset[0]),float(offset[1]))
		var light := OmniLight3D.new(); light.position.y=2.6; light.omni_range=6; light.light_color=Color(d.night_market.light_color); light.light_energy=float(d.night_market.light_energy); slot.add_child(light)
		var marker := MeshInstance3D.new(); var mesh := CylinderMesh.new(); mesh.top_radius=.65; mesh.bottom_radius=.65; mesh.height=.015; marker.mesh=mesh; marker.position.y=.10
		var mat := StandardMaterial3D.new(); mat.albedo_color=Color("d4ab55"); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; marker.material_override=mat; slot.add_child(marker)
		var pick := StaticBody3D.new(); pick.set_meta("loc",d.night_market.location); slot.add_child(pick)
		var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size=Vector3(1.3,.1,1.3); shape.shape=box; shape.position.y=.12; pick.add_child(shape)
	_process(.3)

func _process(delta: float) -> void:
	if world==null or night_root==null: return
	timer-=delta
	if timer>0: return
	timer=.25
	var g=world.game
	night_root.visible=night_open(g)
	for pick in night_root.find_children("*","StaticBody3D",true,false): pick.collision_layer=1 if night_root.visible else 0
	board.visible=g.is_started() and world.player.position.distance_to(board.position)<12
	if not g.is_started(): return
	var lines := ["BẢNG TUYỂN DỤNG · 6:00", "E tại bãi bốc vác để nhận ca"]
	for j in data(g).daily_job_pool:
		var a: Dictionary=g.get_action("daily_"+j.job_id)
		lines.append(str(a.name)+" · "+g.fmt_money(int(a.get("pay",0)))+(" · TẠM NGHỈ" if not job_lock(g,a).is_empty() else ""))
	board.text="\n".join(lines)
	if world.title_open() or world.hud.blocking(): return
	var closest := ""; var distance := INF
	for zone in data(g).zones:
		for loc in data(g).zones[zone].locations:
			if not world.city.locs.has(loc): continue
			var dist: float=world.player.position.distance_to(world.door_of(loc))
			if dist<float(data(g).zones[zone].radius_m) and dist<distance: closest=zone; distance=dist
	if not closest.is_empty(): enter_zone(g,closest)
