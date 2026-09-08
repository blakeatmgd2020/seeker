extends SceneTree
## One windowed run: photograph each NEW biome at eye level near spawn.

const IDS := ["mountain", "riverlands", "cavern", "swamp", "ashlands", "dunes", "moor"]
var _frames := 0
var _idx := -1
var _cam: Camera3D = null


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var main = root.get_node("Main")
	if _idx == -1:
		main.feedback.enabled = false
		main.start_daily()
		_cam = Camera3D.new()
		_cam.far = 1200.0
		root.add_child(_cam)
		_idx = 0
		_frames = 6
	# Give each world ~35 frames to settle, then shoot and advance.
	var stride := 40
	var step := (_frames - 6) % stride
	if step == 0:
		var id: String = IDS[_idx]
		main.debug_biome = id
		main.load_day(0)
		main.day_phase = 0.3
		main._update_daylight(0.0)
		var pp: Vector3 = main.player.global_position
		_cam.global_position = pp + Vector3(10, 5, 12)
		_cam.look_at(pp + Vector3(-14, 1, -16))
		_cam.current = true
	elif step == stride - 1:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("HH_SHOT_DIR").path_join("biome_%s.png" % IDS[_idx]))
		_idx += 1
		if _idx >= IDS.size():
			quit(0)
			return true
	return false
