extends Node3D
## Hidden Hollow — daily-seeded worlds. The calendar date seeds the terrain,
## village layout, structure placement, spawn point, weather mood, and the
## tag's number; the last 7 days stay playable from the Esc menu.

const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const STRUCTURE_TOTAL := 20

const MOODS := [
	{name = "Clear Skies", top = Color(0.20, 0.42, 0.75), horizon = Color(0.66, 0.74, 0.80),
		sun = Color(1.0, 0.96, 0.88), energy = 1.3, fog = 0.0008,
		fogc = Color(0.75, 0.81, 0.90), ambient = 1.0},
	{name = "Morning Haze", top = Color(0.45, 0.58, 0.72), horizon = Color(0.82, 0.83, 0.80),
		sun = Color(1.0, 0.90, 0.75), energy = 1.05, fog = 0.0026,
		fogc = Color(0.85, 0.86, 0.82), ambient = 1.1},
	{name = "Golden Hour", top = Color(0.30, 0.38, 0.60), horizon = Color(0.95, 0.72, 0.45),
		sun = Color(1.0, 0.75, 0.45), energy = 1.2, fog = 0.0014,
		fogc = Color(0.90, 0.78, 0.60), ambient = 0.9},
	{name = "Overcast", top = Color(0.42, 0.46, 0.52), horizon = Color(0.62, 0.65, 0.68),
		sun = Color(0.85, 0.88, 0.92), energy = 0.65, fog = 0.0018,
		fogc = Color(0.68, 0.70, 0.73), ambient = 1.35},
]

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
var mood_name := ""
var tools := {map = false, compass = false, spyglass = false}

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D


func _ready() -> void:
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
	# Local-time day index so the daily world rolls over at local midnight.
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
	if world:
		world.free()
		world = null
	structures.clear()
	searched_count = 0

	var wrng := RandomNumberGenerator.new()
	wrng.seed = _day_seed(day_offset)

	world = Node3D.new()
	world.name = "World"
	add_child(world)
	terrain = Terrain.new()
	world.add_child(terrain)
	terrain.setup(wrng)
	terrain.build()
	_add_water()
	_add_bounds()

	var s_container := Node3D.new()
	s_container.name = "Structures"
	world.add_child(s_container)
	var village := Village.build(world, terrain, wrng)
	var specs: Array = village.specs
	specs += _wild_specs(wrng, STRUCTURE_TOTAL - specs.size())
	for sp in specs:
		_spawn_structure(s_container, sp, wrng)
	for s in structures:
		s.searched.connect(_on_searched)

	_apply_mood(wrng)
	_place_player(wrng)

	var exclusions: Array = village.exclusions
	for s in structures:
		exclusions.append(Vector3(s.position.x, s.position.z, 6.0))
	exclusions.append(Vector3(player.position.x, player.position.z, 6.0))
	Vegetation.build(world, terrain, exclusions, wrng.randi())

	# Round 1 hiding spot, number, and tool locations are deterministic for
	# the day, so a relaunch resumes the same daily puzzle.
	var trng := RandomNumberGenerator.new()
	trng.seed = _day_seed(day_offset) ^ 0x5DEECE66
	_assign_tag(trng, -1)
	_assign_tools(trng)
	tools = {map = false, compass = false, spyglass = false}
	hud.set_tools(tools)
	hud.set_map_texture(terrain.make_map_texture())
	hud.set_count(0, structures.size())
	hud.clear_found()
	_update_day_info()


## Hides the three tools in distinct structures, never the tag's.
func _assign_tools(trng: RandomNumberGenerator) -> void:
	var tag_idx := -1
	for i in structures.size():
		if structures[i].has_item:
			tag_idx = i
	var picks: Array[int] = []
	while picks.size() < 3:
		var i := trng.randi_range(0, structures.size() - 1)
		if i == tag_idx or i in picks:
			continue
		picks.append(i)
	var ids := ["map", "compass", "spyglass"]
	for k in 3:
		structures[picks[k]].tool_id = ids[k]


func _collect_tool(s: Interactable) -> void:
	var id := s.tool_id
	s.tool_id = ""
	tools[id] = true
	s.spawn_tool_prop(id)
	hud.set_tools(tools)
	hud.toast("You found the %s!" % id)


