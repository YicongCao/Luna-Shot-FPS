extends AnimatableBody3D

signal suit_hit(amount: int, origin: Vector3)
signal cue(kind: String, origin: Vector3)

enum Phase { PATROL, CHARGE, RECOVER, DISABLED }

const Kit = preload("res://scripts/polar/kit.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const TRACK_X := 1.0
const BODY_Y := -13.08
const MIN_Z := -26.0
const MAX_Z := 20.0
const START_Z := -21.5
const ROLLER_RADIUS := .14
const SPEED := 2.65
const ATTACK_RANGE := 8.25
const CHARGE_SECONDS := 1.55
const LOCK_AT := .63
const RECOVER_SECONDS := 3.25
const PULSE_SECONDS := .14
const PULSE_RADIUS := .68
const MAX_HEALTH := 3
const DAMAGE := 15
const COLD := Color(.45, .74, .82)
const AMBER := Color(1.0, .56, .16)

var phase: Phase = Phase.PATROL
var phase_time := 0.0
var health := MAX_HEALTH
var _travel := 1.0
var _wheel_cue := 0.0
var _aim := Vector3.ZERO
var _locked := false
var _rollers: Array[Node3D] = []
var _gimbal: Node3D
var _lens: MeshInstance3D
var _spot: SpotLight3D
var _pulse: MeshInstance3D
var _utility: StandardMaterial3D
var _warning: StandardMaterial3D
var _rubber: Material


static func build_track(root: Node3D) -> void:
	var frame := Kit.surface(Color(.23, .27, .29), .68, .55, 1)
	var tread := Kit.surface(Color(.37, .43, .46), .82, .39, 1)
	var pad := Kit.surface(Color(.075, .08, .085), .04, .76, 2)
	var length := MAX_Z - MIN_Z + 2.3
	var mid := (MIN_Z + MAX_Z) * .5
	# I-section with two polished roller treads and replaceable end stops.
	Kit.box(root, Vector3(TRACK_X, -12.28, mid), Vector3(.53, .08, length), frame, .01, true)
	Kit.box(root, Vector3(TRACK_X, -12.08, mid), Vector3(.14, .34, length), frame, .009, true)
	Kit.box(root, Vector3(TRACK_X, -11.88, mid), Vector3(.36, .07, length), frame, .009, true)
	for side: float in [-1.0, 1.0]:
		Kit.box(root, Vector3(TRACK_X + side * .21, -12.234, mid), Vector3(.086, .012, length), tread, .004)
	for z: float in [-25.0, -17.0, -9.0, -1.0, 7.0, 15.0, 19.0]:
		Kit.box(root, Vector3(TRACK_X, -11.76, z), Vector3(.57, .165, .32), frame)
		Kit.box(root, Vector3(TRACK_X, -11.27, z), Vector3(.16, .85, .18), frame, .012)
		Kit.box(root, Vector3(TRACK_X, -10.83, z), Vector3(.64, .08, .48), frame, .01)
		for side: float in [-1.0, 1.0]:
			var bolt := Vector3(TRACK_X + side * .20, -11.88, z)
			Kit.pipe(root, bolt, bolt + Vector3.UP * .043, .038, tread, 6)
	for z: float in [MIN_Z - .91, MAX_Z + .91]:
		Kit.box(root, Vector3(TRACK_X, -12.12, z), Vector3(.62, .34, .23), frame)
		Kit.box(root, Vector3(TRACK_X, -12.13, z), Vector3(.64, .22, .13), pad, .02)

	# Portal legs land at the edge of the drill deck, clear of the main lane.
	var girder := Kit.surface(Color(.32, .36, .39), .51, .55)
	Kit.box(root, Vector3(TRACK_X, -10.60, mid), Vector3(.36, .40, length), girder, .02, true)
	for z: float in [-25.0, -9.0, 7.0, 19.0]:
		Kit.box(root, Vector3(0, -10.45, z), Vector3(21.96, .36, .43), girder, .025, true)
		for side: float in [-1.0, 1.0]:
			var foot := Vector3(side * 10.8, Layout.PIT, z)
			Kit.box(root, foot + Vector3.UP * .14, Vector3(.93, .28, .96), frame, .05, true)
			Kit.box(root, foot + Vector3.UP * 3.43, Vector3(.34, 6.37, .37), girder, .025, true)
			Kit.beam(root, foot + Vector3.UP * 5.06, foot + Vector3(-side * 1.62, 6.39, 0), .20, frame, true, .26)
			for offset: float in [-.29, .29]:
				var stud := foot + Vector3(side * .29, .278, offset)
				Kit.pipe(root, stud, stud + Vector3.UP * .078, .053, tread, 6)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	sync_to_physics = false
	var collider := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(1.05, .75, 1.56)
	collider.shape = bounds
	add_child(collider)
	_build_carriage()
	reset()


func reset() -> void:
	position = Vector3(TRACK_X, BODY_Y, START_Z)
	_travel = 1.0
	_wheel_cue = .0
	_aim = Vector3.ZERO
	_locked = false
	health = MAX_HEALTH
	phase = Phase.PATROL
	phase_time = 0.0
	for roller: Node3D in _rollers:
		roller.rotation.x = 0.0
	_utility.emission_enabled = true
	_spot.show()
	_idle_light()
	_look_along_track()


func emitter_position() -> Vector3:
	return _gimbal.global_position


func register_hit() -> bool:
	if health <= 0:
		return false
	health -= 1
	if health == 0:
		phase = Phase.DISABLED
		phase_time = 0.0
		_pulse.hide()
		_spot.hide()
		_utility.emission_enabled = false
		_lens.material_override = _rubber
		cue.emit("disabled", global_position)
	return true


func tick(delta: float, feet: Vector3, eye: Vector3, unoccluded: Callable) -> void:
	phase_time += delta
	match phase:
		Phase.PATROL:
			_ride(delta)
			var origin := emitter_position()
			if _eligible(feet, eye, origin) and unoccluded.call(origin, eye):
				phase = Phase.CHARGE
				phase_time = 0.0
				_aim = eye
				_locked = false
				_charge_light()
				cue.emit("rail_charge", origin)
		Phase.CHARGE:
			var origin := emitter_position()
			if not _eligible(feet, eye, origin) or not unoccluded.call(origin, eye):
				_recover()
				return
			if not _locked:
				_aim = eye
				_locked = phase_time >= LOCK_AT
			_charge_light()
			if phase_time >= CHARGE_SECONDS:
				_fire(origin, eye, unoccluded)
		Phase.RECOVER:
			if phase_time >= PULSE_SECONDS:
				_idle_light()
				_ride(delta)
			if phase_time >= RECOVER_SECONDS:
				phase = Phase.PATROL
				phase_time = 0.0


func _eligible(feet: Vector3, eye: Vector3, origin: Vector3) -> bool:
	return (absf(feet.y - Layout.PIT) <= 1.25 and feet.z >= -32.0 and feet.z <= 31.0
		and eye.y < origin.y - .30 and origin.distance_squared_to(eye) <= ATTACK_RANGE * ATTACK_RANGE)


func _ride(delta: float) -> void:
	var old_z := position.z
	position.z = clampf(old_z + _travel * SPEED * delta, MIN_Z, MAX_Z)
	if position.z == MAX_Z:
		_travel = -1.0
	elif position.z == MIN_Z:
		_travel = 1.0
	for roller: Node3D in _rollers:
		roller.rotation.x = fposmod(roller.rotation.x + (position.z - old_z) / ROLLER_RADIUS, TAU)
	_wheel_cue += absf(position.z-old_z)
	if _wheel_cue > 4.75:
		_wheel_cue -= 4.75
		cue.emit("rail_roll",emitter_position())
	_look_along_track()


func _look_along_track() -> void:
	_aim_lens(emitter_position() + Vector3(0, -2.2, 4.0 * _travel))


func _aim_lens(target: Vector3) -> void:
	var elevation := absf(emitter_position().direction_to(target).y)
	_gimbal.look_at(target, Vector3.RIGHT if elevation > .98 else Vector3.UP)


func _charge_light() -> void:
	_aim_lens(_aim)
	var wave := .5 + .5 * cos(TAU * 2.0 * phase_time)
	_warning.emission_energy_multiplier = lerpf(.75, 2.0, wave)
	_lens.material_override = _warning
	_spot.light_color = AMBER
	_spot.light_energy = lerpf(.64, .96, wave)
	_spot.spot_range = ATTACK_RANGE + .25


func _idle_light() -> void:
	_pulse.hide()
	_lens.material_override = _utility
	_spot.light_color = COLD
	_spot.light_energy = .38
	_spot.spot_range = 5.0


func _recover() -> void:
	phase = Phase.RECOVER
	phase_time = 0.0
	_idle_light()


func _fire(origin: Vector3, eye: Vector3, unoccluded: Callable) -> void:
	_recover()
	# The aim has been committed for the back half of the charge. Both the
	# committed line and the current eye must still be clear on the firing tick.
	if not unoccluded.call(origin, _aim):
		return
	var nearest := Geometry3D.get_closest_point_to_segment(eye, origin, _aim)
	var lands := nearest.distance_squared_to(eye) <= PULSE_RADIUS * PULSE_RADIUS
	var a := to_local(origin)
	var b := to_local(_aim)
	var axis := b - a
	var axes := Basis(Quaternion(Vector3.UP, axis.normalized()))
	axes.y = axis
	_pulse.transform = Transform3D(axes, (a + b) * .5)
	_warning.emission_energy_multiplier = 2.5
	_lens.material_override = _warning
	_spot.light_color = AMBER
	_spot.light_energy = 1.22
	_spot.spot_range = ATTACK_RANGE + .25
	_pulse.show()
	cue.emit("rail_fire", origin)
	if lands and phase == Phase.RECOVER:
		suit_hit.emit(DAMAGE, origin)


func _build_carriage() -> void:
	var paint := Kit.surface(Color(.31, .37, .39), .45, .53)
	var steel := Kit.surface(Color(.20, .24, .27), .75, .49, 1)
	var satin := Kit.surface(Color(.47, .51, .50), .78, .32, 1)
	_rubber = Kit.surface(Color(.074, .086, .095), .04, .78, 2)
	_utility = Kit.glow(COLD, 1.05)
	_warning = Kit.glow(AMBER, 1.6)
	Kit.box(self, Vector3.ZERO, Vector3(1.02, .69, 1.54), paint, .086)
	Kit.box(self, Vector3(0, -.31, 0), Vector3(.93, .15, 1.32), steel, .04)
	Kit.box(self, Vector3(0, .44, 0), Vector3(.86, .33, 1.33), steel, .028)
	for end: float in [-1.0, 1.0]:
		Kit.box(self, Vector3(0, -.065, end * .79), Vector3(.77, .29, .12), _rubber, .033)
		Kit.box(self, Vector3(0, -.054, end * .851), Vector3(.23, .035, .014), _utility, .008)
		for x: float in [-.31, .31]:
			var bolt := Vector3(x, .126, end * .774)
			Kit.pipe(self, bolt, bolt + Vector3(0, 0, end * .04), .04, satin, 6)
	for side: float in [-1.0, 1.0]:
		Kit.box(self, Vector3(side * .515, -.09, -.17), Vector3(.086, .29, .86), steel, .025)
		for i in range(5):
			Kit.box(self, Vector3(side * .565, -.09, -.46 + i * .125), Vector3(.037, .175, .045), satin, .01)
		Kit.box(self, Vector3(side * .39, .69, 0), Vector3(.12, .32, 1.47), paint, .027)
		for z: float in [-.56, .56]:
			Kit.box(self, Vector3(side * .372, .904, z), Vector3(.109, .305, .211), steel, .023)
			_add_roller(Vector3(side * .245, .986, z), steel, satin)
		Kit.pipe(self, Vector3(side * .42, .09, .58), Vector3(side * .56, .24, .58), .037, _rubber, 10)
		Kit.pipe(self, Vector3(side * .56, .24, .58), Vector3(side * .56, .24, -.26), .037, _rubber, 10)
	Kit.pipe(self, Vector3(.48, -.17, .52), Vector3(.665, -.30, .69), .027, steel, 10)
	Kit.pipe(self, Vector3(.665, -.30, .69), Vector3(.70, -.41, .88), .016, _rubber, 8)

	_gimbal = Node3D.new()
	_gimbal.name = "InspectionEmitter"
	_gimbal.position = Vector3(0, -.52, 0)
	add_child(_gimbal)
	Kit.pipe(self, Vector3(0, -.35, 0), _gimbal.position, .105, steel, 12)
	Kit.pipe(_gimbal, Vector3(0, 0, .014), Vector3(0, 0, .24), .16, steel, 16)
	Kit.pipe(_gimbal, Vector3(0, 0, -.006), Vector3(0, 0, .04), .133, satin, 16)
	_lens = Kit.pipe(_gimbal, Vector3(0, 0, -.02), Vector3(0, 0, .0), .10, _utility, 16)
	_spot = SpotLight3D.new()
	_spot.position.z = -.022
	_spot.spot_angle = 18.0
	_spot.spot_attenuation = 1.6
	_spot.shadow_enabled = true
	_spot.light_volumetric_fog_energy = 0.0
	_gimbal.add_child(_spot)
	_pulse = Kit.pipe(self, Vector3.ZERO, Vector3.UP, .016, _warning, 8)
	_pulse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _add_roller(at: Vector3, steel: Material, satin: Material) -> void:
	var hub := Node3D.new()
	hub.position = at
	add_child(hub)
	_rollers.append(hub)
	Kit.pipe(hub, Vector3.LEFT * .071, Vector3.RIGHT * .071, ROLLER_RADIUS, steel, 16)
	Kit.pipe(hub, Vector3.LEFT * .089, Vector3.RIGHT * .089, .086, satin, 12)
	for x: float in [-.088, .088]:
		Kit.box(hub, Vector3(x, .058, 0), Vector3(.02, .046, .07), steel, .008)
