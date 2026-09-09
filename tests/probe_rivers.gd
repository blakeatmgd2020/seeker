extends SceneTree
## Phase-3 verification photos: riverlands aerial, ford stones, a village
## bridge, and the Saltwind coast.

var _frames := 0
var _step := 0
var _cam: Camera3D = null


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _shoot(name: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(
		OS.get_environment("HH_SHOT_DIR").path_join(name))


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	var main = root.get_node("Main")
	if _step == 0:
		main.feedback.enabled = false
		main.start_daily()
		main.debug_biome = "riverlands"
		main.load_day(0)
		main.day_phase = 0.3
		main._update_daylight(0.0)
		_cam = Camera3D.new()
		_cam.far = 1400.0
		root.add_child(_cam)
		_cam.global_position = Vector3(0, 330, 60)
		_cam.look_at(Vector3(0, 0, -10))
		_cam.current = true
		_step = 1
		_frames = 5
		return false
	if _step == 1 and _frames > 40:
		_shoot("river_aerial.png")
		# Ford close-up.
		var rv: Dictionary = main.river_data[0]
		var f: Vector2 = rv.ford
		var wy: float = main.terrain.water_y
		_cam.global_position = Vector3(f.x + 11, wy + 7, f.y + 11)
		_cam.look_at(Vector3(f.x, wy, f.y))
		_step = 2
		_frames = 5
		return false
	if _step == 2 and _frames > 40:
		_shoot("river_ford.png")
		# Bridge, if one was built.
		var rw: Node3D = main.world.get_node_or_null("RiverWorks")
		var bridge: Node3D = null
		if rw:
			for ch in rw.get_children():
				if ch is StaticBody3D:
					bridge = ch
		if bridge:
			var bp: Vector3 = bridge.global_position
			_cam.global_position = bp + Vector3(14, 8, 14)
			_cam.look_at(bp)
			_step = 3
		else:
			print("no bridge on this riverlands day")
			_step = 4
		_frames = 5
		return false
	if _step == 3 and _frames > 40:
		_shoot("river_bridge.png")
		_step = 4
		_frames = 5
		return false
	if _step == 4:
		main.debug_biome = "dunes"
		main.load_day(0)
		main.day_phase = 0.3
		main._update_daylight(0.0)
		var s: int = main.sea_sides[0] if not main.sea_sides.is_empty() else 0
		var edge: Vector2 = [Vector2(200, 0), Vector2(-200, 0),
			Vector2(0, 200), Vector2(0, -200)][s]
		_cam.global_position = Vector3(edge.x * 0.4, 120, edge.y * 0.4)
		_cam.look_at(Vector3(edge.x * 1.15, main.terrain.water_y, edge.y * 1.15))
		_cam.current = true
		_step = 5
		_frames = 5
		return false
	if _step == 5 and _frames > 40:
		_shoot("dunes_coast.png")
		quit(0)
		return true
	return false
