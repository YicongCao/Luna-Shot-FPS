extends SceneTree
## godot --headless --fixed-fps 60 --path . --script res://tools/quarantine/test_hound.gd -- --quarantine-qa
## Real mission/player/hit dispatch, with an isolated flat physics lane and scripted actor placement.
const BUG := preload("res://scripts/quarantine/t_bug.gd")
const START := Vector3(120, 4, 120)
const DT := 1.0 / 60.0
var output := OS.get_environment("HOUND_CHECKS_OUTPUT")
var mission: Node3D
var player: CharacterBody3D
var checks: Array[Dictionary] = []
var metrics := {}
var accepted: Array[bool] = []
var deaths := 0

func _initialize() -> void:
	run.call_deferred()

func check(id: String, ok: bool) -> void:
	checks.append({"id":id, "ok":ok})
	if not ok: push_error("HOUND CHECK FAILED: " + id)

func solid(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = at
	mission.add_child(body)
	return body

func aim(point: Vector3) -> void:
	var d: Vector3 = point - player.camera.global_position
	player.rotation.y = atan2(-d.x, -d.z)
	player.head.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())

func settle() -> void:
	await physics_frame
	await physics_frame

func probe(style: String) -> CharacterBody3D:
	OS.set_environment("QUARANTINE_BUG_STYLE", style)
	var bug := BUG.new()
	bug.position = START + Vector3.UP * .015
	bug.mission = mission
	mission.add_child(bug)
	bug.set_physics_process(false)
	return bug

func mounts(bug: CharacterBody3D) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	for plate: MeshInstance3D in bug.plates: poses.append(plate.transform)
	return poses

func coating(plate: MeshInstance3D) -> Color:
	var m := plate.material_override
	return m.get_shader_parameter("coating") if m is ShaderMaterial else m.albedo_color

func shoot_side(bug: CharacterBody3D, side: int) -> void:
	player.position = bug.to_global(Vector3(side * 3.5, 0, 0))
	await settle()
	aim(bug.to_global(Vector3(0, .44, 0)))
	player.cooldown = 0 # Input timing is scripted; damage and impact are never injected.
	check("shot_%d_fired" % (accepted.size()+1), player.fire())

func live_shot(bug: CharacterBody3D, other: CharacterBody3D, side: int) -> float:
	var label := "left/" if side < 0 else "right/"
	var rest := mounts(bug)
	var other_rest := mounts(other)
	var other_paints: Array[Color] = []
	for plate: MeshInstance3D in other.plates: other_paints.append(coating(plate))
	var head_rest: Vector3 = bug.hound_head.rotation
	var other_head: Transform3D = other.hound_head.transform
	var anchors: Array[Vector3] = []
	for leg: Node3D in bug.legs: anchors.append(leg.get_node("Pad").global_position)
	var hp: int = bug.health
	var signals := accepted.size()
	var electrical: Node3D = bug.electrical_damage
	var prior_hits: int = electrical.hits
	await shoot_side(bug, side)
	var hit: Dictionary = player.last_hit
	check(label+"one_accepted_ray", hit.get("collider") == bug and accepted.size() == signals+1 and accepted.back() and bug.health == hp-1 and not bug.dead)
	if hit.get("collider") != bug: return 0.
	var point: Vector3 = hit.position
	var nearest := 0
	for i in range(1, rest.size()):
		if bug.model.to_global(rest[i].origin).distance_squared_to(point) < bug.model.to_global(rest[nearest].origin).distance_squared_to(point): nearest = i
	check(label+"contact_on_requested_flank", side*bug.to_local(point).x > .22 and side*rest[nearest].origin.x > 0)
	check(label+"electrical_contact_once", electrical.hits == prior_hits+1 and electrical.last_world_hit.is_equal_approx(point) and electrical.burned.has(bug.plates[nearest].get_instance_id()))
	var peak := 0.
	var peak_angle := 0.
	var head_yaw := 0.
	var inward := 0.
	var drift := 0.
	var isolated := true
	var support_samples := 0
	for tick in 61:
		await process_frame # AI/gait are frozen. Both presentation callbacks run normally.
		var mount: Transform3D = bug.plates[nearest].transform
		var displacement := mount.origin - rest[nearest].origin
		peak = maxf(peak, displacement.length())
		peak_angle = maxf(peak_angle, mount.basis.get_rotation_quaternion().angle_to(rest[nearest].basis.get_rotation_quaternion()))
		if tick < 10: inward = maxf(inward, -side * displacement.x)
		var yaw: float = bug.hound_head.rotation.y - head_rest.y
		if absf(yaw) > absf(head_yaw): head_yaw = yaw
		for i in rest.size():
			isolated = isolated and (i == nearest or bug.plates[i].transform.is_equal_approx(rest[i]))
			isolated = isolated and other.plates[i].transform.is_equal_approx(other_rest[i]) and coating(other.plates[i]).is_equal_approx(other_paints[i])
			if bug.gait.planted[i]:
				support_samples += 1
				drift = maxf(drift, anchors[i].distance_to(bug.legs[i].get_node("Pad").global_position))
		isolated = isolated and other.hound_head.transform.is_equal_approx(other_head)
	check(label+"nearest_mount_deflects_inward_and_rotates", inward > .005 and peak_angle > .025)
	check(label+"mount_and_local_head_recover", bug.plates[nearest].transform.is_equal_approx(rest[nearest]) and bug.hound_head.rotation.distance_to(head_rest) < .002)
	check(label+"only_nearest_mount_and_hit_hound_respond", isolated and absf(head_yaw) > .035 and other.health == 3 and other.electrical_damage.hits == 0)
	check(label+"render_callbacks_preserve_world_stance", support_samples >= 61*3 and drift < .0005)
	metrics[label.trim_suffix("/")] = {"local_ray_contact_m":vec(bug.to_local(point)), "nearest_index":nearest, "peak_mount_translation_m":peak, "peak_mount_angle_rad":peak_angle, "signed_peak_head_yaw_rad":head_yaw, "stance_samples":support_samples, "max_pad_drift_m":drift}
	return head_yaw

