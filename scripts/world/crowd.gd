extends Node3D
## Đám đông trên phố thật (map thật), dựng bằng MultiMesh cho nhẹ (người thật nướng sẵn, chia ô CELL mét); càng gần chỗ của truyện càng
## đông (như dòng xe, traffic.gd):
## - khách ngồi ghế đẩu quán cóc (chỗ ngồi do street_dress.gd ghi lại), quay mặt vào bàn;
## - chủ tiệm, người bán đứng trước cửa tiệm có biển hiệu, có tiệm thêm khách đứng mua; nhóm hai ba người đứng nói
##   chuyện trên vỉa hè;
## - chỗ đông người của truyện (chợ, bến xe, quán cơm): người đứng quanh cổng, phần nhiều quay mặt vào trong; sạp chợ
##   có người bán đứng sau, người mua đứng trước;
## - người đi bộ qua lại một khúc vỉa hè đường lớn, một khúc hẻm (tay chân vung theo bước, tới đầu khúc thì quay lại);
## - trẻ con đá banh trong hẻm: chạy qua lại, trái banh nảy từ đứa này sang đứa kia.
## Không ai đứng giữa lòng đường lớn (xe chạy) hay trên cầu, không ai đứng chồng lên ai; người đi bộ tránh người đứng
## ngồi, bàn ghế, gốc cây, cột điện, cột đèn. Buổi tối vắng dần (trẻ con về nhà trước), ngày mưa còn ít người; mỗi khung
## hình chỉ cập nhật người đi bộ gần An và trẻ con.

const Props3D := preload("res://scripts/world/props3d.gd")
const Geo := preload("res://scripts/realmap/geo.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")
const Traffic := preload("res://scripts/world/traffic.gd")
const Human := preload("res://scripts/world/human.gd")
const Character := preload("res://scripts/world/character.gd")

## Người thật (Rocketbox, tools/bake_people.gd nướng sẵn từng tư thế thành lưới nhẹ ở assets/rb/crowd): người đứng, ngồi,
## đi xa An là lưới tĩnh vẽ hàng loạt; người đi bộ và trẻ con trong vòng NEAR mét quanh An thì thay bằng người có xương,
## có động tác (lấy từ nhóm dựng sẵn POOL_PER người mỗi kiểu, khỏi dựng lúc đang chơi).
## Kiểu người: id trong Character.CROWD (thân và đầu người Việt ghép sẵn), trẻ con Character.CROWD_CHILD.
const AVATARS := ["m1", "m2", "m3", "m4", "m5", "f1", "f2", "f3", "f4"]
const CHILD := "c1"
const NEAR := 24.0
const POOL_PER := 2
## Đám đông chia ô vuông chừng này mét (ô ngoài khung nhìn khỏi vẽ); mỗi ô vài kiểu người.
const CELL := 90.0
const LOOKS_PER_CELL := 4
## Phần người đứng trước tiệm, nhóm nói chuyện đang đưa tay nói.
const TALK_SHARE := 0.35

## Phần chỗ ngồi quán cóc có khách, phần tiệm có người đứng trước cửa (gần chỗ của truyện; xa thì nhân thêm độ đông
## _near), phần tiệm đó có thêm khách đứng mua.
const SEAT_SHARE := 0.8
const SHOP_SHARE := 0.65
const BUYER_SHARE := 0.4
## Người đi bộ mỗi mét vỉa hè (mỗi bên đường lớn), mỗi mét hẻm (gần chỗ của truyện); tối đa cả khu.
const WALK_PER_M := 0.08
const LANE_PER_M := 0.035
const MAX_WALKERS := 340
## Nhóm đứng nói chuyện, nhóm trẻ con đá banh.
const CHAT_GROUPS := 26
const KID_GROUPS := 4
## Khúc đi của người đi bộ lấy điểm cách nhau STEP mét; xa An quá UPDATE_RANGE mét thì vẫn đi nhưng khỏi cập nhật hình.
const STEP := 1.5
const UPDATE_RANGE := 200.0
## Người đi bộ đi lệch về bên phải chiều mình đi chừng này mét (quay đầu thì dịch dần sang trong KEEP_RIGHT_TIME giây).
const KEEP_RIGHT := 0.25
const KEEP_RIGHT_TIME := 1.2
## Ô lưới tra đoạn đường lớn (mét).
const ROAD_CELL := 16.0
## Khoảng ngang người đi bộ chừa ra khi né An, và lệch xa nhất khỏi làn.
const DODGE_GAP := 0.95
const DODGE_MAX := 1.3
const SHIRTS := ["e94b3c", "3a7bd5", "f2c230", "f4f1ea", "2e9e5b", "e67e22", "8e44ad", "1abc9c", "d35480", "34495e", "c0392b", "95a5a6"]
## Sắc quần (props3d.gd: phần sơn thứ hai): xanh đen, xanh jean nhiều nhất, nâu kaki, đỏ đô.
const PANTS_HUES := [0.6, 0.62, 0.58, 0.6, 0.64, 0.08, 0.1, 0.97]

