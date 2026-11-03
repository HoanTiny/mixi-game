extends RefCounted
## Shop catalog: colors are variants of An's existing shirt and jeans.
const CLOTHES := {
	"shirt_olive":{"name":"Áo caro rêu","slot":"shirt","color":"64735a","price":90000},
	"shirt_blue":{"name":"Áo caro xanh xám","slot":"shirt","color":"6d8390","price":110000},
	"shirt_brown":{"name":"Áo caro nâu đất","slot":"shirt","color":"876955","price":85000},
	"pants_charcoal":{"name":"Jeans than","slot":"pants","color":"484b51","price":140000},
	"pants_indigo":{"name":"Jeans chàm","slot":"pants","color":"414f70","price":160000}
}
const HAIR := {
	"cut_neat":{"name":"Cắt gọn","price":40000,"hours":0.5,"style":"neat"},
	"cut_natural":{"name":"Tỉa tự nhiên","price":40000,"hours":0.5,"style":"natural"},
	"dye_black":{"name":"Nhuộm đen","price":80000,"hours":1.0,"color":"28231e"},
	"dye_brown":{"name":"Nhuộm nâu hạt dẻ","price":80000,"hours":1.0,"color":"604331"},
	"dye_ash":{"name":"Nhuộm nâu khói","price":100000,"hours":1.0,"color":"706961"}
}

static func migrate(s: Dictionary) -> void:
	if s.is_empty():
		return
	if not s.has("inventory"):
		var appearance: Dictionary = s.appearance
		s.inventory = {
			"starter_shirt":{"name":"Áo caro của An","slot":"shirt","color":appearance.shirt,"price":0},
			"starter_pants":{"name":"Quần jeans của An","slot":"pants","color":appearance.pants,"price":0}
		}
		s.equipped = {"shirt":"starter_shirt","pants":"starter_pants"}
	if not s.has("hair_style"):
		s.hair_style = "natural"
	s.save_version = 3

static func offer(game, id: String, location: String) -> Dictionary:
	if not game.is_started() or game.is_over():
		return {"ok":false,"reason":"Ván chơi chưa sẵn sàng"}
	var clothing := CLOTHES.has(id)
	var item: Dictionary = CLOTHES.get(id, HAIR.get(id, {}))
	if item.is_empty():
		return {"ok":false,"reason":"Không có mặt hàng này"}
	var expected := "cho_cau_nho" if clothing else "tiem_toc"
	var hours := 0.25 if clothing else float(item.hours)
	var reason := ""
	if location != expected:
		reason = "Cần tới đúng cửa hàng"
	elif not game.s.queue.is_empty():
		reason = "Cần giải quyết việc đang chờ"
	elif clothing and game.s.inventory.has(id):
		reason = "Đã sở hữu"
	elif not clothing and item.has("style") and game.s.hair_style == item.style:
		reason = "Đang để kiểu tóc này"
	elif not clothing and item.has("color") and game.s.appearance.hair == item.color:
		reason = "Đang có màu tóc này"
	elif game.clock() < 8.0 or game.clock() + hours > 19.0:
		reason = "Mở cửa 08:00–19:00; cần đủ giờ thực hiện"
	elif game.hours_left() < hours:
		reason = "Không còn đủ thời gian hôm nay"
	elif int(game.s.cash) < int(item.price):
		reason = "Không đủ tiền"
	return {"ok":reason.is_empty(),"reason":reason,"hours":hours,"item":item,"clothing":clothing}

static func buy(game, id: String, location: String) -> Dictionary:
	var result := offer(game,id,location)
	if not result.ok:
		return result
	var item: Dictionary = result.item
	game.spend(int(item.price),str(item.name))
	game.elapse(float(result.hours))
	if result.clothing:
		game.s.inventory[id] = item.duplicate()
		game.add_log("Cất vào túi: " + str(item.name),"event")
	else:
		if item.has("color"):
			game.s.appearance.hair = item.color
		if item.has("style"):
			game.s.hair_style = item.style
	game.changed.emit()
	return result

static func equip(game, id: String) -> bool:
	if not game.is_started() or game.is_over() or not game.s.inventory.has(id):
		return false
	var item: Dictionary = game.s.inventory[id]
	game.s.equipped[item.slot] = id
	game.s.appearance[item.slot] = item.color
	game.changed.emit()
	return true
