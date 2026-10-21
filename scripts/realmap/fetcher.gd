extends Node
## Gọi thẳng các nguồn bản đồ miễn phí từ trình duyệt (bản web) hay từ máy (bản cài), không qua máy chủ trung gian:
## - Nominatim: tìm tên khu ra tọa độ, khung và mã nước.
## - Overpass: hỏi máy đầu tiên; quá waitSeconds giây chưa trả lời (hay báo lỗi sớm) thì hỏi thêm các máy còn lại,
##   máy nào trả về dữ liệu hợp lệ trước thì dùng, các yêu cầu còn lại bị hủy.
## - Đọc từng đoạn byte của một file lớn (yêu cầu Range) cho Open Buildings.

signal status(text: String)

var cfg: Dictionary = {}
var _tls: TLSOptions


func _init(config: Dictionary = {}) -> void:
	cfg = config
	# Bản cài trên máy đi qua proxy công ty: đọc HTTPS_PROXY, và tin thêm chứng chỉ gốc ở SSL_CERT_FILE nếu có.
	if not OS.has_feature("web"):
		var ca := OS.get_environment("SSL_CERT_FILE")
		if ca != "" and FileAccess.file_exists(ca):
			var cert := X509Certificate.new()
			if cert.load(ca) == OK:
				_tls = TLSOptions.client(cert)


## Gắn proxy (nếu máy có HTTPS_PROXY) và chứng chỉ cho một yêu cầu, bỏ qua trên trình duyệt.
func _setup(req: HTTPRequest, url: String) -> void:
	if OS.has_feature("web") or url.begins_with("http://127.") or url.begins_with("http://localhost"):
		return
	var proxy := OS.get_environment("HTTPS_PROXY" if url.begins_with("https") else "HTTP_PROXY")
	if proxy == "":
		proxy = OS.get_environment("https_proxy")
	if proxy != "":
		var hp := proxy.trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
		if hp.contains("@"):
			hp = hp.get_slice("@", 1)
		var host := hp.get_slice(":", 0)
		var port := int(hp.get_slice(":", 1)) if hp.contains(":") else 80
		req.set_https_proxy(host, port)
		req.set_http_proxy(host, port)
	if _tls != null:
		req.set_tls_options(_tls)


## Một yêu cầu HTTP. limit: số byte tối đa nhận về (chặn trường hợp máy chủ bỏ qua Range mà gửi cả file vài GB).
func http(url: String, headers := PackedStringArray(), method := HTTPClient.METHOD_GET, body := "", timeout := 30.0, limit := -1) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.body_size_limit = limit
	req.accept_gzip = method != HTTPClient.METHOD_GET or not _has_range(headers)
	_setup(req, url)
	add_child(req)
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "body": PackedByteArray(), "error": "không gửi được yêu cầu (%d)" % err}
	var res: Array = await req.request_completed
	req.queue_free()
	var ok: bool = res[0] == HTTPRequest.RESULT_SUCCESS and int(res[1]) in [200, 206]
	return {"ok": ok, "code": int(res[1]), "body": res[3], "result": int(res[0]), "headers": res[2],
		"error": "" if ok else _why(int(res[0]), int(res[1]))}


static func _has_range(headers: PackedStringArray) -> bool:
	for h in headers:
		if h.to_lower().begins_with("range:"):
			return true
	return false


static func _why(result: int, code: int) -> String:
	match result:
		HTTPRequest.RESULT_SUCCESS:
			return "máy chủ trả mã %d" % code
		HTTPRequest.RESULT_TIMEOUT:
			return "quá giờ chờ"
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_CONNECTION_ERROR:
			return "không kết nối được"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "dữ liệu lớn quá giới hạn"
	return "lỗi mạng (%d)" % result


func _ua_headers() -> PackedStringArray:
	# Trình duyệt tự gửi User-Agent và Referer (không được ghi đè); bản cài thì tự giới thiệu theo quy định của Nominatim.
	if OS.has_feature("web"):
		return PackedStringArray()
	return PackedStringArray(["User-Agent: " + str(cfg.get("nominatim", {}).get("userAgent", "TruocMuaMua/1.0"))])


# ---------------------------------------------------------------- Nominatim

