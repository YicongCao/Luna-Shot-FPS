extends SceneTree
# 60s native moving-camera/real-capsule stress route. Health replenishment is benchmark-only.
var mission: Node3D
var samples: Array[float] = []
var path: Array[Vector3] = [Vector3(3,0,18),Vector3(3,0,-18),Vector3(-10,0,-18),Vector3(-10,0,18),Vector3(-18,0,18),Vector3(-18,0,-18),Vector3(-26,0,-18),Vector3(-26,0,26),Vector3(0,0,26)]
var index: int = 0
var measured: float = 0.0
var warmup: float = 0.0
var last_us: int = 0
var shots: int = 0
var route_reached: int = 0
var max_height: float = 0.0
var movement: float = 0.0
var previous_position: Vector3

func _initialize() -> void: call_deferred("run")
func run() -> void:
	if OS.get_environment("QUARANTINE_UNCAPPED") == "1":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	mission = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	mission.player.qa_mode = true
	previous_position = mission.player.position
	last_us = Time.get_ticks_usec()
	process_frame.connect(sample)
	physics_frame.connect(walk)

func walk() -> void:
	if not is_instance_valid(mission): return
	mission.health = 100.0
	var player: Node = mission.player
	var destination: Vector3 = path[index]
	var delta: Vector3 = destination-player.position
	delta.y = 0
	if delta.length() < .4:
		index = (index+1)%path.size()
		route_reached += 1
	player.qa_direction = delta.normalized()
	max_height = maxf(max_height,player.position.y)
	movement += player.position.distance_to(previous_position)
	previous_position = player.position
	# Keep actual movement direction independent from the viewing sweep.
	var focus: Vector3 = Vector3(0,4,0)-player.camera.global_position
	player.rotation.y = atan2(-focus.x,-focus.z)
	player.head.rotation.x = atan2(focus.y,Vector2(focus.x,focus.z).length())
	player.aiming = fmod(measured,8.0)>6.0
	if measured > 0 and int(measured*2)>shots:
		shots = int(measured*2)
		if player.ammo == 0: player.reload_weapon()
		else: player.fire()

func sample() -> void:
	var now: int = Time.get_ticks_usec()
	var ms: float = float(now-last_us)/1000.0
	last_us = now
	warmup += ms/1000.0
	if warmup < 5: return
	samples.append(ms)
	measured += ms/1000.0
	if measured < 60: return
	process_frame.disconnect(sample)
	physics_frame.disconnect(walk)
	mission.player.qa_direction = Vector3.ZERO
	samples.sort()
	var data: Dictionary = {"platform":OS.get_name(),"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(root.size),"seconds":measured,"frames":samples.size(),"median_ms":samples[int(samples.size()*.5)],"p95_ms":samples[int(samples.size()*.95)],"p99_ms":samples[int(samples.size()*.99)],"mean_fps":samples.size()/measured,"route_waypoints_reached":route_reached,"capsule_distance_m":movement,"maximum_capsule_height_m":max_height,"shot_requests":shots,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),"boundary":"Health replenished for rendering stress, no completion assertion; includes active bugs, ADS, shots, local lights, bridge and exterior lane."}
	var out: String = OS.get_environment("QUARANTINE_PERFORMANCE_OUTPUT")
	if out.is_empty(): out = "res://docs/validation/quarantine-v1/performance"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var f: FileAccess = FileAccess.open(out+"/native.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(data,"\t"))
	f.close()
	print(JSON.stringify(data))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/route.png")
	mission.queue_free()
	for i in 12: await process_frame
	quit()
