extends Node3D
## Real-scale workshop vignette, independent of the magnified puzzle geometry.
const Models := preload("res://scripts/work/repair_models.gd")
const An := preload("res://scripts/world/an_character.gd")
var game
var actor: Node3D
var camera: Camera3D
var tool: Node3D
var appliance: Node3D
var customer: Node3D
var phase := "inspect"
var elapsed := 0.0
var handover := false
var kind := 0
var transferred := false
var customer_id := "DUYEN"
var setting := "workshop"

func _ready() -> void:
	var env := WorldEnvironment.new(); env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color("292d28")
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color("c1cbce"); env.environment.ambient_light_energy=.6
	add_child(env)
	var light := DirectionalLight3D.new(); light.rotation_degrees=Vector3(-55,-35,0)
	light.light_color=Color("fff1da"); light.light_energy=.85; light.shadow_enabled=true; add_child(light)
	camera=Camera3D.new(); add_child(camera); camera.position=Vector3(2.7,2.15,3.4)
	camera.look_at(Vector3(0,1.0,0)); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2.45
	Models.box(self,Vector3(0,-.05,0),Vector3(5,.1,4),Models.mat("65635a"))
	_dress()
	Models.box(self,Vector3(0,.81,.20),Vector3(1.55,.08,.85),preload("res://scripts/work/higgsfield_materials.gd").surface("repair_wood",1))
	for x in [-.65,.65]:
		for z in [-.13,.53]: Models.rod(self,Vector3(x,0,z),Vector3(x,.8,z),.025,Models.mat("323c36",.3))
	Models.box(self,Vector3(-.2,.855,.13),Vector3(.47,.01,.4),Models.mat("354a40"))
	appliance=Models.fan() if kind==0 else preload("res://scripts/work/work_props.gd").kettle()
	add_child(appliance); appliance.position=Vector3(.35,.85,.3)
	actor=An.new(); add_child(actor); actor.setup(Color.WHITE,Color.WHITE); actor.apply_outfit(game)
	actor.position=Vector3(0,0,-.65); actor.work("inspect")
	tool=Models.screwdriver(self)
	if handover:
		actor.work(""); tool.visible=false; phase="receive"
		var Character=load("res://scripts/world/character.gd")
		var look: Dictionary=Character.LOOKS.get(customer_id,Character.LOOKS.DUYEN).duplicate(true)
		look["talker"]=true
		customer=Character.make(look); add_child(customer)
		customer.position=Vector3(2.4,0,.75); customer.rotation.y=-PI/2
		camera.position=Vector3(3.4,2.5,4.0); camera.look_at(Vector3(.35,1,0)); camera.size=3.6

func _dress() -> void:
	var finish=preload("res://scripts/work/higgsfield_materials.gd")
	var wall: StandardMaterial3D=finish.surface("hanoi_plaster",.5).duplicate()
	wall.uv1_triplanar=true
	Models.box(self,Vector3(0,1.35,-1.35),Vector3(5,2.7,.13),wall)
	var sign := Label3D.new(); sign.text="TIỆM SƠN · SỬA ĐỒ ĐIỆN" if setting=="workshop" else "HÀNG CHỢ · LONG BIÊN"
	sign.position=Vector3(0,2.3,-1.26); sign.font_size=48; sign.pixel_size=.004; sign.modulate=Color("dbcca4"); sign.outline_size=0
	Models.box(self,Vector3(0,2.3,-1.30),Vector3(2.6,.38,.04),Models.mat("344b43"))
	add_child(sign)
	var shelf := finish.surface("repair_wood",.8).duplicate(); shelf.uv1_triplanar=true
	for y in [.6,1.25,1.85]:
		Models.box(self,Vector3(-1.55,y,-1.08),Vector3(1.0,.05,.4),shelf)
		for i in 3:
			if setting=="workshop":
				Models.casing(self,Vector3(-1.85+i*.30,y+.11,-1.07),Vector3(.23,.20,.23),Models.mat(["8a795b","5c6d60","77796b"][i]))
			else:
				for j in 3: Models.ellipsoid(self,Vector3(-1.85+i*.28,y+.09,-1.2+j*.11),Vector3(.13,.16,.12),Models.mat("ba9a43" if i%2==0 else "738347"))
	for x in [-2.02,-1.05]: Models.rod(self,Vector3(x,0,-1.07),Vector3(x,2.0,-1.07),.022,Models.mat("404940",.3))
	if setting=="workshop":
		Models.box(self,Vector3(1.3,1.5,-1.24),Vector3(.8,.85,.05),Models.mat("675c45"))
		for i in 4:
			var driver := Models.screwdriver(self); driver.position=Vector3(1.0+i*.18,1.30,-1.19)
			for j in 5: Models.ellipsoid(self,Vector3(1.0+i*.18,1.15+j*.16,-1.20),Vector3(.012,.012,.005),Models.mat("302f26"))
	else:
		Models.box(self,Vector3(0,2.65,-.6),Vector3(4,.035,1.4),Models.mat("856951"))
		for x in [-2.0,2.0]: Models.rod(self,Vector3(x,0,0),Vector3(x,2.65,0),.022,Models.mat("586256",.5))

func set_phase(value: String) -> void:
	phase=value
	if is_instance_valid(actor): actor.work(value if value!="test" else "")
	if is_instance_valid(tool): tool.visible=value=="screw"

func _process(delta: float) -> void:
	elapsed+=delta
	if not is_instance_valid(actor): return
	if handover:
		var arriving := elapsed<2.2
		customer.position.x=lerpf(2.4,.95,smoothstep(0.0,2.2,elapsed))
		customer.animate(delta,.55 if arriving else 0.0)
		if not arriving: customer.rotation.y=lerp_angle(customer.rotation.y,PI,.08)
		if elapsed>3.5 and not transferred:
			transferred=true
			if customer.has_method("hold"): customer.hold("box")
			appliance.reparent(customer,false); appliance.position=Vector3(0,.96,.42)
			actor.place()
		return
	var pose=actor._task_pose
	var t: float=pose.elapsed if pose!=null else elapsed
	tool.position=Vector3(-.20+sin(t*2)*.025,.83+sin(t*5)*.025,-.08)
	tool.rotation.y=sin(t*5)*.6
	if phase=="test" and kind==0: appliance.get_node("Rotor").rotate_z(delta*15)
