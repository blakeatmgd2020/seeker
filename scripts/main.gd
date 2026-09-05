extends Node3D
## Seeker — daily-seeded worlds. The calendar date seeds the biome, terrain,
## village layout, structure placement, spawn point, sky mood, weather, and
## the tag's number; the last 7 days stay playable from the Esc menu.
##
## Build order matters: the village and wild structures are laid out FIRST so
## terraces and foundation cuts can be carved into the heightfield, and only
## then is the terrain mesh built — structures rest in the land, not on it.

const WATER_SHADER := "
shader_type spatial;
uniform vec4 base_col : source_color = vec4(0.12, 0.34, 0.44, 0.62);
uniform float wind_amt = 0.15;
uniform vec3 player_pos = vec3(0.0);
uniform float wake = 0.0;
uniform vec2 vel_dir = vec2(0.0, 1.0);
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	float t = TIME;
	float amp = 0.3 + wind_amt * 1.6;
	float w1 = sin(uv.x * 0.35 + t * (0.8 + wind_amt * 2.5))
		+ sin((uv.x + uv.y) * 0.21 - t * (0.6 + wind_amt * 1.8));
	float w2 = sin(uv.y * 0.4 - t * (0.7 + wind_amt * 2.2))
		+ sin((uv.y - uv.x) * 0.17 + t * 0.5);
	vec2 rel = uv - player_pos.xz;
	float d = length(rel);
	// The disturbance trails BEHIND the direction of travel — a wake,
	// not a circle: strongest astern, faint at the bow.
	float behind = 0.5 + 0.5 * dot(normalize(rel + vec2(1e-4)), -vel_dir);
	float ring = cos(d * 9.0 - t * 7.0) * exp(-d * 0.7)
		* wake * (0.9 + 5.1 * behind * behind);
	vec3 nm = normalize(vec3((w1 * amp + ring) * 0.09, (w2 * amp + ring) * 0.09, 1.0));
	NORMAL_MAP = nm * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = base_col.rgb;
	ALPHA = base_col.a;
	ROUGHNESS = 0.05;
	METALLIC = 0.35;
	SPECULAR = 0.7;
}
"

const VERSION := "r7 · 2026-09-04 18:40"
## One digest per release, newest first — readable in-game from the Dev
## Note interface so a playtest knows what to look out for.
const CHANGELOG := [
	"r7 · 2026-09-04 18:40 — Wells fixed: open rims you can see down, plank covers until you own the rope (no more ropeless traps), and climbing out actually works. Cellars deeper with taller vaults; no bottom-step flicker. Cave exits walkable (no jump needed); caves can be tucked into the barrier ridges. Sprint decays to plain walking speed. W or mouse-run cancels autorun. Smooth mouse steering with the map open. Tighter top-right HUD. Esc menu: End current map reveals the recap. Recap report centered above a smaller map. Hollow stumps look hollow; firewood is smaller and often near fire pits.",
	"r6 · 2026-09-04 17:30 — Conditional items: irons/rope are only hidden when the world actually has nests / a cavern well (6-8 items per world; ~1 in 4 maps has no nests). Grey unfound-item roster removed; found items show as circular icons under the minimap. Movement speed readout (walk = 100%). Real sitting pose; leaving crouch or sit always stands you up. Square coffee button with icon. Wild nodes favor shorelines. Tree canopies now block the spyglass. Compact win banner. This version history.",
	"r5 · 2026-09-04 — Rope + well caverns (climb in over the rim, slide down). Two-story, two-room, and roofdeck houses with ladders; house cellars, some empty. Sit (C). Keep moving with the map or Dev Note open. Victory recap draws your whole path. Birds perch on roofs/trees and only sometimes flee to nests. Eraser retired — the pencil erases. Scope vertically un-inverted, labels clipped to the lens.",
	"r4 · 2026-09-04 — Cellars rebuilt: walk in standing, nothing pokes outside. Crouch. Slippery ice. Autorun (`). Pencil marks no longer retroactive — re-sight to ink. Circular minimap; rotating maps have no sheet edge. Directional water wake. Birds scatter when approached. Version stamp.",
	"r3 · 2026-09-03 — Winded countdown with green refill bar. Dev Note corner button. Arrow-key turning. Ink X on searched nodes. Ambient birds commuting between nests.",
	"r2 · 2026-09-01 — Terrain holes: cave and cellar entrances actually open. 0-6 villages, 1-12 buildings, empty buildings. Notepad minimap + N view. Coffee button, stamina lockout. Water wake and campfire smoke.",
	"r1 · 2026-08-31 — The hunt: open every node. Biomes, weather, findable tools, spyglass spotting, daily seeds, random maps, title screen, this feedback system.",
]
const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const STRUCTURE_TOTAL := 20

