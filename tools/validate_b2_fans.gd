extends SceneTree
const OUT := "res://docs/validation/b2-cooling-fans/"
var checks: Array = []
var native := DisplayServer.get_name() != "headless"

func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func check(label: String, passed: bool, detail := "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print("FAN ", "PASS " if passed else "FAIL ", label, " ", detail)
func capture(name: String) -> Image:
	await frames(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	check("capture_" + name, img.save_png(OUT + name + ".png") == OK)
	return img

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 1000)
	var world: Node3D = load("res://scenes/training.tscn").instantiate()
	root.add_child(world)
	world.player.qa_mode = true
	await frames(30)
	var groups: Array[Node3D] = []
	var shared_fixed: Dictionary = {}
	var shared_rotor: Dictionary = {}
	for module: Node3D in world.get_node("Facility").get_children():
		var fans := module.get_node_or_null("CoolingFans")
		check(str(module.name) + "_B2_only", (fans != null) == (module.get("asset_id") == "B2"))
		if not fans: continue
		groups.append(fans)
		check(str(module.name) + "_three_rotors", fans.rotors.size() == 3)
		check(str(module.name) + "_pause_owner", fans.training == world)
		shared_fixed[fans.get_node("FixedHousing").mesh.get_instance_id()] = true
		for rotor: MeshInstance3D in fans.rotors: shared_rotor[rotor.mesh.get_instance_id()] = true
		# Include all eight transformed AABB corners, including rotor swept bounds.
		var inside := true
		for mesh: MeshInstance3D in fans.find_children("*", "MeshInstance3D", true, false):
			var local_box: AABB = (module.global_transform.affine_inverse() * mesh.global_transform) * mesh.get_aabb()
			inside = inside and maxf(absf(local_box.position.x), absf(local_box.end.x)) <= 2.0
			inside = inside and maxf(absf(local_box.position.z), absf(local_box.end.z)) <= 2.0
		check(str(module.name) + "_inside_original_footprint", inside)
		fans.set_process(false)
		var housing_transform: Transform3D = fans.get_node("FixedHousing").transform
		var rotor: Node3D = fans.rotors[0]
		rotor.rotation.z = 0
		fans.advance(1.0)
		var full_step: float = rotor.rotation.z
		rotor.rotation.z = 0
		for i in 120: fans.advance(1.0 / 120)
		check(str(module.name) + "_delta_independent", absf(angle_difference(full_step, rotor.rotation.z)) < .0001)
		check(str(module.name) + "_fixed_housing", fans.get_node("FixedHousing").transform == housing_transform)
		fans.set_process(true)
	check("six_cassettes_eighteen_rotors", groups.size() == 6)
	check("shared_meshes", shared_fixed.size() == 1 and shared_rotor.size() == 1)
	var chosen: Node3D = world.get_node("Facility/B02")
	var fan: Node3D = chosen.get_node("CoolingFans")
	var triangles := 0
	var surfaces := 0
	for mesh: MeshInstance3D in fan.find_children("*", "MeshInstance3D", true, false):
		for surface_id in mesh.mesh.get_surface_count():
			var count: int = mesh.mesh.surface_get_array_index_len(surface_id)
			if count == 0: count = mesh.mesh.surface_get_array_len(surface_id)
			triangles += count / 3
			surfaces += 1
	print("FAN_GEOMETRY per_tower_triangles=", triangles, " per_tower_surfaces=", surfaces)
	world.set_paused(true)
	var angle: float = fan.rotors[0].rotation.z
	await frames(12)
	check("pause_stops_rotation", is_equal_approx(angle, fan.rotors[0].rotation.z))
	world.set_paused(false)
	await create_timer(.15).timeout
	check("resume_rotates", absf(angle_difference(angle, fan.rotors[0].rotation.z)) > .05)
	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(chosen.to_global(Vector3(3, 3, 0)), chosen.to_global(Vector3(1.5, 3, 0)), 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	check("static_guard_blocks_ray", not hit.is_empty() and hit.collider == fan.get_node("GuardCollision"))
	world.reset_range()
	check("reset_keeps_same_fan_instances", chosen.get_node("CoolingFans") == fan)
	if native:
		world.set_overview(true)
		world.hud.hide()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 55
		camera.make_current()
		camera.global_position = chosen.to_global(Vector3(8, 3.8, 4.5))
		camera.look_at(chosen.to_global(Vector3(0, 2.8, 0)))
		fan.hide()
		await capture("01-original")
		fan.show()
		await capture("02-installed")
		camera.global_position = chosen.to_global(Vector3(5.4, 3.0, .8))
		camera.look_at(chosen.to_global(Vector3(1.7, 3.0, 0)))
		fan.set_process(false)
		var first := await capture("03-close")
		fan.advance(.12)
		var second := await capture("04-rotated")
		var changed := 0
		for y in range(100, 900, 2):
			for x in range(400, 1050, 2):
				var a := first.get_pixel(x, y)
				var b := second.get_pixel(x, y)
				if absf(a.r-b.r) + absf(a.g-b.g) + absf(a.b-b.b) > .08: changed += 1
		check("rotor_motion_visible_pixels", changed > 150, str(changed))
		fan.set_process(true)
		if "--fan-demo" in OS.get_cmdline_user_args(): await frames(300)
		world.set_overview(false)
		world.player.position = chosen.to_global(Vector3(4, .05, 2))
		world.player.head.look_at(chosen.to_global(Vector3(1.7, 3.0, 0)))
		world.hud.show()
		await capture("05-player-view")
	var failures := checks.filter(func(c): return not c.passed).size()
	var suffix := "native" if native else "headless"
	FileAccess.open(OUT + suffix + ".json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("FAN_CHECKS ", checks.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)
