extends RefCounted
## Authored street vehicles in metres. One opaque surface, with UV < 0 tagging
## paint/metal/rubber/glass response. No downloaded or extracted game assets.
## Shared geometry is deliberately separate from traffic, riders and collisions.

class Finish:
	var target
	var tag: Vector2
	var wheel := Vector2.ZERO
	var pts: PackedVector3Array:
		get: return target.pts
	func _init(mesh, material_kind: float, rough: float, pivot := Vector2.ZERO) -> void:
		target = mesh
		tag = Vector2(-material_kind, rough)
		wheel = pivot
	func vert(at: Vector3, normal: Vector3, color: Color, bones: Array, _uv := Vector2.ZERO) -> int:
		# UV2 is reserved for close-vehicle wheel rotation: radius (= hub Y), hub Z.
		# Every vertex writes this, including zero on the fixed body and calipers.
		target.st.set_uv2(wheel)
		return target.vert(at, normal, color, bones, tag)
	func tri(a: int, b: int, c: int) -> void:
		target.tri(a, b, c)


static func _fixed(hex: String) -> Color:
	var c := Color(hex)
	return Color(c.r, c.g, c.b, 0.0)


static func _paint(value := 0.88) -> Color:
	return Color(value, value, value, 1.0)


## Rounded tire with open cast rim, centre hub and inset brake disc. Its axis is x.
static func _wheel(g, p, at: Vector3, radius: float, width: float, spokes := 5) -> void:
	var pivot := Vector2(radius, at.z)
	var rubber := Finish.new(g, 1.0, 0.94, pivot)
	var alloy := Finish.new(g, 2.0, 0.37, pivot)
	var iron := Finish.new(g, 2.0, 0.64, pivot)
	var rim := radius * 0.72
	_torus(rubber, at, radius * 0.86, radius * 0.14, width * 0.5, _fixed("242622"), 28, 8)
	for side in [-1.0, 1.0]:
		var face := at + Vector3(side * width * 0.39, 0, 0)
		_torus(alloy, face, rim, radius * 0.026, width * 0.06, _fixed("92978f"), 28, 5)
		p._cyl(iron, face - Vector3(0.012, 0, 0), face + Vector3(0.012, 0, 0), radius * 0.20, radius * 0.20, _fixed("595b56"), 12)
		# The hub-to-rim gaps remain genuinely open, rather than a solid grey disk.
		for i in spokes:
			var angle := TAU * float(i) / float(spokes) + 0.2
			var d := Vector3(0, sin(angle), cos(angle))
			var turn := Vector3(0, sin(angle + 0.17), cos(angle + 0.17))
			p._cyl(alloy, face + d * radius * 0.19, face + turn * rim, radius * 0.048, radius * 0.035, _fixed("858a85"), 5)
		# Fine sidewall bead catches light independently of the tread.
		_torus(rubber, at + Vector3(side * width * 0.46, 0, 0), radius * 0.81, radius * 0.012, width * 0.02, _fixed("30312d"), 28, 4)
	# Tread grooves are short dark bars over the crown, not large faceted blocks.
	for i in 24:
		var a := TAU * float(i) / 24.0
		var d := Vector3(0, sin(a), cos(a))
		var e := Vector3(0, sin(a + 0.042), cos(a + 0.042))
		p._cyl(rubber, at + Vector3(-width * 0.26, 0, 0) + d * radius * 0.999,
			at + Vector3(width * 0.26, 0, 0) + e * radius * 0.999,
			radius * 0.007, radius * 0.007, _fixed("171a18"), 4, false)
	# A brake rotor sits behind the spokes on one side; it is smaller than the rim.
	var rotor := at + Vector3(width * 0.22, 0, 0)
	_torus(iron, rotor, radius * 0.42, radius * 0.08, 0.006, _fixed("686b63"), 20, 4)
	p._box(Finish.new(g, 2.0, 0.64), rotor + Vector3(0.012, radius * 0.3, radius * 0.2), Vector3(0.04, radius * 0.21, radius * 0.15), _fixed("343733"))


