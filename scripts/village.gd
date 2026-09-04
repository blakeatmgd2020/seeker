class_name Village
## Village generation in two passes: layout() decides building positions
## (so foundation cuts can be carved into the terrain before it is built),
## then construct() raises the buildings in the biome's architectural style
## and returns the structure specs inside them.


## Lays out every village. `vils` is [{c: Vector2, n: buildings, rf: radius}].
## Some buildings hold nodes, most may be empty; barns can roll cellars.
static func layout(terrain: Terrain, wrng: RandomNumberGenerator, biome: Dictionary,
		vils: Array) -> Dictionary:
	var buildings: Array = []
	var loose: Array = []
	var wells: Array = []
	for vd in vils:
		var placed: Array[Vector2] = []
		# Village wells: some hide a cavern below (rope territory), and a
		# cavern may or may not hold a cache.
		var cavern := wrng.randf() < 0.5
		wells.append({c = vd.c, cavern = cavern,
			cache = cavern and wrng.randf() < 0.6})
		for bi in vd.n:
			var p := _spot(wrng, vd.c, placed, 6.0, maxf(vd.rf - 3.0, 8.0), 11.0)
			var kind := "barn" if wrng.randf() < 0.25 else "house"
			var variant := "single"
			if kind == "house":
				var vr := wrng.randf()
				if vr < 0.18:
					variant = "tworoom"
				elif vr < 0.36:
					variant = "twostory"
				elif vr < 0.5:
					variant = "roofdeck"
			buildings.append({kind = kind, pos = p, yaw = wrng.randf_range(0.0, 360.0),
				node = false, basement = false, variant = variant, cellar_node = false})
		var lpts: Array[Vector2] = []
		for i in wrng.randi_range(0, 2):
			if loose.size() >= 6:
				break
			var row: Array = biome.village_loose[
				wrng.randi_range(0, biome.village_loose.size() - 1)]
			var lp := _loose_spot(wrng, vd.c, placed, lpts)
			loose.append({kind = row[0], display = row[1], x = lp.x, z = lp.y})
			lpts.append(lp)
	# Choose which buildings hold nodes — empty buildings are fine.
	var idxs: Array = range(buildings.size())
	for i in range(idxs.size() - 1, 0, -1):
		var j := wrng.randi_range(0, i)
		var tmp = idxs[i]
		idxs[i] = idxs[j]
		idxs[j] = tmp
	var max_nodes := clampi(buildings.size(), 0, 8)
	var node_n := 0
	if max_nodes > 0:
		node_n = wrng.randi_range(1, max_nodes)
	for k in node_n:
		buildings[idxs[k]].node = true
	# Cellars: barns and plain houses can dig down (up to three per world);
	# a cellar may well be empty.
	var cellars := 0
	for b in buildings:
		if cellars >= 3:
			break
		var can_dig: bool = b.kind == "barn" \
			or (b.kind == "house" and b.variant in ["single", "roofdeck"])
		var odds := 0.4 if b.kind == "barn" else 0.18
		if can_dig and wrng.randf() < odds:
			b.basement = true
			b.cellar_node = wrng.randf() < 0.65
			cellars += 1
	# Guarantee at least one cavern well when any village exists.
	if not wells.is_empty():
		var any_cav := false
		for wd in wells:
			any_cav = any_cav or wd.cavern
		if not any_cav:
			wells[0].cavern = true
			wells[0].cache = wrng.randf() < 0.6
	return {buildings = buildings, wells = wells, loose = loose}


