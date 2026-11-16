extends SceneTree
var out:="res://docs/validation/environment-refine-v2/final/release/"
func _initialize() -> void:run.call_deferred()
func capture(name: String) -> void:
	for i in 45:await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(out+name+".png")==OK)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out);root.size=Vector2i(1280,800)
	var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	world.player.qa_mode=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await capture("01-spawn")
	world.set_overview(true);await capture("02-overview")
	world.set_overview(false)
	world.player.position=Vector3(-21,.05,2);world.player.head.look_at(Vector3(-18,2.6,-2))
	await capture("03-bridge-side")
	print("ML15_RELEASE_CAPTURE native default assets, unchanged exposure");quit()
