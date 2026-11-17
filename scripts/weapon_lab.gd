extends Node3D
var OUT: String = "res://" + OS.get_environment("LUNA_QA_OUTPUT") + "/" if OS.has_environment("LUNA_QA_OUTPUT") else "res://docs/validation/rifle-pipeline-v2/"
const MODES := ["FINAL PBR", "BAKED NORMAL OFF", "UNIFORM MATERIAL RESPONSE", "CLAY", "BASE COLOR", "METALLIC", "ROUGHNESS", "AO", "BAKED NORMAL ONLY"]
const LIGHTS := ["NEUTRAL STUDIO", "WARM GRAZING", "COOL REVERSE"]
var gun: Node3D
var camera: Camera3D
var key: DirectionalLight3D
var fill: DirectionalLight3D
var label: Label
var mode := 0
var rig := 0
var yaw := 1.08
var pitch := .26
var distance := 1.42
var center := Vector3(0,.025,-.21)
var qa := false
var dragging := false
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	qa = "--lab-qa" in OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = load("res://scripts/weapon_lighting.gd").environment()
	add_child(env)
	gun = load("res://assets/weapons/lc01/lc01.tscn").instantiate()
	add_child(gun)
	camera = Camera3D.new()
	camera.fov = 43
	camera.near = .01
	add_child(camera)
	camera.make_current()
	key = DirectionalLight3D.new()
	add_child(key)
	fill = DirectionalLight3D.new()
	add_child(fill)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(30,24)
	label.add_theme_font_size_override("font_size",19)
	layer.add_child(label)
	var footer := Label.new()
	footer.position = Vector2(30,810)
	footer.text = "DRAG  Orbit     WHEEL  Zoom     1–9  Surface modes     L  Lighting     B  Energy on/off     F3  Training range\nLS01  /  LAYERED METAL  /  ML07  /  actual Godot render"
	if gun.revision=="ml09":footer.text=footer.text.replace("ML07", "ML09")
	if not gun.ls01:footer.text=footer.text.replace("1–9", "1–4").replace("LS01  /  LAYERED METAL  /  ML07", "LC01  /  " + revision_title())
	footer.add_theme_font_size_override("font_size",16)
	layer.add_child(footer)
	set_rig(0)
	update_camera()
	update_label()
	if qa: run_qa.call_deferred()
func update_label() -> void:
	label.text = ("LS01  /  MATERIAL STUDIO\n%s   ·   %s" if gun.ls01 else "LC01  /  " + revision_title() + "\n%s   ·   %s") % [MODES[mode],LIGHTS[rig]] + ("   ·   ENERGY OFF" if not gun.energy_enabled else "")
func revision_title() -> String:
	return "ML20 HUNYUAN BAKE" if gun.revision == "ml20" else "ML06 BASELINE"
func update_camera() -> void:
	camera.position = center + Vector3(cos(pitch)*sin(yaw),sin(pitch),cos(pitch)*cos(yaw))*distance
	camera.look_at(center)
func set_rig(value: int) -> void:
	rig = value
	var angles := [Vector3(-35,-35,0),Vector3(-8,65,0),Vector3(-55,155,0)]
	key.rotation_degrees = angles[rig]
	key.light_energy = [1.5,2.0,1.8][rig]
	key.light_color = [Color(1,.97,.92),Color(1,.76,.53),Color(.66,.81,1)][rig]
	fill.rotation_degrees = Vector3(20,140,0)
	fill.light_energy = .25
	fill.light_color = Color(.7,.82,1)
func _unhandled_input(event: InputEvent) -> void:
	if qa: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT: dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(.45,distance-.08)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(3,distance+.08)
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x*.008
		pitch = clampf(pitch+event.relative.y*.008,-1.3,1.3)
	if event is InputEventKey and event.pressed:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= (KEY_9 if gun.ls01 else KEY_4):
			mode = event.physical_keycode-KEY_1
			gun.set_surface_mode(mode)
		if event.physical_keycode == KEY_L: set_rig((rig+1)%3)
		if event.physical_keycode == KEY_B: gun.set_energy_enabled(not gun.energy_enabled)
		if event.physical_keycode == KEY_F3:
			get_tree().change_scene_to_file("res://scenes/training.tscn")
			return
	update_camera()
	update_label()
func capture(name: String) -> void:
	for i in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(OUT+name+".png")
	assert(error == OK)
	print("LAB_CAPTURE ",name)
func run_qa() -> void:
	await capture("01-hero-pbr")
	mode = 1; gun.set_surface_mode(mode); update_label()
	await capture("02-hero-no-normal")
	mode = 2; gun.set_surface_mode(mode); update_label()
	await capture("03-hero-uniform-response")
	mode = 3; gun.set_surface_mode(mode); update_label()
	await capture("04-hero-clay")
	mode = 0; gun.set_surface_mode(mode); set_rig(1); update_label()
	await capture("05-hero-warm")
	set_rig(2); update_label()
	await capture("06-hero-cool")
	set_rig(0); yaw = PI/2; pitch = .06; update_camera(); update_label()
	await capture("07-side")
	yaw = -1.1; pitch = .24; update_camera()
	await capture("08-reverse")
	center = Vector3(0,.015,-.13); distance = .72; yaw=1.3; pitch=.12; update_camera()
	await capture("09-surface-close")
	mode=1;gun.set_surface_mode(mode);update_label()
	await capture("10-surface-no-normal")
	mode=0;gun.set_surface_mode(mode);update_label()
	center=Vector3(0,.055,-.40);distance=.62;yaw=PI/2;pitch=.12;update_camera()
	await capture("17-coils-on-right")
	gun.set_energy_enabled(false);update_label()
	await capture("18-coils-off-right")
	gun.set_energy_enabled(true);update_label()
	yaw=-PI/2;update_camera()
	await capture("19-coils-on-left")
	center=Vector3(0,.025,.14);distance=.55;yaw=1.15;pitch=.28;update_camera()
	await capture("20-stock-right")
	yaw=-1.15;update_camera()
	await capture("21-stock-left")
	print("LAB_QA_COMPLETE")
	get_tree().quit()
