extends Node
var checks: Array = []
var world: Node3D
var player: CharacterBody3D
var started: int
var frames: Array[float] = []
var OUT: String = "res://" + OS.get_environment("LUNA_QA_OUTPUT") + "/" if OS.has_environment("LUNA_QA_OUTPUT") else "res://docs/validation/energy-whitebox-v2/"
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
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
	check("spawn_floor",player.is_on_floor() and player.position.distance_to(world.marker("Spawn"))<.1)
	check("module_instances",world.get_node("Facility").get_child_count()==58)
	await capture("01-spawn")
	world.set_overview(true)
	await capture("02-overview")
	world.set_overview(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for route_name: String in world.layout.routes:
		var route: Array=world.layout.routes[route_name]
		await place(world.vector(route[0])+Vector3(0,.05,0))
		for i in range(1,route.size()):
			await walk_to(world.vector(route[i]),route_name+"_"+str(i))
			if route[i][1]>0:
				check(route_name+"_height_"+str(i),absf(player.position.y-2.4)<.08,str(player.position.y))
				if i==2:
					aim_at(world.marker("OverviewFocus"))
					await capture(route_name+"-deck")
	# Cross both bridge underpasses with the real capsule.
	for x in [-18,18]:
		await place(Vector3(x-4,.05,0))
		await walk_to(Vector3(x+4,0,0),"bridge_underpass_"+str(x))
		check("underpass_ground_"+str(x),absf(player.position.y)<.05)
		player.rotation=Vector3.ZERO
		player.head.look_at(Vector3(x,2.4,0))
		await capture("underbridge_"+str(x))
	# Continuous side rails stop stepping off the two bridges.
	for x in [-18,18]:
		await place(Vector3(x,2.45,0))
		player.qa_direction=Vector3.RIGHT
		await settle(50)
		player.qa_direction=Vector3.ZERO
		check("bridge_guardrail_"+str(x),player.position.x<x+1.8 and player.position.y>2.3,str(player.position))
	for test in world.layout.boundaries:
		await place(world.vector(test.position)+Vector3(0,.05,0))
		player.qa_direction=world.vector(test.direction)
		player.qa_jump=true
		await settle(45)
		player.qa_direction=Vector3.ZERO;player.qa_jump=false
		check("boundary_"+str(test.direction),absf(player.position.x)<32 and absf(player.position.z)<33)
	for t in world.layout.targets:
		await place(world.vector(t.shoot_from))
		aim_at(world.vector(t.position)+Vector3(0,1.5,0))
		player.cooldown=0;player.ammo=20
		var before: int=world.hits
		player.fire()
		check("hit_"+t.id,world.hits==before+1,str(player.last_hit))
	check("cooldown",not player.fire())
	player.aiming=true
	await settle(40)
	var rear: Node3D=player.weapon.get_node("SightRear")
	check("sight_axis",absf(rear.global_position.x)<.002 and absf(rear.global_position.y)<.002)
	await capture("03-ads")
	player.reload_weapon()
	check("reload_fire_lock",not player.fire())
	await settle(40)
	await capture("04-reload")
	await settle(70)
	check("reload_complete",player.ammo==20 and player.reload_left==0)
	player.ammo=0;player.cooldown=0
	check("empty_lock",not player.fire())
	# Select a generated B tower and fire at its solid core from the central road.
	var tower: Dictionary=world.layout.modules.filter(func(m):return m.type=="B" and m.position[0]==6 and m.position[2]==6)[0]
	await place(Vector3(0,.05,6))
	aim_at(world.vector(tower.position)+Vector3(0,2,0))
	player.ammo=20;player.aiming=false;player.fire()
	check("architecture_occludes",not player.last_hit.is_empty() and not player.last_hit.collider.has_method("register_hit"))
	await capture("05-array")
	player.reload_weapon();world.set_paused(true)
	var time_before: float=player.reload_left
	var pos_before: Vector3=player.position
	await settle(20)
	check("pause_freezes",player.reload_left==time_before and player.position==pos_before)
	world.resume();world.reset_range()
	check("reset_state",world.hits==0 and world.shots==0 and player.ammo==20 and player.reload_left==0 and not world.overview and not world.paused)
	check("reset_marker",player.position.distance_to(world.marker("Spawn"))<.001)
	await settle(20)
	await capture("06-reset")
	if DisplayServer.get_name()!="headless":
		get_window().size=Vector2i(1600,700)
		await settle(20)
		await capture("07-ultrawide")
		check("ultrawide_aspect",get_viewport().get_visible_rect().size.aspect()>2.2)
	frames.sort()
	var failures:=checks.filter(func(item):return not item.passed)
	var report:={"engine":Engine.get_version_info().string,"platform":OS.get_name(),"display":DisplayServer.get_name(),"elapsed_seconds":(Time.get_ticks_msec()-started)/1000.0,"checks":checks,"failures":failures.size(),"frame_ms_p95":frames[int(frames.size()*.95)],"note":"Actual capsule traversal and native rendering; not long-duration performance acceptance."}
	var f:=FileAccess.open(OUT+("headless.json" if DisplayServer.get_name()=="headless" else "native.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")+"\n")
	print("QA_COMPLETE failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
