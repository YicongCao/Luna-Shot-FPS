extends Node3D
## Quarantine-only additive presentation. Assign player before add_child(); mission
## is optional (defaults to parent). Connects the existing shot signal without
## replacing ML13, raycasts, hit handling, geometry, input, or camera transforms.
## Twelve preallocated impact slots / 264 CPU particles maximum. No per-shot nodes.
## Public clear() resets transient particles/audio when the mission redeploys.

const IMPACT_SLOTS: int = 12
const SAMPLE_RATE: int = 22050
const SPARK_LIFETIME: float = 0.24
const FRAGMENT_LIFETIME: float = 0.46

var player: Node3D
var mission: Node
var _sparks: Array[CPUParticles3D] = []
var _fragments: Array[CPUParticles3D] = []
var _cursor: int = 0
var _discharge: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _alarm: AudioStreamPlayer
var _alarm_gain: float = 0.0
var _ambient_gain: float = 0.0
var _previous_elapsed: float = 0.0
var _previous_stage: int = 0
var _audio_enabled: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if not is_instance_valid(mission):
		mission = get_parent()
	_build_impact_pool()
	_discharge = _audio("DischargeBody", _make_discharge(), -14.0)
	_discharge.max_polyphony = 6
	_ambience = _audio("FactorySubstructure", _make_factory_loop(), -80.0)
	_alarm = _audio("ContainmentBeacon", _make_alarm_loop(), -80.0)
	# Headless verification has no listening session. Do not start playbacks there:
	# Godot defers stop/deletion to mixing + update, which rapid headless shutdown
	# may never service. Keep WAV generation and gain state available for tests.
	_audio_enabled = DisplayServer.get_name() != "headless"
	if _audio_enabled:
		_ambience.play()
		_alarm.play()
	if is_instance_valid(player) and player.has_signal("shot"):
		if not player.is_connected("shot", _on_shot):
			player.connect("shot", _on_shot)


func _build_impact_pool() -> void:
	var spark_mesh: BoxMesh = BoxMesh.new()
	spark_mesh.size = Vector3(0.012, 0.012, 0.038)
	var spark_material: StandardMaterial3D = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.albedo_color = Color(0.82, 0.91, 1.0)
	spark_material.emission_enabled = true
	spark_material.emission = Color(0.34, 0.62, 0.75)
	spark_material.emission_energy_multiplier = 0.7
	spark_mesh.material = spark_material
	var fragment_mesh: BoxMesh = BoxMesh.new()
	fragment_mesh.size = Vector3(0.024, 0.016, 0.009)
	var fragment_material: StandardMaterial3D = StandardMaterial3D.new()
	fragment_material.vertex_color_use_as_albedo = true
	fragment_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fragment_material.albedo_color = Color(0.29, 0.33, 0.35)
	fragment_material.metallic = 0.45
	fragment_material.roughness = 0.72
	fragment_mesh.material = fragment_material
	var spark_ramp: Gradient = Gradient.new()
	spark_ramp.offsets = PackedFloat32Array([0.0, 0.17, 0.7, 1.0])
	spark_ramp.colors = PackedColorArray([Color(0.9, 0.97, 1, 0.9), Color(0.62, 0.82, 0.92, 0.85), Color(0.85, 0.57, 0.29, 0.35), Color(0.42, 0.25, 0.13, 0)])
	var fragment_ramp: Gradient = Gradient.new()
	fragment_ramp.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	fragment_ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	for index: int in range(IMPACT_SLOTS):
		var sparks: CPUParticles3D = _emitter("ImpactSparks%02d" % index, spark_mesh, 16, SPARK_LIFETIME)
		sparks.color_ramp = spark_ramp
		sparks.initial_velocity_min = 0.6
		sparks.initial_velocity_max = 2.8
		sparks.gravity = Vector3(0, -2.4, 0)
		sparks.spread = 64.0
		sparks.scale_amount_min = 0.45
		sparks.scale_amount_max = 1.2
		_sparks.append(sparks)
		var fragments: CPUParticles3D = _emitter("ImpactFragments%02d" % index, fragment_mesh, 6, FRAGMENT_LIFETIME)
		fragments.color_ramp = fragment_ramp
		fragments.initial_velocity_min = 0.25
		fragments.initial_velocity_max = 1.1
		fragments.gravity = Vector3(0, -1.62, 0)
		fragments.spread = 72.0
		fragments.angular_velocity_min = -240.0
		fragments.angular_velocity_max = 240.0
		fragments.scale_amount_min = 0.5
		fragments.scale_amount_max = 1.1
		_fragments.append(fragments)


