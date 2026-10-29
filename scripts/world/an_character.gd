extends Node3D
## Textured player avatar. Color masks are stored on bind-pose vertices so they follow the rig.
const SHADER := preload("res://scripts/world/an_material.gdshader")
const DEFAULT_COLORS := {"hair":"28231e", "shirt":"969084", "pants":"657b8c"}
var model: Node3D
var animation: AnimationPlayer
var skeleton: Skeleton3D
var _mood_pose: SkeletonModifier3D
var materials: Array[ShaderMaterial] = []
var hair_meshes: Array[Dictionary] = []
var walk_clip := ""
var idle_clip := ""
var walking := false
var idle_time := 0.0
var sitting := false
var _ride_pose: SkeletonModifier3D
var _task_pose: SkeletonModifier3D
var resting := false
var held_kind := ""
var _worn := {}
var _unit_scale := 1.0
var _walk_cadence := 0.78
var _meal_props: Array[Node3D] = []

func eat(on: bool) -> void:
	if _task_pose==null: return
	_task_pose.eating=on
	for prop in _meal_props: prop.queue_free()
	_meal_props.clear()
	if not on: return
	var Models=load("res://scripts/work/repair_models.gd")
	for side in ["Left","Right"]:
		var bone := skeleton.find_bone(side+"Hand")
		if bone<0: continue
		var a := BoneAttachment3D.new(); a.bone_name=side+"Hand"; skeleton.add_child(a)
		var fix := Node3D.new()
		a.add_child(fix); _meal_props.append(a)
		if side=="Left":
			Models.ellipsoid(fix,Vector3(0,.025,.025),Vector3(.13,.06,.13),Models.mat("c9c3ad"))
			Models.ellipsoid(fix,Vector3(0,.052,.025),Vector3(.105,.02,.105),Models.mat("ddd1ad"))
		else:
			for x in [-.009,.009]: Models.rod(fix,Vector3(x,0,-.025),Vector3(x,0,.15),.003,Models.mat("8b724b"))
	_align_meal_props()

func _align_meal_props() -> void:
	for a in _meal_props:
		if not is_instance_valid(a) or a.is_queued_for_deletion(): continue
		var pose_basis := skeleton.global_basis*skeleton.get_bone_global_pose(skeleton.find_bone(a.bone_name)).basis
		var fix: Node3D=a.get_child(0)
		fix.basis=pose_basis.inverse()*global_basis
		fix.position=pose_basis.inverse()*(global_basis*Vector3(0,-.01,.08))

const PATH := "res://assets/characters/an/an-rigged.glb"


## Có mô hình An đã gắn xương trong dự án (bản xuất game chỉ có bản đã nhập, không có file .glb gốc).
static func available() -> bool:
	return ResourceLoader.exists(PATH) or FileAccess.file_exists(PATH)

## Street and job scenes share the same wardrobe interpretation.
func apply_outfit(game) -> void:
	var ap: Dictionary = game.s.get("appearance", DEFAULT_COLORS)
	var colors := DEFAULT_COLORS.duplicate()
	for key in colors: colors[key]=str(ap.get(key,colors[key]))
	for slot in [["ao","shirt"],["quan","pants"]]:
		var id := str(game.wardrobe().worn.get(slot[0],""))
		if id!="": colors[slot[1]]=str(game.cloth(id).get("color",colors[slot[1]]))
	set_colors(colors)
	set_hair_style(str(game.s.get("hair_style","natural")))


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
	if skeleton:
		var rig_transform := skeleton.transform
		var ancestor := skeleton.get_parent()
		while ancestor != model and ancestor is Node3D:
			rig_transform = ancestor.transform * rig_transform
			ancestor = ancestor.get_parent()
		_unit_scale = rig_transform.basis.get_scale().y
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
	if skeleton:
		_ride_pose = _RidePose.new()
		_ride_pose.unit_scale = _unit_scale
		skeleton.add_child(_ride_pose)
		_task_pose = _TaskPose.new()
		_task_pose.unit_scale = _unit_scale
		skeleton.add_child(_task_pose)
		_task_pose.modification_processed.connect(_align_meal_props)
		_mood_pose = _MoodPose.new()
		skeleton.add_child(_mood_pose)
	set_colors(DEFAULT_COLORS)

