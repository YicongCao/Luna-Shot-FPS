extends CharacterBody3D
## Procedural six-legged factory pest. Local ray steering; no navigation bake.
signal died(bug: Node3D)

const HIT_POINTS: int = 3
const ATTACK_DAMAGE: float = 12.0
const ATTACK_INTERVAL: float = 1.15
const ATTACK_RADIUS: float = 1.6
const DETECTION_RADIUS: float = 15.0
var mission: Node3D
var patrol_index: int = 0
var health: int = HIT_POINTS
var dead: bool = false
var alive: bool:
	get:
		return not dead
var attack_cooldown: float = 0.5
var patrol_origin: Vector3
var patrol_time: float = 0.0
var gait_time: float = 0.0
var model: Node3D
var legs: Array[Node3D] = []
var core_material: StandardMaterial3D
var _avoid_side: float = 1.0
var _avoid_left: float = 0.0
var plates: Array[MeshInstance3D] = []
var electrical_damage: Node3D
var visual_style: String = "baseline"

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 2
	floor_snap_length = 0.4
	floor_constant_speed = true
	patrol_origin = global_position
	_avoid_side = 1.0 if patrol_index % 2 == 0 else -1.0
	patrol_time = float(patrol_index) * 0.73
	var collider: CollisionShape3D = CollisionShape3D.new()
	collider.name = "Collider"
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.43
	capsule.height = 0.9
	collider.shape = capsule
	collider.position.y = 0.45
	add_child(collider)
	_build_model()
	electrical_damage = Node3D.new()
	electrical_damage.name = "ElectricalDamage"
	electrical_damage.set_script(preload("res://scripts/quarantine/bug_damage.gd"))
	electrical_damage.bug = self
	model.add_child(electrical_damage)

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = 0.38 if metallic > 0.0 else 0.65
	return material

func _ellipsoid(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	instance.scale = size
	parent.add_child(instance)
	return instance

func _strut(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 8
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = (a + b) * 0.5
	var direction: Vector3 = (b - a).normalized()
	instance.quaternion = Quaternion(Vector3.UP, direction)
	parent.add_child(instance)

func _build_model() -> void:
	model = Node3D.new()
	model.name = "MechanicalShell"
	add_child(model)
	if OS.get_environment("QUARANTINE_BUG_STYLE") != "baseline":
		visual_style = "refined"
		preload("res://scripts/quarantine/bug_visual.gd").build(self)
		return
	var shell: StandardMaterial3D = _material(Color(0.17, 0.21, 0.24), 0.8)
	var pale: StandardMaterial3D = _material(Color(0.52, 0.56, 0.55), 0.7)
	var dark: StandardMaterial3D = _material(Color(0.035, 0.045, 0.05), 0.6)
	core_material = _material(Color(1.0, 0.24, 0.025), 0.25)
	core_material.emission_enabled = true
	core_material.emission = Color(1.0, 0.16, 0.015)
	core_material.emission_energy_multiplier = 3.0
	_ellipsoid(model, Vector3(0, 0.46, 0.04), Vector3(0.64, 0.38, 1.0), dark)
	# Three separated pairs of shell plates expose the orange longitudinal core.
	_ellipsoid(model, Vector3(0, 0.62, 0.04), Vector3(0.13, 0.16, 0.84), core_material)
	for segment: int in range(3):
		for side: int in [-1, 1]:
			var plate: MeshInstance3D = _ellipsoid(model,
				Vector3(float(side) * 0.21, 0.57, -0.27 + float(segment) * 0.3),
				Vector3(0.38, 0.27, 0.28), pale if segment == 1 else shell)
			plate.rotation.z = float(side) * -0.18
			plates.append(plate)
	_ellipsoid(model, Vector3(0, 0.44, -0.51), Vector3(0.43, 0.3, 0.3), shell)
	for side: int in [-1, 1]:
		_ellipsoid(model, Vector3(float(side) * 0.14, 0.49, -0.65), Vector3(0.08, 0.07, 0.06), core_material)
		var antenna_base: Vector3 = Vector3(float(side) * 0.16, 0.53, -0.53)
		var antenna_joint: Vector3 = Vector3(float(side) * 0.27, 0.79, -0.7)
		var antenna_tip: Vector3 = Vector3(float(side) * 0.4, 0.78, -0.93)
		_strut(model, antenna_base, antenna_joint, 0.018, pale)
		_strut(model, antenna_joint, antenna_tip, 0.014, dark)
		_ellipsoid(model, antenna_tip, Vector3.ONE * 0.055, core_material)
		for segment: int in range(3):
			var leg: Node3D = Node3D.new()
			leg.position = Vector3(float(side) * 0.28, 0.43, float(segment - 1) * 0.32)
			model.add_child(leg)
			legs.append(leg)
			var knee: Vector3 = Vector3(float(side) * 0.37, 0.02, float(segment - 1) * 0.09)
			var foot: Vector3 = Vector3(float(side) * 0.51, -0.38, float(segment - 1) * 0.16)
			_strut(leg, Vector3.ZERO, knee, 0.047, pale)
			_strut(leg, knee, foot, 0.029, dark)
			_ellipsoid(leg, knee, Vector3.ONE * 0.12, shell)
			_ellipsoid(leg, foot, Vector3(0.13, 0.06, 0.12), pale)

func show_electrical_hit(point: Vector3, normal: Vector3) -> void:
	# Presentation only; authoritative health/death stays in register_hit().
	electrical_damage.hit(point,normal)

func register_hit() -> bool:
	if dead or not is_instance_valid(mission) or bool(mission.get("paused")) or int(mission.get("stage")) >= 3:
		return false
	health -= 1
	if health <= 0:
		dead = true
		collision_layer = 0
		collision_mask = 0
		velocity = Vector3.ZERO
		set_physics_process(false)
		core_material.emission_enabled = false
		core_material.albedo_color = Color(0.12, 0.065, 0.025)
		# Leave an inert, noncolliding corpse. Bound tween obeys true scene pause.
		var fall: Tween = create_tween().set_parallel(true)
		fall.tween_property(model, "rotation:z", _avoid_side * 1.3, 0.3)
		fall.tween_property(model, "position:y", -0.12, 0.3)
		died.emit(self)
	return true

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(mission) or bool(mission.get("paused")) or int(mission.get("stage")) >= 3:
		return
	var target: CharacterBody3D = mission.get("player") as CharacterBody3D
	if not is_instance_valid(target):
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	patrol_time += delta
	_avoid_left = maxf(0.0, _avoid_left - delta)
	var difference: Vector3 = target.global_position - global_position
	var horizontal: Vector3 = Vector3(difference.x, 0, difference.z)
	var visible: bool = has_player_los()
	var chase: bool = horizontal.length() <= DETECTION_RADIUS and visible
	var goal: Vector3 = target.global_position if chase else patrol_origin + Vector3(sin(patrol_time * 0.32) * 2.2, 0, cos(patrol_time * 0.32) * 2.2)
	var desired: Vector3 = goal - global_position
	desired.y = 0.0
	var direction: Vector3 = _steer(desired.normalized()) if desired.length() > 0.25 else Vector3.ZERO
	var speed: float = 2.15 if chase else 0.85
	if can_attack_player():
		speed = 0.0
		if attack_cooldown <= 0.0:
			attack_cooldown = ATTACK_INTERVAL
			mission.call("damage_player", ATTACK_DAMAGE)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	move_and_slide()
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), minf(1.0, delta * 7.0))
	var moving: float = Vector2(velocity.x, velocity.z).length()
	gait_time += delta * moving * 6.0
	for index: int in range(legs.size()):
		var phase: float = gait_time + (PI if (index % 3 + (1 if index >= 3 else 0)) % 2 == 0 else 0.0)
		legs[index].rotation.y = sin(phase) * 0.25 * minf(1.0, moving)
		legs[index].rotation.z = maxf(0.0, cos(phase)) * 0.22 * (1.0 if index < 3 else -1.0) * minf(1.0, moving)
	model.position.y = sin(gait_time * 2.0) * 0.015 * minf(1.0, moving)

