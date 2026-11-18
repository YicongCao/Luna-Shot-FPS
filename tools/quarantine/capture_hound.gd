extends SceneTree
## Two fresh mission runs, each into an empty output slot. In an imported project:
## QUARANTINE_BUG_STYLE=hound HOUND_VIEWS=/tmp/review godot --path . --rendering-method forward_plus --resolution 1280x720 --fixed-fps 60 --script tools/quarantine/capture_hound.gd -- --quarantine-qa
## Repeat with QUARANTINE_BUG_STYLE=refined and the same output root.
const START := Vector3(0, .025, 18)
var mission: Node3D
var player: CharacterBody3D
var bug: CharacterBody3D
var shot_camera: Camera3D
var fill: OmniLight3D
var original_materials := {}
var frames: Array[Dictionary] = []
var checks := {}
var output: String
var style := OS.get_environment("QUARANTINE_BUG_STYLE")
var shot_tick := -1
var step := 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> bool:
	checks[label] = ok
	if not ok: push_error("HOUND VIEW: " + label)
	return ok

func ticks(n: int) -> void:
	for i in n: await physics_frame

func layers(game_view: bool) -> void:
	mission.hud.visible = game_view
	player.get_node("WeaponLayer").visible = game_view
	mission.get_node("World").weapon_bloom.visible = game_view
	if game_view: player.camera.make_current()
	else: shot_camera.make_current()

func aim() -> void:
	var d: Vector3 = bug.global_position + Vector3.UP * .48 - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func diagnostic(side: float) -> void:
	# Symmetric, low, slightly forward of broadside. Same perspective on both styles.
	var basis := bug.global_basis.orthonormalized()
	var focus := bug.global_position + Vector3(0,.51,0)
	shot_camera.position = bug.global_position + basis * Vector3(side*2.5, 1.04, -1.17)
	shot_camera.look_at(focus)
	if is_instance_valid(fill): fill.global_position = shot_camera.position + Vector3.UP * .4

func xyz(v: Vector3) -> Array:
	return [v.x,v.y,v.z]

