extends SceneTree
## Headless smoke test:
##   Godot_console.exe --headless --path . -s tests/smoke.gd
## Verifies daily/random world generation, determinism, the 20-structure
## budget, the 7 hidden tools, great-tree nests, spotting, the win
## condition (open all 20), and the feedback report pipeline.

var _frames := 0
var _stage := 0
var _walk_frames := 0
var _walk_house: Node3D = null
var _cave_body: Node3D = null
var _cave_phase := 0
var _well_drop: Dictionary = {}
var _well_phase := 0
var _fails: Array[String] = []


func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		print("FAIL: cannot load main scene")
		quit(1)
		return
	root.add_child(scene.instantiate())


## World signature for determinism checks: kinds, tool spots, positions.
func _sig(main) -> String:
	var s := ""
	for st in main.structures:
		s += "%s:%s:%d,%d;" % [st.kind, st.tool_id,
			int(st.position.x), int(st.position.z)]
	return s + str(main.terrain.village_centers)


func _tool_count(main) -> int:
	var n := 0
	for s in main.structures:
		if not s.tool_id.is_empty():
			n += 1
	return n


## Items are conditional on world features: 7 base, +irons with nests,
## +rope with a cavern well.
func _expected_items(main) -> int:
	var n := 7
	for s in main.structures:
		if s.kind == "nest":
			n += 1
			break
	if not main.well_drops.is_empty():
		n += 1
	return n


