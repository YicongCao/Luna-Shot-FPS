extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1000)
	var w=load("res://scenes/training.tscn").instantiate();root.add_child(w)
	for i in 150: await process_frame
	w.player.qa_mode=true;w.player.blocked=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var times=[];var last=Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now=Time.get_ticks_usec();times.append((now-last)/1000.0);last=now
	times.sort()
	var result={"p50_ms":times[300],"p95_ms":times[570],"frames":600,"ls01":w.player.weapon.ls01,"last_flare_sample_usec":w.lighting.flare_pass.sample_cost_usec,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"viewport":"1600x1000","engine":Engine.get_version_info().string,"objects":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"texture_memory":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)}
	var phase=OS.get_environment("LS01_PHASE")
	var f=FileAccess.open("res://docs/validation/ls01-refine-v1/performance-"+phase+".json",FileAccess.WRITE);f.store_string(JSON.stringify(result,"  "))
	quit()
