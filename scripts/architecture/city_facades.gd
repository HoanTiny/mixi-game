extends RefCounted
## Street-facing architecture for the city batches. The original footprint is
## retained: reveals go into the building, projecting trim is at most 12 cm.
## UV2.x: 1.5 plaster without painted windows, -1 glass, -2 shutter slats.
## CUSTOM0 keeps the existing building cap index so every fitting cuts with it.

const WALLS := ["b8ad97", "a9aaa0", "b9aa97", "a59b89", "c1b49a", "a7aea2", "b4a290", "b7b5a8"]
const SHUTTERS := ["4d6259", "5c625f", "6d6559", "58616a", "746653"]

static func wall_color(seed: int, source: Color) -> Color:
	return Color(WALLS[posmod(seed, WALLS.size())]).lerp(source, 0.12)

static func _point(a: Vector2, d: Vector2, n: Vector2, x: float, y: float, z: float) -> Vector3:
	var p := a + d * x + n * z
	return Vector3(p.x, y, p.y)

static func _quad(st: SurfaceTool, points: Array[Vector3], normal: Vector3, col: Color, tag: float, top: float, uv: Array[Vector2]) -> void:
	var order := [0, 1, 2, 0, 2, 3]
	if (points[1] - points[0]).cross(points[2] - points[0]).dot(normal) > 0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(normal)
		st.set_color(col)
		st.set_uv(uv[i])
		st.set_uv2(Vector2(tag, top))
		st.add_vertex(points[i])

static func _panel(st: SurfaceTool, a: Vector2, d: Vector2, n: Vector2, x0: float, x1: float, y0: float, y1: float, z: float, col: Color, tag: float, top: float) -> void:
	if x1 - x0 < 0.001 or y1 - y0 < 0.001:
		return
	_quad(st, [_point(a,d,n,x0,y0,z), _point(a,d,n,x1,y0,z), _point(a,d,n,x1,y1,z), _point(a,d,n,x0,y1,z)],
		Vector3(n.x,0,n.y), col, tag, top, [Vector2(x0,y0),Vector2(x1,y0),Vector2(x1,y1),Vector2(x0,y1)])

static func _reveal(st: SurfaceTool, a: Vector2, d: Vector2, n: Vector2, x0: float, x1: float, y0: float, y1: float, recess: float, col: Color, top: float) -> void:
	var z := -recess
	for edge in [[x0, -1.0], [x1, 1.0]]:
		var x: float = edge[0]
		_quad(st, [_point(a,d,n,x,y0,0),_point(a,d,n,x,y0,z),_point(a,d,n,x,y1,z),_point(a,d,n,x,y1,0)],
			Vector3(d.x,0,d.y)*-float(edge[1]), col.darkened(0.12),1.5,top,
			[Vector2(0,y0),Vector2(recess,y0),Vector2(recess,y1),Vector2(0,y1)])
	for edge in [[y0,1.0],[y1,-1.0]]:
		var y: float = edge[0]
		_quad(st, [_point(a,d,n,x0,y,0),_point(a,d,n,x1,y,0),_point(a,d,n,x1,y,z),_point(a,d,n,x0,y,z)],
			Vector3.UP*float(edge[1]),col.darkened(0.05),1.5,top,
			[Vector2(x0,0),Vector2(x1,0),Vector2(x1,recess),Vector2(x0,recess)])

