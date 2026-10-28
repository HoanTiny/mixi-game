extends Node3D
## Textured player avatar. Color masks are stored on bind-pose vertices so they follow the rig.
const SHADER := preload("res://scripts/world/an_material.gdshader")
const DEFAULT_COLORS := {"hair":"28231e", "shirt":"969084", "pants":"657b8c"}
var model: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var materials: Array[ShaderMaterial] = []
var hair_meshes: Array[Dictionary] = []
var walk_clip := ""
var idle_clip := ""
var walking := false
var idle_time := 0.0

const PATH := "res://assets/characters/an/an-rigged.glb"


## Có mô hình An đã gắn xương trong dự án (bản xuất game chỉ có bản đã nhập, không có file .glb gốc).
static func available() -> bool:
	return ResourceLoader.exists(PATH) or FileAccess.file_exists(PATH)


func setup(_shirt: Color, _pants: Color, _identity := "An") -> void:
	# Trong trình sửa có file .glb gốc thì đọc thẳng (giữ ảnh gốc để dò vùng tóc, áo, quần); bản xuất game dùng bản
	# đã nhập của Godot.
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if OS.has_feature("editor") and doc.append_from_file(PATH, state) == OK:
		model = doc.generate_scene(state)
	elif ResourceLoader.exists(PATH):
		model = (load(PATH) as PackedScene).instantiate()
	else:
		push_error("Cannot load An rig: " + PATH)
		return
	add_child(model)
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animation = node
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	_prepare_materials()
	if animation:
		for clip in animation.get_animation_list():
			if clip == "RESET":
				continue
			var a := animation.get_animation(clip)
			a.loop_mode = Animation.LOOP_LINEAR
			if "idle" in clip.to_lower():
				idle_clip = clip
			elif walk_clip.is_empty() or "walk" in clip.to_lower():
				walk_clip = clip
		# Stop root translation from moving the avatar away from gameplay collisions.
		for clip in animation.get_animation_list():
			var a := animation.get_animation(clip)
			for track in range(a.get_track_count()):
				if a.track_get_type(track) == Animation.TYPE_POSITION_3D:
					var path_text := str(a.track_get_path(track)).to_lower()
					if "hip" in path_text or "root" in path_text:
						var origin: Vector3 = a.track_get_key_value(track, 0)
						for key in range(a.track_get_key_count(track)):
							var value: Vector3 = a.track_get_key_value(track, key)
							value.x = origin.x
							value.z = origin.z
							a.track_set_key_value(track, key, value)
		_create_idle()
		animation.play(idle_clip)
	set_colors(DEFAULT_COLORS)

func _create_idle() -> void:
	if not skeleton:
		return
	var idle := Animation.new()
	idle.length = 4.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var animation_root := animation.get_node(animation.root_node)
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		var rest := skeleton.get_bone_rest(bone)
		var track_path := NodePath(skeleton_path + ":" + bone_name)
		for kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:
			var track := idle.add_track(kind)
			idle.track_set_path(track,track_path)
			for time in [0.0,1.0,2.0,3.0,4.0]:
				if kind == Animation.TYPE_POSITION_3D:
					idle.position_track_insert_key(track,time,rest.origin)
				elif kind == Animation.TYPE_SCALE_3D:
					idle.scale_track_insert_key(track,time,rest.basis.get_scale())
				else:
					var rotation := rest.basis.get_rotation_quaternion()
					if bone_name.to_lower() == "spine":
						rotation *= Quaternion(Vector3.RIGHT, sin(time * TAU / 4.0) * 0.012)
					idle.rotation_track_insert_key(track,time,rotation)
	var library := AnimationLibrary.new()
	library.add_animation("idle",idle)
	animation.add_animation_library("an",library)
	idle_clip = "an/idle"

