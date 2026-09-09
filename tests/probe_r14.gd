extends SceneTree
## r14 verification photos: house interiors (per variant layouts and
## kitchens), and the well bottom in daylight with the flashlight on.

var _frames := 0
var _step := 0
var _cam: Camera3D = null
var _shots: Array = []


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 6:
		return false
	var main = root.get_node("Main")
	if _step == 0:
		main.feedback.enabled = false
		main.start_daily()
		_cam = Camera3D.new()
		root.add_child(_cam)
		# Photograph three house interiors — all from ONE world (an earlier
		# world's node paths dangle once the next seed loads).
		for sv in [3, 4, 5, 6, 7, 8]:
			main.start_random(sv)
			var found: Array = []
			for ch in main.world.get_node("Village").get_children():
				if String(ch.name).contains("House"):
					found.append(ch.get_path())
			if found.size() >= 3:
				_shots = found.slice(0, 3)
				break
		_step = 1
		# Next _process call must land on phase 0 of stride 0.
		_frames = 5
		return false
	var stride := 30
	var stepi := (_frames - 6) / stride
	var phase := (_frames - 6) % stride
	if _step == 1:
		if stepi < _shots.size():
			if phase == 0:
				var hb: Node3D = root.get_node(_shots[stepi])
				main.day_phase = 0.3
				main._update_daylight(0.0)
				_cam.global_position = hb.global_transform * Vector3(-1.8, 2.3, 2.3)
				var aim: Vector3 = hb.global_transform * Vector3(1.6, 0.9, -1.2)
				_cam.look_at(aim)
				_cam.current = true
			elif phase == stride - 1:
				root.get_viewport().get_texture().get_image().save_png(
					OS.get_environment("HH_SHOT_DIR").path_join("interior_%d.png" % stepi))
			return false
		# Then: the well bottom, player down there with the flashlight lit.
		var dr: Dictionary = {}
		for sv in [11, 22, 33, 44]:
			main.start_random(sv)
			if not main.well_drops.is_empty():
				dr = main.well_drops[0]
				break
		if dr.is_empty():
			quit(1)
			return true
		main.day_phase = 0.3
		main._update_daylight(0.0)
		main.tools.flashlight = true
		var pl = main.player
		pl.global_position = Vector3(dr.axis.x - 0.9, dr.floor_y + 0.6, dr.axis.z - 0.9)
		pl.velocity = Vector3.ZERO
		pl.flashlight.visible = true
		_cam.global_position = Vector3(dr.axis.x + 2.0, dr.floor_y + 1.6, dr.axis.z + 2.0)
		_cam.look_at(Vector3(dr.axis.x - 1.2, dr.floor_y + 0.8, dr.axis.z - 1.2))
		_step = 2
		_frames = 6
		return false
	if _frames > 40:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("HH_SHOT_DIR").path_join("well_bottom.png"))
		quit(0)
		return true
	return false