func _emitter(label: String, mesh: Mesh, count: int, lifetime: float) -> CPUParticles3D:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.name = label
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = count
	particles.lifetime = lifetime
	particles.local_coords = false
	particles.mesh = mesh
	particles.direction = Vector3.UP
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(particles)
	return particles


func _audio(label: String, stream: AudioStreamWAV, volume: float) -> AudioStreamPlayer:
	var audio: AudioStreamPlayer = AudioStreamPlayer.new()
	audio.name = label
	audio.stream = stream
	audio.volume_db = volume
	add_child(audio)
	return audio


func _on_shot(_hit: bool, _distance: float) -> void:
	if not is_instance_valid(player):
		return
	# A weapon-local low body under the existing ML13 crack, including misses.
	if _audio_enabled:
		_discharge.play()
	var data: Variant = player.get("last_hit")
	if not data is Dictionary:
		return
	var impact: Dictionary = data
	if not impact.has("position"):
		return
	var point: Variant = impact.get("position")
	var normal_value: Variant = impact.get("normal", Vector3.UP)
	if not point is Vector3 or not normal_value is Vector3:
		return
	var normal: Vector3 = normal_value
	if normal.length_squared() < 0.001:
		normal = Vector3.UP
	normal = normal.normalized()
	# Read the authoritative impact, never cast a different ray or chase a target.
	var location: Vector3 = point + normal * 0.025
	var sparks: CPUParticles3D = _sparks[_cursor]
	var fragments: CPUParticles3D = _fragments[_cursor]
	_cursor = (_cursor + 1) % IMPACT_SLOTS
	for particles: CPUParticles3D in [sparks, fragments]:
		particles.global_position = location
		# Emitter basis can inherit a transformed parent; convert the normal once.
		particles.direction = particles.global_basis.inverse() * normal
		particles.restart()
		particles.emitting = true


func _process(delta: float) -> void:
	var stage: int = 0
	var elapsed: float = _previous_elapsed
	if is_instance_valid(mission):
		var stage_value: Variant = mission.get("stage")
		var elapsed_value: Variant = mission.get("elapsed")
		if stage_value is int:
			stage = int(stage_value)
		if elapsed_value is float or elapsed_value is int:
			elapsed = float(elapsed_value)
	# Existing mission restart has no required signal. Detect its clock reset too;
	# callers can use clear() for an immediate explicit reset before their next tick.
	if elapsed + 0.001 < _previous_elapsed or (stage == 0 and _previous_stage >= 3):
		clear()
	_previous_elapsed = elapsed
	_previous_stage = stage
	var alarm_target: float = db_to_linear(-35.0)
	if stage == 1:
		alarm_target = db_to_linear(-32.0)
	elif stage == 2:
		alarm_target = db_to_linear(-29.0)
	elif stage >= 3:
		alarm_target = 0.0
	var amount: float = 1.0 - exp(-delta * 1.8)
	_alarm_gain = lerpf(_alarm_gain, alarm_target, amount)
	_ambient_gain = lerpf(_ambient_gain, db_to_linear(-25.0), amount)
	_alarm.volume_db = linear_to_db(maxf(_alarm_gain, 0.00001))
	_ambience.volume_db = linear_to_db(maxf(_ambient_gain, 0.00001))


func clear() -> void:
	for particles: CPUParticles3D in _sparks:
		particles.emitting = false
		# restart(keep_seed) resets existing particle ages; emitting=false alone
		# would let fragments from the previous deployment continue to render.
		particles.restart()
		particles.emitting = false
	for particles: CPUParticles3D in _fragments:
		particles.emitting = false
		particles.restart()
		particles.emitting = false
	if is_instance_valid(_discharge):
		_discharge.stop()
	_cursor = 0