func _create_idle() -> void:
	if not skeleton:
		return
	var idle := Animation.new()
	idle.length = 8.0
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
			for key in 33:
				var time := float(key) * 0.25
				if kind == Animation.TYPE_POSITION_3D:
					idle.position_track_insert_key(track,time,rest.origin)
				elif kind == Animation.TYPE_SCALE_3D:
					idle.scale_track_insert_key(track,time,rest.basis.get_scale())
				else:
					var rotation := rest.basis.get_rotation_quaternion()
					var breath := sin(time * TAU / 4.0)
					var settle := sin(time * TAU / 8.0)
					if bone_name.to_lower() == "spine":
						# Shift through the upper body, leaving both feet planted.
						rotation *= Quaternion(Vector3.RIGHT, breath * 0.012)
						rotation *= Quaternion(Vector3.BACK, settle * 0.012)
					elif bone_name.to_lower() == "head":
						rotation *= Quaternion(Vector3.UP, sin(time * TAU / 8.0 + 0.5) * 0.035)
						rotation *= Quaternion(Vector3.BACK, -settle * 0.010)
					elif bone_name in ["LeftArm", "RightArm"]:
						# Lower the relaxed arms slightly from the source scan's A pose.
						var sign := -1.0 if bone_name == "LeftArm" else 1.0
						var parent_rest := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).basis.orthonormalized()
						var delta_rot := Basis(Quaternion(Vector3.BACK, sign * (0.10 + breath * 0.006)))
						rotation = (parent_rest.inverse() * delta_rot * parent_rest * rest.basis).orthonormalized().get_rotation_quaternion()
					elif bone_name in ["LeftForeArm", "RightForeArm"]:
						var parent_rest := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).basis.orthonormalized()
						var arm_phase := 0.6 if bone_name == "LeftForeArm" else -0.6
						var relaxed := Basis(Vector3.RIGHT, -0.055 + sin(time * TAU / 8.0 + arm_phase) * 0.015)
						rotation = (parent_rest.inverse() * relaxed * parent_rest * rest.basis).orthonormalized().get_rotation_quaternion()
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
			mat.set_shader_parameter("has_normal", original.normal_texture != null)
			var orm := original.ao_texture if original.ao_texture != null else original.roughness_texture
			mat.set_shader_parameter("orm_map", orm)
			mat.set_shader_parameter("has_orm", orm != null)
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
			mat.set_shader_parameter(part+"_color", Color(str(colors.get(part,DEFAULT_COLORS[part]))))

func set_hair_style(style: String) -> void:
	for entry in hair_meshes:
		entry.instance.mesh = entry.neat if style == "neat" else entry.natural

func animate_motion(speed: float, delta: float) -> void:
	if not animation or walk_clip.is_empty():
		return
	if sitting or resting:
		walking = false
		return
	# Hysteresis prevents a tiny joystick input from continually restarting clips.
	var moving := speed > (0.04 if walking else 0.08)
	if moving:
		var target := clampf(speed / 1.5, 0.15, 2.3)
		if not walking:
			animation.play(walk_clip, 0.2)
			_walk_cadence = minf(0.78, target)
		_walk_cadence = lerpf(_walk_cadence, target, 1.0 - exp(-11.0 * maxf(delta, 0.0)))
		animation.speed_scale = _walk_cadence
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


## Signed turn is normalized by world movement. Whole-bike banking stays outside
## this rig; only the torso and gaze respond here, with contacts solved afterwards.
func set_ride_motion(speed_mps: float, turn: float) -> void:
	if _ride_pose != null:
		_ride_pose.target_speed = clampf(speed_mps, 0.0, 20.0) if sitting else 0.0
		_ride_pose.target_turn = clampf(turn, -1.0, 1.0) if sitting and speed_mps > 0.1 else 0.0


