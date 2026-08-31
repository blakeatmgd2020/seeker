class_name Village
## Builds the central village: three houses, a barn, a well. Returns the
## structure specs (wardrobes/chest inside buildings + loose village items)
## and exclusion circles for vegetation.


static func build(parent: Node3D, terrain: Terrain, wrng: RandomNumberGenerator) -> Dictionary:
	var root := Node3D.new()
	root.name = "Village"
	parent.add_child(root)
	var specs: Array = []
	var excl: Array = []
	var vc := terrain.village_center
	var placed: Array[Vector2] = []

	var n_houses := wrng.randi_range(3, 4)
	for i in n_houses:
		var p := _building_spot(wrng, vc, placed, 9.0, 24.0, 12.0)
		var ward_xf := _house(root, terrain, p, wrng.randf_range(0.0, 360.0))
		specs.append({kind = "wardrobe", display = "wardrobe", xform = ward_xf})
		excl.append(Vector3(p.x, p.y, 9.0))

	var bp := _building_spot(wrng, vc, placed, 12.0, 26.0, 14.0)
	var chest_xf := _barn(root, terrain, bp, wrng.randf_range(0.0, 360.0))
	specs.append({kind = "chest", display = "old chest", xform = chest_xf})
	excl.append(Vector3(bp.x, bp.y, 10.0))

	_well(root, terrain, vc)
	excl.append(Vector3(vc.x, vc.y, 3.0))

	var loose := [["crate", "crate", wrng.randi_range(1, 3)],
		["barrel", "barrel", wrng.randi_range(1, 2)],
		["haystack", "haystack", 1]]
	var lpts: Array[Vector2] = []
	for l in loose:
		for i in l[2]:
			var p := _loose_spot(wrng, vc, placed, lpts)
			specs.append({kind = l[0], display = l[1], x = p.x, z = p.y, pad = false})
			lpts.append(p)
	return {specs = specs, exclusions = excl}


static func _building_spot(wrng: RandomNumberGenerator, vc: Vector2,
		placed: Array[Vector2], rmin: float, rmax: float, gap: float) -> Vector2:
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


static func _house(root: Node3D, terrain: Terrain, pos: Vector2, yaw: float) -> Transform3D:
	var b := StaticBody3D.new()
	b.name = "House"
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	b.rotation_degrees.y = yaw

	var plaster := TexF.mat("plaster")
	var wood := TexF.mat("wood")
	var w := 8.0
	var d := 6.0
	var h := 3.0
	var t := 0.25
	Util.box(b, Vector3(w + 0.5, 0.5, d + 0.5), Vector3(0, -0.15, 0), TexF.mat("stone"))
	Util.box(b, Vector3(w - 0.4, 0.15, d - 0.4), Vector3(0, 0.12, 0), TexF.mat("floor"))
	Util.box(b, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5 + t * 0.5), plaster)
	Util.box(b, Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), plaster)
	Util.box(b, Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), plaster)
	# front wall with a door gap (1.6 wide x 2.3 high)
	var seg := (w - 1.6) * 0.5
	var fz := d * 0.5 - t * 0.5
	Util.box(b, Vector3(seg, h, t), Vector3(-(0.8 + seg * 0.5), h * 0.5, fz), plaster)
	Util.box(b, Vector3(seg, h, t), Vector3(0.8 + seg * 0.5, h * 0.5, fz), plaster)
	Util.box(b, Vector3(1.6, h - 2.3, t), Vector3(0, 2.3 + (h - 2.3) * 0.5, fz), plaster)
	# door frame trim
	Util.box(b, Vector3(0.12, 2.3, t + 0.08), Vector3(-0.86, 1.15, fz), wood, false)
	Util.box(b, Vector3(0.12, 2.3, t + 0.08), Vector3(0.86, 1.15, fz), wood, false)
	Util.box(b, Vector3(1.9, 0.14, t + 0.08), Vector3(0, 2.36, fz), wood, false)
	# windows (dark inset panes on the side walls)
	for wz in [-1.4, 1.4]:
		Util.box(b, Vector3(0.08, 0.9, 1.0), Vector3(-w * 0.5 - 0.02, 1.7, wz),
			TexF.mat("window"), false)
		Util.box(b, Vector3(0.08, 0.9, 1.0), Vector3(w * 0.5 + 0.02, 1.7, wz),
			TexF.mat("window"), false)
	# roof
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.2, 2.2, d + 1.2)
	roof.material = TexF.mat("roof")
	Util.mesh(b, roof, Vector3(0, h + 1.1, 0))
	# furniture
	Util.box(b, Vector3(1.4, 0.08, 0.8), Vector3(2.4, 0.78, -1.6), wood, false)
	Util.box(b, Vector3(0.18, 0.75, 0.18), Vector3(2.4, 0.4, -1.6), wood, false)
	Util.box(b, Vector3(0.9, 0.35, 1.9), Vector3(-2.9, 0.35, 1.4), TexF.mat("blanket"))
	Util.box(b, Vector3(0.6, 0.14, 0.4), Vector3(-2.9, 0.6, 0.7), TexF.mat("pillow"), false)
	var wl := OmniLight3D.new()
	wl.position = Vector3(0, 2.5, 0)
	wl.light_color = Color(1.0, 0.85, 0.6)
	wl.omni_range = 7.0
	wl.light_energy = 1.4
	b.add_child(wl)

	var ward_local := Transform3D(Basis(), Vector3(1.2, 0.2, -2.35))
	return b.transform * ward_local


