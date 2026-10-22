extends Node
## Âm thanh màn phố theo data/sounds.json: âm nền theo giờ và trời mưa, tiếng rao, còi xe,
## bước chân, tiếng tiền. Thiếu file nào thì im chỗ đó; tiếng rao vẫn hiện chữ nổi trên phố.

const FADE := 1.5

var world
var game
var cfg: Dictionary = {}
var _beds := {}
var _sfx := {}
var _calls: Array = []
var _horn_t := 0.0
var _step_t := 0.0


func _init(path := "res://data/sounds.json") -> void:
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			cfg = data


func _ready() -> void:
	for k in cfg.get("ambience", {}):
		var e: Dictionary = cfg.ambience[k]
		var p := _player(e, true)
		if p:
			p.volume_db = -60.0
			p.play()
			_beds[k] = {"player": p, "cfg": e, "on": false}
	for k in cfg.get("sfx", {}):
		var p := _player(cfg.sfx[k], false)
		if p:
			_sfx[k] = p
	for e in cfg.get("calls", []):
		_calls.append({"cfg": e, "wait": _rand(e.get("every", [30, 60])) * randf(), "stream": _load(str(e.get("path", "")), false)})
	_horn_t = _rand(cfg.get("horn", {}).get("every", [8, 16]))


func _process(delta: float) -> void:
	if game == null or not game.is_started():
		return
	var hour: float = game.clock()
	var raining: bool = game.s.today.get("rain", false)
	for k in _beds:
		var b: Dictionary = _beds[k]
		var want: bool = _in_hours(b.cfg, hour) and (not b.cfg.has("rain") or bool(b.cfg.rain) == raining)
		if want != b.on:
			b["on"] = want
			var tw := create_tween()
			tw.tween_property(b.player, "volume_db", float(b.cfg.get("volume_db", 0)) if want else -60.0, FADE)
	for c in _calls:
		c["wait"] = float(c.wait) - delta
		if float(c.wait) <= 0.0:
			c["wait"] = _rand(c.cfg.get("every", [30, 60]))
			if _in_hours(c.cfg, hour) and not raining:
				_call(c)
	_horn_t -= delta
	if _horn_t <= 0.0:
		var h: Dictionary = cfg.get("horn", {})
		_horn_t = _rand(h.get("every", [8, 16]))
		var spot = world.horn_spot() if _in_hours(h, hour) else null
		if spot != null:
			_play_at(_load(str(h.get("path", "")), false), spot, float(h.get("volume_db", 0)))


## Dừng âm nền khi rời màn phố, để máy âm thanh không giữ lại luồng phát đang lặp.
func _exit_tree() -> void:
	for k in _beds:
		_beds[k].player.stop()


## Gọi mỗi khung hình khi Minh đang đi, để phát tiếng bước chân đều nhịp.
func step(delta: float) -> void:
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = float(cfg.get("stepEvery", 0.36))
		play("step", randf_range(0.9, 1.1))


func play(key: String, pitch := 1.0) -> void:
	if _sfx.has(key):
		var p: AudioStreamPlayer = _sfx[key]
		p.pitch_scale = pitch
		p.play()


func _call(c: Dictionary) -> void:
	var e: Dictionary = c.cfg
	var pos := Vector3(float(e.get("x", world.player.position.x)), 0, float(e.get("z", world.player.position.z)))
	# Tiếng rao gắn với xe bán rong thì phát ra từ chính chiếc xe; xe chưa ra phố thì im.
	if e.has("vendor"):
		var vp = world.life.vendor_pos(str(e.vendor))
		if vp == null:
			return
		pos = vp
	if c.stream:
		_play_at(c.stream, pos, float(e.get("volume_db", 0)))
	if e.has("text") and pos.distance_to(world.player.position) < 40.0:
		var label: Label3D = world._label3d("♪ " + str(e.text), pos + Vector3(0, 2.6, 0), 30)
		label.modulate = Color("ffe7a8")
		world.add_child(label)
		var tw := label.create_tween()
		tw.tween_property(label, "position:y", label.position.y + 1.0, 3.5)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 3.5).set_delay(1.5)
		tw.tween_callback(label.queue_free)


func _play_at(stream: AudioStream, pos: Vector3, db: float) -> void:
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 12.0
	p.max_distance = 60.0
	p.position = pos
	world.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _player(e: Dictionary, loop: bool) -> AudioStreamPlayer:
	var s := _load(str(e.get("path", "")), loop)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = float(e.get("volume_db", 0))
	add_child(p)
	return p


static func _load(path: String, loop: bool) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if not (s is AudioStream):
		return null
	if loop:
		s = s.duplicate()
		if s is AudioStreamWAV:
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate)
		elif "loop" in s:
			s.loop = true
	return s


## "hours": [từ, đến) theo giờ trong ngày; đến lớn hơn 24 nghĩa là qua nửa đêm. Không có thì luôn đúng.
static func _in_hours(e: Dictionary, hour: float) -> bool:
	if not e.has("hours"):
		return true
	var a := float(e.hours[0])
	var b := float(e.hours[1])
	return (hour >= a and hour < b) or (hour + 24.0 >= a and hour + 24.0 < b)


static func _rand(r: Array) -> float:
	return randf_range(float(r[0]), float(r[1]))
