class_name GameMenu
extends CanvasLayer
## Esc pause menu: re-hide the tag, restart the day, travel to one of the
## last 7 daily worlds, or quit — every action behind a confirmation dialog.
## Esc first clears the current target (WoW-style), then opens the menu.

var main: Node = null
var day_info: Label
var day_buttons: Array[Button] = []
var confirm: ConfirmationDialog
var _pending := Callable()
var _restart_btn: Button
var _random_btn: Button
var _travel_label: Label


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 22)
	panel.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var title := Label.new()
	title.text = "Seeker"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	day_info = Label.new()
	day_info.add_theme_font_size_override("font_size", 15)
	day_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	day_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(day_info)
	v.add_child(HSeparator.new())

	_btn(v, "Resume").pressed.connect(close)
	_restart_btn = _btn(v, "Restart this day…")
	_restart_btn.pressed.connect(func() -> void:
		_ask("Regenerate this world from scratch?",
			func() -> void: main.restart_current()))
	_random_btn = _btn(v, "New random map…")
	_random_btn.pressed.connect(func() -> void:
		_ask("Generate a fresh random map?",
			func() -> void: main.new_random_map()))
	v.add_child(HSeparator.new())

	_travel_label = Label.new()
	_travel_label.text = "Travel to a day:"
	_travel_label.add_theme_font_size_override("font_size", 15)
	v.add_child(_travel_label)
	for i in 7:
		var off := i
		var b := _btn(v, "")
		b.pressed.connect(func() -> void:
			_ask("Travel to %s? The world will regenerate." % main.day_label(off),
				func() -> void: main.load_day(off)))
		day_buttons.append(b)
	v.add_child(HSeparator.new())
	_btn(v, "Return to title…").pressed.connect(func() -> void:
		_ask("Leave this world and return to the title screen?",
			func() -> void: main.return_to_title()))
	_btn(v, "Quit…").pressed.connect(func() -> void:
		_ask("Quit Seeker?", func() -> void: main.quit_game()))

	confirm = ConfirmationDialog.new()
	confirm.title = "Confirm"
	confirm.confirmed.connect(_on_confirmed)
	add_child(confirm)


func _btn(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(300, 34)
	parent.add_child(b)
	return b


func _ask(text: String, action: Callable) -> void:
	_pending = action
	confirm.dialog_text = text
	confirm.popup_centered()


func _on_confirmed() -> void:
	close()
	if _pending.is_valid():
		_pending.call()
	_pending = Callable()


func open() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if main and main.player:
		main.player.release_drag()
	if main:
		day_info.text = "%s · %s · %s · %d/%d searched" % [
			main.world_title(), main.biome.label, main.mood_name,
			main.searched_count, main.structures.size()]
		var daily: bool = main.game_mode == "daily"
		_restart_btn.text = "Restart this day…" if daily else "Restart this map…"
		_random_btn.visible = not daily
		_travel_label.visible = daily
		for i in 7:
			day_buttons[i].visible = daily
			day_buttons[i].text = main.day_label(i)
			day_buttons[i].disabled = daily and i == main.day_offset


func close() -> void:
	visible = false
	get_tree().paused = false
	confirm.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if main and main.world == null:
			return
		if visible:
			close()
		elif main and main.hud and main.hud.big_map_open():
			main.hud.toggle_big_map()
		elif main and main.player and main.player.target:
			main.player.set_target(null)
		else:
			open()
		get_viewport().set_input_as_handled()