var counts := {"seated": 0, "shop": 0, "buyers": 0, "chat": 0, "hot": 0, "walkers": 0, "kids": 0}
var _rng := RandomNumberGenerator.new()
## MultiMesh người đứng ngồi yên theo nhóm giờ giấc: khách quán, trước tiệm (chủ, khách mua, nhóm nói chuyện), chỗ đông.
var _static := {"seated": [], "shop": [], "hot": []}
## Ô 1 m → các chỗ đã có người, bàn ghế, gốc cây, cột đèn (khỏi đặt chồng, người đi bộ khỏi đi xuyên).
var _taken := {}
## Ô ROAD_CELL mét → các đoạn đường lớn, cầu [a, b, cách tim dưới chừng này thì tránh] (xem _index_roads).
var _roads := {}
## Người đi bộ: khúc đi (các điểm cách nhau STEP mét), quãng đã đi trên khúc, chiều, lệch bên phải, tốc độ.
var _w_pts: Array[PackedVector2Array] = []
var _w_s := PackedFloat32Array()
var _w_dir := PackedFloat32Array()
var _w_lat := PackedFloat32Array()
var _w_speed := PackedFloat32Array()
## Người đi bộ đang né An: chỉ số -> độ lệch ngang thêm (m) và còn bao lâu đi chậm lại.
var _dodge := {}
var _hold := {}
## Trẻ con: MultiMesh trẻ con, MultiMesh trái banh, mỗi nhóm {c, d (hướng hẻm), kids: [pha], from, to, t}.
var _kid_mm: MultiMesh
var _ball_mm: MultiMesh
var _groups: Array = []
var _time := 0.0
var _show := {"seated": 1.0, "shop": 1.0, "hot": 1.0, "walk": 1.0, "kids": 1.0}
## Người đi bộ i nằm ở MultiMesh _walk_mms[_w_mm[i]], chỗ _w_slot[i] (chia theo ô của khúc đi, kiểu người theo ô);
## _w_look[i]: kiểu người.
var _walk_mms: Array[MultiMesh] = []
var _w_mm := PackedInt32Array()
var _w_slot := PackedInt32Array()
var _w_look: PackedStringArray = []
## Người có xương đang rảnh theo kiểu người; đang thay cho ai (khóa: số người đi bộ, trẻ con thì -1 - số thứ tự).
var _pool := {}
var _live := {}
var _kid_prev: Array[Vector2] = []


