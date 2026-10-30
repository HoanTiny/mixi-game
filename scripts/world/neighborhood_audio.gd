extends Node3D
## Local foley sources, gently audible nearby and silent when the venue closes.
const Audio := preload("res://scripts/world/audio.gd")
const ROOT := "res://assets/sounds/neighborhood/"
var world
var sources: Array = []
var pass_wait := 9.0

func setup(w) -> void:
	world=w
	for spec in [["tiem_sau","fan",-25.0,0.0],["tiem_sau","screw",-17.0,7.0],["com_hanh","dishes",-17.0,4.5],["xom_bo_me","sweep",-24.0,3.0]]:
		var p := AudioStreamPlayer3D.new()
		p.stream=Audio._load(ROOT+str(spec[1])+".wav",spec[1]=="fan")
		p.unit_size=3.0; p.max_distance=15.0; p.volume_db=-60
		add_child(p); p.global_position=world.loc_point(spec[0],.6,-1.2)+Vector3.UP
		sources.append({"player":p,"loc":spec[0],"kind":spec[1],"db":float(spec[2]),"every":float(spec[3]),"wait":float(spec[3])})
		if spec[1]=="fan": p.play()

func _process(delta: float) -> void:
	if world==null or not world.game.is_started(): return
	var hour: float=world.game.clock()
	for s in sources:
		var on := false
		match str(s.loc):
			"tiem_sau": on=hour>=8 and hour<18
			"com_hanh": on=(hour>=10.5 and hour<14.5) or (hour>=17.5 and hour<21)
			"xom_bo_me": on=(hour>=7 and hour<10) or (hour>=16 and hour<18)
		var p: AudioStreamPlayer3D=s.player
		on=on and world.player.position.distance_to(p.global_position)<15
		p.volume_db=move_toward(p.volume_db,float(s.db) if on else -60,delta*30)
		if s.every>0:
			s.wait-=delta
			if s.wait<=0:
				s.wait=float(s.every)*randf_range(.8,1.4)
				if on: p.pitch_scale=randf_range(.94,1.06); p.play()
	pass_wait-=delta
	if pass_wait<=0:
		pass_wait=randf_range(12,22)
		var spot=world.horn_spot() if hour>=6 and hour<21 else null
		if spot!=null: world.audio._play_at(Audio._load(ROOT+"scooter_pass.wav",false),spot,-23)