static func _frame(st: SurfaceTool, a: Vector2, d: Vector2, n: Vector2, x0: float, x1: float, y0: float, y1: float, col: Color, top: float, mullion: bool) -> void:
	for x in [x0-0.065,x1]:
		_panel(st,a,d,n,x,x+0.065,y0-0.07,y1+0.07,0.035,col,0,top)
	for y in [y0-0.07,y1]:
		_panel(st,a,d,n,x0,x1,y,y+0.07,0.035,col,0,top)
	if mullion:
		var mid := (x0+x1)*0.5
		_panel(st,a,d,n,mid-0.025,mid+0.025,y0,y1,-0.12,col,0,top)
		_panel(st,a,d,n,x0,x1,y0+(y1-y0)*0.7,y0+(y1-y0)*0.7+0.045,-0.12,col,0,top)
	# Sill with a real top plane, rather than a stripe painted on plaster.
	_quad(st, [_point(a,d,n,x0-0.1,y0-0.04,0),_point(a,d,n,x1+0.1,y0-0.04,0),_point(a,d,n,x1+0.1,y0-0.04,0.12),_point(a,d,n,x0-0.1,y0-0.04,0.12)],
		Vector3.UP,Color("817e72"),0,top,[Vector2.ZERO,Vector2(1,0),Vector2(1,0.12),Vector2(0,0.12)])

static func build(st: SurfaceTool, detail: SurfaceTool, idx: int, a: Vector2, end: Vector2, n: Vector2, base: float, height: float, wall: Color, seed: int) -> Dictionary:
	var length := a.distance_to(end)
	var d := (end-a)/maxf(length,0.001)
	var floors := clampi(floori((height-base+0.2)/3.2),1,7)
	var floor_h := (height-base)/floors
	var bays := clampi(roundi(length/4.3),1,12)
	var bay := length/bays
	var out := {"doors":0,"windows":0}
	for floor in floors:
		var low := base+floor*floor_h
		var high := base+(floor+1)*floor_h
		for i in bays:
			var left := i*bay
			var right := (i+1)*bay
			var door := floor==0
			var width := minf(bay-0.72,2.65 if door else 1.45)
			# Alternating narrow house entries and wider workshop shutters.
			if door and posmod(seed+i,4)==0:
				width=minf(width,1.2)
			width=maxf(width,0.7)
			var center := (left+right)*0.5
			var x0 := center-width*0.5
			var x1 := center+width*0.5
			var y0 := low+(0.12 if door else 0.74)
			var y1 := minf(low+(2.38 if door else 2.26),high-0.22)
			st.set_custom(0,Color(idx,1,0,0))
			_panel(st,a,d,n,left,x0,low,high,0,wall,1.5,height)
			_panel(st,a,d,n,x1,right,low,high,0,wall,1.5,height)
			_panel(st,a,d,n,x0,x1,low,y0,0,wall,1.5,height)
			_panel(st,a,d,n,x0,x1,y1,high,0,wall,1.5,height)
			_reveal(st,a,d,n,x0,x1,y0,y1,0.30 if door else 0.20,wall,height)
			# Backing remains in the base batch at all distances, so LOD cannot expose
			# holes. Detail trims/slats disappear with their floor, never get squashed.
			st.set_custom(0,Color(idx,3,0,0))
			var shutter := Color(SHUTTERS[posmod(seed+i,SHUTTERS.size())])
			_panel(st,a,d,n,x0,x1,y0,y1,-0.30 if door else -0.20,shutter if door else Color("37433f"),-2 if door else -1,y1+0.08)
			detail.set_custom(0,Color(idx,3,0,0))
			_frame(detail,a,d,n,x0,x1,y0,y1,shutter.lightened(0.08),y1+0.12,not door)
			if door:
				out.doors+=1
				_panel(detail,a,d,n,x1-0.18,x1-0.12,y0+0.8,y0+1.1,-0.25,Color("a5a297"),0,y1+0.12)
			else:
				out.windows+=1
				if posmod(seed+i+floor,3)==0:
					_panel(detail,a,d,n,x0,x0+width*0.31,y0,y1,-0.15,shutter,-2,y1+0.12)
		# Subtle floor edge and separate worn plinth give the facade human scale.
		detail.set_custom(0,Color(idx,3,0,0))
		_panel(detail,a,d,n,0,length,low+0.025,low+(0.30 if floor==0 else 0.12),0.018,wall.darkened(0.2),1.5,low+0.32)
	return out
