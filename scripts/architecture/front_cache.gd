extends RefCounted
## Offline-built geometry; dynamic props, signage, NPCs and collision remain runtime-owned.
const VERSION := 1
static func restore(parent: Node3D, id: String, width: float, depth: float, seed: int) -> Dictionary:
	if OS.get_cmdline_user_args().has("--no-front-cache"): return {}
	var path := "res://assets/architecture/baked/%s.scn" % id
	if not ResourceLoader.exists(path): return {}
	var scene := load(path) as PackedScene
	if scene == null: return {}
	var node := scene.instantiate() as Node3D
	var signature: Array = node.get_meta("signature", [])
	if signature != [VERSION,width,depth,seed]:
		node.free()
		return {}
	parent.add_child(node)
	var result: Dictionary = node.get_meta("kit").duplicate(true)
	for key in result:
		if result[key] is NodePath: result[key] = node.get_node(result[key])
	return result
