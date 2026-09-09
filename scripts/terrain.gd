class_name Terrain
extends StaticBody3D
## Heightfield terrain: simplex hills + macro relief + a mountain rim at the
## map edge, a flattened village plateau, and carved flat patches (terraces
## and building foundations) registered before build(). Splat-blended
## grass/dirt/rock shader with per-biome color ramps.

const SIZE := 500.0
const RES := 200

const SHADER_CODE := "
shader_type spatial;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D nrm_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float water_y = -10.0;
uniform int plaza_count = 0;
uniform vec2 plazas[8];
uniform vec3 grass_tint = vec3(1.0);
uniform vec3 dirt_tint = vec3(1.0);
uniform vec3 rock_tint = vec3(1.0);
varying vec3 wpos;
varying float wny;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wny = (MODEL_MATRIX * vec4(NORMAL, 0.0)).y;
}

void fragment() {
	vec2 uv = wpos.xz * 0.32;
	// Multi-scale ground mask: broad sweeps, mid patches, and fine grain
	// combine so bare ground comes in varied sizes with ragged edges —
	// no more uniform polka-dot patches.
	float m1 = texture(mask_tex, wpos.xz * 0.011).r;
	float m2 = texture(mask_tex, wpos.xz * 0.0031 + vec2(37.7, 11.3)).r;
	float m3 = texture(mask_tex, wpos.xz * 0.043 + vec2(91.1, 53.9)).r;
	float mask = m1 * 0.5 + m2 * 0.35 + m3 * 0.15;
	vec3 g = mix(texture(grass_tex, uv).rgb,
		texture(grass_tex, uv * 0.13 + vec2(13.7, 7.3)).rgb, 0.5) * grass_tint;
	// Large-scale hue mottling: lusher hollows, sun-dried rises.
	g *= mix(vec3(0.9, 1.02, 0.9), vec3(1.08, 1.0, 0.85), m2);
	vec3 d = mix(texture(dirt_tex, uv * 0.7).rgb,
		texture(dirt_tex, uv * 0.11 + vec2(4.2, 9.1)).rgb, 0.45) * dirt_tint;
	vec3 r = mix(texture(rock_tex, uv * 0.4).rgb,
		texture(rock_tex, uv * 0.05).rgb, 0.5) * rock_tint;
	float slope = clamp(1.0 - wny, 0.0, 1.0);
	float rock_w = smoothstep(0.30, 0.45, slope + (m3 - 0.5) * 0.09);
	// Ground dries out with elevation and on slopes; stays lush low down.
	float dry = smoothstep(water_y + 3.0, water_y + 24.0, wpos.y);
	float th = 0.62 - dry * 0.1 - slope * 0.28;
	float dirt_w = smoothstep(th, th + 0.15 + m3 * 0.1, mask) * (1.0 - rock_w);
	float shore = smoothstep(water_y + 2.2, water_y + 0.7, wpos.y);
	float plaza = 0.0;
	for (int i = 0; i < plaza_count; i++) {
		plaza = max(plaza, smoothstep(24.0, 12.0, length(wpos.xz - plazas[i])));
	}
	plaza *= 0.75;
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
var village_centers: Array[Vector2] = []
var water_y := -100.0
var min_h := 1e9
var max_h := -1e9
var top_spot := Vector3.ZERO
var patches: Array = []  # {p: Vector2, rf: float, rb: float, h: float}
var holes: Array = []    # {c: Vector2, half: Vector2, rot: float}
var rivers: Array = []   # {pts: PackedVector2Array, w: float, ford: Vector2}
var sea_sides: Array = []  # side ints: 0 +x, 1 -x, 2 +z, 3 -z
const RF_N := 101        # carve-field resolution (5 m cells, bilinear)
var _rk := PackedFloat32Array()
var _rbed := PackedFloat32Array()


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
	village_centers.clear()
	patches.clear()
	holes.clear()
	rivers = []
	sea_sides = []
	_rk = PackedFloat32Array()
	_rbed = PackedFloat32Array()
	_analyze()


func min_village_dist(p: Vector2) -> float:
	var best := 1e9
	for c in village_centers:
		best = minf(best, p.distance_to(c))
	return best


## Registers a carved flat patch (terrace / foundation cut). Call between
## setup() and build().
func add_flat_patch(p: Vector2, r_flat: float, r_blend: float, h: float) -> void:
	patches.append({p = p, rf = r_flat, rb = r_blend, h = h})


## Cuts a hole in the terrain mesh (a rotated rect, e.g. under a stairwell
## or cave shaft) so descending passages actually open. Every grid quad
## touching the rect is removed, so the covering geometry must overhang by
## at least one grid cell (~2.5 m).
func add_hole_rect(c: Vector2, half: Vector2, rot: float) -> void:
	holes.append({c = c, half = half, rot = rot})


func _in_hole(x: float, z: float) -> bool:
	for h in holes:
		var lp: Vector2 = (Vector2(x, z) - h.c).rotated(h.rot)
		if absf(lp.x) < h.half.x + 1.8 and absf(lp.y) < h.half.y + 1.8:
			return true
	return false


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


## Registers rivers and sea sides (call between setup() and any placement
## height queries). Rivers carve channels below the water line — deep in
## midstream, wading-shallow around each ford — via a baked 5 m field;
## sea sides drown the map edge instead of raising the rim.
func set_water_features(rvs: Array, seas: Array) -> void:
	rivers = rvs
	sea_sides = seas
	if rivers.is_empty():
		return
	_rk = PackedFloat32Array()
	_rk.resize(RF_N * RF_N)
	_rbed = PackedFloat32Array()
	_rbed.resize(RF_N * RF_N)
	_rbed.fill(water_y - 2.4)
	var cell := SIZE / float(RF_N - 1)
	for rv in rivers:
		var pts: PackedVector2Array = rv.pts
		var wch: float = rv.w
		var reach := wch + 9.0
		for si in pts.size() - 1:
			var a := pts[si]
			var b := pts[si + 1]
			var i0 := maxi(int(floor((minf(a.x, b.x) - reach + SIZE * 0.5) / cell)), 0)
			var i1 := mini(int(ceil((maxf(a.x, b.x) + reach + SIZE * 0.5) / cell)), RF_N - 1)
			var j0 := maxi(int(floor((minf(a.y, b.y) - reach + SIZE * 0.5) / cell)), 0)
			var j1 := mini(int(ceil((maxf(a.y, b.y) + reach + SIZE * 0.5) / cell)), RF_N - 1)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var p := Vector2(-SIZE * 0.5 + i * cell, -SIZE * 0.5 + j * cell)
					var d := seg_dist(p, a, b)
					if d >= reach:
						continue
					var k := 1.0 - smoothstep(wch * 0.45, reach, d)
					# Channels pinch closed against mountain edges (a carved
					# slot in the rim shows the void beyond); only sea sides
					# stay open, where the river empties out.
					var edge := maxf(absf(p.x), absf(p.y))
					if edge > 234.0:
						var sdom := 0
						if absf(p.y) > absf(p.x):
							sdom = 2 if p.y > 0.0 else 3
						elif p.x < 0.0:
							sdom = 1
						if not sdom in sea_sides:
							k *= 1.0 - smoothstep(234.0, 246.0, edge)
					var idx := j * RF_N + i
					if k > _rk[idx]:
						_rk[idx] = k
						var fd: float = rv.ford.distance_to(p)
						_rbed[idx] = lerpf(water_y - 2.4, water_y - 0.35,
							1.0 - smoothstep(4.5, 11.0, fd))


static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-5), 0.0, 1.0)
	return (p - (a + ab * t)).length()