static func _torus(g, center: Vector3, major: float, radial: float, axial: float, color: Color, segments: int, cross_segments: int) -> void:
	var rows: Array[PackedInt32Array] = []
	for i in segments:
		var a := TAU * float(i) / float(segments)
		var direction := Vector3(0, sin(a), cos(a))
		var row := PackedInt32Array()
		for j in cross_segments:
			var b := TAU * float(j) / float(cross_segments)
			var normal := (direction * cos(b) / radial + Vector3.RIGHT * sin(b) / axial).normalized()
			row.append(g.vert(center + direction * (major + radial * cos(b)) + Vector3.RIGHT * axial * sin(b), normal, color, []))
		rows.append(row)
	for i in segments:
		for j in cross_segments:
			var i1 := (i + 1) % segments
			var j1 := (j + 1) % cross_segments
			g.tri(rows[i][j], rows[i1][j], rows[i1][j1])
			g.tri(rows[i][j], rows[i1][j1], rows[i][j1])


static func _fender(g, center: Vector3, color: Color) -> void:
	var rows := []
	for pair in [[-0.072, 0.31], [-0.042, 0.324], [0.042, 0.324], [0.072, 0.31]]:
		var row := PackedInt32Array()
		for i in 17:
			var a := lerpf(deg_to_rad(15.0), deg_to_rad(151.0), float(i) / 16.0)
			var n := Vector3(float(pair[0]) * 3.5, sin(a), cos(a)).normalized()
			row.append(g.vert(center + Vector3(pair[0], sin(a) * pair[1], cos(a) * pair[1]), n, color, []))
		rows.append(row)
	for j in 3:
		for i in 16:
			g.tri(rows[j][i], rows[j + 1][i], rows[j + 1][i + 1])
			g.tri(rows[j][i], rows[j + 1][i + 1], rows[j][i + 1])


## Upright fairings need a fixed frame: an automatically transported frame can
## flip when the centreline's z slope changes sign, tearing the leg shield.
static func _upright(g, rings: Array, segments := 16) -> void:
	var rows := []
	for r in rings:
		var row := PackedInt32Array()
		for i in segments:
			var a := TAU * (float(i) + 0.5) / float(segments)
			var offset := Vector3(cos(a) * r.w, 0, sin(a) * r.h)
			var normal := Vector3(cos(a) / r.w, 0, sin(a) / r.h).normalized()
			row.append(g.vert(r.c + offset, normal, r.col, []))
		rows.append(row)
	for j in rings.size() - 1:
		for i in segments:
			var k := (i + 1) % segments
			g.tri(rows[j][i], rows[j + 1][i], rows[j + 1][k])
			g.tri(rows[j][i], rows[j + 1][k], rows[j][k])
	for end in [0, rings.size() - 1]:
		var normal := (Vector3.DOWN if end == 0 else Vector3.UP) * signf(rings[-1].c.y - rings[0].c.y)
		var r: Dictionary = rings[end]
		var mid: int = g.vert(r.c, normal, r.col, [])
		var rim := PackedInt32Array()
		for i in segments:
			rim.append(g.vert(g.pts[rows[end][i]], normal, r.col, []))
		for i in segments:
			g.tri(mid, rim[i], rim[(i + 1) % segments])


