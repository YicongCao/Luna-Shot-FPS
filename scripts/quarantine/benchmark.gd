extends Node
## Live trailer/benchmark. Staged cameras/enemies; genuine hitscan, E hold and extraction.
## No movie playback, fixed-FPS simulation or shared gameplay/asset modifications.
const CUTS: Array[float] = [0,4,12,19,24,33,39,49]
var mission: Node3D
var player: CharacterBody3D
var elapsed: float = 0
var chapter: int = -1
var samples: Array[float] = []
var checks: Array[Dictionary] = []
var last_us: int = 0
var next_shot: int = 0
var stage_kills: int = 0
var finished: bool = false
var result_age: float = 0
var output: String
var qa: bool = false
var capture_enabled: bool = false
var captured: Dictionary = {}
var ui: CanvasLayer
var heading: Label
var hint: Label
var curtain: ColorRect
var result_panel: PanelContainer
var result_text: Label
var old_vsync: int
var report: Dictionary = {}
var cinema_lens: RefCounted
var framing_style: String = "baseline" if OS.get_environment("QUARANTINE_BENCHMARK_FRAMING") == "baseline" else "lit-closeup"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 20 # Override scenic FOV after the normal player's viewmodel update.
	qa = "--benchmark-qa" in OS.get_cmdline_user_args()
	capture_enabled = "--benchmark-capture" in OS.get_cmdline_user_args()
	output = OS.get_environment("QUARANTINE_BENCHMARK_OUTPUT")
	if output.is_empty(): output = "user://benchmarks/"+Time.get_datetime_string_from_system().replace(":","-")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	old_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	mission = load("res://scenes/quarantine.tscn").instantiate()
	add_child(mission)
	mission.qa_mode = true
	mission.set_process_input(false)
	player = mission.player
	cinema_lens = preload("res://scripts/quarantine/benchmark_lens.gd").new(player.camera)
	player.qa_mode = true
	player.set_process_unhandled_input(false)
	for bug in mission.bugs: bug.set_physics_process(false)
	mission.bugs[0].position = Vector3(1.4,.05,16)
	mission.bugs[1].position = Vector3(-1.6,.05,16)
	mission.bugs[2].position = Vector3(0,.05,14)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	build_ui()
	last_us = Time.get_ticks_usec()
	change_chapter(0)

func build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 30
	add_child(ui)
	var root: Control = Control.new()
	ui.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading = Label.new()
	heading.position = Vector2(40,32)
	heading.add_theme_font_size_override("font_size",24)
	heading.add_theme_color_override("font_color",Color(.82,.88,.88))
	root.add_child(heading)
	hint = Label.new()
	root.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 40
	hint.offset_top = -38
	hint.offset_bottom = -14
	hint.add_theme_font_size_override("font_size",14)
	hint.text = "Esc  退出"
	curtain = ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(curtain)
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_panel = PanelContainer.new()
	root.add_child(result_panel)
	result_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result_panel.offset_left = -380
	result_panel.offset_right = 380
	result_panel.offset_top = -240
	result_panel.offset_bottom = 240
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(.025,.045,.06,.97)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	result_panel.add_theme_stylebox_override("panel",style)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation",20)
	result_panel.add_child(column)
	result_text = Label.new()
	result_text.add_theme_font_size_override("font_size",18)
	column.add_child(result_text)
	var replay: Button = Button.new()
	replay.text = "重播  R"
	replay.pressed.connect(replay_benchmark)
	column.add_child(replay)
	var play: Button = Button.new()
	play.text = "进入关卡  Enter"
	play.pressed.connect(play_mission)
	column.add_child(play)
	var exit_button: Button = Button.new()
	exit_button.text = "退出  Esc"
	exit_button.pressed.connect(exit_benchmark)
	column.add_child(exit_button)
	result_panel.hide()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	# Scene switches detach this node immediately; consume input before switching.
	get_viewport().set_input_as_handled()
	if event.physical_keycode == KEY_ESCAPE:
		exit_benchmark()
	elif finished and event.physical_keycode == KEY_R:
		replay_benchmark()
	elif finished and event.physical_keycode == KEY_ENTER:
		play_mission()

