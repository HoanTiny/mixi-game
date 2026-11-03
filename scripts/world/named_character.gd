extends Node3D
## Original Higgsfield hero characters. Preserve PBR cloth/face textures and the
## actual skin; crowd characters continue using their inexpensive shared library.
const CATALOG := {"HANH": {"path": "res://assets/characters/hanh/hanh.glb", "height": 1.58}}
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var walk_clip := ""
var idle_clip := "hero/idle"
var _moving := false
var _cadence := 1.0

static func available(id: String) -> bool:
	return CATALOG.has(id) and ResourceLoader.exists(CATALOG[id].path)

static func make(id: String) -> Node3D:
	var actor = load("res://scripts/world/named_character.gd").new()
	actor._build(id)
	return actor

func _build(id: String) -> void:
	var spec: Dictionary = CATALOG[id]
	name = "Hero_" + id
	model = (load(spec.path) as PackedScene).instantiate()
	add_child(model)
	# Meshy supplies metre-sized skinned vertices under a centimetre skeleton.
	# Multiplying the mesh AABB by the skeleton transform would shrink the
	# measured box by 100x even though skinning cancels that scale at render time.
	# The rebound skin is calibrated to 1.58 m; preserve its authored root transform.
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animation = node
	assert(skeleton != null and animation != null, "Hero requires a verified animated skin")
	# Clip mutations belong to this instance, never Godot's shared imported library.
	for library_name in animation.get_animation_library_list():
		var library := animation.get_animation_library(library_name).duplicate(true)
		animation.remove_animation_library(library_name)
		animation.add_animation_library(library_name, library)
	for clip in animation.get_animation_list():
		if "walk" in clip.to_lower():
			walk_clip = clip
			var walk := animation.get_animation(clip)
			walk.loop_mode = Animation.LOOP_LINEAR
			for track in walk.get_track_count():
				if walk.track_get_type(track) == Animation.TYPE_POSITION_3D and "hips" in str(walk.track_get_path(track)).to_lower():
					var origin: Vector3 = walk.track_get_key_value(track, 0)
					for key in walk.track_get_key_count(track):
						var value: Vector3 = walk.track_get_key_value(track, key)
						value.x = origin.x
						value.z = origin.z
						walk.track_set_key_value(track, key, value)
				elif walk.track_get_type(track) == Animation.TYPE_ROTATION_3D:
					var bone_name := str(walk.track_get_path(track)).get_slice(":", 1)
					if bone_name in ["LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]:
						var neutral := skeleton.get_bone_rest(skeleton.find_bone(bone_name)).basis.orthonormalized().get_rotation_quaternion()
						for key in walk.track_get_key_count(track):
							var value: Quaternion = walk.track_get_key_value(track, key)
							walk.track_set_key_value(track, key, neutral.slerp(value, 0.58))
	assert(not walk_clip.is_empty(), "Hero requires an in-place walk")
	_create_idle()
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play(idle_clip)
	animation.advance(0.0)
	set_meta("asset_identity", id)
	set_meta("height_m", spec.height)
	set_meta("source", "Higgsfield Tripo H3.1; locally rebound to verified An rig")

## The locally rebound rig has a verified neutral rest pose. Lower the fitted
## A-pose arms for idle; breathing never translates the hips or feet.
func _create_idle() -> void:
	var idle := Animation.new()
	idle.length = 6.0
	idle.loop_mode = Animation.LOOP_LINEAR
	var animation_root := animation.get_node(animation.root_node)
	var skeleton_path := str(animation_root.get_path_to(skeleton))
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		var rest := skeleton.get_bone_rest(bone)
		for kind in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
			var track := idle.add_track(kind)
			idle.track_set_path(track, NodePath(skeleton_path + ":" + bone_name))
			for key in 25:
				var time := key * 0.25
				var breath := sin(time * TAU / 3.0)
				if kind == Animation.TYPE_POSITION_3D:
					idle.position_track_insert_key(track, time, rest.origin)
				elif kind == Animation.TYPE_SCALE_3D:
					idle.scale_track_insert_key(track, time, rest.basis.get_scale())
				else:
					var pose := rest.basis.orthonormalized().get_rotation_quaternion()
					if bone_name in ["LeftArm", "RightArm"]:
						var side := -1.0 if bone_name == "LeftArm" else 1.0
						var parent := skeleton.get_bone_global_rest(skeleton.get_bone_parent(bone)).basis.orthonormalized()
						pose = (parent.inverse() * Basis(Vector3.BACK, side * (0.36 + breath * 0.004)) * parent * rest.basis).orthonormalized().get_rotation_quaternion()
					elif bone_name == "Spine":
						pose *= Quaternion(Vector3.RIGHT, breath * 0.009)
					elif bone_name == "Head":
						pose *= Quaternion(Vector3.UP, sin(time * TAU / 6.0) * 0.025)
					idle.rotation_track_insert_key(track, time, pose)
	var library := AnimationLibrary.new()
	library.add_animation("idle", idle)
	animation.add_animation_library("hero", library)

func animate(delta: float, speed_ratio: float) -> void:
	if not animation:
		return
	var moving := speed_ratio > (0.025 if _moving else 0.055)
	if moving != _moving:
		animation.play(walk_clip if moving else idle_clip, 0.22)
		_moving = moving
	_cadence = lerpf(_cadence, clampf(speed_ratio, 0.25, 1.7) if moving else 1.0, 1.0 - exp(-10.0 * delta))
	animation.speed_scale = _cadence
	animation.advance(maxf(delta, 0.0))
