extends SceneTree
const City := preload("res://scripts/world/real_city.gd")
const Area := preload("res://scripts/realmap/area_builder.gd")
const Facades := preload("res://scripts/architecture/city_facades.gd")
const Trees := preload("res://scripts/architecture/city_trees.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := City.new("hn_pho_co")
	assert(not city.pilot_active,"Run this test without --street-demo to audit full-map coverage")
	var footprint_before := []
	for house in city.data.buildings:
		footprint_before.append([house.poly.duplicate(),house.height])
	var homes_before: Array = city.homes.duplicate(true)
	var area := Area.new()
	area.street_upgrade=true
	area.show_labels=false
	area.dress_opts={"radius":INF,"label_radius":0.0,"wires":false}
	root.add_child(area)
	var start := Time.get_ticks_msec()
	area.build(city.data,city.clip,city.grid)
	var c: Dictionary=area.architecture_counts
	assert(c.total==city.data.buildings.size(),"Every background plot must be accounted for")
	assert(c.total==c.street_buildings+c.background+c.heritage+c.elevated+c.short,"Coverage classification must be exhaustive")
	if city.layout_version >= 2:
		# Compact topology deliberately removes empty filler blocks. Keep the
		# authored density bounded while still requiring frontage coverage below.
		assert(c.total >= 100 and c.total <= 300, "Compact district filler budget regressed")
		assert(c.street_buildings >= 100, "Compact streets lost their inhabited edges")
	else:
		assert(c.street_buildings>500,"Full street coverage was not built")
	assert(c.facades>=c.street_buildings,"Street building lacks a rendered frontage")
	assert(c.doors>=c.facades and c.windows>0,"Missing physical openings")
	assert(c.trees==area.counts.trees,"Tree rendering disagrees with coverage")
	assert(c.trees>30 if city.layout_version >= 2 else c.trees>100,"Tree rollout missing")
	assert(c.detail_batches<160,"Geometry must stay batched rather than per house")
	assert(city.homes==homes_before,"Delivery addresses changed during visual upgrade")
	assert(footprint_before.size()==city.data.buildings.size())
	for i in footprint_before.size():
		assert(footprint_before[i][0]==city.data.buildings[i].poly,"Visual upgrade changed collision footprint")
		assert(footprint_before[i][1]==city.data.buildings[i].height,"Visual height override leaked into map data")
	var triangle_count:=0
	for child in area.get_children():
		if child is MeshInstance3D and child.material_override==area.building_mat:
			for surface in child.mesh.get_surface_count():
				var arrays: Array=child.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				triangle_count+=vertices.size()/3
				for v in vertices:
					assert(v.is_finite(),"Nonfinite architecture vertex")
	assert(triangle_count<600000,"City architecture triangle budget exceeded")
	for mesh in [Trees.trunk(),Trees.crown()]:
		assert(mesh.get_surface_count()==1,"Tree must remain one shared mesh")
		assert(mesh.get_aabb().size.x>0.1 and mesh.get_aabb().size.y>0.1)
	area.update_cut(Vector3(0,14,18),Vector3(0,0,0),0.1)
	area.reset_cut()
	print("PASS city architecture: ",JSON.stringify(c)," triangles=",triangle_count," build_ms=",Time.get_ticks_msec()-start)
	area.queue_free()
	await process_frame
	quit()
