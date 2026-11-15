extends SceneTree
var scene: Node3D
var player: CharacterBody3D
var light: Node3D
var checks: Array=[]
var out := "res://docs/validation/industrial-wear-v1/lighting/"
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n:await process_frame
func check(label: String, passed: bool, details: Variant=null) -> void:
	checks.append({"check":label,"passed":passed,"details":details});print("LIGHTING_", "PASS " if passed else "FAIL ",label," ",details)
func capture(label: String) -> void:
	await frames(20);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+label+".png")
func position_camera(pos: Vector3, target: Vector3) -> void:
	player.position=pos;player.velocity=Vector3.ZERO;player.rotation=Vector3.ZERO;player.head.rotation=Vector3.ZERO
	player.camera.look_at(target)
	await frames(30)
func performance(enabled: bool) -> Dictionary:
	light.set_bloom(enabled);light.flares_enabled=enabled;light.set_facility_enabled(enabled)
	await position_camera(Vector3(3,.05,20),Vector3(3,2,-20))
	await frames(90)
	var times: Array[float]=[];var previous:=Time.get_ticks_usec()
	for i in 600:
		player.position=Vector3(3,.05,20-float(i)/600*40)
		await process_frame
		var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
	times.sort()
	return {"frames":times.size(),"p50_ms":times[300],"p95_ms":times[570],"max_ms":times.back(),"effects":enabled,"route":"central corridor x=3, z=20 to -20, same 600 render frames"}
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,800)
	scene=load("res://scenes/training.tscn").instantiate();root.add_child(scene)
	player=scene.player;player.qa_mode=true;light=scene.lighting
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(90)
	await capture("10-spawn-final")
	await position_camera(Vector3(0,.05,20),Vector3(0,2.3,0))
	light.flares_enabled=false;light.set_bloom(false);player.weapon.set_energy_enabled(false);player.weapon.set_spill_enabled(false)
	await capture("00-baseline")
	player.weapon.set_energy_enabled(true);await capture("01-emission")
	player.weapon.set_spill_enabled(true);await capture("02-local-spill")
	player.get_node("WeaponLayer/Container/Viewport").get_texture().get_image().save_png(out+"weapon-no-bloom-rgba.png")
	light.set_bloom(true);light.environment.glow_enabled=false;await capture("03a-weapon-bloom-only")
	light.weapon_bloom.vertical.get_texture().get_image().save_png(out+"weapon-bloom-pass.png")
	light.environment.glow_enabled=true;await capture("03-bloom")
	player.get_node("WeaponLayer/Container/Viewport").get_texture().get_image().save_png(out+"weapon-bloom-rgba.png")
	light.flares_enabled=true;await capture("04-flare")
	check("gun_emissive_triangle_candidates",light.flare_pass.samples.size()>0,light.flare_pass.samples.size())
	check("gun_visible_emissive_samples",light.flare_pass.gun_visible_samples>0,light.flare_pass.gun_visible_samples)
	# A real opaque viewmodel mesh between camera and weapon must suppress the gun optical effect.
	player.blocked=true
	var blocker:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(2,2,.01);blocker.mesh=box;blocker.position=Vector3(0,0,-.2)
	player.weapon_camera.get_parent().add_child(blocker)
	light.flare_pass.occluders.append({"mesh":blocker,"tree":box.generate_triangle_mesh()})
	await frames(50);check("gun_mesh_occlusion",light.flare_pass.gun_visible_samples==0)
	light.flare_pass.occluders.pop_back();blocker.queue_free();player.blocked=false
	await frames(30)
	player.aiming=true;await capture("05-ads")
	check("ads_active",player.aiming)
	player.aiming=false;player.reload_weapon();await capture("06-reload");await frames(100)
	player.weapon.set_energy_enabled(false);await frames(45)
	check("energy_off_suppresses_gun_flare",light.flare_pass.gun_visible_samples==0)
	player.weapon.set_energy_enabled(true)
	# Fixed lamp shot isolates actual scene Bloom from imagegen flare.
	await position_camera(Vector3(-18,.05,18),Vector3(-19.75,1.2,15.6))
	light.flares_enabled=false;light.set_bloom(false);await capture("20-lamp-no-bloom")
	light.set_bloom(true);await capture("21-lamp-bloom")
	light.flares_enabled=true;await capture("22-lamp-flare")
	light.set_facility_enabled(false);await create_timer(.7).timeout
	check("lamps_off_suppress_flares",light.flare_pass.visible_sources.filter(func(s):return s.kind=="lamp").is_empty())
	light.set_facility_enabled(true)
	# Sun alignment and collision-based occlusion.
	var origin:=Vector3(0,.05,16);var eye:=origin+Vector3(0,1.65,0);var toward: Vector3=light.sun.global_basis.z
	await position_camera(origin,eye+toward*100);await capture("30-sun-facing")
	check("sun_facing_visible",light.flare_pass.sources[0].weight>.7,light.flare_pass.sources[0].weight)
	# Freeze pose and isolate the flare pass: test 25% ADS attenuation in actual pixels.
	player.blocked=true;light.set_bloom(false);await create_timer(.6).timeout
	await capture("50-flare-hip-fixed")
	player.aiming=true;await capture("51-flare-ads-fixed")
	light.flares_enabled=false;await capture("52-flare-none-fixed")
	player.aiming=false;player.blocked=false;light.flares_enabled=true;light.set_bloom(true)
	var body:=StaticBody3D.new();var collision:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(4,4,4);collision.shape=shape;body.add_child(collision)
	body.position=eye+toward*4;scene.add_child(body)
	await frames(60);await capture("31-sun-occluded")
	check("sun_occluded_fades",light.flare_pass.sources[0].weight<.01,light.flare_pass.sources[0].weight)
	check("gun_key_shadow_attenuates",light.sun_visibility<.05,light.sun_visibility)
	body.queue_free();await frames(30)
	await position_camera(origin,eye+toward.rotated(Vector3.UP,PI*.5)*100);await capture("32-sun-side")
	check("sun_side_offscreen",light.flare_pass.sources[0].weight<.01)
	await position_camera(origin,eye-toward*100);await capture("33-sun-behind")
	check("sun_behind_suppressed",light.flare_pass.sources[0].weight<.01)
	await position_camera(Vector3(-18,.05,0),Vector3(-18,2,-15));await capture("40-underbridge")
	scene.set_overview(true);await capture("41-overview")
	check("overview_camera_used",light.flare_pass.last_camera==scene.get_node("Overview") and light.flare_pass.gun_visible_samples==0)
	scene.set_overview(false)
	root.size=Vector2i(1600,700);await frames(30);await capture("42-ultrawide")
	check("ultrawide_flare_layout",light.flare_pass.size==root.get_visible_rect().size)
	root.size=Vector2i(1280,800)
	var off:=await performance(false);var on:=await performance(true)
	var failures:=checks.filter(func(c):return not c.passed)
	var report={"engine":Engine.get_version_info().string,"platform":OS.get_name(),"display":DisplayServer.get_name(),"checks":checks,"failures":failures.size(),"performance":{"off":off,"on":on,"target_p95_ms":16.7,"target_met":on.p95_ms<=16.7},"frame_timing":"Monotonic wall clock between rendered frames, not fixed physics delta; warmup excluded"}
	var file:=FileAccess.open(out+"native.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"))
	print("LIGHTING_COMPLETE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
