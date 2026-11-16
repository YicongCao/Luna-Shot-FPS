extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1600,1000)
	var world: Node3D=load("res://scenes/training.tscn").instantiate()
	root.add_child(world)
	world.player.qa_mode=true
	world.set_overview(true)
	world.hud.hide()
	var cam:=Camera3D.new();world.add_child(cam);cam.current=true
	var started:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-started<3000:
		cam.position=Vector3(15,5,17);cam.look_at(Vector3(0,3,0));await process_frame
	var samples: Array[float]=[]
	started=Time.get_ticks_msec();var last:=Time.get_ticks_usec()
	while Time.get_ticks_msec()-started<60000:
		var t: float=(Time.get_ticks_msec()-started)/60000.0
		cam.position=Vector3(sin(t*TAU)*25,5+3*sin(t*PI),cos(t*TAU)*25)
		cam.look_at(Vector3(0,3,0))
		await process_frame
		var now:=Time.get_ticks_usec();samples.append((now-last)/1000.0);last=now
	samples.sort()
	var out:=OS.get_environment("ENV_QA_OUT")
	DirAccess.make_dir_recursive_absolute(out)
	var result={"seconds":(Time.get_ticks_msec()-started)/1000.0,"frames":samples.size(),"p50_ms":samples[int(samples.size()*.5)],"p95_ms":samples[int(samples.size()*.95)],"engine":Engine.get_version_info().string,"viewport":"1600x1000","primitives_last_frame":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"objects_last_frame":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)}
	FileAccess.open(out+"/performance.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ENV_PERFORMANCE ",JSON.stringify(result));quit()