func snap(id: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var camera := root.get_camera_3d()
	var head: Node3D = bug.model.get_node_or_null("HoundHead")
	var world: Node3D = mission.get_node("World")
	check(id + "_image", image != null and image.get_size() == Vector2i(1280,720) and image.save_webp(output.path_join(id + ".webp"),false,.95) == OK)
	frames.append({"id":id, "fixed_step":step, "ticks_since_shot":step-shot_tick if shot_tick>=0 else null,
		"health":bug.health,"ammo":player.ammo,"camera":xyz(camera.global_position),"camera_euler_deg":xyz(camera.global_rotation_degrees),"fov":camera.fov,
		"body":xyz(bug.global_position),"body_euler_deg":xyz(bug.global_rotation_degrees),"speed":Vector2(bug.velocity.x,bug.velocity.z).length(),
		"head_local_euler_deg":xyz(head.rotation_degrees) if head else null,"head_local_m":xyz(head.position) if head else null,
		"flinch_clock_s":bug.hound_action.impact_age if head else null,"flinching_plate":is_instance_valid(bug.hound_action.plate) if head else null,
		"range_m":player.global_position.distance_to(bug.global_position),"player_los":bug.has_player_los(),"neutral_fill":is_instance_valid(fill),
		"weapon_layer":player.get_node("WeaponLayer").visible,"weapon_bloom":world.weapon_bloom.visible,"hud":mission.hud.visible})
	print("VIEW ",style," ",id)

func run() -> void:
	if not check("native", DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() == "forward_plus") or not style in ["refined","hound"] or not "--quarantine-qa" in OS.get_cmdline_user_args():
		quit(1); return
	var base := OS.get_environment("HOUND_VIEWS")
	if base.is_empty(): base = "res://docs/validation/t-bug-hound-v1/views"
	output = ProjectSettings.globalize_path(base.path_join(style))
	if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
		push_error("Refusing to overwrite captures: " + output); quit(1); return
	if DirAccess.make_dir_recursive_absolute(output) != OK: quit(1); return
	seed(221117)
	mission = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	player = mission.player
	bug = mission.bugs[0]
	if not check("selected_style", bug.visual_style == style and bug.model.has_node("HoundHead") == (style=="hound")):
		quit(1); return
	# Only this actual mission-spawned bug is staged in the open lane. Freeze other AI.
	for b: CharacterBody3D in mission.bugs:
		b.set_physics_process(false)
		if b != bug:
			b.hide()
			b.collision_layer = 0
	bug.position = START
	bug.patrol_origin = START + Vector3.FORWARD * 3.0
	bug.patrol_time = -.15 # Near the scan center for the two gray comparisons.
	bug.rotation = Vector3.ZERO
	player.position = Vector3(0,.025,-2)
	shot_camera = Camera3D.new()
	shot_camera.fov = 43
	mission.add_child(shot_camera)
	await ticks(12)
	# Step only the bug's normal physics/AI method at fixed delta. No head/leg pose authored here.
	for i in 16:
		await physics_frame
		bug._physics_process(1.0 / 60.0)
		step += 1
	var gray := StandardMaterial3D.new()
	gray.albedo_color = Color(.43,.43,.43)
	gray.roughness = .7
	gray.cull_mode = BaseMaterial3D.CULL_BACK
	for mesh: MeshInstance3D in bug.model.find_children("*", "MeshInstance3D", true, false):
		original_materials[mesh] = mesh.material_override
		mesh.material_override = gray
	fill = OmniLight3D.new()
	fill.light_energy = 2.5
	fill.omni_range = 5
	mission.add_child(fill)
	layers(false)
	for side: int in [-1,1]:
		diagnostic(float(side))
		await ticks(6)
		await snap("01-gray-left" if side == -1 else "02-gray-right")
	for mesh: MeshInstance3D in original_materials: mesh.material_override = original_materials[mesh]
	original_materials.clear()
	fill.free()
	player.position = Vector3(1.55,.025,12.4)
	layers(true)
	await ticks(12)
	aim()
	await ticks(3)
	check("hip_view",not player.aiming and absf(player.camera.fov-72.0)<.03 and player.camera.is_current())
	await snap("03-hip-scale")
	layers(false)
	player.position = Vector3(0,.025,-2)
	await ticks(3)
	bug.patrol_time = -1.15 # Stage the encounter start; posture still comes from the real AI.
	for t in range(-75,112):
		await physics_frame
		if t==36: player.position = Vector3(.25,.025,12.0)
		bug._physics_process(1.0 / 60.0)
		step += 1
		diagnostic(1)
		if t in [-59,35]:
			check("outside_detection_"+str(t), player.global_position.distance_to(bug.global_position)>bug.DETECTION_RADIUS)
			await snap("04-patrol-a" if t==-59 else "05-patrol-b")
		elif t==61:
			check("actual_chase",bug.has_player_los() and absf(Vector2(bug.velocity.x,bug.velocity.z).length()-2.15)<.01)
			await snap("06-pursuit")
		elif t==68:
			aim()
			var ammo: int = player.ammo
			var hp: int = bug.health
			var fired: bool = player.fire()
			check("accepted_rifle_hit", fired and player.last_hit.get("collider")==bug and player.ammo==ammo-1 and bug.health==hp-1 and not bug.dead)
			shot_tick = step
		elif t in [71,80,111]:
			await snap({71:"07-impact",80:"08-release",111:"09-recovered"}[t])
	check("only_one_accepted_hit",bug.health==2 and player.ammo==19 and mission.health==100 and mission.kills==0)
	var file := FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE)
	if not file: quit(1); return
	file.store_string(JSON.stringify({"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"style":style,"checks":checks,"frames":frames},"\t") + "\n")
	file.close()
	mission.queue_free()
	await ticks(5)
	quit(0 if not false in checks.values() else 1)
