extends SceneTree
## Regression for foreground roofs hiding An at normal street-camera distance.
## No renderer, save data or source-map mutations are needed.
const City := preload("res://scripts/world/real_city.gd")
const Area := preload("res://scripts/realmap/area_builder.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("FAIL ", message)

func _run() -> void:
	var city := City.new("hn_pho_co")
	var original: Array = city.data.buildings.map(func(b): return b.poly.duplicate())
	var area := Area.new()
	area.street_upgrade = true
	area.show_labels = false
	area.dress_opts = {"radius":INF,"label_radius":0.0,"wires":false}
	root.add_child(area)
	area.build(city.data,city.clip,city.grid)
	var affected := 0
	for id in city.locs:
		var point: Vector2 = city.locs[id].center + city.locs[id].normal * (city.door_out + 1.2)
		var pos := Vector3(point.x,0,point.y)
		var cam := pos + Vector3(0,9.6,11).lerp(Vector3(0,16,18),0.12)
		area.reset_cut()
		# Even one high-refresh-rate frame must reveal An, rather than requiring
		# the screenshot or player to wait 0.5–2 seconds for tall roofs to descend.
		area.update_cut(cam,pos,1.0/240.0)
		for idx in area._cut_polys.size():
			var target := Area.ray_cap(area._cut_polys[idx],area._cut_tops[idx],cam,pos,Area.STREET_BASE_H)
			if target >= area._cut_tops[idx]:
				continue
			affected += 1
			check(area._cut_now.has(idx),id+": candidate missing from cut spatial index")
			var actual := float(area._cut_now.get(idx,Area.CUT_NONE))
			check(actual <= target+0.001,id+": new blocker remains above its safe height")
			check(is_equal_approx(area._cut_img.get_pixel(idx%Area.CAPS_W,idx/Area.CAPS_W).r,actual),id+": shader cap metadata disagrees with CPU")
			for lb in area._cut_labels.get(idx,[]):
				check((lb[0] as Label3D).visible == (actual >= float(lb[1])),id+": floating label outlived its building cap")
		# Moving the camera away restores the structure gradually, then fully.
		var previous: Dictionary = area._cut_now.duplicate()
		area.update_cut(Vector3(10000,10,10010),Vector3(10000,0,10000),1.0/60.0)
		for idx in previous:
			var restored := float(area._cut_now.get(idx,area._cut_tops[idx]))
			check(restored >= float(previous[idx]),id+": restoration lowered a building")
			check(restored <= float(previous[idx])+float(Area.CUT.speed)/60.0+0.001,id+": restoration jumped instead of easing")
	area.reset_cut()
	check(area._cut_now.is_empty(),"Overview reset left active building caps")
	for idx in area._cut_tops.size():
		check(area._cut_img.get_pixel(idx%Area.CAPS_W,idx/Area.CAPS_W).r == Area.CUT_NONE,"Overview reset did not restore a cap")
	for i in original.size():
		check(original[i] == city.data.buildings[i].poly,"Cutaway changed a collision footprint")
	# A neighbouring plot touching An's silhouette must sit below knee height.
	var near := PackedVector2Array([Vector2(-1,-1),Vector2(1,-1),Vector2(1,2),Vector2(-1,2)])
	check(Area.ray_cap(near,12,Vector3(0,10,12),Vector3.ZERO,Area.STREET_BASE_H)<0.5,"Street foundation still hides legs")
	check(Area.ray_cap(near,12,Vector3(0,10,12),Vector3.ZERO)==Area.BASE_H,"Legacy cutaway height changed")
	print("CITY_CUTAWAY ","PASS" if failures.is_empty() else "FAIL"," locations=",city.locs.size()," occluders=",affected," failures=",failures.size())
	area.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
