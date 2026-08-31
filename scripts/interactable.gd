class_name Interactable
extends StaticBody3D
## A searchable structure. One of the 20 holds the numbered tag.

signal searched(s: Interactable)

var kind := ""
var display_name := "structure"
var has_item := false
var opened := false

## "pivots" (lids/doors swing), "sink" (mound digs away), "shake" (log rattles)
var anim_style := "pivots"
var anim_pivots: Array[Node3D] = []
var anim_rots: Array[Vector3] = []
var sink_node: Node3D = null
var sink_orig := Vector3.ONE
var sink_scale := Vector3(1, 0.08, 1)
var sink_shapes: Array[CollisionShape3D] = []
var item_anchor := Vector3(0, 1.0, 0)
var ring_radius := 1.0
var tag_text := ""
var tool_id := ""    ## which tool is inside ("map", "pencil", ...), if any
var seen := false    ## discovered (walked near or spyglassed)
var spotted := false ## logged via spyglass + pencil + writing surface

var _tweens: Array[Tween] = []
var _item_holder: Node3D = null
var _ring: MeshInstance3D = null


## WoW-style gold selection ring at the structure's base.
func set_selected(on: bool) -> void:
	if on:
		if _ring:
			return
		var tm := TorusMesh.new()
		tm.inner_radius = ring_radius * 0.90
		tm.outer_radius = ring_radius * 1.06
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.82, 0.25)
		tm.material = m
		_ring = MeshInstance3D.new()
		_ring.mesh = tm
		_ring.scale = Vector3(1, 0.3, 1)
		_ring.position = Vector3(0, 0.07, 0)
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)
	elif _ring:
		_ring.queue_free()
		_ring = null


func _init() -> void:
	collision_layer = 3


func interact() -> void:
	if opened:
		return
	opened = true
	_animate_open()
	if has_item:
		_reveal_item()
	searched.emit(self)


func reset() -> void:
	for t in _tweens:
		if t:
			t.kill()
	_tweens.clear()
	opened = false
	has_item = false
	for i in anim_pivots.size():
		anim_pivots[i].rotation_degrees = Vector3.ZERO
	if sink_node:
		sink_node.scale = sink_orig
	for c in sink_shapes:
		c.set_deferred("disabled", false)
	if _item_holder:
		_item_holder.queue_free()
		_item_holder = null


func _tw() -> Tween:
	var t := create_tween()
	_tweens.append(t)
	return t


func _animate_open() -> void:
	match anim_style:
		"pivots":
			for i in anim_pivots.size():
				var t := _tw()
				t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				t.tween_property(anim_pivots[i], "rotation_degrees", anim_rots[i], 0.7)
		"sink":
			if sink_node:
				var t := _tw()
				t.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
				t.tween_property(sink_node, "scale", sink_scale, 0.9)
			for c in sink_shapes:
				c.set_deferred("disabled", true)
		"shake":
			var y := position.y
			var t := _tw()
			t.tween_property(self, "position:y", y + 0.14, 0.12)
			var back := t.tween_property(self, "position:y", y, 0.3)
			back.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## Little pickup flourish when a tool is found: prop floats up, spins,
## shrinks away.
func spawn_tool_prop(id: String) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.position = item_anchor
	var gold := TexF.plain(Color(0.85, 0.68, 0.25), 0.4, 0.6)
	var tan := TexF.mat("tag")
	var dark := TexF.mat("darkwood")
	match id:
		"map":
			Util.cyl(holder, 0.08, 0.08, 0.5, Vector3.ZERO, tan, Vector3(0, 0, 90), 10)
			Util.cyl(holder, 0.095, 0.095, 0.1, Vector3.ZERO, dark, Vector3(0, 0, 90), 10)
		"compass":
			Util.cyl(holder, 0.17, 0.17, 0.06, Vector3.ZERO, gold, Vector3.ZERO, 16)
			Util.box(holder, Vector3(0.03, 0.05, 0.24), Vector3(0, 0.05, 0),
				TexF.plain(Color(0.8, 0.15, 0.1)), false)
		"spyglass":
			Util.cyl(holder, 0.055, 0.07, 0.42, Vector3.ZERO, dark, Vector3(0, 0, 90), 12)
			Util.cyl(holder, 0.045, 0.045, 0.12, Vector3(0.26, 0, 0),
				TexF.mat("metal"), Vector3(0, 0, 90), 12)
		"pencil":
			Util.cyl(holder, 0.035, 0.035, 0.42, Vector3.ZERO,
				TexF.plain(Color(0.88, 0.72, 0.18)), Vector3(0, 0, 90), 8)
			Util.cyl(holder, 0.0, 0.035, 0.09, Vector3(0.25, 0, 0),
				TexF.plain(Color(0.25, 0.18, 0.12)), Vector3(0, 0, -90), 8)
		"notepad":
			Util.box(holder, Vector3(0.3, 0.05, 0.4), Vector3.ZERO,
				TexF.plain(Color(0.93, 0.92, 0.86)), false)
			Util.box(holder, Vector3(0.3, 0.06, 0.06), Vector3(0, 0.005, -0.18),
				TexF.mat("metal"), false)
		"eraser":
			Util.box(holder, Vector3(0.24, 0.09, 0.13), Vector3.ZERO,
				TexF.plain(Color(0.92, 0.48, 0.55)), false)
	var gl := OmniLight3D.new()
	gl.light_color = Color(1, 0.95, 0.7)
	gl.omni_range = 2.5
	gl.light_energy = 1.4
	holder.add_child(gl)
	holder.scale = Vector3(0.05, 0.05, 0.05)
	var t := _tw()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(holder, "scale", Vector3.ONE, 0.5)
	t.parallel().tween_property(holder, "position", item_anchor + Vector3(0, 0.9, 0), 0.7)
	var spin := _tw()
	spin.tween_property(holder, "rotation:y", TAU * 1.5, 1.6).as_relative()
	spin.tween_property(holder, "scale", Vector3(0.02, 0.02, 0.02), 0.35)
	spin.tween_callback(holder.queue_free)


func _reveal_item() -> void:
	_item_holder = Node3D.new()
	add_child(_item_holder)
	_item_holder.position = item_anchor
	Util.box(_item_holder, Vector3(0.46, 0.6, 0.06), Vector3.ZERO, TexF.mat("tag"), false)
	Util.box(_item_holder, Vector3(0.52, 0.66, 0.04), Vector3(0, 0, -0.012),
		TexF.mat("darkwood"), false)
	for side in 2:
		var lb := Label3D.new()
		lb.text = tag_text
		lb.font_size = 160
		lb.pixel_size = 0.0016
		lb.modulate = Color(0.16, 0.09, 0.04)
		lb.outline_size = 20
		lb.outline_modulate = Color(0.92, 0.84, 0.62)
		if side == 0:
			lb.position = Vector3(0, 0, 0.036)
		else:
			lb.position = Vector3(0, 0, -0.036)
			lb.rotation_degrees.y = 180.0
		_item_holder.add_child(lb)
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.85, 0.4)
	gl.omni_range = 3.5
	gl.light_energy = 2.0
	_item_holder.add_child(gl)

	_item_holder.scale = Vector3(0.05, 0.05, 0.05)
	var t := _tw()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_item_holder, "scale", Vector3.ONE, 0.6)
	t.parallel().tween_property(_item_holder, "position",
		item_anchor + Vector3(0, 0.8, 0), 0.8)
	var spin := _tw()
	spin.set_loops()
	spin.tween_property(_item_holder, "rotation:y", TAU, 3.0).as_relative()
