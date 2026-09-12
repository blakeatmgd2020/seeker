extends SceneTree
## Photograph the r18 wide well mouth from above.

var _frames := 0
var _dr: Dictionary = {}


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
		for sv in [11, 22, 33, 44]:
			main.start_random(sv)
			if not main.well_drops.is_empty():
				_dr = main.well_drops[0]
				break
		main.day_phase = 0.3
		main._update_daylight(0.0)
		# Rope owned: covers off, mouth open.
		for dr in main.well_drops:
			dr.rope.visible = true
			dr.cover.visible = false
			dr.cover_shape.set_deferred("disabled", true)
		var cam := Camera3D.new()
		root.add_child(cam)
		cam.global_position = _dr.axis + Vector3(4.6, 6.0, -4.6)
		cam.look_at(_dr.axis + Vector3(0, 0.8, 0))
		cam.current = true
		return false
	if _frames > 40:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("HH_SHOT_DIR").path_join("well_mouth.png"))
		quit(0)
		return true
	return false
