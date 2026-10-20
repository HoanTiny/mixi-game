extends Node
## Autoload: giữ một ván chơi cho cả game và tự lưu vào user:// sau mỗi thay đổi.

const GameLogic := preload("res://scripts/game_logic.gd")
const SAVE_PATH := "user://save.json"
const NOTES_PATH := "user://notes.json"

var game: GameLogic
## Chạy với "-- --demo" để vào thẳng ngày 18 tuyến B mà không ghi đè bản lưu thật;
## thêm "--demo-route=A" hoặc "=C" để đổi tuyến, "--demo-full" để chơi từ ngày 1.
var _persist := true
## Chỗ An hiện ra khi về lại phố từ màn khác (để dành cho các màn ngoài phố sau này).
var spawn_at := ""


func _ready() -> void:
	game = GameLogic.new()
	game.load_data()
	var args := OS.get_cmdline_user_args()
	if args.has("--demo"):
		_persist = false
		var route := "B"
		for arg in args:
			if arg.begins_with("--demo-route="):
				route = arg.substr(13)
		# "--demo-full": chơi đủ 30 ngày từ ngày 1 thay vì lát cắt.
		game.new_game("full" if args.has("--demo-full") else route)
		var guard := 0
		while not game.s.queue.is_empty() and guard < 10:
			guard += 1
			game.resolve_first_available()
		# "--demo-end": tự chơi tới hết ngày 22 để xem bảng tổng kết.
		while args.has("--demo-end") and not game.is_over() and guard < 60:
			guard += 1
			if game.s.queue.is_empty():
				game.finish_day()
			else:
				game.resolve_first_available()
		return
	var saved_notes = _read(NOTES_PATH)
	if saved_notes is Array:
		game.notes = saved_notes
	var saved = _read(SAVE_PATH)
	if saved is Dictionary and not saved.is_empty():
		game.s = saved
	game.changed.connect(_save)
	game.notes_changed.connect(func() -> void: _write(NOTES_PATH, game.notes))


func restart() -> void:
	game.reset()


func _save() -> void:
	_write(SAVE_PATH, game.s)


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _write(path: String, data: Variant) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Không lưu được " + path)
		return
	f.store_string(JSON.stringify(data))
