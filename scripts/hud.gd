class_name Hud
extends CanvasLayer
## Target frame, hover tooltip, interact prompt, search counter, toasts,
## and the found banner. Every control ignores the mouse so clicks reach
## the world.

var prompt: Label
var counter: Label
var toast_label: Label
var banner: PanelContainer
var banner_label: Label
var found_tag: Label
var target_frame: PanelContainer
var target_name: Label
var target_status: Label
var hover_label: Label
var day_label: Label
var main: Node = null
var tool_chips := {}
var map_panel: Control
var map_overlay: MiniOverlay
var compass: CompassStrip
var spy_overlay: SpyOverlay
var _toast_tween: Tween = null


## Wires overlays to the game root; call once after both exist.
func setup(m: Node) -> void:
	main = m
	map_overlay.main = m
	compass.main = m
	spy_overlay.main = m


func set_tools(t: Dictionary) -> void:
	for id in tool_chips:
		tool_chips[id].add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.25) if t[id] else Color(1, 1, 1, 0.3))
	map_panel.visible = t.map
	compass.visible = t.compass


func set_map_texture(tex: Texture2D) -> void:
	map_overlay.map_tex = tex


func set_spy(active: bool, spots: Array) -> void:
	spy_overlay.active = active
	spy_overlay.spots = spots


## Fog-of-war minimap: draws the map texture and discovered-structure dots.
## Map only: view-up mode — the map rotates with the camera around your
## position, and a centered arrow always points up.
## Map + compass: north-up mode — the map is fixed and the arrow at your
## position rotates with the camera.
class MiniOverlay:
	extends Control
	var main: Node = null
	var map_tex: Texture2D = null

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _to_px(w: Vector2) -> Vector2:
		return Vector2((w.x + 250.0) / 500.0 * size.x, (w.y + 250.0) / 500.0 * size.y)

	func _draw() -> void:
		if main == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.07, 0.05, 0.85), true)
		var pp := Vector2.ZERO
		var f := 0.0
		if main.player:
			pp = _to_px(Vector2(main.player.global_position.x, main.player.global_position.z))
			f = main.player.cam_yaw
		if main.tools.compass:
			_draw_map_and_dots()
			if main.player:
				_arrow(pp, f)
		elif main.player:
			# Rotate the whole map around the player so the view is up.
			var rz := Transform2D(f, Vector2.ZERO)
			draw_set_transform_matrix(Transform2D(f, size * 0.5 - rz * pp))
			_draw_map_and_dots()
			draw_set_transform_matrix(Transform2D())
			_arrow(size * 0.5, 0.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.75, 0.5, 0.9), false, 2.0)

	func _draw_map_and_dots() -> void:
		if map_tex:
			draw_texture_rect(map_tex, Rect2(Vector2.ZERO, size), false)
		for s in main.structures:
			if not is_instance_valid(s) or not s.seen:
				continue
			var p := _to_px(Vector2(s.global_position.x, s.global_position.z))
			if s.opened:
				draw_circle(p, 2.5, Color(0.55, 0.55, 0.55, 0.8))
			else:
				draw_circle(p, 3.0, Color(1.0, 0.82, 0.25))

	func _arrow(pp: Vector2, f: float) -> void:
		var dirv := Vector2(-sin(f), -cos(f))
		var side := dirv.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			pp + dirv * 8.0, pp - dirv * 4.0 + side * 4.5, pp - dirv * 4.0 - side * 4.5]),
			Color.WHITE)


## Skyrim-style heading strip driven by the camera yaw.
class CompassStrip:
	extends Control
	var main: Node = null
	const DIRS := [["N", 0.0], ["NE", 45.0], ["E", 90.0], ["SE", 135.0],
		["S", 180.0], ["SW", 225.0], ["W", 270.0], ["NW", 315.0]]

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if main == null or main.player == null:
			return
		var f := ThemeDB.fallback_font
		var heading := wrapf(rad_to_deg(-main.player.cam_yaw), 0.0, 360.0)
		var cx := size.x * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - 5, 0), Vector2(cx + 5, 0), Vector2(cx, 7)]), Color(1, 0.85, 0.3))
		for d in DIRS:
			var delta := wrapf(d[1] - heading + 180.0, 0.0, 360.0) - 180.0
			if absf(delta) > 55.0:
				continue
			var x := cx + delta * 3.4
			var fs := 18 if d[0].length() == 1 else 12
			var col := Color(1, 1, 1, clampf(1.15 - absf(delta) / 55.0, 0.0, 1.0))
			draw_string_outline(f, Vector2(x - 14, 28), d[0],
				HORIZONTAL_ALIGNMENT_CENTER, 28, fs, 4, Color(0, 0, 0, 0.8))
			draw_string(f, Vector2(x - 14, 28), d[0],
				HORIZONTAL_ALIGNMENT_CENTER, 28, fs, col)
		draw_string(f, Vector2(cx - 24, 44), "%d°" % int(heading),
			HORIZONTAL_ALIGNMENT_CENTER, 48, 12, Color(1, 1, 1, 0.7))


