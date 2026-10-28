extends Window
const UI := preload("res://scripts/ui/ui_kit.gd")
const SOCKET := Vector3(0.4,0.75,0.25)
const BIN := Vector3(2.15,0.75,0.65)
const SOURCE := Vector3(-2.0,0.75,0.55)
const SAMPLE := Vector3(-2.0,0.75,-0.55)
const SCREWS := [Vector3(-0.2,0.75,0.65),Vector3(1.0,0.75,0.65)]
var game
var token := ""
var kind := 0
var viewport: SubViewport
var surface: SubViewportContainer
var camera: Camera3D
var hint: Label
var details: Label
var test_button: Button
var old_part: Node3D
var new_part: Node3D
var sample_part: Node3D
var screw_nodes: Array[Node3D] = []
var rotor: Node3D
var dragging: Node3D
var drag_id := ""
var drag_origin := Vector3.ZERO
var feedback := ""
var orbit_yaw := 0.0
var orbit_pitch := 0.92
func _ready() -> void:
	title = "Bàn sửa của An"
	size = Vector2i(1040,690)
	min_size = size
	transient = true
	exclusive = true
	theme = UI.make_theme()
	close_requested.connect(queue_free)
	kind = int(game.s.street.job.kind)
	token = str(game.s.street.accepted_day)+":"+str(kind)
	var panel := PanelContainer.new()
	# Nền tối cho chữ sáng của bàn sửa (giao diện chung của game là nền sáng).
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.09, 0.1, 0.12, 0.98), Color(1, 1, 1, 0.12), 6, 14))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",10)
	panel.add_child(column)
	column.add_child(UI.label("BÀN SỬA  ·  " + str(game.s.street.job.name),22,UI.GOLD))
	details = UI.wrap(str(game.s.street.job.reading),15,UI.HUD_TEXT,980)
	column.add_child(details)
	surface = SubViewportContainer.new()
	surface.custom_minimum_size = Vector2(980,430)
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.stretch = true
	surface.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(surface)
	viewport = SubViewport.new()
	viewport.size = Vector2i(980,430)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	surface.add_child(viewport)
	surface.gui_input.connect(_surface_input)
	hint = UI.wrap("",16,UI.GOLD,980)
	column.add_child(hint)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	test_button = Button.new()
	test_button.text = "Lắp vỏ & chạy thử · 15 phút"
	test_button.pressed.connect(_test)
	buttons.add_child(test_button)
	var close := Button.new()
	close.text = "Rời bàn · giữ tiến độ"
	close.pressed.connect(queue_free)
	buttons.add_child(close)
	column.add_child(UI.label("Chuột trái: kéo / siết vít · Chuột phải: xoay góc nhìn · Lăn chuột: phóng · Esc: rời bàn",13,UI.HUD_SOFT))
	_build_scene()
	game.changed.connect(refresh)
	refresh()
	popup_centered()
func material(color: String, metal := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color)
	mat.roughness = 0.74
	mat.metallic = metal
	return mat
func box(parent: Node, pos: Vector3, dimensions: Vector3, color: String) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = pos
	parent.add_child(node)
	return node
func cylinder(parent: Node, pos: Vector3, radius: float, height: float, color: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color,0.35)
	node.position = pos
	parent.add_child(node)
	return node
