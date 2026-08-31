class_name TexF
## Procedural texture / material factory. Everything is generated from noise
## at runtime, so the project needs no imported image assets.

static var _mats := {}
static var _texs := {}


static func noise_tex(key: String, sd: int, freq: float, offsets: Array,
		colors: Array, seamless := true) -> NoiseTexture2D:
	if _texs.has(key):
		return _texs[key]
	var n := FastNoiseLite.new()
	n.seed = sd
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = seamless
	t.noise = n
	if colors.size() > 0:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(offsets)
		g.colors = PackedColorArray(colors)
		t.color_ramp = g
	_texs[key] = t
	return t


static func normal_tex() -> NoiseTexture2D:
	if _texs.has("nrm"):
		return _texs["nrm"]
	var n := FastNoiseLite.new()
	n.seed = 105
	n.frequency = 0.12
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 5.0
	t.noise = n
	_texs["nrm"] = t
	return t


static func terrain_textures() -> Dictionary:
	return {
		grass = noise_tex("grass", 101, 0.18,
			[0.0, 0.45, 0.75, 1.0],
			[Color(0.13, 0.27, 0.09), Color(0.22, 0.38, 0.12),
			 Color(0.30, 0.45, 0.16), Color(0.42, 0.50, 0.20)]),
		dirt = noise_tex("dirt", 102, 0.12,
			[0.0, 0.5, 1.0],
			[Color(0.28, 0.20, 0.13), Color(0.38, 0.29, 0.18), Color(0.48, 0.38, 0.24)]),
		rock = noise_tex("rock", 103, 0.06,
			[0.0, 0.4, 0.7, 1.0],
			[Color(0.30, 0.30, 0.31), Color(0.42, 0.41, 0.40),
			 Color(0.50, 0.49, 0.47), Color(0.60, 0.58, 0.55)]),
		mask = noise_tex("mask", 104, 0.04, [], []),
		nrm = normal_tex(),
	}


static func _std(tex: Texture2D, tint: Color, uvs: Vector3, rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if tex:
		m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_scale = uvs
	m.roughness = rough
	return m


static func plain(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "plain_" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var wood_tex := noise_tex("wood", 110, 0.3,
		[0.0, 0.5, 1.0],
		[Color(0.34, 0.22, 0.11), Color(0.48, 0.33, 0.17), Color(0.40, 0.26, 0.13)])
	var m: Material = null
	match key:
		"wood":
			m = _std(wood_tex, Color.WHITE, Vector3(0.5, 3.5, 1.0))
		"darkwood":
			m = _std(wood_tex, Color(0.55, 0.45, 0.40), Vector3(0.5, 3.5, 1.0))
		"plank":
			m = _std(wood_tex, Color(0.82, 0.74, 0.66), Vector3(1.2, 5.0, 1.0))
		"floor":
			m = _std(wood_tex, Color(0.75, 0.68, 0.60), Vector3(2.5, 0.6, 1.0))
		"plaster":
			m = _std(noise_tex("plaster", 111, 0.5, [0.0, 1.0],
				[Color(0.78, 0.75, 0.68), Color(0.87, 0.84, 0.77)]),
				Color.WHITE, Vector3(1, 1, 1))
		"roof":
			m = _std(noise_tex("rooftex", 112, 0.2, [0.0, 0.5, 1.0],
				[Color(0.42, 0.16, 0.11), Color(0.55, 0.24, 0.15), Color(0.38, 0.13, 0.09)]),
				Color.WHITE, Vector3(3, 3, 1))
		"roof_dark":
			m = _std(noise_tex("roofdark", 113, 0.25, [0.0, 1.0],
				[Color(0.25, 0.26, 0.30), Color(0.35, 0.36, 0.40)]),
				Color.WHITE, Vector3(3, 3, 1))
		"stone":
			m = _std(noise_tex("rock", 103, 0.06, [], []), Color(0.62, 0.60, 0.57), Vector3(2, 2, 1))
		"bark":
			m = _std(noise_tex("bark", 114, 0.5, [0.0, 0.6, 1.0],
				[Color(0.22, 0.15, 0.10), Color(0.33, 0.24, 0.15), Color(0.28, 0.19, 0.12)]),
				Color.WHITE, Vector3(6.0, 0.8, 1.0))
		"leaves":
			m = _std(noise_tex("leaves", 115, 0.5, [0.0, 0.5, 1.0],
				[Color(0.13, 0.30, 0.10), Color(0.22, 0.42, 0.14), Color(0.30, 0.48, 0.18)]),
				Color.WHITE, Vector3(2, 2, 1))
		"leaves_dark":
			m = _std(noise_tex("leavesdark", 116, 0.5, [0.0, 0.5, 1.0],
				[Color(0.08, 0.22, 0.10), Color(0.14, 0.30, 0.14), Color(0.18, 0.35, 0.16)]),
				Color.WHITE, Vector3(2, 2, 1))
		"straw":
			m = _std(noise_tex("straw", 117, 0.45, [0.0, 0.5, 1.0],
				[Color(0.62, 0.48, 0.20), Color(0.78, 0.64, 0.30), Color(0.70, 0.55, 0.24)]),
				Color.WHITE, Vector3(1.0, 4.0, 1.0))
		"dirt_mound":
			m = _std(noise_tex("dirt", 102, 0.12, [], []), Color(0.42, 0.32, 0.22), Vector3(1.5, 1.5, 1.0))
		"tag":
			m = _std(noise_tex("tagtex", 118, 0.4, [0.0, 1.0],
				[Color(0.78, 0.64, 0.42), Color(0.88, 0.76, 0.52)]),
				Color.WHITE, Vector3(1, 1, 1))
		"metal":
			m = plain(Color(0.25, 0.24, 0.22), 0.45, 0.7)
		"window":
			m = plain(Color(0.12, 0.16, 0.22), 0.15, 0.4)
		"blanket":
			m = plain(Color(0.45, 0.15, 0.15), 0.9)
		"pillow":
			m = plain(Color(0.9, 0.88, 0.82), 0.9)
		"water":
			var w := StandardMaterial3D.new()
			w.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			w.albedo_color = Color(0.12, 0.34, 0.44, 0.62)
			w.roughness = 0.06
			w.metallic = 0.3
			m = w
		_:
			m = plain(Color.MAGENTA)
	_mats[key] = m
	return m