func aim(point: Vector3) -> void:
	var d: Vector3 = point-player.camera.global_position
	player.rotation.y = atan2(-d.x,-d.z)
	player.head.rotation.x = atan2(d.y,Vector2(d.x,d.z).length())

func scenic(from: Vector3, to: Vector3, focus: Vector3, fraction: float, fov: float) -> void:
	var t: float = smoothstep(0,1,clampf(fraction,0,1))
	# Coordinates describe the camera, not a fictitious walkable capsule route.
	player.position = from.lerp(to,t)-Vector3(0,1.65,0)
	aim(focus)
	player.camera.fov = fov

func change_chapter(value: int) -> void:
	chapter = value
	cinema_lens.clear(player.camera)
	heading.text = "SELENE"
	var gameplay: bool = value in [4,5,7]
	mission.hud.visible = gameplay
	player.get_node("WeaponLayer").visible = gameplay
	player.set_physics_process(gameplay)
	player.qa_direction = Vector3.ZERO
	player.velocity = Vector3.ZERO
	player.aiming = false
	heading.visible = value == 0
	if value == 3 and framing_style != "baseline":
		# Presentation staging: keep the close-up camera out of another frozen bug.
		mission.bugs[1].position = Vector3(-3.5,.05,18.5)
		mission.bugs[2].position = Vector3(-1.8,.05,20)
	elif value == 4:
		mission.bugs[1].position = Vector3(-1.6,.05,16)
		mission.bugs[2].position = Vector3(0,.05,14)
		player.position = Vector3(0,.05,22)
		stage_kills = mission.kills
	elif value == 5:
		check("three_enemies_killed_by_nine_real_shots",mission.kills-stage_kills==3 and next_shot==9)
		# Narrative time compression, explicitly not a hands-off full mission playthrough.
		for bug in mission.bugs:
			while not bug.dead: bug.register_hit()
		player.position = Vector3(0,.05,-20.2)
	elif value == 6:
		Input.action_release("interact")
		check("terminal_activated_by_three_second_input",mission.stage==mission.EXTRACT)
	elif value == 7:
		player.position = Vector3(0,.05,12)
		player.qa_direction = Vector3(0,0,1)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = float(now-last_us)/1000000.0
	last_us = now
	if finished:
		result_age += dt
		if qa and result_age > 1.5:
			get_tree().quit(0 if checks.all(func(c):return c.ok) else 1)
		return
	if elapsed >= 4: samples.append(dt*1000.0)
	elapsed += dt
	mission.health = 100 # Presentation safety only; normal mission is unaffected.
	var next_chapter: int = 0
	for i in CUTS.size():
		if elapsed >= CUTS[i]: next_chapter=i
	if next_chapter != chapter: change_chapter(next_chapter)
	var local: float = elapsed-CUTS[chapter]
	curtain.color.a = clampf(1.0-elapsed/2.5,0,1) if chapter==0 else maxf(0,.22-local*1.5)
	match chapter:
		0: scenic(Vector3(-4,3.4,27),Vector3(-4,3.4,27),Vector3(0,5,0),0,60)
		1: scenic(Vector3(-4,3.4,27),Vector3(-2,2.3,20),Vector3(0,5,0),local/8,60)
		2: scenic(Vector3(-8,3,-18),Vector3(-4,2.5,-18),Vector3(0,3.5,-28),local/7,55)
		3:
			var focus: Vector3 = mission.bugs[0].global_position+Vector3(0,.46,0)
			if framing_style == "baseline":
				scenic(Vector3(3.7,1.0,18.5),Vector3(2.8,.75,18),focus,local/5,48)
			else:
				scenic(Vector3(-.6,1.15,14.2),Vector3(-.1,.85,13.9),focus,local/5,46)
			cinema_lens.focus(player.camera,focus)
		4:
			var target: int = mini(next_shot/3,2)
			aim(mission.bugs[target].global_position+Vector3(0,.45,0))
			player.aiming = local > .6
			if next_shot < 9 and local >= 1.1+next_shot*.65 and player.cooldown<=0:
				var fired: bool = player.fire()
				check("real_hitscan_%02d"%next_shot,fired and player.last_hit.get("collider")==mission.bugs[target])
				next_shot += 1
		5:
			aim(Vector3(0,1.55,-22.4))
			if local > 1.0 and local < 5.5: Input.action_press("interact")
			else: Input.action_release("interact")
		6: scenic(Vector3(-8,3,-17),Vector3(-10,6,-12),Vector3(0,8,0),local/10,58)
		7:
			aim(Vector3(0,2.5,31))
			if mission.stage == mission.COMPLETE:
				check("capsule_walk_completed_extraction",true)
				finish()
			elif elapsed > 57:
				check("capsule_walk_completed_extraction",false)
				finish()
	if capture_enabled and not finished and local > 1.8 and not captured.has(chapter):
		captured[chapter]=true
		capture("%02d"%chapter)

