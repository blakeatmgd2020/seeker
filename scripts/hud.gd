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
var stam_bg: ColorRect
var stam_fill: ColorRect
var coffee_btn: Button
var coffee_buff: Label
var winded_label: Label
var _pulse := 0.0
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
var spot_panel: PanelContainer
var spot_box: VBoxContainer
var big_dim: ColorRect
var big_map: BigMap
var big_pad: BigMap
var _spot_rows: Array[Label] = []
var _toast_tween: Tween = null


func _process(delta: float) -> void:
	if main == null or not visible:
		return
	_pulse += delta
	coffee_btn.visible = main.has_coffee
	if main.coffee_active():
		# The stamina bar becomes the glowing yellow caffeine countdown.
		var s: int = main.coffee_remaining()
		coffee_buff.visible = true
		coffee_buff.text = "Caffeinated · %d:%02d" % [s / 60, s % 60]
		stam_bg.visible = true
		stam_bg.color = Color(0, 0, 0, 0.55)
		stam_fill.size.x = 180.0 * (main.coffee_remaining() / 120.0)
		var glow := 0.5 + 0.5 * sin(_pulse * 6.0)
		stam_fill.color = Color(1.0, 0.85, 0.2).lerp(Color(1.0, 1.0, 0.55), glow)
	else:
		coffee_buff.visible = false


## Wires overlays to the game root; call once after both exist.
func setup(m: Node) -> void:
	main = m
	map_overlay.main = m
	compass.main = m
	spy_overlay.main = m
	big_map.main = m
	big_pad.main = m


func update_spots(entries: Array) -> void:
	if entries.is_empty() or big_map.visible or big_pad.visible:
		spot_panel.visible = false
		return
	spot_panel.visible = true
	while _spot_rows.size() > entries.size():
		var l: Label = _spot_rows.pop_back()
		spot_box.remove_child(l)
		l.queue_free()
	while _spot_rows.size() < entries.size():
		var l := _label(15, Color.WHITE)
		spot_box.add_child(l)
		_spot_rows.append(l)
	for i in entries.size():
		var e: Dictionary = entries[i]
		var l := _spot_rows[i]
		l.text = ("▶ " if e.selected else "   ") + "%s · %d m" % [
			String(e.name).capitalize(), int(e.dist)]
		l.add_theme_color_override("font_color",
			Color(0.45, 0.95, 0.45) if e.selected else Color(1, 1, 1, 0.85))


func toggle_big_map() -> void:
	if big_map.visible:
		close_big_views()
		return
	if main == null or not main.tools.map:
		toast("You need the map to do that.")
		return
	_open_big(big_map)


func toggle_big_pad() -> void:
	if big_pad.visible:
		close_big_views()
		return
	if main == null or not main.tools.notepad:
		toast("You need the notepad to do that.")
		return
	_open_big(big_pad)


func _open_big(view: BigMap) -> void:
	big_map.visible = false
	big_pad.visible = false
	var vp := get_viewport().get_visible_rect().size
	var side := minf(vp.x, vp.y) * 0.82
	view.size = Vector2(side, side)
	view.position = (vp - view.size) * 0.5
	big_dim.visible = true
	view.visible = true


func close_big_views() -> void:
	big_map.visible = false
	big_pad.visible = false
	big_dim.visible = false


func big_map_open() -> bool:
	return big_map.visible or big_pad.visible


func clear_annotations() -> void:
	big_map.reset_annotations()
	big_pad.annot_img = big_map.annot_img
	big_pad.annot_tex = big_map.annot_tex


func set_tools(t: Dictionary) -> void:
	for id in tool_chips:
		tool_chips[id].add_theme_color_override("font_color",
			Color(1.0, 0.82, 0.25) if t[id] else Color(1, 1, 1, 0.3))
	map_panel.visible = t.map or t.notepad
	map_overlay.paper = t.notepad and not t.map
	compass.visible = t.compass


