extends Node3D
## Ice-station mission: recovery is mandatory; every fight and the freight are optional.
const Layout = preload("res://scripts/polar/layout.gd")
const Lighting = preload("res://scripts/polar/lighting.gd")
const Land = preload("res://scripts/polar/terrain.gd")
const Habitat = preload("res://scripts/polar/habitat.gd")
const Site = preload("res://scripts/polar/site.gd")
const Freight = preload("res://scripts/polar/freight.gd")
const Ship = preload("res://scripts/polar/ship.gd")
const Operator = preload("res://scripts/polar/operator.gd")
const Threats = preload("res://scripts/polar/threats.gd")
const Sound = preload("res://scripts/polar/suit_audio.gd")
const Hud = preload("res://scripts/polar/hud.gd")
const SEAL_TIME := 3.7

enum Phase { ACTIVE, SEALING, COMPLETE, FAILED }
var phase := Phase.ACTIVE
var environment: Environment
var player: Operator
var site: Site
var freight: Freight
var ship: Ship
var threats: Threats
var audio: Sound
var hud: Hud
var paused := false
var health := 100
var has_record := false
var supply_used := false
var closing := 0.0
var use_down := false
var use_time := 0.0
var use_key := ""
var action: Dictionary = {}
var qa := false
var last_threat := Vector3.ZERO
var cue_window := 0.0
var hit_window := 0.0

func _ready() -> void:
	qa = "--polar-qa" in OS.get_cmdline_user_args()
	Operator.configure_input()
	environment = Lighting.build(self)
	var terrain := Node3D.new()
	terrain.name = "PolarBasin"
	add_child(terrain)
	Land.new().build(terrain)
	site = Site.new()
	site.name = "IceWorks"
	add_child(site)
	var habitation := Node3D.new()
	habitation.name = "Habitation"
	add_child(habitation)
	Habitat.build(habitation)
	freight = Freight.new()
	freight.name = "Freight"
	add_child(freight)
	ship = Ship.new()
	ship.name = "Lander"
	ship.position = Layout.SHIP
	add_child(ship)
	player = Operator.new()
	player.name = "Operator"
	player.allow_qa_controls = qa
	add_child(player)
	player.pulse.connect(_pulse)
	player.fell.connect(func(amount: int) -> void: _hurt(amount,player.position+Vector3.FORWARD))
	threats = Threats.new()
	threats.player = player
	add_child(threats)
	threats.suit_hit.connect(_hurt)
	threats.cue.connect(_cue)
	audio = Sound.new()
	add_child(audio)
	var ui := CanvasLayer.new()
	ui.layer = 5
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	hud.resume_requested.connect(_pause.bind(false))
	hud.restart_requested.connect(restart)
	hud.quit_requested.connect(get_tree().quit)
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
		RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
	restart()

func restart() -> void:
	freight.reset()
	threats.reset()
	ship.seal(0.0)
	phase = Phase.ACTIVE
	paused = false
	has_record = false
	supply_used = false
	site.record_cartridge.show()
	health = 100
	closing = 0.0
	cue_window = 0.0
	hit_window = 0.0
	use_down = Input.is_action_pressed("polar_interact")
	use_key = ""
	use_time = 0.0
	action.clear()
	player.reset_at(Layout.SPAWN)
	player.look_toward(Vector3(-11.5,1.05,39.6))
	player.weapon_layer.show()
	threats.set_physics_process(true)
	audio.muted = false
	_set_mouse(true)
	hud.menu("")
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset") and not event.is_echo():
		restart()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause") and not event.is_echo() and phase == Phase.ACTIVE:
		_pause(not paused)
		get_viewport().set_input_as_handled()

func _set_mouse(locked: bool) -> void:
	if not qa: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if locked else Input.MOUSE_MODE_VISIBLE

