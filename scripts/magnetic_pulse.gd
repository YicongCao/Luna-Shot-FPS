extends Node3D
# ML12: pooled, analytic single-shot VFX; gameplay still uses the player's hitscan.
const LIFE := .100
const FLASH_LIFE := .035
const TRACE_LIFE := .065
var player: CharacterBody3D
var age := LIFE
var shot_count := 0
var manual_clock := false # Deterministic native capture / lifetime validation.
var start := Vector3.ZERO
var finish := Vector3.ZERO
var hit_normal := Vector3.UP
var has_impact := false
var muzzle_clear := true
var aimed := false
var flash_extent := 0.0
var sparks: Array[Vector3] = []
var flash_geometry := ImmediateMesh.new()
var world_geometry := ImmediateMesh.new()
var flash: MeshInstance3D
var trail: MeshInstance3D
var flash_light: OmniLight3D
var sound: AudioStreamPlayer
var base_emission := 4.0
var base_lights: Array[float] = []

func _ready() -> void:
	name = "MagneticPulse"
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/effects/magnetic_pulse.gdshader")
	mat.set_shader_parameter("gain", 2.2)
	trail = MeshInstance3D.new()
	trail.name = "WorldTraceAndImpact"
	trail.mesh = world_geometry
	trail.material_override = mat
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	flash = MeshInstance3D.new()
	flash.name = "ProceduralMuzzleFlash"
	flash.mesh = flash_geometry
	# Additive blending alone loses its alpha in the transparent weapon viewport.
	# Use ordinary alpha composition here; the existing bright-pass supplies bloom.
	var flash_mat := mat.duplicate() as ShaderMaterial
	var flash_shader := Shader.new()
	flash_shader.code = mat.shader.code.replace("blend_add", "blend_mix")
	flash_mat.shader = flash_shader
	flash.material_override = flash_mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.weapon.get_node("Muzzle").add_child(flash)
	flash_light = OmniLight3D.new()
	flash_light.name = "ShotSpill"
	flash_light.position = Vector3(0, .065, -.52)
	flash_light.light_color = Color(.14, .85, 1)
	flash_light.omni_range = .24
	flash_light.omni_attenuation = 1.7
	flash_light.shadow_enabled = true
	flash_light.light_energy = 0
	player.weapon.add_child(flash_light)
	base_emission = player.weapon.material.emission_energy_multiplier
	for light in player.weapon.energy_lights: base_lights.append(light.light_energy)
	sound = AudioStreamPlayer.new()
	sound.name = "SynthesizedCapacitorClick"
	sound.stream = make_sound()
	sound.volume_db = -20
	add_child(sound)
	clear()

func make_sound() -> AudioStreamWAV:
	# Soft-limited, short electronic transient, synthesized once. No audio files.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var count := int(.075 * wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1201
	for i in count:
		var t := float(i) / wav.mix_rate
		var attack := minf(t / .0015, 1)
		var envelope := attack * exp(-t * 80) * maxf(0, 1 - t / .075)
		var tone := sin(TAU * (1250 * t - 6200 * t * t))
		var sample := (tone * .42 + rng.randf_range(-1, 1) * .32) * envelope
		bytes.encode_s16(i * 2, int(clampf(sample, -.8, .8) * 32767))
	wav.data = bytes
	return wav

func emit_shot(from: Vector3, to: Vector3, impact: Dictionary, clear_muzzle: bool) -> void:
	start = from
	finish = to
	has_impact = not impact.is_empty()
	hit_normal = impact.get("normal", Vector3.UP)
	muzzle_clear = clear_muzzle
	aimed = player.aiming
	age = 0
	shot_count += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 12000 + shot_count
	sparks.clear()
	# Four short sparks, biased out of the hit surface; no smoke or persistent decals.
	for i in 4:
		var random := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		var tangent := random - hit_normal * random.dot(hit_normal)
		sparks.append((hit_normal * rng.randf_range(.7, 1.4) + tangent) * rng.randf_range(.7, 1.5))
	if not player.qa_mode: sound.play()
	refresh()

func _process(delta: float) -> void:
	if not manual_clock:
		age = minf(LIFE, age + delta)
	if player.blocked:
		clear()
	elif age < LIFE:
		refresh()
	elif flash.visible or trail.visible:
		clear()

