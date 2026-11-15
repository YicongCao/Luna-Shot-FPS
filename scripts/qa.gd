extends Node
var checks: Array = []
var world: Node3D
var player: CharacterBody3D
var started: int
var frames: Array[float] = []
var OUT := "res://docs/validation/rifle-pipeline-v1/regression/" if "--pbr-regression" in OS.get_cmdline_user_args() else "res://docs/validation/whitebox-v1/"
func _ready() -> void:
	world = get_parent()
	player = world.get_node("Player")
	started = Time.get_ticks_msec()
	run.call_deferred()
func _process(delta: float) -> void:
	frames.append(delta * 1000)
func check(label: String, passed: bool, detail: String = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print("QA ", "PASS " if passed else "FAIL ", label, " ", detail)
func settle(count: int = 12) -> void:
	for i in count: await get_tree().physics_frame
func place(pos: Vector3) -> void:
	player.position = pos
	player.velocity = Vector3.ZERO
	player.qa_direction = Vector3.ZERO
	await settle()
func walk_to(point: Vector3, label: String) -> void:
	var max_frames: int = int(player.position.distance_to(point) / 5.0 * 60) + 150
	for i in max_frames:
		var diff := point - player.position
		diff.y = 0
		if diff.length() < .16: break
		player.qa_direction = diff.normalized()
		await get_tree().physics_frame
	player.qa_direction = Vector3.ZERO
	await settle(8)
	var distance: float = Vector2(player.position.x-point.x, player.position.z-point.z).length()
	check(label, distance < .3, "end=%s, planar_error=%.3f" % [player.position, distance])
func aim_at(point: Vector3) -> void:
	player.rotation = Vector3.ZERO
	player.head.look_at(point)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await settle(12)
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	check("screenshot_"+name, result == OK)
func run() -> void:
	await settle(30)
	check("spawn_floor", player.is_on_floor() and absf(player.position.y) < .05, str(player.position))
	await capture("01-spawn")
	world.set_overview(true)
	await capture("02-overview")
	world.set_overview(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Full walk around ship/central loop, via genuine player move_and_slide.
	await walk_to(Vector3(-18,0,20), "loop_south")
	await walk_to(Vector3(-20,0,10), "west_entry")
	await walk_to(Vector3(-20,0,-12), "west_ship_clearance")
	await walk_to(Vector3(-8,0,-12), "north_ship_path")
	await walk_to(Vector3(-8,0,-5.5), "ramp_side_path")
	await walk_to(Vector3(-5,0,-5.5), "north_crossing")
	await walk_to(Vector3(8,0,-6.5), "central_crossing")
	await walk_to(Vector3(11.8,0,-6.5), "east_entry")
	await walk_to(Vector3(11.8,0,9), "east_service_path")
	await walk_to(Vector3(3,0,12), "south_crossing")
	await walk_to(Vector3(0,0,18), "loop_return")
	# Both ramps in both directions + deck connection.
	await place(Vector3(-5,.1,-6))
	await walk_to(Vector3(-5,2.4,-16), "west_ramp_ascent")
	check("deck_height", absf(player.position.y-2.4) < .08, str(player.position.y))
	aim_at(Vector3(0,1,6))
	await capture("03-deck")
	await walk_to(Vector3(5,2.4,-16), "deck_crossing")
	await walk_to(Vector3(5,0,-6), "east_ramp_descent")
	await walk_to(Vector3(5,2.4,-16), "east_ramp_ascent")
	await walk_to(Vector3(-5,2.4,-16), "deck_return")
	await walk_to(Vector3(-5,0,-6), "west_ramp_descent")
	# Boundary blocks capsule even with jump; all four sides.
	for test in [[Vector3(-21,0,18),Vector3(-1,0,0)], [Vector3(21,0,18),Vector3(1,0,0)], [Vector3(0,0,23),Vector3(0,0,1)], [Vector3(-19,0,-23),Vector3(0,0,-1)]]:
		await place(test[0]+Vector3(0,.1,0))
		player.qa_direction = test[1]
		player.qa_jump = true
		await settle(40)
		player.qa_direction = Vector3.ZERO
		player.qa_jump = false
		check("boundary_"+str(test[1]), absf(player.position.x)<22 and absf(player.position.z)<24, str(player.position))
	# Camera-to-target hit, resettable target, ammo lock and reload.
	await place(Vector3(0,.1,18))
	aim_at(Vector3(0,1.5,8))
	player.cooldown = 0
	player.fire()
	check("target_hit", world.hits == 1 and player.ammo == 19, "hits=%d ammo=%d" % [world.hits,player.ammo])
	check("cooldown", not player.fire() and player.ammo==19)
	player.aiming = true
	await settle(40)
	var rear: Node3D = player.weapon.get_node("SightRear")
	var front: Node3D = player.weapon.get_node("SightFront")
	check("sight_axis", absf(rear.global_position.x)<.002 and absf(rear.global_position.y)<.002 and absf(front.global_position.y)<.002, str(rear.global_position))
	await capture("04-ads")
	player.reload_weapon()
	check("reload_fire_lock", not player.fire())
	await settle(40)
	await capture("05-reload")
	await settle(70)
	check("reload_complete", player.ammo==20 and player.reload_left==0)
	player.ammo = 0
	player.cooldown = 0
	check("empty_lock", not player.fire())
	# Test real obstruction: aiming through opaque base facade must hit architecture.
	await place(Vector3(0,2.5,-16))
	aim_at(Vector3(0,3.5,-23))
	player.ammo=20
	player.fire()
	check("architecture_occludes", not player.last_hit.is_empty() and not player.last_hit.collider.has_method("register_hit"))
	# Pause state freezes reload and movement, then resumes correctly.
	player.reload_weapon()
	world.set_paused(true)
	var time_before: float = player.reload_left
	var pos_before: Vector3 = player.position
	await settle(20)
	check("pause_freezes", player.reload_left==time_before and player.position==pos_before)
	world.resume()
	world.reset_range()
	check("reset_state", world.hits==0 and world.shots==0 and player.ammo==20 and player.reload_left==0 and not world.overview and not world.paused)
	await settle(20)
	await capture("06-reset")
	# Same rendering at ultrawide to validate weapon/HUD anchoring.
	if DisplayServer.get_name() != "headless":
		get_window().size = Vector2i(1600, 700)
		await settle(20)
		await capture("07-ultrawide")
		var viewport_size := get_viewport().get_visible_rect().size
		check("ultrawide_aspect", viewport_size.x / viewport_size.y > 2.2, str(viewport_size))
	frames.sort()
	var failures := checks.filter(func(item): return not item.passed)
	var report := {"engine":Engine.get_version_info().string, "platform":OS.get_name(), "display":DisplayServer.get_name(), "elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0, "checks":checks, "failures":failures.size(), "frame_ms_p95":frames[int(frames.size()*.95)], "note":"Automated native traversal and rendering; not human playtest or long-duration performance acceptance."}
	var file := FileAccess.open(OUT + ("headless.json" if DisplayServer.get_name()=="headless" else "native.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	print("QA_COMPLETE failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
