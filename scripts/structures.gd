class_name Structures
## Factory for the searchable structures. Kinds are pooled per biome
## (with overlap); some materials swap by biome (e.g. desert sand mounds
## and bleached logs).

## Height of the great-tree / spire nests — climbing irons required.
const NEST_HEIGHT := 11.0


static func create(kind: String, display: String, biome_id := "meadow") -> Interactable:
	var s := Interactable.new()
	s.kind = kind
	s.display_name = display
	s.name = kind.capitalize()
	s.add_to_group("interactable")
	match kind:
		"crate":
			_crate(s)
		"barrel":
			_barrel(s)
		"chest":
			_chest(s)
		"wardrobe":
			_wardrobe(s)
		"log":
			_log(s, biome_id)
		"dirt_pile":
			_dirt_pile(s, biome_id)
		"haystack":
			_haystack(s)
		"stump":
			_stump(s)
		"cairn":
			_cairn(s)
		"firewood":
			_firewood(s)
		"campfire":
			_campfire(s)
		"scarecrow":
			_scarecrow(s)
		"leaf_pile":
			_leaf_pile(s)
		"snow_mound":
			_snow_mound(s)
		"urn":
			_urn(s)
		"bone_pile":
			_bone_pile(s)
		"nest":
			_nest(s, biome_id)
	return s


## How a kind rests on terrain: "rigid" gets a carved terrace and sits
## upright; "mound" sinks so its skirt follows the slope; "log" lies along
## the slope contour.
static func rest_class(kind: String) -> String:
	match kind:
		"log":
			return "log"
		"dirt_pile", "haystack", "leaf_pile", "snow_mound", "bone_pile":
			return "mound"
		"nest":
			return "tree"
		_:
			return "rigid"


