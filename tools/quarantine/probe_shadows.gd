extends SceneTree
# Diagnostic isolation only: these switches never change the shipped rendering profile.
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func run() -> void:
	var mode: String=OS.get_environment("SHADOW_PROBE")
	if mode.is_empty(): mode="baseline"
	var output_root: String=OS.get_environment("SHADOW_PROBE_ROOT")
	if output_root.is_empty(): output_root="res://docs/validation/lunar-horizon-v1/shadow-probe-recheck"
	var output: String=output_root+"/"+mode
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
	world.weapon_bloom.set_active(false,.65)
	# Explicitly restore the original LOW profile before isolating each variable.
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW)
	match mode:
		"no-directional": world.sun.shadow_enabled=false
		"no-local":
			for light in world.find_children("*","Light3D",true,false):
				if not light is DirectionalLight3D: light.shadow_enabled=false
		"no-ssao":
			world.environment.ssao_enabled=false
			world.environment.ssil_enabled=false
		"no-ssr": world.environment.ssr_enabled=false
		"high": RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_HIGH)
		"ultra": RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
		"hard":
			world.sun.light_angular_distance=0
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_HARD)
	for shot in ["surface","overview"]:
		var at: Vector3=Vector3(0,1.65,22) if shot=="surface" else Vector3(-4,3.4,27)
		var target: Vector3=Vector3(-4,.8,10) if shot=="surface" else Vector3(0,5,0)
		player.position=at-Vector3(0,1.65,0)
		var d: Vector3=target-player.camera.global_position
		player.rotation.y=atan2(-d.x,-d.z)
		player.head.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
		player.camera.fov=52 if shot=="surface" else 60
		await frames(90)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output+"/"+shot+".png")
	for setting in ProjectSettings.get_property_list():
		if "shadow" in setting.name and ("quality" in setting.name or "size" in setting.name): print(setting.name,"=",ProjectSettings.get_setting(setting.name))
	print("SHADOW PROBE COMPLETE ",mode)
	mission.queue_free()
	await frames(5)
	quit()
