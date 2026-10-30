extends RefCounted
## Dressing stays inside existing closed room bays; the central approaches and
## resident anchors stay clear. Added to the ground cutaway group, never the roof.
const M := preload("res://scripts/work/repair_models.gd")
const P := preload("res://scripts/work/work_props.gd")

static func label(parent: Node3D, text: String, at: Vector3, size := 24) -> void:
	var n := Label3D.new(); n.text=text; n.position=at
	n.font_size=size; n.pixel_size=.005; n.outline_size=0; n.modulate=Color("ded3b7"); parent.add_child(n)

static func build(parent: Node3D, id: String, w: float, d: float) -> void:
	var timber := preload("res://scripts/work/higgsfield_materials.gd").surface("repair_wood",.8).duplicate()
	timber.uv1_triplanar=true
	match id:
		"tiem_sau":
			var x := w*.24
			M.box(parent,Vector3(x,1.85,-3.03),Vector3(2.15,1.0,.07),M.mat("655b43"))
			for i in 6:
				var tool := M.screwdriver(parent); tool.position=Vector3(x-.85+i*.32,1.53,-2.97); tool.scale=Vector3.ONE*1.3
			for i in 3:
				M.box(parent,Vector3(-w*.30,.7+i*.48,-2.8),Vector3(1.3,.045,.40),timber)
				for j in 4:
					M.casing(parent,Vector3(-w*.30-.48+j*.32,.81+i*.48,-2.8),Vector3(.23,.18,.24),M.mat(["776851","667265","8b7552","555f5a"][j]))
			label(parent,"TỤ · CẦU CHÌ · DÂY ĐIỆN",Vector3(-w*.30,2.02,-2.7))
			var meter := M.meter(parent,Vector3(x+.35,.98,-1.45)); meter.scale=Vector3.ONE*.35
			label(parent,"ĐỒ CHỜ TRẢ",Vector3(w*.40,1.22,-2.65),22)
		"com_hanh":
			var x := w*.30
			M.box(parent,Vector3(x,.60,-2.9),Vector3(1.85,.85,.70),M.mat("75837a",.45))
			M.box(parent,Vector3(x,1.04,-2.9),Vector3(1.95,.04,.78),M.mat("b0b9ac",.6,.4))
			for i in 3:
				M.casing(parent,Vector3(x-.62+i*.62,1.10,-2.9),Vector3(.54,.08,.52),M.mat("adb6ac",.55,.4))
				for j in 6: M.ellipsoid(parent,Vector3(x-.78+i*.62+(j%3)*.16,1.15,-3.01+(j/3)*.17),Vector3(.15,.045,.15),M.mat(["8c633b","667643","b59761"][i]))
			M.box(parent,Vector3(x,2.06,-3.06),Vector3(1.8,.73,.05),M.mat("344a3e"))
			label(parent,"CƠM NHÀ\nSườn · Rau · Canh\nMời thêm cơm",Vector3(x,2.06,-3.02),27)
			for i in 5:
				var plate := P.dish("com"); parent.add_child(plate); plate.position=Vector3(-w*.3+.55,1.1+i*.022,-2.0); plate.scale=Vector3.ONE*.7
			for z in [-1.05,-1.30]:
				M.rod(parent,Vector3(-w*.3+.1,.92,z),Vector3(-w*.3+.1,1.07,z),.024,M.mat("604a36"))
		"xom_bo_me":
			# Side rooms beside the entry, with separate sleeping and study corners.
			for side in [-1.0,1.0]:
				var x: float = side*w*.30
				M.box(parent,Vector3(x,.36,-2.3),Vector3(1.45,.16,2.15),timber)
				M.casing(parent,Vector3(x,.49,-2.3),Vector3(1.40,.12,2.05),M.mat("8c9485" if side<0 else "7c8b91"))
				M.ellipsoid(parent,Vector3(x,.59,-3.05),Vector3(.90,.15,.45),M.mat("c4bda4"))
				M.box(parent,Vector3(x,.57,-1.8),Vector3(1.38,.04,.85),M.mat("6b7560" if side<0 else "8a7365"))
				M.box(parent,Vector3(x+side*.9,.65,-3.0),Vector3(.55,.05,.65),timber)
				for i in 3: M.box(parent,Vector3(x+side*.9,.70+i*.025,-3.0),Vector3(.20,.023,.28),M.mat(["99755c","a89c7c","667565"][i]))
				label(parent,"PHÒNG 01" if side<0 else "PHÒNG 02",Vector3(x,2.15,-3.25),22)
			var kettle := P.kettle(); parent.add_child(kettle); kettle.position=Vector3(-minf(w*.22,2.8)+.65,.18,-d+1.1)
