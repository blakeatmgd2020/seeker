extends Node3D
## Seeker — daily-seeded worlds. The calendar date seeds the biome, terrain,
## village layout, structure placement, spawn point, sky mood, weather, and
## the tag's number; the last 7 days stay playable from the Esc menu.
##
## Build order matters: the village and wild structures are laid out FIRST so
## terraces and foundation cuts can be carved into the heightfield, and only
## then is the terrain mesh built — structures rest in the land, not on it.

const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const STRUCTURE_TOTAL := 20

var terrain: Terrain
var player: Player
var hud: Hud
var menu: GameMenu
var world: Node3D = null
var structures: Array[Interactable] = []
var searched_count := 0
var day_offset := 0
var round_num := 1
var tag_number := ""
var biome: Dictionary = {}
var mood_name := ""
var weather_id := "clear"
var weather_name := "Clear"
var tools := {map = false, compass = false, spyglass = false,
	pencil = false, notepad = false, eraser = false}
var trail: Array[Vector2] = []
var spotted: Array[Interactable] = []
var spot_idx := 0
var debug_biome := ""

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _weather_node: GPUParticles3D = null


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biome="):
			debug_biome = a.substr(8)
	_setup_input()
	_setup_environment()
	player = Player.new()
	add_child(player)
	hud = Hud.new()
	add_child(hud)
	player.hud = hud
	player.main = self
	hud.setup(self)
	menu = GameMenu.new()
	menu.main = self
	add_child(menu)
	load_day(0)
	if OS.get_cmdline_user_args().has("--shot"):
		_shot_routine()


# --- daily seeds ---------------------------------------------------------

func _day_index(offset: int) -> int:
	var local_unix := Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return int(local_unix / 86400) - offset


func _day_seed(offset: int) -> int:
	return (_day_index(offset) * 2654435761) % 2147483647


func day_label(offset: int) -> String:
	var d := Time.get_date_dict_from_unix_time(_day_index(offset) * 86400)
	var s := "%s, %s %d" % [WEEKDAYS[d.weekday], MONTHS[d.month - 1], d.day]
	if offset == 0:
		s += " (today)"
	elif offset == 1:
		s += " (yesterday)"
	return s


# --- world build ---------------------------------------------------------

func load_day(offset: int) -> void:
	day_offset = offset
	round_num = 1
	_build_world()


func _build_world() -> void:
	player.set_target(null)
	if _weather_node and is_instance_valid(_weather_node):
		_weather_node.queue_free()
	_weather_node = null
	if world:
		world.free()
		world = null
	structures.clear()
	searched_count = 0

	var wrng := RandomNumberGenerator.new()
	wrng.seed = _day_seed(day_offset)
	var ids := Biomes.all_ids()
	var biome_id: String = ids[wrng.randi_range(0, ids.size() - 1)]
	if debug_biome != "" and debug_biome in ids:
		biome_id = debug_biome
	biome = Biomes.get_def(biome_id)

	world = Node3D.new()
	world.name = "World"
	add_child(world)
	terrain = Terrain.new()
	world.add_child(terrain)
	terrain.setup(wrng, biome)

	# Layout pass: decide every position, carve foundations and terraces.
	var lay := Village.layout(terrain, wrng, biome)
	for b in lay.buildings:
		var rf := 6.5 if b.kind == "house" else 7.5
		var p: Vector2 = b.pos
		terrain.add_flat_patch(p, rf, rf + 3.5,
			terrain.height_at(p.x, p.y) - terrain.drop_under(p, rf * 0.7) * 0.35)
	terrain.add_flat_patch(lay.well, 2.2, 4.0,
		terrain.height_at(lay.well.x, lay.well.y))
	var village_count: int = lay.buildings.size() + lay.loose.size()
	var wild := _wild_layout(wrng, STRUCTURE_TOTAL - village_count)

	terrain.build()
	_add_water()
	_add_bounds()

	var s_container := Node3D.new()
	s_container.name = "Structures"
	world.add_child(s_container)
	var village := Village.construct(world, terrain, lay, biome)
	for sp in village.specs + wild:
		_spawn_structure(s_container, sp, wrng)
	for s in structures:
		s.searched.connect(_on_searched)

	_apply_mood(wrng)
	_apply_weather(wrng)
	_place_player(wrng)

	var exclusions: Array = village.exclusions
	for s in structures:
		exclusions.append(Vector3(s.position.x, s.position.z, 6.0))
	exclusions.append(Vector3(player.position.x, player.position.z, 6.0))
	Vegetation.build(world, terrain, exclusions, wrng.randi(), biome)

	var trng := RandomNumberGenerator.new()
	trng.seed = _day_seed(day_offset) ^ 0x5DEECE66
	_assign_tag(trng, -1)
	_assign_tools(trng)
	tools = {map = false, compass = false, spyglass = false,
		pencil = false, notepad = false, eraser = false}
	trail.clear()
	spotted.clear()
	spot_idx = 0
	hud.clear_annotations()
	hud.set_tools(tools)
	hud.set_map_texture(terrain.make_map_texture())
	hud.set_count(0, structures.size())
	hud.clear_found()
	_update_day_info()