var terrain: Terrain
var player: Player
var hud: Hud
var menu: GameMenu
var title: TitleScreen
var feedback: Feedback
var game_mode := "daily"
var random_seed_val := 1
var world: Node3D = null
var structures: Array[Interactable] = []
var climbables: Array = []
var searched_count := 0
var hunt_won := false
var world_start_ms := 0
var day_offset := 0
var biome: Dictionary = {}
var mood_name := ""
var weather_id := "clear"
var weather_name := "Clear"
var tools := {map = false, compass = false, spyglass = false,
	pencil = false, notepad = false, irons = false, rope = false}
var has_coffee := false
var coffee_until_ms := 0
var well_drops: Array = []
var trail: Array[Vector2] = []
var full_path: Array[Vector2] = []
var spotted: Array[Interactable] = []
var spot_idx := 0
var debug_biome := ""

var _env: Environment
var _sky_mat: ProceduralSkyMaterial
var _sun: DirectionalLight3D
var _weather_node: GPUParticles3D = null
var _water_mat: ShaderMaterial = null
var _wake := 0.0
var _wake_dir := Vector2(0, 1)
var _cur_vils: Array = []


func _roll_village_count(wrng: RandomNumberGenerator) -> int:
	# 0..6 villages, weighted: none is uncommon, sprawls are rare.
	var weights := [10, 30, 25, 15, 10, 6, 4]
	var total := 0
	for w in weights:
		total += w
	var pick := wrng.randi_range(1, total)
	for i in weights.size():
		pick -= weights[i]
		if pick <= 0:
			return i
	return 1


func _village_clear(p: Vector2, margin: float) -> bool:
	for vd in _cur_vils:
		if p.distance_to(vd.c) < vd.rf + margin:
			return false
	return true


func _process(delta: float) -> void:
	if _water_mat == null or player == null or terrain == null:
		return
	var in_water: bool = world != null \
		and player.global_position.y < terrain.water_y + 0.6 \
		and Vector2(player.velocity.x, player.velocity.z).length() > 1.2
	_wake = move_toward(_wake, 1.0 if in_water else 0.0, delta * 3.0)
	var hv := Vector2(player.velocity.x, player.velocity.z)
	if hv.length() > 1.0:
		_wake_dir = _wake_dir.lerp(hv.normalized(), minf(1.0, delta * 6.0)).normalized()
	_water_mat.set_shader_parameter("player_pos", player.global_position)
	_water_mat.set_shader_parameter("wake", _wake)
	_water_mat.set_shader_parameter("vel_dir", _wake_dir)


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--biome="):
			debug_biome = a.substr(8)
	var is_shot := OS.get_cmdline_user_args().has("--shot")
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
	title = TitleScreen.new()
	title.main = self
	add_child(title)
	feedback = Feedback.new()
	feedback.main = self
	feedback.enabled = not is_shot
	add_child(feedback)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	hud.visible = false
	title.refresh()
	if is_shot:
		_shot_routine()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and feedback:
		feedback.write_summary()


# --- game modes ----------------------------------------------------------

func start_daily() -> void:
	game_mode = "daily"
	_enter_game()
	load_day(0)


func start_random(sv: int) -> void:
	game_mode = "random"
	random_seed_val = maxi(absi(sv) % 2147483647, 1)
	day_offset = 0
	_enter_game()
	_build_world()


## Seed field accepts numbers or words (words hash); empty rolls fresh.
func start_random_from_text(t: String) -> void:
	t = t.strip_edges()
	if t.is_empty():
		new_random_map()
	elif t.is_valid_int():
		start_random(int(t))
	else:
		start_random(t.hash())


func new_random_map() -> void:
	var r := RandomNumberGenerator.new()
	r.randomize()
	start_random(r.randi())


