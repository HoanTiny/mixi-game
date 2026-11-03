extends RefCounted
## Separate functional assemblies; all dimensions are metres. Static fan surfaces
## are merged by material while Rotor remains independently animatable.
const Finish := preload("res://scripts/work/higgsfield_materials.gd")
static var materials: Dictionary = {}

static func mat(color: String, metal := 0.0, rough := 0.65) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [color,metal,rough]
	if not materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color=Color(color); m.metallic=metal; m.roughness=rough
		materials[key]=m
	return materials[key]

static func enamel() -> StandardMaterial3D:
	var m := Finish.surface("appliance_enamel",2.0)
	m.roughness=0.82; m.metallic=0.0; m.metallic_specular=0.12; m.uv1_triplanar=true
	m.albedo_color=Color("bac1b7")
	return m

static func mesh(parent: Node, shape: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh=shape; n.material_override=material; n.position=at; parent.add_child(n)
	return n

static func ellipsoid(parent: Node, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius=0.5; s.height=1.0; s.radial_segments=24; s.rings=12
	var n := mesh(parent,s,material,at); n.scale=size
	return n

static func rod(parent: Node, a: Vector3, b: Vector3, r: float, material: Material) -> MeshInstance3D:
	var s := CylinderMesh.new()
	s.top_radius=r; s.bottom_radius=r; s.height=a.distance_to(b); s.radial_segments=12
	var n := mesh(parent,s,material,(a+b)*0.5)
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return n

static func ring(parent: Node, at: Vector3, radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var s := TorusMesh.new()
	s.inner_radius=radius-thickness; s.outer_radius=radius+thickness; s.rings=32; s.ring_segments=6
	return mesh(parent,s,material,at)

static func box(parent: Node, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var s := BoxMesh.new(); s.size=size
	return mesh(parent,s,material,at)

## Rounded moulded cases with bevelled top/bottom, rather than sharp boxes.
static func case_mesh(size: Vector3, radius: float) -> ArrayMesh:
	var outline: Array[Vector2]=[]
	for corner in 4:
		var sx := 1.0 if corner in [0,3] else -1.0
		var sz := 1.0 if corner in [0,1] else -1.0
		for i in 5:
			var a := corner*PI/2.0+i*PI/8.0
			outline.append(Vector2(sx*(size.x/2-radius)+cos(a)*radius,sz*(size.z/2-radius)+sin(a)*radius))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := [-size.y/2,-size.y/2+minf(radius,size.y*.25),size.y/2-minf(radius,size.y*.25),size.y/2]
	for k in 3:
		for i in outline.size():
			var j := (i+1)%outline.size()
			var a := outline[i]*(0.94 if k==0 else 1.0)
			var b := outline[j]*(0.94 if k==0 else 1.0)
			var c := outline[j]*(0.94 if k==2 else 1.0)
			var d := outline[i]*(0.94 if k==2 else 1.0)
			for p in [Vector3(a.x,levels[k],a.y),Vector3(c.x,levels[k+1],c.y),Vector3(b.x,levels[k],b.y),Vector3(a.x,levels[k],a.y),Vector3(d.x,levels[k+1],d.y),Vector3(c.x,levels[k+1],c.y)]:
				st.set_uv(Vector2(p.x/size.x+.5,p.z/size.z+.5)); st.add_vertex(p)
	for side in [-1.0,1.0]:
		for i in outline.size():
			var a := outline[i]*.94; var b := outline[(i+1)%outline.size()]*.94
			var triangle := [Vector3(0,side*size.y/2,0),Vector3(a.x,side*size.y/2,a.y),Vector3(b.x,side*size.y/2,b.y)]
			if side<0: triangle.reverse()
			for p in triangle:
				st.set_uv(Vector2(p.x/size.x+.5,p.z/size.z+.5)); st.add_vertex(p)
	st.generate_normals()
	return st.commit()

static func casing(parent: Node, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return mesh(parent,case_mesh(size,minf(size.x,size.z)*.16),material,at)

static func fan() -> Node3D:
	var n := Node3D.new()
	var paint := enamel(); var steel := mat("8b918a",.75,.42); var rubber := mat("303733")
	ellipsoid(n,Vector3(0,.035,-.015),Vector3(.33,.07,.27),paint)
	for x in [-.1,.1]: ellipsoid(n,Vector3(x,.009,0),Vector3(.07,.018,.08),rubber)
	rod(n,Vector3(0,.04,-.04),Vector3(0,.36,-.065),.026,paint)
	ellipsoid(n,Vector3(0,.40,-.065),Vector3(.16,.16,.20),paint)
	rod(n,Vector3(0,.40,-.16),Vector3(0,.40,.10),.015,steel)
	for i in 9:
		var a := i*TAU/9
		rod(n,Vector3(sin(a)*.06,.40+cos(a)*.06,-.15),Vector3(sin(a)*.06,.40+cos(a)*.06,-.13),.006,rubber)
	for z in [-.01,.09]:
		for r in [.07,.12,.17,.205]:
			var hoop := ring(n,Vector3(0,.40,z),r,.0024,steel); hoop.rotation.x=PI/2
		for i in 20:
			var a := TAU*i/20
			var start := Vector3(sin(a)*.028,.40+cos(a)*.028,z+(.02 if z>0 else -.02))
			var mid := Vector3(sin(a)*.12,.40+cos(a)*.12,z+(.012 if z>0 else -.012))
			rod(n,start,mid,.0018,steel)
			rod(n,mid,Vector3(sin(a)*.205,.40+cos(a)*.205,z),.0018,steel)
	var rotor := Node3D.new(); rotor.name="Rotor"; n.add_child(rotor); rotor.position=Vector3(0,.40,.04)
	for i in 3:
		var a := TAU*i/3
		var blade := ellipsoid(rotor,Vector3(sin(a)*.095,cos(a)*.095,0),Vector3(.10,.19,.014),mat("c4bea0",.05,.49))
		blade.rotation=Vector3(.14,0,-a+.28)
	ellipsoid(n,Vector3(0,.40,.115),Vector3(.065,.065,.022),paint)
	for i in 3: casing(n,Vector3(-.05+i*.05,.068,.06),Vector3(.035,.012,.035),mat("d0c9ad"))
	var cable := [Vector3(0,.035,-.12),Vector3(.15,.015,-.18),Vector3(.25,.015,-.10),Vector3(.26,.015,.02)]
	for i in 3: rod(n,cable[i],cable[i+1],.004,rubber)
	casing(n,cable[3],Vector3(.028,.022,.04),rubber)
	# Merge static parts into a handful of draw calls. Rotor stays separate.
	var surfaces: Dictionary={}
	for child in n.get_children():
		if child is not MeshInstance3D: continue
		var material: Material=child.material_override
		if not surfaces.has(material):
			var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES); surfaces[material]=st
		surfaces[material].append_from(child.mesh,0,child.transform)
		n.remove_child(child); child.free()
	for material in surfaces: mesh(n,surfaces[material].commit(),material,Vector3.ZERO)
	return n

static func screwdriver(parent: Node) -> Node3D:
	var n := Node3D.new(); parent.add_child(n)
	ellipsoid(n,Vector3(0,.13,0),Vector3(.045,.17,.045),mat("925637",.05,.4))
	for i in 6:
		var a := TAU*i/6
		rod(n,Vector3(sin(a)*.021,.08,cos(a)*.021),Vector3(sin(a)*.021,.18,cos(a)*.021),.002,mat("4e392d"))
	rod(n,Vector3.ZERO,Vector3(0,.07,0),.005,mat("b7bcb8",.8,.3))
	box(n,Vector3(0,.005,0),Vector3(.012,.012,.003),mat("9a9e98",.8,.3))
	return n

static func kettle() -> Node3D:
	var n := Node3D.new()
	var steel := mat("9baba8",.72,.38)
	var black := mat("303a36",0,.70)
	ellipsoid(n,Vector3(0,.145,0),Vector3(.25,.25,.23),steel)
	rod(n,Vector3(0,.02,0),Vector3(0,.05,0),.115,black)
	var lid := Node3D.new(); lid.name="Lid"; n.add_child(lid); lid.position.y=.265
	ellipsoid(lid,Vector3.ZERO,Vector3(.20,.035,.19),steel)
	ellipsoid(lid,Vector3(0,.02,0),Vector3(.045,.025,.04),black)
	var handle := [Vector3(.08,.24,0),Vector3(.16,.25,0),Vector3(.19,.21,0),Vector3(.19,.10,0),Vector3(.15,.065,0),Vector3(.09,.075,0)]
	for i in handle.size()-1: rod(n,handle[i],handle[i+1],.016,black)
	var spout := CylinderMesh.new(); spout.top_radius=.035; spout.bottom_radius=.052; spout.height=.095; spout.radial_segments=20
	var s := mesh(n,spout,steel,Vector3(-.11,.215,0)); s.rotation.z=.80
	var opening := ring(n,Vector3(-.144,.25,0),.029,.004,steel); opening.rotation.z=.80
	ellipsoid(n,Vector3(-.145,.25,0),Vector3(.048,.006,.048),mat("252e2a"))
	casing(n,Vector3(.095,.065,0),Vector3(.047,.02,.04),mat("8e4d33"))
	for z in [-.023,.023]: rod(n,Vector3(.121,.15,z),Vector3(.123,.20,z),.003,mat("c3ccc4",.6))
	return n

static func meter(parent: Node, at: Vector3) -> Node3D:
	var n := Node3D.new(); parent.add_child(n); n.position=at
	casing(n,Vector3.ZERO,Vector3(.49,.16,.70),mat("a4813f",.0,.78))
	casing(n,Vector3(0,.086,0),Vector3(.39,.025,.58),mat("303c38"))
	box(n,Vector3(0,.102,-.15),Vector3(.33,.009,.18),mat("9fae91"))
	rod(n,Vector3(0,.105,.08),Vector3(0,.132,.08),.075,mat("272d29"))
	box(n,Vector3(0,.136,.055),Vector3(.018,.005,.07),mat("d4cbaa"))
	for i in 11:
		var a := TAU*i/12
		var mark := box(n,Vector3(sin(a)*.119,.106,.08+cos(a)*.119),Vector3(.009,.005,.023),mat("cfcbb4")); mark.rotation.y=a
	for i in 3:
		var r := ring(n,Vector3(-.11+i*.11,.104,.24),.024,.007,mat("a05638" if i==2 else "212a26")); r.scale.y=.6
	return n
