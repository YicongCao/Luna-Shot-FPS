extends RefCounted
## Neutral direct sunlight, unlit vacuum, tiny local vent haze only.
const SkyShader = preload("res://assets/polar/sky.gdshader")

static func build(root: Node3D) -> Environment:
	var env := Environment.new()
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = SkyShader
	sky.sky_material = material
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.65,.71,.80)
	env.ambient_light_energy = .38
	env.ambient_light_sky_contribution = 0.0
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.04
	env.glow_enabled = true
	env.glow_intensity = .23
	env.glow_bloom = .042
	env.glow_hdr_threshold = 1.28
	var stage := WorldEnvironment.new()
	stage.name = "PolarExposure"
	stage.environment = env
	root.add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.name = "RimSun"
	sun.light_color = Color(.97,.982,1)
	sun.light_energy = 2.05
	sun.light_angular_distance = .52
	sun.light_volumetric_fog_energy = .12
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 186.0
	sun.directional_shadow_blend_splits = true
	sun.shadow_bias = .048
	sun.shadow_normal_bias = .68
	root.add_child(sun)
	sun.look_at(root.to_global(Vector3(-.78,-.29,-.57)))
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = .84
		env.ssao_intensity = 1.34
		env.ssao_light_affect = .25
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.0
		env.volumetric_fog_albedo = Color(.72,.78,.84)
		env.volumetric_fog_ambient_inject = .12
		env.volumetric_fog_length = 52.0
		env.volumetric_fog_temporal_reprojection_amount = .77
		var vent := FogVolume.new()
		vent.name = "SublimationAtDrill"
		vent.size = Vector3(4.3,1.78,3.5)
		vent.position = Vector3(-3.15,-16.04,-27.58)
		var mist := FogMaterial.new()
		mist.density = .024
		mist.albedo = Color(.74,.80,.86)
		mist.edge_fade = 1.4
		vent.material = mist
		root.add_child(vent)
	return env
