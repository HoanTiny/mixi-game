extends SceneTree
## Full Hanoi story route audit. Run --headless --path . -s tests/city_routes.gd
## -- --demo (without --street-demo). Uses no rendering or save files.
const City := preload("res://scripts/world/real_city.gd")
const SOURCE_MAP := "res://data/maps/hn_pho_co.json"
const SOURCE_STORY := "res://data/maps/hn_pho_co_story.json"
var failures: Array[String] = []
var routes := 0
var longest := 0.0
var longest_label := ""

func check(ok: bool, message: String) -> void:
	if not ok and not failures.has(message):
		failures.append(message)
		print("FAIL ",message)

func audit(city, a: Vector2, z: Vector2, label: String) -> void:
	routes+=1
	var path: PackedVector2Array=city.path(a,z)
	check(path.size()>=2,"No route: "+label)
	if path.size()<2:
		return
	check(path[0].distance_to(a)<0.05,"Start snapped: "+label+" "+str(a)+" -> "+str(path[0]))
	check(path[-1].distance_to(z)<0.05,"Destination snapped: "+label+" "+str(z)+" -> "+str(path[-1]))
	var total:=0.0
	for segment in range(1,path.size()):
		var length:=path[segment-1].distance_to(path[segment])
		total+=length
		var steps:=maxi(1,ceili(length/0.2))
		for step in range(steps+1):
			var sample:=path[segment-1].lerp(path[segment],float(step)/steps)
			if not city.walkable(sample):
				check(false,"Blocked segment: "+label+" at "+str(sample))
				return
	if total>longest:
		longest=total
		longest_label=label

func local_point(plot: Dictionary,p: Vector2) -> Vector2:
	var n: Vector2=plot.normal
	return (plot.center as Vector2)+Vector2(n.y,-n.x)*p.x+n*p.y

func _initialize() -> void:
	var hashes: Array[String]=[FileAccess.get_sha256(SOURCE_MAP),FileAccess.get_sha256(SOURCE_STORY)]
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE_STORY))
	var city:=City.new("hn_pho_co")
	check(not city.pilot_active,"Audit must run on the normal full map")
	check(city.locs.size()==19,"Expected all 19 story locations")
	check(city.story.locations==source.locations,"Source location coordinates were overridden")
	var ids: Array=city.locs.keys()
	ids.sort()
	for id in ids:
		var door: Vector2=city.loc_door(id)
		check(city.walkable(door),"Door blocked: "+id+" at "+str(door))
		check(city.nearest_walkable(door).distance_to(door)<0.05,"Door needs snapping: "+id)
	# Both directions catch asymmetric first/last path smoothing around doors.
	for start in ids:
		for finish in ids:
			if start!=finish:
				audit(city,city.loc_door(start),city.loc_door(finish),start+" -> "+finish)
	# Stratified samples from each named delivery street, including each end and
	# middle address, so the distant bank is included rather than only nearby homes.
	var streets: Dictionary={}
	for home in city.homes:
		var address:=str(home.address)
		var street:=address.substr(address.find(" ")+1)
		if not streets.has(street):
			streets[street]=[]
		streets[street].append(home)
	var samples:=0
	for street in streets:
		var list: Array=streets[street]
		var picked: Dictionary={}
		for i in [0,list.size()/2,list.size()-1]:
			if picked.has(int(i)):
				continue
			picked[int(i)]=true
			var home: Dictionary=list[int(i)]
			check(city.walkable(home.pos),"Delivery home blocked: "+str(home.address))
			audit(city,city.loc_door("com_hanh"),home.pos,"delivery "+str(home.address))
			samples+=1
	check(city.has_courtyard("xom_bo_me"),"Normal-map home courtyard is not active")
	var plot: Dictionary=city.locs.xom_bo_me
	var points:= {"entry":Vector2(0,-1.5),"passage":Vector2(0,-3.0),"court":Vector2(0,-6),"court_left":Vector2(-2,-6),"court_right":Vector2(2,-6)}
	for key in points:
		var point:=local_point(plot,points[key])
		check(city.walkable(point),"Home "+str(key)+" blocked at "+str(point))
		check(is_equal_approx(city.ground_y(point),0.14),"Home slab height incorrect: "+str(key))
		audit(city,city.loc_door("xom_bo_me"),point,"home door -> "+str(key))
		audit(city,point,city.loc_door("com_hanh"),str(key)+" -> food")
	for rect in city.location_blockers("xom_bo_me"):
		var point:=local_point(plot,rect.get_center())
		check(not city.walkable(point),"Private room/rear wall passable: "+str(rect)+" at "+str(point))
	check(is_zero_approx(city.ground_y(city.loc_door("xom_bo_me"))),"Street outside home was raised")
	check(hashes==[FileAccess.get_sha256(SOURCE_MAP),FileAccess.get_sha256(SOURCE_STORY)],"Source files changed during route audit")
	print("CITY_ROUTES ","PASS" if failures.is_empty() else "FAIL"," locations=",ids.size()," routes=",routes," homes=",city.homes.size()," sampled_homes=",samples," streets=",streets.size()," longest_m=",snappedf(longest,0.1)," longest=",longest_label," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