static func construct(parent: Node3D, terrain: Terrain, lay: Dictionary,
		biome: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Village"
	parent.add_child(root)
	var style: String = biome.village_style
	var specs: Array = []
	var excl: Array = []
	var drops: Array = []
	var ladders: Array = []
	var perches: Array = []
	for b in lay.buildings:
		var res: Dictionary
		if b.kind == "house":
			res = _house(root, terrain, b.pos, b.yaw, style,
				b.get("variant", "single"), b.basement)
			if b.node:
				specs.append({kind = "wardrobe", display = "wardrobe", xform = res.ward})
			excl.append(Vector3(b.pos.x, b.pos.y, 9.0))
		else:
			res = _barn(root, terrain, b.pos, b.yaw, style, b.basement)
			if b.node:
				specs.append({kind = "chest", display = "old chest", xform = res.chest})
			excl.append(Vector3(b.pos.x, b.pos.y, 10.0))
		if res.has("cellar") and b.get("cellar_node", false):
			specs.append({kind = "crate", display = "cellar crate", xform = res.cellar})
		if res.has("ladder"):
			ladders.append(res.ladder)
		if res.has("perch"):
			perches.append(res.perch)
	for wd in lay.wells:
		var wres := _well(root, terrain, wd.c, style, wd.get("cavern", false),
			wd.get("cache", false))
		if wres.has("spec"):
			specs.append(wres.spec)
		if wres.has("drop"):
			drops.append(wres.drop)
		excl.append(Vector3(wd.c.x, wd.c.y, 3.0))
	specs += lay.loose
	return {specs = specs, exclusions = excl, drops = drops,
		ladders = ladders, perches = perches}


static func _spot(wrng: RandomNumberGenerator, vc: Vector2, placed: Array[Vector2],
		rmin: float, rmax: float, gap: float) -> Vector2:
	for i in 80:
		var a := wrng.randf_range(0.0, TAU)
		var p := vc + Vector2(cos(a), sin(a)) * wrng.randf_range(rmin, rmax)
		var ok := true
		for q in placed:
			if (p - q).length() < gap:
				ok = false
				break
		if ok:
			placed.append(p)
			return p
	var f := vc + Vector2(wrng.randf_range(-24.0, 24.0), wrng.randf_range(-24.0, 24.0))
	placed.append(f)
	return f


static func _loose_spot(wrng: RandomNumberGenerator, vc: Vector2,
		placed: Array[Vector2], lpts: Array[Vector2]) -> Vector2:
	for i in 60:
		var a := wrng.randf_range(0.0, TAU)
		var p := vc + Vector2(cos(a), sin(a)) * wrng.randf_range(4.0, 26.0)
		var ok := (p - vc).length() > 2.5
		for q in placed:
			if (p - q).length() < 6.5:
				ok = false
				break
		for q in lpts:
			if (p - q).length() < 3.0:
				ok = false
				break
		if ok:
			return p
	return vc + Vector2(wrng.randf_range(-20.0, 20.0), wrng.randf_range(-20.0, 20.0))


static func _style_mats(style: String) -> Dictionary:
	match style:
		"timber":
			return {wall = TexF.mat("timber"), roof = TexF.mat("roof_brown"),
				barn_wall = TexF.mat("timber"), barn_roof = TexF.mat("roof_brown")}
		"alpine":
			return {wall = TexF.mat("logwall"), roof = TexF.mat("roof_dark"),
				barn_wall = TexF.mat("logwall"), barn_roof = TexF.mat("roof_dark")}
		"adobe":
			return {wall = TexF.mat("adobe"), roof = TexF.mat("clay"),
				barn_wall = TexF.mat("adobe"), barn_roof = TexF.mat("clay")}
		_:
			return {wall = TexF.mat("plaster"), roof = TexF.mat("roof"),
				barn_wall = TexF.mat("plank"), barn_roof = TexF.mat("roof_dark")}


## Interior floor surface height above the building origin (foundation top
## plus the wooden floor veneer). Everything indoors rests on this plane.
const FLOOR_TOP := 0.5
const FOUND_TOP := 0.45


## Shared shell: foundation with entry steps, floor, walls with a door gap.
static func _shell(root: Node3D, terrain: Terrain, pos: Vector2, yaw: float,
		w: float, d: float, h: float, door_w: float, door_h: float,
		wall: Material, _foundation_h: float, stair_hole := 0.0) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	b.rotation_degrees.y = yaw
	var t := 0.25
	var F := FOUND_TOP
	if stair_hole > 0.0:
		# Foundation and floor with the cellar stairwell cut out: a central
		# opening along the long axis (half-length `stair_hole`), wide and
		# tall enough to walk down standing. The foundation is widened so it
		# covers every terrain quad the hole can remove (rect + ~3 m).
		_hole_slab(b, -6.5, 6.5, -(d + 0.5) * 0.5, (d + 0.5) * 0.5,
			-stair_hole, stair_hole, -0.85, 0.85, 0.0, 0.9, TexF.mat("stone"))
		_hole_slab(b, -(w - 0.4) * 0.5, (w - 0.4) * 0.5, -(d - 0.4) * 0.5, (d - 0.4) * 0.5,
			-stair_hole, stair_hole, -0.85, 0.85, 0.475, 0.05, TexF.mat("floor"))
	else:
		Util.box(b, Vector3(w + 0.5, 0.9, d + 0.5), Vector3(0, 0.0, 0), TexF.mat("stone"))
		Util.box(b, Vector3(w - 0.4, 0.05, d - 0.4), Vector3(0, 0.475, 0), TexF.mat("floor"))
	Util.box(b, Vector3(w, h, t), Vector3(0, F + h * 0.5, -d * 0.5 + t * 0.5), wall)
	Util.box(b, Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, F + h * 0.5, 0), wall)
	Util.box(b, Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, F + h * 0.5, 0), wall)
	var seg := (w - door_w) * 0.5
	var fz := d * 0.5 - t * 0.5
	Util.box(b, Vector3(seg, h, t), Vector3(-(door_w * 0.5 + seg * 0.5), F + h * 0.5, fz), wall)
	Util.box(b, Vector3(seg, h, t), Vector3(door_w * 0.5 + seg * 0.5, F + h * 0.5, fz), wall)
	Util.box(b, Vector3(door_w, h - door_h, t),
		Vector3(0, F + door_h + (h - door_h) * 0.5, fz), wall)
	# Entry steps: the visible steps carry NO collision — CharacterBody3D
	# cannot climb vertical ledges, so an invisible ramp does the real work.
	var sw := door_w + 0.7
	Util.box(b, Vector3(sw, 0.3, 0.6), Vector3(0, 0.15, d * 0.5 + 0.55), TexF.mat("stone"), false)
	Util.box(b, Vector3(sw, 0.15, 0.6), Vector3(0, 0.075, d * 0.5 + 1.15), TexF.mat("stone"), false)
	Util.shape_box(b, Vector3(sw, 0.12, 1.55), Vector3(0, 0.21, d * 0.5 + 0.82),
		Vector3(20.5, 0, 0))
	return b


