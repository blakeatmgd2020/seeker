class_name Terrain
extends StaticBody3D
## Heightfield terrain: simplex hills + macro relief + a mountain rim at the
## map edge, with a flattened village plateau at the center and a pond at the
## lowest basin. Splat-blended grass/dirt/rock shader.

const SIZE := 500.0
const RES := 200
const AMP := 20.0
const MACRO_AMP := 14.0
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
var village_center := Vector2.ZERO
var village_h := 0.0
var water_y := -100.0
var min_h := 1e9
var max_h := -1e9
var top_spot := Vector3.ZERO


func _init() -> void:
	name = "Terrain"
	collision_layer = 1
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_octaves = 5
	noise.frequency = 0.0045
	macro.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	macro.frequency = 0.0012


## Seeds the landscape and picks the village site from the day's RNG.
## Must be called before build().
func setup(wrng: RandomNumberGenerator) -> void:
	noise.seed = wrng.randi()
	macro.seed = wrng.randi()
	var a := wrng.randf_range(0.0, TAU)
	village_center = Vector2(cos(a), sin(a)) * wrng.randf_range(0.0, 70.0)
	_analyze()


## Height before village flattening: hills + macro relief + edge mountain rim.
func raw_h(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * AMP + macro.get_noise_2d(x, z) * MACRO_AMP
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
	water_y = raw_min + 3.0
	village_h = maxf(raw_h(village_center.x, village_center.y), water_y + 5.0)


func height_at(x: float, z: float) -> float:
	var h := raw_h(x, z)
	var d := (Vector2(x, z) - village_center).length()
	var t := clampf((d - VILLAGE_FLAT_R) / (VILLAGE_BLEND_R - VILLAGE_FLAT_R), 0.0, 1.0)
	t = t * t * (3.0 - 2.0 * t)
	return lerpf(village_h, h, t)


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.5
	return Vector3(
		height_at(x - e, z) - height_at(x + e, z),
		2.0 * e,
		height_at(x, z - e) - height_at(x, z + e)).normalized()


func build() -> void:
	var n := RES + 1
	var step := SIZE / RES
	var verts := PackedVector3Array()
	verts.resize(n * n)
	var norms := PackedVector3Array()
	norms.resize(n * n)
	var uvs := PackedVector2Array()
	uvs.resize(n * n)
	var best := -1e9
	for j in n:
		for i in n:
			var x := -SIZE * 0.5 + i * step
			var z := -SIZE * 0.5 + j * step
			var h := height_at(x, z)
			var idx := j * n + i
			verts[idx] = Vector3(x, h, z)
			norms[idx] = normal_at(x, z)
			uvs[idx] = Vector2(x, z) * 0.05
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)
			var d := Vector2(x, z).length()
			if d > 100.0 and d < 190.0 and h > best \
					and (Vector2(x, z) - village_center).length() > 50.0:
				best = h
				top_spot = Vector3(x, h, z)

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
	var tex := TexF.terrain_textures()
	mat.set_shader_parameter("grass_tex", tex.grass)
	mat.set_shader_parameter("dirt_tex", tex.dirt)
	mat.set_shader_parameter("rock_tex", tex.rock)
	mat.set_shader_parameter("mask_tex", tex.mask)
	mat.set_shader_parameter("nrm_tex", tex.nrm)
	mat.set_shader_parameter("water_y", water_y)
	mat.set_shader_parameter("village_c", village_center)
	mesh.surface_set_material(0, mat)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	add_child(cs)


## Top-down painted map of the landscape for the minimap. Call after build().
func make_map_texture(res := 128) -> ImageTexture:
	var img := Image.create(res, res, false, Image.FORMAT_RGB8)
	for py in res:
		var z := -SIZE * 0.5 + SIZE * py / (res - 1.0)
		for px in res:
			var x := -SIZE * 0.5 + SIZE * px / (res - 1.0)
			var h := height_at(x, z)
			var c: Color
			if h <= water_y:
				c = Color(0.16, 0.32, 0.50).lerp(Color(0.10, 0.20, 0.38),
					clampf((water_y - h) / 4.0, 0.0, 1.0))
			else:
				var t := clampf((h - water_y) / maxf(max_h - water_y, 1.0), 0.0, 1.0)
				c = Color(0.22, 0.38, 0.16).lerp(Color(0.55, 0.55, 0.35), t)
				if t > 0.62:
					c = c.lerp(Color(0.62, 0.60, 0.57), clampf((t - 0.62) / 0.25, 0.0, 1.0))
				if (Vector2(x, z) - village_center).length() < 26.0:
					c = c.lerp(Color(0.45, 0.36, 0.24), 0.6)
			img.set_pixel(px, py, c)
	return ImageTexture.create_from_image(img)
