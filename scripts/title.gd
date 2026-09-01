class_name TitleScreen
extends CanvasLayer
## Title screen: choose Daily Map (the date-seeded world) or Random Map
## (fresh seed, optionally typed — numbers or words both work).

var main: Node = null
var seed_edit: LineEdit
var daily_btn: Button


func _init() -> void:
	layer = 8


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.10, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(v)

	var icon := TextureRect.new()
	icon.texture = load("res://icon.png")
	icon.custom_minimum_size = Vector2(110, 110)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)

	var title := Label.new()
	title.text = "SEEKER"
	title.add_theme_font_size_override("font_size", 58)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var tag := Label.new()
	tag.text = "Twenty hiding places. One numbered tag. Find it."
	tag.add_theme_font_size_override("font_size", 16)
	tag.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)
	v.add_child(_spacer(16))

	daily_btn = _btn(v, "Daily Map")
	daily_btn.pressed.connect(func() -> void: main.start_daily())
	var random_btn := _btn(v, "Random Map")
	random_btn.pressed.connect(func() -> void:
		main.start_random_from_text(seed_edit.text))
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "seed (optional — numbers or words)"
	seed_edit.custom_minimum_size = Vector2(320, 34)
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(seed_edit)
	v.add_child(_spacer(14))
	var quit_btn := _btn(v, "Quit")
	quit_btn.pressed.connect(func() -> void: main.quit_game())

	var foot := Label.new()
	foot.text = "F8 anytime — leave playtest feedback"
	foot.add_theme_font_size_override("font_size", 13)
	foot.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(foot)


func refresh() -> void:
	if main:
		daily_btn.text = "Daily Map — %s" % main.day_label(0)


func _btn(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 40)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(b)
	return b


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
