extends SceneTree
var world: Node3D
var checks: Array=[]
var out:="res://docs/validation/ground-v1/sample/"
func _initialize() -> void:run.call_deferred()
func frames(n:=20) -> void:
	for i in n:await process_frame
func check(name: String,value: bool,detail: Variant=null) -> void:
	checks.append({"check":name,"passed":value,"detail":detail});print("GROUND_CHECK ",name," ",value)
func shot(name: String) -> Image:
	await frames();await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image();check("capture_"+name,im.save_png(out+name+".png")==OK);return im
func walk(to: Vector3,label: String) -> void:
	var player: CharacterBody3D=world.player
	for i in 220:
		var diff:=to-player.position;diff.y=0
		if diff.length()<.12:break
		player.qa_direction=diff.normalized();await physics_frame
	player.qa_direction=Vector3.ZERO
	for i in 8:await physics_frame
	check(label,Vector2(player.position.x-to.x,player.position.z-to.z).length()<.2 and absf(player.position.y)<.02,player.position)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,800)
	world=load("res://scenes/ground_studio.tscn").instantiate();root.add_child(world);world.player.qa_mode=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var surface: Node3D=world.get_node("GroundSurface")
	check("8x8_base",world.get_node("Ground/Collision").shape.size==Vector3(8,.6,8))
	check("one_A_seat_one_cover",surface.counts.seats==1 and surface.counts.covers==1)
	check("no_new_ground_colliders",surface.find_children("*","CollisionShape3D",true,false).is_empty())
	await frames(30)
	await walk(Vector3(-2,0,-3),"road_forward_capsule")
	await walk(Vector3(-2,0,2),"road_return_capsule")
	await walk(Vector3(2.8,0,2),"cover_and_soil_edge_capsule")
	await walk(Vector3(2.8,0,3.5),"soil_capsule")
	world.reset_range();world.player.qa_mode=true;await frames(20);world.player.blocked=true
	world.lighting.flares_enabled=false;world.lighting.set_bloom(false)
	for phase in ["before","after"]:
		surface.set_baseline(phase=="before");world.set_overview(false);world.player.blocked=true;world.hud.show()
		world.player.head.look_at(Vector3(1,.5,-1));await shot(phase+"-first-person")
		world.set_overview(true);world.hud.hide()
		var cam:=Camera3D.new();world.add_child(cam);cam.current=true;cam.fov=58
		for view in [["overview",Vector3(7,7,9),Vector3(0,0,0)],["cover",Vector3(3.4,.75,3.2),Vector3(1.5,0,1.4)],["soil",Vector3(3.7,.50,4.1),Vector3(2.6,0,3.2)],["seat",Vector3(-.5,.7,1),Vector3(1.5,.05,-.4)]]:
			cam.position=view[1];cam.look_at(view[2]);await shot(phase+"-"+view[0])
		if phase=="after":
			cam.position=Vector3(-2,.40,2);cam.look_at(Vector3(-1,0,0));var normal:=await shot("grazing-normal")
			surface.surface.set_shader_parameter("normal_strength",0.0);var flat:=await shot("grazing-flat")
			var pixels:=0
			for y in range(0,800,2):
				for x in range(0,1280,2):
					if absf(normal.get_pixel(x,y).r-flat.get_pixel(x,y).r)>.015:pixels+=1
			check("native_normal_response",pixels>100,pixels);surface.surface.set_shader_parameter("normal_strength",.75)
			world.lighting.sun.rotation_degrees=Vector3(-8,50,0);await shot("alternate-grazing-direction")
		cam.queue_free();await frames(2)
	var failures:=checks.filter(func(c):return not c.passed).size()
	FileAccess.open(out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"scope":"8x8 native sample, same camera/exposure, Bloom off; real player capsule; not user visual acceptance"},"\t"));print("GROUND_SAMPLE_COMPLETE ",failures);quit(0 if failures==0 else 1)
