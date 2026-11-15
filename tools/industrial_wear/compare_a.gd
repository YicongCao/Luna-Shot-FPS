extends SceneTree
var out: String
func _initialize() -> void: run.call_deferred()
func frames(n: int=24) -> void:
	for i in n:await process_frame
func shot(name: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out+name+".png")==OK)
func run() -> void:
	var phase: String=OS.get_cmdline_user_args()[0]
	out="res://docs/validation/industrial-wear-v1/A/"+phase+"/";DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,800)
	var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	var player: CharacterBody3D=world.player;player.qa_mode=true;player.blocked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await frames(90)
	# Identical world camera, lighting and placement; A03 faces the southern perimeter road.
	for distance in [3]:
		player.position=Vector3(-18,.05,22+distance)
		player.camera.look_at(Vector3(-18,.65,22))
		await shot("range-"+str(distance)+"m")
	player.position=Vector3(-14.2,.05,25.8);player.camera.look_at(Vector3(-18,.65,22))
	await shot("range-interface")
	world.set_overview(true);await shot("overview")
	world.queue_free();await frames(5)
	# Native asset turntable: same neutral studio and four view directions.
	var stage:=Node3D.new();root.add_child(stage)
	var model: Node3D=load("res://assets/environment/A/A.glb").instantiate();stage.add_child(model)
	var env:=WorldEnvironment.new();env.environment=load("res://scripts/weapon_lighting.gd").environment();env.environment.glow_enabled=false;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-35,0);sun.light_energy=1.1;stage.add_child(sun)
	var cam:=Camera3D.new();stage.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=5.2;cam.current=true
	for mode in [0,1,2]:
		var mat: StandardMaterial3D=load("res://scripts/environment_material.gd").create("A",mode)
		for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		for view in [["front",Vector3(1,.8,1)],["back",Vector3(-1,.8,-1)],["left",Vector3(-1,.25,0)],["right",Vector3(1,.25,0)],["top",Vector3(0,1,.01)]]:
			if mode!=0 and view[0]!="front":continue
			cam.position=Vector3(0,.6,0)+view[1]*8;cam.look_at(Vector3(0,.6,0))
			await shot(str(mode)+"-"+view[0])
	for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=load("res://scripts/environment_material.gd").create("A",0)
	cam.projection=Camera3D.PROJECTION_PERSPECTIVE;cam.fov=72
	for distance in [3,10,20]:
		cam.position=Vector3(0,1.65,distance+1.8);cam.look_at(Vector3(0,.65,0))
		await shot("distance-"+str(distance)+"m")
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=1.55
	cam.position=Vector3(.93,2.4,1.4);cam.look_at(Vector3(.93,1.18,.89))
	await shot("lid-close")
	print("A_COMPARE_COMPLETE ",phase);quit()
