extends SceneTree
## Close-up photos of the Blender kit assets in place: pine+oak (meadow),
## autumn oaks, dead trees (swamp), boulders (moor). Cameras aim at real
## MultiMesh instances so the shots always contain trees.

var _frames := 0
var _step := 0
var _cam: Camera3D = null
const RUNS := [["meadow", "kit_meadow.png"], ["autumn", "kit_autumn.png"],
	["swamp", "kit_swamp.png"], ["moor", "kit_moor.png"]]


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 5:
		return false
	var main = root.get_node("Main")
	if _step == 0:
		main.feedback.enabled = false
		main.start_daily()
		_cam = Camera3D.new()
		root.add_child(_cam)
		_step = 1
		_frames = 5
		return false
	var run := (_step - 1) / 2
	if run >= RUNS.size():
		quit(0)
		return true
	if _step % 2 == 1:
		main.debug_biome = RUNS[run][0]
		main.load_day(0)
		main.day_phase = 0.25
		main._update_daylight(0.0)
		var veg: Node3D = main.world.get_node("Vegetation")
		var target := Vector3.ZERO
		var found := false
		if RUNS[run][0] == "moor":
			# Boulders are MeshInstances under the collider body.
			for ch in veg.get_node("TreeColliders").get_children():
				if ch is MeshInstance3D:
					target = ch.global_position
					found = true
					break
		if not found:
			for ch in veg.get_children():
				if ch is MultiMeshInstance3D and ch.multimesh.instance_count > 0:
					target = ch.multimesh.get_instance_transform(0).origin
					found = true
					break
		_cam.global_position = target + Vector3(7.5, 4.5, 7.5)
		_cam.look_at(target + Vector3(0, 2.6, 0))
		_cam.current = true
		_step += 1
		_frames = 5
		return false
	if _frames > 40:
		root.get_viewport().get_texture().get_image().save_png(
			OS.get_environment("HH_SHOT_DIR").path_join(RUNS[run][1]))
		_step += 1
		_frames = 5
	return false