func _prepare_materials() -> void:
	for instance in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = instance.mesh
		var rebuilt := ArrayMesh.new()
		var trimmed := ArrayMesh.new()
		var box := mesh.get_aabb()
		for surface in range(mesh.get_surface_count()):
			var original := mesh.surface_get_material(surface) as StandardMaterial3D
			if not original or not original.albedo_texture:
				continue
			var source: Image = original.albedo_texture.get_image()
			if source == null:
				continue
			if source.is_compressed():
				source.decompress()
			if source.is_compressed():
				continue
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var masks := PackedColorArray()
			for i in vertices.size():
				var height := (vertices[i].y - box.position.y) / box.size.y
				var uv := uvs[i]
				var sample := source.get_pixel(clampi(int(uv.x * source.get_width()),0,source.get_width()-1),clampi(int(uv.y * source.get_height()),0,source.get_height()-1))
				var skin := sample.r > sample.b * 1.18 and sample.r > sample.g * 1.06 and sample.g > sample.b * 1.04
				var mask := Color(0,0,0,1)
				if height > 0.89 and sample.get_luminance() < 0.29 and not skin:
					mask.r = 1
				elif height > 0.06 and height < 0.55 and sample.b > sample.r * 1.01 and sample.b > sample.g * 0.97:
					mask.b = 1
				elif height > 0.49 and height < 0.84 and not skin:
					mask.g = 1
				elif height > 0.06 and height < 0.49 and not skin:
					mask.b = 1
				masks.append(mask)
			arrays[Mesh.ARRAY_COLOR] = masks
			rebuilt.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mat := ShaderMaterial.new()
			mat.shader = SHADER
			mat.set_shader_parameter("albedo_map", original.albedo_texture)
			mat.set_shader_parameter("normal_map", original.normal_texture)
			rebuilt.surface_set_material(rebuilt.get_surface_count()-1, mat)
			var cut_vertices := vertices.duplicate()
			var crown := box.position.y + box.size.y * 0.965
			for i in cut_vertices.size():
				cut_vertices[i].y -= maxf(cut_vertices[i].y - crown, 0.0) * 0.4
			arrays[Mesh.ARRAY_VERTEX] = cut_vertices
			trimmed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			trimmed.surface_set_material(trimmed.get_surface_count()-1, mat)
			materials.append(mat)
		instance.mesh = rebuilt
		hair_meshes.append({"instance":instance,"natural":rebuilt,"neat":trimmed})

func set_colors(colors: Dictionary) -> void:
	for mat in materials:
		for part in DEFAULT_COLORS:
			mat.set_shader_parameter(part+"_color", Color(str(colors.get(part,DEFAULT_COLORS[part]))).srgb_to_linear())

func set_hair_style(style: String) -> void:
	for entry in hair_meshes:
		entry.instance.mesh = entry.neat if style == "neat" else entry.natural

func animate_motion(speed: float, delta: float) -> void:
	if not animation or walk_clip.is_empty():
		return
	var moving := speed > 0.08
	if moving:
		if not walking:
			animation.play(walk_clip, 0.2)
		animation.speed_scale = clampf(speed / 1.5,0.65,1.8)
	elif walking or not animation.is_playing():
		animation.speed_scale = 1.0
		if not idle_clip.is_empty():
			animation.play(idle_clip,0.25)
		else:
			animation.pause()
	walking = moving
	idle_time += delta


# ---- Giao diện chung với thân người thật (human.gd) để world.gd dùng được như nhau.

## speed_ratio: tốc độ đi so với tốc độ chuẩn (0 là đứng yên).
func animate(delta: float, speed_ratio: float) -> void:
	animate_motion(speed_ratio * 1.5, delta)


## Ngồi lên yên xe máy: hạ người xuống ngang yên (mô hình chưa có tư thế ngồi riêng).
func sit(on: bool, seat_h: float) -> void:
	if model != null:
		model.position.y = (seat_h - 0.55) if on else 0.0
	if animation != null and on:
		animation.pause()
