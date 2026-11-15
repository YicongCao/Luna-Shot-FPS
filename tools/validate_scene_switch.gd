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
	var no_range_flare_in_lab := current_scene.find_children("OpticalEffects","CanvasLayer",true,false).is_empty()
	await press_f3()
	var range_ok := current_scene.has_node("Player")
	var one_binding := InputMap.action_get_events("studio").size()==1
	var out := OS.get_environment("LUNA_QA_OUTPUT")
	if out.is_empty(): out="docs/validation/environment-pipeline-v1/rifle"
	DirAccess.make_dir_recursive_absolute("res://"+out)
	var f:=FileAccess.open("res://"+out+"/scene-switch.json",FileAccess.WRITE)
	var range_lighting_restored := current_scene.has_node("LunarLighting/OpticalEffects")
	f.store_string(JSON.stringify({"f3_to_lab":lab_ok,"f3_to_range":range_ok,"no_duplicate_input_bindings":one_binding,"no_range_flare_in_lab":no_range_flare_in_lab,"range_lighting_restored":range_lighting_restored},"\t"))
	print("SCENE_SWITCH ",lab_ok," ",range_ok," ",one_binding)
	quit(0 if lab_ok and range_ok and one_binding and no_range_flare_in_lab and range_lighting_restored else 1)
