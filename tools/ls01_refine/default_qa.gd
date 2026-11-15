extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1000)
	var world=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	for i in 30:await process_frame
	var gun=world.player.weapon
	var expected=OS.get_environment("LS01_EXPECT")!="baseline"
	if gun.ls01!=expected:
		push_error("Default selection mismatch");quit(1);return
	if expected and (gun.atlas_materials.size()!=3 or gun.field_kit.cells.size()!=20):
		push_error("Default asset interfaces mismatch");quit(1);return
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/validation/ls01-refine-v1/default-native.png")
	print("DEFAULT_SELECTION_PASS ls01=",gun.ls01," expected=",expected)
	quit()
