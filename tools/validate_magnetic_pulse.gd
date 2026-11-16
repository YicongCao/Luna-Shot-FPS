extends SceneTree
var OUT = OS.get_environment("LUNA_EFFECT_QA_OUTPUT") if OS.has_environment("LUNA_EFFECT_QA_OUTPUT") else "res://docs/validation/magnetic-pulse-v1/"
var expected_effect := "MagneticPulse"
var checks: Array = []
func check_effect() -> void: pass
func extra_checks() -> void: pass
func extra_capture(_label: String) -> void: pass
var world: Node3D
var p: CharacterBody3D
var fx: Node3D
var native := false
func _initialize() -> void: run.call_deferred()
func frames(n: int = 5) -> void:
	for i in n: await process_frame
func check(label: String, passed: bool, detail: String = "") -> void:
	checks.append({"check": label, "passed": passed, "detail": detail})
	print("PULSE_QA ", "PASS " if passed else "FAIL ", label, " ", detail)
func capture(label: String, at: float) -> void:
	if not native: return
	p.weapon.field_kit.set_ammo(p.ammo, p.CAPACITY)
	fx.age = at
	fx.refresh()
	await frames(3)
	await RenderingServer.frame_post_draw
	check("capture_" + label, root.get_texture().get_image().save_png(OUT+label+".png") == OK)
func prepare(ads: bool) -> void:
	world.reset_range()
	p.qa_mode = true
	p.position = world.vector(world.layout.targets[0].shoot_from)
	p.head.look_at(world.get_node("Target1").position + Vector3(0,1.5,0))
	p.aiming = ads
	await frames(40)
	p.weapon.position = p.ADS if ads else p.HIP
	p.weapon.rotation = Vector3.ZERO
	p.recoil = 0
	p.camera.fov = 52 if ads else 72
	p.weapon_camera.fov = 52 if ads else 62
