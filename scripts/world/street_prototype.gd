extends RefCounted
## Named Hanoi street fronts. Keep each location's existing plot and door while
## giving every occupation a readable frontage and separate cutaway groups.
const Props := preload("res://scripts/world/props3d.gd")
const Surfaces := preload("res://scripts/world/surfaces.gd")
const WorkProps := preload("res://scripts/work/work_props.gd")
const Models := preload("res://scripts/world/models.gd")
const Architecture := preload("res://scripts/architecture/street_kit.gd")
const StoryFronts := preload("res://scripts/architecture/story_fronts.gd")
const PRIMARY := ["com_hanh", "tiem_sau", "xom_bo_me"]
const LOCATIONS := ["com_hanh", "tiem_sau", "xom_bo_me", "cho_cau_nho", "ben_xe_6",
	"nha_di_nam", "hem_dua", "ben_can", "cau_tre", "bai_boc_vac", "xe_tho",
	"nha_tro_giuong", "quan_net", "cam_do", "ve_so", "ho_guom", "shop_ao", "bi_a", "tiem_toc"]

## Reuse the photographed props already shipped for the work scenes. Fit before
## rotating so each cluster has predictable bounds and stays behind the sidewalk.
static func scanned(parent: Node3D, key: String, pos: Vector3, height: float, yaw := 0.0) -> Node3D:
	var node := WorkProps.model(key)
	var bounds := Models._bounds(node, node.transform)
	if bounds.size.y > 0.001:
		node.scale *= height / bounds.size.y
		bounds = Models._bounds(node, node.transform)
	var pivot := Node3D.new()
	node.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	pivot.add_child(node)
	pivot.position = pos
	pivot.rotation.y = yaw
	parent.add_child(pivot)
	return pivot

static func placed(parent: Node3D, node: Node3D, pos: Vector3, yaw := 0.0) -> Node3D:
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)
	return node

static func menu_board(world, parent: Node3D, pos: Vector3, text: String) -> void:
	var frame := Node3D.new()
	frame.position = pos
	frame.rotation.x = -0.08
	parent.add_child(frame)
	var wood := WorkProps.tex("brown_planks_05", 1.5, Color("93816c"))
	WorkProps.box(frame, Vector3(0.72, 0.95, 0.07), wood, Vector3(0, 0.18, 0))
	world._block(Vector3(0.62, 0.82, 0.015), Vector3(0, 0.24, 0.045), Color("28332e"), frame)
	for x in [-0.28, 0.28]:
		WorkProps.box(frame, Vector3(0.06, 0.35, 0.08), wood, Vector3(x, 0, 0))
	var label := Label3D.new()
	label.text = text
	label.font = world.font
	label.font_size = 38
	label.pixel_size = 0.0032
	label.outline_size = 0
	label.modulate = Color("ddd7bc")
	label.position = Vector3(0, 0.67, 0.06)
	frame.add_child(label)