func restart_current() -> void:
	if game_mode == "random":
		start_random(random_seed_val)
	else:
		load_day(day_offset)


func return_to_title() -> void:
	player.set_target(null)
	if _weather_node and is_instance_valid(_weather_node):
		_weather_node.queue_free()
	_weather_node = null
	if world:
		world.free()
		world = null
	structures.clear()
	spotted.clear()
	trail.clear()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	hud.visible = false
	title.visible = true
	title.refresh()


func quit_game() -> void:
	feedback.write_summary()
	get_tree().quit()


func _enter_game() -> void:
	title.visible = false
	hud.visible = true
	player.visible = true
	player.process_mode = Node.PROCESS_MODE_INHERIT


func world_title() -> String:
	if game_mode == "random":
		return "Random Map · seed %d" % random_seed_val
	return day_label(day_offset)


# --- daily seeds ---------------------------------------------------------

func _day_index(offset: int) -> int:
	var local_unix := Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system())
	return int(local_unix / 86400) - offset


func _day_seed(offset: int) -> int:
	return (_day_index(offset) * 2654435761) % 2147483647


func _world_seed() -> int:
	if game_mode == "random":
		return random_seed_val
	return _day_seed(day_offset)


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
	wrng.seed = _world_seed()
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

	# Villages: 0-6 per map, 1-12 buildings each (biased small). Each village
	# flattens its own plateau via the patch system.
	_cur_vils.clear()
	var nvil := _roll_village_count(wrng)
	for i in nvil:
		for attempt in 50:
			var c := Vector2(wrng.randf_range(-130.0, 130.0), wrng.randf_range(-130.0, 130.0))
			var ok := terrain.raw_h(c.x, c.y) > terrain.water_y + 3.0
			for vd in _cur_vils:
				if c.distance_to(vd.c) < 68.0:
					ok = false
					break
			if not ok:
				continue
			var n := 1 + int(pow(wrng.randf(), 1.6) * 11.99)
			var rf := clampf(10.0 + n * 1.6, 12.0, 30.0)
			terrain.add_flat_patch(c, rf, rf + 22.0,
				maxf(terrain.raw_h(c.x, c.y), terrain.water_y + 4.5))
			terrain.village_centers.append(c)
			_cur_vils.append({c = c, n = n, rf = rf})
			break

	# Layout pass: decide every position, carve foundations and terraces.
	var lay := Village.layout(terrain, wrng, biome, _cur_vils)
	for b in lay.buildings:
		var rf := 6.5 if b.kind == "house" else 7.5
		var p: Vector2 = b.pos
		terrain.add_flat_patch(p, rf, rf + 3.5,
			terrain.height_at(p.x, p.y) - terrain.drop_under(p, rf * 0.7) * 0.35)
		if b.basement:
			# Open the terrain under the central cellar stairwell. Removal can
			# reach rect + ~3 m; the widened foundation slab covers all of it.
			var hx := 3.4 if b.kind == "barn" else 2.7
			terrain.add_hole_rect(p, Vector2(hx, 0.95), deg_to_rad(b.yaw))
	for wd in lay.wells:
		terrain.add_flat_patch(wd.c, 2.2, 4.0, terrain.height_at(wd.c.x, wd.c.y))
		if wd.cavern:
			# Open the terrain inside the well shaft; the collar slab covers
			# the over-removal.
			terrain.add_hole_rect(wd.c, Vector2(1.1, 1.1), 0.0)
	var vnodes := 0
	for b in lay.buildings:
		if b.node:
			vnodes += 1
	var village_count: int = vnodes + lay.loose.size()
	var wild := _wild_layout(wrng, clampi(STRUCTURE_TOTAL - village_count, 8, STRUCTURE_TOTAL))

	# Maybe a cave out in the wilds (extra nodes beyond the surface count).
	var cave_pos := Vector2.ZERO
	var cave_yaw := 0.0
	var has_cave := false
	if wrng.randf() < 0.6:
		# Prefer a mine mouth tucked into the barrier ridge, doorway facing
		# the valley; fall back to an open-country site.
		for attempt in 90:
			var p: Vector2
			var yaw := 0.0
			var ridge: bool = attempt < 45
			if ridge:
				var a := wrng.randf_range(0.0, TAU)
				p = Vector2(cos(a), sin(a)) * wrng.randf_range(188.0, 212.0)
				p.x = clampf(p.x, -212.0, 212.0)
				p.y = clampf(p.y, -212.0, 212.0)
				yaw = atan2(-p.x, -p.y) + wrng.randf_range(-0.35, 0.35)
			else:
				var a := wrng.randf_range(0.0, TAU)
				var r := wrng.randf_range(60.0, 200.0)
				p = Vector2(cos(a) * r, sin(a) * r)
				yaw = wrng.randf_range(0.0, TAU)
			if absf(p.x) > 218.0 or absf(p.y) > 218.0:
				continue
			if not _village_clear(p, 14.0):
				continue
			if terrain.height_at(p.x, p.y) < terrain.water_y + 2.0:
				continue
			# Ridge sites can be steep — the carve patch flattens them.
			if not ridge and (terrain.normal_at(p.x, p.y).y < 0.88
					or terrain.drop_under(p, 10.0) > 2.0):
				continue
			var clear := true
			for sp in wild:
				if Vector2(sp.x - p.x, sp.z - p.y).length() < 16.0:
					clear = false
					break
			if not clear:
				continue
			cave_pos = p
			cave_yaw = yaw
			has_cave = true
			# The flat patch must bury the whole chamber, which extends
			# behind the mound (local -Z), so shift the patch that way.
			var back := Vector2(sin(cave_yaw), cos(cave_yaw)) * -3.0
			terrain.add_flat_patch(p + back, 8.5, 12.5, terrain.height_at(p.x, p.y))
			# Open the terrain over the descending shaft.
			terrain.add_hole_rect(p + Vector2(0.0, 0.35).rotated(-cave_yaw),
				Vector2(1.3, 3.6), cave_yaw)
			break

	terrain.build()
	_add_water()
	_add_bounds()

	var s_container := Node3D.new()
	s_container.name = "Structures"
	world.add_child(s_container)
	var village := Village.construct(world, terrain, lay, biome)
	var all_specs: Array = village.specs + wild
	if has_cave:
		all_specs += Caves.build(world, terrain, wrng, cave_pos, cave_yaw, biome)
	for sp in all_specs:
		_spawn_structure(s_container, sp, wrng)
	for s in structures:
		s.searched.connect(_on_searched)

	_apply_mood(wrng)
	_apply_weather(wrng)
	_place_player(wrng)

	var exclusions: Array = village.exclusions
	for vd in _cur_vils:
		exclusions.append(Vector3(vd.c.x, vd.c.y, vd.rf + 6.0))
	for s in structures:
		exclusions.append(Vector3(s.position.x, s.position.z, 6.0))
	if has_cave:
		exclusions.append(Vector3(cave_pos.x, cave_pos.y, 9.0))
	exclusions.append(Vector3(player.position.x, player.position.z, 6.0))
	var tree_perches: Array = Vegetation.build(world, terrain, exclusions, wrng.randi(), biome)

	# Great trees / spires become climbable (with the irons); building
	# ladders climb free. Cavern wells descend with the rope.
	climbables.clear()
	for s in structures:
		if s.kind == "nest":
			climbables.append({axis = Vector3(s.position.x, 0, s.position.z),
				top_y = s.position.y})
	for ld in village.ladders:
		climbables.append({axis = ld.axis, top_y = ld.top_y, free = true})
	well_drops = village.drops

	# Small birds commute between the nests — follow one to find them. They
	# also loiter on rooftops and treetops, and flushed birds only sometimes
	# retreat home.
	var nest_tops: Array = []
	for s in structures:
		if s.kind == "nest":
			nest_tops.append(Vector3(s.position.x, s.position.y + 0.55, s.position.z))
	if nest_tops.size() >= 2:
		var birds := Birds.build(world, terrain, wrng, nest_tops)
		birds.main = self
		birds.spots = village.perches + tree_perches

	# Tool locations are deterministic per seed.
	var trng := RandomNumberGenerator.new()
	trng.seed = _world_seed() ^ 0x5DEECE66
	_assign_tools(trng)
	tools = {map = false, compass = false, spyglass = false,
		pencil = false, notepad = false, irons = false, rope = false}
	has_coffee = false
	coffee_until_ms = 0
	trail.clear()
	full_path.clear()
	spotted.clear()
	spot_idx = 0
	hunt_won = false
	world_start_ms = Time.get_ticks_msec()
	hud.close_big_views()
	hud.clear_annotations()
	hud.set_tools(tools)
	hud.set_map_texture(terrain.make_map_texture())
	hud.set_count(0, structures.size())
	hud.hide_banner()
	_update_day_info()
	if feedback:
		feedback.log_world("%s · %s · %s · %s" % [world_title(), biome.label,
			mood_name, weather_name])


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
	# Reserve slots for the hilltop chest and — on most maps — two
	# great-tree nests. About 1 in 4 worlds has no nests (and hides no
	# climbing irons).
	var has_nests := wrng.randf() < 0.75
	var reserve := 3 if has_nests else 1
	while bag.size() > wild_total - reserve:
		bag.pop_back()
	var fi := 0
	while bag.size() < wild_total - reserve:
		var entry: Array = biome.wild_pool[fi % biome.wild_pool.size()]
		fi += 1
		bag.append({kind = entry[0], display = entry[1]})
	if has_nests:
		var nest_name := "spire nest" if biome.id == "desert" else "bird nest"
		bag.append({kind = "nest", display = nest_name})
		bag.append({kind = "nest", display = nest_name})

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
			if not _village_clear(p, 10.0):
				continue
			var ph := terrain.height_at(p.x, p.y)
			if ph < terrain.water_y + 1.2:
				continue
			# Shoreline bias: hiding spots favor the low ground near water.
			# Early attempts often reject high-and-dry candidates; if no
			# shore is available the later attempts take anything.
			if attempt < 60 and ph > terrain.water_y + 3.5 and wrng.randf() < 0.45:
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
		if rest == "rigid" or rest == "tree":
			var pp := Vector2(sp.x, sp.z)
			terrain.add_flat_patch(pp, 1.4, 2.8,
				terrain.height_at(pp.x, pp.y) - terrain.drop_under(pp, 1.4) * 0.35)

	# Firewood keeps company: given a campfire, stacks usually move beside it.
	var fires: Array[Vector2] = []
	for sp in bag:
		if sp.kind == "campfire":
			fires.append(Vector2(sp.x, sp.z))
	if not fires.is_empty():
		for sp in bag:
			if sp.kind != "firewood" or wrng.randf() > 0.65:
				continue
			var fc := fires[wrng.randi_range(0, fires.size() - 1)]
			for attempt in 20:
				var a := wrng.randf_range(0.0, TAU)
				var q := fc + Vector2(cos(a), sin(a)) * wrng.randf_range(3.0, 6.5)
				if absf(q.x) > 228.0 or absf(q.y) > 228.0:
					continue
				if not _village_clear(q, 10.0):
					continue
				if terrain.height_at(q.x, q.y) < terrain.water_y + 1.2:
					continue
				if terrain.normal_at(q.x, q.y).y < 0.62:
					continue
				sp.x = q.x
				sp.z = q.y
				terrain.add_flat_patch(q, 1.4, 2.8,
					terrain.height_at(q.x, q.y) - terrain.drop_under(q, 1.4) * 0.35)
				break

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
			"tree":
				# Great trees: the structure origin is the NEST at the top.
				s.transform = Transform3D(Basis(Vector3.UP, wrng.randf_range(0.0, TAU)),
					Vector3(x, h + Structures.NEST_HEIGHT, z))
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
	if _water_mat:
		var wind_amt := 0.15
		if weather_id == "wind":
			wind_amt = 0.95
		elif weather_id == "rain":
			wind_amt = 0.45
		_water_mat.set_shader_parameter("wind_amt", wind_amt)


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
	var vc := Vector2.ZERO
	if not _cur_vils.is_empty():
		vc = _cur_vils[wrng.randi_range(0, _cur_vils.size() - 1)].c
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
	if to_v.length() < 1.0:
		to_v = Vector2(0, -1)
	player.set_facing(atan2(-to_v.x, -to_v.y))


