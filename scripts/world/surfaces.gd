extends RefCounted
## Vật liệu tả thực từ texture Poly Haven trong assets/textures (màu, độ nhám, pháp tuyến).
## Chiếu texture theo tọa độ thế giới (triplanar) nên dán lên mọi khối hộp không cần UV,
## các khối kề nhau liền mạch. Thiếu file thì trả về vật liệu màu trơn như cũ.

const DIR := "res://assets/textures/"

static var _cache := {}


## name: tên bộ texture (via_he, duong, tuong, tuong_cu, ton, kim_loai). meters: một ô texture rộng bao nhiêu mét.
## tint: nhân màu (tường sơn nhiều màu dùng chung một texture vữa). vertex_color: nhân thêm màu theo đỉnh.
static func get_mat(name: String, meters := 2.0, tint := Color.WHITE, vertex_color := false) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [name, meters, tint.to_html(), vertex_color]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 1.0
	if ResourceLoader.exists(DIR + name + "_albedo.jpg"):
		m.albedo_texture = load(DIR + name + "_albedo.jpg")
		if ResourceLoader.exists(DIR + name + "_normal.jpg"):
			m.normal_enabled = true
			m.normal_texture = load(DIR + name + "_normal.jpg")
			m.normal_scale = 0.8
		if ResourceLoader.exists(DIR + name + "_rough.jpg"):
			m.roughness_texture = load(DIR + name + "_rough.jpg")
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / meters
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if vertex_color:
		m.vertex_color_use_as_albedo = true
	_cache[key] = m
	return m


## Bầu trời và ánh sáng môi trường từ ảnh HDRI (phố lúc chiều). null nếu thiếu file.
static func sky() -> Sky:
	var path := "res://assets/hdri/pho_chieu.hdr"
	if not ResourceLoader.exists(path):
		return null
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load(path)
	var s := Sky.new()
	s.sky_material = pm
	s.radiance_size = Sky.RADIANCE_SIZE_128
	return s