func label3(text: String, pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = pos
	label.font_size = 20
	label.outline_size = 4
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("e5d7ad")
	viewport.add_child(label)
func part(part_kind: int, pos: Vector3, worn := false) -> Node3D:
	var root := Node3D.new()
	viewport.add_child(root)
	root.position = pos
	if part_kind==0:
		box(root,Vector3(0,0.13,0),Vector3(0.43,0.26,0.23),"77634e" if worn else "2b4146")
		for x in [-0.13,0.13]: box(root,Vector3(x,0.08,0.2),Vector3(0.025,0.025,0.24),"ba9b60")
	else:
		var fuse := cylinder(root,Vector3(0,0.1,0),0.07,0.4,"796654" if worn else "c2b598")
		fuse.rotation.z = PI/2
		box(root,Vector3(0,0.1,0),Vector3(0.7,0.025,0.025),"a38b60")
	return root
func _build_scene() -> void:
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0,5.7,4.0)
	camera.look_at(Vector3(0,0.5,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 6.2
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-25,0)
	light.shadow_enabled = true
	viewport.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("272c28")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("dfd6b9")
	environment.environment.ambient_light_energy = 0.4
	viewport.add_child(environment)
	var table := box(viewport,Vector3(0,0.45,0),Vector3(6,0.2,3.2),"67513a")
	var wood := ShaderMaterial.new()
	wood.shader = preload("res://scripts/world/bench_surface.gdshader")
	table.material_override = wood
	for i in range(15): box(viewport,Vector3(-2.8+i*0.4,0.553,0),Vector3(0.008,0.003,3.12),"45392e")
	box(viewport,Vector3(0.35,0.57,0),Vector3(2.5,0.06,2.4),"33433e")
	box(viewport,BIN-Vector3(0,0.16,0),Vector3(1.05,0.06,0.8),"766958")
	for x in [-0.52,0.52]: box(viewport,BIN+Vector3(x,-0.08,0),Vector3(0.04,0.18,0.8),"90816b")
	box(viewport,SOURCE-Vector3(0,0.16,0),Vector3(1.2,0.06,0.8),"414b44")
	box(viewport,SOCKET-Vector3(0,0.1,0),Vector3(0.85,0.09,0.58),"b99c5c")
	if kind==0:
		cylinder(viewport,Vector3(0.35,0.73,-0.65),0.53,0.26,"73766d")
		rotor = Node3D.new()
		viewport.add_child(rotor)
		rotor.position = Vector3(0.35,0.9,-0.65)
		for angle in [0.0,TAU/3,TAU*2/3]:
			var blade := box(rotor,Vector3(sin(angle)*0.24,0,cos(angle)*0.24),Vector3(0.18,0.035,0.45),"a3a896")
			blade.rotation.y = angle
		cylinder(rotor,Vector3.ZERO,0.1,0.07,"454e47")
	else:
		cylinder(viewport,Vector3(0.35,0.7,-0.55),0.65,0.15,"b7b6a6")
		cylinder(viewport,Vector3(0.35,0.8,-0.55),0.48,0.08,"52584e")
		box(viewport,Vector3(1.05,0.73,-0.55),Vector3(0.15,0.13,0.5),"2a342e")
	# Leads between appliance and the replacement socket.
	for x in [0.22,0.57]: box(viewport,Vector3(x,0.7,-0.1),Vector3(0.025,0.025,0.6),"a15b43")
	# Meter and hand tools on the back edge of the work surface.
	box(viewport,Vector3(2.15,0.65,-0.9),Vector3(0.5,0.16,0.7),"826b42")
	box(viewport,Vector3(2.15,0.74,-1.06),Vector3(0.36,0.025,0.23),"829782")
	cylinder(viewport,Vector3(2.15,0.76,-0.76),0.11,0.04,"282e29")
	var driver := cylinder(viewport,Vector3(1.55,0.66,-0.85),0.065,0.44,"965b3e")
	driver.rotation.x=PI/2
	box(viewport,Vector3(1.55,0.66,-0.45),Vector3(0.025,0.025,0.42),"b1afa0")
	old_part = part(kind,SOCKET,true)
	new_part = part(kind,SOURCE)
	sample_part = part(1-kind,SAMPLE)
	for point in SCREWS:
		var screw := cylinder(viewport,point,0.095,0.08,"b3b5a9")
		box(screw,Vector3(0,0.045,0),Vector3(0.12,0.012,0.025),"3b433b")
		screw_nodes.append(screw)
	label3("LINH KIỆN MỚI",SOURCE+Vector3(0,0,-0.45))
	label3("MẪU ĐỐI CHIẾU",SAMPLE+Vector3(0,0,-0.32))
	label3("KHAY ĐỒ HỎNG",BIN+Vector3(0,0,-0.55))
	label3("Ổ LẮP",SOCKET+Vector3(0,0,0.75))
func progress() -> Dictionary:
	return game.s.street.job.get("bench",{"removed":false,"installed":false,"screws":0})
func refresh() -> void:
	var job: Dictionary = game.s.street.job
	if job.is_empty() or token != str(game.s.street.accepted_day)+":"+str(int(job.kind)):
		queue_free()
		return
	var state := progress()
	if job.stage in ["test","deliver"]: state = {"removed":true,"installed":true,"screws":3}
	if dragging==null:
		old_part.position = BIN if state.removed else SOCKET
		new_part.position = SOCKET if state.installed else SOURCE
		sample_part.position = SAMPLE
	for i in 2:
		screw_nodes[i].material_override = material("789c6c" if int(state.screws)&(1<<i) else "b3b5a9")
	test_button.disabled = job.stage != "test"
	var instruction := "1 / 3 · Kéo linh kiện hỏng từ ổ lắp sang khay bên phải."
	if state.removed: instruction = "2 / 3 · Kéo linh kiện mới bên trái vào ổ lắp màu vàng."
	if state.installed: instruction = "3 / 3 · Bấm hai vít bạc cạnh ổ lắp để siết chặt."
	if job.stage=="test": instruction = "Đã lắp xong · Chạy thử trước khi trả khách."
	if job.stage=="deliver": instruction = "Chạy thử đạt · Rời bàn để trả món và nhận tiền công."
	hint.text = instruction + ("\n"+feedback if not feedback.is_empty() else "")
	details.text = str(job.reading) + "\n" + "Giờ %s · Sửa 45 phút, Mệt +8 khi lắp xong · Linh kiện đã lấy cho đơn" % game.hh(game.clock())
func _surface_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT and dragging==null:
		orbit_yaw -= event.relative.x*0.006
		orbit_pitch = clampf(orbit_pitch+event.relative.y*0.006,0.55,1.15)
		camera.position = Vector3(sin(orbit_yaw)*cos(orbit_pitch),sin(orbit_pitch),cos(orbit_yaw)*cos(orbit_pitch))*6.5+Vector3(0,0.5,0)
		camera.look_at(Vector3(0,0.5,0))
		surface.accept_event()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		camera.size = clampf(camera.size+(-0.3 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.3),4.8,7.5)
		surface.accept_event()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed: pointer_down(event.position)
		else: pointer_up(event.position)
		surface.accept_event()
	elif event is InputEventMouseMotion and dragging!=null:
		pointer_move(event.position)
		surface.accept_event()
func plane_point(pos: Vector2) -> Variant:
	var local := pos * Vector2(viewport.size) / surface.size
	return Plane(Vector3.UP,0.75).intersects_ray(camera.project_ray_origin(local),camera.project_ray_normal(local))
func near_screen(pos: Vector2, point: Vector3, radius := 28.0) -> bool:
	var local := pos * Vector2(viewport.size) / surface.size
	return local.distance_to(camera.unproject_position(point)) < radius
func pointer_down(pos: Vector2) -> void:
	if game.s.street.job.stage != "repair": return
	feedback = ""
	var state := progress()
	for i in 2:
		if near_screen(pos,SCREWS[i],20):
			feedback = game.Street.bench_action(game,"screw",i,token)
			refresh()
			return
	if not state.removed and near_screen(pos,old_part.position+Vector3(0,0.12,0)):
		dragging = old_part; drag_id = "old"
	elif not state.installed and near_screen(pos,new_part.position+Vector3(0,0.12,0)):
		dragging = new_part; drag_id = "new"
	elif near_screen(pos,sample_part.position+Vector3(0,0.12,0)):
		dragging = sample_part; drag_id = "sample"
	if dragging!=null: drag_origin = dragging.position
func pointer_move(pos: Vector2) -> void:
	if dragging==null: return
	var point = plane_point(pos)
	if point!=null:
		dragging.position = Vector3(clampf(point.x,-2.8,2.8),0.82,clampf(point.z,-1.4,1.4))
func pointer_up(pos: Vector2) -> void:
	if dragging==null: return
	var point = plane_point(pos)
	var item: Node3D = dragging
	var id := drag_id
	dragging = null
	item.position = drag_origin
	if point!=null and Vector2(point.x-BIN.x,point.z-BIN.z).length()<0.5 and id=="old":
		feedback = game.Street.bench_action(game,"remove",kind,token)
	elif point!=null and Vector2(point.x-SOCKET.x,point.z-SOCKET.z).length()<0.42 and id in ["new","sample"]:
		feedback = game.Street.bench_action(game,"install",kind if id=="new" else 1-kind,token)
	else: feedback = "Chưa đúng vùng thả; linh kiện được trả về chỗ cũ."
	refresh()
func _test() -> void:
	if game.Street.act(game,"tiem_sau","test"):
		feedback = "Kiểm tra chạy và cách điện đạt."
	else: feedback = "Không đủ giờ hoặc sức để chạy thử; quay lại sau."
	refresh()
func _process(delta: float) -> void:
	if rotor!=null and not game.s.street.job.is_empty() and game.s.street.job.stage=="deliver":
		rotor.rotate_y(delta*7)
func _input(event: InputEvent) -> void:
	# Release outside the viewport cancels the drag instead of leaving a floating part.
	if event is InputEventMouseButton and not event.pressed and dragging!=null:
		if not surface.get_global_rect().has_point(event.position):
			dragging.position = drag_origin
			dragging = null
			refresh()
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: queue_free()
