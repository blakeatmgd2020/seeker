class_name Feedback
extends CanvasLayer
## Playtest feedback + session telemetry. F8 opens a note form (category +
## free text); every note is stamped with game context, and a session
## summary is appended on quit. Reports are markdown files in feedback/
## (gitignored) — written for Claude to reference in future sessions.

var main: Node = null
var enabled := true
var searches := 0
var finds := 0
var tools_found: Array[String] = []
var worlds: Array[String] = []
var notes: Array[String] = []

var _session_start_ms := 0
var _session_stamp := ""
var _file_abs := ""
var _summary_text := ""
var _summary_written := false
var _prev_paused := false

var _dim: ColorRect
var _panel: PanelContainer
var _notes_panel: PanelContainer
var _notes_label: Label
var _text: TextEdit
var _cat_group := ButtonGroup.new()
var _cat_buttons: Array[Button] = []


func _show_notes() -> void:
	if notes.is_empty():
		_notes_label.text = "No notes yet this session."
	else:
		_notes_label.text = "\n".join(notes)
	_panel.visible = false
	_notes_panel.visible = true


func _init() -> void:
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_session_start_ms = Time.get_ticks_msec()
	_session_stamp = Time.get_datetime_string_from_system(false, true)
	var d := Time.get_datetime_dict_from_system()
	_file_abs = ProjectSettings.globalize_path(
		"res://feedback/session_%04d-%02d-%02d_%02d%02d%02d.md" %
		[d.year, d.month, d.day, d.hour, d.minute, d.second])

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.visible = false
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.visible = false
	center.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Playtest note"
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	# Bug on its own row, the rest below.
	var bug_row := HBoxContainer.new()
	bug_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(bug_row)
	var cats := HBoxContainer.new()
	cats.alignment = BoxContainer.ALIGNMENT_CENTER
	cats.add_theme_constant_override("separation", 8)
	v.add_child(cats)
	for c in ["Bug", "General", "Interface", "Gameplay"]:
		var b := Button.new()
		b.text = c
		b.toggle_mode = true
		b.button_group = _cat_group
		b.custom_minimum_size = Vector2(110, 34) if c == "Bug" else Vector2(105, 32)
		if c == "Bug":
			bug_row.add_child(b)
		else:
			cats.add_child(b)
		_cat_buttons.append(b)

	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(460, 120)
	_text.placeholder_text = "Details (optional)…"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	v.add_child(_text)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var save := Button.new()
	save.text = "Save note"
	save.custom_minimum_size = Vector2(140, 34)
	save.pressed.connect(_save)
	row.add_child(save)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(140, 34)
	cancel.pressed.connect(close_form)
	row.add_child(cancel)
	var view := Button.new()
	view.text = "View session notes"
	view.custom_minimum_size = Vector2(180, 30)
	view.pressed.connect(_show_notes)
	v.add_child(view)

	# Session-notes viewer.
	_notes_panel = PanelContainer.new()
	_notes_panel.visible = false
	center.add_child(_notes_panel)
	var nm := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		nm.add_theme_constant_override(side, 16)
	_notes_panel.add_child(nm)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 8)
	nm.add_child(nv)
	var nt := Label.new()
	nt.text = "Session notes"
	nt.add_theme_font_size_override("font_size", 20)
	nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(nt)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 380)
	nv.add_child(sc)
	_notes_label = Label.new()
	_notes_label.add_theme_font_size_override("font_size", 14)
	_notes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notes_label.custom_minimum_size = Vector2(540, 0)
	sc.add_child(_notes_label)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 32)
	back.pressed.connect(func() -> void:
		_notes_panel.visible = false
		_panel.visible = true)
	nv.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("feedback"):
		if _panel.visible or _notes_panel.visible:
			close_form()
		else:
			open_form()
		get_viewport().set_input_as_handled()
	elif (_panel.visible or _notes_panel.visible) and event.is_action_pressed("ui_cancel"):
		close_form()
		get_viewport().set_input_as_handled()


func open_form() -> void:
	_prev_paused = get_tree().paused
	get_tree().paused = true
	if main and main.player:
		main.player.release_drag()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_cat_buttons[1].button_pressed = true  # default: General
	_text.text = ""
	_dim.visible = true
	_panel.visible = true
	_notes_panel.visible = false
	_text.grab_focus()


func close_form() -> void:
	_dim.visible = false
	_panel.visible = false
	_notes_panel.visible = false
	get_tree().paused = _prev_paused


func _save() -> void:
	var cat := "note"
	var pressed := _cat_group.get_pressed_button()
	if pressed:
		cat = pressed.text
	add_note(cat, _text.text.strip_edges())
	close_form()
	if main and main.hud:
		main.hud.toast("Feedback noted — thanks.")


# --- log building --------------------------------------------------------

func add_note(cat: String, txt: String) -> void:
	var s := "### %s · %s\n" % [_clock(), cat.to_upper()]
	if not txt.is_empty():
		s += "> %s\n" % txt.replace("\n", "\n> ")
	s += _context()
	notes.append(s)
	_flush()


func log_world(desc: String) -> void:
	worlds.append("%s — %s" % [_clock(), desc])
	_flush()


func write_summary() -> void:
	if _summary_written:
		return
	_summary_written = true
	var secs := int((Time.get_ticks_msec() - _session_start_ms) / 1000.0)
	var dist := 0.0
	if main and main.player:
		dist = main.player.dist_walked
	var tool_txt := "none"
	if not tools_found.is_empty():
		tool_txt = ", ".join(tools_found)
	_summary_text = "## Session summary\n"
	_summary_text += "- duration %d:%02d · %d world(s)\n" % [
		secs / 60, secs % 60, worlds.size()]
	_summary_text += "- structures searched: %d · hunts completed: %d\n" % [searches, finds]
	_summary_text += "- tools collected: %s\n" % tool_txt
	_summary_text += "- distance walked: %.2f km\n" % (dist / 1000.0)
	_flush()


func _clock() -> String:
	var t := Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [t.hour, t.minute, t.second]


func _context() -> String:
	if main == null or main.world == null:
		return "- context: title screen\n"
	var s := "- world: %s · %s · %s · %s\n" % [
		main.world_title(), main.biome.label, main.mood_name, main.weather_name]
	var owned: Array[String] = []
	for id in main.tools:
		if main.tools[id]:
			owned.append(id)
	var tgt := "none"
	if main.player.target and is_instance_valid(main.player.target):
		tgt = main.player.target.display_name
	s += "- state: searched %d/%d · tools: %s · target: %s · pos (%d, %d)\n" % [
		main.searched_count, main.structures.size(),
		"none" if owned.is_empty() else ", ".join(owned), tgt,
		int(main.player.global_position.x), int(main.player.global_position.z)]
	return s


func _flush() -> void:
	if not enabled:
		return
	DirAccess.make_dir_recursive_absolute(_file_abs.get_base_dir())
	var f := FileAccess.open(_file_abs, FileAccess.WRITE)
	if f == null:
		return
	var s := "# Seeker playtest session — %s\n\n" % _session_stamp
	if not worlds.is_empty():
		s += "## Worlds visited\n"
		for w in worlds:
			s += "- %s\n" % w
		s += "\n"
	if not notes.is_empty():
		s += "## Notes\n\n"
		for n in notes:
			s += n + "\n"
	s += _summary_text
	f.store_string(s)
	f.close()
