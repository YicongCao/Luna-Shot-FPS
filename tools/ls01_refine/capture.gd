extends SceneTree
var out=(OS.get_environment("LS01_REPORT_DIR")+"/" if OS.has_environment("LS01_REPORT_DIR") else "res://docs/validation/ls01-refine-v1/")+""+OS.get_environment("LS01_CAPTURE_PREFIX")
func _initialize() -> void: run.call_deferred()
func shot(name: String) -> void:
	for i in 35:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+name+".png")
func run() -> void:
	root.size=Vector2i(1600,1000)
	var lab=load("res://scenes/weapon_lab.tscn").instantiate();root.add_child(lab)
	for i in 10:await process_frame
	lab.qa=true;lab.gun.set_energy_enabled(false)
	lab.gun.field_kit.set_ammo(13,20)
	for env in lab.get_children():
		if env is WorldEnvironment:env.environment.glow_enabled=false
	for rig in [0,1,2]:
		lab.set_rig(rig);lab.update_label();await shot("studio-%d"%rig)
	lab.set_rig(0);lab.gun.set_surface_mode(3);lab.mode=3;lab.update_label();await shot("clay")
	lab.gun.set_surface_mode(0);lab.mode=0;lab.update_label();lab.center=Vector3(.04,-.04,-.29);lab.distance=.30;lab.yaw=PI/2;lab.pitch=.16;lab.update_camera();lab.update_label();await shot("magazine")
	for i in 3:
		lab.set_rig(i);lab.update_label();await shot("magazine-light-%d"%i)
	if lab.gun.ls01:
		for mode in [4,5,6,7,8]:
			lab.mode=mode;lab.gun.set_surface_mode(mode);lab.update_label();await shot("magazine-channel-%d"%mode)
		lab.mode=0;lab.gun.set_surface_mode(0);lab.update_label()
	lab.set_rig(0);lab.center=Vector3(.02,.08,-.09);lab.distance=.30;lab.yaw=1.13;lab.pitch=.40;lab.update_camera();lab.update_label();await shot("kit-close")
	lab.center=Vector3(0,.03,-.18);lab.distance=1.28;lab.yaw=-PI/2;lab.pitch=.10;lab.update_camera();lab.update_label();await shot("reverse")
	lab.set_rig(0);lab.center=Vector3(0,.109,.012);lab.distance=.20;lab.yaw=.0;lab.pitch=.78;lab.update_camera();lab.update_label();await shot("screen-close")
	lab.center=Vector3(.05,.083,-.015);lab.distance=.16;lab.yaw=PI/2;lab.pitch=.06;lab.update_camera();lab.update_label();await shot("screw-close")
	lab.center=Vector3(0,.045,-.49);lab.distance=.35;lab.yaw=PI/2;lab.pitch=.15;lab.update_camera();lab.update_label();await shot("front-fasteners")
	lab.yaw=-PI/2;lab.update_camera();await shot("front-fasteners-reverse")
	quit()
