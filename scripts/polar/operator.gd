extends CharacterBody3D
## New slice has independent suit movement and a parametric pulse tool.
const Kit = preload("res://scripts/polar/kit.gd")
const Tool = preload("res://scripts/polar/pulse_tool.gd")
const MAGAZINE := 12
const HIP := Vector3(.274,-.296,-.437)
const ADS := Vector3(0,-.151,-.387)
const GRAVITY := 4.8
const IMPULSE := 5.91
signal pulse(hit: bool, position: Vector3)
signal fell(amount: int)

var camera: Camera3D
var head: Node3D
var view: Camera3D
var tool: Node3D
var weapon_layer: CanvasLayer
var rounds := MAGAZINE
var reserve := 18
var cooldown := 0.0
var reload_time := 0.0
var aiming := false
var blocked := false
var flight_locked := false
var pressured := false
var allow_qa_controls := false
var rim_recoil := 0.0
var foot_distance := 0.0
var jump_buffer := 0.0
var coyote := 0.0
var visual_traces: Dictionary = {}
var shot_count := 0
var accepted_hits := 0
var tracer_material := Kit.glow(Color(.45,.78,.99),3.15)
var flash_material := Kit.glow(Color(.70,.86,1.0),3.35)

static func configure_input() -> void:
	var keys := {"forward":KEY_W,"back":KEY_S,"left":KEY_A,"right":KEY_D,"sprint":KEY_SHIFT,"jump":KEY_SPACE,
		"reload":KEY_R,"polar_interact":KEY_E,"pause":KEY_ESCAPE,"reset":KEY_F5}
	for action: String in keys:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var binding := InputEventKey.new()
		binding.physical_keycode = keys[action]
		InputMap.action_add_event(action,binding)
	for action in ["fire","aim"]:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var binding := InputEventMouseButton.new()
		binding.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action,binding)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = .24
	floor_max_angle = deg_to_rad(43)
	floor_constant_speed = true
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.height = 1.74
	shape.radius = .315
	collider.shape = shape
	collider.position.y = .87
	add_child(collider)
	head = Node3D.new()
	head.name = "Head"
	head.position.y = 1.62
	add_child(head)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = .045
	camera.far = 1950.0
	camera.fov = 71.0
	camera.current = true
	head.add_child(camera)
	_build_tool()

func _build_tool() -> void:
	weapon_layer = CanvasLayer.new()
	weapon_layer.layer = 1
	add_child(weapon_layer)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	weapon_layer.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sub := SubViewport.new()
	sub.transparent_bg = true
	sub.own_world_3d = true
	sub.msaa_3d = Viewport.MSAA_2X
	container.add_child(sub)
	view = Camera3D.new()
	view.fov = 63.0
	view.near = .018
	view.far = 5.0
	view.current = true
	sub.add_child(view)
	var stage := WorldEnvironment.new()
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.58,.67,.74)
	env.ambient_light_energy = .52
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	stage.environment = env
	sub.add_child(stage)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-44,38,0)
	key.light_color = Color(.94,.97,1)
	key.light_energy = 1.09
	sub.add_child(key)
	var bounce := DirectionalLight3D.new()
	bounce.rotation_degrees = Vector3(14,-122,0)
	bounce.light_energy = .57
	bounce.light_color = Color(.72,.84,1)
	sub.add_child(bounce)
	tool = Tool.new()
	tool.scale = Vector3.ONE*.89
	tool.position = HIP
	sub.add_child(tool)

func look_toward(point: Vector3) -> void:
	var aim := camera.global_position.direction_to(point)
	rotation.y = atan2(-aim.x,-aim.z)
	head.rotation.x = asin(clampf(aim.y,-.99,.99))

func _unhandled_input(event: InputEvent) -> void:
	if blocked or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x*.002
		head.rotation.x = clampf(head.rotation.x-event.relative.y*.002,-1.52,1.52)
	if event.is_action_pressed("jump") and not event.is_echo(): jump_buffer = .15

func _physics_process(delta: float) -> void:
	if blocked or flight_locked: return
	cooldown = maxf(0.0,cooldown-delta)
	if reload_time > 0.0:
		reload_time = maxf(0,reload_time-delta)
		if reload_time == 0.0:
			var count := mini(reserve,MAGAZINE-rounds)
			rounds += count
			reserve -= count
			tool.set_charge(rounds)
	if Input.is_action_just_pressed("reload"): reload()
	if Input.is_action_just_pressed("jump"): jump_buffer = .15
	var in_control := allow_qa_controls or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	aiming = in_control and Input.is_action_pressed("aim") and reload_time == 0.0
	if in_control and Input.is_action_pressed("fire"): fire()
	var stick := Input.get_vector("left","right","forward","back") if in_control else Vector2.ZERO
	var grounded := is_on_floor()
	var speed := (3.1 if aiming else (7.0 if Input.is_action_pressed("sprint") else 5.0))
	var goal := transform.basis*Vector3(stick.x,0,stick.y)*speed
	var planar := Vector2(velocity.x,velocity.z)
	# Limited thrust in the air: take-off heading matters. Letting go damps, not stops, drift.
	if grounded:
		planar = planar.move_toward(Vector2(goal.x,goal.z),(27.0 if stick != Vector2.ZERO else 34.0)*delta)
	elif stick != Vector2.ZERO:
		planar = planar.move_toward(Vector2(goal.x,goal.z),2.0*delta)
	else:
		planar = planar.move_toward(Vector2.ZERO,.68*delta)
	velocity.x = planar.x
	velocity.z = planar.y
	jump_buffer = maxf(0.0,jump_buffer-delta)
	coyote = .10 if grounded else maxf(0.0,coyote-delta)
	if jump_buffer > 0.0 and coyote > 0.0:
		jump_buffer = 0.0
		coyote = 0.0
		velocity.y = 4.3 if pressured else IMPULSE
	elif grounded:
		velocity.y = -.05
	else:
		velocity.y -= GRAVITY*delta
	var down_speed := velocity.y
	move_and_slide()
	if is_on_floor():
		foot_distance += planar.length()*delta
		if not grounded and down_speed < -10.1:
			fell.emit(ceili((-down_speed-10.1)*18.0))

