class_name Terrain
extends StaticBody3D
## Heightfield terrain: simplex hills + macro relief + a mountain rim at the
## map edge, a flattened village plateau, and carved flat patches (terraces
## and building foundations) registered before build(). Splat-blended
## grass/dirt/rock shader with per-biome color ramps.

const SIZE := 500.0
const RES := 200
const VILLAGE_FLAT_R := 30.0
const VILLAGE_BLEND_R := 60.0

const SHADER_CODE := "
shader_type spatial;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float water_y = -10.0;
uniform vec2 village_c = vec2(0.0);
varying vec3 wpos;
varying float wny;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wny = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
}

void fragment() {
	vec2 uv = wpos.xz * 0.32;
	float mask = texture(mask_tex, wpos.xz * 0.011).r;
	vec3 g = mix(texture(grass_tex, uv).rgb,
		texture(grass_tex, uv * 0.13 + vec2(13.7, 7.3)).rgb, 0.5);
	vec3 d = mix(texture(dirt_tex, uv * 0.7).rgb,
		texture(dirt_tex, uv * 0.11 + vec2(4.2, 9.1)).rgb, 0.45);
	vec3 r = mix(texture(rock_tex, uv * 0.4).rgb, texture(rock_tex, uv * 0.05).rgb, 0.5);
	float slope = clamp(1.0 - wny, 0.0, 1.0);
	float rock_w = smoothstep(0.30, 0.45, slope);
	float dirt_w = smoothstep(0.58, 0.72, mask) * (1.0 - rock_w);
	float shore = smoothstep(water_y + 2.2, water_y + 0.7, wpos.y);
	float plaza = smoothstep(26.0, 14.0, length(wpos.xz - village_c)) * 0.75;
	dirt_w = max(dirt_w, max(shore, plaza) * (1.0 - rock_w));
	vec3 alb = mix(mix(g, d, dirt_w), r, rock_w);
	ALBEDO = alb;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	NORMAL_MAP = texture(nrm_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.5;
}
"

var noise := FastNoiseLite.new()
var macro := FastNoiseLite.new()
var biome: Dictionary = {}
var amp := 20.0
var macro_amp := 14.0
var village_center := Vector2.ZERO
var village_h := 0.0
var water_y := -100.0
var min_h := 1e9
var max_h := -1e9
var top_spot := Vector3.ZERO
var patches: Array = []  # {p: Vector2, rf: float, rb: float, h: float}


func _init() -> void:
	name = "Terrain"
	collision_layer = 1
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 5
	noise.frequency = 0.0045
	macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro.frequency = 0.0012


## Seeds the landscape from the day's RNG and applies the biome's landform
## parameters. Must be called before any height queries or build().
func setup(wrng: RandomNumberGenerator, biome_def: Dictionary) -> void:
	biome = biome_def
	amp = 20.0 * biome.terrain.amp_scale
	macro_amp = 14.0 * biome.terrain.amp_scale
	noise.seed = wrng.randi()
	macro.seed = wrng.randi()
	var a := wrng.randf_range(0.0, TAU)
	village_center = Vector2(cos(a), sin(a)) * wrng.randf_range(0.0, 70.0)
	_analyze()


## Registers a carved flat patch (terrace / foundation cut). Call between
## setup() and build().
func add_flat_patch(p: Vector2, r_flat: float, r_blend: float, h: float) -> void:
	patches.append({p = p, rf = r_flat, rb = r_blend, h = h})


func raw_h(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * amp + macro.get_noise_2d(x, z) * macro_amp
	var edge := maxf(absf(x), absf(z))
	var rim := smoothstep(205.0, 250.0, edge)
	return h + rim * rim * 26.0


func _analyze() -> void:
	var raw_min := 1e9
	var step := SIZE / 60.0
	for i in 61:
		for j in 61:
			var x := -SIZE * 0.5 + i * step
			var z := -SIZE * 0.5 + j * step
			raw_min = minf(raw_min, raw_h(x, z))
	water_y = raw_min + 3.0 + biome.terrain.water_offset
	village_h = maxf(raw_h(village_center.x, village_center.y), water_y + 5.0)


func height_at(x: float, z: float) -> float:
	var h := raw_h(x, z)
	var d := (Vector2(x, z) - village_center).length()
	var t := clampf((d - VILLAGE_FLAT_R) / (VILLAGE_BLEND_R - VILLAGE_FLAT_R), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	h = lerpf(village_h, h, t)
	for pa in patches:
		var pd: float = (Vector2(x, z) - pa.p).length()
		if pd < pa.rb:
			var pt := 0.0
			if pd > pa.rf:
				pt = (pd - pa.rf) / (pa.rb - pa.rf)
				pt = pt * pt * (3.0 - 2.0 * pt)
			h = lerpf(pa.h, h, pt)
	return h


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.5
	return Vector3(
		height_at(x - e, z) - height_at(x + e, z),
		2.0 * e,
		height_at(x, z - e) - height_at(x, z + e)).normalized()


## Height drop from the center to the lowest point within radius r —
## used to decide how deep terraces cut and how far mounds sink.
func drop_under(p: Vector2, r: float) -> float:
	var hc := height_at(p.x, p.y)
	var hmin := hc
	for i in 8:
		var a := TAU * i / 8.0
		hmin = minf(hmin, height_at(p.x + cos(a) * r, p.y + sin(a) * r))
	return hc - hmin


func build() -> void:
	var n := RES + 1
	var step := SIZE / RES
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var verts := PackedVector3Array()
	verts.resize(n * n)
	var uvs := PackedVector2Array()
	uvs.resize(n * n)
	var best := -1e9
	for j in n:
		for i in n:
			var x := -SIZE * 0.5 + i * step
			var z := -SIZE * 0.5 + j * step
			var h := height_at(x, z)
			var idx := j * n + i
			heights[idx] = h
			verts[idx] = Vector3(x, h, z)
			uvs[idx] = Vector2(x, z) * 0.05
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
			var d := Vector2(x, z).length()
			if d > 100.0 and d < 190.0 and h > best \
					and (Vector2(x, z) - village_center).length() > 50.0:
				best = h
				top_spot = Vector3(x, h, z)

	# Normals from the height grid (much faster than re-sampling noise).
	var norms := PackedVector3Array()
	norms.resize(n * n)
	for j in n:
		for i in n:
			var idx := j * n + i
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			norms[idx] = Vector3(hl - hr, 2.0 * step, hd - hu).normalized()

	var idxs := PackedInt32Array()
	idxs.resize(RES * RES * 6)
	var k := 0
	for j in RES:
		for i in RES:
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d2 := c + 1
			# Godot front faces wind clockwise; this order faces the tris upward.
			idxs[k] = a; idxs[k + 1] = b; idxs[k + 2] = c
			idxs[k + 3] = b; idxs[k + 4] = d2; idxs[k + 5] = c
			k += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idxs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var sh := Shader.new()
	sh.code = SHADER_CODE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var bid: String = biome.id
	mat.set_shader_parameter("grass_tex", TexF.noise_tex("grass_" + bid, 101, 0.18,
		biome.terrain.grass[0], biome.terrain.grass[1]))
	mat.set_shader_parameter("dirt_tex", TexF.noise_tex("dirtt_" + bid, 102, 0.12,
		biome.terrain.dirt[0], biome.terrain.dirt[1]))
	mat.set_shader_parameter("rock_tex", TexF.noise_tex("rockt_" + bid, 103, 0.06,
		biome.terrain.rock[0], biome.terrain.rock[1]))
	mat.set_shader_parameter("mask_tex", TexF.noise_tex("mask", 104, 0.04, [], []))
	mat.set_shader_parameter("nrm_tex", TexF.normal_tex())
	mat.set_shader_parameter("water_y", water_y)
	mat.set_shader_parameter("village_c", village_center)
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	add_child(cs)


## Top-down painted map of the landscape for the minimap, using the biome's
## map palette. Call after build().
func make_map_texture(res := 128) -> ImageTexture:
	var pal: Dictionary = biome.terrain.map
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	for py in res:
		var z := -SIZE * 0.5 + SIZE * py / (res - 1.0)
		for px in res:
			var x := -SIZE * 0.5 + SIZE * px / (res - 1.0)
			var h := height_at(x, z)
			var c: Color
			if h <= water_y:
				c = pal.water.lerp(pal.water * 0.6, clampf((water_y - h) / 4.0, 0.0, 1.0))
			else:
				var t := clampf((h - water_y) / maxf(max_h - water_y, 1.0), 0.0, 1.0)
				c = pal.low.lerp(pal.high, t)
				if t > 0.62:
					c = c.lerp(pal.rock, clampf((t - 0.62) / 0.25, 0.0, 1.0))
				if (Vector2(x, z) - village_center).length() < 26.0:
					c = c.lerp(pal.plaza, 0.6)
			img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)
