extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1000)
	var lab=load("res://scenes/weapon_lab.tscn").instantiate();root.add_child(lab)
	for i in 10:await process_frame
	lab.qa=true;lab.gun.set_energy_enabled(false);lab.center=Vector3(-.04,-.04,-.29);lab.distance=.32;lab.yaw=-PI/2;lab.pitch=.16;lab.update_camera()
	for mode in [0,1,4,6,8]:
		lab.mode=mode;lab.gun.set_surface_mode(mode);lab.update_label()
		for i in 20:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/ls01-refine-v2/reverse-channel-%d.png"%mode)
	quit()