static func motorcycle(g, kind: String, p) -> void:
	var shell := Finish.new(g, 1.0, 0.34)
	var plastic := Finish.new(g, 1.0, 0.78)
	var rubber := Finish.new(g, 1.0, 0.94)
	var metal := Finish.new(g, 2.0, 0.42)
	var dark_metal := Finish.new(g, 2.0, 0.62)
	var lens := Finish.new(g, 3.0, 0.22)
	var head_lamp := Finish.new(g, 4.0, 0.22)
	var tail_lamp := Finish.new(g, 5.0, 0.24)
	var scooter := kind == "tay_ga"
	var grey := _fixed("777c76")
	var dark := _fixed("353833")
	var black := _fixed("252623")
	var front := Vector3(0, 0.27, 0.76)
	var back := Vector3(0, 0.27, -0.58)
	_wheel(g, p, front, 0.27, 0.10)
	_wheel(g, p, back, 0.27, 0.12)
	# Rear body follows the seat instead of becoming an inflated capsule.
	p._loft(shell, [p._r(Vector3(0, 0.68, -0.96), 0.055, 0.035, _paint(0.78)),
		p._r(Vector3(0, 0.64, -0.84), 0.145, 0.09, _paint()),
		p._r(Vector3(0, 0.59, -0.58), 0.18 if scooter else 0.15, 0.15, _paint()),
		p._r(Vector3(0, 0.55, -0.29), 0.175 if scooter else 0.13, 0.16, _paint()),
		p._r(Vector3(0, 0.51, -0.05), 0.095, 0.085, _paint(0.84)),
		p._r(Vector3(0, 0.44, 0.10), 0.025, 0.030, _paint(0.80))], 16)
	# Continuous saddle, stitched edge and passenger grab rail.
	p._loft(rubber, [p._r(Vector3(0, 0.78, -0.92), 0.075, 0.025, black, 0.28),
		p._r(Vector3(0, 0.80, -0.78), 0.14, 0.047, black, 0.25),
		p._r(Vector3(0, 0.79, -0.45), 0.157, 0.055, black, 0.23),
		p._r(Vector3(0, 0.775, -0.12), 0.13, 0.05, black, 0.2),
		p._r(Vector3(0, 0.755, 0.025), 0.07, 0.024, black, 0.18)], 16)
	for s in [-1.0, 1.0]:
		p._cyl(rubber, Vector3(s * 0.137, 0.793, -0.78), Vector3(s * 0.15, 0.783, -0.38), 0.003, 0.003, _fixed("59594e"), 4)
		p._cyl(metal, Vector3(s * 0.15, 0.76, -0.6), Vector3(s * 0.175, 0.80, -0.91), 0.012, 0.012, grey, 8)
	p._cyl(metal, Vector3(-0.175, 0.80, -0.91), Vector3(0.175, 0.80, -0.91), 0.012, 0.012, grey, 8)
	if scooter:
		p._loft(shell, [p._r(Vector3(0, 0.25, -0.14), 0.16, 0.06, _paint(0.77), 0.45),
			p._r(Vector3(0, 0.25, 0.39), 0.17, 0.06, _paint(0.77), 0.45)], 16)
		p._box(plastic, Vector3(0, 0.32, 0.13), Vector3(0.30, 0.035, 0.52), dark)
		for s in [-1.0, 1.0]:
			for i in 4:
				p._box(rubber, Vector3(s * (0.05 + i * 0.025), 0.341, 0.12), Vector3(0.009, 0.006, 0.43), black)
		# Layered leg shield, a curved outer painted shell and visible inset plastics.
		_upright(shell, [p._r(Vector3(0, 0.28, 0.44), 0.18, 0.055, _paint()),
			p._r(Vector3(0, 0.52, 0.49), 0.225, 0.075, _paint()),
			p._r(Vector3(0, 0.76, 0.50), 0.20, 0.075, _paint()),
			p._r(Vector3(0, 0.94, 0.46), 0.105, 0.065, _paint())], 16)
		_upright(plastic, [p._r(Vector3(0, 0.37, 0.37), 0.13, 0.018, dark),
			p._r(Vector3(0, 0.72, 0.40), 0.15, 0.022, dark),
			p._r(Vector3(0, 0.91, 0.39), 0.08, 0.02, dark)], 12)
		# CVT case and rear swing arm remain visible below the fairing.
		p._loft(dark_metal, [p._r(Vector3(0.085, 0.30, -0.67), 0.07, 0.09, dark),
			p._r(Vector3(0.085, 0.32, -0.37), 0.08, 0.115, dark),
			p._r(Vector3(0.065, 0.32, -0.13), 0.065, 0.09, dark)], 12)
	else:
		_upright(shell, [p._r(Vector3(0, 0.98, 0.45), 0.065, 0.055, _paint()),
			p._r(Vector3(0, 0.72, 0.37), 0.075, 0.06, _paint()),
			p._r(Vector3(0, 0.47, 0.17), 0.09, 0.08, _paint()),
			p._r(Vector3(0, 0.43, -0.07), 0.10, 0.07, _paint())], 14)
		# Off-white leg guards are separate from the painted frame of the underbone.
		_upright(plastic, [p._r(Vector3(0, 0.36, 0.42), 0.145, 0.028, _fixed("b4b3a2")),
			p._r(Vector3(0, 0.60, 0.44), 0.18, 0.035, _fixed("c4c2ae")),
			p._r(Vector3(0, 0.84, 0.44), 0.115, 0.03, _fixed("bebdac"))], 14)
		p._blob(dark_metal, Vector3(0, 0.31, -0.015), Vector3(0.135, 0.11, 0.13), _fixed("666b62"), 6, 14)
		# Horizontal cylinder with cooling fins, crankcase and exposed pedal.
		for i in 6:
			p._box(dark_metal, Vector3(0, 0.32, 0.09 + i * 0.023), Vector3(0.20, 0.135, 0.012), grey)
		p._cyl(metal, Vector3(-0.15, 0.30, -0.02), Vector3(-0.16, 0.30, -0.02), 0.068, 0.068, grey, 16)
		p._cyl(metal, Vector3(-0.17, 0.28, -0.02), Vector3(-0.20, 0.34, 0.20), 0.010, 0.010, grey, 6)
		p._cyl(rubber, Vector3(-0.20, 0.34, 0.20), Vector3(-0.26, 0.34, 0.20), 0.017, 0.017, black, 8)
	# Rear fork and shock absorbers, with actual coil turns around each shaft.
	for s in [-1.0, 1.0]:
		p._cyl(dark_metal, Vector3(s * 0.095, 0.29, -0.04), Vector3(s * 0.095, 0.27, -0.58), 0.021, 0.021, dark, 8)
		p._cyl(metal, Vector3(s * 0.105, 0.29, -0.56), Vector3(s * 0.105, 0.63, -0.67), 0.012, 0.012, grey, 8)
		for i in 6:
			var start := Vector3(s * 0.105, 0.39 + i * 0.032, -0.594 - i * 0.010)
			# Small opposing spring segments give readable coil highlights at game distance.
			p._cyl(dark_metal, start + Vector3(-0.025, 0, 0), start + Vector3(0.025, 0.014, 0), 0.005, 0.005, dark, 5)
		p._cyl(metal, Vector3(s * 0.09, 0.53, 0.66), Vector3(s * 0.065, 0.93, 0.48), 0.018, 0.018, grey, 10)
		p._cyl(dark_metal, Vector3(s * 0.09, 0.27, 0.76), Vector3(s * 0.09, 0.55, 0.65), 0.028, 0.024, dark, 10)
		p._cyl(metal, Vector3(s * 0.06, 0.36, -0.21), Vector3(s * 0.245, 0.36, -0.21), 0.012, 0.012, grey, 8)
		p._cyl(rubber, Vector3(s * 0.17, 0.36, -0.21), Vector3(s * 0.245, 0.36, -0.21), 0.022, 0.022, black, 8)
	# Fender arch clears the wheel, plus a narrow mud flap behind the tire.
	_fender(shell, Vector3(0, 0.27, 0.76), _paint())
	p._box(rubber, Vector3(0, 0.22, -0.88), Vector3(0.10, 0.18, 0.02), black)
	# Exhaust header, silencer, heat shield and a dark open outlet.
	p._loft(dark_metal, [p._r(Vector3(-0.08, 0.24, 0.15), 0.018, 0.018, dark),
		p._r(Vector3(-0.18, 0.24, -0.12), 0.02, 0.02, dark),
		p._r(Vector3(-0.20, 0.29, -0.42), 0.045, 0.045, dark),
		p._r(Vector3(-0.20, 0.34, -0.86), 0.04, 0.04, dark)], 12)
	p._loft(metal, [p._r(Vector3(-0.238, 0.31, -0.37), 0.012, 0.037, grey),
		p._r(Vector3(-0.238, 0.35, -0.75), 0.012, 0.035, grey)], 10)
	p._blob(rubber, Vector3(-0.20, 0.34, -0.868), Vector3(0.028, 0.028, 0.006), _fixed("111614"), 4, 12)
	# Handlebar cover, inset instrument panel and physical brake levers.
	p._cyl(dark_metal, Vector3(0, 0.91, 0.46), Vector3(0, 1.065, 0.45), 0.034, 0.029, dark, 10)
	p._blob(shell, Vector3(0, 1.065, 0.45), Vector3(0.205, 0.072, 0.13), _paint(), 7, 20)
	p._blob(plastic, Vector3(0, 1.102, 0.394), Vector3(0.115, 0.026, 0.065), black, 5, 14)
	p._blob(lens, Vector3(0, 1.116, 0.392), Vector3(0.082, 0.015, 0.045), _fixed("737e6c"), 4, 14)
	p._blob(head_lamp, Vector3(0, 1.057, 0.572), Vector3(0.107, 0.045, 0.022), _fixed("969f92"), 5, 18)
	for s in [-1.0, 1.0]:
		p._cyl(metal, Vector3(s * 0.16, 1.07, 0.40), Vector3(s * 0.34, 1.07, 0.385), 0.015, 0.015, grey, 8)
		p._cyl(rubber, Vector3(s * 0.25, 1.07, 0.385), Vector3(s * 0.345, 1.07, 0.385), 0.022, 0.022, black, 10)
		p._cyl(metal, Vector3(s * 0.245, 1.075, 0.41), Vector3(s * 0.345, 1.065, 0.447), 0.007, 0.006, grey, 6)
		p._cyl(dark_metal, Vector3(s * 0.19, 1.09, 0.42), Vector3(s * 0.275, 1.285, 0.42), 0.008, 0.008, dark, 8)
		p._blob(plastic, Vector3(s * 0.275, 1.31, 0.42), Vector3(0.072, 0.045, 0.017), black, 6, 14)
		p._blob(lens, Vector3(s * 0.275, 1.31, 0.401), Vector3(0.062, 0.035, 0.004), _fixed("8eaaa8"), 5, 14)
		p._blob(lens, Vector3(s * 0.153, 0.82, 0.565), Vector3(0.03, 0.05, 0.017), _fixed("aa7035"), 4, 10)
		p._blob(lens, Vector3(s * 0.10, 0.68, -0.945), Vector3(0.033, 0.024, 0.018), _fixed("aa7035"), 4, 10)
		# Restrained side stripe and visible fasteners, no fictional brand names.
		p._cyl(plastic, Vector3(s * 0.165, 0.61, -0.71), Vector3(s * 0.16, 0.55, -0.30), 0.005, 0.005, _fixed("8e9184"), 4)
	p._blob(tail_lamp, Vector3(0, 0.70, -0.96), Vector3(0.068, 0.035, 0.018), _fixed("813a2d"), 4, 14)
	p._box(dark_metal, Vector3(0, 0.50, -0.93), Vector3(0.19, 0.14, 0.018), dark)
	p._box(plastic, Vector3(0, 0.50, -0.942), Vector3(0.17, 0.115, 0.006), _fixed("b5b7a4"))
	for i in 5:
		p._box(plastic, Vector3(-0.052 + i * 0.025, 0.49, -0.947), Vector3(0.010, 0.032, 0.002), _fixed("454a43"))


