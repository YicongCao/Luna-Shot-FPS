extends RefCounted
## Forward+ lighting for the polar scene only. Keep ML35 as a same-scene reference.
const SkyShader = preload("res://assets/polar/sky.gdshader")
const PlumeShader = preload("res://assets/polar/exhaust.gdshader")

static func polished() -> bool:
	return (RenderingServer.get_current_rendering_method() == "forward_plus"
		and OS.get_environment("POLAR_LIGHTING") != "baseline")

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
		if polished():
			_refine(env,sun)
		else:
			_baseline_exhaust(root)
	return env

static func _refine(env: Environment, sun: DirectionalLight3D) -> void:
	# Shorter contact radius: separate feet, frames and joints without a broad dark halo.
	env.ssao_radius = .70
	env.ssao_intensity = 2.65
	env.ssao_detail = .78
	env.ssao_light_affect = .32
	# HDR emitters drive glow. Do not bloom the entire sunlit landscape.
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.glow_intensity = .48
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.65
	var glow_levels := [0.0,0.0,.76,.24,0.0,0.0,0.0]
	for level in glow_levels.size():
		env.set_glow_level(level,glow_levels[level])
	# Keep the ML35 sun cascades: tighter near splits cost time in the enclosed galleries.
	sun.light_volumetric_fog_energy = .06
	env.volumetric_fog_anisotropy = .28
	env.volumetric_fog_ambient_inject = .08
	# Resolve the nearby exhaust rather than extending froxels into the distant vacuum.
	env.volumetric_fog_length = 38.0
	env.volumetric_fog_temporal_reprojection_amount = .66

static func _baseline_exhaust(root: Node3D) -> void:
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

static func drill_plume(root: Node3D, mouth: Vector3) -> void:
	# The box only bounds dispatch; the density starts at the outlet and tapers in +Z.
	var vent := FogVolume.new()
	vent.name = "DrillExhaust"
	vent.size = Vector3(4.8,2.25,5.8)
	vent.position = mouth + Vector3.BACK * (vent.size.z*.5)
	var mist := ShaderMaterial.new()
	mist.shader = PlumeShader
	vent.material = mist
	root.add_child(vent)
