extends SceneTree
## Shared objective contracts: real game state, world markers and reloaded saves.
const Logic := preload("res://scripts/game_logic.gd")
const Guide := preload("res://scripts/quest_guide.gd")

class DoorFixture extends RefCounted:
	func loc_door(id: String) -> Vector2:
		return {"xom_bo_me":Vector2(0, 0), "tiem_sau":Vector2(0, 24), "cho_cau_nho":Vector2(24, 24), "com_hanh":Vector2(24, 0)}.get(id, Vector2.ZERO)

func _initialize() -> void:
	_run.call_deferred()

func fresh():
	var g := Logic.new()
	g.load_data()
	g.new_game("full")
	g.s.queue.clear()
	g.s.scenes.clear()
	g.s.neighborhood = {"stage":"done"}
	g.Street.migrate(g.s)
	g.s.used = 10.0 - float(g.cfg.dayStart)
	return g

func order(g, stage := "inspect") -> void:
	g.s.street.job = g.Street.JOBS[0].duplicate(true)
	g.s.street.job.merge({"kind":0, "stage":stage, "due":2})
	g.s.street.accepted_day = 1

func _run() -> void:
	var g = fresh()
	order(g)
	var world = load("res://scripts/world/world.gd").new()
	world.game = g
	world.city = DoorFixture.new()
	for id in ["xom_bo_me", "tiem_sau", "cho_cau_nho", "com_hanh"]:
		world.LOCATIONS[id] = {}
	assert(Guide.active(g).location == "tiem_sau")
	assert(world.objective_spots().size() == 1, "Daily order needs a map marker")
	assert(world.objective_spots()[0][0] == world.door_of("tiem_sau"))
	assert(world.objective_spots()[0][1] == Color("f2c14e"), "Primary HUD target and map emphasis must agree")
	g.s.street.job.stage = "part"
	assert(Guide.active(g).location == "cho_cau_nho")
	assert(world.objective_spots()[0][0] == world.door_of("cho_cau_nho"))
	g.s.street.parts["Tụ quạt"] = 1
	assert(Guide.active(g).location == "tiem_sau", "Owned part must send player back to the bench")
	g.s.street.parts.clear()
	g.s.today.part_0 = 2
	assert(Guide.active(g).location == "tiem_sau", "Sold-out market must offer the usable shop alternative")
	g.s.today.erase("part_0")
	g.s.cash = 0
	assert(not Guide.active(g).navigable)
	assert(Guide.active(g).reason.contains("tiền"))
	assert(world.objective_spots().is_empty(), "Unpayable order must not show an actionable map marker")
	g.s.cash = 100000
	g.s.street.job.stage = "inspect"
	g.s.used = 18.5 - float(g.cfg.dayStart)
	assert(not Guide.active(g).navigable)
	assert(Guide.active(g).reason.contains("18:00"))
	assert(world.objective_spots().is_empty(), "Closed workshop must not point at an impossible current task")
	g.s.used = 10.0 - float(g.cfg.dayStart)
	var snapshot := JSON.stringify(g.s)
	var restored := Logic.new()
	restored.load_data()
	restored.s = JSON.parse_string(snapshot)
	restored.migrate_save()
	assert(Guide.active(restored).location == Guide.active(g).location, "Save reload changed target")
	Guide.targets(g)
	assert(JSON.stringify(g.s) == snapshot, "Guide must not own or mutate progression")
	g.s.queue.append({"id":"ngay1", "data":{}})
	assert(Guide.targets(g).is_empty(), "Dialogue blocks route suggestions")
	g.s.queue.clear()
	g.s.street.job.clear()
	g.s.day = 2
	g.s.used = 12.0 - float(g.cfg.dayStart)
	g.s.scenes = ["ngay2"]
	assert(Guide.targets(g).is_empty(), "Expired story appointment must leave current navigation")
	g.s.used = 10.0 - float(g.cfg.dayStart)
	order(g)
	assert(Guide.active(g).id == "scene:ngay2", "Soon-closing scene should be visible before a tomorrow order")
	g.s.scenes.clear()
	g.s.street.job.clear()
	g.quest_accept("quat_trai_cay", {"deadline_hour":15})
	g.s.queue.clear()
	var fan: Array = Guide.targets(g).filter(func(t): return t.id == "quest:quat_trai_cay")
	assert(fan.size() == 1, "Story repair needs exactly one objective")
	assert(Guide.targets(g).filter(func(t): return t.id == "repair").is_empty(), "Quest-backed repair must not duplicate daily order")
	assert(Guide.active(g).location == "tiem_sau")
	assert(world.objective_spots().size() == 1)
	assert(not str(Guide.active(g).hint).contains("17:00"), "Story fan must use its actual same-day deadline")
	g.s.street.job.stage = "part"
	g.s.cash = 0
	var advance: Dictionary = Guide.active(g)
	assert(advance.location == "tiem_sau" and advance.navigable, "Narrative low-cash fallback must lead to available part advance")
	assert(str(advance.step).contains("ứng"))
	var early = fresh()
	early.s.neighborhood.stage = "intro"
	early.s.used = 0.0
	assert(Guide.active(early).navigable and str(Guide.active(early).hint).contains("08:00"), "Intro supports explicit wait-to-open")
	early.s.neighborhood.stage = "work"
	assert(not Guide.active(early).navigable and str(Guide.active(early).hint).contains("08:00"), "Daily orders must not imply the closed shop is open")
	early.s.used = 8.0 - float(early.cfg.dayStart)
	assert(Guide.active(early).navigable)
	var housing = fresh()
	housing.s.day = 3
	housing.s.housing.visit_target = {"place":"hem_dua", "loc":"hem_dua", "action":"xem_hem_dua"}
	assert(Guide.active(housing).location == "hem_dua" and Guide.active(housing).navigable)
	assert(not housing.s.housing.seen.has("hem_dua"), "Navigation must not complete the visit")
	housing.do_action("xem_hem_dua")
	assert(Guide.active(housing).location == "xom_bo_me", "Physical room visit should lead back to the family")
	assert(housing.s.housing.seen.has("hem_dua"))
	world.free()
	print("PASS: shared quest/order/scene targets, marker parity, part choice/advance, stock/cash/closed hours, deadline priority, intro waiting, real housing visit, save reload, read-only progress")
	quit()
