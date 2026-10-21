extends RefCounted
## Đọc file FlatGeobuf (định dạng của Open Buildings bản VIDA) từ xa mà không tải cả file:
## 1. Tải phần đầu: 8 byte nhận dạng, độ dài header, header (FlatBuffers): kiểu hình, các cột, số nhà, cỡ nút chỉ mục.
## 2. Đi chỉ mục không gian (cây R đóng gói theo đường Hilbert) từ gốc xuống lá, mỗi tầng chỉ tải các nút
##    chạm khung cần đọc, các đoạn gần nhau gộp thành một yêu cầu.
## 3. Tải đúng các nhà ở lá chạm khung, giải đường viền (kinh độ, vĩ độ) và cột độ tin cậy, nguồn.
## Tài liệu định dạng: https://flatgeobuf.org (header.fbs, feature.fbs, packedrtree).

const MAGIC := [0x66, 0x67, 0x62, 0x03]
const NODE_ITEM := 40
## Kiểu cột của FlatGeobuf (ColumnType) và số byte của kiểu có độ dài cố định.
const FIXED := {0: 1, 1: 1, 2: 1, 3: 2, 4: 2, 5: 4, 6: 4, 7: 8, 8: 8, 9: 4, 10: 8}

var url := ""
var fetcher
var gap := 65536
var error := ""
var header_size := 0
var geometry_type := 0
var count := 0
var node_size := 16
var columns: Array = []
var _tree_start := 0
var _tree_size := 0
var _levels: Array = []
## Số byte đã tải, để báo cho người chơi biết chỉ đọc một phần nhỏ của file.
var bytes_read := 0


func _init(file_url: String, f, merge_gap := 65536) -> void:
	url = file_url
	fetcher = f
	gap = merge_gap


func _fetch(a: int, b: int) -> PackedByteArray:
	var d: PackedByteArray = await fetcher.get_range(url, a, b)
	bytes_read += d.size()
	return d


## Đọc header. false nếu không phải FlatGeobuf hay không tải được.
func open() -> bool:
	var head: PackedByteArray = await _fetch(0, 65535)
	if head.size() < 12:
		error = "không tải được phần đầu file"
		return false
	for i in 3:
		if head[i] != MAGIC[i]:
			error = "không phải file FlatGeobuf"
			return false
	header_size = head.decode_u32(8)
	if 12 + header_size > head.size():
		head = await _fetch(0, 12 + header_size - 1)
		if head.size() < 12 + header_size:
			error = "header không đủ"
			return false
	var hb := head.slice(12, 12 + header_size)
	var root := hb.decode_u32(0)
	geometry_type = _u8(hb, root, 2, 0)
	count = _u64(hb, root, 8, 0)
	node_size = _u16(hb, root, 9, 16)
	var cv := _vec(hb, root, 7)
	if cv >= 0:
		for i in hb.decode_u32(cv):
			var p := cv + 4 + i * 4
			var ct := p + hb.decode_u32(p)
			columns.append({"name": _str(hb, ct, 0).to_lower(), "type": _u8(hb, ct, 1, 0)})
	_tree_start = 12 + header_size
	if node_size > 0 and count > 0:
		_levels = level_bounds(count, node_size)
		_tree_size = _num_nodes(count, node_size) * NODE_ITEM
	return true


static func _num_nodes(n: int, ns: int) -> int:
	var total := n
	var k := n
	while k != 1:
		k = int(ceil(float(k) / ns))
		total += k
	return total


## Vị trí các tầng của cây trong file: levels[0] là tầng lá (ở cuối), tầng cuối là gốc (nút 0).
static func level_bounds(n: int, ns: int) -> Array:
	var sizes := [n]
	var k := n
	while k != 1:
		k = int(ceil(float(k) / ns))
		sizes.append(k)
	var total := 0
	for s in sizes:
		total += int(s)
	var out := []
	var end := total
	for s in sizes:
		out.append([end - int(s), end])
		end -= int(s)
	return out