func _wild_specs(wrng: RandomNumberGenerator, wild_total: int) -> Array:
	var names := {crate = "crate", barrel = "barrel", log = "hollow log", dirt_pile = "dirt pile"}
	var bag: Array = []
	for c in [["log", wrng.randi_range(2, 4)], ["dirt_pile", wrng.randi_range(3, 5)],
			["crate", wrng.randi_range(1, 3)], ["barrel", wrng.randi_range(1, 2)]]:
		for i in c[1]:
			bag.append({kind = c[0], display = names[c[0]],
				tilt = c[0] == "log" or c[0] == "dirt_pile"})
	while bag.size() > wild_total - 1:
		bag.pop_back()
	var fillers := ["crate", "log", "dirt_pile", "barrel"]
	var fi := 0
	while bag.size() < wild_total - 1:
		var k: String = fillers[fi % fillers.size()]
		fi += 1
		bag.append({kind = k, display = names[k],
			tilt = k == "log" or k == "dirt_pile"})
	bag.shuffle()

	var pts: Array[Vector2] = []
	for sp in bag:
		for attempt in 80:
			var a := wrng.randf_range(0.0, TAU)
			var r := wrng.randf_range(70.0, 215.0)
			var p := Vector2(cos(a), sin(a)) * r
			if absf(p.x) > 228.0 or absf(p.y) > 228.0:
				continue
			if (p - terrain.village_center).length() < 45.0:
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
			break
		if not sp.has("x"):
			sp.x = wrng.randf_range(-200.0, 200.0)
			sp.z = wrng.randf_range(-200.0, 200.0)
	bag.append({kind = "chest", display = "old chest",
		x = terrain.top_spot.x, z = terrain.top_spot.z})
	return bag


func _spawn_structure(container: Node3D, sp: Dictionary, wrng: RandomNumberGenerator) -> void:
	var s := Structures.create(sp.kind, sp.display)
	container.add_child(s)
	if sp.has("xform"):
		s.transform = sp.xform
	else:
		var x: float = sp.x
		var z: float = sp.z
		for i in 24:
			if terrain.height_at(x, z) > terrain.water_y + 1.2:
				break
			x *= 1.07
			z *= 1.07
			x = clampf(x, -232.0, 232.0)
			z = clampf(z, -232.0, 232.0)
		var h := terrain.height_at(x, z)
		var basis := Basis(Vector3.UP, wrng.randf_range(0.0, TAU))
		if sp.get("tilt", false):
			basis = Basis(Quaternion(Vector3.UP, terrain.normal_at(x, z))) * basis
		s.transform = Transform3D(basis, Vector3(x, h - 0.03, z))
		if sp.get("pad", true):
			var pad := CylinderMesh.new()
			pad.top_radius = 1.7
			pad.bottom_radius = 1.9
			pad.height = 0.22
			pad.radial_segments = 14
			pad.material = TexF.mat("dirt_mound")
			Util.mesh(container, pad, Vector3(x, h - 0.04, z))
	structures.append(s)


func _apply_mood(wrng: RandomNumberGenerator) -> void:
	var mood: Dictionary = MOODS[wrng.randi_range(0, MOODS.size() - 1)]
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


# --- tag rounds ----------------------------------------------------------

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
	# Steer the tag away from structures still holding an unfound tool.
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


func _on_searched(s: Interactable) -> void:
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
	hud.set_day_info("%s · %s · Round %d" % [day_label(day_offset), mood_name, round_num])


# --- static scaffolding --------------------------------------------------

func _setup_input() -> void:
	var binds := [["move_forward", KEY_W], ["move_back", KEY_S],
		["move_left", KEY_A], ["move_right", KEY_D], ["jump", KEY_SPACE],
		["sprint", KEY_SHIFT], ["interact", KEY_E], ["spyglass", KEY_Z]]
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
	pm.material = TexF.mat("water")
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.position = Vector3(0, terrain.water_y, 0)
	world.add_child(mi)


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
	# Map-only first (view-up rotating minimap), full kit for later shots.
	tools = {map = true, compass = false, spyglass = true}
	hud.set_tools(tools)
	for s in structures:
		s.seen = true
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
	menu.open()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_menu.png"))
	get_tree().quit()
