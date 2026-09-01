class_name Village
## Village generation in two passes: layout() decides building positions
## (so foundation cuts can be carved into the terrain before it is built),
## then construct() raises the buildings in the biome's architectural style
## and returns the structure specs inside them.


static func layout(terrain: Terrain, wrng: RandomNumberGenerator, biome: Dictionary) -> Dictionary:
	var vc := terrain.village_center
	var placed: Array[Vector2] = []
	var buildings: Array = []
	for i in wrng.randi_range(3, 4):
		var p := _spot(wrng, vc, placed, 9.0, 24.0, 12.0)
		buildings.append({kind = "house", pos = p, yaw = wrng.randf_range(0.0, 360.0)})
	var bp := _spot(wrng, vc, placed, 12.0, 26.0, 14.0)
	buildings.append({kind = "barn", pos = bp, yaw = wrng.randf_range(0.0, 360.0)})

	var loose: Array = []
	var lpts: Array[Vector2] = []
	for l in biome.village_loose:
		for i in wrng.randi_range(l[2], l[3]):
			var p := _loose_spot(wrng, vc, placed, lpts)
			loose.append({kind = l[0], display = l[1], x = p.x, z = p.y})
			lpts.append(p)
	return {buildings = buildings, well = vc, loose = loose}


static func construct(parent: Node3D, terrain: Terrain, lay: Dictionary,
		biome: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "Village"
	parent.add_child(root)
	var style: String = biome.village_style
	var specs: Array = []
	var excl: Array = []
	for b in lay.buildings:
		if b.kind == "house":
			var ward_xf := _house(root, terrain, b.pos, b.yaw, style)
			specs.append({kind = "wardrobe", display = "wardrobe", xform = ward_xf})
			excl.append(Vector3(b.pos.x, b.pos.y, 9.0))
		else:
			var chest_xf := _barn(root, terrain, b.pos, b.yaw, style)
			specs.append({kind = "chest", display = "old chest", xform = chest_xf})
			excl.append(Vector3(b.pos.x, b.pos.y, 10.0))
	_well(root, terrain, lay.well, style)
	excl.append(Vector3(lay.well.x, lay.well.y, 3.0))
	specs += lay.loose
	return {specs = specs, exclusions = excl}


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
		wall: Material, _foundation_h: float) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	b.rotation_degrees.y = yaw
	var t := 0.25
	var F := FOUND_TOP
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
		style: String) -> Transform3D:
	var m := _style_mats(style)
	var w := 8.0
	var d := 6.0
	var h := 3.0
	var t := 0.25
	var b := _shell(root, terrain, pos, yaw, w, d, h, 1.6, 2.3, m.wall, 0.9)
	b.name = "House"
	var F := FOUND_TOP
	var fz := d * 0.5 - t * 0.5
	var wood := TexF.mat("wood")
	Util.box(b, Vector3(0.12, 2.3, t + 0.08), Vector3(-0.86, F + 1.15, fz), wood, false)
	Util.box(b, Vector3(0.12, 2.3, t + 0.08), Vector3(0.86, F + 1.15, fz), wood, false)
	Util.box(b, Vector3(1.9, 0.14, t + 0.08), Vector3(0, F + 2.36, fz), wood, false)
	var win_h := 0.6 if style == "adobe" else 0.9
	for wz in [-1.4, 1.4]:
		Util.box(b, Vector3(0.08, win_h, 1.0), Vector3(-w * 0.5 - 0.02, F + 1.7, wz), TexF.mat("window"), false)
		Util.box(b, Vector3(0.08, win_h, 1.0), Vector3(w * 0.5 + 0.02, F + 1.7, wz), TexF.mat("window"), false)

	match style:
		"adobe":
			# Flat roof slab with a parapet and viga beam ends.
			Util.box(b, Vector3(w + 0.6, 0.3, d + 0.6), Vector3(0, F + h + 0.15, 0), m.wall)
			for pr in [[Vector3(0, F + h + 0.5, -d * 0.5 - 0.2), Vector3(w + 0.6, 0.4, 0.2)],
					[Vector3(0, F + h + 0.5, d * 0.5 + 0.2), Vector3(w + 0.6, 0.4, 0.2)],
					[Vector3(-w * 0.5 - 0.2, F + h + 0.5, 0), Vector3(0.2, 0.4, d + 0.6)],
					[Vector3(w * 0.5 + 0.2, F + h + 0.5, 0), Vector3(0.2, 0.4, d + 0.6)]]:
				Util.box(b, pr[1], pr[0], m.wall, false)
			for vx in [-3.0, -1.5, 0.0, 1.5, 3.0]:
				Util.cyl(b, 0.09, 0.09, 0.5, Vector3(vx, F + h - 0.25, fz + 0.2),
					TexF.mat("darkwood"), Vector3(90, 0, 0), 8)
		"alpine":
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
		_:
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
	return b.transform * Transform3D(Basis(), Vector3(1.2, FLOOR_TOP, -2.35))


static func _barn(root: Node3D, terrain: Terrain, pos: Vector2, yaw: float,
		style: String) -> Transform3D:
	var m := _style_mats(style)
	var w := 10.0
	var d := 8.0
	var h := 3.6
	var b := _shell(root, terrain, pos, yaw, w, d, h, 3.0, 3.0, m.barn_wall, 0.9)
	b.name = "Barn"
	var F := FOUND_TOP
	var fz := d * 0.5 - 0.125
	Util.box(b, Vector3(0.15, 3.0, 0.35), Vector3(-1.55, F + 1.5, fz), TexF.mat("darkwood"), false)
	Util.box(b, Vector3(0.15, 3.0, 0.35), Vector3(1.55, F + 1.5, fz), TexF.mat("darkwood"), false)
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
	return b.transform * Transform3D(Basis(Vector3.UP, deg_to_rad(-20.0)), Vector3(-3.0, FLOOR_TOP, -2.4))


static func _well(root: Node3D, terrain: Terrain, pos: Vector2, style: String) -> void:
	var b := StaticBody3D.new()
	b.name = "Well"
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	var ring_mat := TexF.mat("clay") if style == "adobe" else TexF.mat("stone")
	Util.cyl(b, 1.1, 1.2, 1.0, Vector3(0, 0.5, 0), ring_mat)
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