func set_map_texture(tex: Texture2D) -> void:
	map_overlay.map_tex = tex
	big_map.map_tex = tex


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
	var paper := false  ## notepad-only mode: paper, trail, and spots

	func _process(_d: float) -> void:
		if is_visible_in_tree():
			queue_redraw()

	func _to_px(w: Vector2) -> Vector2:
		return Vector2((w.x + 250.0) / 500.0 * size.x, (w.y + 250.0) / 500.0 * size.y)

	func _draw() -> void:
		if main == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size),
			Color(0.88, 0.84, 0.72, 0.95) if paper else Color(0.08, 0.07, 0.05, 0.85), true)
		var pp := Vector2.ZERO
		var f := 0.0
		if main.player:
			pp = _to_px(Vector2(main.player.global_position.x, main.player.global_position.z))
			f = main.player.cam_yaw
		if main.tools.compass:
			_draw_map_and_dots()
			if main.player:
				var arrow_col := Color(0.35, 0.3, 0.25) if paper else Color.WHITE
				_arrow(pp, f, arrow_col)
		elif main.player:
			# Rotate the whole view around the player so facing is up.
			var rz := Transform2D(f, Vector2.ZERO)
			draw_set_transform_matrix(Transform2D(f, size * 0.5 - rz * pp))
			_draw_map_and_dots()
			draw_set_transform_matrix(Transform2D())
			_arrow(size * 0.5, 0.0, Color(0.35, 0.3, 0.25) if paper else Color.WHITE)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.75, 0.5, 0.9), false, 2.0)

	func _draw_map_and_dots() -> void:
		if map_tex and not paper:
			draw_texture_rect(map_tex, Rect2(Vector2.ZERO, size), false)
		# Nothing is written down until you hold the pencil.
		if not main.tools.pencil:
			return
		if main.trail.size() > 1:
			var pts := PackedVector2Array()
			for p in main.trail:
				pts.append(_to_px(p))
			draw_polyline(pts, Color(0.45, 0.12, 0.08, 0.8), 1.3)
		var sel: Interactable = main.selected_spot()
		for s in main.structures:
			if not is_instance_valid(s):
				continue
			if paper:
				# The notepad records what you've logged — and crosses off
				# every node you've searched.
				var pn := _to_px(Vector2(s.global_position.x, s.global_position.z))
				if s.opened:
					_cross(pn, 3.2, Color(0.42, 0.10, 0.07, 0.9))
				elif s.spotted:
					draw_circle(pn, 3.2, Color(0.25, 0.65, 0.25))
					if s == sel:
						draw_arc(pn, 5.5, 0.0, TAU, 16, Color(0.25, 0.65, 0.25), 1.4)
				continue
			if not s.seen:
				continue
			var p := _to_px(Vector2(s.global_position.x, s.global_position.z))
			if s.opened:
				_cross(p, 3.2, Color(0.42, 0.10, 0.07, 0.9))
			elif s.spotted:
				draw_circle(p, 3.2, Color(0.3, 0.95, 0.35))
				if s == sel:
					draw_arc(p, 5.5, 0.0, TAU, 16, Color(0.3, 0.95, 0.35), 1.4)
			else:
				draw_circle(p, 3.0, Color(1.0, 0.82, 0.25))

	func _cross(p: Vector2, r: float, col: Color) -> void:
		draw_line(p + Vector2(-r, -r), p + Vector2(r, r), col, 1.6)
		draw_line(p + Vector2(-r, r), p + Vector2(r, -r), col, 1.6)

	func _arrow(pp: Vector2, f: float, col := Color.WHITE) -> void:
		var dirv := Vector2(-sin(f), -cos(f))
		var side := dirv.orthogonal()
		draw_colored_polygon(PackedVector2Array([
			pp + dirv * 8.0, pp - dirv * 4.0 + side * 4.5, pp - dirv * 4.0 - side * 4.5]),
			col)


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
		# Green caret at the bearing of the selected spotted node.
		var spot: Interactable = main.selected_spot()
		if spot and is_instance_valid(spot):
			var d3: Vector3 = spot.global_position - main.player.global_position
			var bearing := wrapf(rad_to_deg(-atan2(-d3.x, -d3.z)), 0.0, 360.0)
			var delta := wrapf(bearing - heading + 180.0, 0.0, 360.0) - 180.0
			var x := cx + clampf(delta * 3.4, -175.0, 175.0)
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 6, 40), Vector2(x + 6, 40), Vector2(x, 32)]),
				Color(0.3, 0.95, 0.35))