## Picks wild structure kinds from the biome pool (weighted, padded/trimmed
## to the budget), finds resting spots per rest class, and carves terraces
## for rigid kinds. The hilltop chest always caps the list.
func _wild_layout(wrng: RandomNumberGenerator, wild_total: int) -> Array:
	var bag: Array = []
	for entry in biome.wild_pool:
		for i in entry[2]:
			bag.append({kind = entry[0], display = entry[1]})
	for i in range(bag.size() - 1, 0, -1):
		var j := wrng.randi_range(0, i)
		var tmp = bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	while bag.size() > wild_total - 1:
		bag.pop_back()
	var fi := 0
	while bag.size() < wild_total - 1:
		var entry: Array = biome.wild_pool[fi % biome.wild_pool.size()]
		fi += 1
		bag.append({kind = entry[0], display = entry[1]})

	var pts: Array[Vector2] = []
	for sp in bag:
		var rest := Structures.rest_class(sp.kind)
		var min_ny := 0.55
		if rest == "mound":
			min_ny = 0.90
		elif rest == "log":
			min_ny = 0.80
		var found := false
		for attempt in 90:
			var a := wrng.randf_range(0.0, TAU)
			var r := wrng.randf_range(70.0, 215.0)
			var p := Vector2(cos(a) * r, sin(a) * r)
			if absf(p.x) > 228.0 or absf(p.y) > 228.0:
				continue
			if (p - terrain.village_center).length() < 45.0:
				continue
			if terrain.height_at(p.x, p.y) < terrain.water_y + 1.2:
				continue
			if terrain.normal_at(p.x, p.y).y < min_ny:
				continue
			var ok := true
			for q in pts:
				if (p - q).length() < 22.0:
					ok = false
					break
			if not ok:
				continue
			sp.x = p.x
			sp.z = p.y
			pts.append(p)
			found = true
			break
		if not found:
			sp.x = wrng.randf_range(-180.0, 180.0)
			sp.z = wrng.randf_range(-180.0, 180.0)
		if rest == "rigid":
			var pp := Vector2(sp.x, sp.z)
			terrain.add_flat_patch(pp, 1.4, 2.8,
				terrain.height_at(pp.x, pp.y) - terrain.drop_under(pp, 1.4) * 0.35)

	var top := terrain.top_spot
	bag.append({kind = "chest", display = "old chest", x = top.x, z = top.z})
	terrain.add_flat_patch(Vector2(top.x, top.z), 1.5, 3.0,
		terrain.height_at(top.x, top.z) - terrain.drop_under(Vector2(top.x, top.z), 1.5) * 0.35)
	return bag


