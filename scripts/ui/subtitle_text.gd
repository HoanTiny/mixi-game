extends RefCounted
## Cắt lời kể và lời thoại thành từng câu phụ đề ngắn: mỗi dòng {who, text}. who rỗng là lời kể.

## Câu dài hơn chừng này thì cắt đôi ở dấu phẩy gần giữa; câu ngắn hơn MERGE thì gộp với câu sau.
const MAX_LEN := 130
const MERGE := 38


## Lời kể (có thể nhiều đoạn, có trích lời trong ngoặc kép) thành các câu ngắn.
static func narration(text: String, who := "") -> Array:
	var out := []
	for para in text.split("\n", false):
		for s in _sentences(para.strip_edges()):
			out.append({"who": who, "text": s})
	return out


## Lời thoại kiểu 'Bà Tư: "..."' (có thể hai người nối nhau: 'Anh Quân: "..." An: "..."') thành các dòng có tên người
## nói; không đúng kiểu đó thì coi như lời kể.
static func quote(text: String) -> Array:
	var out := []
	var re := RegEx.new()
	re.compile("([^\"“”]+?):\\s*[\"“]([^\"”]*)[\"”]")
	var found := re.search_all(text)
	if found.is_empty():
		return narration(text)
	for m in found:
		var who := m.get_string(1).strip_edges()
		# "Chú Sáu (qua điện thoại)" thành "Chú Sáu · qua điện thoại".
		if who.ends_with(")") and who.contains(" ("):
			who = who.trim_suffix(")").replace(" (", " · ")
		for s in _sentences(m.get_string(2).strip_edges()):
			out.append({"who": who, "text": s, "say": true})
	return out


## Cắt một đoạn thành câu ở dấu . ! ? … nằm ngoài ngoặc kép, rồi gộp câu quá ngắn, cắt câu quá dài.
static func _sentences(p: String) -> Array:
	var raw := []
	var cur := ""
	var inside := false
	var n := p.length()
	for i in n:
		var c := p[i]
		cur += c
		if c == "\"":
			inside = not inside
		elif c == "“":
			inside = true
		elif c == "”":
			inside = false
		var closing := c == "\"" or c == "”"
		var end_mark := c in [".", "!", "?", "…"] or (closing and not inside and i > 0 and p[i - 1] in [".", "!", "?", "…"])
		if end_mark and not inside and i + 1 < n and p[i + 1] == " " and (i + 2 >= n or _starts_upper(p[i + 2])):
			raw.append(cur.strip_edges())
			cur = ""
	if cur.strip_edges() != "":
		raw.append(cur.strip_edges())
	var merged := []
	for s in raw:
		if not merged.is_empty() and (str(merged[-1]).length() < MERGE or s.length() < MERGE / 2) \
				and str(merged[-1]).length() + s.length() + 1 <= MAX_LEN:
			merged[-1] = str(merged[-1]) + " " + s
		else:
			merged.append(s)
	var out := []
	for s in merged:
		out.append_array(_split_long(s))
	return out


static func _starts_upper(c: String) -> bool:
	return c == "\"" or (c == c.to_upper() and c != c.to_lower()) or c.is_valid_int()


## Câu quá dài: cắt ở dấu phẩy (ngoài ngoặc kép) gần giữa câu nhất.
static func _split_long(s: String) -> Array:
	if s.length() <= MAX_LEN:
		return [s]
	var best := -1
	var inside := false
	for i in s.length() - 1:
		if s[i] == "\"":
			inside = not inside
		if not inside and s[i] in [",", ";", ":"] and s[i + 1] == " ":
			if best < 0 or absi(i - s.length() / 2) < absi(best - s.length() / 2):
				best = i
	if best < 12 or best > s.length() - 12:
		return [s]
	return _split_long(s.substr(0, best + 1).strip_edges()) + _split_long(s.substr(best + 1).strip_edges())
