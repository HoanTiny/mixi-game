extends RefCounted
## Generated albedo only: lighting and roughness remain controlled by the game.
static var _cache: Dictionary = {}

static func surface(name: String, scale := 0.5, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [name, scale, tint.to_html()]
	if _cache.has(key): return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/higgsfield/%s.png" % name)
	m.albedo_color = tint
	m.roughness = 0.94
	m.metallic_specular = 0.18
	m.uv1_scale = Vector3.ONE * scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m
