extends SceneTree
## Run this external script with --main-pack <exported.pck> -- --demo.
## No dependency on excluded source art, editor imports or other test scripts.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(not FileAccess.file_exists("res://art/higgsfield/runtime-integration.json"), "Source art leaked into export")
	assert(not FileAccess.file_exists("res://assets/characters/hanh/reference-v1.png"), "Reference image leaked into export")
	var factory = load("res://scripts/world/named_character.gd")
	assert(factory.available("HANH"), "Export is missing Hanh's imported model")
	var hero: Node3D = factory.make("HANH")
	root.add_child(hero)
	hero.animate(0.25, 0.0)
	hero.animate(0.25, 1.0)
	assert(hero.skeleton.get_bone_count() == 24)
	for path in ["res://assets/higgsfield/street_food_cart/cart.tscn", "res://scenes/architecture/rice_shop.tscn", "res://scenes/architecture/repair_workshop.tscn", "res://scenes/architecture/lodging_courtyard.tscn"]:
		assert(ResourceLoader.exists(path), "Missing exported asset: " + path)
		var scene: Node = load(path).instantiate()
		assert(scene != null)
		scene.free()
	hero.queue_free()
	await process_frame
	print("ASSET_PACK_PASS: Hanh animated, cart and three architecture scenes loaded, source art excluded")
	quit()