# --- tools ---------------------------------------------------------------

func _assign_tools(trng: RandomNumberGenerator) -> void:
	# Conditional gear: an item is only hidden when the world holds
	# something to use it on — irons need nests, the rope needs a cavern
	# well. Worlds carry 6-8 hidden items.
	var ids := ["map", "compass", "spyglass", "pencil", "notepad", "coffee"]
	for s in structures:
		if s.kind == "nest":
			ids.append("irons")
			break
	if not well_drops.is_empty():
		ids.append("rope")
	var picks: Array[int] = []
	while picks.size() < ids.size():
		var i := trng.randi_range(0, structures.size() - 1)
		if i in picks:
			continue
		picks.append(i)
	for k in ids.size():
		structures[picks[k]].tool_id = ids[k]


func _collect_tool(s: Interactable) -> void:
	var id := s.tool_id
	s.tool_id = ""
	feedback.tools_found.append(id)
	s.spawn_tool_prop(id)
	if id == "coffee":
		has_coffee = true
		hud.toast("You found a cup of coffee — still warm!")
		return
	tools[id] = true
	hud.set_tools(tools)
	if id == "rope":
		# The rope now hangs in every cavern well, and the plank covers
		# come off — the shafts are open.
		for dr in well_drops:
			dr.rope.visible = true
			dr.cover.visible = false
			dr.cover_shape.set_deferred("disabled", true)
	hud.toast("You found the %s!" % ("climbing irons" if id == "irons" else id))


