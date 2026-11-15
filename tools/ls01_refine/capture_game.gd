extends SceneTree
var out="res://docs/validation/ls01-refine-v1/"+OS.get_environment("LS01_CAPTURE_PREFIX")
func _initialize() -> void: run.call_deferred()
func frames(n: int=25) -> void:
	for i in n:await process_frame
func run() -> void:
	root.size=Vector2i(1600,1000)
	var world=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	await frames(100)
	var p=world.player;p.qa_mode=true;p.blocked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	p.weapon.position=p.HIP
	for ammo in [20,13,4,1,0]:
		p.ammo=ammo;await frames();await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"ammo-%02d.png"%ammo)
	p.ammo=13;p.weapon.position=p.ADS;p.weapon_camera.fov=52
	await frames();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"ads.png")
	quit()
