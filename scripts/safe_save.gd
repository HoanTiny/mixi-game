extends RefCounted
## Stage and validate before replacing a save. A valid previous revision survives crashes.
static func _parse(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return parser.data

static func read_data(path: String) -> Variant:
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var value = _parse(candidate)
		if value is Dictionary or value is Array: return value
	return null

static func write_data(path: String, value: Variant) -> Error:
	if not (value is Dictionary or value is Array): return ERR_INVALID_DATA
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return error
	if _parse(temporary) == null: return ERR_INVALID_DATA
	if FileAccess.file_exists(path):
		var previous = _parse(path)
		# Never replace a good backup with a damaged primary save.
		if previous is Dictionary or previous is Array:
			error = DirAccess.copy_absolute(path, path + ".bak")
			if error != OK: return error
	return DirAccess.rename_absolute(temporary, path)