func drink_coffee() -> void:
	if not has_coffee:
		return
	has_coffee = false
	coffee_until_ms = Time.get_ticks_msec() + 120000
	hud.toast("Caffeinated! Unlimited sprint for 2 minutes.")


func coffee_active() -> bool:
	return Time.get_ticks_msec() < coffee_until_ms


func coffee_remaining() -> int:
	return maxi(0, coffee_until_ms - Time.get_ticks_msec()) / 1000


## True when the position stands on a frozen pond's ice sheet.
func on_ice(p: Vector3) -> bool:
	return world != null and terrain != null and not biome.is_empty() \
		and biome.terrain.ice_solid \
		and absf(p.y - terrain.water_y) < 0.8 \
		and terrain.height_at(p.x, p.z) < terrain.water_y - 0.15


# --- pencil / spotting ---------------------------------------------------

## The pencil needs something to write on.
func can_note_spots() -> bool:
	return tools.pencil and (tools.map or tools.notepad)


func record_trail(wp: Vector2) -> void:
	if trail.is_empty() or trail[trail.size() - 1].distance_to(wp) > 2.0:
		trail.append(wp)


## The complete session path — always recorded, shown on the victory recap.
func record_path(wp: Vector2) -> void:
	if full_path.is_empty() or full_path[full_path.size() - 1].distance_to(wp) > 3.0:
		full_path.append(wp)


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
	s.noted = true
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
	feedback.searches += 1
	hud.set_count(searched_count, structures.size())
	var had_tool := not s.tool_id.is_empty()
	if had_tool:
		_collect_tool(s)
	elif searched_count < structures.size():
		hud.toast("The %s is empty." % s.display_name)
	if searched_count >= structures.size() and not hunt_won:
		hunt_won = true
		feedback.finds += 1
		var secs := int((Time.get_ticks_msec() - world_start_ms) / 1000.0)
		hud.show_recap(searched_count, structures.size(),
			"%d:%02d" % [secs / 60, secs % 60], false)