func _pause(value: bool) -> void:
	paused = value
	player.blocked = paused
	threats.set_physics_process(not paused)
	audio.muted = paused
	use_key = ""
	use_down = Input.is_action_pressed("polar_interact")
	use_time = 0.0
	_set_mouse(not paused)
	hud.menu("pause" if paused else "")

func _physics_process(delta: float) -> void:
	if paused: return
	if phase == Phase.ACTIVE:
		if player.position.y < -37.0 or maxf(absf(player.position.x),absf(player.position.z)) > 108.0:
			_hurt(100,player.position)
			return
		freight.tick(delta)
		player.pressured = Habitat.pressurized(player.position+Vector3.UP*1.1)
		cue_window = maxf(0.0,cue_window-delta)
		hit_window = maxf(0.0,hit_window-delta)
		action = action_at_gaze()
		_interaction(delta)
	elif phase == Phase.SEALING:
		closing += delta
		ship.seal(closing/2.32)
		player.pressured = ship.closure > .97
		if closing >= SEAL_TIME:
			phase = Phase.COMPLETE
			player.pressured = false
			player.blocked = true
			_set_mouse(false)
			hud.menu("complete")
	audio.tick(delta,player.pressured)
	_update_hud()

func action_at_gaze() -> Dictionary:
	var choices: Array[Dictionary] = []
	if not has_record:
		choices.append(_choice("record","取回记录匣",Layout.RECORD+Vector3(0,.035,.12),2.58))
	else:
		if freight.cargo == Freight.Cargo.AVAILABLE:
			for side in [-1.0,1.0]:
				choices.append(_choice("ice","调运冰芯",Layout.CORE+Vector3(0,-.078,.80*side),2.55,.65))
		if freight.on_lift(player.position) and freight.can_call(freight.dock+1 if freight.dock < 2 else 0):
			var label := ["升至中层","升至着陆坪","降至坑底"][freight.dock] as String
			choices.append(_choice("lift",label,freight.lift.global_position+Freight.HANDLE,2.62))
		for index in Freight.CALL.size():
			if freight.can_call(index):
				var point: Vector3 = Freight.CALL[index]
				choices.append(_choice("call%d"%index,"召唤货梯",point,2.35))
		if freight.can_store():
			choices.append(_choice("store","将冰芯装船",Freight.RECEIVER,2.50,.65))
		if ship.is_inside(player.position+Vector3.UP*1.1) and freight.cargo != Freight.Cargo.TO_SHIP:
			var label := "封舱撤离" if freight.cargo == Freight.Cargo.STOWED else "仅携记录匣撤离"
			choices.append(_choice("extract",label,Layout.EXTRACT,2.55,.75))
	if not supply_used and (health < 100 or player.reserve < 18 or player.rounds < Operator.MAGAZINE):
		choices.append(_choice("supply","补给",Layout.SUPPLY,2.12))
	var eye := player.camera.global_position
	var forward := -player.camera.global_basis.z
	var best := 1000.0
	var context := {}
	for candidate in choices:
		var target: Vector3 = candidate.point
		var offset := target-eye
		var gap := offset.length()
		if gap > float(candidate.radius) or gap < .07: continue
		var alignment := forward.dot(offset/gap)
		if alignment < .815: continue
		var ray := PhysicsRayQueryParameters3D.create(eye,target,1,[player.get_rid()])
		ray.hit_from_inside = true
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		var score := (1.0-alignment)*3.0+gap*.095
		if score < best:
			best = score
			context = candidate
	return context

func _choice(key: String, label: String, point: Vector3, radius: float, duration: float = 0.0) -> Dictionary:
	return {"key":key,"label":label,"point":point,"radius":radius,"duration":duration}

func _interaction(delta: float) -> void:
	var down := Input.is_action_pressed("polar_interact")
	if not down:
		use_down = false
		use_key = ""
		use_time = 0.0
		return
	if not use_down:
		use_down = true
		use_key = action.get("key","")
	if use_key.is_empty() or use_key != action.get("key",""):
		use_key = ""
		use_time = 0.0
		return
	use_time += delta
	if use_time >= float(action.duration):
		_perform(use_key)
		use_time = 0.0
		use_key = ""
		action.clear()