static func _barn(root: Node3D, terrain: Terrain, pos: Vector2, yaw: float) -> Transform3D:
	var b := StaticBody3D.new()
	b.name = "Barn"
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	b.rotation_degrees.y = yaw

	var plank := TexF.mat("plank")
	var w := 10.0
	var d := 8.0
	var h := 3.6
	var t := 0.25
	Util.box(b, Vector3(w + 0.5, 0.5, d + 0.5), Vector3(0, -0.15, 0), TexF.mat("stone"))
	Util.box(b, Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5 + t * 0.5), plank)
	Util.box(b, Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), plank)
	Util.box(b, Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), plank)
	var seg := (w - 3.0) * 0.5
	var fz := d * 0.5 - t * 0.5
	Util.box(b, Vector3(seg, h, t), Vector3(-(1.5 + seg * 0.5), h * 0.5, fz), plank)
	Util.box(b, Vector3(seg, h, t), Vector3(1.5 + seg * 0.5, h * 0.5, fz), plank)
	Util.box(b, Vector3(3.0, h - 3.0, t), Vector3(0, 3.0 + (h - 3.0) * 0.5, fz), plank)
	Util.box(b, Vector3(0.15, 3.0, t + 0.1), Vector3(-1.55, 1.5, fz), TexF.mat("darkwood"), false)
	Util.box(b, Vector3(0.15, 3.0, t + 0.1), Vector3(1.55, 1.5, fz), TexF.mat("darkwood"), false)
	var roof := PrismMesh.new()
	roof.size = Vector3(w + 1.4, 2.6, d + 1.4)
	roof.material = TexF.mat("roof_dark")
	Util.mesh(b, roof, Vector3(0, h + 1.3, 0))
	# straw scattered on the floor
	for sp in [Vector3(2.5, 0.06, -2.0), Vector3(-3.0, 0.06, 1.5), Vector3(1.0, 0.06, 2.2)]:
		Util.cyl(b, 1.4, 1.5, 0.1, sp, TexF.mat("straw"), Vector3.ZERO, 12)
	var wl := OmniLight3D.new()
	wl.position = Vector3(0, 3.0, 0)
	wl.light_color = Color(1.0, 0.88, 0.65)
	wl.omni_range = 9.0
	wl.light_energy = 1.3
	b.add_child(wl)

	var chest_local := Transform3D(Basis(Vector3.UP, deg_to_rad(-20.0)), Vector3(-3.0, 0.1, -2.4))
	return b.transform * chest_local


static func _well(root: Node3D, terrain: Terrain, pos: Vector2) -> void:
	var b := StaticBody3D.new()
	b.name = "Well"
	b.collision_layer = 1
	root.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	Util.cyl(b, 1.1, 1.2, 1.0, Vector3(0, 0.5, 0), TexF.mat("stone"))
	Util.cyl(b, 0.85, 0.85, 0.1, Vector3(0, 1.02, 0), TexF.plain(Color(0.05, 0.08, 0.1)), Vector3.ZERO, 14)
	Util.shape_cyl(b, 1.2, 1.0, Vector3(0, 0.5, 0))
	for px in [-1.0, 1.0]:
		Util.box(b, Vector3(0.14, 2.2, 0.14), Vector3(px, 1.6, 0), TexF.mat("darkwood"), false)
	var roof := PrismMesh.new()
	roof.size = Vector3(2.8, 0.9, 2.2)
	roof.material = TexF.mat("roof")
	Util.mesh(b, roof, Vector3(0, 2.9, 0))
