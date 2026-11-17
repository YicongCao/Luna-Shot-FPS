extends SceneTree
# Native viewport capture, not an offline render. Fixed cameras freeze enemies for comparison.
var mission: Node3D
var report: Dictionary = {"platform":OS.get_name(),"engine":Engine.get_version_info().string,"checks":[],"fixed_camera":true}
var output: String = "res://docs/validation/quarantine-v1/native"

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count: await process_frame

func capture(name: String, settle: int = 8) -> void:
	await frames(settle)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(output+"/"+name+".png")
	print("CAPTURE "+name)

func aim(point: Vector3) -> void:
	var player: Node = mission.player
	var direction: Vector3 = point-player.camera.global_position
	player.rotation.y = atan2(-direction.x,-direction.z)
	player.head.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())

func check(id: String, ok: bool) -> void:
	report.checks.append({"id":id,"ok":ok})
	print("CHECK ",id," ",ok)

func run() -> void:
	if not OS.get_environment("QUARANTINE_CAPTURE_OUTPUT").is_empty():
		output = OS.get_environment("QUARANTINE_CAPTURE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	mission = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	await frames(90)
	report.renderer = RenderingServer.get_current_rendering_method()
	report.atmosphere = mission.get_node("World").atmosphere_style
	report.bug_style = mission.bugs[0].visual_style
	var player: Node = mission.player
	player.qa_mode = true
	for bug in mission.bugs: bug.set_physics_process(false)
	mission.health = 100.0
	player.position = Vector3(0,.05,28)
	player.rotation = Vector3.ZERO
	player.head.rotation = Vector3.ZERO
	await capture("01-arrival")
	# Actual hitscan into a live procedural enemy from the central clear lane.
	var bug: Node3D = mission.bugs[0]
	bug.position = Vector3(1.4,.05,16)
	player.position = Vector3(0,.05,22)
	await frames(4)
	aim(bug.global_position+Vector3(0,.45,0))
	player.aiming = true
	await frames(40)
	await capture("02-fighter-hud")
	var start_kills: int = mission.kills
	for shot in 3:
		player.cooldown = 0
		check("actual_shot_%d"%shot,player.fire())
		await physics_frame
		if shot == 0:
			# Deterministic 12ms visual sample of the actual fired effect, not a painted overlay.
			player.fire_effect.set_process(false)
			player.fire_effect.age = .012
			player.fire_effect.refresh()
			await capture("03-discharge",0)
			player.fire_effect.set_process(true)
		await frames(15)
	check("hitscan_kills_bug",mission.kills == start_kills+1)
	player.aiming = false
	player.position = Vector3(-18,2.45,5)
	await frames(4)
	aim(Vector3(0,5,-8))
	await frames(40)
	await capture("04-gantry")
	player.position = Vector3(2,.05,-17)
	await frames(4)
	aim(Vector3(0,1.4,-22.3))
	await frames(40)
	await capture("05-terminal")
	# Presentation state after activation; gameplay state gates are tested separately.
	for b in mission.bugs:
		while not b.dead: b.register_hit()
	player.position = Vector3(0,.05,-20.2)
	await frames(4)
	mission._update_activation(3.1,true)
	await frames(30)
	check("terminal_active",mission.stage == mission.EXTRACT)
	await capture("06-power-restored")
	player.position = Vector3(-10,.05,-18)
	await frames(4)
	aim(Vector3(0,8,0))
	await frames(35)
	await capture("06b-reactor-online")
	player.position = Vector3(0,.05,20)
	await frames(4)
	aim(Vector3(0,2,31))
	await frames(30)
	await capture("07-extraction")
	# Real capsule movement over the remaining approach, rather than direct success calls.
	player.qa_direction = Vector3(0,0,1)
	for i in 120:
		await physics_frame
		if mission.stage == mission.COMPLETE: break
	player.qa_direction = Vector3.ZERO
	check("walk_into_extraction_completes",mission.stage == mission.COMPLETE)
	await capture("08-complete")
	report.render = {"objects":Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
	var file: FileAccess = FileAccess.open(output+"/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	mission.queue_free()
	await frames(4)
	quit(0 if report.checks.all(func(item): return item.ok) else 1)