func _nest_check(main, fails: Array[String], tagp: String) -> void:
	var nests := 0
	for s in main.structures:
		if s.kind == "nest":
			nests += 1
			var ground: float = main.terrain.height_at(s.position.x, s.position.z)
			if s.position.y - ground < 8.0:
				fails.append(tagp + "nest not high above terrain")
	if nests != 2 and nests != 0:
		fails.append(tagp + "expected 0 or 2 nests, got %d" % nests)
	var irons_climbs := 0
	for c in main.climbables:
		if not c.get("free", false):
			irons_climbs += 1
	if irons_climbs != nests:
		fails.append(tagp + "irons climbables (%d) != nests (%d)" % [irons_climbs, nests])


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 4:
		return false
	var main = root.get_node_or_null("Main")
	if _stage == 1:
		return _walk_test_tick(main)
	if _stage == 2:
		return _cave_test_tick(main)
	if _stage == 3:
		return _cellar_test_tick(main)
	if _stage == 4:
		return _well_test_tick(main)
	var fails := _fails
	if main == null or main.get_script() == null:
		print("FAIL: Main node missing or script failed to compile")
		quit(1)
		return true
	if main.world == null:
		if main.title == null or not main.title.visible:
			fails.append("title screen not shown at boot")
		# Test runs must not leave feedback reports behind; writing is
		# re-enabled only for the feedback-pipeline check below.
		main.feedback.enabled = false
		main.start_daily()
	if main.world == null:
		print("FAIL: start_daily did not build a world")
		quit(1)
		return true

	if main.structures.size() < 20 or main.structures.size() > 32:
		fails.append("expected 20-32 structures, got %d" % main.structures.size())
	if main.world.get_node_or_null("Village") == null:
		fails.append("village root missing")
	# Underground nodes (cellar/cave/well) must actually be below the terrain.
	for s in main.structures:
		if s.display_name in ["cellar crate", "cave chest", "stashed crate", "buried urn", "well cache"]:
			var gh: float = main.terrain.height_at(s.position.x, s.position.z)
			if s.position.y > gh - 1.5:
				fails.append("underground node '%s' not below terrain" % s.display_name)
		if s.tool_id == "flashlight" \
				and s.position.y < main.terrain.height_at(s.position.x, s.position.z) - 1.5:
			fails.append("flashlight hidden in an underground node")
	if main.terrain == null or main.terrain.water_y <= -50.0:
		fails.append("terrain/water not built")
	if main.menu == null:
		fails.append("menu missing")

	# Items hidden in distinct structures — the set is conditional on what
	# the world holds.
	var tool_ids: Array = []
	for s in main.structures:
		if not s.tool_id.is_empty():
			tool_ids.append(s.tool_id)
	tool_ids.sort()
	var expect := ["coffee", "compass", "flashlight", "map", "notepad", "pencil", "spyglass"]
	var has_nest := false
	for s in main.structures:
		has_nest = has_nest or s.kind == "nest"
	if has_nest:
		expect.append("irons")
	if not main.well_drops.is_empty():
		expect.append("rope")
	expect.sort()
	if tool_ids != expect:
		fails.append("tool spots wrong: %s vs expected %s" % [str(tool_ids), str(expect)])
	for id in main.tools:
		if main.tools[id]:
			fails.append("tool '%s' should start uncollected" % id)
	if hud_map_missing(main):
		fails.append("minimap texture not generated")
	_nest_check(main, fails, "daily: ")

	# Determinism: same day rebuilds the same world.
	var sig0 := _sig(main)
	main.load_day(0)
	if _sig(main) != sig0:
		fails.append("day 0 not deterministic across reloads")

	# Day travel rebuilds a valid world.
	main.load_day(3)
	if main.structures.size() < 20 or main.structures.size() > 32:
		fails.append("day 3: expected 20-32 structures, got %d" % main.structures.size())

	# Collecting a tool via search.
	var tool_s: Interactable = null
	for s in main.structures:
		if not s.tool_id.is_empty() and s.tool_id != "coffee":
			tool_s = s
			break
	var tid: String = tool_s.tool_id
	tool_s.interact()
	if not main.tools[tid]:
		fails.append("tool '%s' not collected on search" % tid)
	var uncollected := _tool_count(main)
	if uncollected != _expected_items(main) - 1:
		fails.append("expected %d unfound items after collecting 1, got %d" % [
			_expected_items(main) - 1, uncollected])

	# Coffee: find it, drink it, buff runs.
	var coffee_s: Interactable = null
	for s in main.structures:
		if s.tool_id == "coffee":
			coffee_s = s
			break
	coffee_s.interact()
	if not main.has_coffee:
		fails.append("coffee not collected on search")
	main.drink_coffee()
	if main.has_coffee or not main.coffee_active() or main.coffee_remaining() < 110:
		fails.append("coffee buff did not activate correctly")

	# Spotting: add to list, then searching removes it.
	var empty_s: Interactable = null
	for s in main.structures:
		if s.tool_id.is_empty() and not s.opened and s.kind != "nest":
			empty_s = s
			break
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

	# Targeting ring.
	var ring_s: Interactable = main.structures[0]
	var p = main.player
	p.set_target(ring_s)
	if p.target != ring_s or ring_s._ring == null:
		fails.append("selection ring missing")
	p.set_target(null)
	if ring_s._ring != null:
		fails.append("selection ring not cleared")

	# Win condition: opening every structure completes the hunt.
	for s in main.structures:
		if not s.opened:
			s.interact()
	if main.searched_count != main.structures.size():
		fails.append("searched count expected %d, got %d" % [
			main.structures.size(), main.searched_count])
	if not main.hunt_won:
		fails.append("hunt_won not set after opening all structures")
	if not main.hud.big_map.visible:
		fails.append("victory recap map did not open on win")

	# New day resets everything.
	main.load_day(1)
	for id in main.tools:
		if main.tools[id]:
			fails.append("tool '%s' not reset on day change" % id)
	if not main.trail.is_empty() or not main.spotted.is_empty() or main.hunt_won:
		fails.append("state not reset on day change")
	if main.has_coffee or main.coffee_active():
		fails.append("coffee not reset on day change")
	if _tool_count(main) != _expected_items(main):
		fails.append("day change should hide %d fresh items, got %d" % [
			_expected_items(main), _tool_count(main)])

	# Feedback round 3: arrow-turn actions, Dev Note button, birds, winded UI.
	if not (InputMap.has_action("turn_left") and InputMap.has_action("turn_right")):
		fails.append("arrow-turn input actions missing")
	var dev_btn := false
	for ch in main.feedback.get_children():
		if ch is Button and ch.text == "Dev Note":
			dev_btn = ch.visible
	if not dev_btn:
		fails.append("Dev Note button missing or hidden")
	var nestn := 0
	for s in main.structures:
		if s.kind == "nest":
			nestn += 1
	var birds = main.world.get_node_or_null("Birds")
	if nestn >= 2:
		if birds == null or birds.get_child_count() < 3:
			fails.append("birds missing from a world with nests")
	elif birds != null:
		fails.append("birds present in a nestless world")
	if birds != null:
		for sp2 in birds.spots:
			if not (sp2 is Vector3):
				fails.append("bird loiter perch is not a Vector3: %s" % str(sp2))
				break
	main.hud.set_stamina(0.2, true, 42.0)
	if not main.hud.winded_label.visible \
			or main.hud.winded_label.text.find("Winded") == -1:
		fails.append("winded countdown label not shown")
	if main.hud.stam_fill.size.x > 180.0 * 0.5:
		fails.append("winded bar should refill from lock progress, not stamina")
	main.hud.set_stamina(1.0, false)
	if main.hud.winded_label.visible:
		fails.append("winded label did not clear")

	# Feedback rounds 4-5: crouch/sit/autorun actions, ice helper, crouch
	# and sit toggles, and the not-retroactive pencil-marking rule.
	if not (InputMap.has_action("crouch") and InputMap.has_action("autorun") \
			and InputMap.has_action("sit")):
		fails.append("crouch/sit/autorun input actions missing")
	main.player.toggle_sit()
	if not main.player.sitting:
		fails.append("sit did not engage")
	main.player.toggle_sit()
	if main.player.sitting:
		fails.append("sit did not release")
	main.player.set_crouch(true)
	if not main.player.crouched:
		fails.append("crouch did not engage")
	main.player.set_crouch(false)
	if main.player.crouched:
		fails.append("crouch did not release in open air")
	if main.on_ice(Vector3(0, 500.0, 0)):
		fails.append("on_ice true far above any pond")
	var ns: Interactable = null
	for s in main.structures:
		if s.tool_id.is_empty() and s.kind != "nest" and not s.opened:
			ns = s
			break
	main.player.global_position = ns.global_position + Vector3(3, 1, 0)
	main.player._update_discovery(false)
	if not ns.seen:
		fails.append("proximity discovery broke")
	if ns.noted:
		fails.append("node noted without pencil+surface")
	main.tools.pencil = true
	main.tools.map = true
	main.player._update_discovery(false)
	if not ns.noted:
		fails.append("node not noted on re-sight with pencil+map")
	main.tools.pencil = false
	main.tools.map = false

	# Menu action: End current map reveals the recap without finishing.
	main.end_current_map()
	if not main.hunt_won or not main.hud.big_map.visible:
		fails.append("End current map did not open the recap")
	main.hud.close_big_views()
	main.hud.hide_banner()

	# Day/night: the cycle advances, wraps, and drives the lights; the
	# flashlight toggles once owned.
	if not InputMap.has_action("flashlight"):
		fails.append("flashlight input action missing")
	if main.player.flashlight == null:
		fails.append("flashlight light missing on player")
	var p0: float = main.day_phase
	main._update_daylight(30.0)
	if absf(main.day_phase - wrapf(p0 + 30.0 / 900.0, 0.0, 1.0)) > 0.001:
		fails.append("day phase did not advance correctly")
	main.day_phase = 0.99
	main._update_daylight(30.0)
	if main.day_phase >= 1.0 or main.day_phase > 0.1:
		fails.append("day phase did not wrap at 1.0")
	main.day_phase = 0.85
	main._update_daylight(0.01)
	if main._sun.visible:
		fails.append("sun still shining at midnight")
	main.day_phase = 0.3
	main._update_daylight(0.01)
	if not main._sun.visible:
		fails.append("sun missing at midday")

	# Random mode: deterministic per seed.
	main.start_random(12345)
	if main.game_mode != "random" or main.structures.size() < 20:
		fails.append("random mode did not build structures")
	var rsig := _sig(main)
	main.start_random(12345)
	if _sig(main) != rsig:
		fails.append("random seed 12345 not deterministic")
	main.start_random(999)
	if main.structures.size() < 20:
		fails.append("random seed 999 did not build")
	# Caves, cellars, and cavern wells: each must show up within a handful
	# of seeds, with their nodes genuinely underground.
	var cave_found := false
	var cellar_found := false
	var well_found := false
	for sv in [11, 22, 33, 44, 55, 66, 77, 88, 5, 17, 29, 41]:
		main.start_random(sv)
		if not main.well_drops.is_empty() and not well_found:
			well_found = true
			# Collecting the rope the real way must open the plank covers.
			for s in main.structures:
				if s.tool_id == "rope":
					s.interact()
					break
			if not main.tools.rope or main.well_drops[0].cover.visible:
				fails.append("collecting the rope did not open the well covers")
		for s in main.structures:
			if s.tool_id == "flashlight" \
					and s.position.y < main.terrain.height_at(s.position.x, s.position.z) - 1.5:
				fails.append("seed %d: flashlight hidden underground" % sv)
		for s in main.structures:
			if s.display_name in ["cave chest", "stashed crate", "buried urn", "cellar crate", "well cache"]:
				var gh: float = main.terrain.height_at(s.position.x, s.position.z)
				if s.position.y > gh - 1.5:
					fails.append("seed %d: underground node '%s' not below terrain" % [sv, s.display_name])
				if s.display_name == "cellar crate":
					cellar_found = true
				elif s.display_name != "well cache":
					cave_found = true
		if cave_found and cellar_found and well_found:
			break
	if not cave_found:
		fails.append("no cave generated across 12 seeds")
	if not cellar_found:
		fails.append("no cellar crate generated across 12 seeds")
	if not well_found:
		fails.append("no cavern well generated across 12 seeds")

	# Building variety: upstairs wardrobes and roof ladders must both occur.
	var upstairs_found := false
	var ladder_found := false
	for sv in range(100, 160):
		main.start_random(sv)
		for c in main.climbables:
			if c.get("free", false):
				ladder_found = true
		for s in main.structures:
			if s.kind == "wardrobe" \
					and s.position.y - main.terrain.height_at(s.position.x, s.position.z) > 2.5:
				upstairs_found = true
		if upstairs_found and ladder_found:
			break
	if not upstairs_found:
		fails.append("no upstairs wardrobe generated across 60 seeds")
	if not ladder_found:
		fails.append("no roof ladder generated across 60 seeds")

	main.start_daily()
	if main.game_mode != "daily":
		fails.append("start_daily did not restore daily mode")

	# Feedback: note + summary land in the session report file. Writing is
	# enabled just for this check, then the file is removed and writing
	# stays off so later world loads can't recreate it.
	main.feedback.enabled = true
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
	main.feedback.enabled = false

	# Every biome must generate a valid world.
	for b in Biomes.all_ids():
		main.debug_biome = b
		main.load_day(0)
		if main.biome.id != b:
			fails.append("biome override '%s' not applied" % b)
			continue
		if main.structures.size() < 20 or main.structures.size() > 32:
			fails.append("%s: expected 20-32 structures, got %d" % [b, main.structures.size()])
		if _tool_count(main) != _expected_items(main):
			fails.append("%s: expected %d hidden items, got %d" % [b,
				_expected_items(main), _tool_count(main)])
		if main.weather_name.is_empty():
			fails.append("%s: no weather rolled" % b)
		if main.world.get_node_or_null("Village") == null:
			fails.append("%s: village missing" % b)
		_nest_check(main, fails, b + ": ")
	main.debug_biome = ""

	# Physically walk the player up the entry ramp into a house (worlds can
	# have zero houses now, so hunt seeds until one appears).
	_walk_house = null
	for sv in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		main.start_random(sv)
		_walk_house = main.world.get_node("Village").get_node_or_null("House")
		if _walk_house:
			break
	if _walk_house == null:
		fails.append("no house found across 10 seeds for walk-in test")
		return _finish(fails)
	var pl = main.player
	pl.global_position = _walk_house.global_transform * Vector3(0, 0.2, 5.5)
	pl.velocity = Vector3.ZERO
	var dirw: Vector3 = _walk_house.global_transform.basis * Vector3(0, 0, -1)
	pl.set_facing(atan2(-dirw.x, -dirw.z))
	Input.action_press("move_forward")
	_stage = 1
	_walk_frames = 0
	return false


