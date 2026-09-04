class_name Caves
## Underground cave: a boulder mound with a stone arch on the surface, a
## stepped shaft descending to a crystal-lit chamber holding extra nodes.
## Everything sits below the terrain sheet, so no terrain surgery needed —
## the shaft and chamber are fully enclosed rooms.


## Builds the cave at pos (terrain already carries a flat patch there).
## Returns the structure specs for the nodes hidden in the chamber.
static func build(parent: Node3D, terrain: Terrain, wrng: RandomNumberGenerator,
		pos: Vector2, yaw: float, biome: Dictionary) -> Array:
	var b := StaticBody3D.new()
	b.name = "Cave"
	b.collision_layer = 1
	parent.add_child(b)
	b.position = Vector3(pos.x, terrain.height_at(pos.x, pos.y), pos.y)
	b.rotation.y = yaw
	var stone := TexF.mat("stone")

	# Entrance mound: a ring of boulders with a gap at the doorway (+Z).
	# Ring rocks are solid; the cap rock over the shaft stays intangible so
	# its collider can't intrude into the stairway below it.
	for r in [[-2.9, 0.8, 1.6, 2.6], [2.9, 0.8, 1.6, 2.6], [-2.2, 0.9, -2.4, 2.8],
			[2.2, 0.9, -2.4, 2.8], [0.0, 1.6, -1.2, 3.4], [0.0, 0.7, -3.4, 2.2]]:
		var rock := SphereMesh.new()
		rock.radius = r[3] * 0.5
		rock.height = r[3] * 0.8
		rock.radial_segments = 9
		rock.rings = 5
		rock.material = stone
		var mi := Util.mesh(b, rock, Vector3(r[0], r[1] * 0.6, r[2]))
		mi.scale = Vector3(1.3, 0.9, 1.2)
		if absf(r[0]) > 1.5:
			var cs := CollisionShape3D.new()
			var sh := SphereShape3D.new()
			sh.radius = r[3] * 0.55
			cs.shape = sh
			cs.position = Vector3(r[0], r[1] * 0.6, r[2])
			b.add_child(cs)
	# A small lantern marks the way in.
	Util.box(b, Vector3(0.18, 0.28, 0.18), Vector3(1.05, 2.05, 3.55), TexF.mat("metal"), false)
	var el := OmniLight3D.new()
	el.position = Vector3(1.05, 2.0, 3.6)
	el.light_color = Color(1.0, 0.8, 0.45)
	el.omni_range = 6.0
	el.light_energy = 1.3
	b.add_child(el)
	# Arch pillars and lintel.
	Util.box(b, Vector3(0.6, 2.4, 0.6), Vector3(-1.3, 1.2, 3.3), stone)
	Util.box(b, Vector3(0.6, 2.4, 0.6), Vector3(1.3, 1.2, 3.3), stone)
	Util.box(b, Vector3(3.2, 0.7, 0.8), Vector3(0, 2.6, 3.3), stone)

	# Shaft: ramp descending from the doorway (z +3.2) into the chamber,
	# flanked by solid stone masses wide enough to cover the terrain hole's
	# ragged edges, with a sloped ceiling and ground aprons front and rear.
	Util.shape_box(b, Vector3(2.3, 0.2, 7.4), Vector3(0, -2.37, 0.4), Vector3(-38.2, 0, 0))
	for i in 8:
		var t := (i + 0.5) / 8.0
		Util.box(b, Vector3(2.2, 0.22, 0.8),
			Vector3(0, -4.5 * t + 0.0, 3.2 - 5.6 * t), stone, false)
	Util.box(b, Vector3(2.5, 7.4, 8.2), Vector3(-2.4, -1.1, 0.3), stone)
	Util.box(b, Vector3(2.5, 7.4, 8.2), Vector3(2.4, -1.1, 0.3), stone)
	Util.box(b, Vector3(3.0, 0.35, 7.2), Vector3(0, 0.55, 0.4), stone, true, Vector3(-38.2, 0, 0))
	Util.box(b, Vector3(6.6, 0.35, 2.4), Vector3(0, -0.14, -4.4), stone)
	# Apron top rides just above the flattened terrain so the two surfaces
	# never share a plane (coplanar faces flicker).
	Util.box(b, Vector3(6.6, 0.3, 3.8), Vector3(0, -0.11, 5.1), stone)

	# Chamber: x -4..4, z -8.6..-2.3, floor -4.4, ceiling -1.7.
	Util.box(b, Vector3(8.9, 0.35, 7.0), Vector3(0, -4.6, -5.5), stone)
	Util.box(b, Vector3(8.9, 0.35, 7.0), Vector3(0, -1.55, -5.5), stone)
	Util.box(b, Vector3(0.35, 3.4, 7.0), Vector3(-4.15, -3.1, -5.5), stone)
	Util.box(b, Vector3(0.35, 3.4, 7.0), Vector3(4.15, -3.1, -5.5), stone)
	Util.box(b, Vector3(8.9, 3.4, 0.35), Vector3(0, -3.1, -8.6), stone)
	Util.box(b, Vector3(2.8, 3.4, 0.35), Vector3(-2.7, -3.1, -2.45), stone)
	Util.box(b, Vector3(2.8, 3.4, 0.35), Vector3(2.7, -3.1, -2.45), stone)

	# Stalagmites and glow crystals.
	for sm in [[-3.0, -7.6, 1.1], [3.2, -3.6, 0.9], [-1.5, -3.2, 0.7]]:
		Util.cyl(b, 0.02, 0.35, sm[2], Vector3(sm[0], -4.4 + sm[2] * 0.5, sm[1]), stone, Vector3.ZERO, 7)
	var crystal := StandardMaterial3D.new()
	crystal.albedo_color = Color(0.5, 0.8, 1.0)
	crystal.emission_enabled = true
	crystal.emission = Color(0.35, 0.65, 1.0)
	crystal.emission_energy_multiplier = 1.6
	for cx in [[-3.4, -5.0, 20.0], [3.3, -6.8, -25.0], [0.8, -8.0, 10.0]]:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.03
		cm.bottom_radius = 0.22
		cm.height = 1.0
		cm.radial_segments = 6
		cm.material = crystal
		Util.mesh(b, cm, Vector3(cx[0], -3.95, cx[1]), Vector3(0, 0, cx[2]))
	var gl := OmniLight3D.new()
	gl.position = Vector3(0, -2.6, -5.5)
	gl.light_color = Color(0.5, 0.7, 1.0)
	gl.omni_range = 9.0
	gl.light_energy = 1.5
	b.add_child(gl)

	# The hidden nodes.
	var second_kind := "urn" if biome.id == "desert" else "crate"
	var second_name := "buried urn" if biome.id == "desert" else "stashed crate"
	return [
		{kind = "chest", display = "cave chest",
			xform = b.transform * Transform3D(Basis(Vector3.UP, wrng.randf_range(0.0, TAU)),
				Vector3(-2.4, -4.4, -6.8))},
		{kind = second_kind, display = second_name,
			xform = b.transform * Transform3D(Basis(Vector3.UP, wrng.randf_range(0.0, TAU)),
				Vector3(2.3, -4.4, -6.2))},
	]