static func _crate(s: Interactable) -> void:
	var wood := TexF.mat("wood")
	var dark := TexF.mat("darkwood")
	Util.box(s, Vector3(1, 0.08, 1), Vector3(0, 0.04, 0), wood, false)
	Util.box(s, Vector3(1, 0.9, 0.08), Vector3(0, 0.5, -0.46), wood, false)
	Util.box(s, Vector3(1, 0.9, 0.08), Vector3(0, 0.5, 0.46), wood, false)
	Util.box(s, Vector3(0.08, 0.9, 1), Vector3(-0.46, 0.5, 0), wood, false)
	Util.box(s, Vector3(0.08, 0.9, 1), Vector3(0.46, 0.5, 0), wood, false)
	for cx in [-0.48, 0.48]:
		for cz in [-0.48, 0.48]:
			Util.box(s, Vector3(0.1, 0.95, 0.1), Vector3(cx, 0.5, cz), dark, false)
	var pv := Node3D.new()
	pv.position = Vector3(0, 0.95, -0.5)
	s.add_child(pv)
	Util.box(pv, Vector3(1.06, 0.09, 1.06), Vector3(0, 0.045, 0.5), dark, false)
	Util.shape_box(s, Vector3(1, 1, 1), Vector3(0, 0.5, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(-115, 0, 0)]
	s.item_anchor = Vector3(0, 0.7, 0)
	s.ring_radius = 0.9


static func _barrel(s: Interactable) -> void:
	Util.cyl(s, 0.42, 0.38, 1.05, Vector3(0, 0.525, 0), TexF.mat("plank"))
	for by in [0.28, 0.82]:
		var band := TorusMesh.new()
		band.inner_radius = 0.40
		band.outer_radius = 0.50
		band.rings = 20
		band.ring_segments = 8
		band.material = TexF.mat("metal")
		Util.mesh(s, band, Vector3(0, by, 0))
	var pv := Node3D.new()
	pv.position = Vector3(0, 1.07, -0.4)
	s.add_child(pv)
	Util.cyl(pv, 0.45, 0.45, 0.06, Vector3(0, 0.03, 0.4), TexF.mat("darkwood"))
	Util.shape_cyl(s, 0.45, 1.1, Vector3(0, 0.55, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(-110, 0, 0)]
	s.item_anchor = Vector3(0, 1.1, 0)
	s.ring_radius = 0.8


static func _chest(s: Interactable) -> void:
	var dark := TexF.mat("darkwood")
	var metal := TexF.mat("metal")
	Util.box(s, Vector3(1.1, 0.55, 0.65), Vector3(0, 0.3, 0), dark, false)
	for sx in [-0.38, 0.38]:
		Util.box(s, Vector3(0.08, 0.58, 0.69), Vector3(sx, 0.3, 0), metal, false)
	Util.box(s, Vector3(0.14, 0.18, 0.05), Vector3(0, 0.42, 0.34),
		TexF.plain(Color(0.75, 0.62, 0.25), 0.4, 0.8), false)
	var pv := Node3D.new()
	pv.position = Vector3(0, 0.58, -0.325)
	s.add_child(pv)
	Util.box(pv, Vector3(1.1, 0.22, 0.65), Vector3(0, 0.11, 0.325), dark, false)
	for sx in [-0.38, 0.38]:
		Util.box(pv, Vector3(0.08, 0.25, 0.69), Vector3(sx, 0.11, 0.325), metal, false)
	Util.shape_box(s, Vector3(1.1, 0.85, 0.7), Vector3(0, 0.42, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(-100, 0, 0)]
	s.item_anchor = Vector3(0, 0.7, 0)
	s.ring_radius = 0.9


static func _wardrobe(s: Interactable) -> void:
	var wood := TexF.mat("wood")
	var dark := TexF.mat("darkwood")
	Util.box(s, Vector3(1.2, 2.1, 0.05), Vector3(0, 1.05, -0.275), dark, false)
	Util.box(s, Vector3(0.05, 2.1, 0.6), Vector3(-0.575, 1.05, 0), dark, false)
	Util.box(s, Vector3(0.05, 2.1, 0.6), Vector3(0.575, 1.05, 0), dark, false)
	Util.box(s, Vector3(1.2, 0.06, 0.6), Vector3(0, 2.08, 0), dark, false)
	Util.box(s, Vector3(1.2, 0.1, 0.6), Vector3(0, 0.05, 0), dark, false)
	Util.box(s, Vector3(1.1, 0.04, 0.5), Vector3(0, 0.75, 0), wood, false)
	var pv_l := Node3D.new()
	pv_l.position = Vector3(-0.58, 1.05, 0.28)
	s.add_child(pv_l)
	Util.box(pv_l, Vector3(0.56, 1.9, 0.05), Vector3(0.28, 0, 0.02), wood, false)
	var pv_r := Node3D.new()
	pv_r.position = Vector3(0.58, 1.05, 0.28)
	s.add_child(pv_r)
	Util.box(pv_r, Vector3(0.56, 1.9, 0.05), Vector3(-0.28, 0, 0.02), wood, false)
	Util.box(pv_l, Vector3(0.05, 0.16, 0.05), Vector3(0.5, 0, 0.06), dark, false)
	Util.box(pv_r, Vector3(0.05, 0.16, 0.05), Vector3(-0.5, 0, 0.06), dark, false)
	Util.shape_box(s, Vector3(1.2, 2.1, 0.62), Vector3(0, 1.05, 0))
	s.anim_pivots = [pv_l, pv_r]
	s.anim_rots = [Vector3(0, -115, 0), Vector3(0, 115, 0)]
	s.item_anchor = Vector3(0, 1.25, 0.2)
	# Wardrobes stand against walls; squash the ring so it stays indoors.
	s.ring_squash = Vector2(1.0, 0.38)


static func _log(s: Interactable, biome_id: String) -> void:
	var bark := TexF.mat("bleached") if biome_id == "desert" else TexF.mat("bark")
	var cap_c := Color(0.7, 0.64, 0.55) if biome_id == "desert" else Color(0.2, 0.13, 0.08)
	Util.cyl(s, 0.42, 0.42, 2.4, Vector3(0, 0.34, 0), bark, Vector3(0, 0, 90))
	for ex in [-1.18, 1.18]:
		Util.cyl(s, 0.31, 0.31, 0.06, Vector3(ex, 0.34, 0),
			TexF.plain(cap_c), Vector3(0, 0, 90), 14)
	Util.cyl(s, 0.08, 0.12, 0.6, Vector3(0.4, 0.75, 0.1), bark, Vector3(20, 0, -15), 8)
	Util.shape_box(s, Vector3(2.4, 0.8, 0.9), Vector3(0, 0.4, 0))
	s.anim_style = "shake"
	s.item_anchor = Vector3(0, 0.8, 0)
	s.ring_radius = 1.6


static func _mound_base(s: Interactable, mat: Material, r: float, sc: Vector3,
		col_size: Vector3) -> MeshInstance3D:
	var mound := SphereMesh.new()
	mound.radius = r
	mound.height = r * 2.0
	mound.is_hemisphere = true
	mound.material = mat
	var mi := Util.mesh(s, mound, Vector3.ZERO)
	mi.scale = sc
	var cs := Util.shape_box(s, col_size, Vector3(0, col_size.y * 0.5, 0))
	s.anim_style = "sink"
	s.sink_node = mi
	s.sink_orig = sc
	s.sink_scale = Vector3(sc.x, 0.07, sc.z)
	s.sink_shapes = [cs]
	return mi


static func _dirt_pile(s: Interactable, biome_id: String) -> void:
	var mat := TexF.mat("sand_mound") if biome_id == "desert" else TexF.mat("dirt_mound")
	_mound_base(s, mat, 1.0, Vector3(1.3, 0.55, 1.3), Vector3(2.0, 0.6, 2.0))
	Util.box(s, Vector3(0.06, 1.1, 0.06), Vector3(0.5, 0.75, 0.3),
		TexF.mat("wood"), false, Vector3(0, 0, -20))
	Util.box(s, Vector3(0.22, 0.3, 0.03), Vector3(0.31, 0.28, 0.3),
		TexF.mat("metal"), false, Vector3(0, 0, -20))
	s.item_anchor = Vector3(0, 0.5, 0)
	s.ring_radius = 1.7


static func _haystack(s: Interactable) -> void:
	_mound_base(s, TexF.mat("straw"), 1.5, Vector3(1.15, 0.8, 1.15), Vector3(2.6, 1.4, 2.6))
	s.item_anchor = Vector3(0, 0.9, 0)
	s.ring_radius = 2.0


static func _leaf_pile(s: Interactable) -> void:
	_mound_base(s, TexF.mat("leaf_pile"), 1.1, Vector3(1.35, 0.5, 1.35), Vector3(2.2, 0.6, 2.2))
	for off in [Vector3(1.5, 0.02, 0.4), Vector3(-1.3, 0.02, 0.8), Vector3(0.5, 0.02, -1.5)]:
		Util.cyl(s, 0.4, 0.45, 0.03, off, TexF.mat("leaf_pile"), Vector3.ZERO, 10)
	s.item_anchor = Vector3(0, 0.45, 0)
	s.ring_radius = 1.6


static func _snow_mound(s: Interactable) -> void:
	_mound_base(s, TexF.mat("snow"), 1.0, Vector3(1.3, 0.6, 1.3), Vector3(2.0, 0.7, 2.0))
	Util.box(s, Vector3(0.05, 1.2, 0.05), Vector3(0.4, 0.8, 0.2),
		TexF.mat("darkwood"), false, Vector3(0, 0, -12))
	Util.box(s, Vector3(0.3, 0.18, 0.02), Vector3(0.56, 1.25, 0.2),
		TexF.plain(Color(0.75, 0.15, 0.12)), false, Vector3(0, 0, -12))
	s.item_anchor = Vector3(0, 0.5, 0)
	s.ring_radius = 1.6


static func _bone_pile(s: Interactable) -> void:
	var bone := TexF.mat("bone")
	for b in [[Vector3(0, 0.08, 0.2), 25.0, 1.0], [Vector3(-0.2, 0.08, -0.25), 105.0, 0.8],
			[Vector3(0.35, 0.08, -0.1), 155.0, 0.9], [Vector3(-0.4, 0.08, 0.3), 60.0, 0.7]]:
		Util.cyl(s, 0.055, 0.07, b[2], b[0], bone, Vector3(0, b[1], 90), 8)
	var skull := SphereMesh.new()
	skull.radius = 0.22
	skull.height = 0.4
	skull.material = bone
	Util.mesh(s, skull, Vector3(0.25, 0.18, 0.15))
	var rib := TorusMesh.new()
	rib.inner_radius = 0.24
	rib.outer_radius = 0.32
	rib.material = bone
	Util.mesh(s, rib, Vector3(-0.25, 0.0, -0.1), Vector3(15, 40, 0))
	Util.shape_box(s, Vector3(1.4, 0.4, 1.4), Vector3(0, 0.2, 0))
	s.anim_style = "shake"
	s.item_anchor = Vector3(0, 0.4, 0)
	s.ring_radius = 1.1


static func _stump(s: Interactable) -> void:
	var bark := TexF.mat("bark")
	Util.cyl(s, 0.5, 0.64, 0.75, Vector3(0, 0.375, 0), bark, Vector3.ZERO, 14)
	# The dark hollow sits proud of the trunk's cap and a bark lip rings
	# it, so the stump reads as genuinely hollow.
	Util.cyl(s, 0.42, 0.42, 0.06, Vector3(0, 0.735, 0), TexF.plain(Color(0.07, 0.05, 0.03)), Vector3.ZERO, 12)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.4
	lip.outer_radius = 0.53
	lip.material = bark
	Util.mesh(s, lip, Vector3(0, 0.765, 0))
	for r in [[0.0, 0.62], [120.0, 0.6], [240.0, 0.66]]:
		var a: float = deg_to_rad(r[0])
		Util.box(s, Vector3(0.3, 0.18, 0.5), Vector3(cos(a) * r[1], 0.09, sin(a) * r[1]),
			bark, false, Vector3(0, r[0], 0))
	var pv := Node3D.new()
	pv.position = Vector3(0, 0.76, -0.42)
	s.add_child(pv)
	Util.cyl(pv, 0.5, 0.52, 0.08, Vector3(0, 0.04, 0.42), TexF.mat("tag"), Vector3.ZERO, 14)
	Util.shape_cyl(s, 0.62, 0.85, Vector3(0, 0.42, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(-105, 0, 0)]
	s.item_anchor = Vector3(0, 0.75, 0)
	s.ring_radius = 0.95


static func _cairn(s: Interactable) -> void:
	var stone := TexF.mat("stone")
	var y := 0.0
	for r in [0.55, 0.46]:
		var rock := SphereMesh.new()
		rock.radius = r
		rock.height = r * 1.2
		rock.radial_segments = 9
		rock.rings = 5
		rock.material = stone
		Util.mesh(s, rock, Vector3(0, y + r * 0.4, 0))
		y += r * 0.62
	var upper := Node3D.new()
	upper.position = Vector3(0, y, 0)
	s.add_child(upper)
	var uy := 0.0
	for r in [0.37, 0.29, 0.21]:
		var rock := SphereMesh.new()
		rock.radius = r
		rock.height = r * 1.2
		rock.radial_segments = 8
		rock.rings = 4
		rock.material = stone
		Util.mesh(upper, rock, Vector3(0, uy + r * 0.4, 0))
		uy += r * 0.62
	Util.shape_cyl(s, 0.58, 1.5, Vector3(0, 0.75, 0))
	s.anim_style = "sink"
	s.sink_node = upper
	s.sink_orig = Vector3.ONE
	s.sink_scale = Vector3(1.6, 0.08, 1.6)
	s.item_anchor = Vector3(0, 0.9, 0)
	s.ring_radius = 0.85


static func _firewood(s: Interactable) -> void:
	var bark := TexF.mat("bark")
	for z in [-0.27, -0.09, 0.09, 0.27]:
		Util.cyl(s, 0.13, 0.13, 1.05, Vector3(0, 0.13, z), bark, Vector3(0, 0, 90), 9)
	for z in [-0.18, 0.0, 0.18]:
		Util.cyl(s, 0.12, 0.12, 1.0, Vector3(0, 0.35, z), bark, Vector3(0, 0, 90), 9)
	var pv := Node3D.new()
	pv.position = Vector3(0, 0.47, 0.32)
	s.add_child(pv)
	for z in [-0.41, -0.23]:
		Util.cyl(pv, 0.11, 0.11, 0.98, Vector3(0, 0.08, z), bark, Vector3(0, 0, 90), 9)
	Util.shape_box(s, Vector3(1.15, 0.7, 0.75), Vector3(0, 0.35, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(100, 0, 0)]
	s.item_anchor = Vector3(0, 0.5, 0)
	s.ring_radius = 0.9


static func _campfire(s: Interactable) -> void:
	var stone := TexF.mat("stone")
	for i in 6:
		var a := TAU * i / 6.0
		var rock := SphereMesh.new()
		rock.radius = 0.17
		rock.height = 0.24
		rock.radial_segments = 8
		rock.rings = 4
		rock.material = stone
		Util.mesh(s, rock, Vector3(cos(a) * 0.72, 0.08, sin(a) * 0.72))
	var ash_root := Node3D.new()
	s.add_child(ash_root)
	var ash := SphereMesh.new()
	ash.radius = 0.5
	ash.height = 1.0
	ash.is_hemisphere = true
	ash.material = TexF.plain(Color(0.34, 0.33, 0.32), 1.0)
	var mi := Util.mesh(ash_root, ash, Vector3.ZERO)
	mi.scale = Vector3(1.0, 0.4, 1.0)
	var char_m := TexF.plain(Color(0.1, 0.09, 0.08))
	Util.cyl(ash_root, 0.06, 0.07, 0.9, Vector3(0, 0.16, 0), char_m, Vector3(80, 30, 0), 7)
	Util.cyl(ash_root, 0.06, 0.07, 0.8, Vector3(0.1, 0.18, 0.1), char_m, Vector3(80, 120, 0), 7)
	var cs := Util.shape_box(s, Vector3(1.7, 0.4, 1.7), Vector3(0, 0.2, 0))
	s.anim_style = "sink"
	s.sink_node = ash_root
	s.sink_orig = Vector3.ONE
	s.sink_scale = Vector3(1.0, 0.12, 1.0)
	s.sink_shapes = [cs]
	s.item_anchor = Vector3(0, 0.35, 0)
	s.ring_radius = 1.0
	# Lazy smoke column rising from the ashes until it's searched.
	var smoke := GPUParticles3D.new()
	smoke.amount = 26
	smoke.lifetime = 5.0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 5.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.25, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	grad.colors = PackedColorArray([Color(0.55, 0.54, 0.52, 0.0),
		Color(0.55, 0.54, 0.52, 0.5), Color(0.62, 0.62, 0.62, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	smoke.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.55, 0.55)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.vertex_color_use_as_albedo = true
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = smat
	smoke.draw_pass_1 = qm
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	smoke.position = Vector3(0, 0.4, 0)
	s.add_child(smoke)
	s.extinguish_node = smoke


static func _scarecrow(s: Interactable) -> void:
	var wood := TexF.mat("darkwood")
	Util.cyl(s, 0.06, 0.07, 2.2, Vector3(0, 1.1, 0), wood, Vector3.ZERO, 8)
	Util.box(s, Vector3(1.3, 0.07, 0.07), Vector3(0, 1.55, 0), wood, false)
	Util.box(s, Vector3(0.7, 0.8, 0.26), Vector3(0, 1.22, 0), TexF.mat("blanket"), false)
	var pv := Node3D.new()
	pv.position = Vector3(0, 1.6, 0.15)
	s.add_child(pv)
	Util.box(pv, Vector3(0.66, 0.72, 0.06), Vector3(0, -0.36, 0.02), TexF.mat("blanket"), false)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.4
	head.material = TexF.mat("tag")
	Util.mesh(s, head, Vector3(0, 1.95, 0))
	Util.cyl(s, 0.02, 0.34, 0.26, Vector3(0, 2.18, 0), TexF.mat("straw"), Vector3.ZERO, 10)
	Util.shape_box(s, Vector3(0.7, 2.2, 0.5), Vector3(0, 1.1, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(95, 0, 0)]
	s.item_anchor = Vector3(0, 1.3, 0.25)
	s.ring_radius = 0.9


## A nest atop a great tree (or a stone spire in the desert). The structure's
## ORIGIN IS AT THE TOP, so interact range naturally requires climbing up;
## the tree/spire hangs below it in local space.
static func _nest(s: Interactable, biome_id: String) -> void:
	var h := NEST_HEIGHT
	if biome_id == "desert":
		Util.cyl(s, 0.9, 1.7, h, Vector3(0, -h * 0.5, 0), TexF.mat("stone"), Vector3.ZERO, 10)
		Util.cyl(s, 1.4, 1.9, 2.4, Vector3(0, -h + 1.2, 0), TexF.mat("stone"), Vector3.ZERO, 9)
	else:
		Util.cyl(s, 0.45, 0.9, h, Vector3(0, -h * 0.5, 0), TexF.mat("bark"), Vector3.ZERO, 10)
		var leaf_key := "leaves"
		if biome_id == "autumn":
			leaf_key = "leaves_autumn1"
		elif biome_id == "winter":
			leaf_key = "leaves_dark"
		for off in [Vector3(-1.2, -2.8, 0.3), Vector3(1.1, -3.3, -0.4),
				Vector3(0.2, -2.2, 1.0), Vector3(-0.2, -4.0, -0.9)]:
			var can := SphereMesh.new()
			can.radius = 1.6
			can.height = 3.2
			can.radial_segments = 9
			can.rings = 5
			can.material = TexF.mat(leaf_key)
			Util.mesh(s, can, off)
		if biome_id == "winter":
			var cap := SphereMesh.new()
			cap.radius = 1.3
			cap.height = 1.2
			cap.is_hemisphere = true
			cap.material = TexF.mat("snow")
			Util.mesh(s, cap, Vector3(0, -1.9, 0))
	# platform and nest
	Util.cyl(s, 1.0, 0.85, 0.18, Vector3(0, -0.16, 0), TexF.mat("darkwood"), Vector3.ZERO, 10)
	var nest := TorusMesh.new()
	nest.inner_radius = 0.42
	nest.outer_radius = 0.85
	nest.material = TexF.mat("straw")
	Util.mesh(s, nest, Vector3(0, 0.08, 0))
	for e in [Vector3(0.15, 0.1, 0.1), Vector3(-0.18, 0.1, -0.05), Vector3(0.0, 0.1, -0.2)]:
		var egg := SphereMesh.new()
		egg.radius = 0.12
		egg.height = 0.28
		egg.material = TexF.plain(Color(0.88, 0.90, 0.86))
		Util.mesh(s, egg, e)
	Util.shape_cyl(s, 0.9, h, Vector3(0, -h * 0.5, 0))
	Util.shape_cyl(s, 1.0, 0.2, Vector3(0, -0.15, 0))
	s.anim_style = "shake"
	s.item_anchor = Vector3(0, 0.5, 0)
	s.ring_radius = 1.0


static func _urn(s: Interactable) -> void:
	var clay := TexF.mat("clay")
	Util.cyl(s, 0.36, 0.26, 0.75, Vector3(0, 0.375, 0), clay, Vector3.ZERO, 14)
	Util.cyl(s, 0.24, 0.3, 0.14, Vector3(0, 0.82, 0), clay, Vector3.ZERO, 12)
	var pv := Node3D.new()
	pv.position = Vector3(0, 0.9, -0.2)
	s.add_child(pv)
	Util.cyl(pv, 0.27, 0.27, 0.06, Vector3(0, 0.03, 0.2), TexF.mat("darkwood"), Vector3.ZERO, 12)
	Util.shape_cyl(s, 0.38, 0.95, Vector3(0, 0.48, 0))
	s.anim_pivots = [pv]
	s.anim_rots = [Vector3(-110, 0, 0)]
	s.item_anchor = Vector3(0, 0.85, 0)
	s.ring_radius = 0.7
