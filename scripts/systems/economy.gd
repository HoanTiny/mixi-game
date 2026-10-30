extends RefCounted

static func data(g) -> Dictionary:
	return g.cfg.get("economy",{})

static func configure(g) -> void:
	if g.cfg.has("full") and data(g).has("initialCash"):
		g.cfg.full.cash = int(data(g).initialCash)
	if g.get_action("tra_tro_dem").is_empty():
		g.cfg.actions.append({"id":"tra_tro_dem","name":"Trả tiền trọ cho cô Duyên","group":"life","location":"xom_bo_me","hours":0.0833333333,"perDay":1,"days":[1,30],"cost":int(data(g).get("nightlyRent",60000)),"effects":{"rent_pay":true},"require":{"mode":"full"}})
	var bath: Dictionary = g.get_action("tam_rua")
	if not bath.is_empty():
		bath.name = "Tắm nước lạnh"
		bath.effects["need.clean"] = 40
	if g.cfg.has("hardship"):
		g.cfg.hardship.startCash = int(data(g).get("initialCash",46000))
		g.cfg.hardship.nightRent = int(data(g).get("nightlyRent",60000))
		g.cfg.hardship.livingCost = int(data(g).get("familyUpkeep",0))

static func initialize(g) -> void:
	g.s["housing_fund"] = int(data(g).get("initialHousingFund",1400000)) if g.is_full() else 0
	g.s["fund_version"] = 1

static func migrate(g) -> void:
	if not g.is_started() or g.s.has("fund_version"): return
	# Preserve total wealth: only split existing day-one savings, never mint cash.
	var locked := 0
	if g.is_full() and g.day() == 1 and g.housing().state == "none" and int(g.s.cash) >= 1400000:
		locked = 1400000
		g.s.cash = int(g.s.cash) - locked
	g.s["housing_fund"] = locked
	g.s["fund_version"] = 1

static func fund(g) -> int:
	return maxi(0,int(g.s.get("housing_fund",0)))

static func housing_available(g, place: String) -> int:
	var paid := int(g.housing().paid) if g.housing().place == place else 0
	var deposit_left := maxi(0,int(g.cfg.housing[place].get("deposit",0))-paid)
	return int(g.s.cash) + mini(fund(g),deposit_left)

static func pay_housing(g, place: String, amount: int, label: String) -> void:
	var locked := mini(amount,housing_available(g,place)-int(g.s.cash))
	g.s.housing_fund = fund(g)-locked
	g.s.cash = int(g.s.cash)+locked
	g.spend(amount,label)

static func action_block(g, a: Dictionary) -> String:
	if str(a.get("id","")) != "tra_tro_dem": return ""
	if not active(g): return "Khoản trọ này chỉ áp dụng ở chương đầu"
	if rent_due(g) == 0: return "Đêm nay đã có chỗ ngủ hoặc đã trả tiền trọ"
	return ""

static func active(g) -> bool:
	return g.is_started() and g.is_full() and g.chapter() == 1 and not data(g).is_empty()

static func base_pay(g, a: Dictionary, pay: int) -> int:
	# 1.13 authored job-board/hot-job quotes own their economy. Preserve those contracts.
	if g.Hardship.on(g) and str(a.get("id","")) != "bia_service": return pay
	if not active(g) or str(a.get("group","")) != "work" or pay <= 0: return pay
	var overrides: Dictionary = data(g).get("basePayOverrides",{})
	if overrides.has(str(a.id)): return mini(pay,int(overrides[str(a.id)]))
	return mini(pay,g.round_k(float(a.get("hours",0))*float(data(g).get("hourlyBaseCap",28000))))

## Quote only NEW repeatable repair orders. Never reprice an accepted job or
## authored quest; its saved payment remains the contract made with the player.
static func repair_base_pay(g, kind: int, legacy: int) -> int:
	if not active(g): return legacy
	return int(data(g).get("repairBasePay",{}).get("fan" if kind == 0 else "kettle",legacy))

static func living_cost(g, legacy: int) -> int:
	return int(data(g).get("familyUpkeep",60000)) if active(g) else legacy

static func living_label(g) -> String:
	return str(data(g).get("familyLabel","Góp sinh hoạt gia đình")) if active(g) else "Sinh hoạt cả nhà"

static func rent_due(g) -> int:
	if not active(g): return 0
	if g.today_count("tra_tro_dem") > 0 or bool(g.s.today.get("rent_paid",false)): return 0
	# Paid lodging (or choosing a rough night) replaces today's daily room.
	for id in g.s.today.get("list",[]):
		if g.get_action(str(id)).has("sleepAway"): return 0
	return int(data(g).get("nightlyRent",60000))

static func nightly(g) -> Dictionary:
	if not active(g): return {}
	if not g.s.has("economy"): g.s.economy = {"lastNight":-1,"rentArrears":0}
	var e: Dictionary = g.s.economy
	if int(e.get("lastNight",-1)) == g.day(): return {}
	e.lastNight = g.day()
	var due := rent_due(g) + int(e.get("rentArrears",0))
	var paid := mini(int(g.s.cash),due)
	if paid > 0: g.spend(paid,"Tiền trọ theo đêm" + (" và tiền trọ còn nợ" if int(e.get("rentArrears",0)) > 0 else ""))
	e.rentArrears = due-paid
	if int(e.rentArrears) > 0: g.add_log("Còn nợ tiền trọ %s; khoản này phải trả vào đêm sau" % g.fmt_money(int(e.rentArrears)),"warn")
	return {"due":due,"paid":paid,"arrears":int(e.rentArrears)}

static func savings(g) -> int:
	return maxi(0,fund(g)+int(g.s.get("cash",0))-int(g.s.get("economy",{}).get("rentArrears",0)))
