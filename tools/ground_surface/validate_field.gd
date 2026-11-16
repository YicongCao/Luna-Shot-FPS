extends SceneTree
var checks: Array=[]
var out:="res://docs/validation/ground-paved/field/"
func _initialize() -> void:run.call_deferred()
func frames(n:=24) -> void:
	for i in n:await process_frame
func check(label: String,value: bool,detail: Variant=null) -> void:
	checks.append({"check":label,"passed":value,"detail":detail});print("GROUND_FIELD ",label," ",value)
func shot(name: String) -> void:
	await frames();await RenderingServer.frame_post_draw
	check("capture_"+name,root.get_texture().get_image().save_png(out+name+".png")==OK)
func run() -> void:
	if not OS.get_environment("GROUND_QA_OUTPUT").is_empty():out="res://"+OS.get_environment("GROUND_QA_OUTPUT").trim_suffix("/")+"/"
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,800)
	var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	world.player.qa_mode=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var floor: Node3D=world.get_node("GroundSurface")
	check("candidate_loaded",floor.surface!=null)
	if floor.surface==null:quit(1);return
	for kind in ["paving","regolith","metal"]:
		for channel in ["BaseColor","ORM","NormalGL"]:
			var tex: Texture2D=load("res://assets/environment/ground_v1/"+kind+"/"+channel+".png")
			var image:=tex.get_image()
			check(kind+"_"+channel+"_2k_compressed_mips",image.get_size()==Vector2i(2048,2048) and image.has_mipmaps() and image.is_compressed())
	check("40_seats_8_shared_covers",floor.counts.seats==40 and floor.counts.covers==8,floor.counts)
	check("no_new_colliders",floor.find_children("*","CollisionShape3D",true,false).is_empty())
	var mask: Image=floor.surface.get_shader_parameter("soil_mask").get_image();mask.save_png(out+"soil-mask.png")
	check("default_is_full_paving",mask.get_data().count(0)==mask.get_data().size())
	var route_samples:=0;var contaminated:=0
	for name in world.layout.routes:
		var route: Array=world.layout.routes[name]
		for i in range(1,route.size()):
			var a:=Vector2(route[i-1][0],route[i-1][2]);var b:=Vector2(route[i][0],route[i][2])
			for t in range(101):
				var point:=a.lerp(b,t/100.0);var uv:=(point+Vector2(32,33))/Vector2(64,66)*Vector2(mask.get_size())
				route_samples+=1
				if mask.get_pixel(clampi(int(uv.x),0,mask.get_width()-1),clampi(int(uv.y),0,mask.get_height()-1)).r>.01:contaminated+=1
	check("routes_keep_paving",contaminated==0,{"samples":route_samples,"soil_hits":contaminated})
	var duplicate: Image=floor.make_paved_mask()
	check("mask_is_deterministic",mask.get_data()==duplicate.get_data())
	world.lighting.flares_enabled=false;world.lighting.set_bloom(false);world.set_paused(true);world.pause_panel.hide()
	for phase in ["before","after"]:
		floor.set_baseline(phase=="before");world.set_overview(false);world.player.blocked=true;world.hud.show()
		world.player.reset_position();world.player.head.look_at(Vector3(0,0,8));await shot(phase+"-spawn")
		world.set_overview(true);world.hud.hide();await shot(phase+"-overview")
		var cam:=Camera3D.new();world.add_child(cam);cam.current=true;cam.fov=64
		for view in [["road",Vector3(1,1.65,15),Vector3(2.8,0,8)],["equipment",Vector3(-13,2.2,19),Vector3(-18,.4,24)],["underbridge",Vector3(-21,1.6,3),Vector3(-18,1,0)]]:
			cam.position=view[1];cam.look_at(view[2]);await shot(phase+"-"+view[0])
		cam.queue_free();await frames(2)
	floor.set_baseline(false);world.set_paused(false);world.lighting.set_bloom(true)
	var failure:=checks.filter(func(c):return not c.passed).size()
	FileAccess.open(out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failure,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string},"\t"));print("GROUND_FIELD_COMPLETE ",failure);quit(0 if failure==0 else 1)
