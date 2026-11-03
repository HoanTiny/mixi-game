extends RefCounted
## Shared asymmetrical tree meshes for city MultiMeshes. No per-tree nodes,
## textures or alpha cards; existing instance cutaway/variation remains active.
static var _trunk: ArrayMesh
static var _crown: ArrayMesh

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normals: Array[Vector3], color: Color) -> void:
	var points := [a,b,c]
	var order := [0,1,2]
	if (b-a).cross(c-a).dot(normals[0]+normals[1]+normals[2])>0:
		order=[0,2,1]
	for i in order:
		st.set_color(color)
		st.set_normal(normals[i])
		st.add_vertex(points[i])

static func _branch(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var direction := (b-a).normalized()
	var u := direction.cross(Vector3.FORWARD).normalized()
	if u.length_squared()<0.01:
		u=Vector3.RIGHT
	var v := direction.cross(u).normalized()
	for i in 7:
		var n0 := u*cos(TAU*i/7.0)+v*sin(TAU*i/7.0)
		var n1 := u*cos(TAU*(i+1)/7.0)+v*sin(TAU*(i+1)/7.0)
		var col := Color(0.80+0.12*sin(i*2.4),0.80+0.12*sin(i*2.4),0.80+0.12*sin(i*2.4))
		_tri(st,a+n0*r0,a+n1*r0,b+n1*r1,[n0,n1,n1],col)
		_tri(st,a+n0*r0,b+n1*r1,b+n0*r1,[n0,n1,n0],col)

static func trunk() -> ArrayMesh:
	if _trunk!=null:
		return _trunk
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_branch(st,Vector3(0,-1.2,0),Vector3(0.08,1.8,-0.06),0.15,0.075)
	for i in 6:
		var angle := i*2.399
		var origin := Vector3(0.04,0.60+i*0.17,0)
		var end := Vector3(cos(angle)*(0.75+i*0.06),1.65+i*0.13,sin(angle)*(0.75+i*0.06))
		_branch(st,origin,end,0.075-i*0.007,0.018)
		_branch(st,end, end+Vector3(cos(angle+0.5)*0.25,0.35,sin(angle+0.5)*0.25),0.025,0.008)
	_trunk=st.commit()
	return _trunk

static func crown() -> ArrayMesh:
	if _crown!=null:
		return _crown
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Overlapping offset lobes leave an irregular outline instead of a solid ball.
	for cluster in 9:
		var angle := cluster*2.399
		var radius := 0.0 if cluster==8 else 0.85+0.15*sin(cluster*1.9)
		var center := Vector3(cos(angle)*radius,sin(cluster*1.7)*0.40+(0.3 if cluster==8 else 0.0),sin(angle)*radius)
		var size := Vector3(0.85+0.1*sin(cluster),0.62+0.16*cos(cluster*2.1),0.78+0.14*cos(cluster))
		for ring in 4:
			for segment in 8:
				var points: Array[Vector3]=[]
				var normals: Array[Vector3]=[]
				for pair in [[ring,segment],[ring,segment+1],[ring+1,segment+1],[ring+1,segment]]:
					var latitude := PI*float(pair[0])/4.0
					var longitude := TAU*float(pair[1])/8.0+cluster*0.31
					var normal := Vector3(sin(latitude)*cos(longitude),cos(latitude),sin(latitude)*sin(longitude))
					var ripple := 1.0+0.13*sin(longitude*3.0+cluster)*sin(latitude)
					points.append(center+normal*size*ripple)
					normals.append((normal/size).normalized())
				var light := 0.68+0.22*(1.0-float(ring)/4.0)+0.10*sin(cluster*3.1+segment*0.8)
				var col := Color(light,light,light)
				_tri(st,points[0],points[1],points[2],[normals[0],normals[1],normals[2]],col)
				_tri(st,points[0],points[2],points[3],[normals[0],normals[2],normals[3]],col)
	_crown=st.commit()
	return _crown
