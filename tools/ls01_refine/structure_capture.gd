extends SceneTree
var out := "res://docs/validation/ls01-refine-v2/"
var lab: Node3D
func _initialize() -> void: run.call_deferred()
func shot(title: String, center: Vector3, distance: float, yaw: float, pitch: float) -> void:
	lab.center=center;lab.distance=distance;lab.yaw=yaw;lab.pitch=pitch;lab.update_camera();lab.update_label()
	for i in 25:await process_frame
	await RenderingServer.frame_post_draw
	var path=out+lab.gun.revision+"-"+OS.get_environment("ML09_VIEW")+"-"+title+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
func run() -> void:
	root.size=Vector2i(1600,1000)
	lab=load("res://scenes/weapon_lab.tscn").instantiate();root.add_child(lab)
	for i in 10:await process_frame
	lab.qa=true;lab.gun.set_energy_enabled(false);lab.gun.field_kit.set_ammo(13,20)
	for env in lab.get_children():
		if env is WorldEnvironment:env.environment.glow_enabled=false
	lab.mode=3 if OS.get_environment("ML09_VIEW")=="clay" else 0
	lab.gun.set_surface_mode(lab.mode)
	lab.set_rig(0)
	await shot("hero",Vector3(0,.025,-.21),1.18,1.08,.26)
	await shot("magazine",Vector3(.04,-.04,-.29),.32,PI/2,.16)
	await shot("magazine-reverse",Vector3(-.04,-.04,-.29),.32,-PI/2,.16)
	await shot("stock",Vector3(0,.025,.12),.40,1.18,.34)
	await shot("stock-reverse",Vector3(0,.025,.12),.40,-1.18,.34)
	await shot("joint",Vector3(.02,.07,.035),.23,1.18,.34)
	await shot("optic",Vector3(0,.163,-.057),.30,0,.04)
	await shot("optic-side",Vector3(0,.150,-.057),.31,1.2,.18)
	await shot("optic-front",Vector3(0,.163,-.057),.30,PI,.04)
	await shot("screen",Vector3(0,.109,.012),.22,0,.78)
	await shot("screen-side",Vector3(0,.109,.012),.24,1.0,.40)
	await shot("coil",Vector3(0,.045,-.49),.37,PI/2,.15)
	await shot("coil-reverse",Vector3(0,.045,-.49),.37,-PI/2,.15)
	if lab.mode==0:
		for rig in [1,2]:
			lab.set_rig(rig);await shot("magazine-rig-%d"%rig,Vector3(.04,-.04,-.29),.32,PI/2,.16)
	quit()