## Floating name · distance labels while the spyglass is raised.
class SpyOverlay:
	extends Control
	var main: Node = null
	var active := false
	var spots: Array = []

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if not active or main == null or main.player == null:
			return
		var cam: Camera3D = main.player.cam
		var f := ThemeDB.fallback_font
		for sp in spots:
			var p: Vector2 = cam.unproject_position(sp.pos)
			draw_circle(p, 2.5, Color(1, 0.85, 0.3))
			draw_string_outline(f, p + Vector2(-90, -8), sp.text,
				HORIZONTAL_ALIGNMENT_CENTER, 180, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(f, p + Vector2(-90, -8), sp.text,
				HORIZONTAL_ALIGNMENT_CENTER, 180, 13, Color(1, 0.95, 0.75))


func _ready() -> void:
	var help := _label(14, Color(1, 1, 1, 0.75))
	help.text = "Left-drag orbit · Right-drag steer · Both buttons run · Wheel zoom\nClick target · Right-click / E search · WASD move · Shift sprint · Space jump · Z spyglass · Esc deselect / menu"
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(14, 8)
	add_child(help)

	day_label = _label(15, Color(1.0, 0.95, 0.8))
	day_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	day_label.position = Vector2(14, 54)
	add_child(day_label)

	counter = _label(20, Color.WHITE)
	counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	counter.position = Vector2(-250, 10)
	counter.size = Vector2(236, 30)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(counter)

	found_tag = _label(20, Color(1.0, 0.85, 0.35))
	found_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	found_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	found_tag.position = Vector2(-250, 40)
	found_tag.size = Vector2(236, 30)
	found_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(found_tag)

	prompt = _label(24, Color.WHITE)
	prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.position = Vector2(-300, -90)
	prompt.size = Vector2(600, 36)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(prompt)

	toast_label = _label(22, Color(1, 1, 1))
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.position = Vector2(-300, 90)
	toast_label.size = Vector2(600, 34)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	add_child(toast_label)

	target_frame = PanelContainer.new()
	target_frame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	target_frame.position = Vector2(-170, 8)
	target_frame.custom_minimum_size = Vector2(340, 0)
	target_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.visible = false
	var tv := VBoxContainer.new()
	tv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_frame.add_child(tv)
	target_name = _label(20, Color(1.0, 0.9, 0.5))
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(target_name)
	target_status = _label(15, Color(0.85, 0.85, 0.85))
	target_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(target_status)
	add_child(target_frame)

	hover_label = _label(15, Color(1.0, 0.95, 0.7))
	hover_label.visible = false
	add_child(hover_label)

	# tool chips (dim until found)
	var chips := HBoxContainer.new()
	chips.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chips.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chips.position = Vector2(-250, 70)
	chips.size = Vector2(236, 24)
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_theme_constant_override("separation", 14)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chips)
	for id in ["map", "compass", "spyglass"]:
		var c := _label(15, Color(1, 1, 1, 0.3))
		c.text = id.capitalize()
		chips.add_child(c)
		tool_chips[id] = c

	# minimap (visible once the map is found)
	map_panel = Control.new()
	map_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map_panel.position = Vector2(-238, 100)
	map_panel.size = Vector2(224, 224)
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.visible = false
	map_panel.clip_contents = true
	add_child(map_panel)
	map_overlay = MiniOverlay.new()
	map_overlay.clip_contents = true
	map_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_panel.add_child(map_overlay)

	# compass strip (visible once the compass is found)
	compass = CompassStrip.new()
	compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass.position = Vector2(-190, 66)
	compass.size = Vector2(380, 48)
	compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	compass.visible = false
	add_child(compass)

	# spyglass spotting labels
	spy_overlay = SpyOverlay.new()
	spy_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	spy_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spy_overlay)

	banner = PanelContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-330, 110)
	banner.custom_minimum_size = Vector2(660, 0)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.visible = false
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	banner.add_child(margin)
	banner_label = _label(26, Color(1.0, 0.9, 0.5))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	margin.add_child(banner_label)
	add_child(banner)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func update_target(disp: String, dist: float, in_range: bool, opened: bool) -> void:
	target_frame.visible = true
	target_name.text = disp.capitalize()
	if opened:
		target_status.text = "Already searched"
		prompt.text = ""
	elif in_range:
		target_status.text = "In range"
		prompt.text = "Right-click / E — Search the %s" % disp
	else:
		target_status.text = "%.0f m — too far" % dist
		prompt.text = ""


func hide_target() -> void:
	if target_frame.visible:
		target_frame.visible = false
		prompt.text = ""


func set_hover(text: String, pos: Vector2) -> void:
	if text.is_empty():
		hover_label.visible = false
	else:
		hover_label.visible = true
		hover_label.text = text.capitalize()
		hover_label.position = pos + Vector2(18, 14)


func set_count(done: int, total: int) -> void:
	counter.text = "Searched %d / %d" % [done, total]


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 1.0)


func set_day_info(text: String) -> void:
	day_label.text = text


func found(num: String) -> void:
	banner.visible = true
	banner_label.text = "YOU FOUND IT!\nThe tag reads: %s" % num
	found_tag.text = "Tag found: %s" % num


func clear_found() -> void:
	banner.visible = false
	found_tag.text = ""
