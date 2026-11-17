extends SceneTree
## Run after import:
## godot --headless --path <project> --script res://tools/quarantine/test_mission.gd -- --quarantine-qa
## Real scene + physics, deterministic direct damage/interaction calls and player
## teleports. Not an art approval, playthrough, navigation soak or GPU evidence.
var mission: Node3D
var failures: int = 0
var checks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)

func _settle() -> void:
	await physics_frame
	await physics_frame
	await process_frame

func _freeze_actors() -> void:
	mission.set_physics_process(false)
	var player: CharacterBody3D = mission.get("player") as CharacterBody3D
	player.set("qa_mode", true)
	player.set_physics_process(false)
	for bug: Node in mission.get("bugs"):
		bug.set_physics_process(false)

func _move_player(position: Vector3) -> void:
	var player: CharacterBody3D = mission.get("player") as CharacterBody3D
	player.global_position = position
	player.velocity = Vector3.ZERO

func _clear_bugs() -> void:
	for bug: Node in mission.get("bugs"):
		for hit: int in range(3):
			bug.call("register_hit")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/quarantine.tscn") as PackedScene
	if scene == null:
		push_error("Cannot load quarantine scene")
		quit(1)
		return
	mission = scene.instantiate() as Node3D
	root.add_child(mission)
	current_scene = mission
	_freeze_actors()
	await _settle()
	var player: CharacterBody3D = mission.get("player") as CharacterBody3D
	var bugs: Array = mission.get("bugs")
	var terminal: Vector3 = (mission.get_node("World/Markers/Terminal") as Node3D).global_position
	var extraction: Vector3 = (mission.get_node("World/Markers/Extraction") as Node3D).global_position
	_check(int(mission.get("stage")) == 0 and bugs.size() == 8, "real scene starts CLEAR with eight T-Bugs")
	_check(player.get_node("Head/Camera") is Camera3D, "existing player/weapon scene instantiated")
	_check(player.global_position.is_equal_approx((mission.get_node("World/Markers/Spawn") as Node3D).global_position), "player uses world Spawn marker")
	for bug: CharacterBody3D in bugs:
		var shape_node: CollisionShape3D = bug.get_node("Collider") as CollisionShape3D
		var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.collision_mask = 1
		query.margin = 0.001
		var overlaps: Array[Dictionary] = bug.get_world_3d().direct_space_state.intersect_shape(query)
		_check(overlaps.is_empty(), "%s spawns clear of actual facility solids" % bug.name)
	_move_player(terminal + Vector3(0, 0.05, 1))
	mission.call("_update_activation", 4.0, true)
	_check(int(mission.get("stage")) == 0 and float(mission.get("progress")) == 0.0, "terminal cannot activate before clearance")

	var first: CharacterBody3D = bugs[0] as CharacterBody3D
	var deaths: Array[int] = [0]
	first.connect("died", func(_bug: Node3D) -> void: deaths[0] += 1)
	_check(first.collision_layer == 4 and first.collision_mask == 3, "bug collision layers match rifle/player contract")
	_check(bool(first.call("register_hit")), "first hit accepted")
	_check(bool(first.call("register_hit")) and not bool(first.get("dead")), "two hits do not kill")
	_check(bool(first.call("register_hit")) and bool(first.get("dead")), "third hit kills")
	_check(not bool(first.call("register_hit")) and deaths[0] == 1 and int(mission.get("kills")) == 1, "corpse ignores further hits and emits death/scores once")
	mission.call("_on_bug_died", first)
	_check(int(mission.get("kills")) == 1 and first.collision_layer == 0 and first.collision_mask == 0, "duplicate death cannot score; corpse has no collisions")

	# Actual direct-space LOS query, with a temporary solid wall in a clear lane.
	var attacker: CharacterBody3D = bugs[1] as CharacterBody3D
	attacker.global_position = Vector3(-2, 0.05, 20)
	_move_player(Vector3(-2, 0.05, 21.4))
	await _settle()
	_check(bool(attacker.call("can_attack_player")), "nearby unobstructed player is attackable")
	var wall: StaticBody3D = StaticBody3D.new()
	wall.collision_layer = 1
	var collider: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(2, 3, 0.15)
	collider.shape = box
	wall.add_child(collider)
	mission.add_child(wall)
	wall.global_position = Vector3(-2, 1.5, 20.7)
	await _settle()
	_check(not bool(attacker.call("can_attack_player")), "wall blocks contact damage via physics LOS")
	var health_before: float = float(mission.get("health"))
	attacker.set("attack_cooldown", 0.0)
	attacker.call("_physics_process", 0.01)
	_check(float(mission.get("health")) == health_before, "wall prevents actual attack damage")
	wall.free()
	_move_player(Vector3(-2, 3.5, 21))
	await _settle()
	_check(not bool(attacker.call("can_attack_player")), "player above bug cannot be bitten through bridge")
	_move_player(Vector3(-2, 0.05, 21.4))
	await _settle()
	attacker.set("attack_cooldown", 0.0)
	attacker.call("_physics_process", 0.01)
	_check(float(mission.get("health")) == health_before - 12.0, "visible close attack applies damage")
	attacker.call("_physics_process", 0.01)
	_check(float(mission.get("health")) == health_before - 12.0, "attack cooldown prevents repeated frame damage")

	mission.call("set_paused", true)
	var effect: Node = player.get("fire_effect") as Node
	var clock: float = float(mission.get("elapsed"))
	_check(paused and not player.can_process() and not attacker.can_process(), "ESC pause freezes tree/player/enemies")
	_check(is_instance_valid(effect) and not effect.can_process(), "deferred rifle effect is also paused")
	mission.call("damage_player", 100.0)
	mission.call("_physics_process", 1.0)
	await process_frame
	_check(float(mission.get("health")) == health_before - 12.0 and float(mission.get("elapsed")) == clock, "paused mission rejects damage and elapsed time")
	mission.call("set_paused", false)
	mission.call("damage_player", 1000.0)
	_check(int(mission.get("stage")) == 4 and float(mission.get("health")) == 0.0 and paused, "death enters FAILED and stops simulation")
	mission.call("set_paused", false)
	_check(paused and bool(player.get("blocked")), "resume cannot bypass FAILED state")
	var restart_key: InputEventKey = InputEventKey.new()
	restart_key.physical_keycode = KEY_F5
	restart_key.pressed = true
	mission.call("_input", restart_key)
	_freeze_actors()
	await _settle()
	_check(int(mission.get("stage")) == 0 and float(mission.get("health")) == 100.0 and not paused, "F5 restarts from FAILED")
	_check(int(mission.get("kills")) == 0 and int(player.get("ammo")) == 20 and (mission.get("bugs") as Array).size() == 8, "restart resets ammo, score and exactly eight live enemies")
	mission.call("set_paused", true)
	mission.call("_input", restart_key)
	_freeze_actors()
	_check(not paused and not bool(mission.get("paused")), "F5 works while explicitly paused")

	_clear_bugs()
	_check(int(mission.get("stage")) == 1 and int(mission.get("kills")) == 8, "all eight kills unlock ACTIVATE")
	_move_player(extraction)
	mission.call("_update_activation", 4.0, true)
	_check(int(mission.get("stage")) == 1 and float(mission.get("progress")) == 0.0, "remote terminal activation is rejected")
	mission.call("_physics_process", 0.01)
	_check(int(mission.get("stage")) == 1, "extraction before activation cannot complete")
	_move_player(terminal + Vector3(0, 0.05, 1))
	mission.call("_update_activation", 1.0, true)
	_check(is_equal_approx(float(mission.get("progress")), 1.0 / 3.0), "hold E accumulates three-second progress")
	mission.call("_update_activation", 0.1, false)
	_check(float(mission.get("progress")) == 0.0, "releasing E resets uninterrupted hold")
	mission.call("_update_activation", 1.0, true)
	_move_player(terminal + Vector3(4, 0, 0))
	mission.call("_update_activation", 1.0, true)
	_check(float(mission.get("progress")) == 0.0, "leaving interaction radius resets hold")
	_move_player(terminal + Vector3(0, 0.05, 1))
	for frame: int in range(180):
		mission.call("_update_activation", 1.0 / 60.0, true)
	_check(int(mission.get("stage")) == 2 and float(mission.get("progress")) == 1.0, "three-second hold enters EXTRACT")
	_move_player(extraction + Vector3(0, 3, 0))
	mission.call("_physics_process", 0.01)
	_check(int(mission.get("stage")) == 2, "overhead position does not trigger ground extraction")
	_move_player(extraction + Vector3(3, 0, 0))
	mission.call("_physics_process", 0.01)
	_check(int(mission.get("stage")) == 2, "outside extraction circle cannot complete")
	_move_player(extraction + Vector3(0, 0.05, 0))
	mission.call("_physics_process", 0.01)
	_check(int(mission.get("stage")) == 3 and paused, "entering south circle completes and freezes mission")
	mission.call("damage_player", 1000.0)
	_check(int(mission.get("stage")) == 3, "COMPLETE is terminal until restart")
	mission.call("_input", restart_key)
	_freeze_actors()
	_check(int(mission.get("stage")) == 0 and not paused, "F5 also restarts completed mission")
	print("QUARANTINE QA: %d checks, %d failures. Direct-call/teleport logic and physics LOS only; no visual/playthrough claim." % [checks, failures])
	# Looping factory audio is asynchronous; stop and drain before destroying the
	# tree, otherwise an immediate headless quit reports playback references.
	for audio: Node in mission.find_children("*", "AudioStreamPlayer", true, false):
		(audio as AudioStreamPlayer).stop()
	await create_timer(0.1).timeout
	mission.queue_free()
	await process_frame
	await process_frame
	quit(1 if failures > 0 else 0)
