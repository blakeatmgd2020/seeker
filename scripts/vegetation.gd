class_name Vegetation
## Biome-driven flora scattering via MultiMeshes. Trees stay vertical (they
## grow toward the sun) and sink by the local slope drop so no base floats;
## decor (bushes, flowers, litter) hugs the ground; boulders get collision.


## Returns a handful of treetop points birds can perch on.
static func build(parent: Node3D, terrain: Terrain, exclusions: Array, sd: int,
		biome: Dictionary) -> Array:
	var perches: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var fnoise := FastNoiseLite.new()
	fnoise.seed = 999
	fnoise.frequency = 0.007

	var root := Node3D.new()
	root.name = "Vegetation"
	parent.add_child(root)
	var cols := StaticBody3D.new()
	cols.name = "TreeColliders"
	cols.collision_layer = 1
	root.add_child(cols)

	var v: Dictionary = biome.veg
	# Trees: [mesh, count, trunk radius]
	var tree_sets: Array = []
	if v.pine > 0:
		tree_sets.append([_pine_mesh(false), v.pine, 0.32])
	if v.snow_pine > 0:
		tree_sets.append([_pine_mesh(true), v.snow_pine, 0.32])
	if v.oak > 0:
		tree_sets.append([_oak_mesh("leaves"), v.oak, 0.36])
	if v.autumn_oak > 0:
		for li in 3:
			tree_sets.append([_oak_mesh("leaves_autumn%d" % (li + 1)),
				int(v.autumn_oak / 3.0), 0.36])
	if v.bare > 0:
		tree_sets.append([_bare_tree_mesh("bark"), v.bare, 0.28])
	if v.dead > 0:
		tree_sets.append([_bare_tree_mesh("deadwood"), v.dead, 0.28])
	if v.saguaro > 0:
		tree_sets.append([_saguaro_mesh(), v.saguaro, 0.34])

	for ts in tree_sets:
		var xforms: Array[Transform3D] = []
		var attempts := 0
		while xforms.size() < ts[1] and attempts < ts[1] * 30:
			attempts += 1
			var x := rng.randf_range(-235.0, 235.0)
			var z := rng.randf_range(-235.0, 235.0)
			var h := terrain.height_at(x, z)
			if h < terrain.water_y + 1.8:
				continue
			if terrain.normal_at(x, z).y < 0.76:
				continue
			if biome.id != "desert" and fnoise.get_noise_2d(x, z) < 0.03:
				continue
			if _excluded(exclusions, x, z):
				continue
			var sc := rng.randf_range(0.85, 1.4)
			var sink := terrain.drop_under(Vector2(x, z), 1.0) * 0.8 + 0.2
			var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc, sc))
			xforms.append(Transform3D(basis, Vector3(x, h - sink, z)))
			if xforms.size() % 25 == 1 and perches.size() < 14:
				perches.append(Vector3(x, h - sink + 4.4 * sc, z))
			var cs := CollisionShape3D.new()
			var sh := CylinderShape3D.new()
			sh.radius = ts[2] * sc
			sh.height = 5.0
			cs.shape = sh
			cs.position = Vector3(x, h + 2.5, z)
			cols.add_child(cs)
		_add_multimesh(root, ts[0], xforms)

	# Ground decor (no collision).
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _bush_mesh("leaves"), v.bush, 40.0, true)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _bush_mesh("leaves_autumn1"), v.autumn_bush, 40.0, true)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _bush_mesh("dry_bush"), v.dry_bush, 40.0, false)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _barrel_cactus_mesh(), v.barrel_cactus, 45.0, false)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _mushroom_mesh(), v.mushrooms, 45.0, true)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _litter_mesh(), v.leaf_litter, 35.0, false)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _tuft_mesh(), v.snow_tufts, 35.0, false)
	_scatter_decor(root, terrain, exclusions, rng, fnoise, _tumbleweed_mesh(), v.tumbleweed, 50.0, false)
	if v.flowers > 0:
		_scatter_flowers(root, terrain, exclusions, rng, v.flowers)

	# Small rocks (no collision).
	var rock_x: Array[Transform3D] = []
	for i in v.rocks * 4:
		if rock_x.size() >= v.rocks:
			break
		var x := rng.randf_range(-235.0, 235.0)
		var z := rng.randf_range(-235.0, 235.0)
		if _excluded(exclusions, x, z):
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 0.5:
			continue
		var sc := rng.randf_range(0.3, 1.1)
		var basis := Basis.from_euler(Vector3(rng.randf_range(0, 0.4), rng.randf_range(0, TAU),
			rng.randf_range(0, 0.4))).scaled(Vector3(sc, sc * 0.6, sc * rng.randf_range(0.7, 1.3)))
		rock_x.append(Transform3D(basis, Vector3(x, h + 0.05 - sc * 0.15, z)))
	_add_multimesh(root, _rock_mesh(), rock_x)

	# Big boulders with collision.
	var placed := 0
	for i in 400:
		if placed >= v.boulders:
			break
		var x := rng.randf_range(-220.0, 220.0)
		var z := rng.randf_range(-220.0, 220.0)
		if _excluded(exclusions, x, z):
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 0.5:
			continue
		placed += 1
		var sc := rng.randf_range(1.8, 3.5)
		var bm := SphereMesh.new()
		bm.radius = 1.0
		bm.height = 2.0
		bm.radial_segments = 8
		bm.rings = 5
		bm.material = TexF.mat("stone")
		var sink := terrain.drop_under(Vector2(x, z), sc * 0.6) * 0.7
		var mi := Util.mesh(cols, bm, Vector3(x, h + sc * 0.25 - sink, z),
			Vector3(rng.randf_range(0, 30), rng.randf_range(0, 360), rng.randf_range(0, 30)))
		mi.scale = Vector3(sc, sc * 0.7, sc * rng.randf_range(0.8, 1.2))
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = sc * 0.72
		cs.shape = sh
		cs.position = Vector3(x, h + sc * 0.2 - sink, z)
		cols.add_child(cs)
	return perches


