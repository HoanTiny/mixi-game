extends Node3D
## Proportioned, articulated residents. No dependency on gameplay or save data.
var rig: Node3D
var limbs := {}
var knees := {}
var elbows := {}
var gait := 0.0
var motion := 0.0
var seated := false
var elder := false
var phase := 0.0
var _cloth: Material
var _trousers: Material
var _skin: Material
const FABRIC := preload("res://scripts/world/fabric.gdshader")

func setup(shirt: Color, pants: Color, identity := "resident") -> void:
	elder = identity == "Bà Tư"
	phase = float(abs(identity.hash()) % 100) * 0.1
	rig = Node3D.new()
	add_child(rig)
	var female := identity in ["Bà Tư", "Linh", "Cô Duyên", "Chị Hạnh", "Trâm"]
	if identity == "Linh":
		shirt = Color("b2a492")
	elif identity == "Bà Tư":
		shirt = Color("706b77")
	elif identity == "Cô Duyên":
		shirt = Color("765b52")
	_cloth = fabric(shirt.lerp(Color("686659"), 0.25))
	_trousers = fabric(pants.lerp(Color("4b4942"), 0.2))
	_skin = material(Color("b8987c") if not elder else Color("aa937e"))
	var dark := material(Color("282922"))
	var hair := material(Color("5b5b52") if elder else Color("282820"))
	# Waist, ribcage, shoulders and neck are shaped separately from the arms.
	form(rig, Vector3.ZERO, [Vector3(0.85,0.17,0.12),Vector3(0.94,0.18,0.12),Vector3(1.08,0.175,0.115),Vector3(1.27,0.225,0.14),Vector3(1.38,0.225,0.12),Vector3(1.43,0.13,0.095)], _cloth)
	form(rig, Vector3.ZERO, [Vector3(0.79,0.15,0.115),Vector3(0.88,0.175,0.12),Vector3(0.95,0.17,0.12)], _trousers)
	ellipsoid(rig,Vector3(0,1.46,0),Vector3(0.065,0.085,0.065),_skin)
	form(rig, Vector3.ZERO, [Vector3(1.49,0.065,0.065),Vector3(1.53,0.088,0.09),Vector3(1.60,0.105,0.095),Vector3(1.68,0.10,0.09),Vector3(1.73,0.07,0.065),Vector3(1.745,0.015,0.02)], _skin)
	# Hair follows the skull; ears, bridge of nose and brow give a readable profile.
	form(rig,Vector3(0,0,-0.014),[Vector3(1.65,0.105,0.087),Vector3(1.71,0.094,0.083),Vector3(1.75,0.055,0.05),Vector3(1.76,0.002,0.002)],hair)
	ellipsoid(rig,Vector3(0,1.605,0.097),Vector3(0.023,0.038,0.035),_skin)
	for side in [-1.0,1.0]:
		ellipsoid(rig,Vector3(side*0.105,1.605,0),Vector3(0.022,0.037,0.018),_skin)
		ellipsoid(rig,Vector3(side*0.042,1.635,0.087),Vector3(0.017,0.007,0.006),dark)
		var hip := Node3D.new()
		hip.position = Vector3(side*0.095,0.88,0)
		rig.add_child(hip)
		limbs["leg"+str(side)] = hip
		form(hip,Vector3.ZERO,[Vector3(-0.43,0.07,0.075),Vector3(-0.25,0.085,0.085),Vector3(-0.06,0.095,0.10),Vector3(0.025,0.08,0.085)],_trousers)
		var knee := Node3D.new()
		knee.position.y = -0.41
		hip.add_child(knee)
		knees[side] = knee
		form(knee,Vector3.ZERO,[Vector3(-0.38,0.057,0.058),Vector3(-0.28,0.066,0.065),Vector3(-0.12,0.077,0.072),Vector3(0.02,0.07,0.075)],_trousers)
		ellipsoid(knee,Vector3(0,-0.38,0.065),Vector3(0.078,0.07,0.15),dark)
		# Sole and trouser folds.
		ellipsoid(knee,Vector3(0,-0.425,0.06),Vector3(0.079,0.018,0.15),material(Color("48483e")))
		for fold_y in [-0.08,-0.3]:
			form(knee,Vector3.ZERO,[Vector3(fold_y-0.015,0.075,0.074),Vector3(fold_y,0.08,0.078),Vector3(fold_y+0.012,0.071,0.07)],material(pants.lightened(0.045)))
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side*0.235,1.34,0)
		shoulder.rotation.z = side*0.09
		rig.add_child(shoulder)
		limbs["arm"+str(side)] = shoulder
		form(shoulder,Vector3.ZERO,[Vector3(-0.29,0.06,0.065),Vector3(-0.12,0.078,0.08),Vector3(0.015,0.085,0.085)],_cloth)
		var elbow := Node3D.new()
		elbow.position.y = -0.28
		shoulder.add_child(elbow)
		elbows[side] = elbow
		form(elbow,Vector3.ZERO,[Vector3(-0.25,0.04,0.043),Vector3(-0.10,0.055,0.058),Vector3(0.02,0.06,0.06)],_cloth)
		form(elbow,Vector3.ZERO,[Vector3(-0.255,0.046,0.05),Vector3(-0.22,0.048,0.051)],material(shirt.lightened(0.08)))
		ellipsoid(elbow,Vector3(0,-0.305,0.012),Vector3(0.037,0.065,0.026),_skin)
		ellipsoid(elbow,Vector3(-side*0.028,-0.285,0.03),Vector3(0.018,0.034,0.018),_skin)
	# Shirt seam, buttons and breast pockets are actual shallow geometry.
	var stitch := material(shirt.lightened(0.13))
	strip(rig,Vector3(0,1.16,0.141),Vector3(0.014,0.42,0.008),stitch)
	for y in [1.0,1.11,1.22,1.33]:
		ellipsoid(rig,Vector3(0,y,0.15),Vector3(0.008,0.008,0.004),dark)
	for side in [-1.0,1.0]:
		if identity in ["An", "Trâm", "Chú Sáu"]:
			strip(rig,Vector3(side*0.115,1.24,0.139),Vector3(0.085,0.095,0.013),_cloth)
			strip(rig,Vector3(side*0.115,1.282,0.15),Vector3(0.088,0.014,0.012),stitch)
		var collar := strip(rig,Vector3(side*0.067,1.4,0.085),Vector3(0.065,0.09,0.025),stitch)
		collar.rotation.z = side*0.42
	if identity == "An":
		# Worn canvas shoulder bag and cap identify the player at a glance.
		ellipsoid(rig,Vector3(0,1.72,0),Vector3(0.115,0.07,0.105),material(Color("555b4d")))
		ellipsoid(rig,Vector3(0,1.70,0.115),Vector3(0.12,0.012,0.09),material(Color("555b4d")))
		var bag := strip(rig,Vector3(-0.235,0.96,-0.09),Vector3(0.16,0.28,0.26),material(Color("746751")))
		bag.rotation.z = -0.1
		var strap := strip(rig,Vector3(-0.02,1.21,0.158),Vector3(0.035,0.55,0.018),material(Color("564b38")))
		strap.rotation.z = -0.42
	elif female:
		ellipsoid(rig,Vector3(0,1.68,-0.095),Vector3(0.085,0.07,0.07),hair)
	if identity == "Chị Hạnh":
		var apron := material(Color("8d8470"))
		form(rig,Vector3(0,0,0.045),[Vector3(0.63,0.19,0.10),Vector3(0.93,0.19,0.11),Vector3(1.24,0.15,0.125)],apron)
		strip(rig,Vector3(0,0.92,0.165),Vector3(0.2,0.12,0.015),apron)
	if identity == "Linh":
		ellipsoid(rig,Vector3(0,1.18,-0.17),Vector3(0.16,0.23,0.085),material(Color("514a3e")))
	if elder:
		rig.rotation.x = 0.1
		scale = Vector3(0.94,0.91,0.94)
	elif female:
		scale = Vector3(0.92,0.95,0.94)

