extends SceneTree
var out:="res://docs/validation/environment-refine-v2/final/markings/"
var results: Array=[]
func _initialize() -> void:run.call_deferred()
func frames(n:=30) -> void:
	for i in n:await process_frame
func shot(name: String) -> Image:
	await frames();await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image();im.save_png(out+name+".png");return im
func check(label: String, value: bool, detail: Variant=null) -> void:
	results.append({"check":label,"passed":value,"detail":detail})
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,800)
	var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	world.player.qa_mode=true;world.set_overview(true);world.hud.hide();world.set_paused(true);world.pause_panel.hide()
	world.lighting.set_bloom(false);world.lighting.flares_enabled=false;world.lighting.set_facility_enabled(false)
	var markings: Node3D=world.get_node("ReflectiveMarkings")
	check("48_segmented_edge_markings",markings.strips.size()==48,markings.strips.size())
	check("same_geometry_grid_batch",markings.get_node("SharedGroundGrid").multimesh.instance_count==132)
	var cam:=Camera3D.new();world.add_child(cam);cam.current=true;cam.fov=58
	cam.position=Vector3(2,1.1,22);cam.look_at(Vector3(0,.03,20))
	await shot("sunlight")
	world.lighting.sun.light_energy=0;world.lighting.environment.ambient_light_energy=.025
	world.lighting.environment.reflected_light_source=Environment.REFLECTION_SOURCE_DISABLED
	for child in world.lighting.get_children():
		if child is ReflectionProbe:child.visible=false
	var lamp:=SpotLight3D.new();world.add_child(lamp);lamp.position=Vector3(-2,2,16.4);lamp.look_at(Vector3(0,0,20));lamp.spot_range=10;lamp.spot_angle=45;lamp.light_energy=8
	var polished:=await shot("grazing-reflection")
	markings.paint.set_shader_parameter("specular_strength",0.0)
	var matte:=await shot("same-light-specular-disabled")
	var changed:=0;var peak:=0.0
	for y in 800:
		for x in 1280:
			var a:=polished.get_pixel(x,y);var b:=matte.get_pixel(x,y);var d:=maxf(a.r-b.r,a.g-b.g)
			peak=maxf(peak,d)
			if d>.02:changed+=1
	check("paint_has_real_specular_response",changed>50,{"pixels":changed,"peak":peak})
	markings.paint.set_shader_parameter("specular_strength",.5)
	cam.position=Vector3(-2,1.1,22);cam.look_at(Vector3(0,.03,20));await shot("alternate-view")
	lamp.light_energy=0;world.lighting.environment.ambient_light_energy=0
	var dark:=await shot("unlit-no-emission")
	var dark_samples: Array[float]=[]
	for x in [-1.0,0.0,1.0]:
		var pixel:=cam.unproject_position(Vector3(x,.028,20));var color:=dark.get_pixel(int(pixel.x),int(pixel.y));dark_samples.append(maxf(color.r,maxf(color.g,color.b)))
	check("unlit_paint_pixels_are_dark",dark_samples.all(func(v):return v<.05),dark_samples)
	check("paint_shader_is_nonmetal_nonemissive",markings.paint.shader.code.contains("METALLIC=0.0") and markings.paint.shader.code.contains("EMISSION=vec3(0.0)"))
	world.lighting.sun.light_energy=1.15;world.lighting.environment.ambient_light_energy=.24;world.lighting.set_facility_enabled(true);world.lighting.set_bloom(true)
	cam.position=Vector3(33,32,39);cam.look_at(Vector3(0,0,0));await shot("overview")
	var failures:=results.filter(func(c):return not c.passed).size()
	FileAccess.open(out+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":results,"failures":failures},"\t"));print("MARKINGS_CHECKS ",results);quit(0 if failures==0 else 1)