func vec(v: Vector3) -> Array:
	return [v.x, v.y, v.z]

func shots(bug: CharacterBody3D, other: CharacterBody3D) -> void:
	bug.position = START + Vector3.UP*.015
	bug.rotation.y = deg_to_rad(125) # Opposes world X: incorrect world-space impulses must fail.
	player.position = bug.to_global(Vector3(0,0,-1.4))
	bug.attack_cooldown = 10.
	bug.died.connect(func(_victim): deaths += 1)
	bug.set_physics_process(true)
	for tick in 35: await physics_frame
	bug.set_physics_process(false)
	await settle()
	check("stance_grounded_before_impact", bug.is_on_floor() and bug.gait.planted.count(true) >= 3)
	var left := await live_shot(bug, other, -1)
	var right := await live_shot(bug, other, 1)
	check("opposing_side_hits_reverse_local_head_response", left*right < -.001)
	await shoot_side(bug, -1)
	await settle()
	check("third_ray_kills_once", accepted == [true,true,true] and bug.dead and bug.health == 0 and deaths == 1 and mission.kills == 1 and bug.electrical_damage.hits == 3)
	await shoot_side(bug, -1)
	check("fourth_ray_not_accepted_or_scored", accepted == [true,true,true,false] and player.last_hit.get("collider") != bug and bug.health == 0 and bug.electrical_damage.hits == 3 and deaths == 1 and mission.kills == 1)

# Identical fresh patrol clocks, floor and starting poses; only player bearing and wall vary.
# Record actual local head transforms and path, not the action state machine's input/flags.
func pursuit(side: int, hidden: bool) -> Dictionary:
	var bug := probe("hound")
	var hp: float = mission.health
	var wall: StaticBody3D
	if hidden: wall = solid(START+Vector3(0,1,-.78), Vector3(16,2.5,.12))
	player.position = START + (Vector3(side*.55,0,-1.3) if hidden else Vector3(side*3.,0,-5.))
	await settle()
	var yaws: Array[float] = []
	var path: Array[Vector3] = []
	var los := 0
	var near := bug.global_position.distance_to(player.global_position) < BUG.ATTACK_RADIUS
	bug.attack_cooldown = 0.
	bug.set_physics_process(true)
	for tick in 85:
		await physics_frame
		yaws.append(bug.hound_head.rotation.y)
		path.append(bug.position)
		if bug.has_player_los(): los += 1
	bug.set_physics_process(false)
	var close_by: float = path.front().distance_to(player.position) - path.back().distance_to(player.position)
	var label := ("occluded" if hidden else "visible") + ("_left" if side < 0 else "_right")
	var yaw_range: float = yaws.max() - yaws.min()
	check(label+"_perception_and_action", (near and los == 0 and yaw_range > .2 and mission.health == hp) if hidden else (los == path.size() and close_by > 2.0 and -side*yaws[6] > .015))
	metrics[label] = {"los_ticks":los, "ticks":path.size(), "tick7_local_yaw_rad":yaws[6], "scan_yaw_range_rad":yaw_range, "distance_closed_m":close_by, "damage":hp-mission.health}
	bug.free()
	if wall: wall.free()
	return {"yaws":yaws, "path":path}

