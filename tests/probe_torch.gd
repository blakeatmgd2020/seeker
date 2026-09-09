extends SceneTree
## Aim a camera at the nearest Undervault torch to verify the volumetric halo.

var _frames := 0


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 6:
		var main = root.get_node("Main")
		main.feedback.enabled = false
		main.debug_biome = "cavern"
		main.start_daily()
	if _frames == 50:
		var main = root.get_node("Main")
		var torches: Node3D = main.world.get_node("Torches")
		var pp: Vector3 = main.player.global_position
		var best: Node3D = null
		var bd := 1e9
		for t in torches.get_children():
			var d: float = t.global_position.distance_to(pp)
			if d < bd:
				bd = d
				best = t
		var cam := Camera3D.new()
		root.add_child(cam)
		var tp: Vector3 = best.global_position + Vector3(0, 1.8, 0)
		var away := (tp - pp).normalized()
		cam.global_position = tp - away * 9.0 + Vector3(0, 0.4, 0)
		cam.look_at(tp)
		cam.current = true
	if _frames == 95:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("HH_SHOT_DIR").path_join("torch_beam.png"))
		quit(0)
		return true
	return false
