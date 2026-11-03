extends SceneTree
const City := preload("res://scripts/world/real_city.gd")
const Street := preload("res://scripts/world/street_prototype.gd")
const Cache := preload("res://scripts/architecture/front_cache.gd")
const Kit := preload("res://scripts/architecture/street_kit.gd")
const Fronts := preload("res://scripts/architecture/story_fronts.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: run.call_deferred()
func shape(n: Node) -> Array:
	var result := []
	if n is MeshInstance3D:
		result.append([n.name,n.mesh.get_aabb(),n.mesh.get_surface_count()])
	for child in n.get_children(): result.append_array(shape(child))
	return result
func run() -> void:
	var city := City.new("hn_pho_co")
	for id in Street.LOCATIONS:
		var p: Dictionary=city.locs[id]
		var seed := int(p.get("seed",-1))
		if seed<0: seed=Street.LOCATIONS.find(id)
		var cached := Node3D.new()
		var a := Cache.restore(cached,id,float(p.w),float(p.d),seed)
		check(not a.is_empty(),id+": baked geometry available")
		if a.is_empty(): cached.free(); continue
		var generated := Node3D.new()
		var b: Dictionary
		if id in Street.PRIMARY: b=Kit.build(generated,{"com_hanh":"restaurant","tiem_sau":"repair","xom_bo_me":"lodging"}[id],float(p.w),float(p.d),seed)
		else: b=Fronts.build(generated,id,float(p.w),float(p.d),seed)
		check(shape(cached)==shape(generated),id+": mesh bounds and surfaces unchanged")
		for key in ["height","blockers","sign_position","front_occlusion_cut"]:
			check(a.get(key)==b.get(key),id+": "+key+" unchanged")
		for key in ["ground","upper","roof","front_walls","occluding_shell"]:
			check((a.get(key)==null)==(b.get(key)==null),id+": cutaway nodes preserved")
		var invalid := Node3D.new()
		check(Cache.restore(invalid,id,float(p.w)+1.0,float(p.d),seed).is_empty() and invalid.get_child_count()==0,"changed lot rejects stale cache")
		invalid.free(); cached.free(); generated.free()
	print("Front cache parity: failures=",failures)
	quit(0 if failures==0 else 1)
