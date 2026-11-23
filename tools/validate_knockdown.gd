extends SceneTree
var checks: Array=[]
var scene: Node3D
var out: String
func _initialize() -> void: run.call_deferred()
func check(name: String, passed: bool) -> void:
	checks.append({"check":name,"passed":passed})
	print("TARGET_QA ",name," ",passed)
func settle(n: int) -> void:
	for i in n: await physics_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name+".png"))
func run() -> void:
	out = OS.get_environment("KNOCKDOWN_QA_OUTPUT")
	if out.is_empty(): out = "res://docs/validation/knockdown-targets"
	scene=load("res://scenes/training.tscn").instantiate()
	root.add_child(scene)
	scene.player.qa_mode=true
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await settle(12)
	for t in scene.layout.targets:
		var target: StaticBody3D=scene.get_node(t.id)
		var player: CharacterBody3D=scene.player
		player.position=scene.vector(t.shoot_from)
		player.rotation=Vector3.ZERO
		player.head.look_at(target.position+Vector3(0,1.5,0))
		await settle(12)
		player.cooldown=0;player.ammo=20
		var before: int=scene.hits
		player.fire()
		check(t.id+"_hit_and_disable",target.knocked_down and target.collision_layer==0 and scene.hits==before+1)
		check(t.id+"_reject_duplicate",not target.register_hit() and target.hits==1)
		await settle(35)
		check(t.id+"_lies_flat",absf(target.get_node("Pivot").rotation.x+PI/2)<.001)
		player.cooldown=0;player.fire()
		check(t.id+"_no_score_on_empty_space",scene.hits==before+1)
		if t.id=="Target1":
			player.position=target.position+Vector3(1.7,.05,3)
			player.head.look_at(target.position+Vector3(0,.1,-.7))
			await settle(5)
			await capture("01-fallen")
	scene.reset_range()
	check("reset_all_five",get_nodes_in_group("targets").all(func(t):return not t.knocked_down and t.hits==0 and t.collision_layer==4 and t.get_node("Pivot").rotation==Vector3.ZERO))
	var first: StaticBody3D=scene.get_node("Target1")
	first.register_hit()
	await settle(5)
	scene.set_paused(true)
	var rotation_before: Vector3=first.get_node("Pivot").rotation
	await settle(15)
	check("pause_freezes_fall",first.get_node("Pivot").rotation==rotation_before)
	scene.reset_range()
	await settle(35)
	check("reset_during_fall_stays_upright",not first.knocked_down and first.get_node("Pivot").rotation==Vector3.ZERO)
	scene.player.position=first.position+Vector3(1.7,.05,3)
	scene.player.head.look_at(first.position+Vector3(0,1.1,0))
	await settle(5)
	await capture("02-restored")
	check("can_hit_again",first.register_hit() and first.hits==1)
	var failures:=checks.filter(func(c):return not c.passed)
	var f:=FileAccess.open(out.path_join(DisplayServer.get_name()+".json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures.size()},"\t"))
	print("TARGET_QA_COMPLETE ",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
