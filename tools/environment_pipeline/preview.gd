extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var args:=OS.get_cmdline_user_args()
	var asset: String=args[0] if args.size()>0 else "A"
	var out: String="res://docs/validation/environment-pipeline-v1/"+asset+"/"
	DirAccess.make_dir_recursive_absolute(out)
	root.size=Vector2i(1280,900)
	var stage:=Node3D.new();root.add_child(stage)
	var model: Node3D=load("res://assets/environment/"+asset+"/"+asset+".glb").instantiate();stage.add_child(model)
	var env:=WorldEnvironment.new();env.environment=load("res://scripts/weapon_lighting.gd").environment();env.environment.glow_enabled=false;stage.add_child(env)
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-30,-35,0);sun.light_energy=1.1;stage.add_child(sun)
	var cam:=Camera3D.new();stage.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.current=true
	var height: float=1.2 if asset=="A" else (14.2 if asset=="E" else (6.0 if asset.begins_with("B") else 3.5))
	var extent: float=17 if asset=="D" else (12 if asset=="C" else (18 if asset=="E" else (9 if asset.begins_with("B") else 6)))
	cam.size=extent
	var center:=Vector3(0,height*.5,0)
	var positions: Dictionary={"front":Vector3(1,.65,1),"back":Vector3(-1,.65,-1),"left":Vector3(-1,.1,0),"right":Vector3(1,.1,0)}
	for mode in [0,1,2]:
		var mat: StandardMaterial3D=load("res://scripts/environment_material.gd").create(asset,mode)
		for mesh in model.find_children("*","MeshInstance3D",true,false):mesh.material_override=mat
		for title: String in positions:
			if mode!=0 and title!="front":continue
			cam.position=center+positions[title]*extent;cam.look_at(center)
			for i in 12:await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png(out+str(mode)+"-"+title+".png")==OK)
	print("ENVIRONMENT_PREVIEW_COMPLETE ",asset)
	quit()
