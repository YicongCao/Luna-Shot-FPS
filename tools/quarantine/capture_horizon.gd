extends SceneTree
# Native same-camera terrain comparison; no extra fill or altered atmosphere.
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	var output: String=OS.get_environment("HORIZON_CAPTURE_OUTPUT")
	if output.is_empty():
		push_error("HORIZON_CAPTURE_OUTPUT must name a new evidence directory")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var mission: Node3D=load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	await frames(45)
	var world: Node3D=mission.get_node("World")
	for bug in mission.bugs:
		bug.set_physics_process(false)
		bug.hide()
	var player: Node=mission.player
	player.qa_mode=true
	player.set_physics_process(false)
	player.set_process(false)
	mission.hud.hide()
	for layer in player.find_children("*","CanvasLayer",true,false): layer.hide()
	# The independent world-owned weapon compositor otherwise leaves cyan ghosts.
	world.weapon_bloom.set_active(false,.65)
	var views: Array[Dictionary]=[
		{"name":"overview","at":Vector3(-4,3.4,27),"target":Vector3(0,5,0),"fov":60.0},
		{"name":"west","at":Vector3(-29,12,22),"target":Vector3(-180,9,-80),"fov":55.0},
		{"name":"east","at":Vector3(29,12,-22),"target":Vector3(180,9,80),"fov":55.0},
		# Opposing outside inspection views verify native backface culling, not playable cameras.
		{"name":"inspection-left","at":Vector3(-110,65,80),"target":Vector3(-180,5,-110),"fov":65.0},
		{"name":"inspection-right","at":Vector3(-230,65,-170),"target":Vector3(-150,5,-70),"fov":65.0}
	]
	var checks: Dictionary={"forward_plus":RenderingServer.get_current_rendering_method()=="forward_plus","amber_preserved":world.atmosphere_style=="amber","backface_culling":world.get_node("ProceduralLunarHorizon").mesh.surface_get_material(0).cull_mode==BaseMaterial3D.CULL_BACK,"no_terrain_collision":world.get_node("ProceduralLunarHorizon").get_child_count()==0}
	var baseline_noise: FastNoiseLite=FastNoiseLite.new()
	baseline_noise.seed=221117
	baseline_noise.frequency=.011
	baseline_noise.fractal_octaves=5
	for shot in views:
		var baseline_y: float=world.horizon_height(baseline_noise,shot.at.x,shot.at.z)
		var refined_y: float=preload("res://scripts/quarantine/lunar_horizon.gd").sample_height(shot.at.x,shot.at.z)
		checks["camera_clears_both_surfaces_"+shot.name]=shot.at.y>maxf(baseline_y,refined_y)+5
		player.position=shot.at-Vector3(0,1.65,0)
		var d: Vector3=shot.target-player.camera.global_position
		player.rotation.y=atan2(-d.x,-d.z)
		player.head.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
		player.camera.fov=shot.fov
		await frames(90)
		checks["camera_pose_"+shot.name]=player.camera.global_position.distance_to(shot.at)<.01 and (-player.camera.global_basis.z).dot((shot.target-shot.at).normalized())>.999
		await RenderingServer.frame_post_draw
		checks["saved_"+shot.name]=root.get_texture().get_image().save_png(output+"/"+shot.name+".png")==OK
	var file: FileAccess=FileAccess.open(output+"/result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"resolution":str(root.size),"horizon":world.horizon_style,"shadows":world.shadow_style,"atmosphere":world.atmosphere_style,"views":views,"checks":checks,"boundary":"Native frozen-camera comparison; inspection cameras outside the facility are diagnostic only. No offline rendering or added fill."},"\t"))
	file.close()
	var passed: bool=true
	for key in checks:
		print("HORIZON NATIVE CHECK ",key," ",checks[key])
		passed=passed and checks[key]
	mission.queue_free()
	await frames(5)
	quit(0 if passed else 1)
