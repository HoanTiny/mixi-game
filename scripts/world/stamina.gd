extends RefCounted
## Hơi khi chạy (giữ Shift hay nút Chạy): tính theo giây thật, không lưu vào bản lưu. Chạy thì tụt drain mỗi giây (Thể
## chất cao tụt chậm hơn, đang Mệt từ mức cảnh báo thì tụt nhanh hơn); không chạy thì hồi, đứng yên hồi nhanh hơn đi bộ.
## Tụt về 0 là hụt hơi: không chạy được, đi chậm lại một chút, phải hồi tới recoverAt mới chạy tiếp.
## Số liệu ở cfg.stamina (data/config.json không có thì dùng DEFAULTS).

const DEFAULTS := {"max": 100.0, "drain": 12.0, "regenWalk": 5.0, "regenIdle": 11.0, "recoverAt": 45.0, "windedSlow": 0.85,
	"drainPerStr": -0.08, "tiredDrain": 0.5, "regenDelay": 0.6}

var cfg: Dictionary = DEFAULTS
var value := 100.0
## Đang hụt hơi: chờ hồi tới recoverAt.
var winded := false
## Giây kể từ lần chạy cuối (vừa dừng chạy thì chưa hồi ngay, như người thở dốc).
var _since_run := 99.0


func setup(data: Dictionary) -> void:
	cfg = DEFAULTS.merged(data, true)
	value = float(cfg.max)


## Chạy được không (đủ hơi, không hụt hơi).
func can_run() -> bool:
	return not winded and value > 0.0


## Một khung hình: running là đang chạy thật (có bước đi), moving là có bước đi. strength: cấp Thể chất, tired: đang
## Mệt từ mức cảnh báo. Trả về true nếu vừa hụt hơi ở khung này.
func step(delta: float, running: bool, moving: bool, strength := 1, tired := false) -> bool:
	var top := float(cfg.max)
	if running and can_run():
		_since_run = 0.0
		var rate := float(cfg.drain) * maxf(0.2, 1.0 + float(cfg.drainPerStr) * float(strength - 1)) * (1.0 + (float(cfg.tiredDrain) if tired else 0.0))
		value = maxf(0.0, value - rate * delta)
		if value <= 0.0:
			winded = true
			return true
		return false
	_since_run += delta
	if _since_run >= float(cfg.regenDelay):
		value = minf(top, value + float(cfg.regenWalk if moving else cfg.regenIdle) * delta)
	if winded and value >= float(cfg.recoverAt):
		winded = false
	return false


## Hệ số tốc độ đi bộ khi hụt hơi.
func walk_mult() -> float:
	return float(cfg.windedSlow) if winded else 1.0


## Phần hơi còn lại 0..1.
func ratio() -> float:
	return value / float(cfg.max)


func reset() -> void:
	value = float(cfg.max)
	winded = false
	_since_run = 99.0
