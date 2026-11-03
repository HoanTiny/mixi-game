extends Node3D
## Visible consequences use the existing quest/save facts; no second quest state.
const Props := preload("res://scripts/work/work_props.gd")
const Front := preload("res://scripts/world/street_prototype.gd")
const Character := preload("res://scripts/world/character.gd")
var world
var shop_fan: Node3D
var market_fan: Node3D
var mangoes: Node3D
var merchant: Node3D
var merchant_pick: StaticBody3D
var caption: Label3D
var home_caption: Label3D
var rotor: Node3D
var carried: Node3D
var carry_id := ""
var water_kettle: Node3D
var water_seller: Node3D
var water_pick: StaticBody3D
var water_caption: Label3D
var porch_lights: Array[OmniLight3D]=[]

static func reservation_points(city) -> Array:
	var plot: Dictionary=city.locs.cho_cau_nho
	var normal: Vector2=plot.normal
	var along := Vector2(normal.y,-normal.x)
	var center: Vector2=plot.center-along*1.8+normal*0.35
	var water: Vector2=plot.center+along*1.8+normal*0.35
	return [center,center+along*0.35,center-along*0.35,water,water+along*0.35,water-along*0.35]

func setup(w) -> void:
	world=w
	var shop: Node3D = world._frame_node(world.city.locs.tiem_sau,"FirstCustomerWorkbench")
	add_child(shop)
	var sw: float=world.city.locs.tiem_sau.w
	# Kept inside the existing blocked plot, with the centre entrance clear.
	shop_fan=Props.fan()
	shop_fan.position=Vector3(sw*0.24+0.35,0.93,-1.65)
	shop.add_child(shop_fan)
	Front.menu_board(world,shop,Vector3(-sw*0.39,0.15,-0.3),"NHẬN SỬA\nGhi lỗi · Báo giá\nHẹn giờ trả")
	var market: Node3D = world._frame_node(world.city.locs.cho_cau_nho,"FirstCustomerStall")
	add_child(market)
	var x := -1.8
	Props.box(market,Vector3(2.1,0.7,0.75),Props.tex("brown_planks_05",1.2),Vector3(x,0.15,-1.05))
	for i in 3:
		Front.scanned(market,"plastic_crate_01",Vector3(x-0.65+i*0.65,0.85,-1.05),0.22)
		for j in 6:
			_fruit(market,Vector3(x-0.84+i*0.65+(j%3)*0.16,1.04,-1.2+(j/3)*0.23),i)
	market_fan=Props.fan()
	market_fan.position=Vector3(x+1.3,0.88,-1.05)
	Props.box(market,Vector3(0.5,0.73,0.55),Props.tex("brown_planks_05",1.2),Vector3(x+1.3,0.15,-1.05))
	market.add_child(market_fan)
	rotor=market_fan.get_node("Rotor")
	merchant=Character.make(Character.LOOKS.MA.duplicate(true))
	merchant.name="FruitSeller"
	market.add_child(merchant)
	merchant.position=Vector3(x,0.15,0.35)
	merchant.rotation.y=PI*0.8
	world.idlers.append(merchant)
	var pick := StaticBody3D.new()
	merchant_pick=pick
	pick.set_meta("loc","cho_cau_nho")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius=0.35
	capsule.height=1.7
	shape.shape=capsule
	shape.position.y=0.85
	pick.add_child(shape)
	merchant.add_child(pick)
	caption=_label(market,Vector3(x,2.25,0.35))
	# The second customer occupies the other half of the central market bay.
	Props.box(market,Vector3(1.5,0.72,0.7),Props.tex("brown_planks_05",1.4),Vector3(1.8,0.15,-1.05))
	water_kettle=Props.kettle()
	water_kettle.position=Vector3(1.65,0.87,-1.0)
	market.add_child(water_kettle)
	for offset in [-0.3,0.0,0.3]:
		Front.placed(market,Props.dish("tra"),Vector3(2.0+offset,0.88,-0.8))
	water_seller=Character.make(Character.LOOKS.DUYEN.duplicate(true))
	market.add_child(water_seller)
	water_seller.position=Vector3(1.8,0.15,0.35)
	water_seller.rotation.y=-0.4
	world.idlers.append(water_seller)
	water_pick=StaticBody3D.new()
	water_pick.set_meta("loc","cho_cau_nho")
	var water_shape := CollisionShape3D.new()
	water_shape.shape=capsule.duplicate()
	water_shape.position.y=0.85
	water_pick.add_child(water_shape)
	water_seller.add_child(water_pick)
	water_caption=_label(market,Vector3(1.8,2.25,0.35))
	Front.menu_board(world,market,Vector3(3.0,0.15,-0.3),"NƯỚC CHÈ\nNóng · Mát\nMời ngồi")
	var home: Node3D = world._frame_node(world.city.locs.xom_bo_me,"FirstDayHome")
	add_child(home)
	var hw: float=world.city.locs.xom_bo_me.w
	# Packing belongs beside the entrance, outside the walkable 3 m corridor.
	for i in 3:
		Front.scanned(home,"cardboard_box_01",Vector3(-hw*0.28+i*0.42,0.15,-0.7),0.4+(i%2)*0.15,0.1*i)
	mangoes=Node3D.new()
	home.add_child(mangoes)
	mangoes.position=Vector3(hw*0.29,0.15,-0.65)
	Props.box(mangoes,Vector3(0.85,0.5,0.55),Props.tex("brown_planks_05",1.5),Vector3.ZERO)
	for i in 2: _fruit(mangoes,Vector3(-0.13+i*0.25,0.57,0),1)
	home_caption=_label(home,Vector3(hw*0.29,1.65,-0.65))
	# Four distinct entrances, warmer practical light after dusk.
	for loc in ["xom_bo_me","tiem_sau","cho_cau_nho","com_hanh"]:
		var entry: Node3D=world._frame_node(world.city.locs[loc],"EveningPorch_"+loc)
		add_child(entry)
		var lamp := OmniLight3D.new()
		lamp.position=Vector3(0,2.3,-0.7)
		lamp.light_color=Color("ffd3a0")
		lamp.omni_range=5.0
		lamp.shadow_enabled=false
		entry.add_child(lamp)
		porch_lights.append(lamp)
		if loc in ["xom_bo_me","com_hanh"]:
			Front.scanned(entry,"metal_stool_01",Vector3(-1.1,0.15,0.6),0.42)
		if loc=="tiem_sau":
			Front.menu_board(world,entry,Vector3(sw*0.45,0.15,-0.2),"BÁO GIÁ\nKhách đồng ý\nMới thay đồ")
		if loc=="com_hanh":
			Front.menu_board(world,entry,Vector3(1.6,0.15,-0.3),"CƠM TRƯA\n10–14 giờ\nCơm tối 17–20")
	world.game.changed.connect(refresh)
	refresh()

