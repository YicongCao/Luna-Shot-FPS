extends RefCounted
# ML25: the user's preferred amber, dust-laden apocalypse mood, not a neutralizing grade.
# The preceding clear preset remains reproducible; training/resources are untouched.
static func apply(world: Node3D) -> String:
	if OS.get_environment("QUARANTINE_ATMOSPHERE") == "clear": return "clear"
	var env: Environment = world.environment
	world.sun.light_color = Color(1.0,.88,.63)
	world.sun.light_energy = 1.9
	# Finite solar disk softens distant penumbrae without painting blur over the image.
	world.sun.light_angular_distance = .53
	world.sun.directional_shadow_blend_splits = true
	env.ambient_light_color = Color(.30,.36,.43)
	env.ambient_light_energy = .42
	env.fog_light_color = Color(.42,.38,.27)
	env.fog_light_energy = .60
	env.fog_density = .0016
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.volumetric_fog_density = .0062
		env.volumetric_fog_albedo = Color(.78,.76,.62)
		env.volumetric_fog_length = 110
		env.volumetric_fog_anisotropy = .46
		env.volumetric_fog_ambient_inject = .12
	env.sky.sky_material.set_shader_parameter("amber_haze",1.0)
	return "amber"