func has_player_los() -> bool:
	if not is_instance_valid(mission):
		return false
	var target: CharacterBody3D = mission.get("player") as CharacterBody3D
	if not is_instance_valid(target):
		return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.55, 0), target.global_position + Vector3(0, 0.85, 0), 1 | 2, [get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.get("collider") == target

func can_attack_player() -> bool:
	if dead or not is_instance_valid(mission):
		return false
	var target: CharacterBody3D = mission.get("player") as CharacterBody3D
	if not is_instance_valid(target):
		return false
	var offset: Vector3 = target.global_position - global_position
	return absf(offset.y) <= 1.0 and Vector2(offset.x, offset.z).length() <= ATTACK_RADIUS and has_player_los()

func _clearance(direction: Vector3) -> float:
	var length: float = 1.5
	var side: Vector3 = Vector3(-direction.z, 0, direction.x) * 0.38
	for offset: Vector3 in [Vector3.ZERO, side, -side]:
		var origin: Vector3 = global_position + Vector3(0, 0.44, 0) + offset
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.5, 1 | 4, [get_rid()])
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			length = minf(length, origin.distance_to(hit["position"]))
	return length

func _steer(desired: Vector3) -> Vector3:
	if desired == Vector3.ZERO:
		return desired
	if _clearance(desired) >= 1.3:
		return desired
	var best: Vector3 = Vector3.ZERO
	var best_score: float = -INF
	for angle: float in [0.65, -0.65, 1.15, -1.15, 1.65, -1.65, 2.3, -2.3, PI]:
		var candidate: Vector3 = desired.rotated(Vector3.UP, angle)
		var distance: float = _clearance(candidate)
		if distance < 0.55:
			continue
		var score: float = distance + candidate.dot(desired) * 0.35
		if signf(angle) == _avoid_side:
			score += 0.2
		if score > best_score:
			best_score = score
			best = candidate
			if _avoid_left <= 0.0:
				_avoid_side = signf(angle)
	if _avoid_left <= 0.0:
		_avoid_left = 0.35
	return best
