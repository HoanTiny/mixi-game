extends RefCounted
## Đồng hồ 24 giờ của ván chơi. Nguồn duy nhất vẫn là s.day và s.used (số giờ đã dùng tính từ cfg.dayStart); file này
## chỉ đọc và quy đổi. Một ngày có 24 giờ: phần thức (dayStart → dayEnd) chơi từng giờ, phần ngủ (dayEnd → dayStart
## hôm sau) gói vào một lần qua đêm ở finish_day (cfg.needs.overnight, cfg.fatigue.sleep).
## Mọi hạn chót, trạng thái có hạn dùng giờ tuyệt đối abs_hours() = ngày × 24 + giờ, để so được qua nhiều ngày.

const HOURS_PER_DAY := 24.0
## Buổi trong ngày: [từ giờ, tên]. Giờ trước mốc đầu tiên là đêm.
const PERIODS := [[5.0, "sáng"], [11.0, "trưa"], [13.0, "chiều"], [18.0, "tối"], [22.0, "đêm"]]


## Giờ trong ngày, 0..24 (ví dụ 13.5 là 13:30).
static func hour(g) -> float:
	return fposmod(g.clock(), HOURS_PER_DAY)


static func minute(g) -> int:
	return int(floor(fposmod(g.clock(), 1.0) * 60.0 + 0.0001))


## Giờ tuyệt đối tính từ đầu ván.
static func abs_hours(g) -> float:
	return g.now_abs()


## Giờ tuyệt đối của một mốc trong ngày d.
static func at(day: int, h: float) -> float:
	return float(day) * HOURS_PER_DAY + h


## "07:45"
static func text(g) -> String:
	return "%02d:%02d" % [int(hour(g)), minute(g)]


static func period(g) -> String:
	var h := hour(g)
	var name: String = PERIODS[PERIODS.size() - 1][1]
	for p in PERIODS:
		if h >= float(p[0]):
			name = p[1]
	return name


static func is_night(g) -> bool:
	return hour(g) >= float(g.cfg.dayEnd) or hour(g) < float(g.cfg.dayStart)


## Số giờ thức trong ngày (cfg.dayEnd − cfg.dayStart) và số giờ ngủ gói vào lúc qua đêm.
static func awake_hours(g) -> float:
	return float(g.cfg.dayEnd) - float(g.cfg.dayStart)


static func sleep_hours(g) -> float:
	return HOURS_PER_DAY - awake_hours(g)


## Còn bao nhiêu giờ tới mốc h trong hôm nay (âm nếu đã qua).
static func hours_until(g, h: float) -> float:
	return h - g.clock()


## Phần ngày thức đã trôi, 0..1 (thanh thời gian, ánh sáng).
static func day_fraction(g) -> float:
	return clampf(float(g.s.get("used", 0.0)) / awake_hours(g), 0.0, 1.0)