## Riding uses the original skin with a two-bone solve for both hands and feet.
func sit(on: bool, seat_h: float) -> void:
	sitting = on
	if _ride_pose != null:
		_ride_pose.enabled = on
		_ride_pose.reset_motion()
	if model != null and skeleton != null:
		var hip := skeleton.find_bone("Hips")
		var hip_y := skeleton.get_bone_global_rest(hip).origin.y * _unit_scale
		model.position.y = seat_h + 0.09 - hip_y if on else 0.0
		_ride_pose.model_offset = model.position.y
	if animation != null:
		animation.speed_scale = 1.0
		animation.play(idle_clip, 0.18)
		walking = false

func hold(kind: String) -> void:
	held_kind=kind
	if _task_pose != null: _task_pose.carrying=kind!="" and kind!="ride"
	if _task_pose != null: _task_pose.kind=kind

func place() -> void:
	if _task_pose != null: _task_pose.place_left=0.65

## Workshop preview shares the street rig and wardrobe. Hands reach the work
## surface through the existing two-bone solver, without root translation.
func work(action: String) -> void:
	if _task_pose != null:
		_task_pose.repairing=not action.is_empty()
		_task_pose.work_action=action
	if animation != null and not action.is_empty():
		animation.play(idle_clip,0.2)
		walking=false

## A chair pose has feet on the floor, unlike the motorcycle pose.
func rest(on: bool, seat_h := 0.46) -> void:
	resting=on
	if not on: eat(false)
	if _task_pose==null: return
	_task_pose.resting=on
	if model!=null and skeleton!=null:
		var hip := skeleton.find_bone("Hips")
		model.position.y=seat_h+0.09-skeleton.get_bone_global_rest(hip).origin.y*_unit_scale if on else 0.0
		_task_pose.model_offset=model.position.y
	if animation!=null:
		animation.play(idle_clip,0.15)
		walking=false

class _TaskPose extends _RidePose:
	var eating := false
	var repairing := false
	var work_action := ""
	var kind := ""
	var carrying := false
	var resting := false
	var weight := 0.0
	var place_left := 0.0

	func advance_motion(delta: float) -> void:
		var dt := clampf(delta,0.0,0.1)
		place_left=maxf(0.0,place_left-dt)
		weight=move_toward(weight,1.0 if carrying or resting or repairing or place_left>0 else 0.0,dt*6.0)
		elapsed+=dt

	func _apply() -> void:
		if weight<0.001: return
		var sk := get_skeleton()
		if sk==null: return
		var before := {}
		for side in ["Left","Right"]:
			for part in ["Arm","ForeArm","Hand","UpLeg","Leg","Foot"]:
				var index := sk.find_bone(side+part)
				if index>=0: before[index]=sk.get_bone_global_pose(index)
		for side in ["Left","Right"]:
			var s := 1.0 if side=="Left" else -1.0
			var reach := sin((1.0-place_left/0.65)*PI) if place_left>0 else 0.0
			var hand := Vector3(s*0.20,1.06-reach*0.18,0.44+reach*0.14)
			if kind=="kettle" and place_left<=0:
				hand=Vector3(0.24,1.16,0.44) if side=="Left" else Vector3(-0.06,1.01,0.44)
			if resting: hand=Vector3(s*0.22,0.65,0.26)
			if resting and eating:
				hand=Vector3(.14,.76,.31) if side=="Left" else Vector3(-.12,.78,.34).lerp(Vector3(-.06,1.15,.16),pow(maxf(0.0,sin(elapsed*1.65)),2.0))
			if repairing:
				hand=Vector3(s*.20,.94,.57)
				if side=="Right":
					hand.y+=.04+sin(elapsed*5.0)*(.025 if work_action=="screw" else .009)
					hand.x+=sin(elapsed*2.0)*.025
			hand.y-=model_offset
			_solve(sk,side+"Arm",side+"ForeArm",side+"Hand",hand/unit_scale,Vector3(s*0.8,-0.7,-0.2),false)
			if resting:
				_solve(sk,side+"UpLeg",side+"Leg",side+"Foot",Vector3(s*0.16,0.08-model_offset,0.32)/unit_scale,Vector3(s*0.08,0.1,1.0),true)
		for index in before:
			sk.set_bone_global_pose(index,(before[index] as Transform3D).interpolate_with(sk.get_bone_global_pose(index),weight))

