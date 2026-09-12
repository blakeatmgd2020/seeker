extends SceneTree
## Diagnostics for the grapple wall climb: reproduce smoke stage 5 and
## print every gate the climb depends on.

var _frames := 0
var _house: Node3D = null


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
		for sv in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
			main.start_random(sv)
			for ch in main.world.get_node("Village").get_children():
				if not String(ch.name).contains("House"):
					continue
				var ap: Vector3 = ch.global_transform * Vector3(6.9, 0.6, 0.0)
				var clear := true
				for dr2 in main.well_drops:
					if Vector2(ap.x - dr2.axis.x, ap.z - dr2.axis.z).length() < 4.5:
						clear = false
						break
				if clear:
					_house = ch
					break
			if _house:
				break
		print("fixture: %s at %s" % [_house.name, str(_house.global_position)])
		main.tools.rope = true
		main.tools.grapple = true
		var pl = main.player
		pl.global_position = _house.global_transform * Vector3(6.9, 0.6, 0.0)
		pl.velocity = Vector3.ZERO
		var dirw: Vector3 = _house.global_transform.basis * Vector3(-1, 0, 0)
		pl.set_facing(atan2(-dirw.x, -dirw.z))
		Input.action_press("move_forward")
		return false
	if _frames % 40 == 0:
		var pl = main.player
		var lp: Vector3 = _house.to_local(pl.global_position)
		var low: Vector3 = pl._grapple_ray(-0.6)
		var mid: Vector3 = pl._grapple_ray(0.6)
		print("f%d lp=(%.2f, %.2f, %.2f) floor=%s climb=%s wall=%s low=%s mid=%s head=%s fgrap=%s wc=%s" % [
			_frames, lp.x, lp.y, lp.z, pl.is_on_floor(), pl.climbing,
			str(pl._near_climbable()), str(low), str(mid),
			pl._headroom_clear(), pl._floor_is_grapple(), pl._wall_climb])
	if _frames >= 400:
		quit(0)
		return true
	return false
