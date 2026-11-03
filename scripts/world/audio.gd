extends Node
## Âm thanh màn phố theo data/sounds.json: âm nền theo giờ và trời mưa, tiếng rao, còi xe,
## bước chân, tiếng tiền. Thiếu file nào thì im chỗ đó; tiếng rao vẫn hiện chữ nổi trên phố.
## Một tiếng có thể có nhiều bản ("paths"): mỗi lần phát chọn ngẫu nhiên một bản cho đỡ lặp.

const FADE := 1.5
## Tiếng rao: to bằng volume_db ở 6 m, mỗi lần xa gấp đôi nhỏ đi 6 dB, quá 45 m thì im.
const CALL_UNIT := 6.0
const CALL_RANGE := 45.0
const CALL_TEXT_RANGE := 30.0

var world
var game
var cfg: Dictionary = {}
var _beds := {}
var _sfx := {}
var _sfx_streams := {}
var _calls: Array = []
var _horns: Array = []
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
			_sfx_streams[k] = _load_all(cfg.sfx[k])
	for e in cfg.get("calls", []):
		# Mỗi bản rao một câu chữ riêng (texts cùng thứ tự với paths). Chưa có file thu (không có paths)
		# thì chỉ hiện chữ nổi trên đầu người bán.
		var variants := []
		var paths: Array = e.get("paths", [e.get("path", "")])
		var texts: Array = e.get("texts", [e.get("text", "")])
		for i in maxi(paths.size(), texts.size()):
			variants.append({"stream": _load(str(paths[i]), false) if i < paths.size() else null,
				"text": str(texts[i]) if i < texts.size() else str(texts[0])})
		_calls.append({"cfg": e, "wait": _rand(e.get("every", [30, 60])) * randf(), "variants": variants})
	_horns = _load_all(cfg.get("horn", {}))
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
		var spot = world.horn_spot() if _in_hours(h, hour) and not _horns.is_empty() else null
		if spot != null:
			_play_at(_horns.pick_random(), spot, float(h.get("volume_db", 0)))


## Dừng âm nền khi rời màn phố, để máy âm thanh không giữ lại luồng phát đang lặp.
func _exit_tree() -> void:
	for k in _beds:
		_beds[k].player.stop()


## Gọi mỗi khung hình khi Minh đang đi, để phát tiếng bước chân đều nhịp. Trời mưa thì bước lép nhép.
func step(delta: float) -> void:
	_step_t -= delta
	if _step_t <= 0.0:
		_step_t = float(cfg.get("stepEvery", 0.36))
		var wet: bool = game != null and game.is_started() and game.s.today.get("rain", false)
		play("step_wet" if wet and _sfx.has("step_wet") else "step", randf_range(0.92, 1.08))


func play(key: String, pitch := 1.0) -> void:
	if _sfx.has(key):
		var p: AudioStreamPlayer = _sfx[key]
		var streams: Array = _sfx_streams.get(key, [])
		if streams.size() > 1:
			p.stream = streams.pick_random()
		p.pitch_scale = pitch
		p.play()


func _call(c: Dictionary) -> void:
	var e: Dictionary = c.cfg
	var pos := Vector3(float(e.get("x", world.player.position.x)), 0, float(e.get("z", world.player.position.z)))
	var v: Dictionary = c.variants.pick_random()
	var db := float(e.get("volume_db", 0))
	# Tiếng rao gắn với người bán rong thì phát ra từ chính người đó và đi theo họ; chưa ra phố thì im.
	if e.has("vendor"):
		var node = world.life.vendor_node(str(e.vendor))
		if node == null:
			return
		pos = node.position
		if v.stream and pos.distance_to(world.player.position) < CALL_RANGE:
			var p := _spatial(v.stream, db)
			p.unit_size = CALL_UNIT
			p.max_distance = CALL_RANGE
			p.pitch_scale = randf_range(0.97, 1.03)
			p.position = Vector3(0, 1.6, 0)
			node.add_child(p)
			p.play()
	elif v.stream:
		_play_at(v.stream, pos, db)
	if str(v.text) != "" and pos.distance_to(world.player.position) < CALL_TEXT_RANGE:
		var label: Label3D = world._label3d("♪ " + str(v.text), pos + Vector3(0, 2.6, 0), 30)
		label.modulate = Color("ffe7a8")
		world.add_child(label)
		var tw := label.create_tween()
		tw.tween_property(label, "position:y", label.position.y + 1.0, 3.5)
		tw.parallel().tween_property(label, "modulate:a", 0.0, 3.5).set_delay(1.5)
		tw.tween_callback(label.queue_free)


func _play_at(stream: AudioStream, pos: Vector3, db: float) -> void:
	if stream == null:
		return
	var p := _spatial(stream, db)
	p.position = pos
	world.add_child(p)
	p.play()


## Loa 3D phát một lần rồi tự xóa. Xa thì nhỏ dần và mất tiếng cao (bộ lọc theo khoảng cách của Godot).
func _spatial(stream: AudioStream, db: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = db
	p.unit_size = 12.0
	p.max_distance = 60.0
	p.attenuation_filter_cutoff_hz = 3500.0
	p.finished.connect(p.queue_free)
	return p


func _player(e: Dictionary, loop: bool) -> AudioStreamPlayer:
	var s := _load(str(e.get("path", e.get("paths", [""])[0])), loop)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = float(e.get("volume_db", 0))
	add_child(p)
	return p


## Các bản của một tiếng: "paths" (mảng) hoặc "path"; bỏ qua file thiếu.
static func _load_all(e: Dictionary) -> Array:
	var out := []
	for path in e.get("paths", [e.get("path", "")]):
		var s := _load(str(path), false)
		if s:
			out.append(s)
	return out


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