func _spawn_structure(container: Node3D, sp: Dictionary, wrng: RandomNumberGenerator) -> void:
	var s := Structures.create(sp.kind, sp.display, biome.id)
	container.add_child(s)
	if sp.has("xform"):
		s.transform = sp.xform
	else:
		var x: float = sp.x
		var z: float = sp.z
		var h := terrain.height_at(x, z)
		match Structures.rest_class(sp.kind):
			"log":
				# Logs lie along the slope contour, like fallen timber.
				var nrm := terrain.normal_at(x, z)
				var basis: Basis
				if nrm.y > 0.985:
					basis = Basis(Vector3.UP, wrng.randf_range(0.0, TAU))
				else:
					var contour := Vector3(-nrm.z, 0.0, nrm.x).normalized()
					var xv := (contour - nrm * contour.dot(nrm)).normalized()
					basis = Basis(xv, nrm, xv.cross(nrm))
				s.transform = Transform3D(basis, Vector3(x, h - 0.1, z))
			"mound":
				# Mounds stay vertical and sink so their skirt meets the slope.
				var hmin := h
				for i in 8:
					var a := TAU * i / 8.0
					hmin = minf(hmin, terrain.height_at(x + cos(a) * 1.1, z + sin(a) * 1.1))
				var sink := (h - hmin) * 0.85 + 0.04
				s.transform = Transform3D(Basis(Vector3.UP, wrng.randf_range(0.0, TAU)),
					Vector3(x, h - sink, z))
			_:
				# Rigid kinds sit upright on their carved terrace.
				s.transform = Transform3D(Basis(Vector3.UP, wrng.randf_range(0.0, TAU)),
					Vector3(x, h - 0.02, z))
	structures.append(s)


func _apply_mood(wrng: RandomNumberGenerator) -> void:
	var mood: Dictionary = biome.moods[wrng.randi_range(0, biome.moods.size() - 1)]
	mood_name = mood.name
	_sky_mat.sky_top_color = mood.top
	_sky_mat.sky_horizon_color = mood.horizon
	_sky_mat.ground_horizon_color = mood.horizon * 0.85
	_env.fog_density = mood.fog
	_env.fog_light_color = mood.fogc
	_env.ambient_light_energy = mood.ambient
	_sun.light_color = mood.sun
	_sun.light_energy = mood.energy
	_sun.rotation_degrees = Vector3(wrng.randf_range(-52.0, -28.0), wrng.randf_range(0.0, 360.0), 0.0)


func _apply_weather(wrng: RandomNumberGenerator) -> void:
	var w := Biomes.roll_weather(biome, wrng)
	weather_id = w[0]
	weather_name = w[1]
	match weather_id:
		"rain":
			_weather_node = _precip(900, 1.4, Vector2(0.03, 0.34),
				Color(0.62, 0.72, 0.88, 0.55), Vector3(0, -1, 0), 16.0, Vector3(0, -12, 0))
			_env.fog_density += 0.0008
			_sun.light_energy *= 0.85
		"snow":
			_weather_node = _precip(550, 6.0, Vector2(0.07, 0.07),
				Color(0.96, 0.97, 1.0, 0.9), Vector3(0, -1, 0), 2.0, Vector3(0, -1.5, 0))
		"fog":
			_env.fog_density += 0.0055
			_sun.light_energy *= 0.8
		"wind":
			var a := wrng.randf_range(0.0, TAU)
			_weather_node = _precip(520, 2.2, Vector2(0.42, 0.07), biome.debris,
				Vector3(cos(a), -0.15, sin(a)), 22.0, Vector3(0, -2, 0))
			_env.fog_density += 0.0015
			_sun.light_energy *= 0.9