func _make_discharge() -> AudioStreamWAV:
	var duration: float = 0.36
	var count: int = roundi(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 220617
	var low_noise: float = 0.0
	var slow_noise: float = 0.0
	for index: int in range(count):
		var t: float = float(index) / SAMPLE_RATE
		# Two lowpasses remove the brittle high end; the existing crack remains
		# the sole sharp transient. Integrated sweep settles toward 68 Hz.
		low_noise += (random.randf_range(-1, 1) - low_noise) * 0.15
		slow_noise += (low_noise - slow_noise) * 0.12
		var attack: float = smoothstep(0.0, 0.003, t)
		var end: float = 1.0 - smoothstep(duration - 0.06, duration, t)
		var phase: float = TAU * (68.0 * t + 97.0 * 0.032 * (1.0 - exp(-t / 0.032)))
		var body: float = sin(phase) * exp(-t * 15.0) * 0.57
		var tail: float = (sin(TAU * 53.0 * t) * 0.16 + sin(TAU * 106.0 * t) * 0.045) * exp(-t * 8.5)
		var pressure: float = slow_noise * exp(-t * 25.0) * 0.9
		_store_sample(bytes, index, (body + tail + pressure) * attack * end)
	return _wav(bytes, false)


func _make_factory_loop() -> AudioStreamWAV:
	# Six-second periodic harmonics and modulation: sample-exact looping without
	# a discontinuous random-noise seam. Low harmonics remain audible on laptops.
	var duration: float = 6.0
	var count: int = roundi(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for index: int in range(count):
		var t: float = float(index) / SAMPLE_RATE
		var cycle: float = TAU * t / duration
		var modulation: float = 0.84 + 0.1 * cos(cycle) + 0.06 * cos(cycle * 2.0)
		var motors: float = sin(TAU * 47.0 * t) * 0.28 + sin(TAU * 53.0 * t) * 0.19
		var structure: float = sin(TAU * 94.0 * t + 0.2 * sin(cycle)) * 0.095
		var ventilation: float = sin(TAU * 141.0 * t) * 0.035 + sin(TAU * 188.0 * t) * 0.02
		_store_sample(bytes, index, (motors + structure + ventilation) * modulation)
	return _wav(bytes, true)


func _make_alarm_loop() -> AudioStreamWAV:
	# A soft two-note beacon every four seconds, not a full-time siren or hiss.
	var duration: float = 4.0
	var count: int = roundi(duration * SAMPLE_RATE)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for index: int in range(count):
		var t: float = float(index) / SAMPLE_RATE
		var sample: float = _beacon_note(t - 0.12, 185.0) + _beacon_note(t - 0.62, 220.0)
		_store_sample(bytes, index, sample)
	return _wav(bytes, true)


func _beacon_note(t: float, frequency: float) -> float:
	if t <= 0.0 or t >= 0.38:
		return 0.0
	var envelope: float = smoothstep(0.0, 0.045, t) * (1.0 - smoothstep(0.14, 0.38, t))
	return (sin(TAU * frequency * t) * 0.48 + sin(TAU * frequency * 2.0 * t) * 0.045) * envelope


func _store_sample(bytes: PackedByteArray, index: int, value: float) -> void:
	bytes.encode_s16(index * 2, roundi(clampf(value, -0.85, 0.85) * 32767.0))


func _wav(bytes: PackedByteArray, loop: bool) -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = bytes.size() / 2
	return wav


func _exit_tree() -> void:
	if is_instance_valid(player) and player.has_signal("shot") and player.is_connected("shot", _on_shot):
		player.disconnect("shot", _on_shot)
	# Looping WAV playbacks can outlive their scene during immediate QA shutdown.
	# Explicitly end playback and release stream refs while the audio server is
	# still alive, including when the tree was paused on a mission end screen.
	for audio: AudioStreamPlayer in [_discharge, _ambience, _alarm]:
		if is_instance_valid(audio):
			if audio.has_stream_playback():
				var playback: AudioStreamPlayback = audio.get_stream_playback()
				playback.stop()
			audio.stop()
			audio.stream = null
	_discharge = null
	_ambience = null
	_alarm = null
