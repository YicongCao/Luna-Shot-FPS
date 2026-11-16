extends SceneTree
var lab: Node3D
var out := "res://docs/validation/ls01-refine-v2/"
var checks: Array=[]
var probes: Dictionary={}
func _initialize() -> void: run.call_deferred()
func frames(n: int=25) -> void:
	for i in n:await process_frame
func shot(name: String) -> Image:
	await frames();await RenderingServer.frame_post_draw
	var im=root.get_texture().get_image();im.save_png(out+name+".png");return im
func run() -> void:
	root.size=Vector2i(1600,1000);lab=load("res://scenes/weapon_lab.tscn").instantiate();root.add_child(lab)
	await frames();lab.qa=true;lab.gun.set_energy_enabled(true)
	for env in lab.get_children():
		if env is WorldEnvironment:env.environment.glow_enabled=false
	lab.key.light_energy=.38;lab.fill.light_energy=.08
	lab.center=Vector3(0,.03,-.30);lab.distance=.72;lab.pitch=.15
	for side in [-1,1]:
		lab.yaw=side*PI/2;lab.update_camera()
		var regions={"receiver":Vector3(side*.055,.083,-.268),"copper_well":Vector3(side*.064,.055,-.19),"magazine_rim":Vector3(side*.056,-.020,-.29),"shroud":Vector3(side*.050,.016,-.44)}
		probes[str(side)]={}
		for region in regions:
			var pixel=lab.camera.unproject_position(regions[region]);probes[str(side)][region]=[pixel.x,pixel.y]
		lab.gun.set_spill_enabled(false);await shot("spill-%s-off"%side)
		lab.gun.set_spill_enabled(true);await shot("spill-%s-on"%side)
	var spots=[]
	for light in lab.gun.energy_lights:
		if light is SpotLight3D:spots.append(light)
	checks.append({"check":"two shadowed side lights","passed":spots.size()==2 and spots.all(func(l):return l.shadow_enabled)})
	# Test receiver shadow against actual geometry at fixed camera/exposure. Block only
	# the near-side light, then compare shadow-on/off with the blocker still present.
	lab.yaw=PI/2;lab.update_camera()
	var blocker:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.045,.15,.005);blocker.mesh=box;blocker.position=Vector3(.074,.025,-.342)
	blocker.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY;lab.gun.add_child(blocker)
	await shot("spill-blocker-shadow-on")
	for l in spots:l.shadow_enabled=false
	await shot("spill-blocker-shadow-off")
	for l in spots:l.shadow_enabled=true
	blocker.queue_free()
	lab.gun.set_energy_enabled(false);checks.append({"check":"energy off hides all four lights","passed":lab.gun.energy_lights.all(func(l):return not l.visible)})
	lab.gun.set_energy_enabled(true);lab.gun.set_spill_enabled(false);checks.append({"check":"spill off hides all four lights","passed":lab.gun.energy_lights.all(func(l):return not l.visible)})
	var pf=FileAccess.open(out+"spill-probes.json",FileAccess.WRITE);pf.store_string(JSON.stringify(probes,"  "));pf.close()
	var f=FileAccess.open(out+"spill-controls.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"  "));quit(0 if checks.all(func(c):return c.passed) else 1)
