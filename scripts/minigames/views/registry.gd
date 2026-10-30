extends RefCounted
## Chọn cảnh cho trò chơi nhỏ theo cfg.view (trò trong data/systems/minigames.json) hay cfg.scene (bàn bi-a cũ);
## còn lại là ca làm 3D (scripts/work/work_site.gd, cfg.kind: bricks, site, dishes, repair).
## Thêm trò mới: viết cảnh kế thừa minigame_view.gd, thêm một dòng vào VIEWS, khai báo trò trong minigames.json.

const WorkSite := preload("res://scripts/work/work_site.gd")
const VIEWS := {
	"beer_service": preload("res://scripts/minigames/views/beer_service_view.gd"),
	"ring_toss": preload("res://scripts/minigames/views/ring_toss_view.gd"),
	"brick_balance": preload("res://scripts/minigames/views/brick_balance_view.gd"),
	"billiards": preload("res://scripts/work/billiards.gd"),
}


static func make(cfg: Dictionary) -> Control:
	var key := str(cfg.get("view", cfg.get("scene", "")))
	return (VIEWS[key] if VIEWS.has(key) else WorkSite).new()
