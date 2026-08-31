extends SceneTree
## Headless icon generator:
##   Godot_console.exe --headless --path . -s tools/make_icon.gd
## Draws the Seeker icon (parchment map, hills, pond, dashed trail, red X)
## and saves icon.png plus smaller sizes for the .ico packer.


func _initialize() -> void:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rounded_rect(img, Rect2(14, 14, 228, 228), 34, Color(0.42, 0.30, 0.18))
	_rounded_rect(img, Rect2(26, 26, 204, 204), 26, Color(0.88, 0.77, 0.56))
	# pond
	_disc(img, Vector2(72, 78), 21, Color(0.25, 0.45, 0.55))
	# hills
	_disc(img, Vector2(178, 196), 34, Color(0.33, 0.46, 0.22))
	_disc(img, Vector2(128, 208), 30, Color(0.28, 0.40, 0.19))
	_disc(img, Vector2(76, 202), 26, Color(0.33, 0.46, 0.22))
	# dashed trail winding up toward the X
	var pts := [Vector2(60, 192), Vector2(88, 160), Vector2(124, 150),
		Vector2(152, 122), Vector2(162, 98)]
	for i in pts.size() - 1:
		_dashed(img, pts[i], pts[i + 1], 6.0, Color(0.45, 0.12, 0.08))
	# bold red X marks the spot
	var xc := Vector2(180, 78)
	var red := Color(0.72, 0.11, 0.09)
	_line(img, xc + Vector2(-23, -23), xc + Vector2(23, 23), 10.0, red)
	_line(img, xc + Vector2(-23, 23), xc + Vector2(23, -23), 10.0, red)
	img.save_png("res://icon.png")
	for s in [48, 32, 16]:
		var c: Image = img.duplicate()
		c.resize(s, s, Image.INTERPOLATE_LANCZOS)
		c.save_png("res://icon_%d.png" % s)
	print("ICON OK")
	quit(0)


func _rounded_rect(img: Image, r: Rect2, rad: float, col: Color) -> void:
	var imin := r.position + Vector2(rad, rad)
	var imax := r.end - Vector2(rad, rad)
	for y in range(int(r.position.y), int(r.end.y)):
		for x in range(int(r.position.x), int(r.end.x)):
			var nx := clampf(x, imin.x, imax.x)
			var ny := clampf(y, imin.y, imax.y)
			if Vector2(x - nx, y - ny).length() <= rad:
				img.set_pixel(x, y, col)


func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(maxi(0, int(c.y - r)), mini(256, int(c.y + r + 1))):
		for x in range(maxi(0, int(c.x - r)), mini(256, int(c.x + r + 1))):
			if Vector2(x - c.x, y - c.y).length() <= r:
				img.set_pixel(x, y, col)


func _line(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var steps := int(a.distance_to(b) / 0.6) + 1
	for i in steps + 1:
		_disc(img, a.lerp(b, float(i) / steps), w * 0.5, col)


func _dashed(img: Image, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var length := a.distance_to(b)
	var steps := int(length / 0.6) + 1
	for i in steps + 1:
		var d := length * float(i) / steps
		if fmod(d, 17.0) < 9.5:
			_disc(img, a.lerp(b, float(i) / steps), w * 0.5, col)
