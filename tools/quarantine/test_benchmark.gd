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
	var luminaire: Node3D=world.get_node_or_null("InspectionLuminaire")
	var expect_service: bool=OS.get_environment("QUARANTINE_SERVICE_LIGHT")!="off"
	var mounted_light: bool=not expect_service and luminaire==null
	if expect_service and luminaire!=null:
		var spot: SpotLight3D=luminaire.get_node("InspectionSpot")
		mounted_light=luminaire.has_node("Housing") and luminaire.has_node("Diffuser") and spot.shadow_enabled and spot.light_volumetric_fog_energy==0 and luminaire.position.is_equal_approx(Vector3(-3,10.5,0))
	check("inspection_light_has_fixed_physical_source",mounted_light)
	var start: int = Time.get_ticks_msec()
	var saw_closeup: bool=false
	var focus_valid: bool=true
	var gameplay_clear: bool=true
	var original_attributes: CameraAttributes=scene.cinema_lens.original
	while not scene.finished and Time.get_ticks_msec()-start<75000:
		await process_frame
		if scene.chapter==3:
			saw_closeup=true
			var expected: CameraAttributes=scene.cinema_lens.attributes if scene.cinema_lens.enabled else original_attributes
			focus_valid=focus_valid and scene.player.camera.attributes==expected and scene.cinema_lens.focus_distance>1 and scene.cinema_lens.focus_distance<5
		else:
			gameplay_clear=gameplay_clear and scene.player.camera.attributes==original_attributes
	check("closeup_lens_sampled_during_live_reel",saw_closeup)
	check("native_focus_tracks_closeup_subject",focus_valid)
	check("non_closeup_cameras_keep_original_attributes",gameplay_clear)
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
	check("play_restores_original_camera_attributes",current_scene.player.camera.attributes==original_attributes)
	check("normal_play_uses_same_inspection_fixture",current_scene.has_node("World/InspectionLuminaire")==expect_service)
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