static func _quad(g, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	var ids := []
	for v in [a, b, c, d]:
		ids.append(g.vert(v, normal, color, []))
	g.tri(ids[0], ids[1], ids[2])
	g.tri(ids[0], ids[2], ids[3])


## Continuous body shell with the wheel openings cut into the lower edge. Each
## side grows from one sill into the fender and bumper instead of separate boxes.
static func _car_body(g) -> void:
	var rows := []
	for i in 85:
		var z := lerpf(-2.10, 2.10, float(i) / 84.0)
		var end := smoothstep(1.55, 2.10, absf(z))
		var width := lerpf(0.853, 0.755, end)
		var deck := lerpf(0.987, 0.83 if z < 0.0 else 0.79, end)
		var shoulder := deck - 0.075
		var bottom := 0.365
		for wheel_z in [-1.30, 1.30]:
			var dz: float = absf(z - wheel_z)
			if dz < 0.39:
				bottom = maxf(bottom, 0.315 + sqrt(0.39 * 0.39 - dz * dz))
		var profile := [Vector2(-width * 0.96, bottom), Vector2(-width, shoulder),
			Vector2(-width * 0.88, deck), Vector2(0, deck + 0.012),
			Vector2(width * 0.88, deck), Vector2(width, shoulder), Vector2(width * 0.96, bottom)]
		var normals := [Vector3(-1, -0.06, 0).normalized(), Vector3(-1, 0.3, 0).normalized(),
			Vector3(-0.25, 1, 0).normalized(), Vector3.UP, Vector3(0.25, 1, 0).normalized(),
			Vector3(1, 0.3, 0).normalized(), Vector3(1, -0.06, 0).normalized()]
		var row := PackedInt32Array()
		for j in profile.size():
			row.append(g.vert(Vector3(profile[j].x, profile[j].y, z), normals[j], _paint(0.89), []))
		rows.append(row)
	for i in rows.size() - 1:
		for j in 6:
			g.tri(rows[i][j], rows[i + 1][j], rows[i + 1][j + 1])
			g.tri(rows[i][j], rows[i + 1][j + 1], rows[i][j + 1])
	for end in [0, rows.size() - 1]:
		var normal := Vector3.FORWARD if end == 0 else Vector3.BACK
		var edge: PackedInt32Array = rows[end]
		var center: Vector3 = (g.pts[edge[0]] + g.pts[edge[6]] + g.pts[edge[3]]) / 3.0
		var mid: int = g.vert(center, normal, _paint(0.85), [])
		var face := PackedInt32Array()
		for j in 7:
			face.append(g.vert(g.pts[edge[j]], normal, _paint(0.85), []))
		for j in 7:
			g.tri(mid, face[j], face[(j + 1) % 7])


static func car(g, p) -> void:
	var paint := Finish.new(g, 1.0, 0.33)
	var trim := Finish.new(g, 1.0, 0.76)
	var metal := Finish.new(g, 2.0, 0.36)
	var glass := Finish.new(g, 6.0, 0.28)
	var indicator := Finish.new(g, 3.0, 0.24)
	var head_lamp := Finish.new(g, 4.0, 0.22)
	var tail_lamp := Finish.new(g, 5.0, 0.24)
	var dark := _fixed("303934")
	# The cabin is a four-door compact car. Body panels leave wheel arches open.
	_car_body(paint)
	p._box(trim, Vector3(0, 0.40, 0), Vector3(1.30, 0.22, 3.60), dark)
	for s in [-1.0, 1.0]:
		for z in [-1.30, 1.30]:
			_wheel(g, p, Vector3(s * 0.78, 0.315, z), 0.315, 0.20, 6)
			# Thin curved paint lip over each wheel, with a dark inner arch.
			for layer in [0, 1]:
				var rad: float = 0.365 + layer * 0.023
				var color := _paint(0.92) if layer == 1 else dark
				for k in 14:
					var a := PI * float(k) / 14.0
					var b := PI * float(k + 1) / 14.0
					p._cyl(paint if layer == 1 else trim,
						Vector3(s * 0.86, 0.315 + sin(a) * rad, z + cos(a) * rad),
						Vector3(s * 0.86, 0.315 + sin(b) * rad, z + cos(b) * rad),
						0.025, 0.025, color, 5)
		# Window panels are inset between A, B and C pillars, with a metal sill.
		var a := Vector3(s * 0.82, 0.995, 0.83)
		var b := Vector3(s * 0.66, 1.405, 0.37)
		var c := Vector3(s * 0.66, 1.405, -0.73)
		var d := Vector3(s * 0.82, 0.995, -1.20)
		_quad(glass, a, b, c, d, Vector3(s, 0.25, 0).normalized(), _fixed("3d4d50"))
		for pair in [[a, b], [b, c], [c, d], [d, a]]:
			p._cyl(paint, pair[0], pair[1], 0.018, 0.018, _paint(0.9), 8)
		p._cyl(trim, Vector3(s * 0.812, 1.005, -0.24), Vector3(s * 0.664, 1.398, -0.24), 0.036, 0.036, dark, 8)
		# Door cut lines are recessed narrow strips, with separate handles.
		for z in [-0.23, -1.03, 0.80]:
			p._cyl(trim, Vector3(s * 0.852, 0.91, z), Vector3(s * 0.825, 0.41, z), 0.0035, 0.0035, dark, 4)
		for z in [-0.84, 0.01]:
			p._box(metal, Vector3(s * 0.857, 0.92, z), Vector3(0.020, 0.025, 0.12), _fixed("989e98"))
		p._cyl(trim, Vector3(s * 0.81, 1.03, 0.67), Vector3(s * 0.98, 1.06, 0.66), 0.02, 0.02, dark, 8)
		p._blob(paint, Vector3(s * 1.0, 1.07, 0.65), Vector3(0.10, 0.055, 0.09), _paint(0.84), 6, 12)
		p._blob(glass, Vector3(s * 1.0, 1.07, 0.558), Vector3(0.075, 0.040, 0.006), _fixed("92a6a3"), 5, 10)
		# Shaped lamp housings and inset turn signals; both remain opaque for batching.
		p._blob(trim, Vector3(s * 0.55, 0.71, 2.104), Vector3(0.185, 0.064, 0.022), dark, 5, 14)
		p._blob(head_lamp, Vector3(s * 0.55, 0.712, 2.123), Vector3(0.164, 0.048, 0.010), _fixed("969f92"), 5, 14)
		p._blob(indicator, Vector3(s * 0.72, 0.706, 2.12), Vector3(0.027, 0.042, 0.014), _fixed("a97840"), 4, 10)
		p._blob(tail_lamp, Vector3(s * 0.59, 0.74, -2.111), Vector3(0.14, 0.053, 0.018), _fixed("833d34"), 5, 14)
	# Windshield/rear glass with a slight blue-grey reflection tint.
	_quad(glass, Vector3(-0.79, 1.0, 0.84), Vector3(0.79, 1.0, 0.84),
		Vector3(0.65, 1.40, 0.37), Vector3(-0.65, 1.40, 0.37), Vector3(0, 0.75, 0.65), _fixed("3d4d50"))
	_quad(glass, Vector3(-0.79, 1.0, -1.20), Vector3(-0.65, 1.40, -0.73),
		Vector3(0.65, 1.40, -0.73), Vector3(0.79, 1.0, -1.20), Vector3(0, 0.75, -0.65), _fixed("3d4d50"))
	p._loft(paint, [p._r(Vector3(0, 1.418, -0.76), 0.665, 0.018, _paint(), 0.4),
		p._r(Vector3(0, 1.435, -0.59), 0.675, 0.025, _paint(), 0.4),
		p._r(Vector3(0, 1.435, 0.22), 0.675, 0.025, _paint(), 0.4),
		p._r(Vector3(0, 1.418, 0.40), 0.665, 0.018, _paint(), 0.4)], 16)
	for s in [-1.0, 1.0]:
		p._cyl(trim, Vector3(s * 0.35, 1.02, 0.815), Vector3(s * 0.35 - 0.26, 1.08, 0.75), 0.006, 0.006, dark, 5)
	# Horizontal grille slats, lower intake, bumper rubbing strips and plates.
	p._box(trim, Vector3(0, 0.66, 2.109), Vector3(0.72, 0.16, 0.018), dark)
	for row in 4:
		p._box(metal, Vector3(0, 0.61 + row * 0.034, 2.123), Vector3(0.68, 0.009, 0.009), _fixed("747e76"))
	for z in [-2.09, 2.10]:
		p._box(trim, Vector3(0, 0.47, z), Vector3(1.42, 0.075, 0.04), dark)
		p._box(trim, Vector3(0, 0.52, z + signf(z) * 0.025), Vector3(0.48, 0.13, 0.014), _fixed("363f37"))
		p._box(trim, Vector3(0, 0.52, z + signf(z) * 0.034), Vector3(0.445, 0.105, 0.006), _fixed("b8bca8"))
		for i in 7:
			p._box(trim, Vector3(-0.15 + i * 0.05, 0.52, z + signf(z) * 0.039), Vector3(0.017, 0.046, 0.002), _fixed("455047"))
