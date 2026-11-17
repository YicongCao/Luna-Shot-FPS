extends Control
# Existing imagegen optical kernels; visibility is established by world collision.
var world: Node3D
var mission: Node
var streak: Texture2D = preload("res://assets/lighting/streak.png")
var halo: Texture2D = preload("res://assets/lighting/halo.png")
var sources: Array[Dictionary] = []
var clock: float = 0
var flare_enabled: bool = true
var cinema: bool = false
var film: ShaderMaterial

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var additive: ShaderMaterial = ShaderMaterial.new()
	additive.shader = load("res://assets/lighting/flare.gdshader")
	material = additive
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var rect: ColorRect = ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film = ShaderMaterial.new()
	film.shader = load("res://assets/quarantine/film.gdshader")
	rect.material = film
	layer.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(delta: float) -> void:
	clock -= delta
	if clock <= 0:
		clock = .10
		sample_sources()
	queue_redraw()

func sample_sources() -> void:
	sources.clear()
	if not is_instance_valid(mission) or not is_instance_valid(mission.player): return
	var player: Node = mission.player
	var camera: Camera3D = player.camera
	var candidates: Array[Dictionary] = []
	candidates.append({"position":camera.global_position+world.sun.global_basis.z*250,"color":Color(1,.65,.31),"sun":true})
	for emitter in world.emitters:
		if camera.global_position.distance_squared_to(emitter.position)<900:
			candidates.append({"position":emitter.position,"color":emitter.color,"sun":false})
	for source in candidates:
		var p: Vector3 = source.position
		if camera.is_position_behind(p): continue
		var pixel: Vector2 = camera.unproject_position(p)
		var uv: Vector2 = pixel / get_viewport_rect().size
		if uv.x < .02 or uv.x > .98 or uv.y < .04 or uv.y > .96: continue
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position,p,1,[player.get_rid()])
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var strength: float = minf(minf(uv.x,1-uv.x),minf(uv.y,1-uv.y))*3.0
		strength *= .32 if source.sun else minf(.22,2.0/camera.global_position.distance_to(p))
		if player.aiming: strength *= .25
		sources.append({"pixel":pixel,"color":source.color,"strength":strength,"sun":source.sun})
		if sources.size() >= 4: break

func _draw() -> void:
	if not flare_enabled: return
	for source in sources:
		var p: Vector2 = source.pixel
		var extent: Vector2 = Vector2(size.x*(.78 if source.sun else .34),size.y*.024)
		draw_texture_rect(streak,Rect2(p-extent*.5,extent),false,Color(source.color,source.strength))
		var diameter: float = size.y*(.23 if source.sun else .08)
		draw_texture_rect(halo,Rect2(p-Vector2.ONE*diameter*.5,Vector2.ONE*diameter),false,Color(source.color,source.strength*.35))

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F7: world.set_bloom(not world.environment.glow_enabled)
		KEY_F8: flare_enabled = not flare_enabled
		KEY_F10:
			cinema = not cinema
			film.set_shader_parameter("cinema",1.0 if cinema else 0.0)