func _water_mod(h: float, x: float, z: float) -> float:
	for s in sea_sides:
		var edge: float = [x, -x, z, -z][s]
		var t := smoothstep(195.0, 242.0, edge)
		if t > 0.0:
			h = lerpf(h, water_y - 7.0, t)
	if _rk.is_empty():
		return h
	var cell := SIZE / float(RF_N - 1)
	var fx := clampf((x + SIZE * 0.5) / cell, 0.0, float(RF_N - 1) - 0.001)
	var fz := clampf((z + SIZE * 0.5) / cell, 0.0, float(RF_N - 1) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var i1 := mini(i + 1, RF_N - 1)
	var j1 := mini(j + 1, RF_N - 1)
	var k := lerpf(lerpf(_rk[j * RF_N + i], _rk[j * RF_N + i1], tx),
		lerpf(_rk[j1 * RF_N + i], _rk[j1 * RF_N + i1], tx), tz)
	if k > 0.003:
		var bed := lerpf(lerpf(_rbed[j * RF_N + i], _rbed[j * RF_N + i1], tx),
			lerpf(_rbed[j1 * RF_N + i], _rbed[j1 * RF_N + i1], tx), tz)
		h = lerpf(h, minf(h, bed), k)
	return h


func height_at(x: float, z: float) -> float:
	var h := raw_h(x, z)
	for pa in patches:
		var pd: float = (Vector2(x, z) - pa.p).length()
		if pd < pa.rb:
			var pt := 0.0
			if pd > pa.rf:
				pt = (pd - pa.rf) / (pa.rb - pa.rf)
				pt = pt * pt * (3.0 - 2.0 * pt)
			h = lerpf(pa.h, h, pt)
	# Water carving comes LAST: a terrace or plaza blend must never dam a
	# river channel or silt up a ford.
	return _water_mod(h, x, z)


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
					and min_village_dist(Vector2(x, z)) > 45.0:
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
	for j in RES:
		for i in RES:
			if not holes.is_empty():
				var qx := -SIZE * 0.5 + (i + 0.5) * step
				var qz := -SIZE * 0.5 + (j + 0.5) * step
				if _in_hole(qx, qz):
					continue
			var a := j * n + i
			var b := a + 1
			var c := a + n
			var d2 := c + 1
			# Godot front faces wind clockwise; this order faces the tris upward.
			idxs.append_array(PackedInt32Array([a, b, c, b, d2, c]))

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
	# Real photo textures per biome (CC0, textures/), tinted to keep each
	# biome's palette; the mask stays procedural. Falls back to the old
	# noise textures if a file is missing.
	var ground_file := "leafy_grass"
	var gt := Color(1, 1, 1)
	var dt := Color(1, 1, 1)
	var rt := Color(1, 1, 1)
	match bid:
		"autumn":
			ground_file = "forest_leaves_03"
			gt = Color(1.05, 0.95, 0.8)
		"winter":
			ground_file = "snow_02"
			dt = Color(0.75, 0.75, 0.82)
			rt = Color(0.9, 0.95, 1.05)
		"desert":
			ground_file = "coast_sand_01"
			gt = Color(1.1, 0.98, 0.78)
			dt = Color(1.15, 1.0, 0.78)
			rt = Color(1.1, 0.95, 0.8)
		"dunes":
			ground_file = "coast_sand_01"
			gt = Color(1.12, 1.05, 0.92)
			dt = Color(1.1, 1.02, 0.88)
		"mountain":
			gt = Color(0.92, 0.95, 0.88)
		"riverlands":
			gt = Color(0.88, 1.04, 0.82)
		"swamp":
			ground_file = "forest_ground_04"
			gt = Color(0.72, 0.78, 0.66)
			dt = Color(0.7, 0.72, 0.62)
			rt = Color(0.7, 0.72, 0.68)
		"ashlands":
			ground_file = "burned_ground_01"
			gt = Color(0.55, 0.53, 0.51)
			dt = Color(0.5, 0.48, 0.47)
			rt = Color(0.45, 0.44, 0.45)
		"cavern":
			ground_file = "rocky_terrain"
			gt = Color(0.62, 0.68, 0.78)
			dt = Color(0.55, 0.6, 0.72)
			rt = Color(0.6, 0.66, 0.78)
		"moor":
			gt = Color(0.84, 0.9, 0.78)
	var g_diff := TexF.pbr_tex(ground_file + "_diff")
	if g_diff:
		mat.set_shader_parameter("grass_tex", g_diff)
		mat.set_shader_parameter("dirt_tex", TexF.pbr_tex("brown_mud_diff"))
		mat.set_shader_parameter("rock_tex", TexF.pbr_tex("rock_face_diff"))
		mat.set_shader_parameter("nrm_tex", TexF.pbr_tex(ground_file + "_nor"))
		mat.set_shader_parameter("grass_tint", Vector3(gt.r, gt.g, gt.b))
		mat.set_shader_parameter("dirt_tint", Vector3(dt.r, dt.g, dt.b))
		mat.set_shader_parameter("rock_tint", Vector3(rt.r, rt.g, rt.b))
	else:
		mat.set_shader_parameter("grass_tex", TexF.noise_tex("grass_" + bid, 101, 0.18,
			biome.terrain.grass[0], biome.terrain.grass[1]))
		mat.set_shader_parameter("dirt_tex", TexF.noise_tex("dirtt_" + bid, 102, 0.12,
			biome.terrain.dirt[0], biome.terrain.dirt[1]))
		mat.set_shader_parameter("rock_tex", TexF.noise_tex("rockt_" + bid, 103, 0.06,
			biome.terrain.rock[0], biome.terrain.rock[1]))
		mat.set_shader_parameter("nrm_tex", TexF.normal_tex())
	mat.set_shader_parameter("mask_tex", TexF.noise_tex("mask", 104, 0.04, [], []))
	mat.set_shader_parameter("water_y", water_y)
	var plaza_arr := PackedVector2Array()
	for c in village_centers:
		if plaza_arr.size() < 8:
			plaza_arr.append(c)
	while plaza_arr.size() < 8:
		plaza_arr.append(Vector2(9999, 9999))
	mat.set_shader_parameter("plaza_count", mini(village_centers.size(), 8))
	mat.set_shader_parameter("plazas", plaza_arr)
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
				if min_village_dist(Vector2(x, z)) < 24.0:
					c = c.lerp(pal.plaza, 0.6)
			img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)
