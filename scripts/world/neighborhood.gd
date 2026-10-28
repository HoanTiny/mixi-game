extends RefCounted
## Modular street architecture: deep shopfronts, upstairs rooms, verandas and roofs.
var world
var parent: Node3D
var rng := RandomNumberGenerator.new()
var plaster: Material
var faded: Material
const PLASTER := preload("res://assets/materials/aged-plaster.png")

func build(owner_world, holder: Node3D, id: String, loc: Dictionary) -> void:
	world = owner_world
	parent = holder
	rng.seed = abs(id.hash())
	var x := float(loc.x)
	var size: Vector3 = loc.size
	var w := size.x
	var depth := size.z
	var home := id == "xom_bo_me"
	var floors := 2 if size.y > 4.0 else 1
	var h := 3.05 * floors
	var bays := maxi(1,roundi(w/3.8))
	var bw := w / bays
	plaster = wall_material(Color("a5a08e") if home else Color(loc.color).lerp(Color("8d897b"),0.7))
	faded = wall_material(Color("9b998c"))
	# Building mass is behind the arcade; front openings remain genuinely recessed.
	box(Vector3(w,h,depth-0.85),Vector3(x,0,-5-depth/2-0.425),Color.WHITE,plaster)
	box(Vector3(w+0.15,0.22,depth+0.5),Vector3(x,0,-5-depth/2+0.15),Color("77786c"))
	for bay in range(bays):
		var bx := x-w/2+bw*(bay+0.5)
		var panel_mat := plaster if bay%3 != 1 else faded
		for floor_index in range(floors):
			var y := float(floor_index)*3.05+0.22
			# A pier at each side frames a 55cm-deep opening.
			for side in [-1.0,1.0]:
				box(Vector3(0.25,2.83,0.8),Vector3(bx+side*(bw/2-0.125),y,-5.4),Color.WHITE,panel_mat)
			box(Vector3(bw,0.55,0.8),Vector3(bx,y+2.3,-5.4),Color.WHITE,panel_mat)
			box(Vector3(bw-0.45,2.3,0.05),Vector3(bx,y,-5.84),Color("252c29"))
			if home or floor_index > 0:
				room_front(bx,y,bw,bay,floor_index,panel_mat)
			else:
				shop_front(bx,y,bw,id,bay)
		# Raised balcony, individual weathered door plates and railings.
		if floors > 1:
			box(Vector3(bw+0.08,0.16,1.15),Vector3(bx,3.12,-5.0),Color("777b70"))
			if home or bay%2==0:
				rail(bx,3.3,-4.47,bw-0.12)
				pot(Vector3(bx-bw*0.3,3.29,-4.7),0.16)
				pot(Vector3(bx+bw*0.28,3.29,-4.7),0.12)
		# Stained foot of wall and narrow structural band between floors.
		box(Vector3(bw-0.12,0.25,0.08),Vector3(bx,0.2,-5.0),Color("5c6254"))
	box(Vector3(w+0.1,0.2,0.25),Vector3(x,3.02,-4.95),Color("8c8b7b"))
	# Corrugated lean-to roof, dark eaves and slender awning brackets.
	roof(x,h+0.16,-5-depth/2,w+0.65,depth+0.65,Color("696a5c"))
	if home:
		roof(x,2.72,-4.77,w+0.3,1.3,Color("5c6359"))
		laundry(x,3.65,w)
	else:
		for bay in range(bays):
			var bx := x-w/2+bw*(bay+0.5)
			roof(bx,2.7,-4.7,bw-0.1,1.45,Color("5c685e") if bay%2==0 else Color("736453"))
	# Narrow drainpipe with elbows, meter box and wall cable.
	var px := x+w/2-0.28
	pipe(Vector3(px,0.25,-4.91),Vector3(px,h+0.2,-4.91),0.045,Color("656c66"))
	box(Vector3(0.3,0.42,0.16),Vector3(x-w/2+0.5,1.5,-4.96),Color("777b70"))
	pipe(Vector3(x-w/2,2.48,-4.94),Vector3(x+w/2,2.48,-4.94),0.013,Color("292e28"))
	# Small sign integrated with the facade rather than floating over the roof.
	sign_text(str(loc.name).to_upper(),Vector3(x,2.52,-3.97),minf(w*0.72,6.5),0.43,Color("404c42"),28)
	if home:
		sign_text("PHÒNG TRỌ  •  LỐI VÀO",Vector3(x,1.95,-4.83),1.65,0.22,Color("605947"),15)
	for side in [-1.0,1.0]:
		pot(Vector3(x+side*(w/2-0.6),0.2,-4.55),0.24)
	bake_static_meshes()

