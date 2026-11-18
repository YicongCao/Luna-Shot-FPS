extends SceneTree
## godot --headless --fixed-fps 60 --script tools/quarantine/test_bug_gait.gd
## godot --rendering-method forward_plus --resolution 1280x720 --fixed-fps 60 --script tools/quarantine/test_bug_gait.gd -- --gait-native --quarantine-qa
## Both commands compare fresh baseline/default bugs; no AI, steering or targets.
const BUG = preload("res://scripts/quarantine/t_bug.gd")
var output := OS.get_environment("GAIT_OUTPUT")
const DT := 1.0 / 60.0
const NEAR_FLOOR := 0.035 # Same observer for both rigs; not a contact sensor.
const SLOPE := 12.0
const MODES := ["baseline", "default"]
var checks: Array[Dictionary] = []
var results: Dictionary = {}
var baseline := false

class DummyMission extends Node3D:
	var paused := false
	var stage := 0

func _initialize() -> void:
	call_deferred("run")

func check(label: String, ok: bool) -> void:
	checks.append({"id": label, "ok": ok})
	if not ok: push_error("GAIT CHECK FAILED: " + label)

func select_mode(mode: String) -> void:
	baseline = mode == "baseline"
	if baseline: OS.set_environment("QUARANTINE_GAIT", "baseline")
	else: OS.unset_environment("QUARANTINE_GAIT")

func spawn(parent: Node3D, start: Vector3) -> CharacterBody3D:
	var bug: CharacterBody3D = BUG.new()
	bug.position = start
	parent.add_child(bug)
	bug.set_physics_process(false)
	return bug

func rig_ready(bug: CharacterBody3D) -> bool:
	if bug.legs.size() != 6 or not bug.has_method("animate_legs"): return false
	for leg: Node3D in bug.legs:
		if leg.has_node("Pad") == baseline: return false
	return baseline or is_instance_valid(bug.get("gait"))

func sole(bug: CharacterBody3D, i: int) -> Vector3:
	var leg: Node3D = bug.legs[i]
	if not baseline: return (leg.get_node("Pad") as Node3D).global_position
	# ML26 pad center -.38 minus half its .05 m thickness: actual underside.
	return leg.to_global(Vector3((-1.0 if i < 3 else 1.0) * .51, -.405, (i % 3 - 1) * .16))

func drive(bug: CharacterBody3D, speed: float, yaw_rate: float = 0.0) -> void:
	# Called once per physics frame, after autonomous movement has been disabled.
	var forward: Vector3 = -bug.global_basis.z
	bug.velocity.x = forward.x * speed
	bug.velocity.z = forward.z * speed
	bug.velocity.y = -.5 if bug.is_on_floor() else bug.velocity.y - 18.0 * DT
	bug.move_and_slide()
	bug.rotate_y(yaw_rate * DT)
	if baseline: bug.animate_legs(DT)
	else: bug.gait.update(bug, DT)

