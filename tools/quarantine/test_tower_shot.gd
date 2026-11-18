extends SceneTree
## Deterministic scenic chapter comparison, not a run of the mission.
func _initialize() -> void: run.call_deferred()

func run() -> void:
	var out := OS.get_environment("TOWER_SHOT_OUTPUT")
	if out.is_empty(): out = "res://artifacts/tower-shot"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var reel: Node = load("res://scenes/quarantine_benchmark.tscn").instantiate()
	root.add_child(reel)
	reel.set_process(false)
	reel.player.set_process(false)
	# Don't let the initial player capsule inside the south extraction zone pause the fixture.
	reel.mission.set_physics_process(false)
	reel.mission.stage = reel.mission.EXTRACT
	reel.change_chapter(6)
	reel.curtain.color.a = 0
	for i in 150: await process_frame
	var cam: Camera3D = reel.player.camera
	var result := {}
	var world: Node = reel.mission.get_node("World")
	var ok: bool = RenderingServer.get_current_rendering_method()=="forward_plus" and world.energy_column.visible and not paused and world.energy_material.get_shader_parameter("power") >= .99
	result["power"] = world.energy_material.get_shader_parameter("power")
	var wide := reel.tower_wide as bool
	for mode in [false,true]:
		reel.tower_wide = mode
		var prefix := "wide" if mode else "baseline"
		var edges: Array[float] = []
		for i in 101:
			reel.tower_shot(i*.1)
			var rect := cam.get_viewport().get_visible_rect().size
			for y: float in [0.,23.]:
				var target := Vector3(0,y,0)
				var uv := cam.unproject_position(target)/rect
				var margin := minf(minf(uv.x,1.-uv.x),minf(uv.y,1.-uv.y)) if not cam.is_position_behind(target) else -1.
				edges.append(margin)
			if i in [5,50,95]:
				for j in 5: await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				ok = image.save_webp(out+"/"+prefix+"-%02d.webp"%i,false,.94)==OK and ok
		result[prefix+"_minimum_frame_margin"] = edges.min()
		if mode: ok = ok and edges.min() >= .025
	reel.tower_wide = wide
	result["passed"] = ok
	result["boundary"] = "101 samples of base/crown projection per camera; six native pictures for occlusion. Powered state is staged. No full playthrough claim."
	var f := FileAccess.open(out+"/checks.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(result,"\t")+"\n")
	f.close()
	print("TOWER SHOT ",result)
	reel.queue_free()
	for j in 5: await process_frame
	quit(0 if ok else 1)
