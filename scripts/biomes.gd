class_name Biomes
## Biome definitions. One biome is rolled per daily seed (equal odds) and
## drives terrain palette, water behavior, flora, village architecture,
## structure pools, sky moods, and the weather table.


static func all_ids() -> Array:
	return ["meadow", "autumn", "winter", "desert"]


static func _mood(n: String, top: Color, hor: Color, sun: Color, e: float,
		fg: float, fgc: Color, amb: float) -> Dictionary:
	return {name = n, top = top, horizon = hor, sun = sun, energy = e,
		fog = fg, fogc = fgc, ambient = amb}


static func get_def(id: String) -> Dictionary:
	match id:
		"autumn":
			return {
				id = "autumn", label = "Autumn Vale",
				terrain = {
					amp_scale = 1.0, water_offset = 0.0,
					grass = [[0.0, 0.45, 0.75, 1.0], [Color(0.30, 0.24, 0.09), Color(0.44, 0.34, 0.13),
						Color(0.55, 0.42, 0.16), Color(0.62, 0.50, 0.22)]],
					dirt = [[0.0, 0.5, 1.0], [Color(0.24, 0.16, 0.10), Color(0.34, 0.24, 0.14), Color(0.44, 0.32, 0.19)]],
					rock = [[0.0, 0.5, 1.0], [Color(0.32, 0.30, 0.28), Color(0.45, 0.42, 0.39), Color(0.56, 0.52, 0.48)]],
					map = {low = Color(0.40, 0.32, 0.12), high = Color(0.58, 0.46, 0.24),
						rock = Color(0.52, 0.48, 0.44), water = Color(0.16, 0.30, 0.44), plaza = Color(0.42, 0.32, 0.20)},
					water_mat = "water", ice_solid = false,
				},
				village_style = "timber",
				veg = {pine = 60, oak = 0, autumn_oak = 210, snow_pine = 0, bare = 20, dead = 0,
					saguaro = 0, barrel_cactus = 0, bush = 0, autumn_bush = 130, dry_bush = 0,
					flowers = 0, mushrooms = 90, leaf_litter = 130, snow_tufts = 0, tumbleweed = 0,
					rocks = 140, boulders = 12},
				wild_pool = [["leaf_pile", "leaf pile", 3], ["log", "hollow log", 3],
					["stump", "hollow stump", 2], ["dirt_pile", "dirt pile", 2], ["cairn", "stone cairn", 2],
					["campfire", "old campfire", 2], ["firewood", "firewood stack", 2],
					["scarecrow", "scarecrow", 1], ["crate", "crate", 1]],
				village_loose = [["crate", "crate", 1, 2], ["barrel", "barrel", 1, 2],
					["firewood", "firewood stack", 1, 1], ["haystack", "haystack", 1, 1]],
				moods = [
					_mood("Amber Morning", Color(0.45, 0.42, 0.52), Color(0.88, 0.72, 0.50), Color(1.0, 0.82, 0.58), 1.1, 0.0018, Color(0.88, 0.80, 0.66), 1.0),
					_mood("Crisp Sky", Color(0.30, 0.46, 0.68), Color(0.72, 0.74, 0.72), Color(1.0, 0.95, 0.86), 1.25, 0.0008, Color(0.78, 0.80, 0.80), 0.95),
					_mood("Harvest Dusk", Color(0.32, 0.30, 0.50), Color(0.92, 0.58, 0.32), Color(1.0, 0.68, 0.38), 1.15, 0.0014, Color(0.86, 0.70, 0.52), 0.9),
					_mood("Gray Quilt", Color(0.44, 0.45, 0.48), Color(0.64, 0.63, 0.60), Color(0.88, 0.86, 0.82), 0.7, 0.0022, Color(0.70, 0.68, 0.64), 1.3),
				],
				weather = [["clear", "Clear", 50], ["rain", "Rain", 25],
					["fog", "Morning Mist", 12], ["wind", "Leaf Gale", 13]],
				debris = Color(0.85, 0.45, 0.15, 0.9),
			}
		"winter":
			return {
				id = "winter", label = "Winter Highlands",
				terrain = {
					amp_scale = 1.1, water_offset = 0.0,
					grass = [[0.0, 0.5, 1.0], [Color(0.76, 0.79, 0.86), Color(0.86, 0.89, 0.94), Color(0.94, 0.96, 1.0)]],
					dirt = [[0.0, 0.5, 1.0], [Color(0.34, 0.31, 0.29), Color(0.46, 0.42, 0.38), Color(0.58, 0.54, 0.50)]],
					rock = [[0.0, 0.5, 1.0], [Color(0.28, 0.30, 0.34), Color(0.40, 0.42, 0.46), Color(0.55, 0.57, 0.62)]],
					map = {low = Color(0.80, 0.83, 0.89), high = Color(0.93, 0.95, 0.99),
						rock = Color(0.45, 0.47, 0.52), water = Color(0.62, 0.74, 0.84), plaza = Color(0.62, 0.58, 0.52)},
					water_mat = "ice", ice_solid = true,
				},
				village_style = "alpine",
				veg = {pine = 0, oak = 0, autumn_oak = 0, snow_pine = 240, bare = 110, dead = 0,
					saguaro = 0, barrel_cactus = 0, bush = 0, autumn_bush = 0, dry_bush = 0,
					flowers = 0, mushrooms = 0, leaf_litter = 0, snow_tufts = 130, tumbleweed = 0,
					rocks = 120, boulders = 12},
				wild_pool = [["snow_mound", "snow mound", 4], ["firewood", "firewood stack", 3],
					["log", "hollow log", 2], ["stump", "hollow stump", 2], ["cairn", "stone cairn", 2],
					["campfire", "old campfire", 2], ["crate", "crate", 1], ["barrel", "barrel", 1]],
				village_loose = [["firewood", "firewood stack", 1, 2], ["crate", "crate", 1, 2],
					["barrel", "barrel", 1, 1]],
				moods = [
					_mood("Ice Blue", Color(0.40, 0.56, 0.78), Color(0.78, 0.84, 0.90), Color(0.95, 0.97, 1.0), 1.2, 0.0010, Color(0.82, 0.87, 0.94), 1.0),
					_mood("Milk Sky", Color(0.68, 0.71, 0.76), Color(0.85, 0.86, 0.88), Color(0.92, 0.93, 0.95), 0.85, 0.0020, Color(0.86, 0.87, 0.89), 1.35),
					_mood("Alpenglow", Color(0.36, 0.36, 0.58), Color(0.94, 0.66, 0.56), Color(1.0, 0.74, 0.60), 1.05, 0.0014, Color(0.90, 0.78, 0.74), 0.95),
					_mood("Leaden", Color(0.36, 0.38, 0.42), Color(0.55, 0.56, 0.58), Color(0.80, 0.82, 0.86), 0.6, 0.0026, Color(0.62, 0.64, 0.66), 1.4),
				],
				weather = [["clear", "Clear", 55], ["snow", "Snowfall", 25],
					["fog", "Freezing Mist", 10], ["wind", "Blizzard", 10]],
				debris = Color(0.95, 0.96, 1.0, 0.85),
			}
		"desert":
			return {
				id = "desert", label = "Sunscar Badlands",
				terrain = {
					amp_scale = 0.85, water_offset = -1.5,
					grass = [[0.0, 0.5, 1.0], [Color(0.70, 0.58, 0.38), Color(0.79, 0.67, 0.46), Color(0.86, 0.75, 0.55)]],
					dirt = [[0.0, 0.5, 1.0], [Color(0.52, 0.28, 0.16), Color(0.62, 0.37, 0.21), Color(0.70, 0.46, 0.28)]],
					rock = [[0.0, 0.5, 1.0], [Color(0.44, 0.34, 0.26), Color(0.58, 0.46, 0.34), Color(0.70, 0.58, 0.44)]],
					map = {low = Color(0.72, 0.60, 0.40), high = Color(0.85, 0.74, 0.54),
						rock = Color(0.55, 0.44, 0.33), water = Color(0.24, 0.48, 0.46), plaza = Color(0.60, 0.42, 0.26)},
					water_mat = "oasis", ice_solid = false,
				},
				village_style = "adobe",
				veg = {pine = 0, oak = 0, autumn_oak = 0, snow_pine = 0, bare = 0, dead = 80,
					saguaro = 90, barrel_cactus = 100, bush = 0, autumn_bush = 0, dry_bush = 110,
					flowers = 0, mushrooms = 0, leaf_litter = 0, snow_tufts = 0, tumbleweed = 45,
					rocks = 230, boulders = 20},
				wild_pool = [["dirt_pile", "sand mound", 3], ["urn", "clay urn", 3],
					["bone_pile", "bone pile", 2], ["cairn", "stone cairn", 2], ["campfire", "old campfire", 2],
					["crate", "crate", 1], ["barrel", "barrel", 1], ["log", "bleached log", 1]],
				village_loose = [["urn", "clay urn", 1, 2], ["crate", "crate", 1, 2],
					["barrel", "barrel", 1, 1]],
				moods = [
					_mood("Blazing Noon", Color(0.34, 0.52, 0.74), Color(0.82, 0.78, 0.66), Color(1.0, 0.97, 0.88), 1.45, 0.0005, Color(0.85, 0.80, 0.68), 0.95),
					_mood("Amber Heat", Color(0.55, 0.48, 0.40), Color(0.90, 0.74, 0.50), Color(1.0, 0.85, 0.60), 1.25, 0.0012, Color(0.90, 0.78, 0.58), 1.0),
					_mood("Bone Sky", Color(0.62, 0.64, 0.64), Color(0.84, 0.82, 0.74), Color(0.95, 0.93, 0.86), 1.0, 0.0016, Color(0.86, 0.83, 0.74), 1.15),
					_mood("Red Dusk", Color(0.36, 0.26, 0.42), Color(0.88, 0.46, 0.26), Color(1.0, 0.60, 0.34), 1.1, 0.0012, Color(0.84, 0.60, 0.44), 0.9),
				],
				weather = [["clear", "Clear", 65], ["rain", "Desert Rain", 10],
					["fog", "Sand Haze", 10], ["wind", "Dust Storm", 15]],
				debris = Color(0.80, 0.64, 0.42, 0.8),
			}
		_:
			return {
				id = "meadow", label = "Green Meadow",
				terrain = {
					amp_scale = 1.0, water_offset = 0.0,
					grass = [[0.0, 0.45, 0.75, 1.0], [Color(0.13, 0.27, 0.09), Color(0.22, 0.38, 0.12),
						Color(0.30, 0.45, 0.16), Color(0.42, 0.50, 0.20)]],
					dirt = [[0.0, 0.5, 1.0], [Color(0.28, 0.20, 0.13), Color(0.38, 0.29, 0.18), Color(0.48, 0.38, 0.24)]],
					rock = [[0.0, 0.4, 0.7, 1.0], [Color(0.30, 0.30, 0.31), Color(0.42, 0.41, 0.40),
						Color(0.50, 0.49, 0.47), Color(0.60, 0.58, 0.55)]],
					map = {low = Color(0.22, 0.38, 0.16), high = Color(0.55, 0.55, 0.35),
						rock = Color(0.62, 0.60, 0.57), water = Color(0.16, 0.32, 0.50), plaza = Color(0.45, 0.36, 0.24)},
					water_mat = "water", ice_solid = false,
				},
				village_style = "meadow",
				veg = {pine = 170, oak = 140, autumn_oak = 0, snow_pine = 0, bare = 0, dead = 0,
					saguaro = 0, barrel_cactus = 0, bush = 170, autumn_bush = 0, dry_bush = 0,
					flowers = 240, mushrooms = 0, leaf_litter = 0, snow_tufts = 0, tumbleweed = 0,
					rocks = 150, boulders = 14},
				wild_pool = [["log", "hollow log", 3], ["dirt_pile", "dirt pile", 3],
					["stump", "hollow stump", 2], ["cairn", "stone cairn", 2], ["firewood", "firewood stack", 2],
					["campfire", "old campfire", 2], ["crate", "crate", 2], ["barrel", "barrel", 1],
					["scarecrow", "scarecrow", 1]],
				village_loose = [["crate", "crate", 1, 3], ["barrel", "barrel", 1, 2],
					["haystack", "haystack", 1, 1]],
				moods = [
					_mood("Clear Skies", Color(0.20, 0.42, 0.75), Color(0.66, 0.74, 0.80), Color(1.0, 0.96, 0.88), 1.3, 0.0008, Color(0.75, 0.81, 0.90), 1.0),
					_mood("Morning Haze", Color(0.45, 0.58, 0.72), Color(0.82, 0.83, 0.80), Color(1.0, 0.90, 0.75), 1.05, 0.0026, Color(0.85, 0.86, 0.82), 1.1),
					_mood("Golden Hour", Color(0.30, 0.38, 0.60), Color(0.95, 0.72, 0.45), Color(1.0, 0.75, 0.45), 1.2, 0.0014, Color(0.90, 0.78, 0.60), 0.9),
					_mood("Overcast", Color(0.42, 0.46, 0.52), Color(0.62, 0.65, 0.68), Color(0.85, 0.88, 0.92), 0.65, 0.0018, Color(0.68, 0.70, 0.73), 1.35),
				],
				weather = [["clear", "Clear", 55], ["rain", "Rain", 25],
					["fog", "Thick Fog", 10], ["wind", "High Winds", 10]],
				debris = Color(0.55, 0.55, 0.30, 0.8),
			}


## Weighted roll from a biome's weather table → [id, display].
static func roll_weather(def: Dictionary, wrng: RandomNumberGenerator) -> Array:
	var total := 0
	for w in def.weather:
		total += w[2]
	var pick := wrng.randi_range(1, total)
	for w in def.weather:
		pick -= w[2]
		if pick <= 0:
			return [w[0], w[1]]
	return ["clear", "Clear"]