static func _house(root: Node3D, terrain: Terrain, pos: Vector2, yaw: float,
		style: String, variant := "single", basement := false) -> Dictionary:
	var m := _style_mats(style)
	var w := 11.0 if variant == "tworoom" else 8.0
	var d := 6.0
	var h := 5.45 if variant == "twostory" else 3.0
	var t := 0.25
	var flat_roof: bool = style == "adobe" or variant == "roofdeck"
	var b := _shell(root, terrain, pos, yaw, w, d, h, 1.6, 2.3, m.wall, 0.9,
		2.6 if basement else 0.0)
	b.name = "House"
	var F := FOUND_TOP
	var fz := d * 0.5 - t * 0.5
	var wood := TexF.mat("wood")
	# Door trim overlaps into the walls so no faces share a plane.
	Util.box(b, Vector3(0.16, 2.3, t + 0.08), Vector3(-0.85, F + 1.15, fz), wood, false)
	Util.box(b, Vector3(0.16, 2.3, t + 0.08), Vector3(0.85, F + 1.15, fz), wood, false)
	Util.box(b, Vector3(1.9, 0.2, t + 0.08), Vector3(0, F + 2.38, fz), wood, false)
	var win_h := 0.6 if style == "adobe" else 0.9
	for wz in [-1.4, 1.4]:
		Util.box(b, Vector3(0.08, win_h, 1.0), Vector3(-w * 0.5 - 0.02, F + 1.7, wz), TexF.mat("window"), false)
		Util.box(b, Vector3(0.08, win_h, 1.0), Vector3(w * 0.5 + 0.02, F + 1.7, wz), TexF.mat("window"), false)

	var res := {}
	if flat_roof:
		# Flat roof slab with a parapet (walkable on the roofdeck variant).
		Util.box(b, Vector3(w + 0.6, 0.3, d + 0.6), Vector3(0, F + h + 0.15, 0), m.wall)
		for pr in [[Vector3(0, F + h + 0.5, -d * 0.5 - 0.2), Vector3(w + 0.6, 0.4, 0.2)],
				[Vector3(0, F + h + 0.5, d * 0.5 + 0.2), Vector3(w + 0.6, 0.4, 0.2)],
				[Vector3(-w * 0.5 - 0.2, F + h + 0.5, 0), Vector3(0.2, 0.4, d + 0.6)],
				[Vector3(w * 0.5 + 0.2, F + h + 0.5, 0), Vector3(0.2, 0.4, d + 0.6)]]:
			Util.box(b, pr[1], pr[0], m.wall, false)
		if style == "adobe":
			for vx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
				Util.cyl(b, 0.09, 0.09, 0.5, Vector3(vx, F + h - 0.25, fz + 0.2),
					TexF.mat("darkwood"), Vector3(90, 0, 0), 8)
		res.perch = b.transform * Transform3D(Basis(),
			Vector3(w * 0.5 - 0.6, F + h + 0.8, d * 0.5 - 0.6))
	elif style == "alpine":
		var roof := PrismMesh.new()
		roof.size = Vector3(w + 1.4, 2.8, d + 1.4)
		roof.material = m.roof
		Util.mesh(b, roof, Vector3(0, F + h + 1.4, 0))
		var snow := PrismMesh.new()
		snow.size = Vector3(w + 1.5, 0.5, d + 1.5)
		snow.material = TexF.mat("snow")
		Util.mesh(b, snow, Vector3(0, F + h + 2.75, 0))
		Util.box(b, Vector3(0.7, 2.2, 0.7), Vector3(w * 0.5 - 1.2, F + h + 1.2, -d * 0.5 + 1.4),
			TexF.mat("stone"), false)
		Util.box(b, Vector3(0.8, 0.15, 0.8), Vector3(w * 0.5 - 1.2, F + h + 2.35, -d * 0.5 + 1.4),
			TexF.mat("snow"), false)
		res.perch = b.transform * Transform3D(Basis(), Vector3(0, F + h + 2.9, 0))
	else:
		var roof := PrismMesh.new()
		roof.size = Vector3(w + 1.2, 2.2, d + 1.2)
		roof.material = m.roof
		Util.mesh(b, roof, Vector3(0, F + h + 1.1, 0))
		if style == "timber":
			for iv in [Vector3(-2.6, F + 1.1, fz + 0.15), Vector3(3.1, F + 1.8, fz + 0.15)]:
				var ivy := SphereMesh.new()
				ivy.radius = 0.55
				ivy.height = 1.1
				ivy.material = TexF.mat("leaves_autumn1")
				var mi := Util.mesh(b, ivy, iv)
				mi.scale = Vector3(1.0, 1.2, 0.4)
		res.perch = b.transform * Transform3D(Basis(), Vector3(0, F + h + 2.3, 0))

	var ward_local := Vector3(1.2, FLOOR_TOP, -2.35)
	match variant:
		"tworoom":
			# A dividing wall with an inner doorway; the wardrobe hides in
			# the back room.
			Util.box(b, Vector3(0.25, h, 2.675), Vector3(1.0, F + h * 0.5, -1.5375), m.wall)
			Util.box(b, Vector3(0.25, h, 1.875), Vector3(1.0, F + h * 0.5, 1.9375), m.wall)
			ward_local = Vector3(3.6, FLOOR_TOP, -2.3)
		"twostory":
			# Upper floor slab with a stairwell over a straight west-side
			# stair; the wardrobe lives upstairs.
			_hole_slab(b, -(w - 0.4) * 0.5, (w - 0.4) * 0.5, -(d - 0.4) * 0.5, (d - 0.4) * 0.5,
				-3.75, -2.55, -2.35, 1.2, 3.45, 0.3, TexF.mat("floor"))
			for i in 10:
				Util.box(b, Vector3(1.1, 0.2, 0.5),
					Vector3(-3.15, 0.4 + (i + 1) * 0.31, 2.4 - (i + 0.5) * 0.5),
					wood, false)
			Util.shape_box(b, Vector3(1.1, 0.15, 5.95), Vector3(-3.15, 1.975, -0.1),
				Vector3(31.8, 0, 0))
			for wz in [-1.4, 1.4]:
				Util.box(b, Vector3(0.08, 0.9, 1.0), Vector3(-w * 0.5 - 0.02, F + 4.3, wz),
					TexF.mat("window"), false)
				Util.box(b, Vector3(0.08, 0.9, 1.0), Vector3(w * 0.5 + 0.02, F + 4.3, wz),
					TexF.mat("window"), false)
			var ul := OmniLight3D.new()
			ul.position = Vector3(0, 5.2, 0)
			ul.light_color = Color(1.0, 0.85, 0.6)
			ul.omni_range = 7.0
			ul.light_energy = 1.2
			b.add_child(ul)
			ward_local = Vector3(2.4, 3.6, -2.2)
		"roofdeck":
			# An outside ladder up the east wall — no irons needed.
			var lx := w * 0.5 + 0.18
			for rx in [-0.4, 0.4]:
				Util.box(b, Vector3(0.07, 3.9, 0.07), Vector3(lx, F + 1.75, rx), wood, false)
			for i in 8:
				Util.box(b, Vector3(0.07, 0.07, 0.86), Vector3(lx, 0.5 + i * 0.42, 0), wood, false)
			res.ladder = {axis = b.global_transform * Vector3(lx, 0, 0),
				top_y = b.position.y + F + h + 0.35, free = true}

	# Furniture rests on the interior floor plane.
	Util.box(b, Vector3(1.4, 0.08, 0.8), Vector3(2.4, FLOOR_TOP + 0.74, -1.6), wood, false)
	Util.box(b, Vector3(0.18, 0.7, 0.18), Vector3(2.4, FLOOR_TOP + 0.35, -1.6), wood, false)
	Util.box(b, Vector3(0.9, 0.35, 1.9), Vector3(-2.9, FLOOR_TOP + 0.175, 1.4), TexF.mat("blanket"))
	Util.box(b, Vector3(0.6, 0.14, 0.4), Vector3(-2.9, FLOOR_TOP + 0.42, 0.7), TexF.mat("pillow"), false)
	var wl := OmniLight3D.new()
	wl.position = Vector3(0, F + 2.5, 0)
	wl.light_color = Color(1.0, 0.85, 0.6)
	wl.omni_range = 7.0
	wl.light_energy = 1.4
	b.add_child(wl)
	if basement:
		res.cellar = b.transform * Transform3D(
			Basis(Vector3.UP, deg_to_rad(35.0)), _cellar(b, 2.6))
	res.ward = b.transform * Transform3D(Basis(), ward_local)
	return res