func run() -> void:
	native = DisplayServer.get_name() != "headless"
	root.size = Vector2i(1600,1000)
	world = load("res://scenes/training.tscn").instantiate()
	root.add_child(world)
	await frames(50)
	p = world.player
	p.qa_mode = true
	fx = p.fire_effect
	fx.manual_clock = true
	check("selected_effect",fx.name == expected_effect)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	check("default_ml06", p.weapon.revision == "ml06")
	var original_nodes := get_node_count()
	var baseline: float = p.weapon.material.emission_energy_multiplier
	for ads in [false,true]:
		await prepare(ads)
		var label := "ads" if ads else "hip"
		var uv: Vector2 = p.weapon_camera.unproject_position(p.weapon.get_node("Muzzle").global_position) / Vector2(p.weapon_camera.get_viewport().size)
		var uv_world: Vector2 = p.camera.unproject_position(p.muzzle_world_position()) / root.get_visible_rect().size
		check(label+"_muzzle_projection", uv.distance_to(uv_world) < .0001, str(uv.distance_to(uv_world)))
		if native:
			fx.clear()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+label+"-before.png")
		check(label+"_shot",p.fire())
		check(label+"_hit",world.hits == 1 and p.ammo == 19)
		check(label+"_endpoint",fx.finish.distance_to(p.last_hit.position)<.00001)
		check(label+"_pulse",p.weapon.material.emission_energy_multiplier > baseline)
		check(label+"_muzzle_visible",fx.flash.visible and fx.muzzle_clear)
		var count: int = fx.shot_count
		check(label+"_cooldown_no_fx",not p.fire() and fx.shot_count == count)
		check_effect()
		# Freeze pose/target for reproducible photographic evidence; effect still renders natively.
		p.set_process(false)
		world.get_node("Target1").animation_paused = true
		await capture(label+"-008ms",.008)
		await extra_capture(label)
		await capture(label+"-045ms",.045)
		fx.age = .070; fx.refresh()
		check(label+"_flash_expired",not fx.flash.visible)
		await capture(label+"-080ms",.080)
		fx.manual_clock = false
		fx._process(.100)
		check(label+"_all_expired",not fx.flash.visible and not fx.trail.visible and fx.flash_light.light_energy == 0)
		check(label+"_emission_restored",is_equal_approx(p.weapon.material.emission_energy_multiplier,baseline))
		fx.manual_clock = true
		p.set_process(true)
		world.get_node("Target1").animation_paused = false
	await prepare(false)
	world.lighting.set_bloom(false)
	world.lighting.flares_enabled = false
	p.fire(); p.set_process(false)
	await capture("hip-no-bloom-008ms",.008)
	fx.clear(); p.set_process(true)
	world.lighting.set_bloom(true)
	world.lighting.flares_enabled = true
	await prepare(false)
	# Thin wall between camera and actual muzzle; old camera ray must not bypass it.
	var wall := StaticBody3D.new()
	wall.name = "QA_CloseWall"
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new(); box.size = Vector3(3,3,.08); shape.shape = box
	wall.add_child(shape)
	var mesh := MeshInstance3D.new(); var cube := BoxMesh.new(); cube.size = box.size; mesh.mesh = cube
	wall.add_child(mesh)
	world.add_child(wall)
	wall.global_transform = p.camera.global_transform
	wall.position -= p.camera.global_basis.z*.45
	await physics_frame; await physics_frame
	check("near_wall_shot",p.fire())
	check("near_wall_blocks_target",p.last_hit.get("collider") == wall and world.hits == 0)
	check("near_wall_hides_viewmodel_flash",not fx.muzzle_clear and not fx.flash.visible and fx.flash_light.light_energy == 0)
	check("near_wall_trace_no_penetration",fx.start.distance_to(fx.finish)<.001)
	p.set_process(false);await capture("near-wall",.008);p.set_process(true)
	fx.clear()
	wall.position = p.camera.global_position - p.camera.global_basis.z * 1.3
	await physics_frame; await physics_frame
	p.cooldown = 0
	p.fire()
	check("wall_ahead_shortens_flash",fx.muzzle_clear and fx.flash_extent <= fx.start.distance_to(fx.finish) * .85 + .0001 and fx.flash_extent < .58)
	var anchored: Vector3 = fx.finish
	p.position.x += .1
	check("impact_world_anchored",fx.finish == anchored and fx.get_parent() == world)
	fx.clear();wall.queue_free();await frames()
	await prepare(false)
	p.head.rotation.x = PI*.35
	p.cooldown = 0
	check("sky_miss_shot",p.fire())
	check("sky_miss_no_impact",p.last_hit.is_empty() and not fx.has_impact)
	fx.age = .080;fx.refresh()
	fx.clear()
	await prepare(false)
	p.weapon.set_energy_enabled(false)
	p.fire()
	check("energy_off_respected",not p.weapon.material.emission_enabled and fx.flash_light.light_energy == 0)
	p.weapon.set_energy_enabled(true)
	p.weapon.set_spill_enabled(false)
	fx.refresh()
	check("spill_off_respected",fx.flash_light.light_energy == 0)
	p.weapon.set_spill_enabled(true)
	fx.clear()
	# Real cadence: elapsed-time expiration, no allocations retained between 20 shots.
	await prepare(false)
	fx.manual_clock = false
	var initial: int = fx.shot_count
	for i in 20:
		check("burst_shot_%02d"%i,p.fire())
		await create_timer(.175).timeout
		check("burst_decay_%02d"%i,fx.age >= fx.LIFE and not fx.flash.visible and not fx.trail.visible)
	check("burst_exact_ammo",p.ammo == 0 and fx.shot_count-initial == 20)
	check("empty_no_fx",not p.fire() and fx.shot_count-initial == 20)
	check("pooled_nodes",get_node_count() == original_nodes,str([original_nodes,get_node_count()]))
	p.reload_weapon()
	check("reload_no_fx",not p.fire() and fx.shot_count-initial == 20)
	await create_timer(1.65).timeout
	check("reload_returns",p.ammo == 20)
	p.fire();world.set_overview(true);await frames()
	check("overview_clears",not fx.flash.visible and not fx.trail.visible)
	world.set_overview(false)
	p.cooldown = 0;p.fire();world.reset_range()
	check("reset_clears",fx.age == fx.LIFE and is_equal_approx(p.weapon.material.emission_energy_multiplier,baseline))
	if native:
		root.size = Vector2i(2100,900)
		await prepare(true)
		p.fire();fx.manual_clock = true;p.set_process(false)
		await capture("ultrawide-ads",.008)
		var screen_a: Vector2 = p.camera.unproject_position(fx.start)/root.get_visible_rect().size
		var screen_b: Vector2 = p.weapon_camera.unproject_position(p.weapon.get_node("Muzzle").global_position)/Vector2(p.weapon_camera.get_viewport().size)
		check("ultrawide_muzzle_alignment",screen_a.distance_to(screen_b)<.001)
	await extra_checks()
	var failures := checks.filter(func(c):return not c.passed)
	FileAccess.open(OUT+("native.json" if native else "headless.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures.size(),"engine":Engine.get_version_info().string,"note":"Timing frames held for labelled screenshots; burst uses elapsed runtime. Not sustained performance acceptance."},"\t"))
	print("PULSE_QA_COMPLETE failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
