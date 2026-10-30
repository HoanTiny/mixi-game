extends SceneTree
## Rebuild the native vehicle library and check geometry without an editor import.
const Props := preload("res://scripts/world/props3d.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/vehicles")
	for entry in [["scooter", Props.motorbike("tay_ga", true)], ["underbone", Props.motorbike("xe_so", true)], ["compact_car", Props.car(true)]]:
		var mesh: ArrayMesh = entry[1]
		assert(mesh.get_surface_count() == 1, "One vehicle surface is required for traffic batching")
		var data := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
		var uv: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
		var wheels: PackedVector2Array = data[Mesh.ARRAY_TEX_UV2]
		assert(wheels.size() == vertices.size(), "Every close vehicle vertex must explicitly tag wheel or fixed body")
		var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
		var reversed := 0
		var degenerate := 0
		for i in range(0, indices.size(), 3):
			var a := indices[i]
			var b := indices[i + 1]
			var c := indices[i + 2]
			var cross := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
			if cross.length_squared() < 1e-16:
				degenerate += 1
			elif cross.dot(normals[a] + normals[b] + normals[c]) > 1e-6:
				reversed += 1
		for i in vertices.size():
			assert(vertices[i].is_finite() and normals[i].is_finite())
			assert(uv[i].x < -0.5 and uv[i].y >= 0.16 and uv[i].y <= 0.98)
			if wheels[i].x > 0.01:
				assert(absf(wheels[i].x - (0.315 if entry[0] == "compact_car" else 0.27)) < 0.0001)
				assert(Vector2(vertices[i].y, vertices[i].z).distance_to(wheels[i]) <= wheels[i].x + 0.004,
					"Rotating geometry must remain inside its wheel envelope")
		assert(reversed == 0, "Front-face winding must agree with normals")
		assert(mesh.get_aabb().position.y >= -0.01 and mesh.get_aabb().size.y < 1.6)
		mesh.surface_set_material(0, Props.material(Color("626e62")))
		var path := "res://assets/vehicles/%s.res" % entry[0]
		assert(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) == OK)
		var loaded: ArrayMesh = load(path)
		assert(loaded.get_surface_count() == 1)
		print("VEHICLE ", entry[0], " triangles=", indices.size() / 3, " vertices=", vertices.size(), " bounds=", mesh.get_aabb(), " degenerate_caps=", degenerate)
	assert(Props.motorbike("tay_ga", false).get_surface_count() == 1)
	assert(Props.car(false).get_surface_count() == 1)
	assert(Props.motorbike("tay_ga", true) == Props.motorbike("tay_ga", true))
	print("PASS vehicle near/far geometry, normals, finish masks, wheel envelopes, cache, bounds and saved resources")
	quit()
