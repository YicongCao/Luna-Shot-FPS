extends CharacterBody3D
signal shot(hit: bool, distance: float)
const CAPACITY := 20
const HIP := Vector3(0.22, -0.235, -0.40)
const ADS := Vector3(0, -0.178, -0.38)
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera
@onready var weapon: Node3D = $WeaponLayer/Container/Viewport/Weapon
@onready var weapon_camera: Camera3D = $WeaponLayer/Container/Viewport/Camera
var ammo: int = CAPACITY
var reload_left: float = 0
var cooldown: float = 0
var recoil: float = 0
var aiming: bool = false
var blocked: bool = false
var qa_mode: bool = false
var qa_direction := Vector3.ZERO
var qa_jump := false
var last_hit: Dictionary = {}
var steps: float = 0
var spawn_position := Vector3.ZERO

func _ready() -> void:
	var lighting := WorldEnvironment.new()
	lighting.name = "WeaponEnvironment"
	lighting.environment = load("res://scripts/weapon_lighting.gd").environment()
	$WeaponLayer/Container/Viewport.add_child(lighting)

func _unhandled_input(event: InputEvent) -> void:
	if qa_mode or blocked: return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= event.relative.x * 0.002
		head.rotation.x = clampf(head.rotation.x - event.relative.y * 0.002, -1.48, 1.48)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event.is_action_pressed("reload"): reload_weapon()

func _physics_process(delta: float) -> void:
	if blocked: return
	cooldown = maxf(0, cooldown - delta)
	if reload_left > 0:
		reload_left = maxf(0, reload_left - delta)
		if reload_left == 0: ammo = CAPACITY
	var direction := qa_direction
	var jump := qa_jump
	if not qa_mode:
		var controls := Input.get_vector("left", "right", "forward", "back")
		direction = transform.basis * Vector3(controls.x, 0, controls.y)
		jump = Input.is_action_just_pressed("jump")
		aiming = Input.is_action_pressed("aim") and reload_left == 0
		if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: fire()
	var speed := 3.3 if aiming else (8.0 if Input.is_action_pressed("sprint") else 5.0)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if not is_on_floor(): velocity.y -= 18.0 * delta
	elif jump: velocity.y = 5.2
	else: velocity.y = 0
	move_and_slide()
	if position.y < -5: reset_position()

func _process(delta: float) -> void:
	if is_instance_valid(weapon.field_kit): weapon.field_kit.set_ammo(ammo, CAPACITY)
	if blocked: return
	recoil = move_toward(recoil, 0, delta * .25)
	var target := ADS if aiming and reload_left == 0 else HIP
	weapon.position = weapon.position.lerp(target, 1 - exp(-18 * delta))
	weapon.position.z += recoil * delta * 25
	weapon.rotation.x = -recoil * 1.3
	var cell: Node3D = weapon.get_node("P07_Cell")
	cell.position.y = 0.0 - (sin((1.0 - reload_left / 1.5) * PI) * .22 if reload_left > 0 else 0)
	weapon.rotation.z = sin((1.0 - reload_left / 1.5) * PI) * -.18 if reload_left > 0 else 0
	camera.fov = lerpf(camera.fov, 52.0 if aiming else 72.0, 1 - exp(-14 * delta))
	weapon_camera.fov = lerpf(weapon_camera.fov, 52.0 if aiming else 62.0, 1 - exp(-14 * delta))

func fire() -> bool:
	if blocked or cooldown > 0 or reload_left > 0 or ammo <= 0: return false
	ammo -= 1
	cooldown = 0.16
	recoil = .035
	var origin := camera.global_position
	var end := origin - camera.global_basis.z * 100
	var query := PhysicsRayQueryParameters3D.create(origin, end, 5, [get_rid()])
	last_hit = get_world_3d().direct_space_state.intersect_ray(query)
	# Prevent a camera-over-cover ray shooting through an obstacle at muzzle height.
	var hit := false
	var distance := 0.0
	if not last_hit.is_empty():
		var muzzle_world := camera.global_transform * Vector3(0.18, -0.19, -0.55)
		var obstruction := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, muzzle_world, 1, [get_rid()]))
		if obstruction.is_empty():
			obstruction = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(muzzle_world, last_hit.position, 1, [get_rid()]))
		if not obstruction.is_empty() and origin.distance_to(obstruction.position) + .08 < origin.distance_to(last_hit.position):
			last_hit = obstruction
		distance = origin.distance_to(last_hit.position)
		if last_hit.collider.has_method("register_hit"):
			hit = last_hit.collider.register_hit()
	shot.emit(hit, distance)
	return true

func reload_weapon() -> void:
	if ammo < CAPACITY and reload_left == 0:
		reload_left = 1.5
		aiming = false

func reset_position() -> void:
	position = spawn_position
	rotation = Vector3.ZERO
	head.rotation = Vector3.ZERO
	velocity = Vector3.ZERO
