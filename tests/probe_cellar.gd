extends SceneTree
## Diagnose the smoke cellar-walk fixture: which building, where does the
## player end up frame by frame.

var _frames := 0
var _barn: Node3D = null


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	var main = root.get_node("Main")
	if _frames == 5:
		main.feedback.enabled = false
		main.start_daily()
		for sv in [11, 22, 33, 44, 55, 66, 77, 88, 5, 17, 29, 41]:
			main.start_random(sv)
			var crate = null
			for s in main.structures:
				if s.display_name == "cellar crate":
					crate = s
			if crate == null:
				continue
			var bestd := 12.0
			for ch in main.world.get_node("Village").get_children():
				if String(ch.name).contains("Barn") or String(ch.name).contains("House"):
					var dch: float = ch.global_position.distance_to(crate.global_position)
					if dch < bestd:
						bestd = dch
						_barn = ch
			if _barn:
				print("fixture: seed %d node %s at %s (crate d %.1f)" % [
					sv, _barn.name, str(_barn.global_position), bestd])
				break
		var pl = main.player
		pl.global_position = _barn.global_transform * Vector3(-3.2, 0.7, 0.0)
		pl.velocity = Vector3.ZERO
		var dirw: Vector3 = _barn.global_transform.basis * Vector3(1, 0, 0)
		pl.set_facing(atan2(-dirw.x, -dirw.z))
		Input.action_press("move_forward")
		return false
	if _frames % 50 == 0:
		var lp: Vector3 = _barn.to_local(main.player.global_position)
		print("f%d lp=(%.2f, %.2f, %.2f) floor=%s" % [
			_frames, lp.x, lp.y, lp.z, main.player.is_on_floor()])
	if _frames >= 360:
		Input.action_release("move_forward")
		quit(0)
		return true
	return false