func _perform(key: String) -> void:
	match key:
		"record":
			has_record = true
			site.record_cartridge.hide()
			freight.set_unlocked(true)
			audio.emit_cue("confirmed")
		"ice":
			if freight.receive_core(): audio.emit_cue("lift")
		"lift":
			if freight.advance(): audio.emit_cue("lift")
		"store":
			if freight.store_core(): audio.emit_cue("confirmed")
		"call0", "call1", "call2":
			if freight.call_dock(int(key.right(1))): audio.emit_cue("lift",.8)
		"supply":
			supply_used = true
			health = mini(100,health+38)
			player.reserve = mini(36,player.reserve+14)
			audio.emit_cue("confirmed")
		"extract":
			phase = Phase.SEALING
			player.flight_locked = true
			player.velocity = Vector3.ZERO
			player.weapon_layer.hide()
			threats.set_physics_process(false)
			audio.emit_cue("seal",1.0)

func _pressure_connected(at: Vector3) -> bool:
	# A short contact-borne cue only on the floor connected to the active machine.
	var p := player.position
	if absf(p.y-Layout.PIT) < .16:
		return absf(p.x) < 13.45 and p.z > -33.8 and p.z < 32.0 and at.y < Layout.MID-.5
	if absf(p.y-Layout.MID) < .16:
		return p.x < -2.5 and p.x > -24.0 and absf(p.z-Layout.SHAFT_Z) < 1.75 and at.y > Layout.MID-.5
	return false

func _cue(kind: String, at: Vector3) -> void:
	if paused or phase != Phase.ACTIVE: return
	var distance := player.camera.global_position.distance_to(at)
	# The lower pressure vestibule is bolted to the service deck; the track can
	# weakly excite that shell. No air propagation in the exposed excavation.
	var hab_resonance := kind == "rail_roll" and distance < 27.0 and player.pressured and player.position.z < -14.0 and at.z < -18.0
	if hab_resonance:
		audio.emit_cue(kind,.45*(1.0-distance/30.0))
		return
	if distance > 14.0: return
	var air := player.pressured and Habitat.pressurized(at)
	var contact := player.is_on_floor() and _pressure_connected(at)
	if not air and not contact: return
	audio.emit_cue(kind,1.0-distance/17.5,not air)
	if kind in ["rail_charge","sampler_warn"]:
		last_threat = at
		cue_window = .7

func _hurt(amount: int, at: Vector3) -> void:
	if phase != Phase.ACTIVE or paused: return
	health = maxi(0,health-amount)
	last_threat = at
	cue_window = .62
	audio.emit_cue("impact")
	if health != 0: return
	phase = Phase.FAILED
	threats.set_physics_process(false)
	player.blocked = true
	_set_mouse(false)
	_update_hud()
	hud.menu("failed")

func _pulse(hit: bool, _at: Vector3) -> void:
	audio.emit_cue("pulse",.85,not player.pressured)
	if hit: hit_window = .15

func _update_hud() -> void:
	hud.health = health
	hud.aim = player.aiming
	hud.record = has_record
	hud.objective = "返回着陆坪撤离" if has_record else "取回坑底记录匣"
	hud.cargo_state = freight.cargo
	hud.action_text = action.get("label", "") if phase == Phase.ACTIVE else ""
	hud.hold = use_time/maxf(.02,float(action.get("duration",0.0)))
	hud.reloading = player.reload_time > 0
	hud.reserve = player.reserve
	hud.sealed = phase == Phase.SEALING
	hud.tag = hit_window
	hud.signal_age = cue_window
	if cue_window > 0:
		var d := player.to_local(last_threat)
		hud.signal_dir = atan2(d.x,-d.z)
	hud.queue_redraw()