func animate_motion(speed: float, delta: float) -> void:
	motion = lerpf(motion,clampf(speed / 2.8,0,1),minf(1,delta*10))
	gait += delta * (7.0 if elder else 9.0)

func _process(delta: float) -> void:
	if rig == null:
		return
	phase += delta
	for side in [-1.0,1.0]:
		var wave := sin(gait + (PI if side > 0 else 0))
		limbs["leg"+str(side)].rotation.x = wave * 0.40 * motion if not seated else -1.25
		knees[side].rotation.x = maxf(0,-wave) * 0.65 * motion if not seated else 1.3
		limbs["arm"+str(side)].rotation.x = -wave * 0.28 * motion - 0.08 if not seated else -0.95
		elbows[side].rotation.x = -0.12 - maxf(0,wave)*0.15*motion if not seated else -0.35
	rig.position.y = 0.15 + absf(sin(gait))*0.025*motion + sin(phase*1.6)*0.003

static func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	return mat

static func fabric(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FABRIC
	mat.set_shader_parameter("base_color",color)
	return mat

static func ellipsoid(parent: Node3D,pos: Vector3,radii: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	node.scale = radii
	parent.add_child(node)
	return node

static func strip(parent: Node3D,pos: Vector3,size: Vector3,mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node

static func form(parent: Node3D,pos: Vector3,rings: Array,mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 20
	for row in range(rings.size()-1):
		for segment in range(SEGMENTS):
			for corner in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,0)]:
				var ring: Vector3 = rings[row+corner.x]
				var angle := float(segment+corner.y)/SEGMENTS*TAU
				var slope: float = (rings[row+1].y-rings[row].y) / maxf(0.001,rings[row+1].x-rings[row].x)
				st.set_normal(Vector3(cos(angle),-slope,sin(angle)).normalized())
				st.set_uv(Vector2(float(segment+corner.y)/SEGMENTS,ring.x))
				st.add_vertex(Vector3(cos(angle)*ring.y,ring.x,sin(angle)*ring.z))
	# Cap the garment ends; open rings look like holes at shoulders from above.
	for end in [0,rings.size()-1]:
		var ring: Vector3 = rings[end]
		var normal := Vector3.DOWN if end == 0 else Vector3.UP
		for segment in range(SEGMENTS):
			var a := float(segment)/SEGMENTS*TAU
			var b := float(segment+1)/SEGMENTS*TAU
			var edge_a := Vector3(cos(a)*ring.y,ring.x,sin(a)*ring.z)
			var edge_b := Vector3(cos(b)*ring.y,ring.x,sin(b)*ring.z)
			var verts := [Vector3(0,ring.x,0),edge_b,edge_a] if end == 0 else [Vector3(0,ring.x,0),edge_a,edge_b]
			for vertex in verts:
				st.set_normal(normal)
				st.set_uv(Vector2(vertex.x,vertex.z))
				st.add_vertex(vertex)
	var node := MeshInstance3D.new()
	node.mesh = st.commit()
	node.material_override = mat
	node.position = pos
	parent.add_child(node)
	return node