## Cuts a horizontal slab into four boxes around a rectangular hole.
static func _hole_slab(b: Node3D, rx0: float, rx1: float, rz0: float, rz1: float,
		hx0: float, hx1: float, hz0: float, hz1: float, yc: float, hgt: float,
		mat: Material) -> void:
	var pieces := [
		[rx0, rx1, rz0, hz0], [rx0, rx1, hz1, rz1],
		[rx0, hx0, hz0, hz1], [hx1, rx1, hz0, hz1]]
	for p in pieces:
		var sx: float = p[1] - p[0]
		var sz: float = p[3] - p[2]
		if sx < 0.05 or sz < 0.05:
			continue
		Util.box(b, Vector3(sx, hgt, sz),
			Vector3((p[0] + p[1]) * 0.5, yc, (p[2] + p[3]) * 0.5), mat)


static func _barn(root: Node3D, terrain: Terrain, pos: Vector2, yaw: float,
		style: String, with_basement := false) -> Dictionary:
	var m := _style_mats(style)
	var w := 10.0
	var d := 8.0
	var h := 3.6
	var b := _shell(root, terrain, pos, yaw, w, d, h, 3.0, 3.0, m.barn_wall, 0.9,
		3.3 if with_basement else 0.0)
	b.name = "Barn"
	var F := FOUND_TOP
	var fz := d * 0.5 - 0.125
	Util.box(b, Vector3(0.22, 3.0, 0.35), Vector3(-1.56, F + 1.5, fz), TexF.mat("darkwood"), false)
	Util.box(b, Vector3(0.22, 3.0, 0.35), Vector3(1.56, F + 1.5, fz), TexF.mat("darkwood"), false)
	if style == "adobe":
		Util.box(b, Vector3(w + 0.6, 0.3, d + 0.6), Vector3(0, F + h + 0.15, 0), m.barn_wall)
		for pr in [[Vector3(0, F + h + 0.5, -d * 0.5 - 0.2), Vector3(w + 0.6, 0.4, 0.2)],
				[Vector3(0, F + h + 0.5, d * 0.5 + 0.2), Vector3(w + 0.6, 0.4, 0.2)],
				[Vector3(-w * 0.5 - 0.2, F + h + 0.5, 0), Vector3(0.2, 0.4, d + 0.6)],
				[Vector3(w * 0.5 + 0.2, F + h + 0.5, 0), Vector3(0.2, 0.4, d + 0.6)]]:
			Util.box(b, pr[1], pr[0], m.barn_wall, false)
	else:
		var roof := PrismMesh.new()
		roof.size = Vector3(w + 1.4, 3.0 if style == "alpine" else 2.6, d + 1.4)
		roof.material = m.barn_roof
		Util.mesh(b, roof, Vector3(0, F + h + (1.5 if style == "alpine" else 1.3), 0))
		if style == "alpine":
			var snow := PrismMesh.new()
			snow.size = Vector3(w + 1.5, 0.5, d + 1.5)
			snow.material = TexF.mat("snow")
			Util.mesh(b, snow, Vector3(0, F + h + 2.95, 0))
	if style != "adobe":
		for sp in [Vector3(2.5, FLOOR_TOP + 0.03, -2.0), Vector3(-3.0, FLOOR_TOP + 0.03, 1.5)]:
			Util.cyl(b, 1.4, 1.5, 0.1, sp, TexF.mat("straw"), Vector3.ZERO, 12)
	var wl := OmniLight3D.new()
	wl.position = Vector3(0, F + 3.0, 0)
	wl.light_color = Color(1.0, 0.88, 0.65)
	wl.omni_range = 9.0
	wl.light_energy = 1.3
	b.add_child(wl)

	var res := {chest = b.transform * Transform3D(
		Basis(Vector3.UP, deg_to_rad(-20.0)), Vector3(-3.0, FLOOR_TOP, -2.4)),
		perch = b.transform * Transform3D(Basis(), Vector3(0, F + h + 2.8, 0)
			if style != "adobe" else Vector3(w * 0.5 - 0.6, F + h + 0.8, d * 0.5 - 0.6))}
	if with_basement:
		res.cellar = b.transform * Transform3D(
			Basis(Vector3.UP, deg_to_rad(35.0)), _cellar(b, 3.3))
	return res


