extends SceneTree
# Native comparison only: replace the live mask without modifying published assets.
const OUT := "res://docs/validation/ground-coverage/"
var checks: Array = []
func _initialize() -> void:
	run.call_deferred()
func frames(count: int = 30) -> void:
	for i in count: await process_frame
func check(label: String, passed: bool) -> void:
	checks.append({"check": label, "passed": passed})
	print("COVERAGE ", label, " ", passed)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1600, 1000)
	var world: Node3D = load("res://scenes/training.tscn").instantiate()
	root.add_child(world)
	world.player.qa_mode = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await frames(90)
	var floor: Node3D = world.get_node("GroundSurface")
	if floor.surface == null:
		push_error("Published ML16 ground required"); quit(1); return
	var original: Texture2D = floor.surface.get_shader_parameter("soil_mask")
	var mixed: Texture2D = ImageTexture.create_from_image(floor.make_field_mask(world.layout))
	var masks := {"mixed": mixed}
	for mode in ["regolith", "paving"]:
		var mask := Image.create(4, 4, false, Image.FORMAT_R8)
		mask.fill(Color.WHITE if mode == "regolith" else Color.BLACK)
		masks[mode] = ImageTexture.create_from_image(mask)
		check(mode + "_uniform_mask", mask.get_data().count(255 if mode == "regolith" else 0) == 16)
	# Freeze time so lamps, fan blades, weapon and exposure match all three variants.
	world.set_paused(true)
	world.pause_panel.hide()
	world.lighting.flares_enabled = false
	world.lighting.set_bloom(false)
	for view in ["player", "overview", "close"]:
		world.set_overview(view == "overview")
		world.player.blocked = true
		world.hud.visible = view == "player"
		var camera: Camera3D
		if view == "player":
			world.player.reset_position()
			world.player.head.look_at(Vector3(0, .2, 7))
		elif view == "close":
			world.player.get_node("WeaponLayer").hide()
			camera = Camera3D.new()
			world.add_child(camera)
			camera.current = true
			camera.fov = 64
			camera.position = Vector3(1, 1.65, 15)
			camera.look_at(Vector3(2.8, 0, 8))
		for mode in ["mixed", "regolith", "paving"]:
			floor.surface.set_shader_parameter("soil_mask", masks[mode])
			await frames()
			await RenderingServer.frame_post_draw
			check(view + "_" + mode, root.get_texture().get_image().save_png(OUT + view + "-" + mode + ".png") == OK)
		if camera:
			camera.queue_free()
			await frames(2)
	floor.surface.set_shader_parameter("soil_mask", original)
	check("published_mask_restored", floor.surface.get_shader_parameter("soil_mask") == original)
	var failures := checks.filter(func(c): return not c.passed).size()
	FileAccess.open(OUT + "checks.json", FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "renderer": RenderingServer.get_current_rendering_method(), "engine": Engine.get_version_info().string, "resolution": [1600, 1000], "bloom": false, "flares": false, "published_assets_changed": false}, "\t"))
	quit(0 if failures == 0 else 1)
