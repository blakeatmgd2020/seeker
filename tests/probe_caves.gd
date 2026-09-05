extends SceneTree
## Diagnostic: where do caves actually generate? Prints each seed's cave
## distance from map center (ridge band is roughly r 188-212).

var _frames := 0


func _initialize() -> void:
	root.add_child((load("res://scenes/main.tscn") as PackedScene).instantiate())


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var main = root.get_node("Main")
	main.feedback.enabled = false
	var ridge := 0
	var interior := 0
	var none := 0
	for sv in range(1, 31):
		main.start_random(sv)
		var cave: Node3D = main.world.get_node_or_null("Cave")
		if cave == null:
			none += 1
			continue
		var e := maxf(absf(cave.global_position.x), absf(cave.global_position.z))
		if e > 218.0:
			ridge += 1
		else:
			interior += 1
		print("seed %d: cave at edge=%.0f (%s)" % [sv,
			e, "RIDGE" if e > 218.0 else "interior"])
	print("TOTALS: %d ridge, %d interior, %d none (of 30 seeds)" % [ridge, interior, none])
	quit(0)
	return true
