extends SceneTree
## Real Forward+ app entry, native input events and uncapped wall-time sampling.
const Game = preload("res://scripts/polar/mission.gd")
const Lighting = preload("res://scripts/polar/lighting.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const TURN_SAMPLES := 144
var game: Game
var timings := []
var failures := 0
var gpu: String

func _initialize() -> void:
	call_deferred("probe")

func probe() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Native Forward+ required")
		quit(1)
		return
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	gpu = RenderingServer.get_video_adapter_name()
	var started := Time.get_ticks_usec()
	var scene := load(ProjectSettings.get_setting("application/run/main_scene")) as PackedScene
	game = scene.instantiate() as Game
	if not is_instance_valid(game):
		push_error("Project default must be polar extraction")
		quit(1)
		return
	root.add_child(game)
	await RenderingServer.frame_post_draw
	var init_ms := float(Time.get_ticks_usec()-started)/1000.0
	await _draws(32)
	var start := game.player.position
	game.player.look_toward(Vector3(start.x,game.player.camera.global_position.y,42.4))
	_key(KEY_W,true)
	await _ticks(47)
	_key(KEY_W,false)
	_check("WASD from project default",game.player.position.z < start.z-3.0 and game.player.is_on_floor())
	_key(KEY_ESCAPE,true)
	_key(KEY_ESCAPE,false)
	await _ticks(3)
	_check("Escape opens pause panel",game.paused and game.hud.panel.visible and game.player.blocked)
	_key(KEY_ESCAPE,true)
	_key(KEY_ESCAPE,false)
	await _ticks(3)
	_check("Escape resumes same game",not game.paused and not game.player.blocked)
	_key(KEY_F5,true)
	_key(KEY_F5,false)
	await _ticks(3)
	_check("F5 returns to spawn",game.player.position.distance_to(start) < .12 and game.player.rounds == 12)
	await _measure("rim and lander", Vector3(-8.0,1.52,43.0),.32)
	var player := game.player
	var polished := Lighting.polished()
	player.position = Vector3(-2.72,-16.96,-20.87)
	player.velocity = Vector3.ZERO
	var drill_look := Vector3(-3.23,-15.70,-26.55)
	player.look_toward(drill_look)
	game.threats.reset()
	await _draws(32)
	var volume := (game.site.get_node_or_null("DrillExhaust") if polished
		else game.get_node_or_null("SublimationAtDrill")) as FogVolume
	_check("pan starts with the working exhaust in view",is_instance_valid(volume)
		and volume.is_visible_in_tree() and player.camera.is_position_in_frustum(volume.global_position))
	await _measure("working drill and active patrol",drill_look,.30)
	player.position = Vector3(5.31,-16.96,-27.41)
	player.velocity = Vector3.ZERO
	await _measure("record alcove and key light",Layout.RECORD,.23)
	player.position = Vector3(-27.8,-8.45,20.9)
	player.velocity = Vector3.ZERO
	await _measure("habitation glazing and work lights",Vector3(-26.5,-6.8,17.0),.26)
	var report := {"gpu":gpu,"lighting":"enhanced" if polished else "baseline",
		"resolution":[root.size.x,root.size.y],"first_draw_ms":snappedf(init_ms,.01),
		"probes":timings,"probe_failures":failures}
	var dst := OS.get_environment("POLAR_NATIVE_REPORT")
	if not dst.is_empty():
		var file := FileAccess.open(dst,FileAccess.WRITE)
		if file == null:
			push_error("Could not write native probe results")
			failures += 1
		else:
			file.store_string(JSON.stringify(report,"\t")+"\n")
	print("POLAR_NATIVE ",JSON.stringify(report))
	quit(int(failures > 0))

func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _draws(count: int) -> void:
	for index in count:
		await RenderingServer.frame_post_draw

func _ticks(count: int) -> void:
	for index in count:
		await physics_frame

func _check(label: String, ok: bool) -> void:
	if not ok: failures += 1
	print("POLAR_CHECK ",label," ",ok)

func _measure(label: String, target: Vector3, angle: float) -> void:
	game.player.look_toward(target)
	var center := game.player.rotation.y
	await _draws(48)
	var samples: Array[float] = []
	var before := Time.get_ticks_usec()
	for i in (2*TURN_SAMPLES):
		game.player.rotation.y = center + angle*sin(float(i)*TAU/TURN_SAMPLES)
		await RenderingServer.frame_post_draw
		var tick := Time.get_ticks_usec()
		samples.append(float(tick-before)/1000.0)
		before = tick
	var average := float(samples.reduce(func(a: float,b: float) -> float: return a+b,0.0))/samples.size()
	samples.sort()
	var middle := floori(samples.size()*.5)
	var median := (samples[middle-1]+samples[middle])*.5
	var p95 := samples[floori((samples.size()-1)*.95)]
	timings.append({"path":label,"samples":samples.size(),"average_ms":snappedf(average,.01),
		"median_ms":snappedf(median,.01),"p95_ms":snappedf(p95,.01),"average_fps":snappedf(1000.0/average,.1)})