func _walk_test_tick(main) -> bool:
	_walk_frames += 1
	if _walk_frames < 150:
		return false
	Input.action_release("move_forward")
	var lp: Vector3 = _walk_house.to_local(main.player.global_position)
	# Standing on the floor counts; so does having descended into the
	# house's own cellar stairwell (also proof of entry).
	if lp.z > 2.6 or (lp.y < 0.35 and lp.y > -1.0):
		_fails.append("player could not walk into the house (local z=%.2f y=%.2f)" % [lp.z, lp.y])
	# Next: walk down into a cave through its arch.
	_cave_body = null
	for sv in [11, 22, 33, 44, 55, 66, 77, 88]:
		main.start_random(sv)
		_cave_body = main.world.get_node_or_null("Cave")
		if _cave_body:
			break
	if _cave_body == null:
		_fails.append("no cave found for walk-in test")
		return _finish(_fails)
	var pl = main.player
	pl.global_position = _cave_body.global_transform * Vector3(0, 0.5, 5.0)
	pl.velocity = Vector3.ZERO
	var dirw: Vector3 = _cave_body.global_transform.basis * Vector3(0, 0, -1)
	pl.set_facing(atan2(-dirw.x, -dirw.z))
	Input.action_press("move_forward")
	_stage = 2
	_walk_frames = 0
	return false


