class_name TexF
## Texture / material factory. Real CC0 PBR photo textures (textures/,
## loaded at runtime — no importer involved) carry the world's key
## surfaces; procedural noise still fills in the rest.

static var _mats := {}
static var _texs := {}


## Loads textures/<file>.jpg from disk (the folder is .gdignore'd, so this
## bypasses the resource importer entirely — works headless too).
## Returns null if the file is missing so callers can fall back to noise.
static func pbr_tex(file: String) -> ImageTexture:
	var key := "pbr_" + file
	if _texs.has(key):
		return _texs[key]
	var path := ProjectSettings.globalize_path("res://textures/%s.jpg" % file)
	if not FileAccess.file_exists(path):
		_texs[key] = null
		return null
	var img := Image.load_from_file(path)
	if img == null:
		_texs[key] = null
		return null
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_texs[key] = t
	return t


## A PBR standard material: photo albedo (tinted) plus its normal map.
static func _pbr(slug: String, tint: Color, uvs: Vector3,
		rough := 0.95) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var diff := pbr_tex(slug + "_diff")
	if diff:
		m.albedo_texture = diff
	var nor := pbr_tex(slug + "_nor")
	if nor:
		m.normal_enabled = true
		m.normal_texture = nor
		m.normal_scale = 0.8
	m.albedo_color = tint
	m.uv1_scale = uvs
	m.roughness = rough
	return m


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
	var m: Material = null
	match key:
		"wood":
			m = _pbr("planks_brown_10", Color(1.05, 1.0, 0.95), Vector3(1, 1, 1))
		"darkwood":
			m = _pbr("planks_brown_10", Color(0.58, 0.48, 0.42), Vector3(1, 1, 1))
		"plank":
			m = _pbr("planks_brown_10", Color(1.18, 1.12, 1.05), Vector3(1.5, 1.5, 1))
		"floor":
			m = _pbr("planks_brown_10", Color(1.0, 0.94, 0.86), Vector3(2, 2, 1))
		"plaster":
			m = _pbr("plastered_wall_02", Color.WHITE, Vector3(1.6, 1.0, 1))
		"roof":
			m = _pbr("clay_roof_tiles", Color.WHITE, Vector3(3, 3, 1))
		"roof_dark":
			m = _pbr("clay_roof_tiles", Color(0.5, 0.52, 0.58), Vector3(3, 3, 1))
		"stone":
			m = _pbr("stone_tile_wall", Color(0.8, 0.78, 0.75), Vector3(1.6, 1.6, 1))
		"rockface":
			m = _pbr("rocky_terrain", Color(0.95, 0.96, 1.0), Vector3(1, 1, 1))
		"bark":
			m = _pbr("bark_brown_01", Color.WHITE, Vector3(2.0, 1.0, 1))
		"leaves":
			m = _std(noise_tex("leaves", 115, 0.5, [0.0, 0.5, 1.0],
				[Color(0.13, 0.30, 0.10), Color(0.22, 0.42, 0.14), Color(0.30, 0.48, 0.18)]),
				Color.WHITE, Vector3(2, 2, 1))
		"leaves_dark":
			m = _std(noise_tex("leavesdark", 116, 0.5, [0.0, 0.5, 1.0],
				[Color(0.08, 0.22, 0.10), Color(0.14, 0.30, 0.14), Color(0.18, 0.35, 0.16)]),
				Color.WHITE, Vector3(2, 2, 1))
		"heather":
			m = _std(noise_tex("heather", 141, 0.5, [0.0, 0.5, 1.0],
				[Color(0.36, 0.22, 0.42), Color(0.50, 0.30, 0.55), Color(0.44, 0.34, 0.30)]),
				Color.WHITE, Vector3(2, 2, 1))
		"straw":
			m = _std(noise_tex("straw", 117, 0.45, [0.0, 0.5, 1.0],
				[Color(0.62, 0.48, 0.20), Color(0.78, 0.64, 0.30), Color(0.70, 0.55, 0.24)]),
				Color.WHITE, Vector3(1.0, 4.0, 1.0))
		"dirt_mound":
			m = _pbr("brown_mud", Color(0.9, 0.85, 0.8), Vector3(1.5, 1.5, 1))
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
		"oasis":
			var o := StandardMaterial3D.new()
			o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			o.albedo_color = Color(0.14, 0.42, 0.40, 0.66)
			o.roughness = 0.08
			o.metallic = 0.25
			m = o
		"ice":
			m = _std(noise_tex("icetex", 130, 0.08, [0.0, 1.0],
				[Color(0.78, 0.86, 0.92), Color(0.90, 0.95, 1.0)]),
				Color.WHITE, Vector3(6, 6, 1), 0.25)
		"snow":
			m = _pbr("snow_02", Color.WHITE, Vector3(1.5, 1.5, 1))
		"leaf_pile":
			m = _std(noise_tex("leafpile", 132, 0.5, [0.0, 0.4, 0.7, 1.0],
				[Color(0.55, 0.22, 0.08), Color(0.72, 0.38, 0.10),
				 Color(0.62, 0.28, 0.10), Color(0.78, 0.55, 0.16)]),
				Color.WHITE, Vector3(2, 2, 1))
		"sand_mound":
			m = _pbr("coast_sand_01", Color(1.05, 0.95, 0.8), Vector3(1.5, 1.5, 1))
		"bleached":
			m = _pbr("bark_brown_01", Color(1.3, 1.24, 1.12), Vector3(2.0, 1.0, 1))
		"clay":
			m = _std(noise_tex("claytex", 133, 0.25, [0.0, 1.0],
				[Color(0.62, 0.36, 0.22), Color(0.74, 0.48, 0.30)]),
				Color.WHITE, Vector3(1.5, 1.5, 1))
		"bone":
			m = plain(Color(0.88, 0.85, 0.76), 0.7)
		"adobe":
			m = _pbr("plastered_wall_02", Color(1.05, 0.86, 0.62), Vector3(1.6, 1.0, 1))
		"timber":
			m = _pbr("planks_brown_10", Color(0.55, 0.45, 0.38), Vector3(1, 1, 1))
		"logwall":
			m = _pbr("bark_brown_01", Color(0.95, 0.82, 0.68), Vector3(3.0, 1.0, 1))
		"cactus":
			m = _std(noise_tex("cactustex", 135, 0.5, [0.0, 1.0],
				[Color(0.22, 0.42, 0.20), Color(0.34, 0.55, 0.28)]),
				Color.WHITE, Vector3(4.0, 0.8, 1.0))
		"deadwood":
			m = _pbr("bark_brown_01", Color(0.85, 0.78, 0.68), Vector3(2.0, 1.0, 1))
		"dry_bush":
			m = _std(noise_tex("leaves", 115, 0.5, [], []), Color(0.55, 0.48, 0.28), Vector3(2, 2, 1))
		"leaves_autumn1":
			m = _std(noise_tex("laut1", 136, 0.5, [0.0, 0.5, 1.0],
				[Color(0.62, 0.25, 0.08), Color(0.78, 0.40, 0.10), Color(0.70, 0.32, 0.10)]),
				Color.WHITE, Vector3(2, 2, 1))
		"leaves_autumn2":
			m = _std(noise_tex("laut2", 137, 0.5, [0.0, 0.5, 1.0],
				[Color(0.72, 0.14, 0.10), Color(0.85, 0.28, 0.14), Color(0.62, 0.18, 0.10)]),
				Color.WHITE, Vector3(2, 2, 1))
		"leaves_autumn3":
			m = _std(noise_tex("laut3", 138, 0.5, [0.0, 0.5, 1.0],
				[Color(0.80, 0.60, 0.14), Color(0.90, 0.74, 0.24), Color(0.74, 0.55, 0.14)]),
				Color.WHITE, Vector3(2, 2, 1))
		"mushroom_cap":
			m = plain(Color(0.75, 0.18, 0.14), 0.6)
		"roof_brown":
			m = _pbr("clay_roof_tiles", Color(0.62, 0.47, 0.36), Vector3(3, 3, 1))
		_:
			m = plain(Color.MAGENTA)
	_mats[key] = m
	return m