## Full-screen map (M): the painted terrain with trail ink and node marks
## (pencil-gated, same rules as the minimap), plus a lightweight paint layer —
## LMB draws with the pencil, RMB erases strokes AND trail with the eraser.
class BigMap:
	extends Control
	const ANNOT_RES := 512
	var main: Node = null
	var map_tex: Texture2D = null
	var paper := false  ## notepad view: paper + trail + spots, no terrain
	var annot_img: Image
	var annot_tex: ImageTexture
	var _last := Vector2(-9999, -9999)
	var _content_xf := Transform2D()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func reset_annotations() -> void:
		annot_img = Image.create(ANNOT_RES, ANNOT_RES, false, Image.FORMAT_RGBA8)
		annot_img.fill(Color(0, 0, 0, 0))
		annot_tex = ImageTexture.create_from_image(annot_img)

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _to_px(w: Vector2) -> Vector2:
		return Vector2((w.x + 250.0) / 500.0 * size.x, (w.y + 250.0) / 500.0 * size.y)

	func _world_of(local: Vector2) -> Vector2:
		return Vector2(local.x / size.x * 500.0 - 250.0, local.y / size.y * 500.0 - 250.0)

	func _cross(p: Vector2, r: float, col: Color) -> void:
		draw_line(p + Vector2(-r, -r), p + Vector2(r, r), col, 2.2)
		draw_line(p + Vector2(-r, r), p + Vector2(r, -r), col, 2.2)

	func _draw() -> void:
		if main == null:
			return
		var bgc := Color(0.88, 0.84, 0.72, 0.98) if paper else Color(0.10, 0.08, 0.06, 0.97)
		draw_rect(Rect2(Vector2.ZERO, size), bgc, true)
		# Without the compass the whole view rotates around you: facing = up.
		var pp := Vector2.ZERO
		var fy := 0.0
		if main.player:
			pp = _to_px(Vector2(main.player.global_position.x, main.player.global_position.z))
			fy = main.player.cam_yaw
		_content_xf = Transform2D()
		if not main.tools.compass and main.player:
			var rz := Transform2D(fy, Vector2.ZERO)
			_content_xf = Transform2D(fy, size * 0.5 - rz * pp)
		draw_set_transform_matrix(_content_xf)
		if map_tex and not paper:
			draw_texture_rect(map_tex, Rect2(Vector2.ZERO, size), false)
		if annot_tex:
			draw_texture_rect(annot_tex, Rect2(Vector2.ZERO, size), false)
		if main.tools.pencil:
			if main.trail.size() > 1:
				var pts := PackedVector2Array()
				for p in main.trail:
					pts.append(_to_px(p))
				draw_polyline(pts, Color(0.45, 0.12, 0.08, 0.85), 2.0)
			var sel: Interactable = main.selected_spot()
			for s in main.structures:
				if not is_instance_valid(s):
					continue
				var p := _to_px(Vector2(s.global_position.x, s.global_position.z))
				if paper:
					if s.opened:
						_cross(p, 5.0, Color(0.42, 0.10, 0.07, 0.9))
					elif s.spotted:
						draw_circle(p, 5.0, Color(0.25, 0.65, 0.25))
						if s == sel:
							draw_arc(p, 9.0, 0.0, TAU, 20, Color(0.25, 0.65, 0.25), 2.0)
					continue
				if not s.seen:
					continue
				if s.opened:
					_cross(p, 5.0, Color(0.42, 0.10, 0.07, 0.9))
				elif s.spotted:
					draw_circle(p, 5.0, Color(0.3, 0.95, 0.35))
					if s == sel:
						draw_arc(p, 9.0, 0.0, TAU, 20, Color(0.3, 0.95, 0.35), 2.0)
				else:
					draw_circle(p, 4.5, Color(1.0, 0.82, 0.25))
		draw_set_transform_matrix(Transform2D())
		if main.player:
			var mark_col := Color(0.35, 0.3, 0.25) if paper else Color.WHITE
			if main.tools.compass:
				var dirv := Vector2(-sin(fy), -cos(fy))
				var side := dirv.orthogonal()
				draw_colored_polygon(PackedVector2Array([
					pp + dirv * 12.0, pp - dirv * 6.0 + side * 7.0, pp - dirv * 6.0 - side * 7.0]),
					mark_col)
			else:
				var c2 := size * 0.5
				draw_colored_polygon(PackedVector2Array([
					c2 + Vector2(0, -12), c2 + Vector2(-7, 6), c2 + Vector2(7, 6)]), mark_col)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.85, 0.75, 0.5), false, 3.0)
		var hint := ("N — close" if paper else "M — close")
		if main.tools.pencil:
			hint += " · left-drag draw"
		if main.tools.eraser:
			hint += " · right-drag erase"
		var f := ThemeDB.fallback_font
		var hint_col := Color(0.3, 0.25, 0.2) if paper else Color(1, 0.95, 0.8)
		draw_string_outline(f, Vector2(12, size.y - 12), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5,
			Color(1, 1, 1, 0.6) if paper else Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(12, size.y - 12), hint,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, hint_col)

	func _gui_input(event: InputEvent) -> void:
		if main == null:
			return
		if event is InputEventMouseButton and not event.pressed:
			_last = Vector2(-9999, -9999)
			return
		var draw_btn := false
		var erase_btn := false
		var pos := Vector2.ZERO
		if event is InputEventMouseButton and event.pressed:
			pos = event.position
			draw_btn = event.button_index == MOUSE_BUTTON_LEFT
			erase_btn = event.button_index == MOUSE_BUTTON_RIGHT
			_last = Vector2(-9999, -9999)
		elif event is InputEventMouseMotion:
			pos = event.position
			draw_btn = (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
			erase_btn = (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0
		else:
			return
		if draw_btn and main.tools.pencil:
			_stroke(pos, false)
		elif erase_btn and main.tools.eraser:
			_stroke(pos, true)
		else:
			_last = Vector2(-9999, -9999)

	func _stroke(screen_pos: Vector2, erase: bool) -> void:
		# Screen → map space (undo the facing rotation when active).
		var pos := _content_xf.affine_inverse() * screen_pos
		var from := _last if _last.x > -9000.0 else pos
		var steps := maxi(int(from.distance_to(pos) / 2.0), 1)
		for i in steps + 1:
			var p := from.lerp(pos, float(i) / steps)
			_brush(p / size * float(ANNOT_RES), erase)
			if erase:
				main.erase_trail_near(_world_of(p), 9.0)
		_last = pos
		annot_tex.update(annot_img)

	func _brush(ip: Vector2, erase: bool) -> void:
		var r := 7 if erase else 2
		var col := Color(0, 0, 0, 0) if erase else Color(0.42, 0.10, 0.07, 0.95)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if dx * dx + dy * dy > r * r:
					continue
				var px := int(ip.x) + dx
				var py := int(ip.y) + dy
				if px < 0 or py < 0 or px >= ANNOT_RES or py >= ANNOT_RES:
					continue
				annot_img.set_pixel(px, py, col)


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
		# Scope: black vignette around a circular viewport with crosshairs.
		var c := size * 0.5
		var t: float = clampf((72.0 - cam.fov) / (72.0 - 16.0), 0.0, 1.0)
		var r := minf(size.x, size.y) * 0.42
		if t > 0.03:
			draw_arc(c, r + 600.0, 0.0, TAU, 64, Color(0, 0, 0, t), 1200.0)
			draw_arc(c, r + 3.0, 0.0, TAU, 64, Color(0, 0, 0, t), 8.0)
			draw_line(Vector2(c.x - r, c.y), Vector2(c.x + r, c.y), Color(0, 0, 0, 0.45 * t), 1.0)
			draw_line(Vector2(c.x, c.y - r), Vector2(c.x, c.y + r), Color(0, 0, 0, 0.45 * t), 1.0)
		for sp in spots:
			var p: Vector2 = cam.unproject_position(sp.pos)
			var centered: bool = sp.get("centered", false)
			var col := Color(0.5, 1.0, 0.5) if centered else Color(1, 0.95, 0.75)
			draw_circle(p, 3.0 if centered else 2.5,
				Color(0.3, 0.95, 0.35) if centered else Color(1, 0.85, 0.3))
			draw_string_outline(f, p + Vector2(-90, -8), sp.text,
				HORIZONTAL_ALIGNMENT_CENTER, 180, 13, 4, Color(0, 0, 0, 0.85))
			draw_string(f, p + Vector2(-90, -8), sp.text,
				HORIZONTAL_ALIGNMENT_CENTER, 180, 13, col)


func _ready() -> void:
	var help := _label(14, Color(1, 1, 1, 0.75))
	help.text = "Left-drag orbit · Right-drag steer · Both buttons run · Wheel zoom\nClick target · Right-click / E search · WASD move · Arrows turn/walk · Shift sprint · Space jump\nZ spyglass · M map · N notepad · Tab cycle spots · F8 / Dev Note feedback · Esc deselect / menu"
	help.set_anchors_preset(Control.PRESET_TOP_LEFT)
	help.position = Vector2(14, 8)
	add_child(help)

	day_label = _label(15, Color(1.0, 0.95, 0.8))
	day_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	day_label.position = Vector2(14, 74)
	add_child(day_label)

	counter = _label(20, Color.WHITE)
	counter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	counter.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	counter.position = Vector2(-370, 10)  # clear of the Dev Note corner button
	counter.size = Vector2(236, 30)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(counter)

	# sprint stamina bar (fades away when full)
	stam_bg = ColorRect.new()
	stam_bg.color = Color(0, 0, 0, 0.55)
	stam_bg.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stam_bg.position = Vector2(-92, -52)
	stam_bg.size = Vector2(184, 9)
	stam_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stam_bg)
	stam_fill = ColorRect.new()
	stam_fill.color = Color(0.4, 0.85, 0.35)
	stam_fill.position = Vector2(2, 2)
	stam_fill.size = Vector2(180, 5)
	stam_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stam_bg.add_child(stam_fill)
	stam_bg.visible = false

	# coffee: clickable once found (bottom-center, under the character);
	# while active the stamina bar becomes the glowing yellow countdown
	coffee_btn = Button.new()
	coffee_btn.text = "Drink coffee"
	coffee_btn.custom_minimum_size = Vector2(160, 38)
	coffee_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	coffee_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	coffee_btn.position = Vector2(-80, -104)
	coffee_btn.visible = false
	coffee_btn.pressed.connect(func() -> void:
		if main:
			main.drink_coffee())
	add_child(coffee_btn)
	coffee_buff = _label(15, Color(1.0, 0.85, 0.35))
	coffee_buff.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	coffee_buff.position = Vector2(-90, -72)
	coffee_buff.size = Vector2(180, 18)
	coffee_buff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coffee_buff.visible = false
	add_child(coffee_buff)

	# winded recovery countdown (sits where the coffee buff text does; the
	# two never show together — caffeine suspends the stamina economy)
	winded_label = _label(15, Color(1.0, 0.55, 0.45))
	winded_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	winded_label.position = Vector2(-90, -72)
	winded_label.size = Vector2(180, 18)
	winded_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winded_label.visible = false
	add_child(winded_label)

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

	# tool chips (dim until found), two rows
	var chips_v := VBoxContainer.new()
	chips_v.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	chips_v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	chips_v.position = Vector2(-250, 66)
	chips_v.size = Vector2(236, 44)
	chips_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chips_v)
	for row in [["map", "compass", "spyglass", "irons"], ["pencil", "notepad", "eraser"]]:
		var chips := HBoxContainer.new()
		chips.alignment = BoxContainer.ALIGNMENT_END
		chips.add_theme_constant_override("separation", 12)
		chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chips_v.add_child(chips)
		for id in row:
			var c := _label(14, Color(1, 1, 1, 0.3))
			c.text = id.capitalize()
			chips.add_child(c)
			tool_chips[id] = c

	# minimap (visible once the map is found)
	map_panel = Control.new()
	map_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	map_panel.position = Vector2(-238, 118)
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

	# spotted-nodes list (bottom right)
	spot_panel = PanelContainer.new()
	spot_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	spot_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	spot_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	spot_panel.position = Vector2(-264, -46)
	spot_panel.custom_minimum_size = Vector2(250, 0)
	spot_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot_panel.visible = false
	var sv := VBoxContainer.new()
	sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spot_panel.add_child(sv)
	var st := _label(13, Color(1.0, 0.85, 0.4))
	st.text = "Spotted — Tab to cycle"
	sv.add_child(st)
	spot_box = VBoxContainer.new()
	spot_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sv.add_child(spot_box)
	add_child(spot_panel)

	# full map view (M)
	big_dim = ColorRect.new()
	big_dim.color = Color(0, 0, 0, 0.45)
	big_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	big_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	big_dim.visible = false
	add_child(big_dim)
	big_map = BigMap.new()
	big_map.visible = false
	add_child(big_map)
	big_pad = BigMap.new()
	big_pad.paper = true
	big_pad.visible = false
	add_child(big_pad)
	clear_annotations()

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