## dress: street_dress.gd của khu (chỗ ngồi, tiệm); roads: đường của khu; center: chỗ của truyện; walkable(p): đi được;
## hot: chỗ đông người [chỗ, số người, bán kính]; stalls: sạp chợ [giữa sạp, hướng ra phía người mua]; blocked: gốc cây,
## cột đèn; amount: nhân số người đi bộ, nhóm nói chuyện, người ở chỗ đông (điện thoại bớt).
func build(dress, roads: Array, center: Vector2, walkable: Callable, hot: Array = [], stalls: Array = [], blocked: Array = [],
		amount := 1.0) -> void:
	_rng.seed = 4711
	_index_roads(roads, center)
	for p in blocked:
		_take(p)
	var ok := func(p: Vector2, r: float) -> bool: return walkable.call(p) and _free(p, r) and not _on_road(p)
	# Sạp chợ: người bán đứng sau sạp nhìn ra (sát mặt tiền, khỏi xét đi được), hai ba người mua đứng trước sạp (trước
	# sạp là chỗ đi bộ dù có đường vẽ chồng ở đó, khỏi xét lòng đường).
	var crowded: Array = []
	for st in stalls:
		var c: Vector2 = st[0]
		var out: Vector2 = st[1]
		var along := out.orthogonal()
		for k in [-1.0, 0.0, 1.0]:
			_take(c + along * k)
		var seller := c - out * 0.95
		if _free(seller, 0.4):
			_take(seller)
			crowded.append([seller, out.rotated(_rng.randf_range(-0.3, 0.3)), 0.0])
			counts.hot += 1
		for k in _rng.randi_range(2, 3):
			var q := c + out * _rng.randf_range(1.0, 1.35) + along * _rng.randf_range(-1.1, 1.1)
			if walkable.call(q) and _free(q, 0.55):
				_take(q)
				crowded.append([q, (-out).rotated(_rng.randf_range(-0.35, 0.35)), 0.0])
				counts.hot += 1
	var seated: Array = []
	for it in dress.seats:
		var p: Vector2 = it[0]
		var f: Vector2 = it[1]
		_take(p)
		_take(p + f * 0.55)
		if _rng.randf() < SEAT_SHARE * _near(p, center):
			seated.append([p, f, float(it[2])])
	var shop: Array = []
	for it in dress.shops:
		var p: Vector2 = it[0]
		var n: Vector2 = it[1]
		if _rng.randf() >= SHOP_SHARE * _near(p, center) or not ok.call(p, 0.7):
			continue
		_take(p)
		shop.append([p, n.rotated(_rng.randf_range(-0.6, 0.6)), 0.0])
		counts.shop += 1
		if _rng.randf() < BUYER_SHARE:
			for k in _rng.randi_range(1, 2):
				var q := p + n * _rng.randf_range(0.9, 1.3) + n.orthogonal() * _rng.randf_range(-0.7, 0.7)
				if ok.call(q, 0.6):
					_take(q)
					shop.append([q, (p - q).normalized().rotated(_rng.randf_range(-0.4, 0.4)), 0.0])
					counts.buyers += 1
	shop.append_array(_chat_groups(roads, center, ok, roundi(CHAT_GROUPS * amount)))
	for h in hot:
		var c: Vector2 = h[0]
		var want := roundi(float(h[1]) * amount)
		var got := 0
		var tries := 0
		while got < want and tries < want * 12:
			tries += 1
			var q := c + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.0, float(h[2]))
			if not ok.call(q, 0.6):
				continue
			_take(q)
			crowded.append([q, (c - q).normalized().rotated(_rng.randf_range(-1.3, 1.3)), 0.0])
			got += 1
		counts.hot += got
	_people(seated, "sit", "seated")
	_people(shop, "stand", "shop")
	_people(crowded, "stand", "hot")
	counts.seated = seated.size()
	_build_walkers(roads, center, ok, amount)
	_build_kids(roads, center, ok)


## Nhóm hai ba người đứng nói chuyện trên vỉa hè đường lớn trong vòng 200 m quanh chỗ của truyện, quay mặt vào nhau.
func _chat_groups(roads: Array, center: Vector2, ok: Callable, want: int) -> Array:
	var big := roads.filter(func(r) -> bool:
		return _big(r) and Array(r.line).any(func(p: Vector2) -> bool: return p.distance_to(center) < 200.0))
	var out: Array = []
	var tries := 0
	while counts.chat < want and tries < want * 20 and not big.is_empty():
		tries += 1
		var r = big[_rng.randi() % big.size()]
		var line := _offset(r.line, (float(r.width) / 2.0 + maxf(AreaData.sidewalk(r) * 0.55, 0.9)) * (-1.0 if _rng.randf() < 0.5 else 1.0))
		var c := _at(line, _rng.randf() * _length(line))
		if c.distance_to(center) > 200.0:
			continue
		var n := _rng.randi_range(2, 3)
		var a0 := _rng.randf() * TAU
		var spots: Array[Vector2] = []
		for k in n:
			var q := c + Vector2.from_angle(a0 + TAU * float(k) / float(n)) * _rng.randf_range(0.42, 0.55)
			if not ok.call(q, 0.5):
				break
			spots.append(q)
		if spots.size() < n:
			continue
		for q in spots:
			_take(q)
			out.append([q, (c - q).normalized().rotated(_rng.randf_range(-0.25, 0.25)), 0.0])
		counts.chat += 1
	return out


## Người đứng, ngồi yên: mỗi ô CELL mét, mỗi kiểu người, mỗi tư thế một MultiMesh lưới nướng sẵn (ô ngoài khung nhìn
## thì khỏi vẽ; mỗi ô chỉ dùng vài kiểu người, _look_of, cho đỡ lần vẽ). Ngồi: ghế cao hay ghế đẩu thấp theo độ cao ghế;
## đứng trước tiệm: có người đang nói. Thứ tự xáo trộn để buổi tối vắng bớt thì vắng đều các chỗ.
func _people(items: Array, pose: String, key: String) -> void:
	var split := {}
	for it in items:
		var p := pose
		if pose == "sit":
			p = "sit" if float(it[2]) > 0.35 else "low"
		elif key == "shop" and _rng.randf() < TALK_SHARE:
			p = "talk"
		var cell := _cell(it[0])
		var k := "%s|%s|%s" % [_look_of(cell), p, cell]
		if not split.has(k):
			split[k] = []
		split[k].append(it)
	for k in split:
		var mine: Array = split[k]
		for i in range(mine.size() - 1, 0, -1):
			var j := _rng.randi() % (i + 1)
			var t = mine[i]
			mine[i] = mine[j]
			mine[j] = t
		var parts := str(k).split("|")
		var mesh := _real(parts[0], parts[1])
		var mm := _mm(mesh if mesh != null else Props3D.person("sit" if pose == "sit" else "stand"), mine.size())
		for i in mine.size():
			var p: Vector2 = mine[i][0]
			var f: Vector2 = mine[i][1]
			var y := 0.0 if mesh != null or pose != "sit" else float(mine[i][2]) - 0.3
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(f.x, f.y)), Vector3(p.x, y, p.y)))
		_static[key].append(_mmi(mm, null if mesh != null else Props3D.instanced_material()))


