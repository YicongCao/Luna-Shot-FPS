extends Node3D
## Standalone mission; never changes the training scene or shared rifle/player scripts.
const BUG_SCRIPT = preload("res://scripts/quarantine/t_bug.gd")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const CLEAR: int = 0
const ACTIVATE: int = 1
const EXTRACT: int = 2
const COMPLETE: int = 3
const FAILED: int = 4
const ACTIVATION_SECONDS: float = 3.0
const EXTRACTION_RADIUS: float = 2.5
const BUG_STARTS: Array[Vector3] = [
	Vector3(2, 0, 15), Vector3(-2, 0, 3), Vector3(2, 0, -12),
	Vector3(-10, 0, 8), Vector3(10, 0, 5), Vector3(-10, 0, -12),
	Vector3(10, 0, -16), Vector3(0, 0, -24),
]

var player: CharacterBody3D
var stage: int = CLEAR
var health: float = 100.0
var kills: int = 0
var total_bugs: int = 8
var objective_text: String = ""
var interact_hint: String = ""
var progress: float = 0.0
var terminal_completed: bool = false
var elapsed: float = 0.0
var hit_flash: float = 0.0
var damage_flash: float = 0.0
var paused: bool = false
var overview: bool = false
var bugs: Array = []
var hud: Control
var qa_mode: bool = false
var _counted_deaths: Dictionary = {}

func _ready() -> void:
	# Only the controller/HUD run while paused. Deferred player effects must also
	# be pausable, rather than inheriting this controller's ALWAYS process mode.
	process_mode = Node.PROCESS_MODE_ALWAYS
	child_entered_tree.connect(_on_child_entered_tree)
	configure_input()
	qa_mode = "--quarantine-qa" in OS.get_cmdline_user_args()
	var world: Node3D = Node3D.new()
	world.name = "World"
	world.set_script(preload("res://scripts/quarantine/world.gd"))
	add_child(world)
	player = PLAYER_SCENE.instantiate() as CharacterBody3D
	player.name = "Player"
	add_child(player)
	player.set("qa_mode", qa_mode)
	player.set("spawn_position", _marker("Spawn"))
	player.connect("shot", _on_shot)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "MissionHUD"
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	hud = Control.new()
	hud.set_script(preload("res://scripts/quarantine/hud.gd"))
	hud.set("mission", self)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	restart()

func _on_child_entered_tree(child: Node) -> void:
	if not child is CanvasLayer:
		child.process_mode = Node.PROCESS_MODE_PAUSABLE

func configure_input() -> void:
	var bindings: Dictionary = {
		"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D,
		"sprint": KEY_SHIFT, "jump": KEY_SPACE, "reload": KEY_R,
		"reset": KEY_F5, "pause": KEY_ESCAPE, "interact": KEY_E,
	}
	for action: String in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
	for action: String in ["fire", "aim"]:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var button: InputEventMouseButton = InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, button)

func _input(event: InputEvent) -> void:
	# Handle before GUI focus; restart remains available on pause/death/success.
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("reset"):
		restart()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pause"):
		set_paused(not paused)
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if paused or stage >= COMPLETE:
		return
	elapsed += delta
	hit_flash = maxf(0.0, hit_flash - delta)
	damage_flash = maxf(0.0, damage_flash - delta)
	_update_activation(delta, Input.is_action_pressed("interact"))
	if stage == EXTRACT and _inside_extraction():
		stage = COMPLETE
		_sync_pause()
	_update_objective()

func _update_activation(delta: float, held: bool) -> void:
	if paused or stage != ACTIVATE:
		return
	# Full 3D distance also prevents interaction from the overhead walkway.
	if not held or not can_use_terminal():
		progress = 0.0
		return
	progress = minf(1.0, progress + maxf(0.0, delta) / ACTIVATION_SECONDS)
	if progress >= 0.99999:
		progress = 1.0
		terminal_completed = true
		stage = EXTRACT

func can_use_terminal() -> bool:
	if stage != ACTIVATE or paused or not is_instance_valid(player): return false
	var base: Vector3 = _marker("Terminal")
	if player.global_position.distance_to(base)>3.0 or player.global_position.z<base.z+.35: return false
	var target: Vector3 = base+Vector3(0,2.14,.06)
	var camera: Camera3D = player.camera
	if (-camera.global_basis.z).dot((target-camera.global_position).normalized()) < .72: return false
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(camera.global_position,target,1,[player.get_rid()])
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider")==get_node("World/TerminalCollision")