func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("BENCHMARK CHECK ",id," ",ok)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")

func finish() -> void:
	finished = true
	Input.action_release("interact")
	player.qa_direction = Vector3.ZERO
	get_tree().paused = true
	mission.hud.hide()
	var total_ms: float = 0
	for ms in samples: total_ms+=ms
	var ordered: Array[float] = samples.duplicate()
	ordered.sort()
	var average: float = 1000.0*samples.size()/maxf(1,total_ms)
	var p95: float = ordered[mini(ordered.size()-1,int(ordered.size()*.95))] if not ordered.is_empty() else 0
	var p99: float = ordered[mini(ordered.size()-1,int(ordered.size()*.99))] if not ordered.is_empty() else 0
	report = {"engine":Engine.get_version_info().string,"platform":OS.get_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"atmosphere":mission.get_node("World").atmosphere_style,"horizon":mission.get_node("World").horizon_style,"directional_shadows":mission.get_node("World").shadow_style,"bug_style":mission.bugs[0].visual_style,"closeup_framing":framing_style,"closeup_dof":cinema_lens.enabled,"inspection_light":mission.has_node("World/InspectionLuminaire"),"resolution":str(get_viewport().size),"logical_canvas_size":str(get_viewport().get_visible_rect().size),"vsync":DisplayServer.window_get_vsync_mode(),"warmup_seconds":4,"measured_seconds":total_ms/1000,"frames":samples.size(),"mean_fps":average,"p95_ms":p95,"p99_ms":p99,"capture_enabled":capture_enabled,"checks":checks,"frame_ms":samples,"boundary":"Scripted cameras, frozen enemy positions, nine real shots into three enemies; remaining five cleared at cut; actual E input and physical evacuation. Health replenished. Not unassisted gameplay or a comparison with the separate 60s route benchmark."}
	var file: FileAccess = FileAccess.open(output+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BENCHMARK RESULT ",ProjectSettings.globalize_path(output+"/result.json"))
	curtain.color.a = .35
	heading.hide()
	hint.hide()
	result_text.text = "性能测试\n\n%s · %s\n%s · VSync OFF\n\n%.1f FPS   ·   P95 %.2f ms   ·   P99 %.2f ms\n%.1f 秒（不含预热）\n\n脚本化实机演示 · 结果已保存" % [report.gpu,report.renderer,report.resolution,average,p95,p99,total_ms/1000]
	result_panel.show()
	if capture_enabled: capture("result")

func replay_benchmark() -> void:
	Input.action_release("interact")
	get_tree().paused=false
	DisplayServer.window_set_vsync_mode(old_vsync)
	get_tree().reload_current_scene()

func play_mission() -> void:
	Input.action_release("interact")
	get_tree().paused=false
	DisplayServer.window_set_vsync_mode(old_vsync)
	get_tree().change_scene_to_file("res://scenes/quarantine.tscn")

func exit_benchmark() -> void:
	Input.action_release("interact")
	get_tree().paused=false
	DisplayServer.window_set_vsync_mode(old_vsync)
	get_tree().quit()