func _precip(amount: int, life: float, size: Vector2, color: Color, dir: Vector3,
		vel: float, grav: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir
	pm.spread = 8.0
	pm.initial_velocity_min = vel * 0.8
	pm.initial_velocity_max = vel * 1.2
	pm.gravity = grav
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(28, 12, 28)
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = mat
	p.draw_pass_1 = qm
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = Vector3(0, 12, 0)
	player.add_child(p)
	return p


func _place_player(wrng: RandomNumberGenerator) -> void:
	var vc := terrain.village_center
	var pos := Vector3(vc.x, 0.0, vc.y + 34.0)
	for i in 60:
		var a := wrng.randf_range(0.0, TAU)
		var r := wrng.randf_range(35.0, 130.0)
		var p := vc + Vector2(cos(a), sin(a)) * r
		if absf(p.x) > 225.0 or absf(p.y) > 225.0:
			continue
		var h := terrain.height_at(p.x, p.y)
		if h < terrain.water_y + 1.5 or terrain.normal_at(p.x, p.y).y < 0.8:
			continue
		pos = Vector3(p.x, h, p.y)
		break
	pos.y = terrain.height_at(pos.x, pos.z) + 0.5
	player.position = pos
	player.velocity = Vector3.ZERO
	var to_v := Vector2(vc.x - pos.x, vc.y - pos.z)
	player.set_facing(atan2(-to_v.x, -to_v.y))


# --- tag rounds & tools --------------------------------------------------

func _assign_tag(trng: RandomNumberGenerator, exclude_idx: int) -> void:
	if structures.is_empty():
		return
	for s in structures:
		s.has_item = false
		s.tag_text = ""
	var idx := trng.randi_range(0, structures.size() - 1)
	if structures.size() > 1:
		while idx == exclude_idx:
			idx = trng.randi_range(0, structures.size() - 1)
	tag_number = str(trng.randi_range(1000, 9999))
	structures[idx].has_item = true
	structures[idx].tag_text = tag_number


func _assign_tools(trng: RandomNumberGenerator) -> void:
	var tag_idx := -1
	for i in structures.size():
		if structures[i].has_item:
			tag_idx = i
	var picks: Array[int] = []
	while picks.size() < 6:
		var i := trng.randi_range(0, structures.size() - 1)
		if i == tag_idx or i in picks:
			continue
		picks.append(i)
	var ids := ["map", "compass", "spyglass", "pencil", "notepad", "eraser"]
	for k in ids.size():
		structures[picks[k]].tool_id = ids[k]


func _collect_tool(s: Interactable) -> void:
	var id := s.tool_id
	s.tool_id = ""
	tools[id] = true
	s.spawn_tool_prop(id)
	hud.set_tools(tools)
	hud.toast("You found the %s!" % id)


func rehide_tag() -> void:
	if structures.is_empty():
		return
	round_num += 1
	var prev := -1
	for i in structures.size():
		if structures[i].has_item:
			prev = i
	for s in structures:
		s.reset()
	searched_count = 0
	var rr := RandomNumberGenerator.new()
	rr.randomize()
	_assign_tag(rr, prev)
	for attempt in 50:
		var holder := -1
		for i in structures.size():
			if structures[i].has_item:
				holder = i
		if structures[holder].tool_id.is_empty():
			break
		_assign_tag(rr, prev)
	hud.set_count(0, structures.size())
	hud.clear_found()
	_update_day_info()
	hud.toast("The tag has been re-hidden somewhere new.")


# --- pencil / spotting ---------------------------------------------------

## The pencil needs something to write on.
func can_note_spots() -> bool:
	return tools.pencil and (tools.map or tools.notepad)


func record_trail(wp: Vector2) -> void:
	if trail.is_empty() or trail[trail.size() - 1].distance_to(wp) > 2.0:
		trail.append(wp)


func erase_trail_near(wp: Vector2, r: float) -> void:
	var keep: Array[Vector2] = []
	for p in trail:
		if p.distance_to(wp) > r:
			keep.append(p)
	trail = keep


func add_spot(s: Interactable) -> void:
	if s.spotted or s.opened:
		return
	s.spotted = true
	spotted.append(s)
	if spotted.size() == 1:
		spot_idx = 0


func cycle_spot() -> void:
	if spotted.is_empty():
		return
	spot_idx = (spot_idx + 1) % spotted.size()


func selected_spot() -> Interactable:
	if spotted.is_empty():
		return null
	spot_idx = clampi(spot_idx, 0, spotted.size() - 1)
	return spotted[spot_idx]


func _remove_spot(s: Interactable) -> void:
	s.spotted = false
	var i := spotted.find(s)
	if i >= 0:
		spotted.remove_at(i)
	if spot_idx >= spotted.size():
		spot_idx = 0


func _on_searched(s: Interactable) -> void:
	if s.spotted:
		_remove_spot(s)
	searched_count += 1
	hud.set_count(searched_count, structures.size())
	var had_tool := not s.tool_id.is_empty()
	if had_tool:
		_collect_tool(s)
	if s.has_item:
		hud.found(tag_number)
	elif not had_tool:
		hud.toast("Nothing in the %s." % s.display_name)


func _update_day_info() -> void:
	var txt := "%s · %s · %s" % [day_label(day_offset), biome.label, mood_name]
	if weather_id != "clear":
		txt += " · " + weather_name
	txt += " · Round %d" % round_num
	hud.set_day_info(txt)


# --- static scaffolding --------------------------------------------------

func _setup_input() -> void:
	var binds := [["move_forward", KEY_W], ["move_back", KEY_S],
		["move_left", KEY_A], ["move_right", KEY_D], ["jump", KEY_SPACE],
		["sprint", KEY_SHIFT], ["interact", KEY_E], ["spyglass", KEY_Z],
		["cycle_spot", KEY_TAB], ["toggle_map", KEY_M]]
	for b in binds:
		if InputMap.has_action(b[0]):
			continue
		InputMap.add_action(b[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = b[1]
		InputMap.action_add_event(b[0], ev)


func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	_env = Environment.new()
	_sky_mat = ProceduralSkyMaterial.new()
	_sky_mat.ground_bottom_color = Color(0.12, 0.14, 0.12)
	_sky_mat.ground_horizon_color = Color(0.55, 0.60, 0.58)
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.ssao_enabled = true
	_env.fog_enabled = true
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 260.0
	add_child(_sun)


func _add_water() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(496, 496)
	pm.material = TexF.mat(biome.terrain.water_mat)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(0, terrain.water_y, 0)
	world.add_child(mi)
	if biome.terrain.ice_solid:
		var ib := StaticBody3D.new()
		ib.name = "Ice"
		ib.collision_layer = 1
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(496, 0.4, 496)
		cs.shape = sh
		cs.position = Vector3(0, terrain.water_y - 0.2, 0)
		ib.add_child(cs)
		world.add_child(ib)


func _add_bounds() -> void:
	var body := StaticBody3D.new()
	body.name = "Bounds"
	body.collision_layer = 1
	world.add_child(body)
	for w in [[Vector3(0, 30, -248), Vector3(500, 120, 4)],
			[Vector3(0, 30, 248), Vector3(500, 120, 4)],
			[Vector3(-248, 30, 0), Vector3(4, 120, 500)],
			[Vector3(248, 30, 0), Vector3(4, 120, 500)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = w[1]
		cs.shape = sh
		cs.position = w[0]
		body.add_child(cs)


func _shot_routine() -> void:
	var nearest: Interactable = null
	var best := 1e9
	for s in structures:
		var d := player.global_position.distance_to(s.global_position)
		if d < best:
			best = d
			nearest = s
	player.set_target(nearest)
	tools = {map = true, compass = false, spyglass = true,
		pencil = true, notepad = true, eraser = true}
	hud.set_tools(tools)
	for s in structures:
		s.seen = true
	add_spot(nearest)
	# Fake a little wandering so the trail ink shows in screenshots.
	var pw := Vector2(player.position.x, player.position.z)
	for i in 30:
		record_trail(pw + Vector2(sin(i * 0.4) * 14.0, -i * 3.0))
	await get_tree().create_timer(2.2).timeout
	var dir := OS.get_environment("HH_SHOT_DIR")
	if dir.is_empty():
		dir = "user://"
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_player.png"))
	tools.compass = true
	hud.set_tools(tools)
	var tv := nearest.global_position - player.global_position
	player.set_facing(atan2(-tv.x, -tv.z))
	player.pitch_node.rotation_degrees.x = -2.0
	Input.action_press("spyglass")
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_spy.png"))
	Input.action_release("spyglass")
	var vc := terrain.village_center
	var cam := Camera3D.new()
	add_child(cam)
	cam.far = 1200.0
	cam.position = Vector3(vc.x + 70, terrain.village_h + 55, vc.y + 95)
	cam.look_at(Vector3(vc.x, terrain.village_h, vc.y))
	cam.current = true
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_aerial.png"))
	hud.toggle_big_map()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_map.png"))
	hud.toggle_big_map()
	menu.open()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_menu.png"))
	get_tree().quit()