static func _cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.y / CELL))


## Kiểu người ngẫu nhiên trong ô: mỗi ô LOOKS_PER_CELL kiểu (nam nữ xen kẽ), ô bên cạnh kiểu khác.
func _look_of(cell: Vector2i) -> String:
	var start := absi(hash(cell)) % AVATARS.size()
	var step := AVATARS.size() / LOOKS_PER_CELL
	return AVATARS[(start + step * (_rng.randi() % LOOKS_PER_CELL)) % AVATARS.size()]


## Lưới người thật nướng sẵn (null nếu chưa nướng).
static func _real(avatar: String, pose: String) -> Mesh:
	var path := "res://assets/rb/crowd/%s_%s.res" % [avatar, pose]
	return load(path) if ResourceLoader.exists(path) else null


func _mm(mesh: Mesh, n: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	# Người thật (ảnh atlas) khỏi cần màu riêng từng người.
	if mesh.resource_path.begins_with("res://assets/rb/"):
		mm.instance_count = n
		return mm
	# Màu áo ở custom data, sắc quần ở kênh a; màu instance trắng (bản Compatibility nhân màu đỉnh với màu instance).
	mm.use_custom_data = true
	mm.use_colors = true
	mm.instance_count = n
	for i in n:
		var c := Color(str(SHIRTS[_rng.randi() % SHIRTS.size()]))
		c.a = float(PANTS_HUES[_rng.randi() % PANTS_HUES.size()])
		mm.set_instance_custom_data(i, c)
		mm.set_instance_color(i, Color.WHITE)
	return mm


func _mmi(mm: MultiMesh, mat: Material) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if mat != null:
		mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Người đi bộ rải theo mét vỉa hè đường lớn (giữa vỉa hè, mỗi bên) và mét hẻm (giữa hẻm, lệch chút), gần chỗ của
## truyện thì đông (traffic._near_k). Mỗi người một khúc 20–60 m: đi từ chỗ xuất phát tới khi đủ khúc; gặp chỗ không đi
## được, có người đứng ngồi, bàn ghế, gốc cây, cột điện hay lòng đường lớn thì khúc dừng ở đó (dưới 10 m thì bỏ). Ai cũng
## đi lệch về bên phải chiều mình đi (KEEP_RIGHT), hai người ngược chiều tránh nhau.
func _build_walkers(roads: Array, center: Vector2, ok: Callable, amount: float) -> void:
	# Mỗi lối: [đường, lệch khỏi tim, lệch thêm tối đa (hai phía), người mỗi mét].
	var ways: Array = []
	var total := 0.0
	for r in roads:
		if r.bridge or r.tunnel or r.line.size() < 2 or str(r.kind) == "steps" \
				or not Array(r.line).any(func(p: Vector2) -> bool: return p.distance_to(center) < 300.0):
			continue
		var k := Traffic._near_k(r.line, center)
		var mine: Array = []
		if _big(r):
			for side in [-1.0, 1.0]:
				mine.append([r.line, side * (float(r.width) / 2.0 + maxf(AreaData.sidewalk(r) * 0.45, 0.7)), 0.05, k * WALK_PER_M])
		else:
			mine.append([r.line, 0.0, minf(float(r.width) / 4.0, 0.5), k * LANE_PER_M])
		for wy in mine:
			total += _length(wy[0]) * float(wy[3])
		ways.append_array(mine)
	var scale := amount * minf(1.0, float(MAX_WALKERS) / maxf(total, 1.0))
	# Chỗ đi qua phải trống cả hai làn tránh nhau.
	var clear := func(q: Vector2, nrm: Vector2) -> bool:
		return ok.call(q, 0.3) and ok.call(q + nrm * KEEP_RIGHT, 0.35) and ok.call(q - nrm * KEEP_RIGHT, 0.35)
	for wy in ways:
		var base: PackedVector2Array = wy[0]
		var n := floori(_length(base) * float(wy[3]) * scale + _rng.randf())
		# Chỗ xuất phát hỏng (ngã tư, gốc cây...) thì thử chỗ khác, tới năm lần số người cần.
		var placed := 0
		var tries := 0
		while placed < n and tries < n * 5:
			tries += 1
			var line := _offset(base, float(wy[1]) + _rng.randf_range(-float(wy[2]), float(wy[2])))
			var span := _length(line)
			var want := _rng.randf_range(20.0, 60.0)
			var dir := 1.0 if _rng.randf() < 0.5 else -1.0
			var s := _rng.randf_range(0.0, span)
			var pts := PackedVector2Array()
			while float(pts.size() - 1) * STEP < want and s >= 0.0 and s <= span:
				var q := _at(line, s)
				var nrm := (_at(line, s + 0.5) - _at(line, s - 0.5)).normalized().orthogonal()
				if q.distance_to(center) > 320.0 or not clear.call(q, nrm):
					break
				pts.append(q)
				s += STEP * dir
			if pts.size() < 8:
				continue
			placed += 1
			_w_pts.append(pts)
			_w_s.append(_rng.randf_range(0.0, float(pts.size() - 1) * STEP))
			_w_dir.append(1.0 if _rng.randf() < 0.5 else -1.0)
			_w_lat.append(KEEP_RIGHT * _w_dir[_w_dir.size() - 1])
			_w_speed.append(_rng.randf_range(1.0, 1.5))
	if _w_pts.is_empty():
		return
	# Xáo thứ tự: buổi tối vắng bớt (ẩn những người cuối danh sách) thì vắng đều các phố.
	for i in range(_w_pts.size() - 1, 0, -1):
		var j := _rng.randi() % (i + 1)
		var pts := _w_pts[i]
		_w_pts[i] = _w_pts[j]
		_w_pts[j] = pts
		var t := Vector4(_w_s[i], _w_dir[i], _w_lat[i], _w_speed[i])
		_w_s[i] = _w_s[j]
		_w_dir[i] = _w_dir[j]
		_w_lat[i] = _w_lat[j]
		_w_speed[i] = _w_speed[j]
		_w_s[j] = t.x
		_w_dir[j] = t.y
		_w_lat[j] = t.z
		_w_speed[j] = t.w
	# Chia người đi bộ theo ô của giữa khúc đi và kiểu người: mỗi nhóm một MultiMesh.
	var groups := {}
	for i in _w_pts.size():
		var pts := _w_pts[i]
		var cell := _cell(pts[pts.size() / 2])
		var look := _look_of(cell)
		var k := "%s|%s" % [look, cell]
		if not groups.has(k):
			groups[k] = [look, PackedInt32Array()]
		groups[k][1].append(i)
	_w_mm.resize(_w_pts.size())
	_w_slot.resize(_w_pts.size())
	_w_look.resize(_w_pts.size())
	for k in groups:
		var look: String = groups[k][0]
		var list: PackedInt32Array = groups[k][1]
		var mesh := _real(look, "walk")
		var mm := _mm(mesh if mesh != null else Props3D.person("walk"), list.size())
		_mmi(mm, null if mesh != null else Props3D.walking_material(7.0))
		for j in list.size():
			_w_mm[list[j]] = _walk_mms.size()
			_w_slot[list[j]] = j
			_w_look[list[j]] = look
		_walk_mms.append(mm)
	for a in AVATARS:
		for k in POOL_PER:
			_spare(a)
	counts.walkers = _w_pts.size()
	_update_walkers(0.0, Vector2.ZERO, true)


## Trẻ con đá banh: KID_GROUPS nhóm ba đứa ở các hẻm trong vòng 200 m quanh chỗ của truyện (cách nhau từ 40 m).
func _build_kids(roads: Array, center: Vector2, ok: Callable) -> void:
	var lanes := roads.filter(func(r) -> bool:
		return (r.small or float(r.width) < 6.0) and not r.bridge and str(r.kind) not in ["steps", "footway", "path"] and r.line.size() >= 2 \
			and Array(r.line).any(func(p: Vector2) -> bool: return p.distance_to(center) < 200.0))
	var spots: Array[Vector2] = []
	var tries := 0
	while _groups.size() < KID_GROUPS and tries < 200 and not lanes.is_empty():
		tries += 1
		var r = lanes[_rng.randi() % lanes.size()]
		var i: int = _rng.randi() % (r.line.size() - 1)
		var a: Vector2 = r.line[i]
		var b: Vector2 = r.line[i + 1]
		if a.distance_to(b) < 8.0:
			continue
		var c := a.lerp(b, _rng.randf_range(0.3, 0.7))
		var d := (b - a).normalized()
		if c.distance_to(center) > 200.0 or spots.any(func(q: Vector2) -> bool: return q.distance_to(c) < 40.0):
			continue
		if not (ok.call(c, 1.0) and ok.call(c + d * 3.0, 1.0) and ok.call(c - d * 3.0, 1.0)):
			continue
		spots.append(c)
		_groups.append({"c": c, "d": d, "kids": [0.0, 2.1, 4.2], "from": 0, "to": 1, "t": 0.0})
	if _groups.is_empty():
		return
	var kid := _real(CHILD, "walk")
	_kid_mm = _mm(kid if kid != null else Props3D.person("walk"), _groups.size() * 3)
	_mmi(_kid_mm, null if kid != null else Props3D.walking_material(11.0))
	_kid_prev.resize(_groups.size() * 3)
	for k in POOL_PER:
		_spare(CHILD)
	var ball := SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.22
	ball.radial_segments = 8
	ball.rings = 4
	_ball_mm = MultiMesh.new()
	_ball_mm.transform_format = MultiMesh.TRANSFORM_3D
	_ball_mm.mesh = ball
	_ball_mm.instance_count = _groups.size()
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color("f2efe6")
	bmat.roughness = 0.6
	_mmi(_ball_mm, bmat)
	counts.kids = _groups.size() * 3
	_update_kids(0.0)


## Giờ trong ngày, trời mưa: buổi tối vắng dần (chợ vãn sớm), trẻ con về nhà lúc chạng vạng; mưa thì gần như vắng.
func set_time(hour: float, rain: bool) -> void:
	var dusk := clampf((hour - 19.0) / 2.0, 0.0, 1.0)
	_show["seated"] = (0.25 if rain else 1.0) * (1.0 - dusk * 0.4)
	_show["shop"] = (0.4 if rain else 1.0) * (1.0 - dusk * 0.6)
	_show["hot"] = (0.3 if rain else 1.0) * (1.0 - dusk * 0.85)
	_show["walk"] = (0.2 if rain else 1.0) * (1.0 - dusk * 0.7)
	_show["kids"] = 0.0 if rain or hour >= 18.5 or hour < 7.0 else 1.0
	for key in _static:
		for mi in _static[key]:
			var mm: MultiMesh = mi.multimesh
			mm.visible_instance_count = int(round(mm.instance_count * float(_show[key])))
	for mm in _walk_mms:
		mm.visible_instance_count = int(round(mm.instance_count * float(_show.walk)))
	if _kid_mm != null:
		_kid_mm.visible_instance_count = _kid_mm.instance_count if float(_show.kids) > 0.5 else 0
		_ball_mm.visible_instance_count = _ball_mm.instance_count if float(_show.kids) > 0.5 else 0


## Mỗi khung hình: người đi bộ bước tiếp, trẻ con chạy, banh nảy. focus: chỗ An (xa quá thì khỏi cập nhật hình).
func update(delta: float, focus: Vector2) -> void:
	_time += delta
	var seen := {}
	if not _walk_mms.is_empty():
		_update_walkers(delta, focus, false, seen)
	if _kid_mm != null and _kid_mm.visible_instance_count != 0:
		_update_kids(delta, focus, seen)
	for key in _live.keys():
		if not seen.has(key):
			_release(key)


## all: cập nhật hình cả những người xa focus và những người đang ẩn (lúc mới dựng). seen: ghi những ai đang được thay
## bằng người có xương.
func _update_walkers(delta: float, focus: Vector2, all := false, seen := {}) -> void:
	var r2 := UPDATE_RANGE * UPDATE_RANGE
	for i in _w_pts.size():
		var mm := _walk_mms[_w_mm[i]]
		var slot := _w_slot[i]
		var shown := all or mm.visible_instance_count < 0 or slot < mm.visible_instance_count
		if not shown:
			continue
		var pts := _w_pts[i]
		var span := float(pts.size() - 1) * STEP
		var s := _w_s[i] + _w_dir[i] * _w_speed[i] * delta * (0.35 if _hold.has(i) else 1.0)
		if s > span or s < 0.0:
			_w_dir[i] = -_w_dir[i]
			s = clampf(s, 0.0, span)
		_w_s[i] = s
		_w_lat[i] = move_toward(_w_lat[i], KEEP_RIGHT * _w_dir[i], delta * 2.0 * KEEP_RIGHT / KEEP_RIGHT_TIME)
		if not all and pts[0].distance_squared_to(focus) > r2:
			continue
		var k := mini(int(s / STEP), pts.size() - 2)
		var a := pts[k]
		var b := pts[k + 1]
		# Bên phải chiều đi: orthogonal() của hướng khúc là bên trái chiều xuôi.
		var n := (b - a).normalized().orthogonal()
		var base := a.lerp(b, s / STEP - float(k))
		var p := base - n * (_w_lat[i] + (0.0 if all else _dodge_step(i, base, n, (b - a).normalized() * _w_dir[i], focus, delta)))
		var f := (b - a) * _w_dir[i]
		var xf := Transform3D(Basis(Vector3.UP, atan2(f.x, f.y)), Vector3(p.x, 0.0, p.y))
		if not all and p.distance_squared_to(focus) < NEAR * NEAR and _animate(i, _w_look[i], xf, _w_speed[i], delta, seen):
			xf = Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
		mm.set_instance_transform(slot, xf)


## Né An: An ở phía trước trong hành lang 1 m thì bước lệch sang bên đang thoáng hơn và đi chậm lại, qua rồi thì
## trở về làn. Trả độ lệch thêm (cùng chiều với _w_lat).
func _dodge_step(i: int, base: Vector2, n: Vector2, fwd: Vector2, focus: Vector2, delta: float) -> float:
	var cur := float(_dodge.get(i, 0.0))
	var rel := focus - base
	if rel.length_squared() > 25.0:
		if cur != 0.0:
			_dodge.erase(i)
			_hold.erase(i)
		return 0.0
	var ahead := rel.dot(fwd)
	var gap := rel.dot(n) + _w_lat[i]
	var want := 0.0
	if ahead > -0.5 and ahead < 2.6:
		want = maxf(0.0, DODGE_GAP - gap) if gap >= 0.0 else minf(0.0, -DODGE_GAP - gap)
		want = clampf(want, -DODGE_MAX, DODGE_MAX)
	cur = move_toward(cur, want, delta * 2.4)
	if absf(gap + cur) < DODGE_GAP * 0.8 and ahead > 0.0 and ahead < 1.4:
		_hold[i] = true
	else:
		_hold.erase(i)
	if cur == 0.0 and want == 0.0:
		_dodge.erase(i)
	else:
		_dodge[i] = cur
	return cur


## Người có xương đang đứng thay người đi bộ (gần An), để An không đi xuyên qua họ.
func live_people() -> Array:
	return _live.values()


## Người có xương đứng thay cho người key ở xf, bước theo tốc độ speed (m/giây); hết người rảnh thì trả false.
func _animate(key: int, avatar: String, xf: Transform3D, speed: float, delta: float, seen: Dictionary) -> bool:
	var h: Node3D = _live.get(key)
	if h == null:
		var free: Array = _pool.get(avatar, [])
		if free.is_empty():
			return false
		h = free.pop_back()
		h.visible = true
		_live[key] = h
	seen[key] = true
	h.transform = xf
	h.animate(delta, speed / (Human.WALK_SPEED * 1.6))
	return true


func _release(key: int) -> void:
	var h: Node3D = _live[key]
	_live.erase(key)
	h.visible = false
	_pool[str(h.look.id)].append(h)


## Dựng sẵn một người có xương kiểu avatar (id), cất vào nhóm rảnh.
func _spare(avatar: String) -> void:
	var look: Dictionary = Character.CROWD_CHILD
	for l in Character.CROWD:
		if l.id == avatar:
			look = l
	if not Human.exists(str(look.rb)):
		return
	var h := Human.make(look)
	h.visible = false
	add_child(h)
	if not _pool.has(avatar):
		_pool[avatar] = []
	_pool[avatar].append(h)


func _update_kids(delta: float, focus := Vector2.ZERO, seen := {}) -> void:
	for g in range(_groups.size()):
		var grp: Dictionary = _groups[g]
		var c: Vector2 = grp.c
		var d: Vector2 = grp.d
		var n := d.orthogonal()
		var pos: Array[Vector2] = []
		for k in 3:
			# Ba đứa đứng tam giác dọc hẻm, chạy qua lại quanh chỗ của mình.
			var base := c + d * (float(k) - 1.0) * 2.6 + n * (0.7 if k == 1 else -0.5)
			var wob := sin(_time * 1.3 + float(grp.kids[k])) * 0.9
			pos.append(base + d * wob + n * cos(_time * 0.9 + float(grp.kids[k])) * 0.4)
		# Banh bay từ đứa này sang đứa kia mỗi 1,2 giây, nảy lên giữa đường.
		grp["t"] = float(grp.t) + delta / 1.2
		if float(grp.t) >= 1.0:
			grp["t"] = 0.0
			grp["from"] = grp.to
			grp["to"] = (int(grp.to) + 1 + _rng.randi() % 2) % 3
		var t := float(grp.t)
		var bp: Vector2 = pos[int(grp.from)].lerp(pos[int(grp.to)], t)
		_ball_mm.set_instance_transform(g, Transform3D(Basis.IDENTITY, Vector3(bp.x, 0.11 + sin(t * PI) * 0.6, bp.y)))
		for k in 3:
			var look: Vector2 = bp - pos[k]
			var yaw := atan2(look.x, look.y) if look.length() > 0.05 else 0.0
			var idx := g * 3 + k
			var xf := Transform3D(Basis(Vector3.UP, yaw), Vector3(pos[k].x, 0.0, pos[k].y))
			var speed := pos[k].distance_to(_kid_prev[idx]) / maxf(delta, 0.001)
			_kid_prev[idx] = pos[k]
			if not seen.is_empty() or focus != Vector2.ZERO:
				if pos[k].distance_squared_to(focus) < NEAR * NEAR and _animate(-1 - idx, CHILD, xf, speed, delta, seen):
					xf = Transform3D(Basis().scaled(Vector3.ZERO), xf.origin)
			_kid_mm.set_instance_transform(idx, xf)


# ---------------------------------------------------------------- chỗ trống, lòng đường

## Độ đông theo khoảng cách tới chỗ của truyện: đủ trong vòng 65 m, xa dần thưa dần, xa hẳn còn một phần ba.
static func _near(p: Vector2, center: Vector2) -> float:
	return clampf(1.25 - p.distance_to(center) / 260.0, 0.33, 1.0)


static func _big(r) -> bool:
	return not r.small and not r.bridge and not r.tunnel and float(r.width) >= 6.0 and r.line.size() >= 2


func _take(p: Vector2) -> void:
	var c := Vector2i(floori(p.x), floori(p.y))
	if not _taken.has(c):
		_taken[c] = []
	(_taken[c] as Array).append(p)


## Trong vòng r mét (tới 1 m) quanh p chưa có ai, chưa có gì.
func _free(p: Vector2, r: float) -> bool:
	var c := Vector2i(floori(p.x), floori(p.y))
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for q in _taken.get(c + Vector2i(dx, dy), []):
				if p.distance_to(q) < r:
					return false
	return true


## Lòng đường lớn (xe chạy) chừa 0,2 m mép; cầu (mặt cầu cao hơn mặt đất, xem real_city.ground_y) cả bề rộng thêm
## 0,35 m hai bên.
func _index_roads(roads: Array, center: Vector2) -> void:
	for r in roads:
		if r.tunnel or r.line.size() < 2 or not (_big(r) or r.bridge):
			continue
		var keep := float(r.width) / 2.0 + (0.35 if r.bridge else -0.2)
		for i in r.line.size() - 1:
			var a: Vector2 = r.line[i]
			var b: Vector2 = r.line[i + 1]
			if Geo.seg_dist(center, a, b) > 360.0:
				continue
			var box := Rect2(a, Vector2.ZERO).expand(b).grow(keep)
			for x in range(floori(box.position.x / ROAD_CELL), floori(box.end.x / ROAD_CELL) + 1):
				for y in range(floori(box.position.y / ROAD_CELL), floori(box.end.y / ROAD_CELL) + 1):
					var key := Vector2i(x, y)
					if not _roads.has(key):
						_roads[key] = []
					(_roads[key] as Array).append([a, b, keep])


## Trên lòng đường lớn hay trên cầu (xem _index_roads): người đứng, đi bộ tránh ra.
func _on_road(p: Vector2) -> bool:
	for s in _roads.get(Vector2i(floori(p.x / ROAD_CELL), floori(p.y / ROAD_CELL)), []):
		if Geo.seg_dist(p, s[0], s[1]) < float(s[2]):
			return true
	return false


# ---------------------------------------------------------------- đường gấp khúc

static func _length(line: PackedVector2Array) -> float:
	var total := 0.0
	for k in line.size() - 1:
		total += line[k].distance_to(line[k + 1])
	return total


## Điểm cách đầu đường gấp khúc s mét.
static func _at(line: PackedVector2Array, s: float) -> Vector2:
	var acc := 0.0
	for k in line.size() - 1:
		var l := line[k].distance_to(line[k + 1])
		if acc + l >= s:
			return line[k].lerp(line[k + 1], clampf((s - acc) / maxf(l, 0.001), 0.0, 1.0))
		acc += l
	return line[line.size() - 1]


## Đường gấp khúc dời ngang d mét (dương: bên trái theo chiều vẽ).
static func _offset(line: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in line.size():
		var a: Vector2 = line[maxi(i - 1, 0)]
		var b: Vector2 = line[mini(i + 1, line.size() - 1)]
		out.append(line[i] + (b - a).normalized().orthogonal() * d)
	return out