## Merge the static architecture by material; signs and interaction bodies stay separate.
func bake_static_meshes() -> void:
	var groups := {}
	var sources := []
	for child in parent.get_children():
		if not child is MeshInstance3D:
			continue
		var mat: Material = child.material_override
		var key := mat.get_instance_id()
		if not groups.has(key):
			var builder := SurfaceTool.new()
			builder.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[key] = {"builder": builder, "material": mat}
		groups[key].builder.append_from(child.mesh,0,child.transform)
		sources.append(child)
	for key in groups:
		var merged := MeshInstance3D.new()
		merged.name = "FacadeBatch"
		merged.mesh = groups[key].builder.commit()
		merged.material_override = groups[key].material
		parent.add_child(merged)
	for child in sources:
		child.free()

func wall_material(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = PLASTER
	mat.albedo_color = tint.lightened(0.16)
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE*0.32
	mat.roughness = 0.98
	return mat

func box(size: Vector3,pos: Vector3,color: Color,mat: Material = null) -> MeshInstance3D:
	var mesh: MeshInstance3D = world._block(size,pos,color,parent)
	if mat != null:
		mesh.material_override = mat
	return mesh

func room_front(x: float,y: float,width: float,bay: int,level: int,mat: Material) -> void:
	var door_x := x-width*0.22
	var window_x := x+width*0.22
	box(Vector3(width-0.5,2.3,0.16),Vector3(x,y,-5.7),Color.WHITE,mat)
	box(Vector3(0.87,2.12,0.15),Vector3(door_x,y,-5.51),Color("303b36"))
	for side in [-1.0,1.0]:
		box(Vector3(0.055,2.15,0.13),Vector3(door_x+side*0.45,y,-5.4),Color("807c69"))
	box(Vector3(0.95,0.07,0.13),Vector3(door_x,y+2.12,-5.4),Color("807c69"))
	box(Vector3(0.7,0.92,0.04),Vector3(door_x,y+0.12,-5.41),Color("48534a"))
	for i in range(7):
		box(Vector3(0.7,0.06,0.04),Vector3(door_x,y+1.1+i*0.12,-5.41),Color("667062"))
	box(Vector3(0.035,0.15,0.06),Vector3(door_x+0.3,y+0.9,-5.32),Color("b0a88b"))
	box(Vector3(1.05,0.1,0.5),Vector3(door_x,y,-5.32),Color("999783"))
	window(window_x,y+1.05,0.95,1.05)
	if level > 0 and bay%2==1:
		box(Vector3(0.67,0.46,0.38),Vector3(window_x,y+0.42,-5.25),Color("b2b09b"))
		for i in range(6):
			box(Vector3(0.54,0.02,0.03),Vector3(window_x,y+0.49+i*0.05,-5.04),Color("505b50"))
	var plate: Label3D = world._label3d("%02d" % (level*4+bay+1),Vector3(door_x,y+2.22,-5.38),18)
	plate.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	plate.no_depth_test = false
	plate.outline_size = 1
	parent.add_child(plate)

func window(x: float,y: float,width: float,height: float) -> void:
	box(Vector3(width+0.14,height+0.14,0.15),Vector3(x,y-0.07,-5.5),Color("a5a08b"))
	box(Vector3(width,height,0.1),Vector3(x,y,-5.39),Color("303a35"))
	# Uneven curtains behind crossed metal bars.
	for side in [-1.0,1.0]:
		box(Vector3(width*0.28,height*0.91,0.015),Vector3(x+side*width*0.3,y+0.03,-5.32),Color("8c8876"))
	for i in range(4):
		box(Vector3(0.025,height,0.025),Vector3(x-width*0.4+i*width*0.27,y,-5.22),Color("6e786d"))
	box(Vector3(width,0.035,0.04),Vector3(x,y+height*0.52,-5.21),Color("6e786d"))
	box(Vector3(width+0.3,0.1,0.32),Vector3(x,y-0.12,-5.23),Color("96927f"))

func shop_front(x: float,y: float,width: float,id: String,bay: int) -> void:
	# Visible rear shelves and an open roll-up shutter reveal depth inside shops.
	for shelf_y in [0.65,1.3,1.95]:
		box(Vector3(width-0.65,0.055,0.35),Vector3(x,y+shelf_y,-5.73),Color("797363"))
		for item in range(5):
			var shade := Color("8d826b").darkened(rng.randf_range(0,0.35))
			box(Vector3(0.2,0.22+rng.randf()*0.15,0.2),Vector3(x-width*0.3+item*width*0.15,y+shelf_y+0.055,-5.69),shade)
	for i in range(6):
		box(Vector3(width-0.48,0.075,0.12),Vector3(x,y+1.94+i*0.06,-5.06),Color("76796d"))
	for side in [-1.0,1.0]:
		box(Vector3(0.07,2.35,0.12),Vector3(x+side*(width/2-0.25),y,-5.06),Color("555e54"))
	box(Vector3(width*0.65,0.72,0.48),Vector3(x,y,-5.35),Color("655d4e"))
	box(Vector3(width*0.68,0.055,0.55),Vector3(x,y+0.72,-5.35),Color("a19d87"))
	if id == "com_hanh":
		sign_text("CƠM NHÀ  •  CANH NÓNG",Vector3(x,1.45,-5.01),width*0.72,0.32,Color("665b43"),18)
	elif id == "tiem_sau":
		for j in range(3):
			pipe(Vector3(x-0.45+j*0.45,y+0.78,-5.22),Vector3(x-0.45+j*0.45,y+1.05,-5.22),0.055,Color("899185"))
	elif bay%2==0:
		box(Vector3(0.45,0.5,0.4),Vector3(x+width*0.3,y,-4.98),Color("807154"))

func roof(x: float,y: float,z: float,width: float,depth: float,color: Color) -> void:
	var panel := box(Vector3(width,0.075,depth),Vector3(x,y,z),color)
	panel.rotation.x = -0.08
	for i in range(int(width/0.16)):
		var rib := box(Vector3(0.027,0.035,depth),Vector3(x-width/2+i*0.16,y+0.055,z),color.lightened(0.07))
		rib.rotation.x = -0.08
	box(Vector3(width,0.14,0.09),Vector3(x,y-depth*0.04,z+depth/2),color.darkened(0.3))
	for side in [-1.0,1.0]:
		pipe(Vector3(x+side*(width/2-0.15),y-0.6,z-0.25),Vector3(x+side*(width/2-0.15),y,z+depth/2),0.025,Color("424b42"))

func rail(x: float,y: float,z: float,width: float) -> void:
	for rail_y in [0.1,0.8]:
		pipe(Vector3(x-width/2,y+rail_y,z),Vector3(x+width/2,y+rail_y,z),0.025,Color("414b42"))
	for i in range(int(width/0.18)+1):
		pipe(Vector3(x-width/2+i*0.18,y,z),Vector3(x-width/2+i*0.18,y+0.8,z),0.016,Color("4c574c"))

func pipe(a: Vector3,b: Vector3,radius: float,color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = world._mat(color)
	parent.add_child(node)
	node.position = (a+b)*0.5
	var direction := (b-a).normalized()
	var axis := Vector3.UP.cross(direction)
	if axis.length() > 0.0001:
		node.quaternion = Quaternion(axis.normalized(),acos(clampf(Vector3.UP.dot(direction),-1,1)))

func pot(pos: Vector3,radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius*0.7
	mesh.height = radius*1.8
	mesh.radial_segments = 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = world._surface(Color("796451"))
	node.position = pos+Vector3(0,radius*0.9,0)
	parent.add_child(node)
	for i in range(7):
		var angle := i*2.4
		var tip := pos+Vector3(sin(angle)*radius*1.3,radius*(2.8+rng.randf()),cos(angle)*radius*1.3)
		pipe(pos+Vector3(0,radius*1.7,0),tip,0.016,Color("576047"))
		var leaf := box(Vector3(radius*0.65,0.018,radius*1.5),tip,Color("59674d"))
		leaf.rotation = Vector3(-0.35,angle,0.35)

func laundry(x: float,y: float,width: float) -> void:
	pipe(Vector3(x-width*0.42,y,-4.28),Vector3(x+width*0.42,y,-4.28),0.009,Color("30372f"))
	for i in range(6):
		var px := x-width*0.33+i*width*0.13
		var cloth := box(Vector3(0.38,0.58,0.025),Vector3(px,y-0.6,-4.28),Color("8e8a78").darkened((i%3)*0.15))
		cloth.rotation.z = (i%3-1)*0.07

func sign_text(text: String,pos: Vector3,width: float,height: float,color: Color,font_size: int) -> void:
	box(Vector3(width,height,0.08),pos-Vector3(0,height/2,0),color)
	var label: Label3D = world._label3d(text,pos+Vector3(0,0,0.05),font_size)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.outline_size = 1
	label.modulate = Color("d5cdb3")
	parent.add_child(label)