func clear() -> void:
	age = LIFE
	flash.visible = false
	trail.visible = false
	flash_light.light_energy = 0
	if is_instance_valid(player.weapon):
		player.weapon.material.emission_energy_multiplier = base_emission
		for i in base_lights.size(): player.weapon.energy_lights[i].light_energy = base_lights[i]
	if is_instance_valid(sound): sound.stop()

func ribbon(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: float, color: Color, eye: Vector3) -> void:
	var axis := b - a
	if axis.length_squared() < .0000001: return
	var side := axis.normalized().cross((eye - (a + b) * .5).normalized())
	if side.length_squared() < .0001: side = axis.normalized().cross(Vector3.UP)
	if side.length_squared() < .0001: side = Vector3.RIGHT
	side = side.normalized() * width
	var vertices := [a-side, a+side, b+side, a-side, b+side, b-side]
	var uvs := [Vector2(0,0), Vector2(0,1), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(1,0)]
	for i in 6:
		mesh.surface_set_color(color)
		mesh.surface_set_uv(uvs[i])
		mesh.surface_add_vertex(vertices[i])

func refresh() -> void:
	var gun = player.weapon
	var energy: bool = gun.energy_enabled and gun.surface_mode == 0
	var pulse := pow(maxf(0, 1 - age / .085), 2)
	gun.material.emission_energy_multiplier = base_emission * (1 + 1.1 * pulse if energy else 1.0)
	for i in base_lights.size(): gun.energy_lights[i].light_energy = base_lights[i] * (1 + 1.8 * pulse if energy else 1.0)
	flash_light.light_energy = .28 * pulse if energy and gun.spill_enabled and muzzle_clear else 0.0
	flash_light.visible = flash_light.light_energy > 0
	var size_factor := .55 if aimed else 1.0
	flash_extent = minf(.58 * size_factor, start.distance_to(finish) * .85)
	flash.visible = age < FLASH_LIFE and muzzle_clear and flash_extent > .005
	flash_geometry.clear_surfaces()
	if flash.visible:
		flash_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var alpha := pow(1 - age / FLASH_LIFE, .65)
		var eye: Vector3 = flash.to_local(player.weapon_camera.global_position)
		# Sharp axial lance and short asymmetric side streaks, all at the real socket.
		ribbon(flash_geometry, Vector3(0,0,.002), Vector3(0,0,-flash_extent), .028*size_factor, Color(.5,.94,1,alpha), eye)
		ribbon(flash_geometry, Vector3(-.065*size_factor,0,-flash_extent*.55), Vector3(.075*size_factor,0,-flash_extent*.59), .009*size_factor, Color(.18,.72,1,alpha*.6), eye)
		flash_geometry.surface_end()
	trail.visible = age < LIFE
	world_geometry.clear_surfaces()
	world_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var eye: Vector3 = player.camera.global_position
	var direction := (finish-start).normalized()
	var distance := start.distance_to(finish)
	if age < TRACE_LIFE and distance > .03:
		# At long range maintain a thin readable trail; still depth-tested in the level.
		var width := clampf(distance * .00065, .007, .019) * size_factor
		var alpha := pow(1 - age / TRACE_LIFE, 1.4)
		ribbon(world_geometry, start, finish, width, Color(.28,.87,1,alpha*.8), eye)
	if has_impact:
		var point := finish + hit_normal * .012
		var alpha := pow(maxf(0, 1-age/LIFE), 1.6)
		var right: Vector3 = player.camera.global_basis.x
		var up: Vector3 = player.camera.global_basis.y
		# Small impact glint fades quickly, sparks continue outward to 100 ms.
		if age < .045:
			ribbon(world_geometry, point-right*.035, point+right*.035, .012, Color(.7,.96,1,alpha), eye)
			ribbon(world_geometry, point-up*.025, point+up*.025, .009, Color(.4,.9,1,alpha), eye)
		for i in sparks.size():
			var velocity := sparks[i]
			var tip := point + velocity * age
			var tail := point + velocity * maxf(0,age-.012)
			ribbon(world_geometry, tail, tip, .004, Color(1,.53,.18,alpha) if i==0 else Color(.3,.82,1,alpha), eye)
	# Surface cannot be empty on a miss after the trace expires.
	if not has_impact and age >= TRACE_LIFE:
		ribbon(world_geometry, start, start+direction*.001, .0001, Color(0,0,0,0), eye)
	world_geometry.surface_end()
