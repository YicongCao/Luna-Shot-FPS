extends StaticBody3D

signal suit_hit(amount: int, origin: Vector3)
signal cue(kind: String, origin: Vector3)

enum Phase { SAFE, WARN, SWEEP, DISABLED }

const Kit = preload("res://scripts/polar/kit.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const MOUNT := Vector3(-7.5, Layout.MID, Layout.SHAFT_Z)
const SAFE_SECONDS := 5.4
const WARN_SECONDS := 1.75
const SWEEP_SECONDS := 2.25
const RETURN_SECONDS := 1.65
const SWEEP_YAW := .34 # Fits the 3.62 m wide bypass, including the corer housing.
const UPPER := 1.82
const FORE := 1.73
const SHOULDER_UP := .78
const ELBOW_UP := -.90
const SHOULDER_DOWN := .18
const ELBOW_DOWN := -.45
const CONTACT := Vector3(.34, -.22, 0)
const STRUT_FOOT := Vector3(.27, .65, .28)
const STRUT_EYE := Vector3(.88, -.16, .28)
const HIT_RADIUS := .60
const HIT_HEIGHT := .62
const MAX_HEALTH := 4
const DAMAGE := 22
const AMBER := Color(1.0, .56, .16)

var phase: Phase = Phase.SAFE
var phase_time := 0.0
var health := MAX_HEALTH
var _returning := false
var _spent := false
var _deployment := 0.0
var _turret: Node3D
var _shoulder: Node3D
var _elbow: Node3D
var _wrist: Node3D
var _contact: Node3D
var _barrel: MeshInstance3D
var _rod: MeshInstance3D
var _drive_lens: MeshInstance3D
var _tool_lens: MeshInstance3D
var _marks: Array[MeshInstance3D] = []
var _paint: Material
var _steel: Material
var _polished: Material
var _rubber: Material
var _utility: Material
var _amber_dim: Material
var _amber_hot: Material


func _ready() -> void:
	position = MOUNT
	collision_layer = 4
	collision_mask = 0
	var target := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = Vector3(1.49, 1.10, 1.28)
	target.position = Vector3(.05, .70, 0)
	target.shape = bounds
	add_child(target)
	_build_arm()
	_build_markers()
	reset()


func reset() -> void:
	phase = Phase.SAFE
	phase_time = 0.0
	health = MAX_HEALTH
	_returning = false
	_spent = false
	_pose(SWEEP_YAW, 0.0)
	_refresh_lights()


func tip_position() -> Vector3:
	return _contact.global_position


func drive_position() -> Vector3:
	return _drive_lens.global_position


func register_hit() -> bool:
	if health <= 0:
		return false
	health -= 1
	if health == 0:
		phase = Phase.DISABLED
		phase_time = 0.0
		_refresh_lights()
		cue.emit("disabled", drive_position())
	return true


func tick(delta: float, feet: Vector3, eye: Vector3, unoccluded: Callable) -> void:
	phase_time += delta
	match phase:
		Phase.SAFE:
			if _returning:
				var swing := smoothstep(.35, RETURN_SECONDS, phase_time)
				var lower := 1.0 - smoothstep(0.0, .54, phase_time)
				_pose(lerpf(-SWEEP_YAW, SWEEP_YAW, swing), lower)
				_returning = phase_time < RETURN_SECONDS
			if phase_time >= SAFE_SECONDS:
				phase = Phase.WARN
				phase_time = 0.0
				_refresh_lights()
				cue.emit("sampler_warn", drive_position())
		Phase.WARN:
			_pose(SWEEP_YAW, smoothstep(.12, WARN_SECONDS - .16, phase_time))
			if phase_time >= WARN_SECONDS:
				phase = Phase.SWEEP
				phase_time = 0.0
				_spent = false
				_refresh_lights(0.0)
				cue.emit("sampler_sweep", tip_position())
			else:
				_refresh_lights()
		Phase.SWEEP:
			var sweep := smoothstep(0.0, SWEEP_SECONDS, phase_time)
			_pose(lerpf(SWEEP_YAW, -SWEEP_YAW, sweep), 1.0)
			_refresh_lights(sweep)
			_try_contact(feet, eye, unoccluded)
			if phase == Phase.SWEEP and phase_time >= SWEEP_SECONDS:
				phase = Phase.SAFE
				phase_time = 0.0
				_returning = true
				_refresh_lights()
		Phase.DISABLED:
			# A pressure accumulator lifts the head clear after the drive goes dark.
			if _deployment > 0.0:
				_pose(_turret.rotation.y, move_toward(_deployment, 0.0, delta * 1.6))


func _try_contact(feet: Vector3, eye: Vector3, unoccluded: Callable) -> void:
	if _spent or feet.x > -2.55 or absf(feet.y - Layout.MID) > .85:
		return
	if absf(feet.z - Layout.SHAFT_Z) > 1.63:
		return
	var tip := tip_position()
	var torso := feet + Vector3.UP * 1.04
	var offset := torso - tip
	if offset.x * offset.x + offset.z * offset.z > HIT_RADIUS * HIT_RADIUS or absf(offset.y) > HIT_HEIGHT:
		return
	if unoccluded.call(tip, torso) and unoccluded.call(tip, eye):
		_spent = true
		suit_hit.emit(DAMAGE, tip)


func _pose(yaw: float, deployment: float) -> void:
	_deployment = deployment
	_turret.rotation.y = yaw
	var shoulder_pitch := lerpf(SHOULDER_UP, SHOULDER_DOWN, deployment)
	var elbow_pitch := lerpf(ELBOW_UP, ELBOW_DOWN, deployment)
	_shoulder.rotation.z = shoulder_pitch
	_elbow.rotation.z = elbow_pitch
	_wrist.rotation.z = -shoulder_pitch - elbow_pitch
	# The hydraulic barrel is fixed-length; only the piston travels as the links pitch.
	var link := _shoulder.transform * STRUT_EYE
	var direction := STRUT_FOOT.direction_to(link)
	var sleeve_end := STRUT_FOOT + direction * .51
	_fit_tube(_barrel, STRUT_FOOT, sleeve_end)
	_fit_tube(_rod, sleeve_end - direction * .04, link)


func _fit_tube(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var axis := b - a
	var axes := Basis(Quaternion(Vector3.UP, axis.normalized()))
	axes.y = axis
	mesh.transform = Transform3D(axes, (a + b) * .5)


func _refresh_lights(progress: float = 0.0) -> void:
	var warn := phase == Phase.WARN
	var sweeping := phase == Phase.SWEEP
	var flash := warn and cos(TAU * 2.0 * phase_time) > 0.0
	var lamp := _rubber if phase == Phase.DISABLED else _utility
	if warn or sweeping:
		lamp = _amber_hot if flash or sweeping else _amber_dim
	_drive_lens.material_override = lamp
	_tool_lens.material_override = lamp
	var passing := roundi(progress * float(_marks.size() - 1))
	for i in range(_marks.size()):
		var color := _rubber
		if flash or (sweeping and i == passing):
			color = _amber_hot
		elif warn or sweeping:
			color = _amber_dim
		_marks[i].material_override = color


func _pivot(parent: Node3D, label: String, offset: Vector3) -> Node3D:
	var part := Node3D.new()
	part.name = label
	part.position = offset
	parent.add_child(part)
	return part


func _build_arm() -> void:
	_paint = Kit.surface(Color(.42, .46, .48), .32, .56)
	_steel = Kit.surface(Color(.22, .26, .29), .72, .47, 1)
	_polished = Kit.surface(Color(.52, .55, .56), .83, .32, 1)
	_rubber = Kit.surface(Color(.075, .085, .095), .06, .73, 2)
	_utility = Kit.glow(Color(.45, .74, .82), .95)
	_amber_dim = Kit.glow(AMBER, .47)
	_amber_hot = Kit.glow(AMBER, 1.72)

	Kit.box(self, Vector3(0, .077, 0), Vector3(1.58, .154, 1.48), _steel, .055)
	Kit.box(self, Vector3(-.025, .485, 0), Vector3(1.26, .72, 1.12), _paint, .084)
	Kit.box(self, Vector3(.628, .62, 0), Vector3(.14, .43, .79), _steel, .035)
	Kit.box(self, Vector3(.712, .60, 0), Vector3(.06, .25, .54), _paint, .024)
	_drive_lens = Kit.box(self, Vector3(.746, .665, 0), Vector3(.027, .042, .24), _utility, .009)
	for x: float in [-.64, .64]:
		for z: float in [-.60, .60]:
			var bolt := Vector3(x, .147, z)
			Kit.pipe(self, bolt, bolt + Vector3.UP * .055, .068, _polished, 6)
	for z: float in [-.42, .42]:
		Kit.pipe(self, Vector3(.54, .35, z), Vector3(.28, .21, z * 1.37), .055, _rubber, 10)
		Kit.pipe(self, Vector3(.28, .21, z * 1.37), Vector3(-.37, .21, z * 1.37), .054, _rubber, 10)

	_turret = _pivot(self, "SlewBearing", Vector3.ZERO)
	Kit.pipe(_turret, Vector3.UP * .81, Vector3.UP * 1.045, .51, _steel, 20)
	Kit.pipe(_turret, Vector3.UP * .932, Vector3.UP * .99, .526, _polished, 20)
	_shoulder = _pivot(_turret, "Shoulder", Vector3.UP * 1.26)
	_elbow = _pivot(_shoulder, "Elbow", Vector3.RIGHT * UPPER)
	_wrist = _pivot(_elbow, "ToolCarrier", Vector3.RIGHT * FORE)
	_contact = _pivot(_wrist, "SampleContact", CONTACT)
	for side: float in [-1.0, 1.0]:
		Kit.box(_turret, Vector3(-.06, 1.08, side * .298), Vector3(.42, .46, .16), _steel, .052)
		Kit.box(_shoulder, Vector3(.90, 0, side * .211), Vector3(1.80, .36, .142), _paint, .057)
		Kit.box(_shoulder, Vector3(.84, -.169, side * .206), Vector3(1.39, .112, .093), _steel, .026)
		Kit.box(_elbow, Vector3(.84, 0, side * .136), Vector3(1.73, .27, .13), _paint, .044)
		Kit.pipe(_shoulder, Vector3(.21, .17, side * .316), Vector3(1.43, .17, side * .316), .032, _rubber, 10)
		Kit.pipe(_shoulder, Vector3(1.43, .17, side * .316), Vector3(1.70, .051, side * .29), .034, _rubber, 10)
		for i in range(3):
			Kit.box(_shoulder, Vector3(.49 + float(i) * .35, .155, side * .315), Vector3(.052, .095, .065), _polished, .009)
	_journal(_shoulder, .225, .345)
	_journal(_elbow, .181, .273)
	_journal(_wrist, .133, .197)
	_barrel = Kit.pipe(_turret, Vector3.ZERO, Vector3.UP, .118, _steel, 16)
	_rod = Kit.pipe(_turret, Vector3.ZERO, Vector3.UP, .060, _polished, 14)

	Kit.box(_wrist, Vector3(.22, .032, 0), Vector3(.55, .28, .39), _steel, .051)
	Kit.pipe(_wrist, CONTACT + Vector3.UP * .06, CONTACT + Vector3.UP * .30, .225, _paint, 18)
	Kit.pipe(_wrist, CONTACT + Vector3.DOWN * .07, CONTACT + Vector3.UP * .13, .198, _polished, 18)
	for i in range(6):
		var yaw := float(i) * TAU / 6.0
		var tooth := Vector3.RIGHT.rotated(Vector3.UP, yaw) * .165
		Kit.box(_wrist, CONTACT + tooth + Vector3.DOWN * .076, Vector3(.093, .112, .075), _steel, .017, false, yaw)
	_tool_lens = Kit.box(_wrist, Vector3(.499, .05, 0), Vector3(.018, .043, .174), _utility, .008)


func _journal(root: Node3D, radius: float, width: float) -> void:
	Kit.pipe(root, Vector3.FORWARD * width, Vector3.BACK * width, radius, _steel, 16)
	for side: float in [-1.0, 1.0]:
		Kit.pipe(root, Vector3.BACK * width * side, Vector3.BACK * (width + .043) * side, radius * .69, _polished, 12)
		Kit.pipe(root, Vector3.BACK * (width + .043) * side, Vector3.BACK * (width + .068) * side, radius * .29, _steel, 6)


func _build_markers() -> void:
	# Low-profile light inserts follow the deployed contact point, not the lift.
	var radius := UPPER * cos(SHOULDER_DOWN) + FORE * cos(SHOULDER_DOWN + ELBOW_DOWN) + CONTACT.x
	for i in range(9):
		var yaw := lerpf(SWEEP_YAW, -SWEEP_YAW, float(i) / 8.0)
		var at := Vector3.RIGHT.rotated(Vector3.UP, yaw) * radius
		Kit.box(self, at + Vector3.UP * .011, Vector3(.22, .022, .117), _steel, .009, false, yaw)
		_marks.append(Kit.box(self, at + Vector3.UP * .028, Vector3(.139, .016, .065), _rubber, .007, false, yaw))