## Các nhà chạm khung [tây, nam, đông, bắc] (kinh, vĩ độ). Trả về [{rings: [PackedVector2Array…], props: {}}].
func read_bbox(minx: float, miny: float, maxx: float, maxy: float, max_features := 20000) -> Array:
	if _levels.is_empty():
		error = "file không có chỉ mục không gian"
		return []
	# Đi từ gốc xuống: mỗi phần tử là chỉ số nút đầu của một nhóm con (tối đa node_size nút liền nhau).
	var starts: Array = [0]
	var leaves := []
	for li in range(_levels.size() - 1, -1, -1):
		var lb: Array = _levels[li]
		var ranges := []
		for s in starts:
			var a := int(s)
			var b := mini(a + node_size, int(lb[1]))
			# Ở tầng lá đọc thêm một nút để biết chỗ kết thúc của nhà cuối nhóm.
			if li == 0 and b < int(lb[1]):
				b += 1
			ranges.append([a, b])
		ranges = _merge(ranges, gap / NODE_ITEM)
		var next := []
		for r in ranges:
			var a := int(r[0])
			var b := int(r[1])
			var d: PackedByteArray = await _fetch(_tree_start + a * NODE_ITEM, _tree_start + b * NODE_ITEM - 1)
			if d.size() < (b - a) * NODE_ITEM:
				error = "không tải được nút chỉ mục"
				return []
			for i in range(a, b):
				var o := (i - a) * NODE_ITEM
				var hit := d.decode_double(o) <= maxx and d.decode_double(o + 8) <= maxy and d.decode_double(o + 16) >= minx and d.decode_double(o + 24) >= miny
				var off := d.decode_u64(o + 32)
				if li == 0:
					var nxt := d.decode_u64(o + 32 + NODE_ITEM) if i + 1 < b else -1
					if hit and _in_group(i, starts, node_size):
						leaves.append([off, nxt])
				elif hit:
					next.append(off)
		starts = next
		if li > 0 and starts.is_empty():
			return []
	if leaves.size() > max_features:
		leaves.resize(max_features)
	return await _read_features(leaves)


static func _in_group(i: int, starts: Array, ns: int) -> bool:
	for s in starts:
		if i >= int(s) and i < int(s) + ns:
			return true
	return false


## Gộp các đoạn [a, b) chồng hay gần nhau (cách nhau không quá max_gap).
static func _merge(ranges: Array, max_gap: int) -> Array:
	ranges.sort_custom(func(x, y) -> bool: return int(x[0]) < int(y[0]))
	var out := []
	for r in ranges:
		if not out.is_empty() and int(r[0]) <= int(out[out.size() - 1][1]) + max_gap:
			out[out.size() - 1][1] = maxi(int(out[out.size() - 1][1]), int(r[1]))
		else:
			out.append([int(r[0]), int(r[1])])
	return out


func _read_features(leaves: Array) -> Array:
	var feat_start := _tree_start + _tree_size
	# Đoạn byte của từng nhà: [đầu, cuối) tính từ đầu phần dữ liệu nhà; nhà cuối nhóm chưa biết cuối thì đọc dư rồi xem độ dài.
	var spans := []
	for l in leaves:
		var a := int(l[0])
		var b := int(l[1]) if int(l[1]) > a else a + 8192
		spans.append([a, b])
	spans = _merge(spans, gap)
	var out := []
	for sp in spans:
		var a := int(sp[0])
		var d: PackedByteArray = await _fetch(feat_start + a, feat_start + int(sp[1]) - 1)
		var want := {}
		for l in leaves:
			if int(l[0]) >= a and int(l[0]) < int(sp[1]):
				want[int(l[0]) - a] = true
		for p in want:
			var pos := int(p)
			if pos + 4 > d.size():
				continue
			var len := d.decode_u32(pos)
			if pos + 4 + len > d.size():
				var more: PackedByteArray = await _fetch(feat_start + a + pos, feat_start + a + pos + 4 + len - 1)
				if more.size() < 4 + len:
					continue
				var f := parse_feature(more.slice(4))
				if not f.is_empty():
					out.append(f)
				continue
			var f := parse_feature(d.slice(pos + 4, pos + 4 + len))
			if not f.is_empty():
				out.append(f)
	return out