func behavior() -> void:
	await pursuit(-1, false)
	await pursuit(1, false)
	var a := await pursuit(-1, true)
	var b := await pursuit(1, true)
	var delta_yaw := 0.
	var delta_path := 0.
	for i in a.yaws.size():
		delta_yaw = maxf(delta_yaw, absf(a.yaws[i] - b.yaws[i]))
		delta_path = maxf(delta_path, a.path[i].distance_to(b.path[i]))
	check("hidden_player_bearing_cannot_steer_head_or_body", delta_yaw < .001 and delta_path < .001)
	metrics.hidden_pair = {"max_local_yaw_difference_rad":delta_yaw, "max_world_path_difference_m":delta_path}
	var bug := probe("hound")
	player.position = START+Vector3(0,0,-1.42)
	await settle()
	bug.attack_cooldown = 2.
	bug.set_physics_process(true)
	for tick in 40: await physics_frame
	check("close_visible_player_is_attackable", bug.can_attack_player())
	var hp: float = mission.health
	var rest: float = bug.hound_head.rotation.x
	var excursion := 0.
	var changes: Array[int] = []
	var last_hp := hp
	var recovered := false
	bug.attack_cooldown = 0.
	for tick in 95:
		await physics_frame
		if mission.health != last_hp:
			changes.append(tick)
			last_hp = mission.health
		if tick >= 1 and tick < 19: excursion = maxf(excursion, rest - bug.hound_head.rotation.x)
		if tick == 48: recovered = absf(rest - bug.hound_head.rotation.x) < .015
	check("melee_head_stroke_and_recovery", excursion > .15 and recovered)
	check("existing_melee_damage_and_interval", hp-mission.health == 24.0 and changes.size() == 2 and changes[1]-changes[0] >= 68 and changes[1]-changes[0] <= 71)
	metrics.melee = {"peak_head_dip_rad":excursion, "damage_ticks":changes, "hp_lost":hp-mission.health}
	bug.free()

func run() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("Headless only")
		quit(1)
		return
	Engine.physics_ticks_per_second = 60
	OS.set_environment("QUARANTINE_BUG_STYLE", "hound")
	OS.unset_environment("QUARANTINE_GAIT")
	mission = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	player = mission.player
	player.qa_mode = true
	player.set_physics_process(false)
	player.shot.connect(func(ok: bool, _d: float): accepted.append(ok))
	mission.set_physics_process(false)
	for bug: CharacterBody3D in mission.bugs: bug.set_physics_process(false)
	solid(START+Vector3.DOWN*.25, Vector3(40,.5,40))
	var b: CharacterBody3D = mission.bugs[0]
	var ready: bool = b.visual_style == "hound" and b.model.get_node_or_null("HoundHead") != null and b.hound_head == b.model.get_node("HoundHead") and b.hound_action != null and b.legs.size() == 6 and b.plates.size() == 6 and b.gait != null
	check("hound_selector_and_rig", ready)
	if ready:
		await shots(b, mission.bugs[1])
		await behavior()
	for style: String in ["refined", "baseline"]:
		var old := probe(style)
		check("select_"+style, old.visual_style == style and old.hound_head == null and old.hound_action == null and old.model.get_node_or_null("HoundHead") == null and old.plates.size() == 6 and (old.gait != null) == (style == "refined"))
		old.free()
	for audio: AudioStreamPlayer in mission.find_children("*", "AudioStreamPlayer", true, false): audio.stop()
	await create_timer(.12).timeout
	mission.queue_free()
	await process_frame
	await process_frame
	if output.is_empty(): output = "res://artifacts/hound/checks"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		push_error("Cannot create evidence directory")
		quit(1)
		return
	var f := FileAccess.open(output+"/headless.json", FileAccess.WRITE)
	if not f:
		push_error("Cannot write evidence")
		quit(1)
		return
	var ok := checks.all(func(c): return c.ok)
	f.store_string(JSON.stringify({"engine":Engine.get_version_info().string, "platform":OS.get_name(), "command":"godot --headless --fixed-fps 60 --path . --script res://tools/quarantine/test_hound.gd -- --quarantine-qa", "boundary":"Actual mission player.fire, accepted-shot signal, hit callback, capsule physics and melee cooldown on a controlled platform. AI frozen only for the two render-only stance/impact measurements; unmodified chase/attack ticks in behavior trials. No native frames, performance or art acceptance.", "metrics":metrics, "checks":checks, "pass":ok}, "\t")+"\n")
	f.close()
	print("HOUND: ", checks.size(), " headless checks, pass=", ok)
	quit(0 if ok else 1)