static func _scatter_decor(root: Node3D, terrain: Terrain, exclusions: Array,
		rng: RandomNumberGenerator, fnoise: FastNoiseLite, mesh: Mesh, count: int,
		_min_r: float, forest_gate: bool) -> void:
	if count <= 0:
		return
	var xforms: Array[Transform3D] = []
	for i in count * 6:
		if xforms.size() >= count:
			break
		var x := rng.randf_range(-230.0, 230.0)
		var z := rng.randf_range(-230.0, 230.0)
		if _excluded(exclusions, x, z):
			continue
		if forest_gate and fnoise.get_noise_2d(x, z) < -0.1:
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 1.2 or terrain.normal_at(x, z).y < 0.8:
			continue
		var sc := rng.randf_range(0.6, 1.3)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc * 0.8, sc))
		xforms.append(Transform3D(basis, Vector3(x, h + 0.05, z)))
	_add_multimesh(root, mesh, xforms)


static func _scatter_flowers(root: Node3D, terrain: Terrain, exclusions: Array,
		rng: RandomNumberGenerator, count: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var fm := SphereMesh.new()
	fm.radius = 0.09
	fm.height = 0.14
	fm.radial_segments = 6
	fm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	fm.material = mat
	mm.mesh = fm
	var pts: Array = []
	for i in count * 5:
		if pts.size() >= count:
			break
		var x := rng.randf_range(-220.0, 220.0)
		var z := rng.randf_range(-220.0, 220.0)
		if _excluded(exclusions, x, z):
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 1.2 or terrain.normal_at(x, z).y < 0.85:
			continue
		pts.append(Vector3(x, h + 0.06, z))
	mm.instance_count = pts.size()
	var palette := [Color(1, 1, 1), Color(1.0, 0.9, 0.3), Color(0.9, 0.4, 0.6), Color(0.6, 0.5, 0.95)]
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
		mm.set_instance_color(i, palette[rng.randi_range(0, palette.size() - 1)])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)


static func _excluded(exclusions: Array, x: float, z: float) -> bool:
	for e in exclusions:
		if Vector2(x - e.x, z - e.y).length() < e.z:
			return true
	return false


static func _add_multimesh(root: Node3D, mesh: Mesh, xforms: Array[Transform3D]) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)


static func _pine_mesh(snowy: bool) -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.18
	trunk.bottom_radius = 0.34
	trunk.height = 3.6
	trunk.radial_segments = 10
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.8, 0)))
	st.commit(m)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in [[2.5, 2.9, 3.2], [2.0, 2.6, 4.7], [1.3, 2.3, 6.1]]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = layer[0]
		cone.height = layer[1]
		cone.radial_segments = 12
		st2.append_from(cone, 0, Transform3D(Basis(), Vector3(0, layer[2], 0)))
	st2.commit(m)
	m.surface_set_material(0, TexF.mat("bark"))
	m.surface_set_material(1, TexF.mat("leaves_dark"))
	if snowy:
		var st3 := SurfaceTool.new()
		st3.begin(Mesh.PRIMITIVE_TRIANGLES)
		for layer in [[2.1, 0.9, 4.35], [1.7, 0.8, 5.75], [1.1, 0.9, 7.0]]:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = layer[0]
			cone.height = layer[1]
			cone.radial_segments = 12
			st3.append_from(cone, 0, Transform3D(Basis(), Vector3(0, layer[2], 0)))
		st3.commit(m)
		m.surface_set_material(2, TexF.mat("snow"))
	return m


