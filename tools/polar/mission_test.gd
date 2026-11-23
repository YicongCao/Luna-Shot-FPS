extends SceneTree
## Fixed 60 Hz, no native viewport. Place feet only at named fixture boundaries.
## Route progress, damage, freight, and extraction must come from the live scene and InputMap.

const Level = preload("res://scenes/polar_extraction.tscn")
const Mission = preload("res://scripts/polar/mission.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const Operator = preload("res://scripts/polar/operator.gd")
const Freight = preload("res://scripts/polar/freight.gd")
const Crawler = preload("res://scripts/polar/threat_crawler.gd")
const Sampler = preload("res://scripts/polar/threat_sampler.gd")
const HZ := 60
const MAX_TICKS := 30000
const RECORD_FEET := Vector3(5.30, Layout.PIT + .028, -28.10)
const RECORD_POINT := Layout.RECORD + Vector3(0, .035, .12)
const CORE_FEET := Vector3(1.20, Layout.PIT, -18.53)
const CORE_POINT := Layout.CORE + Vector3(0, -.078, -.80)
const CABIN_FEET := Vector3(Layout.SHIP.x, 1.08, 55.10)
const CRAWLER_FEET := Vector3(4, Layout.PIT + .028, -20)
const SAMPLER_FEET := Vector3(-3.75, Layout.MID + .028, Layout.SHAFT_Z)
const ACTIONS := [&"forward", &"back", &"left", &"right", &"sprint", &"jump", &"polar_interact", &"fire", &"reload", &"reset"]

var game: Mission
var player: Operator
var frame := 0
var checks := 0
var failures := 0
var cues: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var tracking := false
var cargo_history: Array[int] = []
var crate_before := Vector3.ZERO
var max_crate_step := 0.0
var crate_clearance := PhysicsShapeQueryParameters3D.new()
var crate_collision: CollisionShape3D
var freight_obstruction := ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() != "headless" or "--polar-qa" not in OS.get_cmdline_user_args() or Engine.physics_ticks_per_second != HZ:
		_check("headless 60 Hz with --polar-qa", false)
		quit(1)
		return
	physics_frame.connect(_sample)
	game = Level.instantiate()
	root.add_child(game)
	player = game.player
	game.threats.cue.connect(func(kind: String, _at: Vector3) -> void: cues.append({"kind": kind, "frame": frame}))
	game.threats.suit_hit.connect(func(amount: int, _at: Vector3) -> void: hits.append({"amount": amount, "frame": frame}))
	await _spawn_and_locks()
	await _habitat()
	await _steps()
	await _record_only()
	await _freight_route(false)
	await _freight_route(true)
	await _crawler_timing_and_supply()
	await _covered_fire()
	await _sampler()
	await _sampler_cover()
	await _failure_and_reset()
	_release_inputs()
	print("POLAR_TOTAL ", checks, " checks, ", failures, " failed; ", frame, " physics ticks")
	quit(int(failures > 0))


func _check(description: String, passed: bool, detail: String = "") -> void:
	checks += 1
	print("POLAR_CHECK ", description, " ", passed)
	if not passed:
		failures += 1
		print("POLAR_DETAIL ", description, ": ", detail, " | feet=", player.position if is_instance_valid(player) else Vector3.ZERO, " frame=", frame)


func _scenario(name: String, setup: String) -> void:
	print("POLAR_SCENARIO ", name, " | ", setup)


func _sample() -> void:
	frame += 1
	if frame == MAX_TICKS:
		_check("suite finishes inside the global physics budget", false)
		quit(1)
		return
	if not tracking:
		return
	var freight := game.freight
	var at := freight.crate.global_position
	max_crate_step = maxf(max_crate_step, at.distance_to(crate_before))
	crate_before = at
	if cargo_history.is_empty() or cargo_history.back() != freight.cargo:
		cargo_history.append(freight.cargo)
	if freight.cargo == Freight.Cargo.TO_SHIP and freight_obstruction.is_empty() and crate_collision != null:
		crate_clearance.transform = crate_collision.global_transform
		var overlaps := player.get_world_3d().direct_space_state.intersect_shape(crate_clearance, 1)
		if not overlaps.is_empty():
			var blocker := overlaps[0].collider as Node3D
			freight_obstruction = "crate at %s overlaps %s at %s" % [at, blocker.get_path(), blocker.global_position]


func _frames(count: int) -> void:
	for tick in count:
		await physics_frame


func _until(predicate: Callable, budget: int) -> bool:
	for tick in budget:
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _release_inputs() -> void:
	for action: StringName in ACTIONS:
		Input.action_release(action)


func _restart() -> void:
	tracking = false
	_release_inputs()
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F5
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(1)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(1)
	cues.clear()
	hits.clear()


func _place(feet: Vector3, settle: int = 12) -> void:
	player.global_position = feet
	player.velocity = Vector3.ZERO
	await _frames(settle)


func _look(point: Vector3) -> void:
	player.look_toward(point)
	await _frames(2)


func _hold(key: StringName, ticks: int) -> void:
	Input.action_press(key)
	await _frames(ticks)
	Input.action_release(key)
	await _frames(2)


func _key() -> String:
	return game.action.get("key", "")


func _use(key: String, point: Vector3, ticks: int = 2) -> bool:
	await _look(point)
	var found := _key() == key
	if not found:
		print("POLAR_DETAIL expected action ", key, " at ", point, " from feet ", player.position,
			" (found '", _key(), "'; blocking ray: ", _ray_label(player.camera.global_position, point, 1), ")")
	await _hold(&"polar_interact", ticks)
	return found


func _distance_xz(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _walk(target: Vector3, budget: int = 800) -> bool:
	var start := player.position
	var best := _distance_xz(start, target)
	var stale := 0
	Input.action_press(&"forward")
	for tick in budget:
		var distance := _distance_xz(player.position, target)
		if distance < .20 or game.phase != Mission.Phase.ACTIVE or stale >= 65:
			break
		if distance < best - .025:
			best = distance
			stale = 0
		else:
			stale += 1
		player.look_toward(Vector3(target.x, player.camera.global_position.y, target.z))
		await physics_frame
	Input.action_release(&"forward")
	await _frames(11)
	var ok := _distance_xz(player.position, target) < .55 and absf(player.position.y - target.y) < .27 and player.is_on_floor()
	if not ok:
		print("POLAR_DETAIL walk from ", start, " to ", target, " stopped at ", player.position,
			" floor=", player.is_on_floor(), " velocity=", player.velocity, " contact=", _slide_label())
	return ok


func _slide_label() -> String:
	var names := PackedStringArray()
	for index in player.get_slide_collision_count():
		var body := player.get_slide_collision(index).get_collider() as Node
		if body != null and str(body.get_path()) not in names:
			names.append(str(body.get_path()))
	return ", ".join(names)


func _ray(a: Vector3, b: Vector3, mask: int) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, mask, [player.get_rid()])
	query.hit_from_inside = true
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _clear_and_near(point: Vector3, radius: float) -> bool:
	var eye := player.camera.global_position
	var offset := point - eye
	return offset.length() < radius and -player.camera.global_basis.z.dot(offset.normalized()) > .96 and _ray(eye, point, 1).is_empty()


func _ray_label(a: Vector3, b: Vector3, mask: int) -> String:
	var hit := _ray(a, b, mask)
	if hit.is_empty():
		return "none"
	var body := hit.collider as Node3D
	return "%s @ %s (body %s)" % [body.get_path(), hit.position, body.global_position]


func _block(label: String, at: Vector3, size: Vector3, layer: int = 1) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = layer
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	game.add_child(body)
	return body


func _cue_frames(kind: String) -> Array[int]:
	var times: Array[int] = []
	for event in cues:
		if event.kind == kind:
			times.append(event.frame)
	return times


func _spawn_and_locks() -> void:
	_scenario("spawn and pre-record interlocks", "natural spawn; independent pit-lift, mid call, and lander anchor fixtures")
	await _frames(45)
	var spawn := player.position
	await _frames(60)
	_check("spawn settles upright and stationary on the rim", player.is_on_floor() and spawn.distance_to(player.position) < .015
		and _distance_xz(spawn, Layout.SPAWN) < .04 and absf(spawn.y - Layout.RIM) < .06 and not player.pressured)
	_check("spawn starts a clean locked mission", game.phase == Mission.Phase.ACTIVE and game.health == 100 and not game.has_record
		and player.rounds == Operator.MAGAZINE and player.reserve == 18 and not game.freight.unlocked and game.ship.closure == 0.0)
	await _place(Vector3(-1, Layout.PIT + .03, Layout.SHAFT_Z))
	var handle := game.freight.lift.global_position + Freight.HANDLE
	await _look(handle)
	await _hold(&"polar_interact", 50)
	_check("pit lift refuses E before the record", game.freight.on_lift(player.position) and player.is_on_floor()
		and _clear_and_near(handle, 2.62) and game.freight.goal == -1 and game.freight.lift_departures == 0 and _key() != "lift")
	await _place(Vector3(-5.0, Layout.MID + .03, 38.60))
	await _look(Freight.CALL[1])
	await _hold(&"polar_interact", 50)
	_check("mid call refuses E before the record", _clear_and_near(Freight.CALL[1], 2.35) and _key() != "call1"
		and game.freight.dock == 0 and game.freight.goal == -1 and game.freight.lift_departures == 0)
	await _place(CABIN_FEET)
	await _look(Layout.EXTRACT)
	await _hold(&"polar_interact", 53)
	_check("cabin console refuses a complete E hold before the record", game.ship.is_inside(player.position + Vector3.UP * 1.1)
		and _clear_and_near(Layout.EXTRACT, 2.55) and _key() != "extract" and game.phase == Mission.Phase.ACTIVE and game.ship.closure == 0.0)
	var eye := player.camera.global_position
	var through_glass := _ray(eye, Vector3(Layout.SHIP.x, eye.y, 49), 1)
	_check("ship windshield blocks a level line of sight", through_glass.get("collider") != null
		and absf(float(through_glass.position.z) - (Layout.SHIP.z - 7.10)) < .15,
		_ray_label(eye, Vector3(Layout.SHIP.x, eye.y, 49), 1))
	await _safe_sweep("lander cabin")


func _habitat() -> void:
	_scenario("habitat and pad bypass", "F5 to natural spawn; continuous WASD across the pad, down both habitat inclines, and through the mid bypass")
	await _restart()
	await _frames(18)
	# Cross behind the rear ramp, not diagonally through the parked lander.
	var pad := await _walk(Vector3(player.position.x, 0, 68.35))
	pad = (await _walk(Vector3(-19.30, 0, 68.35))) and pad
	pad = (await _walk(Vector3(-27, 0, 52.10))) and pad
	_check("landing pad reaches habitat vestibule without lift power", pad and game.freight.lift_departures == 0)
	var upper := await _walk(Vector3(-27, 0, 44.25))
	upper = (await _walk(Vector3(-27, Layout.MID, 27.05))) and upper
	_check("capsule descends upper habitat grade into pressure", upper and player.pressured)
	var dock := await _walk(Vector3(-22.03, Layout.MID, 27.02))
	var vacuum := not player.pressured
	dock = (await _walk(Vector3(-22.03, Layout.MID, 37.47))) and dock
	dock = (await _walk(Vector3(-3.66, Layout.MID, 37.47))) and dock
	_check("mid bypass walks from habitat door to shaft at deck height", dock and vacuum and game.freight.dock == 0)
	var returned := await _walk(Vector3(-22.03, Layout.MID, 37.47))
	returned = (await _walk(Vector3(-22.03, Layout.MID, 27.02))) and returned
	returned = (await _walk(Vector3(-27, Layout.MID, 24.00))) and returned
	_check("mid bypass connects back into the pressurized room", returned and player.pressured)
	if not returned:
		# Isolate the glazing and lower grade even if the bypass route is broken.
		_scenario("habitat fallback", "fixture at the supply room, only after a reported upper/bypass failure")
		await _place(Vector3(-27, Layout.MID + .03, 23.70))
	else:
		await _walk(Vector3(-27, Layout.MID, 23.70))
	var eye := player.camera.global_position
	var glass_hit := _ray(eye, eye + Vector3.RIGHT * 5, 1).get("collider") as Node
	player.look_toward(eye + Vector3.FORWARD * 5)
	await _hold(&"right", 78)
	_check("habitat glazing stops the side-strafing capsule and ray", glass_hit != null and glass_hit.name == &"HabitatGlazing"
		and player.position.x > -24.70 and player.position.x < -24.21 and player.is_on_floor() and player.pressured,
		"ray collider %s; slide %s" % [glass_hit, _slide_label()])
	await _safe_sweep("pressurized habitat cabin")
	var lower := await _walk(Vector3(-27, Layout.MID, 17.36))
	lower = (await _walk(Vector3(-21, Layout.PIT, -10.42))) and lower
	_check("capsule descends lower habitat grade into pressurized pit hall", lower and player.pressured)
	lower = (await _walk(Vector3(-21, Layout.PIT, -25.34))) and lower
	_check("capsule exits lower airlock onto pit deck", lower and not player.pressured)


func _steps() -> void:
	_scenario("exterior step", "F5 then one fixture on right landing apron; same continuous downhill and uphill jump pair")
	await _restart()
	await _place(Vector3(Layout.STEP_X, .03, 51.55))
	var top := await _walk(Vector3(Layout.STEP_X, 0, 46.28))
	_check("landing pad connects to exterior descent's top ledge", top)
	var down := await _jump_step(-1, 7, Layout.STEPS[1])
	_check("low-gravity jump lands down the 2.85 m exterior step", down.landed and down.rise > 3.0,
		"jump %s" % [down])
	_check("airborne capsule retains takeoff momentum after W release", down.velocity > 2.3 and down.drift > .74 and down.airborne,
		"jump %s" % [down])
	if not down.landed:
		_scenario("uphill fallback", "fixture on second ledge, only after a reported downhill failure")
		await _place(Vector3(Layout.STEP_X, Layout.STEPS[1].y + .03, 37.20))
	var approach := await _walk(Vector3(Layout.STEP_X, Layout.STEPS[1].y, 37.32))
	var up := await _jump_step(1, 12, Layout.STEPS[0])
	_check("same gap returns uphill by a 2.85 m jump", approach and up.landed and up.rise > 3.0 and up.airborne,
		"jump %s" % [up])


func _jump_step(direction: int, lead: int, landing: Vector2) -> Dictionary:
	var start := player.position
	var eye := player.camera.global_position
	player.look_toward(eye + Vector3.BACK * direction * 5.0)
	Input.action_press(&"forward")
	await _frames(lead)
	var launch := player.position
	Input.action_press(&"jump")
	await _frames(3)
	Input.action_release(&"jump")
	Input.action_release(&"forward")
	var before_drift := player.position
	await _frames(15)
	var drift := (player.position.z - before_drift.z) * direction
	var speed := player.velocity.z * direction
	var airborne := not player.is_on_floor()
	var crest := player.position.y
	for tick in 200:
		if player.is_on_floor():
			break
		await physics_frame
		crest = maxf(crest, player.position.y)
	var landed := player.is_on_floor() and absf(player.position.y - landing.y) < .14 and absf(player.position.z - landing.x) < 3.11
	return {"start": start, "launch": launch, "landed": landed, "rise": crest - launch.y, "drift": drift,
		"velocity": speed, "airborne": airborne, "end": player.position}


func _recover_record(strict: bool) -> bool:
	if strict:
		await _look(RECORD_POINT)
		_check("record rejected beyond the 2.58 m range", player.camera.global_position.distance_to(RECORD_POINT) > 2.58 and _key() != "record")
		var closed := await _walk(RECORD_FEET)
		_check("record approach enters the alcove on foot", closed)
		await _look(player.camera.global_position + Vector3.BACK * 5)
		Input.action_press(&"polar_interact")
		await _frames(5)
		var away := _key() != "record" and not game.has_record
		await _look(RECORD_POINT)
		await _frames(6)
		_check("record needs gaze when E is pressed, not while stale-held", away and _key() == "record" and not game.has_record)
		Input.action_release(&"polar_interact")
		await _frames(2)
		var cover := _block("QARecordCover", player.camera.global_position.lerp(RECORD_POINT, .53), Vector3(.80, .55, .13))
		await _frames(3)
		await _hold(&"polar_interact", 4)
		_check("record interaction respects solid line-of-sight occlusion", _key() != "record" and not game.has_record)
		cover.queue_free()
		await _frames(3)
	var offered := await _use("record", RECORD_POINT)
	return offered and game.has_record and game.freight.unlocked and not game.site.record_cartridge.visible


func _to_pit_lift(with_core: bool) -> bool:
	var walked := await _walk(Vector3(5.30, Layout.PIT, CORE_FEET.z))
	if with_core:
		walked = (await _walk(CORE_FEET)) and walked
	if not walked:
		return false
	if with_core:
		await _look(CORE_POINT)
		var crate := game.freight.crate
		var core_ray := _ray(player.camera.global_position, CORE_POINT + Vector3.BACK * .17, 1)
		_check("ice core is a physical layer-1 crate with a reachable control", core_ray.get("collider") == crate and _key() == "ice")
		await _hold(&"polar_interact", 23)
		var partial := game.freight.cargo == Freight.Cargo.AVAILABLE and game.freight.cargo_departures == 0
		await _hold(&"polar_interact", 24)
		_check("releasing E clears both partial 0.65 s ice holds", partial and game.freight.cargo == Freight.Cargo.AVAILABLE)
		var offered := await _use("ice", CORE_POINT, 42)
		_check("full 0.65 s ice hold starts exactly one transfer", offered and game.freight.cargo == Freight.Cargo.TO_LIFT
			and game.freight.cargo_departures == 1 and game.freight.crate == crate)
	walked = await _walk(Vector3(-1.1, Layout.PIT, CORE_FEET.z))
	walked = (await _walk(Vector3(-1.1, Layout.PIT, 33.65))) and walked
	walked = (await _walk(Vector3(-1.1, Layout.PIT, Layout.SHAFT_Z))) and walked
	return walked and game.freight.on_lift(player.position)


func _ride(dock: int, label: String) -> bool:
	var freight := game.freight
	var initial_feet := player.position
	var initial_lift := freight.lift.position.y
	var initial_crate := freight.crate.position
	var prior_departures := freight.lift_departures
	var aboard := freight.on_lift(initial_feet) and player.is_on_floor()
	var offered := await _use("lift", freight.lift.global_position + Freight.HANDLE)
	var departed := freight.goal == dock and freight.lift_departures == prior_departures + 1
	var last_height := freight.lift.position.y
	var max_step := 0.0
	var carry_gap := 0.0
	for tick in 300:
		if freight.goal == -1:
			break
		await physics_frame
		var y := freight.lift.position.y
		max_step = maxf(max_step, absf(y - last_height))
		last_height = y
		carry_gap = maxf(carry_gap, absf((player.position.y - y) - (initial_feet.y - initial_lift)))
		aboard = aboard and player.is_on_floor() and freight.on_lift(player.position)
	await _frames(8)
	var reached := freight.dock == dock and freight.goal == -1 and absf(freight.lift.position.y - Layout.DOCKS[dock]) < .035
	var carried := aboard and _distance_xz(player.position, initial_feet) < .15 and carry_gap < .15 and max_step > .02 and max_step < .065
	_check(label + " hoist physically carries the grounded player", offered and departed and reached and carried,
		"dock=%d goal=%d deck_y=%.3f carry_gap=%.3f max_step=%.3f on_floor=%s departed=%s" % [freight.dock, freight.goal,
		freight.lift.position.y, carry_gap, max_step, aboard, departed])
	if freight.cargo == Freight.Cargo.ON_LIFT:
		_check(label + " same crate rides with the deck", reached and freight.crate.get_parent() == freight.lift
			and freight.crate.position.distance_to(initial_crate) < .025 and absf(freight.crate.global_position.y - Layout.DOCKS[dock]) < .035)
	return reached and freight.on_lift(player.position) and player.is_on_floor()


func _ship_walk(west: bool, strict: bool = false) -> bool:
	var side := -19.20 if west else -4.80
	var outside := await _walk(Vector3(side, 0, 65.98))
	outside = (await _walk(Vector3(Layout.SHIP.x, 0, 65.98))) and outside
	await _look(Layout.EXTRACT)
	_check("lander console is not offered outside the ramp", _key() != "extract"
		and not game.ship.is_inside(player.position + Vector3.UP * 1.1))
	if strict:
		var rear_cabin := await _walk(Vector3(Layout.SHIP.x, 1.05, 59.10))
		await _look(Layout.EXTRACT)
		await _hold(&"polar_interact", 48)
		var eye := player.camera.global_position
		_check("extract refuses E inside the cabin but beyond its 2.55 m range", rear_cabin
			and game.ship.is_inside(player.position + Vector3.UP * 1.1) and eye.distance_to(Layout.EXTRACT) > 2.55
			and _ray(eye, Layout.EXTRACT, 1).is_empty() and _key() != "extract" and game.phase == Mission.Phase.ACTIVE)
	var cabin := await _walk(Vector3(Layout.SHIP.x, 1.05, 55.10))
	return outside and cabin and game.ship.is_inside(player.position + Vector3.UP * 1.1)


func _extract(strict: bool, expected_cargo: Freight.Cargo, label: String) -> void:
	var start := player.position
	await _look(Layout.EXTRACT)
	var correct_prompt := _key() == "extract" and float(game.action.get("duration", -1)) == .75
	if strict:
		var eye := player.camera.global_position
		var cover := _block("QAExtractCover", eye.lerp(Layout.EXTRACT, .53), Vector3(.78, .60, .11))
		await _frames(3)
		await _hold(&"polar_interact", 48)
		_check("extract refuses a full hold through a layer-1 occluder", correct_prompt and _ray(eye, Layout.EXTRACT, 1).get("collider") == cover
			and _key() != "extract" and game.phase == Mission.Phase.ACTIVE and game.ship.closure == 0.0)
		cover.queue_free()
		await _frames(3)
		await _hold(&"polar_interact", 31)
		var partial := game.phase == Mission.Phase.ACTIVE and game.ship.closure == 0.0
		Input.action_press(&"polar_interact")
		await _frames(23)
		partial = partial and game.phase == Mission.Phase.ACTIVE and game.use_time > .30
		await _look(player.camera.global_position + Vector3.BACK * 5)
		var lost := _key() != "extract" and game.use_time == 0.0
		await _look(Layout.EXTRACT)
		await _frames(49)
		_check("extract rejects short and interrupted 0.75 s holds", correct_prompt and partial and lost
			and game.phase == Mission.Phase.ACTIVE and game.use_time == 0.0)
		Input.action_release(&"polar_interact")
		await _frames(2)
	var offered := await _use("extract", Layout.EXTRACT, 47)
	var sealing := game.phase == Mission.Phase.SEALING and player.flight_locked and not player.weapon_layer.visible
	await _hold(&"back", 52)
	var locked := start.distance_to(player.position) < .06
	var done := await _until(func() -> bool: return game.phase == Mission.Phase.COMPLETE, 235)
	_check(label + " seals and completes physically inside the lander", offered and sealing and done and locked and game.has_record
		and game.ship.is_inside(player.position + Vector3.UP * 1.1) and game.ship.closure == 1.0 and player.blocked
		and game.freight.cargo == expected_cargo and player.shot_count == 0,
		"prompt=%s seal=%s done=%s lock=%s cargo=%d health=%d" % [offered, sealing, done, locked, game.freight.cargo, game.health])


func _record_only() -> void:
	_scenario("record-only success", "F5 then fixture at the alcove approach; no relocation from record through ship")
	await _restart()
	await _place(Vector3(5.3, Layout.PIT + .03, -26.91))
	var recovered := await _recover_record(true)
	_check("record pickup hides the cartridge and unlocks freight", recovered)
	var boarded := await _to_pit_lift(false)
	_check("empty lift boards on foot from the pit", boarded)
	var mid := await _ride(1, "record-only pit to mid")
	var top := await _ride(2, "record-only mid to rim")
	var pad := await _walk(Vector3(-1.1, 0, 45.44))
	_check("rim dock opens a walkable pad exit", mid and top and pad and not game.freight.on_lift(player.position))
	var cabin := await _ship_walk(false, true)
	_check("record-only operator boards the ship by its ramp", boarded and cabin)
	await _extract(true, Freight.Cargo.AVAILABLE, "record-only")


func _freight_route(abandon: bool) -> void:
	var label := "abandoned freight" if abandon else "full freight"
	_scenario(label, "F5 then fixture at record alcove; no relocation from record through ship")
	var was_stowed := game.phase == Mission.Phase.COMPLETE and game.freight.cargo == Freight.Cargo.STOWED
	await _restart()
	if abandon:
		_check("F5 from completed freight returns the physical crate to its source", was_stowed and game.phase == Mission.Phase.ACTIVE
			and game.freight.cargo == Freight.Cargo.AVAILABLE and game.freight.crate.get_parent() == game.freight
			and game.freight.crate.position.distance_to(game.freight.context_core_floor()) < .035 and not game.has_record
			and game.site.record_cartridge.visible and game.ship.closure == 0.0)
	await _place(RECORD_FEET)
	var recovered := await _recover_record(false)
	_check(label + " recovers the required record", recovered)
	var f := game.freight
	var crate := f.crate
	crate_collision = null
	for child in crate.get_children():
		if child is CollisionShape3D:
			crate_collision = child
			break
	if crate_collision != null:
		crate_clearance.shape = crate_collision.shape
		crate_clearance.exclude = [crate.get_rid()]
		crate_clearance.collision_mask = 1
	freight_obstruction = ""
	tracking = true
	cargo_history.clear()
	crate_before = crate.global_position
	max_crate_step = 0.0
	var boarded := await _to_pit_lift(true)
	_check(label + " loads the same crate onto the pit deck and walks aboard", boarded and f.cargo == Freight.Cargo.ON_LIFT
		and f.crate == crate and crate.get_parent() == f.lift and absf(crate.global_position.z - (Layout.SHAFT_Z + .70)) < .035)
	var mid := await _ride(1, label + " pit to mid")
	if abandon:
		var path := await _walk(Vector3(-22.03, Layout.MID, Layout.SHAFT_Z))
		path = (await _walk(Vector3(-22.03, Layout.MID, 27.02))) and path
		path = (await _walk(Vector3(-27.0, Layout.MID, 27.02))) and path
		path = (await _walk(Vector3(-27.0, 0, 52.72))) and path
		_check("can abandon the crate at mid and climb through habitat", mid and path and f.dock == 1
			and not f.on_lift(player.position) and crate.get_parent() == f.lift and f.cargo == Freight.Cargo.ON_LIFT)
	else:
		var lip := await _walk(Vector3(-2.12, Layout.MID, Layout.SHAFT_Z))
		_check("mid lift can stand near sampler without stepping onto bypass", mid and lip and f.on_lift(player.position))
		await _safe_sweep("mid lift")
		var top := await _ride(2, label + " mid to rim")
		var pad := await _walk(Vector3(-2.12, 0, 46.65))
		pad = (await _walk(Vector3(2.67, 0, 46.65))) and pad
		_check("operator disembarks while ice remains on the top lift", top and pad and not f.on_lift(player.position)
			and f.cargo == Freight.Cargo.ON_LIFT and crate.get_parent() == f.lift)
		var offered := await _use("store", Freight.RECEIVER, 42)
		_check("receiver hold starts the physical ship transfer", offered and f.cargo == Freight.Cargo.TO_SHIP
			and crate.get_parent() == f and crate.global_position.distance_to(Freight.CRADLE) > 5)
	var cabin := await _ship_walk(abandon)
	_check(label + " operator boards by the physical ship ramp", cabin)
	var target := Freight.Cargo.ON_LIFT if abandon else Freight.Cargo.STOWED
	var ready := await _until(func() -> bool: return f.cargo == target, 460)
	var expected := [Freight.Cargo.AVAILABLE, Freight.Cargo.TO_LIFT, Freight.Cargo.ON_LIFT]
	if not abandon:
		expected.append_array([Freight.Cargo.TO_SHIP, Freight.Cargo.STOWED])
	var crate_at := Vector3(Layout.CORE.x, Layout.MID, Layout.SHAFT_Z + .70) if abandon else Freight.CRADLE
	_check(label + " crate completes its expected continuous path", ready and f.crate == crate and cargo_history == expected
		and max_crate_step > .055 and max_crate_step < .135 and crate.global_position.distance_to(crate_at) < .045,
		"history=%s max_step=%.4f actual=%s expected=%s" % [cargo_history, max_crate_step, crate.global_position, crate_at])
	if not abandon:
		_check("ship transfer carries the solid crate clear of architecture", ready and crate_collision != null and freight_obstruction.is_empty(), freight_obstruction)
		_check("operator and stowed crate are separated by the pressure cell", cabin and ready
			and not game.ship.is_inside(crate.global_position + Vector3.UP * 1.1) and crate.get_parent() == f)
	tracking = false
	await _extract(false, target, label)


func _safe_sweep(label: String) -> void:
	var sampler := game.threats.sampler
	var health := game.health
	var prior_hits := hits.size()
	# Start before the next full sweep, not part-way through the current one.
	var clear := await _until(func() -> bool: return sampler.phase != Sampler.Phase.SWEEP, 145)
	var sweep := await _until(func() -> bool: return sampler.phase == Sampler.Phase.SWEEP, 455)
	var complete := await _until(func() -> bool: return sampler.phase == Sampler.Phase.SAFE, 145)
	_check("sampler cannot damage operator in " + label + " through a full sweep", clear and sweep and complete
		and game.health == health and hits.size() == prior_hits and player.is_on_floor(),
		"sampler=%d at %.2f health=%d (was %d) hits=%d" % [sampler.phase, sampler.phase_time, game.health, health, hits.size() - prior_hits])


func _crawler_timing_and_supply() -> void:
	_scenario("crawler timing and resupply", "F5 then pit fixture; after real damage, separate habitat supply fixture preserving health and ammo")
	await _restart()
	await _place(CRAWLER_FEET, 10)
	var crawler := game.threats.crawler
	var charging := await _until(func() -> bool: return crawler.phase == Crawler.Phase.CHARGE, 20)
	var starts := _cue_frames("rail_charge")
	var start: int = starts[0] if not starts.is_empty() else frame
	await _frames(maxi(0, start + 88 - frame))
	_check("crawler telegraphs without premature damage", charging and starts.size() == 1 and crawler.phase == Crawler.Phase.CHARGE
		and game.health == 100 and _cue_frames("rail_fire").is_empty())
	var fired := await _until(func() -> bool: return not _cue_frames("rail_fire").is_empty(), 16)
	var shots := _cue_frames("rail_fire")
	var delay := shots[0] - start if not shots.is_empty() else -1
	_check("unobstructed locked crawler charge fires once after 1.55 s", fired and abs(delay - 93) <= 1
		and game.health == 100 - Crawler.DAMAGE and hits.size() == 1 and crawler.phase == Crawler.Phase.RECOVER,
		"delay=%d health=%d phases=%d hits=%s cue=%s" % [delay, game.health, crawler.phase, hits, cues])
	await _shot(crawler.global_position)
	await _hold(&"reload", 79)
	await _place(Vector3(-27.23, Layout.MID + .03, 22.05))
	var health := game.health
	var reserve := player.reserve
	var used := await _use("supply", Layout.SUPPLY)
	_check("damaged suit can resupply with health cap and reserve bonus", used and health < 100 and game.health == mini(100, health + 38)
		and player.rounds == Operator.MAGAZINE and reserve < 18 and player.reserve == mini(36, reserve + 14) and game.supply_used)
	await _shot(player.camera.global_position + Vector3.UP * 10)
	await _hold(&"reload", 79)
	reserve = player.reserve
	await _look(Layout.SUPPLY)
	await _hold(&"polar_interact", 45)
	_check("habitat supply cannot be reused after consuming more ammo", _key() != "supply" and player.reserve == reserve and game.supply_used)


func _shot(target: Vector3) -> void:
	await _look(target)
	await _hold(&"fire", 2)
	await _frames(12)


func _covered_fire() -> void:
	_scenario("crawler LOS and layered weapon", "F5 then pit fixture with removable static QA occluders")
	await _restart()
	var crawler := game.threats.crawler
	var cover_at := Vector3(2.5, -14.5, -20.75)
	var cover_size := Vector3(.32, 1.45, 3.40)
	var cover := _block("QACrawlerCover", cover_at, cover_size)
	await _place(CRAWLER_FEET, 20)
	var ray := _ray(player.camera.global_position, crawler.global_position, 5)
	await _shot(crawler.global_position)
	_check("architecture blocks gun ray and prevents crawler charge", ray.get("collider") == cover and crawler.health == 3
		and player.shot_count == 1 and player.accepted_hits == 0 and _cue_frames("rail_charge").is_empty(),
		"cover at %s ray=%s crawler_z=%.3f" % [cover_at, _ray_label(player.camera.global_position, crawler.global_position, 5), crawler.position.z])
	cover.queue_free()
	var charge := await _until(func() -> bool: return crawler.phase == Crawler.Phase.CHARGE, 20)
	await _frames(45)
	var locked := crawler.phase == Crawler.Phase.CHARGE and crawler.phase_time > .63
	cover = _block("QALateCrawlerCover", cover_at, cover_size)
	await _frames(2)
	var eye := player.camera.global_position
	var blocked: bool = _ray(crawler.emitter_position(), eye, 1).get("collider") == cover
	var canceled := await _until(func() -> bool: return crawler.phase == Crawler.Phase.RECOVER, 10)
	await _frames(65)
	_check("late loss of crawler line of sight cancels an already locked charge", charge and locked and blocked and canceled
		and _cue_frames("rail_fire").is_empty() and hits.is_empty() and game.health == 100,
		"blocker at %s blocked=%s phase=%d cues=%s" % [cover_at, blocked, crawler.phase, cues])
	cover.queue_free()
	_scenario("muzzle and target layers", "F5 at the same pit anchor; test boxes do not drive the live targets")
	await _restart()
	await _place(CRAWLER_FEET, 8)
	# The normal charge pauses the rail carriage, so setup and shot use the same aim line.
	await _look(crawler.global_position)
	eye = player.camera.global_position
	var muzzle := player.muzzle_world()
	var muzzle_at := muzzle + muzzle.direction_to(crawler.global_position) * .24
	var muzzle_cover := _block("QAMuzzleCover", muzzle_at, Vector3.ONE * .135)
	await _frames(3)
	var aimed_target: bool = _ray(eye, crawler.global_position, 5).get("collider") == crawler
	var muzzle_blocked: bool = _ray(muzzle, crawler.global_position, 5).get("collider") == muzzle_cover
	await _shot(crawler.global_position)
	_check("muzzle-side obstacle blocks shot despite a clear crosshair", aimed_target and muzzle_blocked
		and crawler.health == 3 and player.shot_count == 1 and player.accepted_hits == 0,
		"muzzle=%s blocker=%s crosshair=%s muzzle_blocked=%s health=%d" % [muzzle, muzzle_at, aimed_target, muzzle_blocked, crawler.health])
	muzzle_cover.queue_free()
	await _frames(3)
	var irrelevant := _block("QANonTargetLayer", player.camera.global_position.lerp(crawler.global_position, .45), Vector3.ONE * .7, 8)
	await _frames(3)
	var ignore: bool = (_ray(player.camera.global_position, crawler.global_position, 8).get("collider") == irrelevant
		and _ray(player.camera.global_position, crawler.global_position, 5).get("collider") == crawler)
	for i in 3:
		await _shot(crawler.global_position)
	_check("pulse ignores wrong layer and disables crawler in three accepted shots", ignore and crawler.collision_layer == 4
		and crawler.health == 0 and crawler.phase == Crawler.Phase.DISABLED and player.accepted_hits == 3
		and player.shot_count == 4 and player.rounds == Operator.MAGAZINE - 4,
		"ignore=%s accepted=%d health=%d shots=%d rounds=%d" % [ignore, player.accepted_hits, crawler.health, player.shot_count, player.rounds])
	irrelevant.queue_free()
	await _shot(crawler.global_position)
	_check("disabled crawler no longer accepts hits", player.shot_count == 5 and player.accepted_hits == 3 and crawler.health == 0)


func _sampler() -> void:
	_scenario("sampler timing and weak point", "F5 then one fixed mid-sweep buffer anchor; no threat ticks injected")
	await _restart()
	var reset_frame := frame
	await _place(SAMPLER_FEET, 8)
	var sampler := game.threats.sampler
	await _frames(303)
	var safe := sampler.phase == Sampler.Phase.SAFE and hits.is_empty() and game.health == 100
	var warned := await _until(func() -> bool: return sampler.phase == Sampler.Phase.WARN, 25)
	var warns := _cue_frames("sampler_warn")
	var warn_at := warns[0] if not warns.is_empty() else frame
	_check("sampler stays safe for 5.4 s before issuing warning", safe and warned and warns.size() == 1
		and absi(warn_at - reset_frame - 324) <= 3 and game.health == 100,
		"warning=%d from reset=%d phase=%d" % [warn_at, reset_frame, sampler.phase])
	await _frames(98)
	var before := sampler.phase == Sampler.Phase.WARN and hits.is_empty() and game.health == 100
	var sweeping := await _until(func() -> bool: return sampler.phase == Sampler.Phase.SWEEP, 12)
	var sweep_times := _cue_frames("sampler_sweep")
	var sweep_at := sweep_times[0] if not sweep_times.is_empty() else frame
	_check("sampler provides 1.75 s of nondamaging warning before sweep", before and sweeping and sweep_times.size() == 1
		and absi(sweep_at - warn_at - 105) <= 1 and game.health == 100,
		"warn at %d sweep at %d hits %s" % [warn_at, sweep_at, hits])
	var contact := await _until(func() -> bool: return game.health < 100, 133)
	var during := sampler.phase == Sampler.Phase.SWEEP and sampler.phase_time > 0.0
	var ended := await _until(func() -> bool: return sampler.phase == Sampler.Phase.SAFE, 140)
	var elapsed := frame - sweep_at - 1
	await _frames(105)
	_check("only the live 2.25 s sampler sweep hurts, once per pass", contact and during and ended and absi(elapsed - 135) <= 1
		and hits.size() == 1 and game.health == 100 - Sampler.DAMAGE,
		"elapsed=%d damage=%d phase=%d hits=%s tip=%s" % [elapsed, 100 - game.health, sampler.phase, hits, sampler.tip_position()])
	var target: bool = _ray(player.camera.global_position, sampler.drive_position(), 5).get("collider") == sampler
	for i in 4:
		await _shot(sampler.drive_position())
	_check("sampler's layer-4 drive disables in four accepted shots", target and sampler.collision_layer == 4
		and sampler.health == 0 and sampler.phase == Sampler.Phase.DISABLED and player.shot_count == 4 and player.accepted_hits == 4,
		"drive %s accepted=%d health=%d" % [sampler.drive_position(), player.accepted_hits, sampler.health])


func _sampler_cover() -> void:
	_scenario("sampler LOS", "F5 then one bypass fixture; add a narrow solid barrier between passes without moving the operator")
	await _restart()
	await _place(Vector3(-3.17, Layout.MID + .028, Layout.SHAFT_Z))
	var sampler := game.threats.sampler
	var exposed := await _until(func() -> bool: return game.health < 100, 567)
	var at := player.position
	var cover := _block("QASamplerCover", Vector3(-3.54, Layout.MID + 1.14, Layout.SHAFT_Z), Vector3(.055, 1.31, 1.50))
	var ended := await _until(func() -> bool: return sampler.phase == Sampler.Phase.SAFE, 145)
	var health := game.health
	var swept := await _until(func() -> bool: return sampler.phase == Sampler.Phase.SWEEP, 436)
	var blocked := false
	for tick in 141:
		if sampler.phase != Sampler.Phase.SWEEP:
			break
		var tip := sampler.tip_position()
		var torso := player.position + Vector3.UP * 1.04
		if _distance_xz(tip, torso) < .60 and absf(tip.y - torso.y) < .62 and _ray(tip, torso, 1).get("collider") == cover:
			blocked = true
		await physics_frame
	_check("sampler cannot strike through world cover at the same reachable feet", exposed and ended and swept and blocked
		and sampler.phase == Sampler.Phase.SAFE and game.health == health and hits.size() == 1 and player.position.distance_to(at) < .02,
		"prior contact=%s intervening ray=%s health=%d hits=%s cover=%s" % [exposed, blocked, game.health, hits, cover.position])
	cover.queue_free()


func _failure_and_reset() -> void:
	_scenario("failure and reset", "F5 then outer playable boundary anchor; WASD past boundary, then actual F5")
	await _restart()
	var floor_hit := _ray(Vector3(0, 85, 107.36), Vector3(0, -38, 107.36), 1)
	var floor_y := float(floor_hit.get("position", Vector3(0, 1, 0)).y)
	await _place(Vector3(0, floor_y + .035, 107.36))
	var active := game.phase == Mission.Phase.ACTIVE
	await _look(player.camera.global_position + Vector3.BACK * 5)
	await _hold(&"forward", 70)
	_check("leaving playable bounds by movement enters FAILED and blocks operator", active and not floor_hit.is_empty()
		and player.position.z > 108 and game.phase == Mission.Phase.FAILED and game.health == 0 and player.blocked
		and not game.threats.is_physics_processing())
	var failed_at := player.position
	await _hold(&"forward", 18)
	_check("failed operator cannot continue moving", player.position.distance_to(failed_at) < .02)
	await _restart()
	await _frames(25)
	_check("F5 restores spawn, input, record, freight, hatch, ammo, and threats", game.phase == Mission.Phase.ACTIVE
		and player.position.distance_to(Layout.SPAWN) < .07 and player.is_on_floor() and game.health == 100 and not player.blocked
		and not player.flight_locked and player.weapon_layer.visible and not game.has_record and game.site.record_cartridge.visible
		and not game.supply_used and game.freight.cargo == Freight.Cargo.AVAILABLE and not game.freight.unlocked and game.freight.dock == 0
		and game.freight.goal == -1 and game.freight.crate.get_parent() == game.freight
		and game.freight.crate.position.distance_to(game.freight.context_core_floor()) < .035 and game.ship.closure == 0
		and player.rounds == Operator.MAGAZINE and player.reserve == 18 and game.threats.is_physics_processing()
		and game.threats.crawler.health == 3 and game.threats.sampler.health == 4 and game.threats.sampler.phase == Sampler.Phase.SAFE)
	var start := player.position
	await _hold(&"forward", 24)
	_check("WASD movement resumes after F5", _distance_xz(start, player.position) > 1 and game.phase == Mission.Phase.ACTIVE)