static func item(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := Props.instance(mesh, color)
	node.position = pos
	parent.add_child(node)
	return node


static func laundry(parent: Node3D, pos: Vector3, variant: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Sewn garments have sleeves or two legs and a hanging, folded silhouette.
	# Geometry is deliberately modest at street-camera scale, no opaque rectangles.
	var bands := [[0.0, 0.17, 0.31], [0.17, 0.55, 0.20]] if variant % 2 == 0 else [[0.0, 0.2, 0.22], [0.2, 0.68, 0.22]]
	for band in bands:
		for strip in 12:
			var x0: float = lerpf(-band[2], band[2], float(strip) / 12.0)
			var x1: float = lerpf(-band[2], band[2], float(strip + 1) / 12.0)
			if variant % 2 == 1 and float(band[0]) > 0.1 and absf((x0 + x1) * 0.5) < 0.045:
				continue
			var points := [Vector3(x0, -band[0], 0), Vector3(x1, -band[0], 0), Vector3(x1, -band[1], 0), Vector3(x0, -band[1], 0)]
			for k in [0, 2, 1, 0, 3, 2]:
				var p: Vector3 = points[k]
				p.z = sin(p.x * 37.0 + variant) * (0.017 + absf(p.y) * 0.03)
				p.y += sin(p.x * 11.0 + variant) * 0.018
				st.set_uv(Vector2(p.x, -p.y))
				st.add_vertex(p)
	st.generate_normals()
	st.index()
	var mesh := st.commit()
	var mat := WorkProps.plain([Color("918879"), Color("596668"), Color("8b7c6e"), Color("6b7270"), Color("aa9c86")][variant % 5], 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, mat)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	for x in [-0.14, 0.14]:
		WorkProps.box(parent, Vector3(0.025, 0.065, 0.025), WorkProps.plain(Color("796951")), pos + Vector3(x, -0.02, 0.012))

static func signboard(world, parent: Node3D, text: String, pos: Vector3, width: float, color: Color) -> void:
	var steel := WorkProps.tex("rusty_metal_sheet", 0.65, color.lightened(0.18))
	WorkProps.box(parent, Vector3(width, 0.65, 0.095), steel, pos)
	var rim := WorkProps.plain(color.darkened(0.32), 0.92, 0.15)
	for y in [0.025, 0.625]:
		WorkProps.box(parent, Vector3(width + 0.035, 0.025, 0.12), rim, pos + Vector3(0, y, 0))
	var lines := text.split("\n", false, 1)
	var label := Label3D.new()
	label.text = lines[0]
	label.font = world.font
	label.font_size = 56
	label.pixel_size = minf(0.0066, (width - 0.3) / maxf(world.font.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 56).x, 1.0))
	label.outline_size = 0
	label.shaded = true
	label.modulate = Color("e1d8bf")
	label.position = pos + Vector3(0, 0.38 if lines.size() > 1 else 0.32, 0.06)
	parent.add_child(label)
	if lines.size() > 1:
		var small := Label3D.new()
		small.text = lines[1]
		small.font = world.font
		small.font_size = 28
		small.pixel_size = 0.005
		small.shaded = true
		small.modulate = Color("c9c5ae")
		small.outline_size = 0
		small.position = pos + Vector3(0, 0.13, 0.06)
		parent.add_child(small)

static func build(world, parent: Node3D, id: String, width: float, depth: float, seed := -1) -> Dictionary:
	if id not in PRIMARY:
		var city_kit := StoryFronts.build(parent, id, width, depth, LOCATIONS.find(id) if seed < 0 else seed)
		signboard(world, city_kit.front_walls, city_kit.sign_text, city_kit.sign_position, city_kit.sign_width, city_kit.sign_color)
		return city_kit
	var kinds := {"com_hanh": "restaurant", "tiem_sau": "repair", "xom_bo_me": "lodging"}
	var kit := Architecture.build(parent, kinds[id], width, depth, LOCATIONS.find(id) if seed < 0 else seed)
	var sign_pos: Vector3 = kit.sign_position
	var sign_width: float = kit.sign_width
	sign_width = minf(sign_width, 4.8)
	# The fascia sits in front of the balcony/shutter, so its letters are readable
	# from the actual high gameplay camera rather than hidden behind the overhang.
	sign_pos.z = 1.08 if id == "com_hanh" else 0.5
	sign_pos.y = 2.82 if id == "com_hanh" else 3.05
	if id == "xom_bo_me":
		sign_width = minf(sign_width, 5.4)
	var light := OmniLight3D.new()
	light.position = Vector3(-width * 0.22, 2.4, -0.8)
	light.light_color = Color("ffcf8e")
	light.light_energy = 0.65
	light.omni_range = 4.0
	parent.add_child(light)
	match id:
		"com_hanh":
			signboard(world, parent, "CƠM HẠNH\nCƠM BÌNH DÂN · MANG VỀ", sign_pos, sign_width, Color("794f43"))
			for x in [-width * 0.3, width * 0.3]:
				placed(parent, WorkProps.steel_table(), Vector3(x, 0.15, -1.15))
				for dx in [-0.78, 0.78]:
					scanned(parent, "metal_stool_01", Vector3(x + dx, 0.15, -1.12), 0.44, 0.12 if dx < 0.0 else -0.18)
				placed(parent, WorkProps.dish("com"), Vector3(x - 0.28, 0.9, -1.05))
				placed(parent, WorkProps.dish("tra"), Vector3(x + 0.26, 0.9, -0.98))
				scanned(parent, "wooden_bowl_02", Vector3(x + 0.08, 0.9, -1.28), 0.09)
			# Serving shelf and cookware, left of the clear central approach.
			WorkProps.box(parent, Vector3(1.3, 0.06, 0.36), WorkProps.tex("brown_planks_05", 1.5), Vector3(-width * 0.3, 1.04, -2.05))
			scanned(parent, "pot_enamel_01", Vector3(-width * 0.3 - 0.3, 1.1, -2.05), 0.25)
			placed(parent, WorkProps.rice_cooker(), Vector3(-width * 0.3 + 0.25, 1.1, -2.02))
			menu_board(world, parent, Vector3(-width * 0.43, 0.15, -0.35), "CƠM NHÀ\nCơm · Canh\nTrà đá")
		"tiem_sau":
			signboard(world, parent, "SƠN SỬA XE\nĐỒ ĐIỆN · BƠM VÁ · THAY NHỚT", sign_pos, sign_width, Color("536a65"))
			var bike := item(parent, Props.motorbike("xe_so"), Vector3(-width * 0.25, 0.15, -1.15), Color("874d3a"))
			bike.rotation.y = 0.65
			scanned(parent, "metal_office_desk", Vector3(width * 0.24, 0.15, -1.65), 0.78)
			scanned(parent, "bench_vice_01", Vector3(width * 0.24 - 0.4, 0.93, -1.4), 0.22, 0.35)
			if not world.real or not world.city.street_upgrade:
				placed(parent, WorkProps.fan(), Vector3(width * 0.24 + 0.35, 0.93, -1.65))
			scanned(parent, "metal_tool_chest", Vector3(width * 0.41, 0.15, -1.85), 0.55)
			placed(parent, WorkProps.spool(), Vector3(width * 0.39, 0.15, -2.7), 0.3)
			scanned(parent, "portable_generator", Vector3(-width * 0.38, 0.15, -1.85), 0.48, 0.25)
			for i in 3:
				var tire := TorusMesh.new()
				tire.inner_radius = 0.2
				tire.outer_radius = 0.34
				item(parent, tire, Vector3(width * 0.37, 0.2 + i * 0.17, -0.55), Color("292c2b"))
		"xom_bo_me":
			signboard(world, kit.front_walls, "HẺM TRỌ · PHÚC TÂN", sign_pos, sign_width, Color("6c6251"))
			# A shared courtyard beyond the 3 m entrance; props leave the middle clear.
			var yard_x := minf(width * 0.22, 2.8)
			var yard_z := -depth + 1.2
			var basin := WorkProps.tex("concrete_floor_worn_001", 2.0, Color("9c9c8c"))
			# Open trough with four thick sides, inset floor and a galvanized tap.
			WorkProps.box(parent, Vector3(1.1, 0.15, 0.65), basin, Vector3(-yard_x, 0.15, yard_z))
			for side in [-1.0, 1.0]:
				WorkProps.box(parent, Vector3(0.10, 0.5, 0.65), basin, Vector3(-yard_x + side * 0.5, 0.3, yard_z))
				WorkProps.box(parent, Vector3(0.9, 0.5, 0.10), basin, Vector3(-yard_x, 0.3, yard_z + side * 0.275))
			WorkProps.box(parent, Vector3(0.86, 0.01, 0.4), WorkProps.plain(Color("495957"), 0.3), Vector3(-yard_x, 0.4, yard_z))
			var metal := WorkProps.plain(Color("7b8785"), 0.45, 0.6)
			WorkProps.cyl(parent, 0.022, 0.65, metal, Vector3(-yard_x, 0.75, yard_z - 0.29))
			WorkProps.cyl(parent, 0.025, 0.18, metal, Vector3(-yard_x, 1.07, yard_z - 0.21), Vector3.BACK)
			scanned(parent, "plastic_crate_01", Vector3(-yard_x, 0.15, yard_z + 1.1), 0.3, 0.08)
			scanned(parent, "potted_plant_04", Vector3(yard_x, 0.15, -depth + 0.6), 0.75)
			scanned(parent, "plastic_monobloc_chair_01", Vector3(yard_x, 0.15, -4.35), 0.82, -0.18)
			scanned(parent, "wooden_ladder", Vector3(yard_x + 0.3, 0.15, -6.8), 1.95, 0.1)
			# Two worn bikes hug the rear left wall; the central 3 m lane stays open.
			for i in 2:
				var bike := item(parent,Props.motorbike("xe_so"),Vector3(-2.7,0.15,-4.7-i*0.9),Color("626f66") if i==0 else Color("66564b"))
				bike.name = "HomeParkedBike%d" % i
				bike.rotation.y = PI/2
				bike.rotation.z = -0.06
			var bulb := preload("res://scripts/world/hanging_bulb.gd").new()
			bulb.name = "HomeHangingBulb"
			bulb.game = world.game
			bulb.position = Vector3(0.8,3.25,-3.8)
			parent.add_child(bulb)
			WorkProps.cyl(bulb,0.009,0.65,WorkProps.plain(Color("393b34")),Vector3(0,-0.325,0))
			WorkProps.cyl(bulb,0.055,0.09,metal,Vector3(0,-0.68,0))
			var globe := MeshInstance3D.new()
			var glass := SphereMesh.new()
			glass.radius=0.09; glass.height=0.16
			globe.mesh=glass
			globe.position.y=-0.79
			var warm := WorkProps.plain(Color("ffe1a2"))
			warm.emission_enabled=true; warm.emission=Color("ffc578")
			warm.emission_energy_multiplier=1.3
			globe.material_override=warm
			bulb.add_child(globe)
			var bulb_light := OmniLight3D.new()
			bulb_light.position=globe.position
			bulb_light.omni_range=5.0; bulb_light.light_color=Color("ffd1a0")
			bulb_light.shadow_enabled=false
			bulb.add_child(bulb_light); bulb.lamp=bulb_light
			world._block(Vector3(5.6, 0.025, 0.025), Vector3(0, 2.6, -depth + 0.9), Color("494a40"), parent)
			for i in 5:
				laundry(parent, Vector3(-2.3 + i * 1.05, 2.58, -depth + 0.9), i)
	kit["owns_dressing"] = true
	preload("res://scripts/architecture/lived_in_interiors.gd").build(kit.ground,id,width,depth)
	kit["identity"] = kinds[id]
	return kit
