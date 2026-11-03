# Máy chủ giả để thử chế độ Dựng khu thật khi không ra được mạng ngoài:
# /ob/<file>: phục vụ file có hỗ trợ Range (206); /nominatim/search: kết quả mẫu;
# /slow/api/interpreter: chờ 10 s mới trả (thử luật hỏi thêm máy sau 7 s); /fast/...: trả ngay; /broken/...: lỗi 504.
import sys, os, time, json, re, urllib.parse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
ROOT = sys.argv[1]
LOG = open(os.path.join(ROOT, "requests.log"), "a")
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, ctype="application/json", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path.startswith("/ob/"):
            f = os.path.join(ROOT, u.path.lstrip("/"))
            if not os.path.exists(f):
                return self._send(404, b"no")
            size = os.path.getsize(f)
            rng = self.headers.get("Range", "")
            m = re.match(r"bytes=(\d+)-(\d+)", rng)
            if not m:
                LOG.write("FULL %s\n" % u.path); LOG.flush()
                return self._send(200, open(f, "rb").read(), "application/octet-stream")
            a, b = int(m.group(1)), min(int(m.group(2)), size - 1)
            with open(f, "rb") as fh:
                fh.seek(a); data = fh.read(b - a + 1)
            LOG.write("RANGE %s %d-%d (%d)\n" % (u.path, a, b, len(data))); LOG.flush()
            return self._send(206, data, "application/octet-stream", {"Content-Range": "bytes %d-%d/%d" % (a, b, size)})
        if u.path.startswith("/nominatim/search"):
            q = urllib.parse.parse_qs(u.query)
            LOG.write("NOMINATIM %s\n" % q.get("q", [""])[0]); LOG.flush()
            return self._send(200, open(os.path.join(ROOT, "nominatim.json"), "rb").read())
        self._send(404, b"{}")
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode()
        LOG.write("OVERPASS %s %d bytes\n" % (self.path, n)); LOG.flush()
        if self.path.startswith("/broken"):
            return self._send(504, b"gateway timeout", "text/plain")
        if self.path.startswith("/slow"):
            time.sleep(10)
        data = urllib.parse.parse_qs(body).get("data", [""])[0]
        name = "overpass_preview.json" if "[\"highway\"~" in data and "building" not in data else "overpass.json"
        p = os.path.join(ROOT, name)
        self._send(200, open(p, "rb").read() if os.path.exists(p) else b'{"elements":[]}')
ThreadingHTTPServer(("127.0.0.1", int(sys.argv[2])), H).serve_forever()