## Underground cellar shared by barns and houses: a full-height room fully
## inside the building footprint (interior x ±3.5, z ±3.0, floor -2.75,
## ceiling -0.75), reached by a straight stair of half-run `run_half`
## descending east through the open stairwell cut in the floor. Nothing
## pokes outside the building, and abutting slabs overlap a little so no
## faces are coplanar. Returns the crate's local resting spot.
static func _cellar(b: StaticBody3D, run_half: float) -> Vector3:
	var stone := TexF.mat("stone")
	Util.box(b, Vector3(7.6, 0.3, 6.6), Vector3(0, -2.9, 0), stone)
	var x0 := -(run_half - 0.4)
	var x1 := run_half - 0.4
	var run := x1 - x0
	var slope := 3.25 / run
	# The ceiling opens above the stairs from where heads pass through it.
	var hx0 := x0 + 0.92 / slope - 0.35
	_hole_slab(b, -3.8, 3.8, -3.3, 3.3, hx0, 3.8, -0.85, 0.85, -0.585, 0.33, stone)
	Util.box(b, Vector3(0.3, 2.5, 6.6), Vector3(-3.65, -1.65, 0), stone)
	Util.box(b, Vector3(0.3, 2.5, 6.6), Vector3(3.65, -1.65, 0), stone)
	Util.box(b, Vector3(7.6, 2.5, 0.3), Vector3(0, -1.65, -3.15), stone)
	Util.box(b, Vector3(7.6, 2.5, 0.3), Vector3(0, -1.65, 3.15), stone)
	# Shallow treads (visual only) over an invisible ramp running flush
	# from the floor edge down to the cellar floor.
	var n := maxi(int(roundf(run / 0.58)), 6)
	var step_d := run / n
	var rise := 3.25 / n
	for i in n:
		Util.box(b, Vector3(step_d, 0.22, 1.6),
			Vector3(x0 + (i + 0.5) * step_d, 0.39 - (i + 1) * rise, 0), stone, false)
	var ang := rad_to_deg(atan2(3.25, run))
	Util.shape_box(b, Vector3(sqrt(run * run + 3.25 * 3.25), 0.15, 1.6),
		Vector3(0, -1.2, 0), Vector3(0, 0, -ang))
	# Lantern and the crate's corner.
	var cl := OmniLight3D.new()
	cl.position = Vector3(0, -1.0, 1.6)
	cl.light_color = Color(1.0, 0.8, 0.5)
	cl.omni_range = 8.0
	cl.light_energy = 1.2
	b.add_child(cl)
	Util.box(b, Vector3(0.2, 0.35, 0.2), Vector3(0, -0.95, 1.6), TexF.mat("metal"), false)
	return Vector3(-2.4, -2.75, 1.8)


