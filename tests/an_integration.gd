extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1366,800)
	root.gui_embed_subwindows = true
	var scene = load("res://scenes/world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var g = scene.game
	g.s.queue.clear()
	g.s.cash = 1000000
	g.s.used = 0.0
	assert(not Wardrobe.buy(g,"shirt_olive","cho_cau_nho").ok,"Closed shop charged")
	g.s.used = 8.0 - float(g.cfg.dayStart)
	assert(not Wardrobe.buy(g,"shirt_olive","tiem_toc").ok)
	assert(not Wardrobe.equip(g,"shirt_olive"))
	g.s.cash = 0
	assert(not Wardrobe.buy(g,"shirt_olive","cho_cau_nho").ok)
	g.s.cash = 1000000
	assert(Wardrobe.buy(g,"shirt_olive","cho_cau_nho").ok)
	assert(g.s.cash == 910000 and is_equal_approx(g.clock(),8.25))
	assert(g.s.equipped.shirt == "starter_shirt")
	assert(not Wardrobe.buy(g,"shirt_olive","cho_cau_nho").ok)
	assert(g.s.cash == 910000)
	assert(Wardrobe.buy(g,"cut_neat","tiem_toc").ok)
	assert(Wardrobe.buy(g,"dye_brown","tiem_toc").ok)
	assert(g.s.cash == 790000 and is_equal_approx(g.clock(),9.75))
	assert(g.s.hair_style == "neat" and g.s.appearance.hair == "604331")
	scene.hud._open_wardrobe()
	assert(scene.hud.blocking())
	var start: Vector3 = scene.player.position
	scene._target = start + Vector3(2,0,0)
	for i in range(5):
		await physics_frame
	assert(scene.player.position.is_equal_approx(start))
	var panel = scene.hud._wardrobe
	assert(panel.find_children("*","ColorPickerButton",true,false).is_empty())
	for button in panel.inventory.find_children("*","Button",true,false):
		if button.text.begins_with("Áo caro rêu"):
			button.pressed.emit()
	assert(panel.selected == "shirt_olive")
	panel.equip_button.pressed.emit()
	assert(g.s.equipped.shirt == "shirt_olive" and g.s.appearance.shirt == "64735a")
	assert(g.s.cash == 790000)
	var reload := Logic.new()
	reload.s = JSON.parse_string(JSON.stringify(g.s))
	reload.migrate_save()
	assert(reload.s.inventory.size() == g.s.inventory.size() and reload.s.equipped.shirt == "shirt_olive")
	assert(reload.s.inventory.shirt_olive.color == "64735a" and int(reload.s.inventory.shirt_olive.price) == 90000)
	assert(reload.s.hair_style == "neat")
	reload.s.erase("inventory")
	reload.s.erase("equipped")
	reload.s.erase("hair_style")
	reload.migrate_save()
	assert(reload.s.inventory.starter_shirt.color == "64735a")
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/an-wardrobe-preview.png")
	scene.hud._cancel_wardrobe()
	await process_frame
	scene._target = start + Vector3(2,0,0)
	for i in range(20):
		await physics_frame
	assert(scene.player.walking)
	scene._target = null
	for i in range(20):
		await physics_frame
	assert(scene.player.animation.current_animation == scene.player.idle_clip)
	scene.player.position = scene.door_of("tiem_toc")
	scene.hud.open_location("tiem_toc")
	scene.hud._buy_style("dye_ash")
	assert(g.s.appearance.hair == "706961" and g.s.cash == 690000)
	scene.player.position = scene.door_of("cho_cau_nho")
	scene.hud.open_location("cho_cau_nho")
	scene.hud._buy_style("pants_charcoal")
	assert(g.s.inventory.has("pants_charcoal") and g.s.cash == 550000)
	scene.player.position += Vector3(10,0,0)
	scene.hud._buy_style("pants_indigo")
	assert(not g.s.inventory.has("pants_indigo"))
	print("An integration PASS: shop hours, money, duplicate prevention, equip UI, salon, save migration, movement and animation")
	quit()