## Menu action: give up on the map and reveal everything — the full map,
## every node, and the path walked.
func end_current_map() -> void:
	if world == null or hunt_won:
		return
	hunt_won = true
	var secs := int((Time.get_ticks_msec() - world_start_ms) / 1000.0)
	hud.show_recap(searched_count, structures.size(),
		"%d:%02d" % [secs / 60, secs % 60], true)


func _update_day_info() -> void:
	var txt := "%s · %s · %s" % [world_title(), biome.label, mood_name]
	if weather_id != "clear":
		txt += " · " + weather_name
	hud.set_day_info(txt)


# --- static scaffolding --------------------------------------------------

func _setup_input() -> void:
	var binds := [["move_forward", KEY_W], ["move_back", KEY_S],
		["move_left", KEY_A], ["move_right", KEY_D], ["jump", KEY_SPACE],
		["sprint", KEY_SHIFT], ["interact", KEY_E], ["spyglass", KEY_Z],
		["cycle_spot", KEY_TAB], ["toggle_map", KEY_M], ["toggle_pad", KEY_N],
		["feedback", KEY_F8], ["turn_left", KEY_LEFT], ["turn_right", KEY_RIGHT],
		["crouch", KEY_X], ["sit", KEY_C], ["autorun", KEY_QUOTELEFT]]
	for b in binds:
		if InputMap.has_action(b[0]):
			continue
		InputMap.add_action(b[0])
		var ev := InputEventKey.new()
		ev.physical_keycode = b[1]
		InputMap.action_add_event(b[0], ev)
	# Up/Down arrows double as walk keys alongside W/S.
	for ex in [["move_forward", KEY_UP], ["move_back", KEY_DOWN]]:
		var ev := InputEventKey.new()
		ev.physical_keycode = ex[1]
		InputMap.action_add_event(ex[0], ev)


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
	if biome.terrain.water_mat == "ice":
		pm.material = TexF.mat("ice")
		_water_mat = null
	else:
		var sh := Shader.new()
		sh.code = WATER_SHADER
		_water_mat = ShaderMaterial.new()
		_water_mat.shader = sh
		var col := Color(0.12, 0.34, 0.44, 0.62)
		if biome.terrain.water_mat == "oasis":
			col = Color(0.14, 0.42, 0.40, 0.66)
		_water_mat.set_shader_parameter("base_col", col)
		pm.material = _water_mat
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
	var dir0 := OS.get_environment("HH_SHOT_DIR")
	if dir0.is_empty():
		dir0 = "user://"
	await get_tree().create_timer(0.6).timeout
	get_viewport().get_texture().get_image().save_png(dir0.path_join("shot_title.png"))
	start_daily()
	var nearest: Interactable = null
	var best := 1e9
	for s in structures:
		var d := player.global_position.distance_to(s.global_position)
		if d < best:
			best = d
			nearest = s
	player.set_target(nearest)
	tools = {map = true, compass = false, spyglass = true,
		pencil = true, notepad = true, irons = true, rope = true}
	has_coffee = true
	hud.set_tools(tools)
	for s in structures:
		s.seen = true
		s.noted = true
	add_spot(nearest)
	player.stamina = 0.2
	player._stamina_locked = true
	player._lock_until_ms = Time.get_ticks_msec() + 42000
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
	var aim_at: Interactable = nearest
	var nbest := 1e9
	for s in structures:
		if s.kind == "nest":
			var nd := player.global_position.distance_to(s.global_position)
			if nd < nbest:
				nbest = nd
				aim_at = s
	var tv := aim_at.global_position - player.global_position
	player.set_facing(atan2(-tv.x, -tv.z))
	player.pitch_node.rotation_degrees.x = rad_to_deg(
		atan2(tv.y, Vector2(tv.x, tv.z).length()))
	Input.action_press("spyglass")
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_spy.png"))
	Input.action_release("spyglass")
	var vc := Vector2(player.global_position.x, player.global_position.z)
	if not _cur_vils.is_empty():
		vc = _cur_vils[0].c
	var vh := terrain.height_at(vc.x, vc.y)
	var cam := Camera3D.new()
	add_child(cam)
	cam.far = 1200.0
	cam.position = Vector3(vc.x + 70, vh + 55, vc.y + 95)
	cam.look_at(Vector3(vc.x, vh, vc.y))
	cam.current = true
	await get_tree().create_timer(0.8).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_aerial.png"))
	# Birds at (or between) the nests.
	var nest_s: Interactable = null
	for s in structures:
		if s.kind == "nest":
			nest_s = s
			break
	if nest_s:
		var bcam := Camera3D.new()
		add_child(bcam)
		bcam.position = nest_s.global_position + Vector3(6.5, 1.2, 6.5)
		bcam.look_at(nest_s.global_position + Vector3(0, 0.4, 0))
		bcam.current = true
		await get_tree().create_timer(0.6).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_birds.png"))
	player.cam.make_current()
	# Search a few nodes so the X marks show on the map shot.
	var opened := 0
	for s in structures:
		if not s.opened and s != nearest:
			s.interact()
			opened += 1
			if opened >= 3:
				break
	hud.toggle_big_map()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_map.png"))
	hud.toggle_big_map()
	menu.open()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_menu.png"))
	menu.close()
	feedback.open_form()
	await get_tree().create_timer(0.4).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_feedback.png"))
	feedback.close_form()
	end_current_map()
	await get_tree().create_timer(0.5).timeout
	get_viewport().get_texture().get_image().save_png(dir.path_join("shot_recap.png"))
	hud.close_big_views()
	hud.hide_banner()
	# Find a world with a cave and photograph the chamber.
	for sv in [11, 22, 33, 44, 55, 66, 77, 88]:
		start_random(sv)
		var cave_chest: Interactable = null
		for s in structures:
			if s.display_name == "cave chest":
				cave_chest = s
		if cave_chest:
			player.cam.make_current()
			var other: Interactable = null
			for s in structures:
				if s.display_name in ["stashed crate", "buried urn"]:
					other = s
			var mid := cave_chest.global_position
			if other:
				mid = (cave_chest.global_position + other.global_position) * 0.5
			player.global_position = mid + Vector3(0, 0.4, 0)
			var cv := cave_chest.global_position - player.global_position
			player.set_facing(atan2(-cv.x, -cv.z))
			player.set_target(cave_chest)
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(dir.path_join("shot_cave.png"))
			break
	# Find a world with a cellar: photograph the barn outside and the room.
	for sv in [11, 22, 33, 44, 55, 66, 77, 88, 5, 17]:
		start_random(sv)
		var crate: Interactable = null
		for s in structures:
			if s.display_name == "cellar crate":
				crate = s
		if crate == null:
			continue
		var barn: Node3D = null
		for ch in world.get_node("Village").get_children():
			if String(ch.name).contains("Barn") \
					and ch.global_position.distance_to(crate.global_position) < 12.0:
				barn = ch
				break
		if barn == null:
			continue
		var xcam := Camera3D.new()
		add_child(xcam)
		xcam.global_position = barn.global_transform * Vector3(11.0, 5.0, 9.0)
		xcam.look_at(barn.global_position + Vector3(0, 1.0, 0))
		xcam.current = true
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_cellar_ext.png"))
		player.cam.make_current()
		player.global_position = barn.global_transform * Vector3(2.2, -2.65, 0.0)
		player.velocity = Vector3.ZERO
		var cv2: Vector3 = crate.global_position - player.global_position
		player.set_facing(atan2(-cv2.x, -cv2.z))
		player.set_target(crate)
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_cellar.png"))
		break
	# Find a cavern well and photograph the cavern with the rope down.
	for sv in [11, 22, 33, 44, 55, 66, 77, 88, 5, 17]:
		start_random(sv)
		if well_drops.is_empty():
			continue
		var dr: Dictionary = well_drops[0]
		# First the sealed mouth from above, then the cavern with the rope.
		var wxcam := Camera3D.new()
		add_child(wxcam)
		wxcam.global_position = dr.axis + Vector3(3.5, 4.0, 3.5)
		wxcam.look_at(dr.axis + Vector3(0, 0.9, 0))
		wxcam.current = true
		await get_tree().create_timer(0.7).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_well_ext.png"))
		dr.rope.visible = true
		dr.cover.visible = false
		dr.cover_shape.set_deferred("disabled", true)
		player.global_position = dr.axis + Vector3(0.0, -6.3, -1.6)
		player.velocity = Vector3.ZERO
		var wcam := Camera3D.new()
		add_child(wcam)
		wcam.global_position = dr.axis + Vector3(-2.5, -4.7, -2.5)
		wcam.look_at(dr.axis + Vector3(1.5, -6.1, 1.5))
		wcam.current = true
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_wellcave.png"))
		break
	# A roofdeck house with its ladder.
	for sv in range(100, 140):
		start_random(sv)
		var lad: Dictionary = {}
		for c in climbables:
			if c.get("free", false):
				lad = c
				break
		if lad.is_empty():
			continue
		var rcam := Camera3D.new()
		add_child(rcam)
		rcam.global_position = lad.axis + Vector3(5.5, 3.0, 4.5)
		rcam.look_at(lad.axis + Vector3(-1.5, 2.2, 0.0))
		rcam.current = true
		await get_tree().create_timer(0.8).timeout
		get_viewport().get_texture().get_image().save_png(dir.path_join("shot_roofdeck.png"))
		break
	get_tree().quit()
