extends RefCounted
static func environment() -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://assets/weapons/lc01/studio_sky.gdshader")
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(.008,.009,.012)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = .55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# Godot 4.7 Compatibility supports glow; use its supported intensity/threshold controls.
	env.glow_enabled = true
	env.glow_intensity = .75
	env.glow_hdr_threshold = 1.0
	env.glow_hdr_scale = 1.0
	env.glow_bloom = 0.0
	return env
