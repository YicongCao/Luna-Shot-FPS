extends SceneTree
# Native full reel plus real keyboard-event replay/play/pause transitions.
var output: String = "res://docs/validation/quarantine-benchmark-v1"
var checks: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("CONTROL CHECK ",id," ",ok)
func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	event=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=false
	Input.parse_input_event(event)
func run() -> void:
	if not OS.get_environment("QUARANTINE_BENCHMARK_QA_ROOT").is_empty():
		output=OS.get_environment("QUARANTINE_BENCHMARK_QA_ROOT")
	var scene: Node = load("res://scenes/quarantine_benchmark.tscn").instantiate()
	root.add_child(scene)
	current_scene=scene
	await frames(5)
	var world: Node3D = scene.mission.get_node("World")
	check("no_visible_world_Label3D",world.find_children("*","Label3D",true,false).all(func(n):return not n.is_visible_in_tree()))
	var start: int = Time.get_ticks_msec()
	while not scene.finished and Time.get_ticks_msec()-start<75000: await process_frame
	check("full_reel_finishes",scene.finished)
	check("all_reel_checks_pass",scene.checks.size()==12 and scene.checks.all(func(c):return c.ok))
	check("pixel_resolution_not_logical_canvas",scene.report.get("resolution")==str(root.size))
	await frames(5)
	var identity: int=scene.get_instance_id()
	key(KEY_R)
	await frames(30)
	check("R_reloads_benchmark",current_scene!=null and current_scene.get_instance_id()!=identity and current_scene.get_script()==load("res://scripts/quarantine/benchmark.gd"))
	check("replay_unpauses_scene",not paused and current_scene.elapsed<3)
	# The full reel was validated above; this only opens the second menu to test ENTER.
	# Redirect this abbreviated test result so it cannot overwrite the full-reel evidence.
	current_scene.output=output+"/menu-test"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(current_scene.output))
	current_scene.finish()
	await frames(5)
	key(KEY_ENTER)
	await frames(60)
	check("ENTER_loads_normal_playable_mission",current_scene.get_script()==load("res://scripts/quarantine/mission.gd"))
	check("play_has_normal_input_and_health",not current_scene.qa_mode and not current_scene.player.qa_mode and current_scene.health==100)
	var before: Vector3 = current_scene.player.position
	Input.action_press("forward")
	for i in 20: await physics_frame
	Input.action_release("forward")
	check("play_accepts_actual_movement_input",current_scene.player.position.distance_to(before)>.5)
	key(KEY_ESCAPE)
	await frames(3)
	check("normal_mission_ESC_pauses",paused)
	key(KEY_ESCAPE)
	await frames(3)
	check("normal_mission_ESC_resumes",not paused)
	var file: FileAccess=FileAccess.open(output+"/controls.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"boundary":"Full live reel, then actual R/ENTER/ESC events. Second result screen invoked directly only for menu transition test."},"\t"))
	file.close()
	current_scene.queue_free()
	await frames(15)
	quit(0 if checks.all(func(c):return c.ok) else 1)
