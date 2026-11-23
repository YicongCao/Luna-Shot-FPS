extends Node
## Small generated audio bank. Vacuum never plays distant diegetic air sound.
const SAMPLE_RATE := 22050
var fan: AudioStreamPlayer
var cue: AudioStreamPlayer
var samples: Dictionary = {}
var pressure := 0.0
var muted := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless": return
	fan = AudioStreamPlayer.new()
	fan.stream = _tone("fan",1.7,true)
	fan.volume_db = -65.0
	add_child(fan)
	cue = AudioStreamPlayer.new()
	cue.volume_db = -13.0
	add_child(cue)
	for entry in [["pulse",.13],["rail_roll",.31],["rail_charge",.34],["rail_fire",.18],["sampler_warn",.54],
		["sampler_sweep",.29],["disabled",.32],["seal",.72],["confirmed",.26],["lift",.48],["impact",.17]]:
		samples[entry[0]] = _tone(entry[0],entry[1])

func _exit_tree() -> void:
	if fan != null:
		fan.stop()
		cue.stop()
		fan.stream = null
		cue.stream = null

func tick(delta: float, in_air: bool) -> void:
	if fan == null: return
	var active := in_air and not muted
	pressure = move_toward(pressure,1.0 if active else 0.0,delta*1.6)
	if active and not fan.playing: fan.play()
	fan.volume_db = lerpf(-65.0,-23.0,pressure)
	if not active and pressure == 0.0 and fan.playing: fan.stop()

func emit_cue(kind: String, strength: float = 1.0, dim: bool = false) -> void:
	if muted or not samples.has(kind): return
	cue.stream = samples[kind]
	cue.pitch_scale = .73 if dim else 1.0
	cue.volume_db = linear_to_db(clampf(strength,.04,1.0))-14.0
	cue.play()

func _tone(kind: String, seconds: float, looping: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	var count := int(seconds*SAMPLE_RATE)
	data.resize(count*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(kind.hash())
	var smooth := 0.0
	for i in count:
		var t := float(i)/SAMPLE_RATE
		var p := float(i)/count
		smooth = lerpf(smooth,rng.randf_range(-1,1),.14)
		var envelope := minf(1.0,p*26.0)*pow(1.0-p,.82)
		var value := 0.0
		match kind:
			"fan":
				# Integer cycles over the loop; the ends match rather than click.
				value = .32*sin(p*TAU*109)+.14*sin(p*TAU*217)+.16*sin(p*TAU*41)+smooth*.14*sin(p*PI)
				envelope = 1.0
			"pulse": value = sin(TAU*(127.0*t-220.0*t*t))*.45+smooth*.88
			"rail_roll": value = .25*sin(TAU*85.0*t)+.34*smooth*(.44+.56*pow(sin(t*TAU*13.0),2.0))
			"rail_charge": value = .38*sin(TAU*(138*t+415*t*t))+.18*sin(TAU*(278.0*t+292.0*t*t))
			"rail_fire", "impact": value = .71*sin(TAU*(58.0*t-58.0*t*t))+.52*smooth
			"sampler_warn": value = (.44*sin(t*TAU*280.0)+.23*sin(t*TAU*125.0))*(.26+.74*pow(sin(t*TAU*3.0),2.0))
			"sampler_sweep", "lift", "seal": value = .50*sin(TAU*(61.0*t+42.0*t*t))+.3*smooth+.13*sin(t*TAU*235.0)
			"disabled": value = .39*sin(TAU*(122.0*t-87.0*t*t))+.37*smooth
			"confirmed": value = .42*sin(TAU*t*(360.0 if p < .47 else 540.0))
		data.encode_s16(i*2,int(clampf(value*envelope*.79,-1,1)*32760))
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = SAMPLE_RATE
	wave.data = data
	if looping:
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = count
	return wave