## Giải một nhà (bảng Feature của FlatBuffers): đường viền ngoài của từng đa giác, và các cột.
func parse_feature(fb: PackedByteArray) -> Dictionary:
	if fb.size() < 8:
		return {}
	var root := fb.decode_u32(0)
	var g := _table(fb, root, 0)
	var rings := []
	if g >= 0:
		_geom_rings(fb, g, geometry_type, rings)
	var props := {}
	var pv := _vec(fb, root, 1)
	if pv >= 0:
		var n := fb.decode_u32(pv)
		var p := pv + 4
		var end := p + n
		while p + 2 <= end:
			var ci := fb.decode_u16(p)
			p += 2
			if ci >= columns.size():
				break
			var c: Dictionary = columns[ci]
			var t := int(c.type)
			var v = null
			if FIXED.has(t):
				match t:
					0: v = fb.decode_s8(p)
					1, 2: v = fb[p]
					3: v = fb.decode_s16(p)
					4: v = fb.decode_u16(p)
					5: v = fb.decode_s32(p)
					6: v = fb.decode_u32(p)
					7: v = fb.decode_s64(p)
					8: v = fb.decode_u64(p)
					9: v = fb.decode_float(p)
					10: v = fb.decode_double(p)
				p += int(FIXED[t])
			else:
				var l := fb.decode_u32(p)
				if t in [11, 12, 13]:
					v = fb.slice(p + 4, p + 4 + l).get_string_from_utf8()
				p += 4 + l
			props[c.name] = v
	return {"rings": rings, "props": props}


func _geom_rings(fb: PackedByteArray, g: int, def_type: int, rings: Array) -> void:
	var t := _u8(fb, g, 6, def_type)
	var parts := _vec(fb, g, 7)
	if parts >= 0 and fb.decode_u32(parts) > 0:
		# MultiPolygon: mỗi phần là một Polygon.
		for i in fb.decode_u32(parts):
			var p := parts + 4 + i * 4
			_geom_rings(fb, p + fb.decode_u32(p), 3, rings)
		return
	if t != 3 and t != 6 and t != 0:
		return
	var xy := _vec(fb, g, 1)
	if xy < 0:
		return
	var n := fb.decode_u32(xy) / 2
	var first_end := n
	var ends := _vec(fb, g, 0)
	if ends >= 0 and fb.decode_u32(ends) > 0:
		first_end = fb.decode_u32(ends + 4)
	var ring := PackedVector2Array()
	ring.resize(first_end)
	for i in first_end:
		ring[i] = Vector2(fb.decode_double(xy + 4 + i * 16), fb.decode_double(xy + 12 + i * 16))
	rings.append(ring)


# ---------------------------------------------------------------- FlatBuffers

## Vị trí trường thứ k của bảng tại t (-1 nếu không có).
static func _field(b: PackedByteArray, t: int, k: int) -> int:
	var vt := t - b.decode_s32(t)
	var o := 4 + k * 2
	if o >= b.decode_u16(vt):
		return -1
	var off := b.decode_u16(vt + o)
	return -1 if off == 0 else t + off


static func _u8(b: PackedByteArray, t: int, k: int, def: int) -> int:
	var p := _field(b, t, k)
	return def if p < 0 else b[p]


static func _u16(b: PackedByteArray, t: int, k: int, def: int) -> int:
	var p := _field(b, t, k)
	return def if p < 0 else b.decode_u16(p)


static func _u64(b: PackedByteArray, t: int, k: int, def: int) -> int:
	var p := _field(b, t, k)
	return def if p < 0 else b.decode_u64(p)


## Vector: trả về vị trí ô độ dài (u32), phần tử bắt đầu ngay sau.
static func _vec(b: PackedByteArray, t: int, k: int) -> int:
	var p := _field(b, t, k)
	return -1 if p < 0 else p + b.decode_u32(p)


static func _table(b: PackedByteArray, t: int, k: int) -> int:
	var p := _field(b, t, k)
	return -1 if p < 0 else p + b.decode_u32(p)


static func _str(b: PackedByteArray, t: int, k: int) -> String:
	var p := _vec(b, t, k)
	return "" if p < 0 else b.slice(p + 4, p + 4 + b.decode_u32(p)).get_string_from_utf8()