static func _oak_mesh(leaf_key: String) -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.4
	trunk.height = 3.0
	trunk.radial_segments = 10
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 1.5, 0)))
	st.commit(m)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var canopy := SphereMesh.new()
	canopy.radius = 1.7
	canopy.height = 3.4
	canopy.radial_segments = 10
	canopy.rings = 6
	for off in [Vector3(0, 3.9, 0), Vector3(1.0, 3.3, 0.5), Vector3(-0.9, 3.4, -0.4)]:
		st2.append_from(canopy, 0, Transform3D(Basis(), off))
	st2.commit(m)
	m.surface_set_material(0, TexF.mat("bark"))
	m.surface_set_material(1, TexF.mat(leaf_key))
	return m


static func _bare_tree_mesh(bark_key: String) -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.12
	trunk.bottom_radius = 0.3
	trunk.height = 4.2
	trunk.radial_segments = 8
	st.append_from(trunk, 0, Transform3D(Basis(), Vector3(0, 2.1, 0)))
	var branch := CylinderMesh.new()
	branch.top_radius = 0.03
	branch.bottom_radius = 0.09
	branch.height = 1.8
	branch.radial_segments = 6
	for b in [[Vector3(0.5, 3.1, 0), Vector3(0, 0, -50)], [Vector3(-0.45, 3.5, 0.2), Vector3(10, 0, 45)],
			[Vector3(0.1, 3.9, -0.45), Vector3(-48, 0, 5)], [Vector3(-0.15, 2.6, 0.4), Vector3(40, 0, 12)]]:
		var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(b[1].x),
			deg_to_rad(b[1].y), deg_to_rad(b[1].z))), b[0])
		st.append_from(branch, 0, xf)
	st.commit(m)
	m.surface_set_material(0, TexF.mat(bark_key))
	return m


static func _saguaro_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := CylinderMesh.new()
	body.top_radius = 0.28
	body.bottom_radius = 0.34
	body.height = 3.2
	body.radial_segments = 10
	st.append_from(body, 0, Transform3D(Basis(), Vector3(0, 1.6, 0)))
	var arm := CylinderMesh.new()
	arm.top_radius = 0.16
	arm.bottom_radius = 0.18
	arm.height = 1.1
	arm.radial_segments = 8
	st.append_from(arm, 0, Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(70))), Vector3(0.55, 1.6, 0)))
	st.append_from(arm, 0, Transform3D(Basis(), Vector3(0.95, 2.3, 0)))
	st.append_from(arm, 0, Transform3D(Basis.from_euler(Vector3(0, 0, deg_to_rad(-70))), Vector3(-0.5, 2.0, 0.1)))
	st.append_from(arm, 0, Transform3D(Basis(), Vector3(-0.88, 2.6, 0.1)))
	st.commit(m)
	m.surface_set_material(0, TexF.mat("cactus"))
	return m


static func _barrel_cactus_mesh() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.32
	c.bottom_radius = 0.42
	c.height = 0.7
	c.radial_segments = 10
	c.material = TexF.mat("cactus")
	return c


static func _mushroom_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.06
	stem.bottom_radius = 0.08
	stem.height = 0.3
	stem.radial_segments = 7
	st.append_from(stem, 0, Transform3D(Basis(), Vector3(0, 0.15, 0)))
	st.commit(m)
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SphereMesh.new()
	cap.radius = 0.18
	cap.height = 0.2
	cap.is_hemisphere = true
	cap.radial_segments = 9
	cap.rings = 4
	st2.append_from(cap, 0, Transform3D(Basis(), Vector3(0, 0.28, 0)))
	st2.commit(m)
	m.surface_set_material(0, TexF.plain(Color(0.9, 0.86, 0.78)))
	m.surface_set_material(1, TexF.mat("mushroom_cap"))
	return m


static func _litter_mesh() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.15
	c.height = 0.06
	c.radial_segments = 10
	c.material = TexF.mat("leaf_pile")
	return c


static func _tuft_mesh() -> SphereMesh:
	var t := SphereMesh.new()
	t.radius = 0.5
	t.height = 0.5
	t.is_hemisphere = true
	t.radial_segments = 8
	t.rings = 4
	t.material = TexF.mat("snow")
	return t


static func _tumbleweed_mesh() -> SphereMesh:
	var t := SphereMesh.new()
	t.radius = 0.55
	t.height = 1.1
	t.radial_segments = 7
	t.rings = 4
	t.material = TexF.mat("dry_bush")
	return t


static func _rock_mesh() -> SphereMesh:
	var r := SphereMesh.new()
	r.radius = 0.5
	r.height = 1.0
	r.radial_segments = 7
	r.rings = 4
	r.material = TexF.mat("stone")
	return r


static func _bush_mesh(mat_key: String) -> SphereMesh:
	var b := SphereMesh.new()
	b.radius = 0.7
	b.height = 1.4
	b.radial_segments = 8
	b.rings = 5
	b.material = TexF.mat(mat_key)
	return b