func wear(kind: String, on: bool, tint := Color("344e5c")) -> void:
	if not skeleton:
		return
	if on and not _worn.has(kind):
		var Character = load("res://scripts/world/character.gd")
		var index := skeleton.find_bone("Head")
		if index < 0:
			return
		var attachment := BoneAttachment3D.new()
		attachment.bone_name = "Head"
		skeleton.add_child(attachment)
		var fix := Node3D.new()
		var rest := skeleton.get_bone_global_rest(index)
		fix.basis = rest.basis.inverse()
		fix.scale *= 1.0 / _unit_scale
		attachment.add_child(fix)
		var mesh := MeshInstance3D.new()
		mesh.mesh = Character._acc(kind)
		# The generated avatar has more hair volume than the Rocketbox heads.
		# Fit the shell around that crown, without scaling its head or skin.
		mesh.position = Vector3(0, -1.50, 0)
		if kind == "helmet":
			mesh.scale = Vector3(1.13, 1.08, 1.12)
			mesh.position = Vector3(0, -1.50 - 1.605 * 0.08 + 0.024, 0)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.albedo_color = tint
		material.roughness = 0.48 if kind == "helmet" else 0.88
		material.metallic_specular = 0.28
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.material_override = material
		fix.add_child(mesh)
		_worn[kind] = {"node": attachment, "material": material}
	if _worn.has(kind):
		_worn[kind].node.visible = on
		_worn[kind].material.albedo_color = tint

## Đói hay buồn (juice.gd gọi khi Độ no hay Tâm trạng dưới 30): lưng khom, vai rũ, cúi đầu. 0..1, đổi mượt.
func set_mood_pose(amount: float) -> void:
	if _mood_pose != null:
		_mood_pose.target = clampf(amount, 0.0, 1.0)


## Dáng rũ vai chạy sau mọi tư thế khác: xoay thêm lưng, cổ, đầu về trước và hạ hai vai, theo trục của khung xương.
class _MoodPose extends SkeletonModifier3D:
	var target := 0.0
	var amount := 0.0

	func _process_modification_with_delta(delta: float) -> void:
		amount = move_toward(amount, target, clampf(delta, 0.0, 0.1) * 1.5)
		_apply()

	func _process_modification() -> void:
		_apply()

	func _apply() -> void:
		if amount < 0.001:
			return
		var sk := get_skeleton()
		if sk == null:
			return
		for spec in [["Spine01", 0.12], ["Spine02", 0.08], ["neck", 0.16], ["Head", 0.14]]:
			var i := sk.find_bone(spec[0])
			if i >= 0:
				var pose := sk.get_bone_global_pose(i)
				sk.set_bone_global_pose(i, Transform3D(Basis(Vector3.RIGHT, float(spec[1]) * amount) * pose.basis, pose.origin))
		for side in [["LeftShoulder", 1.0], ["RightShoulder", -1.0]]:
			var i := sk.find_bone(side[0])
			if i >= 0:
				var pose := sk.get_bone_global_pose(i)
				var drop := Basis(Vector3.BACK, -float(side[1]) * 0.16 * amount) * Basis(Vector3.RIGHT, 0.1 * amount)
				sk.set_bone_global_pose(i, Transform3D(drop * pose.basis, pose.origin))


