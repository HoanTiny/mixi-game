extends SceneTree
const City := preload("res://scripts/world/real_city.gd")
const Kit := preload("res://scripts/architecture/street_kit.gd")
const Fronts := preload("res://scripts/architecture/story_fronts.gd")
const Street := preload("res://scripts/world/street_prototype.gd")
const Cache := preload("res://scripts/architecture/front_cache.gd")
func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own(child,owner_node)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var city := City.new("hn_pho_co")
	DirAccess.make_dir_recursive_absolute("res://assets/architecture/baked")
	for id in Street.LOCATIONS:
		if not city.locs.has(id): continue
		var p: Dictionary = city.locs[id]
		var seed := int(p.get("seed",-1))
		if seed < 0: seed = Street.LOCATIONS.find(id)
		var node := Node3D.new()
		node.name = "BakedFront"
		var result: Dictionary
		if id in Street.PRIMARY:
			result = Kit.build(node,{"com_hanh":"restaurant","tiem_sau":"repair","xom_bo_me":"lodging"}[id],float(p.w),float(p.d),seed)
		else: result = Fronts.build(node,id,float(p.w),float(p.d),seed)
		for key in result:
			if result[key] is Node: result[key] = node.get_path_to(result[key])
		node.set_meta("kit",result)
		node.set_meta("signature",[Cache.VERSION,float(p.w),float(p.d),seed])
		own(node,node)
		var packed := PackedScene.new()
		assert(packed.pack(node) == OK)
		assert(ResourceSaver.save(packed,"res://assets/architecture/baked/%s.scn" % id,ResourceSaver.FLAG_COMPRESS) == OK)
		print("Baked ",id)
		node.free()
	quit()