func _cave_test_tick(main) -> bool:
	_walk_frames += 1
	if _cave_phase == 0:
		if _walk_frames < 260:
			return false
		Input.action_release("move_forward")
		var depth: float = main.player.global_position.y - _cave_body.global_position.y
		if depth > -3.0:
			_fails.append("player could not descend into the cave (depth %.2f)" % depth)
		# Now walk back OUT — standing, no jumping allowed.
		var pl0 = main.player
		var outw: Vector3 = _cave_body.global_transform.basis * Vector3(0, 0, 1)
		pl0.set_facing(atan2(-outw.x, -outw.z))
		pl0.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		_cave_phase = 1
		_walk_frames = 0
		return false
	if _walk_frames < 420:
		return false
	Input.action_release("move_forward")
	var exdepth: float = main.player.global_position.y - _cave_body.global_position.y
	if exdepth < -0.6:
		_fails.append("player could not walk OUT of the cave (depth %.2f)" % exdepth)
	# Finally: walk down a cellar stairwell (barn or house).
	var barn: Node3D = null
	for sv in [11, 22, 33, 44, 55, 66, 77, 88, 5, 17, 29, 41]:
		main.start_random(sv)
		var crate: Interactable = null
		for s in main.structures:
			if s.display_name == "cellar crate":
				crate = s
		if crate == null:
			continue
		var village: Node3D = main.world.get_node("Village")
		var bestd := 12.0
		for ch in village.get_children():
			if String(ch.name).contains("Barn") or String(ch.name).contains("House"):
				var dch: float = ch.global_position.distance_to(crate.global_position)
				if dch < bestd:
					bestd = dch
					barn = ch
		if barn:
			break
	if barn == null:
		_fails.append("no cellar building found for walk-in test")
		return _finish(_fails)
	# Start on the floor west of the stairwell mouth and walk east — down
	# the full stair, standing, with no jumping allowed.
	var pl = main.player
	pl.global_position = barn.global_transform * Vector3(-3.2, 0.7, 0.0)
	pl.velocity = Vector3.ZERO
	var dirw: Vector3 = barn.global_transform.basis * Vector3(1, 0, 0)
	pl.set_facing(atan2(-dirw.x, -dirw.z))
	Input.action_press("move_forward")
	_walk_house = barn
	_stage = 3
	_walk_frames = 0
	return false


