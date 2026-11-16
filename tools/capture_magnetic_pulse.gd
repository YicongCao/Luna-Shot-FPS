extends SceneTree
# Godot native Movie Maker: fixed 60 Hz simulation, real effect durations, not a benchmark.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280,800)
	var w = load("res://scenes/training.tscn").instantiate()
	root.add_child(w)
	var p = w.player
	p.qa_mode = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for i in 30: await process_frame
	p.position = w.vector(w.layout.targets[0].shoot_from)
	p.head.look_at(w.get_node("Target1").position + Vector3(0,1.5,0))
	for frame in 420:
		if frame == 210: p.reload_weapon()
		if frame == 310:
			for target in get_nodes_in_group("targets"): target.reset()
			p.aiming = true
		if frame in [30,65] or (frame >= 100 and frame < 200 and frame % 10 == 0) or (frame >= 340 and frame < 390 and frame % 10 == 0):
			if p.fire(): p.fire_effect.sound.play()
		await process_frame
	quit()