func add_floor(parent: Node3D, degrees: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(16, .5, 32)
	collider.shape = box
	collider.position.y = -.25 # Top face goes through body origin.
	body.rotation.x = deg_to_rad(degrees)
	body.add_child(collider)
	parent.add_child(body)
	return body

func horizontal(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func measure(bug: CharacterBody3D, frames: int, speed: float, yaw_rate: float, slope: float, floor_present: bool) -> Dictionary:
	var previous: Array[Vector3] = []
	var anchors: Array[Vector3] = []
	var takeoff: Array[Vector3] = []
	var near_prev: Array[bool] = []
	var plant_prev: Array[bool] = []
	var saw_takeoff: Array[bool] = []
	var steps := [0, 0, 0, 0, 0, 0]
	var near_samples := 0
	var near_travel := 0.0
	var planted_samples := 0
	var max_stance_drift := 0.0
	var max_plant_gap := 0.0
	var max_foot_delta := 0.0
	var max_reach := 0.0
	var max_joint_gap := 0.0
	var max_gap := -INF
	var min_gap := INF
	var max_step := 0.0
	var min_support := 6
	var grounded_frames := 0
	var finite := true
	var start := bug.global_position
	for tick in frames:
		await physics_frame
		drive(bug, speed, yaw_rate)
		if bug.is_on_floor(): grounded_frames += 1
		var support := 0
		for i in 6:
			var p := sole(bug, i)
			if not baseline:
				var l = bug.gait.links[i]
				max_joint_gap = maxf(max_joint_gap,l.upper.to_global(l.knee).distance_to(l.lower.global_position))
				max_joint_gap = maxf(max_joint_gap,l.lower.to_global(l.foot-l.knee).distance_to(l.pad.to_global(Vector3.UP*.025)))
			finite = finite and p.is_finite()
			# Independent oracle: vertical separation from analytic box top directly below sole.
			var gap := p.y + p.z * tan(deg_to_rad(slope))
			var near := floor_present and absf(gap) <= NEAR_FLOOR
			var plant: bool = not baseline and bug.gait.planted[i]
			if tick == 0:
				previous.append(p)
				anchors.append(p)
				takeoff.append(p)
				near_prev.append(false)
				plant_prev.append(false)
				saw_takeoff.append(false)
			max_reach = maxf(max_reach, p.distance_to(bug.global_position))
			if floor_present:
				min_gap = minf(min_gap, gap)
				max_gap = maxf(max_gap, gap)
			if plant:
				support += 1
				planted_samples += 1
				if not plant_prev[i]: anchors[i] = p
				max_stance_drift = maxf(max_stance_drift, p.distance_to(anchors[i]))
				if floor_present: max_plant_gap = maxf(max_plant_gap, absf(gap))
			if tick > 0:
				max_foot_delta = maxf(max_foot_delta, p.distance_to(previous[i]))
				if near and near_prev[i]:
					near_samples += 1
					near_travel += horizontal(p, previous[i])
				if near_prev[i] and gap > NEAR_FLOOR:
					takeoff[i] = previous[i]
					saw_takeoff[i] = true
				if near and not near_prev[i] and saw_takeoff[i]:
					var travel := horizontal(p, takeoff[i])
					if travel >= .04:
						steps[i] += 1
						max_step = maxf(max_step, travel)
					saw_takeoff[i] = false
			previous[i] = p
			near_prev[i] = near
			plant_prev[i] = plant
		min_support = mini(min_support, support)
	return {"ticks": frames, "speed_mps": speed, "yaw_deg_s": rad_to_deg(yaw_rate),
		"body_xz_m": horizontal(start, bug.global_position), "body_dy_m": bug.global_position.y - start.y,
		"body_grounded_ticks": grounded_frames, "max_joint_gap_m": max_joint_gap if not baseline else null, "finite": finite, "max_reach_m": max_reach,
		"max_sole_delta_m": max_foot_delta, "observed_steps_per_leg": steps, "max_observed_step_m": max_step,
		"near_floor_pairs": near_samples, "mean_near_floor_xz_speed_mps": near_travel / (near_samples * DT) if near_samples else null,
		"min_gap_m": min_gap if floor_present else null, "max_gap_m": max_gap if floor_present else null,
		"min_planted": min_support if not baseline else null, "plant_samples": planted_samples if not baseline else null,
		"max_plant_drift_m": max_stance_drift if planted_samples else null,
		"max_abs_plant_gap_m": max_plant_gap if planted_samples and floor_present else null}

func fixture(mode: String, slope: float) -> void:
	var level := DummyMission.new()
	root.add_child(level)
	var floor_body := add_floor(level, slope)
	var bug := spawn(level, Vector3(0, .03, 0))
	var terrain := "ramp" if slope else "flat"
	var label := mode + "/" + terrain + "/"
	var ready := rig_ready(bug)
	check(label + "expected_rig", ready)
	if not ready:
		level.free()
		return
	var collider: CollisionShape3D = bug.get_node("Collider")
	var capsule := collider.shape as CapsuleShape3D
	check(label + "capsule", capsule != null and is_equal_approx(capsule.radius, .43) and is_equal_approx(capsule.height, .9) and collider.position.is_equal_approx(Vector3(0, .45, 0)))
	for t in 30:
		await physics_frame
		drive(bug, 0)
	var phases := {}
	phases.walk = await measure(bug, 120, .85, 0, slope, true)
	if slope == 0:
		phases.chase = await measure(bug, 90, 2.15, 0, slope, true)
		phases.turn = await measure(bug, 90, 0, PI / 1.5, slope, true)
		check(label + "turned_180_in_place", absf(absf(bug.rotation.y) - PI) < .002 and phases.turn.body_xz_m < .01)
	for t in 45: # Finishing the last swing is not idle jitter.
		await physics_frame
		drive(bug, 0)
	phases.idle = await measure(bug, 45, 0, 0, slope, true)
	check(label + "idle_still", phases.idle.max_sole_delta_m < .002)
	for phase: String in phases:
		var m: Dictionary = phases[phase]
		check(label + phase + "_grounded", m.body_grounded_ticks == m.ticks)
		if baseline: continue
		check(label + phase + "_support", m.min_planted >= 2 and m.max_plant_drift_m != null and m.max_plant_drift_m < .025)
		check(label + phase + "_floor", m.max_abs_plant_gap_m != null and m.max_abs_plant_gap_m < .035 and m.min_gap_m > -.035)
		if phase != "idle":
			check(label + phase + "_steps", m.observed_steps_per_leg.min() >= 1 and m.max_gap_m > .045)
	check(label + "walk_displacement", phases.walk.body_xz_m > 1.5 and phases.walk.body_xz_m < 1.8)
	if slope != 0: check(label + "actually_ascended", phases.walk.body_dy_m > .3)
	if slope == 0:
		floor_body.free() # Lose previously valid anchors; do not teleport bug or re-create gait.
		for t in 6:
			await physics_frame
			drive(bug, 0)
		phases.fall = await measure(bug, 30, 0, 0, slope, false)
		check(label + "falls_with_no_support", phases.fall.body_grounded_ticks == 0 and phases.fall.body_dy_m < -1 and (baseline or phases.fall.plant_samples == 0))
	for phase: String in phases:
		if not baseline: check(label + phase + "_links_connected", phases[phase].max_joint_gap_m < .001)
		check(label + phase + "_bounded_soles", phases[phase].finite and phases[phase].max_reach_m < 1.6)
	bug.mission = level
	var hits_ok: bool = bug.health == 3
	for hp in [2, 1, 0]:
		var hit: bool = bug.register_hit()
		hits_ok = hits_ok and hit and bug.health == hp and bug.dead == (hp == 0)
	check(label + "dies_on_third_hit", hits_ok and not bug.register_hit())
	results[mode][terrain] = phases
	level.free()

func compare() -> void:
	for terrain: String in ["flat", "ramp"]:
		if not results.default.has(terrain) or not results.baseline.has(terrain): continue
		for phase: String in results.default[terrain]:
			if phase in ["idle", "fall"]: continue
			var a: Dictionary = results.baseline[terrain][phase]
			var b: Dictionary = results.default[terrain][phase]
			check(terrain + "/" + phase + "/comparable_body_path", absf(a.body_xz_m - b.body_xz_m) < .005 and absf(a.body_dy_m - b.body_dy_m) < .005)
			check(terrain + "/" + phase + "/reduced_near_floor_slip", a.near_floor_pairs >= 30 and b.near_floor_pairs >= 30 and b.mean_near_floor_xz_speed_mps < a.mean_near_floor_xz_speed_mps * .6)

func capture_pair() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		check("native_forward_plus", false)
		return
	var mission: Node3D = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	var player: CharacterBody3D = mission.player
	player.set_physics_process(false)
	player.set_process(false)
	mission.hud.hide()
	player.get_node("WeaponLayer").hide()
	for b: Node3D in mission.bugs:
		b.set_physics_process(false)
		b.hide()
		b.collision_layer = 0
	var camera := Camera3D.new()
	mission.add_child(camera)
	camera.current = true
	camera.fov = 50
	var start := Vector3(0, .03, 19)
	# Fixed three-quarter side view across an open stretch of the actual south route.
	camera.position = Vector3(3.3, 1.1, 17.1)
	camera.look_at(Vector3(0, .35, 18.35))
	for t in 8: await process_frame
	mission.get_node("World").weapon_bloom.hide()
	for mode: String in MODES:
		select_mode(mode)
		var bug := spawn(mission, start)
		check(mode + "/capture_rig", rig_ready(bug))
		if not rig_ready(bug):
			bug.free()
			continue
		for t in 30:
			await physics_frame
			drive(bug, 0)
		var poses: Array[Dictionary] = []
		for tick in range(1, 85):
			await physics_frame
			drive(bug, .85)
			if tick in [40, 45, 50, 55, 60, 65, 70, 75, 80]:
				var foot_data: Array[Dictionary] = []
				var support := 0
				for i in 6:
					var p := sole(bug, i)
					var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * .5, p - Vector3.UP * .7, 1)
					var hit := bug.get_world_3d().direct_space_state.intersect_ray(ray)
					var planted: bool = not baseline and bug.gait.planted[i]
					var gap: Variant = null if hit.is_empty() else p.y - float(hit.position.y)
					if planted and gap != null and absf(gap) < NEAR_FLOOR: support += 1
					foot_data.append({"xyz_m":[p.x,p.y,p.z], "gap_m":gap, "planted":planted if not baseline else null})
				check(mode + "/native_floor_" + str(tick), foot_data.all(func(s): return s.gap_m != null) and (baseline or support >= 2))
				await RenderingServer.frame_post_draw
				var path := "%s/%s-walk-%03d.webp" % [output, mode, tick]
				var image := root.get_texture().get_image()
				check(mode + "/image_" + str(tick), image != null and not image.is_empty() and image.save_webp(path, false, .92) == OK)
				poses.append({"tick":tick, "z_m":bug.global_position.z, "soles":foot_data})
		check(mode + "/native_walk_displacement", start.z - bug.global_position.z > 1.1)
		results[mode] = poses
		bug.free()
	mission.free()

func run() -> void:
	Engine.physics_ticks_per_second = 60
	# Keep the historical ML31 comparison reproducible; allow an explicit hound rerun.
	if OS.get_environment("QUARANTINE_BUG_STYLE") != "hound": OS.set_environment("QUARANTINE_BUG_STYLE","refined")
	if output.is_empty(): output = "res://docs/validation/t-bug-gait-v1/recheck"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		push_error("Cannot create gait evidence directory")
		quit(1)
		return
	var native := "--gait-native" in OS.get_cmdline_user_args()
	if native:
		await capture_pair()
	else:
		for mode: String in MODES:
			select_mode(mode)
			results[mode] = {}
			await fixture(mode, 0)
			await fixture(mode, SLOPE)
		compare()
	var file := FileAccess.open(output + ("/native.json" if native else "/metrics.json"), FileAccess.WRITE)
	if not file:
		push_error("Cannot write gait evidence")
		quit(1)
		return
	file.store_string(JSON.stringify({"engine": Engine.get_version_info().string, "platform": OS.get_name(), "dt_s": DT,
		"boundary": "Scripted 60 Hz capsule motion; no autonomous AI, performance or art acceptance claim. Near-floor = |vertical sole-to-box gap| <= 35 mm, not a force/contact measurement. Observed steps require departure from and return to this band with >= 40 mm horizontal travel. Declared-plant drift is maximum 3D displacement from first measured stance sample; baseline has no stance flags. Fall measured after six grace ticks. Native sequence uses the flat fixture's .85 m/s walk on the facility floor, with an unobstructed diagnostic camera and unchanged scene lighting.",
		"results": results, "checks": checks}, "\t") + "\n")
	file.close()
	var ok := checks.all(func(c): return c.ok)
	print("GAIT ", "native" if native else "fixtures", ": ", checks.size(), " checks, pass=", ok)
	quit(0 if ok else 1)
