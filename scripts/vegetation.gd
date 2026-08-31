class_name Vegetation
## Scatters pines, oaks, bushes, rocks, and boulders across the landscape
## using MultiMeshes, avoiding the village, water, steep slopes, and the
## exclusion circles around structures.


static func build(parent: Node3D, terrain: Terrain, exclusions: Array, sd: int) -> void:
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

	var pine_x: Array[Transform3D] = []
	var oak_x: Array[Transform3D] = []
	var attempts := 0
	while pine_x.size() + oak_x.size() < 420 and attempts < 12000:
		attempts += 1
		var x := rng.randf_range(-235.0, 235.0)
		var z := rng.randf_range(-235.0, 235.0)
		if Vector2(x, z).length() < 52.0:
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 1.8:
			continue
		if terrain.normal_at(x, z).y < 0.76:
			continue
		if fnoise.get_noise_2d(x, z) < 0.03:
			continue
		if _excluded(exclusions, x, z):
			continue
		var sc := rng.randf_range(0.85, 1.4)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc, sc))
		var tf := Transform3D(basis, Vector3(x, h - 0.15, z))
		if rng.randf() < 0.6:
			pine_x.append(tf)
		else:
			oak_x.append(tf)
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.32 * sc
		sh.height = 5.0
		cs.shape = sh
		cs.position = Vector3(x, h + 2.5, z)
		cols.add_child(cs)

	_add_multimesh(root, _pine_mesh(), pine_x)
	_add_multimesh(root, _oak_mesh(), oak_x)

	# small rocks (no collision)
	var rock_x: Array[Transform3D] = []
	for i in 500:
		if rock_x.size() >= 150:
			break
		var x := rng.randf_range(-235.0, 235.0)
		var z := rng.randf_range(-235.0, 235.0)
		if Vector2(x, z).length() < 34.0 or _excluded(exclusions, x, z):
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 0.5:
			continue
		var sc := rng.randf_range(0.3, 1.1)
		var basis := Basis.from_euler(Vector3(rng.randf_range(0, 0.4), rng.randf_range(0, TAU),
			rng.randf_range(0, 0.4))).scaled(Vector3(sc, sc * 0.6, sc * rng.randf_range(0.7, 1.3)))
		rock_x.append(Transform3D(basis, Vector3(x, h + 0.05, z)))
	_add_multimesh(root, _rock_mesh(), rock_x)

	# bushes (no collision)
	var bush_x: Array[Transform3D] = []
	for i in 900:
		if bush_x.size() >= 170:
			break
		var x := rng.randf_range(-230.0, 230.0)
		var z := rng.randf_range(-230.0, 230.0)
		if Vector2(x, z).length() < 40.0 or _excluded(exclusions, x, z):
			continue
		if fnoise.get_noise_2d(x, z) < -0.1:
			continue
		var h := terrain.height_at(x, z)
		if h < terrain.water_y + 1.2 or terrain.normal_at(x, z).y < 0.8:
			continue
		var sc := rng.randf_range(0.6, 1.3)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(sc, sc * 0.7, sc))
		bush_x.append(Transform3D(basis, Vector3(x, h + 0.1, z)))
	_add_multimesh(root, _bush_mesh(), bush_x)

	# big boulders with collision
	var placed := 0
	for i in 400:
		if placed >= 14:
			break
		var x := rng.randf_range(-220.0, 220.0)
		var z := rng.randf_range(-220.0, 220.0)
		if Vector2(x, z).length() < 70.0 or _excluded(exclusions, x, z):
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
		var mi := Util.mesh(cols, bm, Vector3(x, h + sc * 0.25, z),
			Vector3(rng.randf_range(0, 30), rng.randf_range(0, 360), rng.randf_range(0, 30)))
		mi.scale = Vector3(sc, sc * 0.7, sc * rng.randf_range(0.8, 1.2))
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = sc * 0.72
		cs.shape = sh
		cs.position = Vector3(x, h + sc * 0.2, z)
		cols.add_child(cs)


static func _excluded(exclusions: Array, x: float, z: float) -> bool:
	for e in exclusions:
		if Vector2(x - e.x, z - e.y).length() < e.z:
			return true
	return false


static func _add_multimesh(root: Node3D, mesh: Mesh, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)


static func _pine_mesh() -> ArrayMesh:
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
	for layer in [[2.5, 2.9, 3.2], [2.0, 2.5, 4.7], [1.3, 2.3, 6.1]]:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = layer[0]
		cone.height = layer[1]
		cone.radial_segments = 12
		st2.append_from(cone, 0, Transform3D(Basis(), Vector3(0, layer[2], 0)))
	st2.commit(m)
	m.surface_set_material(0, TexF.mat("bark"))
	m.surface_set_material(1, TexF.mat("leaves_dark"))
	return m


static func _oak_mesh() -> ArrayMesh:
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
	m.surface_set_material(1, TexF.mat("leaves"))
	return m


static func _rock_mesh() -> SphereMesh:
	var r := SphereMesh.new()
	r.radius = 0.5
	r.height = 1.0
	r.radial_segments = 7
	r.rings = 4
	r.material = TexF.mat("stone")
	return r


static func _bush_mesh() -> SphereMesh:
	var b := SphereMesh.new()
	b.radius = 0.7
	b.height = 1.4
	b.radial_segments = 8
	b.rings = 5
	b.material = TexF.mat("leaves")
	return b
