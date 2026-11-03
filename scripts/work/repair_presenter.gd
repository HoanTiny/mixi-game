extends Node
## Observe committed outcomes instead of duplicating payment/quest rules.
## Initial saves establish a baseline; only new deliveries show the vignette.
var hud
var game
var baseline: Dictionary = {}
var pending: Dictionary = {}
var last_kind := 0

func setup(owner_hud) -> void:
	hud=owner_hud; game=hud.game
	baseline=_facts()
	game.changed.connect(_changed)

func _facts() -> Dictionary:
	return {"fan":game.quest_state("quat_trai_cay")=="done", "kettle":bool(game.s.flags.get("day23_kettle_delivered",false)), "completed":int(game.s.get("street",{}).get("completed",0)), "day":game.day()}

func _changed() -> void:
	var now := _facts()
	var job: Dictionary=game.s.get("street",{}).get("job",{})
	if not job.is_empty(): last_kind=int(job.get("kind",0))
	if int(now.day)>=int(baseline.day):
		if now.fan and not baseline.fan:
			pending={"kind":0,"title":"Chiếc quạt đã về với cô bán hoa quả","line":"“Có gió rồi! Cô đỡ phải vừa bán hàng vừa quạt tay. Cảm ơn cháu, An.”"}
			pending.merge({"customer":"MA","setting":"market"})
		elif now.kettle and not baseline.kettle:
			pending={"kind":1,"title":"Cô hàng nước nhận lại ấm","line":"“Ấm nóng lại rồi. Mai cô có trà mời khách sớm. Cảm ơn An nhé.”"}
			pending["setting"]="market"
			if game.s.get("day23",{}).get("order_late",false): pending.line="“Ấm chạy tốt. Lần sau chậm thì báo cô sớm, để cô còn xoay xở nhé.”"
		elif int(now.completed)>int(baseline.completed):
			pending={"kind":last_kind,"title":"Khách đã nhận lại món sửa","line":"“Để cô mang về dùng. Có người quen cần sửa, cô sẽ chỉ sang tiệm.”"}
	baseline=now

func _process(_delta: float) -> void:
	if pending.is_empty() or not is_instance_valid(hud) or hud.blocking(): return
	var view=preload("res://scripts/work/repair_handover.gd").new()
	view.game=game; view.info=pending.duplicate(); pending.clear()
	hud._bench=view
	hud.add_child(view)
