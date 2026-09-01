extends SceneTree
## Headless smoke test:
##   Godot_console.exe --headless --path . -s tests/smoke.gd
## Verifies daily world generation (determinism per day, rebuild on day
## travel), the 20 structures, tag reveal, targeting, and menu-driven rehide.

var _frames := 0


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		print("FAIL: cannot load main scene")
		quit(1)
		return
	root.add_child(scene.instantiate())


func _holders(main) -> int:
	var n := 0
	for s in main.structures:
		if s.has_item:
			n += 1
	return n


func _holder_idx(main) -> int:
	for i in main.structures.size():
		if main.structures[i].has_item:
			return i
	return -1


func hud_map_missing(main) -> bool:
	return main.hud.map_overlay == null or main.hud.map_overlay.map_tex == null


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var fails: Array[String] = []
	var main = root.get_node_or_null("Main")
	if main == null or main.get_script() == null:
		print("FAIL: Main node missing or script failed to compile")
		quit(1)
		return true
	# The game boots to the title screen; enter Daily mode for the suite.
	if main.world == null:
		if main.title == null or not main.title.visible:
			fails.append("title screen not shown at boot")
		main.start_daily()
	if main.world == null:
		print("FAIL: start_daily did not build a world")
		quit(1)
		return true

	if main.structures.size() != 20:
		fails.append("expected 20 structures, got %d" % main.structures.size())
	if _holders(main) != 1:
		fails.append("expected exactly 1 holder, got %d" % _holders(main))
	if main.tag_number.length() != 4 or not main.tag_number.is_valid_int():
		fails.append("tag number malformed: '%s'" % main.tag_number)
	if main.world == null or main.world.get_node_or_null("Village") == null:
		fails.append("village missing")
	if main.terrain == null or main.terrain.water_y <= -50.0:
		fails.append("terrain/water not built")
	if main.menu == null:
		fails.append("menu missing")

	# Determinism: reloading the same day gives the same holder and number.
	var idx0 := _holder_idx(main)
	var num0: String = main.tag_number
	main.load_day(0)
	if _holder_idx(main) != idx0 or main.tag_number != num0:
		fails.append("day 0 not deterministic across reloads")

	# Day travel rebuilds a valid world.
	main.load_day(3)
	if main.structures.size() != 20:
		fails.append("day 3: expected 20 structures, got %d" % main.structures.size())
	if _holders(main) != 1:
		fails.append("day 3: expected 1 holder, got %d" % _holders(main))

	# Tools: exactly 6 distinct tools hidden, never in the tag's structure.
	var tool_ids: Array = []
	for s in main.structures:
		if not s.tool_id.is_empty():
			tool_ids.append(s.tool_id)
			if s.has_item:
				fails.append("tool '%s' shares the tag's structure" % s.tool_id)
	tool_ids.sort()
	if tool_ids != ["compass", "eraser", "map", "notepad", "pencil", "spyglass"]:
		fails.append("tool spots wrong: %s" % str(tool_ids))
	for id in main.tools:
		if main.tools[id]:
			fails.append("tool '%s' should start uncollected" % id)
	if hud_map_missing(main):
		fails.append("minimap texture not generated")

	# Collecting a tool via search.
	var tool_s: Interactable = null
	for s in main.structures:
		if not s.tool_id.is_empty():
			tool_s = s
			break
	var tid: String = tool_s.tool_id
	tool_s.interact()
	if not main.tools[tid]:
		fails.append("tool '%s' not collected on search" % tid)
	if not tool_s.tool_id.is_empty():
		fails.append("tool_id not cleared after collection")

	# Interact: empty structure opens; holder reveals the tag.
	var item_s: Interactable = null
	var empty_s: Interactable = null
	for s in main.structures:
		if s.has_item:
			item_s = s
		elif empty_s == null and s.tool_id.is_empty() and not s.opened:
			empty_s = s
	# Spotting: add to list, then searching removes it.
	main.add_spot(empty_s)
	if main.spotted.size() != 1 or main.selected_spot() != empty_s:
		fails.append("add_spot did not register")
	main.cycle_spot()
	if main.selected_spot() != empty_s:
		fails.append("cycle_spot broke on single entry")
	empty_s.interact()
	if not empty_s.opened:
		fails.append("empty structure did not open")
	if not main.spotted.is_empty() or empty_s.spotted:
		fails.append("searching a spotted node did not clear it")

	# Trail record + erase.
	main.record_trail(Vector2(0, 0))
	main.record_trail(Vector2(5, 0))
	if main.trail.size() < 2:
		fails.append("trail did not record")
	main.erase_trail_near(Vector2(2.5, 0), 10.0)
	if not main.trail.is_empty():
		fails.append("erase_trail_near did not erase")
	item_s.interact()
	if item_s._item_holder == null:
		fails.append("tag not revealed")
	else:
		var label_ok := false
		for c in item_s._item_holder.get_children():
			if c is Label3D and c.text == main.tag_number:
				label_ok = true
		if not label_ok:
			fails.append("tag label missing or mismatched")
	if main.searched_count != 3:
		fails.append("searched count expected 3, got %d" % main.searched_count)

	# Targeting ring.
	var p = main.player
	p.set_target(empty_s)
	if p.target != empty_s:
		fails.append("set_target did not take")
	if empty_s._ring == null:
		fails.append("selection ring missing")
	p.set_target(null)
	if empty_s._ring != null:
		fails.append("selection ring not cleared")

	# Menu-driven rehide: closes everything, advances the round, new holder.
	var prev_round: int = main.round_num
	main.rehide_tag()
	if main.round_num != prev_round + 1:
		fails.append("round did not advance")
	if _holders(main) != 1:
		fails.append("after rehide expected 1 holder, got %d" % _holders(main))
	for s in main.structures:
		if s.opened:
			fails.append("structure still open after rehide")
			break
	# Collected tools persist across rounds; the tag avoids unfound tools.
	if not main.tools[tid]:
		fails.append("collected tool lost on rehide")
	var uncollected := 0
	for s in main.structures:
		if not s.tool_id.is_empty():
			uncollected += 1
			if s.has_item:
				fails.append("rehidden tag landed on an unfound tool")
	if uncollected != 5:
		fails.append("expected 5 unfound tools after collecting 1, got %d" % uncollected)

	# New day resets the toolkit.
	main.load_day(1)
	for id in main.tools:
		if main.tools[id]:
			fails.append("tool '%s' not reset on day change" % id)
	if not main.trail.is_empty() or not main.spotted.is_empty():
		fails.append("trail/spots not reset on day change")
	var fresh := 0
	for s in main.structures:
		if not s.tool_id.is_empty():
			fresh += 1
	if fresh != 6:
		fails.append("day change should hide 6 fresh tools, got %d" % fresh)

	# Random mode: deterministic per seed, distinct seeds build fine.
	main.start_random(12345)
	if main.game_mode != "random" or main.structures.size() != 20:
		fails.append("random mode did not build 20 structures")
	var rh := _holder_idx(main)
	var rn: String = main.tag_number
	main.start_random(12345)
	if _holder_idx(main) != rh or main.tag_number != rn:
		fails.append("random seed 12345 not deterministic")
	main.start_random(999)
	if main.structures.size() != 20:
		fails.append("random seed 999 did not build")
	main.start_daily()
	if main.game_mode != "daily":
		fails.append("start_daily did not restore daily mode")

	# Feedback: note + summary land in the session report file.
	main.feedback.add_note("bug", "smoke test note")
	main.feedback.write_summary()
	var fa := FileAccess.open(main.feedback._file_abs, FileAccess.READ)
	if fa == null:
		fails.append("feedback report file missing")
	else:
		var ftxt := fa.get_as_text()
		fa.close()
		if ftxt.find("smoke test note") == -1 or ftxt.find("Session summary") == -1:
			fails.append("feedback report missing note or summary")
		DirAccess.remove_absolute(main.feedback._file_abs)

	# Every biome must generate a valid world (20 structures, 1 tag, 3 tools,
	# a weather roll, and a village).
	for b in Biomes.all_ids():
		main.debug_biome = b
		main.load_day(0)
		if main.biome.id != b:
			fails.append("biome override '%s' not applied" % b)
			continue
		if main.structures.size() != 20:
			fails.append("%s: expected 20 structures, got %d" % [b, main.structures.size()])
		if _holders(main) != 1:
			fails.append("%s: holders != 1" % b)
		var btools := 0
		for s in main.structures:
			if not s.tool_id.is_empty():
				btools += 1
		if btools != 6:
			fails.append("%s: expected 6 tools, got %d" % [b, btools])
		if main.weather_name.is_empty():
			fails.append("%s: no weather rolled" % b)
		if main.world.get_node_or_null("Village") == null:
			fails.append("%s: village missing" % b)
	main.debug_biome = ""

	if fails.is_empty():
		print("SMOKE PASS (daily worldgen, determinism, 4 biomes, weather, targeting, menu rehide OK)")
		quit(0)
	else:
		for f in fails:
			print("FAIL: " + f)
		quit(1)
	return true