static func _well(root: Node3D, terrain: Terrain, pos: Vector2, style: String,
		cavern := false, cache := false) -> Dictionary:
	var b := StaticBody3D.new()
	b.name = "Well"
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	var ring_mat := TexF.mat("clay") if style == "adobe" else TexF.mat("stone")
	Util.cyl(b, 1.1, 1.2, 1.0, Vector3(0, 0.5, 0), ring_mat)
	var res := {}
	if cavern:
		# An open shaft: hollow rim collision (four arcs), stone shaft walls
		# down through the terrain hole, and a cavern room at the bottom.
		var stone := TexF.mat("stone")
		for rw in [[Vector3(2.5, 1.0, 0.3), Vector3(0, 0.5, 1.05)],
				[Vector3(2.5, 1.0, 0.3), Vector3(0, 0.5, -1.05)],
				[Vector3(0.3, 1.0, 1.9), Vector3(1.05, 0.5, 0)],
				[Vector3(0.3, 1.0, 1.9), Vector3(-1.05, 0.5, 0)]]:
			Util.shape_box(b, rw[0], rw[1])
		Util.box(b, Vector3(0.35, 4.3, 2.5), Vector3(-1.07, -2.0, 0), stone)
		Util.box(b, Vector3(0.35, 4.3, 2.5), Vector3(1.07, -2.0, 0), stone)
		Util.box(b, Vector3(2.5, 4.3, 0.35), Vector3(0, -2.0, -1.07), stone)
		Util.box(b, Vector3(2.5, 4.3, 0.35), Vector3(0, -2.0, 1.07), stone)
		# Collar slab: covers everything the terrain hole can remove.
		_hole_slab(b, -4.4, 4.4, -4.4, 4.4, -1.1, 1.1, -1.1, 1.1, -0.25, 0.6, stone)
		# Cavern: interior x/z ±3.0, floor -6.35, ceiling -4.35.
		Util.box(b, Vector3(6.6, 0.3, 6.6), Vector3(0, -6.5, 0), stone)
		_hole_slab(b, -3.3, 3.3, -3.3, 3.3, -0.95, 0.95, -0.95, 0.95, -4.125, 0.35, stone)
		Util.box(b, Vector3(0.3, 2.5, 6.6), Vector3(-3.15, -5.15, 0), stone)
		Util.box(b, Vector3(0.3, 2.5, 6.6), Vector3(3.15, -5.15, 0), stone)
		Util.box(b, Vector3(6.6, 2.5, 0.3), Vector3(0, -5.15, -3.15), stone)
		Util.box(b, Vector3(6.6, 2.5, 0.3), Vector3(0, -5.15, 3.15), stone)
		for sm in [[-2.2, 2.0, 0.9], [2.4, -1.8, 0.7]]:
			Util.cyl(b, 0.03, 0.3, sm[2], Vector3(sm[0], -6.35 + sm[2] * 0.5, sm[1]),
				stone, Vector3.ZERO, 7)
		var gl := OmniLight3D.new()
		gl.position = Vector3(0, -5.0, 0)
		gl.light_color = Color(0.55, 0.72, 0.85)
		gl.omni_range = 8.0
		gl.light_energy = 1.3
		b.add_child(gl)
		# The rope appears once found; until then the shaft is a dark drop.
		var rope := Util.cyl(b, 0.045, 0.045, 8.4, Vector3(0.28, -2.1, 0.28),
			TexF.mat("darkwood"), Vector3.ZERO, 6)
		rope.visible = false
		res.drop = {axis = Vector3(pos.x, b.position.y, pos.y),
			rim_y = b.position.y + 1.0, floor_y = b.position.y - 6.35,
			rope = rope}
		if cache:
			res.spec = {kind = "crate", display = "well cache",
				xform = b.transform * Transform3D(
					Basis(Vector3.UP, deg_to_rad(50.0)), Vector3(1.9, -6.35, 1.9))}
	else:
		Util.cyl(b, 0.85, 0.85, 0.1, Vector3(0, 1.02, 0), TexF.plain(Color(0.05, 0.08, 0.1)), Vector3.ZERO, 14)
		Util.shape_cyl(b, 1.2, 1.0, Vector3(0, 0.5, 0))
	if style == "adobe":
		Util.box(b, Vector3(2.6, 0.14, 0.14), Vector3(0, 1.6, 0), TexF.mat("darkwood"), false)
		for px in [-1.15, 1.15]:
			Util.box(b, Vector3(0.14, 1.2, 0.14), Vector3(px, 1.0, 0), TexF.mat("darkwood"), false)
	else:
		for px in [-1.0, 1.0]:
			Util.box(b, Vector3(0.14, 2.2, 0.14), Vector3(px, 1.6, 0), TexF.mat("darkwood"), false)
		var roof := PrismMesh.new()
		roof.size = Vector3(2.8, 0.9, 2.2)
		roof.material = TexF.mat("roof_dark") if style == "alpine" else TexF.mat("roof")
		Util.mesh(b, roof, Vector3(0, 2.9, 0))
		if style == "alpine":
			var snow := PrismMesh.new()
			snow.size = Vector3(2.9, 0.25, 2.3)
			snow.material = TexF.mat("snow")
			Util.mesh(b, snow, Vector3(0, 3.42, 0))
	return res
