extends Node3D
var player: CharacterBody3D
var overview := false
var paused := false
var hits := 0
var shots := 0
var hit_time := 0.0
var last_distance := 0.0
var hud: Control
var title: Label
var status: Label
var help: Label
var ammo_label: Label
var pause_panel: PanelContainer
var reticle: Label
var qa_mode := false
var layout: Dictionary = {}
var lighting: Node3D

func vector(values: Array) -> Vector3:
	return Vector3(values[0],values[1],values[2])

func marker(name: String) -> Vector3:
	return get_node("Markers/"+name).global_position

func _ready() -> void:
	layout = JSON.parse_string(FileAccess.get_file_as_string(get_meta("layout_path")))
	configure_input()
	player = $Player
	$Overview.position = marker("OverviewCamera")
	$Overview.look_at(marker("OverviewFocus"))
	player.spawn_position = marker("Spawn")
	player.reset_position()
	player.shot.connect(on_shot)
	qa_mode = "--qa" in OS.get_cmdline_user_args() or "--rifle-qa" in OS.get_cmdline_user_args()
	build_hud()
	lighting=Node3D.new()
	lighting.name="LunarLighting"
	lighting.set_script(load("res://scripts/lunar_lighting.gd"))
	add_child(lighting)
	if qa_mode:
		player.qa_mode = true
		var qa := Node.new()
		qa.set_script(load("res://scripts/rifle_qa.gd" if "--rifle-qa" in OS.get_cmdline_user_args() else "res://scripts/qa.gd"))
		add_child(qa)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func configure_input() -> void:
	var bindings := {"forward": KEY_W, "back": KEY_S, "left": KEY_A, "right": KEY_D, "sprint": KEY_SHIFT, "jump": KEY_SPACE, "reload": KEY_R, "reset": KEY_F5, "overview": KEY_F2, "pause": KEY_ESCAPE, "studio": KEY_F3}
	for action in bindings:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action]
		InputMap.action_add_event(action, key)
	for action in ["fire", "aim"]:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT if action == "fire" else MOUSE_BUTTON_RIGHT
		InputMap.action_add_event(action, button)

func text_label(text: String, size: int, pos: Vector2, parent: Node) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(.92,.94,.94))
	label.add_theme_color_override("font_shadow_color", Color(0,0,0,.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(label)
	return label

func build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title = text_label("LUNA SHOT / TRAINING", 25, Vector2(28,22), hud)
	var ground_surface:=get_node_or_null("GroundSurface")
	var milestone:="ML—16" if ground_surface and ground_surface.get("surface")!=null else "ML—15"
	text_label("%s   /   LUNAR ENERGY   /   %d × %d m" % [milestone,layout.size[0],layout.size[1]], 13, Vector2(29,57), hud)
	status = text_label("", 17, Vector2(28,92), hud)
	help = text_label("WASD  Move     SHIFT  Sprint     SPACE  Jump     LMB  Fire     RMB  Aim     R  Reload\nF2  Survey view     F3  Material studio     F5  Reset range     ESC  Release mouse", 15, Vector2.ZERO, hud)
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 28
	help.offset_top = -65
	help.offset_right = 1000
	help.offset_bottom = -15
	var effect_help:=text_label("F6 Energy  /  F7 Bloom  /  F8 Flares  /  F9 Local spill",12,Vector2(29,77),hud)
	effect_help.modulate=Color(.65,.73,.8)
	ammo_label = text_label("", 29, Vector2.ZERO, hud)
	ammo_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.offset_left = -235
	ammo_label.offset_top = -85
	ammo_label.offset_right = -20
	ammo_label.offset_bottom = -15
	reticle = text_label("＋", 24, Vector2.ZERO, hud)
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.offset_left = -12
	reticle.offset_top = -19
	reticle.offset_right = 12
	reticle.offset_bottom = 19
	pause_panel = PanelContainer.new()
	hud.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.offset_left = -200
	pause_panel.offset_top = -110
	pause_panel.offset_right = 200
	pause_panel.offset_bottom = 110
	pause_panel.custom_minimum_size = Vector2(400,220)
	var box := VBoxContainer.new()
	pause_panel.add_child(box)
	var heading := Label.new()
	heading.text = "TRAINING PAUSED"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(heading)
	for entry in [["Resume / 继续", resume], ["Reset range / 重置", reset_range], ["Quit / 退出", quit_game]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 48
		button.pressed.connect(entry[1])
		box.add_child(button)
	pause_panel.hide()

func on_shot(hit: bool, distance: float) -> void:
	shots += 1
	last_distance = distance
	if hit:
		hits += 1
		hit_time = .16

func _process(delta: float) -> void:
	if not paused: hit_time = maxf(0, hit_time-delta)
	reticle.text = "×" if hit_time > 0 else "＋"
	reticle.modulate = Color(1,.65,.35) if hit_time > 0 else Color.WHITE
	reticle.visible = not overview and not paused and not player.aiming
	status.text = "%s   |   HITS %02d / SHOTS %02d   |   %.1f m" % ["SURVEY" if overview else "FREE PRACTICE", hits, shots, last_distance]
	ammo_label.text = "RELOADING" if player.reload_left > 0 else "%02d / ∞\nLS01" % player.ammo

func _unhandled_input(event: InputEvent) -> void:
	if qa_mode: return
	if event.is_action_pressed("pause"):
		if paused: resume()
		else: set_paused(true)
	elif event.is_action_pressed("overview") and not paused: set_overview(not overview)
	elif event.is_action_pressed("reset"): reset_range()
	elif event.is_action_pressed("studio"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/weapon_lab.tscn")

func set_paused(value: bool) -> void:
	paused = value
	for target in get_tree().get_nodes_in_group("targets"):
		target.animation_paused = value
	player.blocked = paused or overview
	pause_panel.visible = value
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused or overview else Input.MOUSE_MODE_CAPTURED
func resume() -> void: set_paused(false)
func quit_game() -> void: get_tree().quit()
func set_overview(value: bool) -> void:
	overview = value
	player.blocked = value or paused
	player.get_node("WeaponLayer").visible = not value
	if value: $Overview.make_current()
	else: player.camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if value or paused else Input.MOUSE_MODE_CAPTURED
func reset_range() -> void:
	for target in get_tree().get_nodes_in_group("targets"): target.reset()
	hits = 0
	shots = 0
	last_distance = 0
	player.ammo = player.CAPACITY
	player.reload_left = 0
	player.cooldown = 0
	player.aiming = false
	player.reset_position()
	set_overview(false)
	resume()
