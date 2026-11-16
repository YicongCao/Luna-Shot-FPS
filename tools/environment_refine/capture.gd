extends SceneTree
var out: String
var checks: Array=[]
func _initialize() -> void: run.call_deferred()
func frames(n:=12) -> void:
	for i in n: await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check":label,"passed":passed});print("ENV_CHECK ",label," ",passed)
func shot(name: String) -> Image:
	await frames();await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image();check("capture_"+name,im.save_png(out+name+".png")==OK);return im
func run() -> void:
	var asset:=OS.get_environment("ENV_ASSET")
	if asset.is_empty():asset="B1"
	var phase:=OS.get_environment("ENV_PHASE")
	out="res://docs/validation/environment-refine-v2/"+asset+"/"+phase+"/"
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,900)
	var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	world.player.qa_mode=true;world.set_overview(true);world.hud.hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var tower: Node3D
	for module in world.get_node("Facility").get_children()+world.get_node("Landmarks").get_children():
		if module.asset_id==asset and (OS.get_environment("ENV_MODULE_ID").is_empty() or str(module.name)==OS.get_environment("ENV_MODULE_ID")):tower=module;break
	var cam:=Camera3D.new();world.add_child(cam);cam.current=true;cam.fov=65
	cam.global_position=tower.to_global(Vector3(8,4,8));cam.look_at(tower.to_global(Vector3(0,3,0)))
	if asset in ["D","E"]:
		cam.global_position=tower.to_global(Vector3(14,10 if asset=="E" else 6,14));cam.look_at(tower.to_global(Vector3(0,7 if asset=="E" else 1.7,0)))
	await shot("range")
	var lamps:=tower.get_node_or_null("FacilityLamps")
	if lamps:
		check("fixture_count",lamps.fixtures.size()==({"B1":4,"B2":4,"C":4,"D":6,"E":1}[asset]))
		lamps.set_process(false);lamps.forced_level=1
		if asset=="E":lamps.phase=0;lamps.elapsed=.84
		lamps.refresh()
		world.lighting.set_bloom(false)
		if asset in ["B1","B2"]:
			cam.global_position=tower.to_global(Vector3(3.5,6.9,3.5));cam.look_at(tower.to_global(Vector3(0,5.7,0)));cam.fov=48
		else:
			var fixture: Dictionary=lamps.fixtures[1 if asset=="D" else 0]
			var local: Vector3=tower.to_local(fixture.mesh.global_position)
			cam.global_position=tower.to_global(local+Vector3(-3,1.1,2));cam.look_at(fixture.mesh.global_position);cam.fov=48
			world.lighting.sun.light_energy=.08;world.lighting.environment.ambient_light_energy=.07
		await shot("lights-on-no-bloom")
		# Hold lamp emission fixed; compare only real local illumination.
		var lit:=root.get_texture().get_image()
		world.lighting.set_process(false)
		for light in world.lighting.module_light_pool:light.visible=false
		world.lighting.beacon_spot.visible=false
		var unlit:=await shot("emission-only")
		var changed:=0
		for y in range(0,900,2):
			for x in range(0,1280,2):
				var a:=lit.get_pixel(x,y);var b:=unlit.get_pixel(x,y)
				if (a.b-b.b if asset in ["C","D"] else a.r-b.r)>.015:changed+=1
		check("real_local_spill_pixels",changed>20)
		world.lighting.set_process(true)
		lamps.forced_level=0;lamps.refresh();await shot("lights-off")
		lamps.forced_level=1;lamps.refresh();world.lighting.set_bloom(true);await shot("lights-bloom")
		lamps.forced_level=-1;lamps.phase=0;lamps.elapsed=.12;lamps.refresh()
		if asset in ["B1","B2"]:
			check("red_pulse_on",lamps.fixtures[0].level>.99)
			lamps.elapsed=.5;lamps.refresh();check("red_pulse_off",lamps.fixtures[0].level==0)
		elif asset in ["C","D"]:check("blue_constant",lamps.fixtures.all(func(f):return f.level==1))
		elif asset=="E":
			lamps.elapsed=.08;lamps.refresh();check("amber_pulse_peak",lamps.fixtures[0].level>.99)
			lamps.elapsed=.5;lamps.refresh();check("amber_between_pulses",is_equal_approx(lamps.fixtures[0].level,.35))
			lamps.elapsed=.25;lamps.refresh();check("one_revolution_per_second",is_equal_approx(lamps.fixtures[0].beacon.rotor.rotation.y,PI*.5))
			var first: Image
			for step in 4:
				lamps.elapsed=.1+step*.25;lamps.refresh()
				var phase_image:=await shot("beacon-phase-"+str(step))
				if step==0:first=phase_image
				if step==2:
					var changed_pixels:=0
					for y in range(0,900,2):
						for x in range(0,1280,2):
							if absf(first.get_pixel(x,y).r-phase_image.get_pixel(x,y).r)>.025:changed_pixels+=1
					check("rotating_sector_visible_pixels",changed_pixels>30)
			var beam_dir: Vector3=lamps.fixtures[0].beacon.rotor.global_basis.z-Vector3.UP*.65
			check("spot_tracks_rotor",(-world.lighting.beacon_spot.global_basis.z).dot(beam_dir.normalized())>.999)
		lamps.set_process(true);world.set_paused(true);var t: float=lamps.elapsed;await frames(10);check("pause_freezes_phase",lamps.elapsed==t);world.set_paused(false)
		if "--demo" in OS.get_cmdline_user_args():
			world.lighting.set_bloom(false)
			print("DEMO_START_FRAME ",Engine.get_process_frames())
			if asset in ["C","D"]:
				var start:=cam.global_position;var right:=cam.global_basis.x
				var target: Vector3=lamps.fixtures[1 if asset=="D" else 0].mesh.global_position
				for i in 300:
					cam.global_position=start+right*.4*sin(float(i)/300.0*TAU);cam.look_at(target);await process_frame
			else:await frames(300)
			print("DEMO_END_FRAME ",Engine.get_process_frames())
	world.queue_free();await frames(5)
	var stage:=Node3D.new();root.add_child(stage)
	var model:=Node3D.new();model.set_script(load("res://scripts/module_visual.gd"));model.asset_id=asset;stage.add_child(model)
	var env:=WorldEnvironment.new();env.environment=load("res://scripts/weapon_lighting.gd").environment();env.environment.glow_enabled=false;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-35,0);sun.light_energy=1.1;stage.add_child(sun)
	cam=Camera3D.new();stage.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size={"B1":7.6,"B2":7.6,"C":11.0,"D":15.0,"E":17.0}[asset];cam.current=true
	var gray:=StandardMaterial3D.new();gray.albedo_color=Color(.5,.5,.5);gray.roughness=.65
	var meshes:=model.get_node("FinalVisual").find_children("*","MeshInstance3D",true,false)
	var mats: Array=[]
	for mesh in meshes:mats.append(mesh.material_override)
	var center:=Vector3(0,7 if asset=="E" else (1.7 if asset in ["C","D"] else 2.8),0)
	for mode in ["gray","pbr"]:
		for i in meshes.size():meshes[i].material_override=gray if mode=="gray" else mats[i]
		for view in [["front",Vector3(1,.65,1)],["back",Vector3(-1,.6,-1)],["left",Vector3(-1,.2,0)],["right",Vector3(1,.2,0)]]:
			cam.position=center+view[1]*20;cam.look_at(center);await shot(mode+"-"+view[0])
	sun.rotation_degrees=Vector3(-6,-35,0);await shot("pbr-grazing");sun.rotation_degrees=Vector3(-30,-35,0)
	cam.projection=Camera3D.PROJECTION_PERSPECTIVE;cam.fov=65
	for distance in [3,10,20]:
		cam.position=Vector3(0,1.65,distance+1.8);cam.look_at(Vector3(0,7 if asset=="E" else 3,0));await shot("distance-"+str(distance))
	var failures:=checks.filter(func(c):return not c.passed).size()
	FileAccess.open(out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("ENV_CAPTURE_COMPLETE ",phase," failures=",failures);quit(0 if failures==0 else 1)
