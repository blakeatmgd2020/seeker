class_name Structures
## Factory for the searchable structures.


static func create(kind: String, display: String) -> Interactable:
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
			_log(s)
		"dirt_pile":
			_dirt_pile(s)
		"haystack":
			_haystack(s)
	return s


static func _crate(s: Interactable) -> void:
	var wood := TexF.mat("wood")
	var dark := TexF.mat("darkwood")
	Util.box(s, Vector3(1, 0.08, 1), Vector3(0, 0.04, 0), wood, false)
	Util.box(s, Vector3(1, 0.9, 0.08), Vector3(0, 0.5, -0.46), wood, false)
	Util.box(s, Vector3(1, 0.9, 0.08), Vector3(0, 0.5, 0.46), wood, false)
	Util.box(s, Vector3(0.08, 0.9, 1), Vector3(-0.46, 0.5, 0), wood, false)
	Util.box(s, Vector3(0.08, 0.9, 1), Vector3(0.46, 0.5, 0), wood, false)
	# corner posts
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
	# handles
	Util.box(pv_l, Vector3(0.05, 0.16, 0.05), Vector3(0.5, 0, 0.06), dark, false)
	Util.box(pv_r, Vector3(0.05, 0.16, 0.05), Vector3(-0.5, 0, 0.06), dark, false)
	Util.shape_box(s, Vector3(1.2, 2.1, 0.62), Vector3(0, 1.05, 0))
	s.anim_pivots = [pv_l, pv_r]
	s.anim_rots = [Vector3(0, -115, 0), Vector3(0, 115, 0)]
	s.item_anchor = Vector3(0, 1.25, 0.2)


static func _log(s: Interactable) -> void:
	var bark := TexF.mat("bark")
	Util.cyl(s, 0.42, 0.42, 2.4, Vector3(0, 0.34, 0), bark, Vector3(0, 0, 90))
	for ex in [-1.18, 1.18]:
		Util.cyl(s, 0.31, 0.31, 0.06, Vector3(ex, 0.34, 0),
			TexF.plain(Color(0.2, 0.13, 0.08)), Vector3(0, 0, 90), 14)
	# a broken stub branch
	Util.cyl(s, 0.08, 0.12, 0.6, Vector3(0.4, 0.75, 0.1), bark, Vector3(20, 0, -15), 8)
	Util.shape_box(s, Vector3(2.4, 0.8, 0.9), Vector3(0, 0.4, 0))
	s.anim_style = "shake"
	s.item_anchor = Vector3(0, 0.8, 0)
	s.ring_radius = 1.6


static func _dirt_pile(s: Interactable) -> void:
	var mound := SphereMesh.new()
	mound.radius = 1.0
	mound.height = 2.0
	mound.is_hemisphere = true
	mound.material = TexF.mat("dirt_mound")
	var mi := Util.mesh(s, mound, Vector3.ZERO)
	mi.scale = Vector3(1.3, 0.55, 1.3)
	# shovel stuck in the pile
	Util.box(s, Vector3(0.06, 1.1, 0.06), Vector3(0.5, 0.75, 0.3),
		TexF.mat("wood"), false, Vector3(0, 0, -20))
	Util.box(s, Vector3(0.22, 0.3, 0.03), Vector3(0.31, 0.28, 0.3),
		TexF.mat("metal"), false, Vector3(0, 0, -20))
	var cs := Util.shape_box(s, Vector3(2.0, 0.6, 2.0), Vector3(0, 0.3, 0))
	s.anim_style = "sink"
	s.sink_node = mi
	s.sink_orig = mi.scale
	s.sink_scale = Vector3(1.3, 0.07, 1.3)
	s.sink_shapes = [cs]
	s.item_anchor = Vector3(0, 0.5, 0)
	s.ring_radius = 1.7


static func _haystack(s: Interactable) -> void:
	var mound := SphereMesh.new()
	mound.radius = 1.5
	mound.height = 3.0
	mound.is_hemisphere = true
	mound.material = TexF.mat("straw")
	var mi := Util.mesh(s, mound, Vector3.ZERO)
	mi.scale = Vector3(1.15, 0.8, 1.15)
	var cs := Util.shape_box(s, Vector3(2.6, 1.4, 2.6), Vector3(0, 0.7, 0))
	s.anim_style = "sink"
	s.sink_node = mi
	s.sink_orig = mi.scale
	s.sink_scale = Vector3(1.15, 0.1, 1.15)
	s.sink_shapes = [cs]
	s.item_anchor = Vector3(0, 0.9, 0)
	s.ring_radius = 2.0

