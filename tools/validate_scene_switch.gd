extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func press_f3() -> void:
	var e := InputEventKey.new()
	e.physical_keycode=KEY_F3;e.pressed=true
	Input.parse_input_event(e)
	await frames(8)
	e=InputEventKey.new();e.physical_keycode=KEY_F3;e.pressed=false
	Input.parse_input_event(e)
	await frames(8)
func run() -> void:
	change_scene_to_file("res://scenes/training.tscn")
	await frames(10)
	await press_f3()
	var lab_ok := current_scene.name == "WeaponLab"
	await press_f3()
	var range_ok := current_scene.has_node("Player")
	var one_binding := InputMap.action_get_events("studio").size()==1
	var f:=FileAccess.open("res://docs/validation/rifle-pipeline-v2/scene-switch.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"f3_to_lab":lab_ok,"f3_to_range":range_ok,"no_duplicate_input_bindings":one_binding},"\t"))
	print("SCENE_SWITCH ",lab_ok," ",range_ok," ",one_binding)
	quit(0 if lab_ok and range_ok and one_binding else 1)
