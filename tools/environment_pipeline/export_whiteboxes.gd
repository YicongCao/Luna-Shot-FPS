extends SceneTree
const OUT := "res://art_source/environment/pipeline-v1/00-whitebox/"
func _initialize() -> void: run.call_deferred()
func strip_non_visual(node: Node) -> void:
	for child in node.get_children():
		if child is CollisionShape3D or child is Label3D or child is Marker3D:
			child.free()
		else: strip_non_visual(child)
func run() -> void:
	root.size=Vector2i(1024,1024)
	var stage:=Node3D.new()
	root.add_child(stage)
	var env:=WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.18,.20,.23)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.65
	stage.add_child(env)
	var sun:=DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.light_energy=1.1
	stage.add_child(sun)
	var camera:=Camera3D.new()
	stage.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL
	camera.current=true
	var specs: Dictionary={"A":["A",1.2,6.5],"B1":["B1",6,9],"B2":["B2",6,9],"C":["C",3.5,12],"D":["D",3.5,17],"E":["Signal",14.2,18]}
	for id: String in specs:
		var spec: Array=specs[id]
		var model: Node3D=load("res://assets/industrial/module_"+spec[0]+".tscn").instantiate()
		# Never activate the final-visual wrapper while exporting the B0 reference.
		model.set_script(null)
		stage.add_child(model)
		strip_non_visual(model)
		camera.size=spec[2]
		var focus:=Vector3(0,float(spec[1])*.5,0)
		camera.position=focus+Vector3(10,7,14)
		camera.look_at(focus)
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(OUT+id+"-reference.png")==OK)
		var doc:=GLTFDocument.new()
		var state:=GLTFState.new()
		assert(doc.append_from_scene(model,state)==OK)
		assert(doc.write_to_filesystem(state,OUT+id+"-whitebox.glb")==OK)
		model.free()
	print("WHITEBOX_EXPORT_COMPLETE six isolated references and GLBs; gameplay collision unchanged")
	quit()