func set_stamina(v: float, locked: bool, lock_left := 0.0) -> void:
	if main and main.coffee_active():
		winded_label.visible = false
		return  # _process owns the bar while caffeinated
	stam_bg.visible = v < 0.999 or locked
	winded_label.visible = locked
	if locked:
		# Winded: the bar goes red and refills with green over the recovery
		# minute, with the remaining time counted down above it.
		var t := clampf(1.0 - lock_left / 60.0, 0.0, 1.0)
		stam_bg.color = Color(0.42, 0.07, 0.05, 0.8)
		stam_fill.size.x = 180.0 * t
		stam_fill.color = Color(0.4, 0.85, 0.35)
		winded_label.text = "Winded · %d s" % int(ceilf(lock_left))
	else:
		stam_bg.color = Color(0, 0, 0, 0.55)
		stam_fill.size.x = 180.0 * v
		if v < 0.3:
			stam_fill.color = Color(0.9, 0.7, 0.25)
		else:
			stam_fill.color = Color(0.4, 0.85, 0.35)


func win(total: int, time_str: String) -> void:
	banner.visible = true
	banner_label.text = "EVERY HIDING PLACE SEARCHED!\nAll %d found in %s.\nAnother world awaits — a new day, or a random map." % [total, time_str]


func hide_banner() -> void:
	banner.visible = false
