extends SceneTree
# Deterministic native frame at 21 seconds of the benchmark, not a whole playthrough.
func _initialize() -> void: call_deferred("run")
func projected_bounds(node: Node, camera: Camera3D, result: Array[Vector2]) -> void:
	if node is MeshInstance3D and node.mesh!=null and node.is_visible_in_tree():
		var box: AABB=node.mesh.get_aabb()
		for i in 8:
			var point: Vector3=node.to_global(box.get_endpoint(i))
			var pixel: Vector2=camera.unproject_position(point)
			result[0]=result[0].min(pixel)
			result[1]=result[1].max(pixel)
	for child in node.get_children(): projected_bounds(child,camera,result)
func run() -> void:
	var output: String=OS.get_environment("BENCHMARK_LENS_OUTPUT")
	if output.is_empty(): output="res://artifacts/benchmark-lens"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var scene: Node=load("res://scenes/quarantine_benchmark.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.player.set_process(false)
	scene.elapsed=21.0
	scene.last_us=Time.get_ticks_usec()
	scene._process(0.0)
	for i in 90: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/closeup.png")
	var camera: Camera3D=scene.player.camera
	var lens: RefCounted=scene.cinema_lens
	var bounds: Array[Vector2]=[Vector2(INF,INF),Vector2(-INF,-INF)]
	projected_bounds(scene.mission.bugs[0].model,camera,bounds)
	var size: Vector2=camera.get_viewport().get_visible_rect().size
	var in_frame: bool=bounds[0].x>=12 and bounds[0].y>=12 and bounds[1].x<size.x-12 and bounds[1].y<size.y-12
	var checks: Array[Dictionary]=[
		{"id":"closeup_chapter","ok":scene.chapter==3},
		{"id":"whole_subject_has_frame_margin","ok":in_frame},
		{"id":"lens_flag_matches_camera","ok":camera.attributes==(lens.attributes if lens.enabled else lens.original)},
		{"id":"subject_in_frustum","ok":camera.is_position_in_frustum(scene.mission.bugs[0].global_position+Vector3(0,.46,0))},
		{"id":"focus_is_in_front_of_camera","ok":lens.focus_distance>1.0 and lens.focus_distance<5.0}]
	var file: FileAccess=FileAccess.open(output+"/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"framing":scene.framing_style,"dof":lens.enabled,"inspection_light":scene.mission.has_node("World/InspectionLuminaire"),"camera_position":str(camera.global_position),"fov":camera.fov,"focus_distance":lens.focus_distance,"far_start":lens.attributes.dof_blur_far_distance,"elapsed":scene.elapsed,"checks":checks,"boundary":"Native deterministic scripted benchmark frame at 21 seconds. The inspection_light flag identifies the physical scene luminaire, also used in normal play. No offline render. Complete live reel validated separately."},"\t"))
	file.close()
	for c in checks: print("LENS CHECK ",c.id," ",c.ok)
	scene.queue_free()
	for i in 5: await process_frame
	quit(0 if checks.all(func(c):return c.ok) else 1)
