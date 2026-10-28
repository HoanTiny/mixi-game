extends RefCounted
## Visual set dressing only. Interaction positions and saved repair steps stay
## in RepairBench so close-up geometry cannot change the puzzle's hit regions.
const WP := preload("res://scripts/work/work_props.gd")

static func blade(parent: Node3D, angle: float) -> void:
	var outline := PackedVector2Array([Vector2(0.04,-0.035),Vector2(0.20,-0.13),Vector2(0.40,-0.15),Vector2(0.49,-0.06),Vector2(0.46,0.08),Vector2(0.28,0.16),Vector2(0.08,0.09)])
	var triangles := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in triangles:
		var p := outline[i]
		st.add_vertex(Vector3(p.x,0.025+p.y*0.12,p.y))
	st.generate_normals()
	var n := MeshInstance3D.new()
	n.mesh=st.commit()
	var mat := WP.plain(Color("7d9690"),0.48)
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	n.material_override=mat; n.rotation.y=angle
	parent.add_child(n)

static func wire(parent: Node3D, a: Vector3, b: Vector3, color: String, radius := 0.017) -> void:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius=radius; mesh.bottom_radius=radius; mesh.height=a.distance_to(b); mesh.radial_segments=8
	n.mesh=mesh; n.material_override=WP.plain(Color(color),0.67)
	n.position=(a+b)*0.5
	parent.add_child(n)
	n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())

static func loop(parent: Node3D, center: Vector3, radius: float, color: String, thickness := 0.015) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius=radius-thickness; mesh.outer_radius=radius+thickness
	mesh.rings=32; mesh.ring_segments=8
	n.mesh=mesh; n.material_override=WP.plain(Color(color),0.44,0.55); n.position=center
	parent.add_child(n)
	return n

static func build(b) -> void:
	var root := Node3D.new()
	b.viewport.add_child(root)
	# A shallow open chassis, copper windings and a removed guard read as a fan,
	# rather than a three-bladed symbol sitting on an empty table.
	if b.kind==0:
		for r in [0.18,0.27,0.38,0.52]: loop(root,Vector3(0.35,0.90,-0.65),r,"747d79",0.012)
		for i in 12:
			var a := i*TAU/12
			wire(root,Vector3(0.35,0.91,-0.65),Vector3(0.35+sin(a)*0.52,0.91,-0.65+cos(a)*0.52),"a0a79d",0.008)
		for i in 10:
			var a := i*TAU/10
			loop(root,Vector3(0.35+sin(a)*0.23,0.72,-0.65+cos(a)*0.23),0.075,"ad784a",0.018)
		var casing: MeshInstance3D = b.box(root,Vector3(0.35,0.59,-0.65),Vector3(1.22,0.08,1.20),"5c6961")
		casing.material_override=WP.tex("rusty_metal_sheet",1.4,Color("83908a"))
	else:
		# Open underside of the kettle: metal heating ring, thermostat, screws.
		for r in [0.38,0.57,0.64]: loop(root,Vector3(0.35,0.84,-0.55),r,"c1c2b7",0.024)
		for i in 3:
			var a := i*TAU/3
			b.cylinder(root,Vector3(0.35+cos(a)*0.53,0.85,-0.55+sin(a)*0.53),0.045,0.05,"535b59")
		b.box(root,Vector3(0.35,0.87,-0.55),Vector3(0.26,0.08,0.23),"9b8965")
		var kettle := WP.kettle()
		root.add_child(kettle); kettle.position=Vector3(-0.82,0.6,-0.88); kettle.scale=Vector3.ONE*1.35
	# Flexible insulated leads instead of straight rectangular bars.
	for side in [-1.0,1.0]:
		var x: float = 0.4+side*0.2
		var points := [Vector3(x,0.77,-0.30),Vector3(x+side*0.15,0.78,-0.15),Vector3(x+side*0.18,0.77,0.07),Vector3(x,0.78,0.25)]
		for i in 3: wire(root,points[i],points[i+1],"99543e" if side<0 else "383e3c")
	# Paper service ticket on the left, visible without covering any drop zone.
	var ticket: MeshInstance3D = b.box(root,Vector3(-1.55,0.57,-1.08),Vector3(1.25,0.012,0.55),"c8b997")
	ticket.rotation.y=-0.06
	for i in 4: b.box(root,Vector3(-1.60,0.579,-1.24+i*0.09),Vector3(0.85 if i>0 else 0.6,0.002,0.008),"8c846e")
	# Cloth, retaining screws and vent slots add scale without hiding the puzzle.
	var cloth: MeshInstance3D = b.box(root,Vector3(2.35,0.57,1.2),Vector3(0.8,0.025,0.35),"728079")
	cloth.rotation.y=0.14
	for i in 5: b.box(root,Vector3(2.08+i*0.12,0.587,1.2),Vector3(0.005,0.003,0.32),"a1a79a")
	for i in 6: b.box(root,Vector3(-0.14+i*0.18,0.614,1.05),Vector3(0.085,0.008,0.10),"192924")
	# Lamp body remains behind the work area; soft pool reinforces the focal point.
	b.cylinder(root,Vector3(2.7,0.6,-1.20),0.17,0.08,"343e3b")
	wire(root,Vector3(2.7,0.62,-1.2),Vector3(2.7,1.55,-1.2),"56615c",0.025)
	wire(root,Vector3(2.7,1.55,-1.2),Vector3(1.7,1.65,-1.15),"56615c",0.025)
	var lamp := OmniLight3D.new()
	lamp.position=Vector3(0.4,2.2,-0.5); lamp.light_color=Color("ffe5b6")
	lamp.light_energy=0.65; lamp.omni_range=4.0; lamp.shadow_enabled=false
	root.add_child(lamp)