func _fruit(parent: Node3D, pos: Vector3, kind: int) -> void:
	var mesh := SphereMesh.new()
	mesh.radius=0.08
	mesh.height=0.16
	mesh.radial_segments=12
	mesh.rings=6
	var fruit := MeshInstance3D.new()
	fruit.mesh=mesh
	fruit.material_override=Props.plain([Color("7d8847"),Color("c0a34f"),Color("b0753d")][kind],0.8)
	fruit.position=pos
	if kind==1: fruit.scale=Vector3(0.85,0.8,1.4)
	parent.add_child(fruit)

func _label(parent: Node3D, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.font=world.font
	l.font_size=32
	l.pixel_size=0.006
	l.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size=6
	l.width=520.0
	l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	l.modulate=Color("e5d8b6")
	l.position=pos
	parent.add_child(l)
	return l

func refresh() -> void:
	if world==null or not world.game.is_started():
		visible=false
		return
	visible=world.game.is_full() and world.game.chapter()==1
	merchant_pick.collision_layer=1 if visible and world.game.clock()>=7 and world.game.clock()<19 else 0
	water_pick.collision_layer=merchant_pick.collision_layer
	var g=world.game
	var state: String=g.quest_state("quat_trai_cay")
	var delivered := state=="done"
	water_kettle.visible=bool(g.s.flags.get("day23_kettle_delivered",false))
	water_caption.text="Ấm đã nóng, cô có trà mời khách rồi!" if water_kettle.visible else "Cô hàng nước · chiếc ấm đang chờ ở tiệm Sơn"
	if g.s.get("day23",{}).get("order_late",false): water_caption.text="Ấm chạy tốt. Lần sau báo cô sớm nhé, An."
	market_fan.visible=delivered
	shop_fan.visible=not delivered and g.item_count("quat")==0 and state!="failed"
	mangoes.visible=bool(g.s.flags.get("opening_home_shared",false))
	home_caption.text="Bà đã chia xoài. Túi đồ nghề sẵn cho ngày mai."
	if g.s.flags.get("day23_linh_solo",false): home_caption.text="Ảnh phòng Linh mang về nằm cạnh sổ tiền."
	if delivered:
		caption.text="An đấy à? Quạt chạy êm lắm!"
	elif g.item_count("quat")>0:
		caption.text="Quạt của cô sửa xong rồi à?"
	elif state=="failed":
		caption.text="Hôm nay cô mượn quạt hàng bên. Lần sau báo cô sớm nhé."
	else:
		caption.text="Cô bán hoa quả · chờ chiếc quạt ở tiệm Sơn"
	_sync_carry()

func _sync_carry() -> void:
	var wanted := "fan" if world.game.item_count("quat")>0 else ("kettle" if world.game.s.flags.get("day23_carry_kettle",false) else "")
	if wanted==carry_id: return
	if is_instance_valid(carried):
		carried.queue_free()
		if world.player_body.has_method("place"): world.player_body.place()
	carry_id=wanted
	if wanted!="":
		carried=Props.fan() if wanted=="fan" else Props.kettle()
		carried.position=Vector3(0,1.02,0.44)
		world.player.add_child(carried)
	if world.player_body.has_method("hold") and not world._riding: world.player_body.hold(wanted)

func _process(delta: float) -> void:
	if world==null or not visible: return
	var open: bool=world.game.clock()>=7 and world.game.clock()<19
	merchant.visible=open
	water_seller.visible=open
	merchant_pick.collision_layer=1 if open else 0
	water_pick.collision_layer=1 if open else 0
	caption.visible=open and world.player.global_position.distance_to(merchant.global_position)<8.0
	home_caption.visible=mangoes.visible and world.player.global_position.distance_to(mangoes.global_position)<7.0
	water_caption.visible=open and world.player.global_position.distance_to(water_seller.global_position)<5.0
	for lamp in porch_lights: lamp.light_energy=0.85 if world.game.clock()>=17.0 else 0.22
	if is_instance_valid(carried):
		carried.visible=not world._riding and not world._resting
		if not world._riding and world.player_body.has_method("hold"): world.player_body.hold(carry_id)
	if market_fan.visible and open: rotor.rotation.z-=delta*14.0
