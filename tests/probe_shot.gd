extends SceneTree
## One-off: photograph seed 1's ridge cave from the valley approach.

var _frames := 0
var _cam: Camera3D = null


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		var main = root.get_node("Main")
		main.feedback.enabled = false
		main.start_random(1)
		main.day_phase = 0.3
		main._update_daylight(0.0)
		var cave: Node3D = main.world.get_node("Cave")
		_cam = Camera3D.new()
		_cam.far = 1200.0
		root.add_child(_cam)
		var toward: Vector3 = cave.global_position.normalized()
		_cam.global_position = cave.global_position - toward * 26.0 + Vector3(0, 9.0, 0)
		_cam.look_at(cave.global_position + Vector3(0, 2.0, 0))
		_cam.current = true
	if _frames == 40:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("HH_SHOT_DIR").path_join("probe_ridge_cave.png"))
		quit(0)
		return true
	return false