func _process(delta: float) -> void:
	# Always release transient nodes even after death or extraction.
	for item: Node3D in visual_traces.keys():
		visual_traces[item] -= delta
		if visual_traces[item] <= 0.0:
			visual_traces.erase(item)
			item.queue_free()
	if blocked: return
	rim_recoil = move_toward(rim_recoil,0.0,delta*.33)
	var hold := ADS if aiming else HIP
	if not aiming:
		hold += Vector3(sin(foot_distance*2.3)*.006,sin(foot_distance*4.6)*.005,0)
	var tilt := 0.0
	if reload_time > 0.0:
		tilt = sin(reload_time/1.25*PI)
		hold += Vector3(.04,-.12,.048)*tilt
	tool.position = tool.position.lerp(hold+Vector3(0,0,rim_recoil*.65),1.0-exp(-17.0*delta))
	tool.rotation = Vector3(-rim_recoil*1.3,0,tilt*-.38)
	camera.fov = lerpf(camera.fov,52.0 if aiming else 71.0,1.0-exp(-12.0*delta))
	view.fov = lerpf(view.fov,52.0 if aiming else 63.0,1.0-exp(-12.0*delta))

func reload() -> void:
	if rounds < MAGAZINE and reserve > 0 and reload_time == 0.0:
		reload_time = 1.25
		aiming = false

func muzzle_world() -> Vector3:
	var uv := view.unproject_position(tool.to_global(tool.muzzle)) / Vector2(view.get_viewport().size)
	var pix := uv*camera.get_viewport().get_visible_rect().size
	return camera.project_position(pix,-tool.to_global(tool.muzzle).z)

func fire() -> bool:
	if blocked or flight_locked or cooldown > 0.0 or reload_time > 0.0: return false
	if rounds == 0:
		reload()
		return false
	rounds -= 1
	shot_count += 1
	tool.set_charge(rounds)
	cooldown = .205
	rim_recoil = .045
	var from := camera.global_position
	var ray_end := from-camera.global_basis.z*72.0
	var muzzle := muzzle_world()
	var space := get_world_3d().direct_space_state
	var aimed := space.intersect_ray(_ray(from,ray_end))
	var occlusion := space.intersect_ray(_ray(from,muzzle))
	var flash := occlusion.is_empty()
	var finish: Vector3 = aimed.get("position",ray_end)
	if flash and muzzle.distance_squared_to(finish) > .0001:
		occlusion = space.intersect_ray(_ray(muzzle,finish+muzzle.direction_to(finish)*.009))
	var contact: Dictionary = aimed if occlusion.is_empty() else occlusion
	finish = contact.get("position",ray_end)
	var hit := false
	if contact.has("collider") and contact.collider.has_method("register_hit"):
		hit = contact.collider.register_hit()
		if hit: accepted_hits += 1
	if flash and muzzle.distance_squared_to(finish) > .0001:
		var beam := Kit.pipe(get_parent(),muzzle,finish,.010,tracer_material,6)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		visual_traces[beam] = .045
	if not contact.is_empty() and contact.normal.length_squared() > .50:
		for i in 4:
			var tilt := Basis(contact.normal,i*TAU/4.0)*Vector3(.14,.06,-.1)
			var start: Vector3 = finish+contact.normal*.024
			var spark := Kit.pipe(get_parent(),start,start+contact.normal*.17+tilt,.013,flash_material,5)
			spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			visual_traces[spark] = .074
	pulse.emit(hit,finish)
	return true

func _ray(a: Vector3, b: Vector3) -> PhysicsRayQueryParameters3D:
	var query := PhysicsRayQueryParameters3D.create(a,b,5,[get_rid()])
	query.hit_from_inside = true
	return query

func reset_at(at: Vector3) -> void:
	position = at
	velocity = Vector3.ZERO
	rounds = MAGAZINE
	reserve = 18
	cooldown = 0.0
	reload_time = 0.0
	jump_buffer = 0.0
	coyote = 0.0
	foot_distance = 0.0
	rim_recoil = 0.0
	shot_count = 0
	accepted_hits = 0
	aiming = false
	pressured = false
	blocked = false
	flight_locked = false
	tool.position = HIP
	tool.set_charge(rounds)
	for node: Node3D in visual_traces.keys(): node.queue_free()
	visual_traces.clear()