## Tìm tên khu. Trả về [{name, lat, lon, bbox: [nam, bắc, tây, đông], cc}] hoặc {"error": ...} trong mảng rỗng.
func search(q: String) -> Dictionary:
	var n: Dictionary = cfg.get("nominatim", {})
	var url := "%s?q=%s&format=jsonv2&addressdetails=1&limit=%d&accept-language=vi" % [
		str(n.get("url", "https://nominatim.openstreetmap.org/search")), q.uri_encode(), int(n.get("limit", 6))]
	if str(n.get("countrycodes", "")) != "":
		url += "&countrycodes=" + str(n.countrycodes)
	status.emit("Đang tìm \"%s\" trên Nominatim…" % q)
	var r := await http(url, _ua_headers(), HTTPClient.METHOD_GET, "", 20.0, 2_000_000)
	if not r.ok:
		return {"error": "Nominatim: " + str(r.error), "places": []}
	var data = JSON.parse_string((r.body as PackedByteArray).get_string_from_utf8())
	if not (data is Array):
		return {"error": "Nominatim trả dữ liệu lạ", "places": []}
	var out := []
	for p in data:
		var bb: Array = p.get("boundingbox", [])
		out.append({"name": str(p.get("display_name", "")), "lat": float(p.get("lat", 0)), "lon": float(p.get("lon", 0)),
			"bbox": [float(bb[0]), float(bb[1]), float(bb[2]), float(bb[3])] if bb.size() == 4 else [],
			"cc": str(p.get("address", {}).get("country_code", "")).to_lower(), "kind": str(p.get("addresstype", p.get("type", "")))})
	return {"error": "", "places": out}


# ---------------------------------------------------------------- Overpass

## Gửi một câu hỏi Overpass tới nhiều máy theo luật chờ; trả về {json, server} hoặc {error}.
func overpass(query: String) -> Dictionary:
	var o: Dictionary = cfg.get("overpass", {})
	var servers: Array = o.get("servers", ["https://overpass-api.de/api/interpreter"])
	var wait := float(o.get("waitSeconds", 7.0))
	var timeout := float(o.get("timeoutSeconds", 60.0))
	var state := {"done": false, "json": null, "server": "", "pending": 0, "errors": [], "reqs": []}
	_ask(str(servers[0]), query, state, timeout)
	status.emit("Đang hỏi Overpass (%s)…" % _host(str(servers[0])))
	var t0 := Time.get_ticks_msec()
	var backups := servers.size() <= 1
	while not bool(state.done):
		await get_tree().process_frame
		var waited := (Time.get_ticks_msec() - t0) / 1000.0
		# Máy đầu chưa trả lời sau waitSeconds giây, hay đã báo lỗi: hỏi thêm các máy còn lại cùng lúc.
		if not backups and (waited >= wait or int(state.pending) == 0):
			backups = true
			var names := []
			for k in range(1, servers.size()):
				_ask(str(servers[k]), query, state, timeout)
				names.append(_host(str(servers[k])))
			status.emit("Overpass chưa trả lời, hỏi thêm %s…" % ", ".join(names))
		if backups and int(state.pending) == 0:
			break
		if waited > timeout + wait + 5.0:
			break
	for req in state.reqs:
		if is_instance_valid(req):
			req.cancel_request()
			req.queue_free()
	if bool(state.done):
		return {"json": state.json, "server": state.server, "error": ""}
	return {"json": null, "server": "", "error": "Overpass: " + "; ".join(state.errors)}


func _ask(server: String, query: String, state: Dictionary, timeout: float) -> void:
	var req := HTTPRequest.new()
	req.timeout = timeout
	req.body_size_limit = 200_000_000
	_setup(req, server)
	add_child(req)
	state.reqs.append(req)
	state["pending"] = int(state.pending) + 1
	req.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		state["pending"] = int(state.pending) - 1
		if bool(state.done):
			return
		if result == HTTPRequest.RESULT_SUCCESS and code == 200:
			var data = JSON.parse_string(body.get_string_from_utf8())
			if data is Dictionary and data.has("elements"):
				state["done"] = true
				state["json"] = data
				state["server"] = server
				return
			state.errors.append(_host(server) + ": dữ liệu lạ")
		else:
			state.errors.append(_host(server) + ": " + _why(result, code)))
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	headers.append_array(_ua_headers())
	if req.request(server, headers, HTTPClient.METHOD_POST, "data=" + query.uri_encode()) != OK:
		state["pending"] = int(state.pending) - 1
		state.errors.append(_host(server) + ": không gửi được")


static func _host(url: String) -> String:
	var s := url.trim_prefix("https://").trim_prefix("http://")
	return s.substr(0, s.find("/")) if s.find("/") > 0 else s


# ---------------------------------------------------------------- đọc theo byte

## Đọc byte [a, b] (tính cả b) của một file. Trả về rỗng nếu lỗi.
func get_range(url: String, a: int, b: int) -> PackedByteArray:
	var r := await http(url, PackedStringArray(["Range: bytes=%d-%d" % [a, b]]), HTTPClient.METHOD_GET, "", 60.0, (b - a + 1) + 1024)
	if not r.ok:
		return PackedByteArray()
	var body: PackedByteArray = r.body
	# Máy chủ không hiểu Range mà file lại nhỏ: tự cắt đúng đoạn.
	if int(r.code) == 200 and body.size() > b - a + 1:
		return body.slice(a, b + 1)
	return body