func _inside_extraction() -> bool:
	var offset: Vector3 = player.global_position - _marker("Extraction")
	return Vector2(offset.x, offset.z).length() <= EXTRACTION_RADIUS and absf(offset.y) <= 1.0

func _marker(marker_name: String) -> Vector3:
	var marker: Node3D = get_node("World/Markers/" + marker_name) as Node3D
	return marker.global_position

func objective_position() -> Vector3:
	if stage == CLEAR:
		var nearest: Vector3 = _marker("Terminal")
		var distance: float = INF
		for bug: Node3D in bugs:
			if not is_instance_valid(bug) or bool(bug.get("dead")):
				continue
			var candidate: float = player.global_position.distance_squared_to(bug.global_position)
			if candidate < distance:
				distance = candidate
				nearest = bug.global_position
		return nearest
	return _marker("Terminal") if stage == ACTIVATE else _marker("Extraction")

func _update_objective() -> void:
	interact_hint = ""
	match stage:
		CLEAR:
			objective_text = "清理机械害虫 T-BUG  %d / %d" % [kills, total_bugs]
			if player.global_position.distance_to(_marker("Terminal")) <= 3.0:
				interact_hint = "终端锁定 · 先清除全部 T-Bug"
		ACTIVATE:
			objective_text = "前往北侧终端 · 恢复工厂控制"
			if can_use_terminal():
				interact_hint = "E"
		EXTRACT:
			objective_text = "控制已恢复 · 返回南侧圆形撤离区"
		COMPLETE:
			objective_text = "任务完成 · 工厂已清理"
			interact_hint = "F5 重新开始"
		FAILED:
			objective_text = "任务失败 · 生命值耗尽"
			interact_hint = "F5 重新开始"

func _on_bug_died(bug: Node3D) -> void:
	if stage != CLEAR or not bugs.has(bug):
		return
	var identity: int = bug.get_instance_id()
	if _counted_deaths.has(identity):
		return
	_counted_deaths[identity] = true
	kills += 1
	if kills == total_bugs:
		stage = ACTIVATE
		progress = 0.0
	_update_objective()

func _on_shot(hit: bool, _distance: float) -> void:
	if hit:
		hit_flash = 0.16

func damage_player(amount: float) -> void:
	if paused or stage >= COMPLETE or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	damage_flash = 0.35
	if health <= 0.0:
		stage = FAILED
		progress = 0.0
		_sync_pause()
	_update_objective()

func set_paused(value: bool) -> void:
	paused = value
	_sync_pause()

func _sync_pause() -> void:
	var stopped: bool = paused or stage >= COMPLETE
	get_tree().paused = stopped
	player.set("blocked", stopped)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if stopped or qa_mode else Input.MOUSE_MODE_CAPTURED

func restart() -> void:
	# Reuse environment/player, discard enemies and effects; no scene reload race.
	for bug: Node in bugs:
		if is_instance_valid(bug):
			remove_child(bug)
			bug.queue_free()
	bugs.clear()
	_counted_deaths.clear()
	stage = CLEAR
	health = 100.0
	kills = 0
	total_bugs = BUG_STARTS.size()
	progress = 0.0
	terminal_completed = false
	elapsed = 0.0
	hit_flash = 0.0
	damage_flash = 0.0
	paused = false
	player.set("ammo", 20)
	player.set("reload_left", 0.0)
	player.set("cooldown", 0.0)
	player.set("recoil", 0.0)
	player.set("aiming", false)
	player.set("qa_direction", Vector3.ZERO)
	player.set("qa_jump", false)
	player.call("reset_position")
	for index: int in range(BUG_STARTS.size()):
		var bug: CharacterBody3D = CharacterBody3D.new()
		bug.set_script(BUG_SCRIPT)
		bug.name = "TBug%02d" % (index + 1)
		bug.position = BUG_STARTS[index] + Vector3(0, 0.06, 0)
		bug.set("mission", self)
		bug.set("patrol_index", index)
		bug.connect("died", _on_bug_died)
		bugs.append(bug)
		add_child(bug)
	_sync_pause()
	_update_objective()

func _exit_tree() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