func _cellar_test_tick(main) -> bool:
	_walk_frames += 1
	if _walk_frames < 200:
		return false
	Input.action_release("move_forward")
	var depth: float = main.player.global_position.y - _walk_house.global_position.y
	if depth > -2.0:
		_fails.append("player could not descend into the cellar (depth %.2f)" % depth)
	# Stage 4: rope-descend a cavern well — climb in over the rim with W,
	# let go, and slide the rope to the cavern floor.
	_well_drop = {}
	for sv in [11, 22, 33, 44, 55, 66, 77, 88, 5, 17, 29, 41]:
		main.start_random(sv)
		if not main.well_drops.is_empty():
			_well_drop = main.well_drops[0]
			break
	if _well_drop.is_empty():
		_fails.append("no cavern well found for descent test")
		return _finish(_fails)
	if _well_drop.cover_shape.disabled:
		_fails.append("well cover should start sealed (no rope yet)")
	main.tools.rope = true
	# Owning the rope opens the plank covers in _collect_tool; the test
	# grants the rope directly, so open them the same way here.
	for dr in main.well_drops:
		dr.rope.visible = true
		dr.cover.visible = false
		dr.cover_shape.set_deferred("disabled", true)
	var pl = main.player
	pl.global_position = _well_drop.axis + Vector3(1.55, 0.2, 0.0)
	pl.velocity = Vector3.ZERO
	Input.action_press("move_forward")
	_stage = 4
	_walk_frames = 0
	return false


func _well_test_tick(main) -> bool:
	_walk_frames += 1
	if _well_phase == 0:
		if _walk_frames == 100:
			Input.action_release("move_forward")
		if _walk_frames < 560:
			return false
		var depth: float = main.player.global_position.y - _well_drop.axis.y
		if depth > -4.0:
			_fails.append("player could not rope-descend the well (depth %.2f)" % depth)
			return _finish(_fails)
		# Climb back out on the rope — being trapped down there is exactly
		# the bug this phase exists to catch.
		Input.action_press("move_forward")
		_well_phase = 1
		_walk_frames = 0
		return false
	if _walk_frames < 700:
		return false
	Input.action_release("move_forward")
	var ex: float = main.player.global_position.y - _well_drop.axis.y
	if ex < -1.0:
		_fails.append("player trapped in the well (rel y %.2f)" % ex)
	return _finish(_fails)


func _finish(fails: Array[String]) -> bool:
	if fails.is_empty():
		print("SMOKE PASS (modes, determinism, 4 biomes, 8 items, nests, win+recap, walk-ins incl. well, feedback OK)")
		quit(0)
	else:
		for f in fails:
			print("FAIL: " + f)
		quit(1)
	return true


func hud_map_missing(main) -> bool:
	return main.hud.map_overlay == null or main.hud.map_overlay.map_tex == null