class _RidePose extends SkeletonModifier3D:
	var enabled := false
	var model_offset := 0.0
	var unit_scale := 1.0
	var target_speed := 0.0
	var target_turn := 0.0
	var speed := 0.0
	var turn := 0.0
	var elapsed := 0.0

	func reset_motion() -> void:
		target_speed = 0.0
		target_turn = 0.0
		speed = 0.0
		turn = 0.0
		elapsed = 0.0

	func _process_modification_with_delta(delta: float) -> void:
		advance_motion(delta)
		_apply()

	func advance_motion(delta: float) -> void:
		if not enabled:
			return
		var dt := clampf(delta, 0.0, 0.1)
		speed = lerpf(speed, target_speed, 1.0 - exp(-6.0 * dt))
		turn = lerpf(turn, target_turn, 1.0 - exp(-8.0 * dt))
		elapsed += dt

	func _process_modification() -> void:
		_apply()

	func _apply() -> void:
		if not enabled:
			return
		var sk := get_skeleton()
		if not sk:
			return
		var hips := sk.find_bone("Hips")
		var breath := sin(elapsed * TAU / 4.0) * 0.004
		var lean := 0.52 + clampf(speed / 7.0, 0.0, 1.0) * 0.025 + breath
		if hips >= 0:
			var hip_rest := sk.get_bone_global_rest(hips)
			# The scan's shoulders are well behind the handlebar. A seated forward
			# lean makes the grips reachable without stretching the arms or skin.
			sk.set_bone_global_pose(hips, Transform3D(Basis(Vector3.RIGHT, lean) * hip_rest.basis, hip_rest.origin))
		# Counter-rotate neck/head to keep the rider looking ahead, not at his lap.
		for spec in [["neck", -lean * 0.77], ["Head", -lean * 0.23]]:
			var index := sk.find_bone(spec[0])
			if index >= 0:
				var pose := sk.get_bone_global_pose(index)
				sk.set_bone_global_pose(index, Transform3D(Basis(Vector3.RIGHT, spec[1]) * pose.basis, pose.origin))
		var head := sk.find_bone("Head")
		if head >= 0:
			var head_pose := sk.get_bone_global_pose(head)
			sk.set_bone_global_pose(head, Transform3D(Basis(Vector3.UP, turn * 0.085) * head_pose.basis, head_pose.origin))
		for side in ["Left", "Right"]:
			var s := 1.0 if side == "Left" else -1.0
			# Targets are in bike space minus avatar z=-.15 and model vertical offset.
			# The wrist sits behind/above the grip; the palm extends over it.
			var grip := Vector3(s * 0.30, 1.095 - model_offset, 0.475) / unit_scale
			var foot := Vector3(s * 0.18, 0.43 - model_offset, 0.39) / unit_scale
			_solve(sk, side + "Arm", side + "ForeArm", side + "Hand", grip, Vector3(s * 0.65, -0.8, -0.25), false)
			_solve(sk, side + "UpLeg", side + "Leg", side + "Foot", foot, Vector3(s * 0.12, 0.35, 1.0), true)

	func _solve(sk: Skeleton3D, upper: String, lower: String, end: String, target: Vector3, pole: Vector3, flat_foot: bool) -> void:
		var a := sk.find_bone(upper)
		var b := sk.find_bone(lower)
		var c := sk.find_bone(end)
		if mini(a, mini(b, c)) < 0:
			return
		var ra := sk.get_bone_global_rest(a)
		var rb := sk.get_bone_global_rest(b)
		var rc := sk.get_bone_global_rest(c)
		var origin := sk.get_bone_global_pose(a).origin
		var l1 := ra.origin.distance_to(rb.origin)
		var l2 := rb.origin.distance_to(rc.origin)
		var axis := (target - origin).normalized()
		var distance := clampf(origin.distance_to(target), absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
		var bend := (pole - axis * pole.dot(axis)).normalized()
		var along := (l1 * l1 - l2 * l2 + distance * distance) / (2.0 * distance)
		var joint := origin + axis * along + bend * sqrt(maxf(l1 * l1 - along * along, 0.0))
		var tip := origin + axis * distance
		var rot_a := Basis(Quaternion((rb.origin - ra.origin).normalized(), (joint - origin).normalized()))
		var rot_b := Basis(Quaternion((rc.origin - rb.origin).normalized(), (tip - joint).normalized()))
		sk.set_bone_global_pose(a, Transform3D(rot_a * ra.basis, origin))
		sk.set_bone_global_pose(b, Transform3D(rot_b * rb.basis, joint))
		# Hands have no individual finger bones in this asset. Orient the palms
		# across the grip instead of letting the scan's relaxed hands hang down.
		# Matching only the finger direction preserves the scan's 40-degree hand
		# roll, so one palm hangs beside the rubber grip. Establish both axes: the
		# finger ray points along the road and the palm lies across the bar.
		var palm_forward := Vector3(0, -0.15, 1).normalized()
		var palm := Basis(Vector3.LEFT, palm_forward, Vector3.LEFT.cross(palm_forward))
		sk.set_bone_global_pose(c, Transform3D(rc.basis if flat_foot else palm, tip))
