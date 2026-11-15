extends SceneTree
const OUT := "res://docs/validation/energy-whitebox-v2/"
func _initialize() -> void: run.call_deferred()
func capture(scene: Node3D, camera: Camera3D, title: String, eye: Vector3, focus: Vector3) -> void:
	camera.position=eye
	camera.look_at(focus)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(OUT+title+".png")==OK)
func run() -> void:
	var scene: Node3D=load("res://scenes/training.tscn").instantiate()
	root.add_child(scene)
	scene.player.qa_mode=true
	await process_frame
	scene.set_overview(true)
	var camera:=Camera3D.new()
	scene.add_child(camera)
	camera.fov=65
	camera.current=true
	await capture(scene,camera,"08-signal",Vector3(4,1.65,12),Vector3(0,6.5,0))
	for subtype in ["B1","B2"]:
		var module: Dictionary=scene.layout.modules.filter(func(m):return m.get("subtype","")==subtype)[0]
		var pos: Vector3=scene.vector(module.position)
		var instance: Node3D=scene.get_node("Facility/"+module.id)
		await capture(scene,camera,"09-"+subtype,instance.to_global(Vector3(4,2,7)),pos+Vector3(0,2.8,0))
	print("LANDMARK_CAPTURES_COMPLETE")
	quit()
