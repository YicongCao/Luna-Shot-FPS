extends SceneTree
var mission: Node3D
var checks: Array[Dictionary] = []
var output: String = "res://docs/validation/quarantine-benchmark-v1/feedback"
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("FEEDBACK CHECK ",id," ",ok)
func aim(point: Vector3) -> void:
	var p: Node = mission.player
	var d: Vector3 = point-p.camera.global_position
	p.rotation.y=atan2(-d.x,-d.z)
	p.head.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
func capture(name: String) -> void:
	await frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	if not OS.get_environment("QUARANTINE_BENCHMARK_QA_ROOT").is_empty():
		output=OS.get_environment("QUARANTINE_BENCHMARK_QA_ROOT")+"/feedback"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	mission=load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	await frames(75)
	var player: Node = mission.player
	player.qa_mode=true
	for b in mission.bugs: b.set_physics_process(false)
	player.position=Vector3(0,.05,-20.2)
	await frames(4)
	aim(Vector3(0,2.14,-21.94))
	# Visibility is sampled at 10 Hz and fades over time; frame counts vary with GPU speed.
	await create_timer(1.0).timeout
	var hologram: Node=mission.get_node("World/HolographicTerminal")
	check("locked_hologram_has_no_enabled_action",hologram.readable and not hologram.panel.can_interact)
	await capture("00-terminal-locked")
	var bug: Node3D=mission.bugs[0]
	bug.position=Vector3(1.4,.05,16)
	player.position=Vector3(0,.05,19)
	await frames(5)
	aim(bug.position+Vector3(0,.5,0))
	await frames(25)
	var effect: Node3D=bug.electrical_damage
	var node_count: int=effect.get_child_count()
	player.cooldown=0
	check("first_real_shot",player.fire())
	check("damage_still_one_hp_per_hit",bug.health==2 and not bug.dead)
	check("effect_uses_authoritative_hit_point",effect.hits==1 and effect.last_world_hit.is_equal_approx(player.last_hit.position))
	check("local_plate_damage_persists",effect.burned.size()==1)
	check("arc_budget_bounded",effect.segment_count>0 and effect.segment_count<=24)
	effect.set_process(false)
	effect.age=.09
	effect.refresh_arcs()
	await capture("01-hit-gameplay")
	player.get_node("WeaponLayer").hide()
	mission.hud.hide()
	await capture("02-hit-inspection")
	effect.set_process(true)
	mission.set_paused(true)
	var age: float=effect.age
	await frames(12)
	check("damage_effect_obeys_true_pause",is_equal_approx(age,effect.age))
	mission.set_paused(false)
	# Two further real hits, with authoritative cooldown reset for deterministic QA.
	for i in 2:
		await frames(15)
		aim(bug.position+Vector3(0,.5,0))
		player.cooldown=0
		check("additional_real_shot_%d"%i,player.fire())
	check("three_hits_one_death",bug.dead and bug.health==0 and mission.kills==1 and effect.hits==3)
	check("effects_do_not_allocate_nodes_per_hit",effect.get_child_count()==node_count)
	await create_timer(.36).timeout
	effect.set_process(false)
	effect.age=.38
	effect.refresh_arcs()
	await capture("03-death-residual")
	effect.set_process(true)
	await create_timer(2.0).timeout
	check("residual_arcs_expire",not effect.arc_node.visible and not effect.is_processing())
	check("dead_core_stays_unpowered",not bug.core_material.emission_enabled)
	await capture("04-damaged-corpse")
	# An architecture wall intercepts the next shot; no remote target damage/effects.
	var next_bug: Node3D=mission.bugs[1]
	next_bug.position=Vector3(1.4,.05,16)
	var wall: StaticBody3D=StaticBody3D.new()
	wall.position=Vector3(.65,1.0,17.5)
	var shape: CollisionShape3D=CollisionShape3D.new()
	var box: BoxShape3D=BoxShape3D.new()
	box.size=Vector3(4,3,.3)
	shape.shape=box
	wall.add_child(shape)
	mission.add_child(wall)
	await physics_frame
	await physics_frame
	aim(next_bug.position+Vector3(0,.5,0))
	player.cooldown=0
	player.fire()
	check("wall_prevents_enemy_damage_and_electrics",next_bug.health==3 and next_bug.electrical_damage.hits==0)
	wall.queue_free()
	await frames(3)
	# Pure projection helper: front, side, behind, and safe-area edge bounds.
	var hud_script: Script=load("res://scripts/quarantine/hud.gd")
	var projection: Projection=player.camera.get_camera_projection()
	var size: Vector2=Vector2(1920,810)
	var front: Dictionary=hud_script.objective_marker_layout(Vector3(0,0,-10),projection,size)
	var right: Dictionary=hud_script.objective_marker_layout(Vector3(100,0,-10),projection,size)
	var back: Dictionary=hud_script.objective_marker_layout(Vector3(0,0,10),projection,size)
	check("objective_front_projects_inside",front.inside and not front.behind)
	check("objective_right_clamps_to_right_edge",not right.inside and right.position.x>size.x*.8 and right.position.x<size.x)
	check("objective_behind_has_edge_direction",back.behind and not back.inside and back.direction.length()>.9)
	var tilted_back: Dictionary=hud_script.objective_marker_layout(Vector3(0,12,40),projection,size)
	check("aft_ground_target_never_points_into_sky",tilted_back.direction.y>0 and tilted_back.position.y>size.y*.5)
	for b in mission.bugs:
		while not b.dead: b.register_hit()
	player.get_node("WeaponLayer").show()
	mission.hud.show()
	player.position=Vector3(0,.05,20)
	await frames(4)
	aim(Vector3(0,2,-22))
	await capture("05-terminal-waypoint")
	aim(Vector3(0,2,32))
	await capture("06-terminal-behind")
	player.position=Vector3(0,.05,-20.2)
	await frames(4)
	aim(Vector3(0,2.14,-21.94))
	# Visibility is sampled at 10 Hz and fades over time; frame counts vary with GPU speed.
	await create_timer(1.0).timeout
	check("ready_hologram_owns_interaction_prompt",hologram.readable and hologram.panel.can_interact and mission.hud._terminal_panel_readable())
	await capture("07-terminal-E")
	Input.action_press("interact")
	await create_timer(1.35).timeout
	check("hold_keeps_item_incomplete_until_committed",mission.progress>0 and mission.progress<1 and not mission.terminal_completed)
	await capture("07b-terminal-hold")
	Input.action_release("interact")
	await physics_frame
	await physics_frame
	check("release_resets_hologram_action",mission.progress==0 and not mission.terminal_completed)
	mission._update_activation(3.1,true)
	await frames(20)
	check("activated_terminal_item_is_one",mission.terminal_completed)
	await capture("07c-terminal-success")
	aim(Vector3(0,2,27))
	await capture("08-extraction-waypoint")
	check("terminal_to_extraction_stage",mission.stage==mission.EXTRACT)
	var file: FileAccess=FileAccess.open(output+"/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"boundary":"Actual native hitscan and architecture occlusion. Hit inspection holds effect age at 90ms; death inspection at 380ms. Not an unassisted playthrough or physical fracture simulation."},"\t"))
	file.close()
	mission.queue_free()
	await frames(15)
	quit(0 if checks.all(func(c):return c.ok) else 1)
