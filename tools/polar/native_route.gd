extends SceneTree
## An uninterrupted record-only route in the actual rendered game. The driver may
## aim and issue keys, but never relocates the capsule or advances mission state.
const Layout = preload("res://scripts/polar/layout.gd")
const Mission = preload("res://scripts/polar/mission.gd")
const Freight = preload("res://scripts/polar/freight.gd")
var game: Mission
var out: String
var start_tick: int

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		quit(1)
		return
	out = OS.get_environment("POLAR_ROUTE_OUTPUT")
	if out.is_empty(): out = ProjectSettings.globalize_path("res://artifacts/polar-route")
	DirAccess.make_dir_recursive_absolute(out)
	game = (load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene).instantiate()
	root.add_child(game)
	await _ticks(20)
	start_tick = Engine.get_physics_frames()
	var went_down := await _walk_route([
		Vector3(-19.3,0,68.35), Vector3(-27,0,52.1), Vector3(-27,0,44.25), Vector3(-27,-8.5,27.08),
		Vector3(-27,-8.5,17.36), Vector3(-21,-17,-10.42), Vector3(-21,-17,-25.34),
		Vector3(-18.2,-17,-23.45),Vector3(-13.25,-17,-23.45), Vector3(4.9,-17,-23.45), Vector3(5.3,-17,-28.10),
	])
	if not went_down: return
	if not await _interact("record",Layout.RECORD+Vector3(0,.035,.12),3): return
	if not game.has_record: _fail("record not recovered"); return
	await _draw("native-record")
	if not await _walk_route([Vector3(5.30,-17,-18.53),Vector3(-1.1,-17,-18.53),Vector3(-1.1,-17,33.65),Vector3(-1.1,-17,37.5)]): return
	for next_dock in [1,2]:
		if not await _interact("lift",game.freight.lift.global_position+Freight.HANDLE,3): return
		for i in 360:
			if game.freight.goal == -1: break
			await physics_frame
		if game.freight.dock != next_dock or not game.freight.on_lift(game.player.position):
			_fail("hoist missed native dock %d" % next_dock)
			return
	await _draw("native-return")
	if not await _walk_route([Vector3(-1.1,0,45.44),Vector3(-4.8,0,65.98),Vector3(Layout.SHIP.x,0,65.98),Vector3(Layout.SHIP.x,1.05,55.1)]): return
	if not await _interact("extract",Layout.EXTRACT,49): return
	if game.phase != Mission.Phase.SEALING: _fail("cabin did not start sealing"); return
	game.player.look_toward(Vector3(-11.4,2.55,43.7))
	await _ticks(160)
	await _draw("native-sealing")
	await _ticks(77)
	if game.phase != Mission.Phase.COMPLETE or game.player.shot_count != 0 or game.freight.cargo != Freight.Cargo.AVAILABLE:
		_fail("record-only completion state mismatch")
		return
	await _draw("native-complete")
	print("POLAR_ROUTE true ticks=",Engine.get_physics_frames()-start_tick," health=",game.health," shots=",game.player.shot_count)
	quit()

func _walk_route(points: Array[Vector3]) -> bool:
	for point in points:
		var ok := await _walk(point)
		if not ok:
			_fail("walk target %s"%[point])
			return false
	return true

func _walk(point: Vector3) -> bool:
	for i in 1000:
		var p := game.player.position
		var gap := Vector2(point.x-p.x,point.z-p.z).length()
		if gap < .15:
			_key(KEY_W,false)
			_key(KEY_SHIFT,false)
			await _ticks(11)
			return absf(game.player.position.y-point.y) < .20 and game.phase == Mission.Phase.ACTIVE
		game.player.look_toward(Vector3(point.x,game.player.camera.global_position.y-.09,point.z))
		# A native window focus change can release physical keys while this driver
		# is still active. Restore its held input, never the player's position.
		if not Input.is_action_pressed("forward"): _key(KEY_W,true)
		var fast := Input.is_action_pressed("sprint")
		if (gap > 5.0) != fast: _key(KEY_SHIFT,not fast)
		await physics_frame
	_key(KEY_W,false)
	_key(KEY_SHIFT,false)
	return false

func _interact(which: String, at: Vector3, duration: int) -> bool:
	game.player.look_toward(at)
	await _ticks(3)
	if game.action.get("key","") != which:
		_fail("no %s interaction at sightline %s" % [which,at])
		return false
	_key(KEY_E,true)
	await _ticks(duration)
	_key(KEY_E,false)
	await _ticks(3)
	return true

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _ticks(count: int) -> void:
	for index in count:
		await physics_frame

func _draw(label: String) -> void:
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(out.path_join(label+".png"))
	if error != OK: push_error("Failed to save native route screenshot: " + label)

func _fail(which: String) -> void:
	push_error("POLAR_ROUTE false "+which+" at "+str(game.player.position))
	quit(1)
