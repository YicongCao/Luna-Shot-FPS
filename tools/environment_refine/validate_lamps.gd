extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
	world.player.qa_mode=true
	await process_frame
	var modules:=get_nodes_in_group("facility_lamp_modules")
	var checks: Array=[];var total:=0;var phases: Dictionary={}
	for module in modules:
		if module.asset_id not in ["B1","B2"]:continue
		total+=module.fixtures.size();phases[module.phase]=true
		module.set_process(false);module.forced_level=-1
		var old_phase: float=module.phase;module.phase=0
		module.elapsed=.12;module.refresh()
		checks.append({"check":str(module.get_parent().name)+"_all_four_on","passed":module.fixtures.size()==4 and module.fixtures.all(func(f):return f.level>.99)})
		module.elapsed=.31;module.refresh()
		checks.append({"check":str(module.get_parent().name)+"_all_four_off","passed":module.fixtures.all(func(f):return f.level==0)})
		for fixture in module.fixtures:
			var local: Vector3=module.get_parent().to_local(fixture.mesh.global_position)
			checks.append({"check":"lamp_envelope","passed":absf(local.x)<2 and absf(local.z)<2 and local.y+.0575<=6})
		module.phase=old_phase;module.set_process(true)
	checks.append({"check":"red_count","passed":total==modules.filter(func(m):return m.asset_id in ["B1","B2"]).size()*4})
	var blue_count:=0
	for module in modules:
		if module.asset_id not in ["C","D"]:continue
		var expected:=4 if module.asset_id=="C" else 6
		checks.append({"check":str(module.get_parent().name)+"_blue_count","passed":module.fixtures.size()==expected})
		for fixture in module.fixtures:
			blue_count+=1
			checks.append({"check":"blue_always_on","passed":fixture.level==1.0 and fixture.material.emission_enabled})
			var p: Vector3=fixture.mesh.position
			checks.append({"check":"blue_inside_boundary","passed":absf(p.x)+.0075<=2})
	checks.append({"check":"tower_phase_variation","passed":phases.size()>1})
	for module in modules:
		if module.asset_id!="E":continue
		checks.append({"check":"one_amber_beacon","passed":module.fixtures.size()==1})
		module.set_process(false);module.phase=0;module.elapsed=.25;module.refresh()
		var beacon: Node3D=module.fixtures[0].beacon
		checks.append({"check":"beacon_14_2m_envelope","passed":beacon.position.y+.0875<=14.2})
		checks.append({"check":"beacon_quarter_rotation","passed":is_equal_approx(beacon.rotor.rotation.y,PI*.5)})
		module.elapsed=1.25;module.refresh();checks.append({"check":"beacon_period_one_second","passed":is_equal_approx(beacon.rotor.rotation.y,PI*.5)})
		module.set_process(true)
	checks.append({"check":"local_pool_limit","passed":world.lighting.module_light_pool.size()==8})
	world.lighting.set_facility_enabled(false);await process_frame;await process_frame
	checks.append({"check":"facility_switch_disables_spill","passed":world.lighting.module_light_pool.all(func(l):return not l.visible)})
	var out:=OS.get_environment("ENV_QA_OUT")
	if out.is_empty():out="res://docs/validation/environment-refine-v2/B1/published"
	DirAccess.make_dir_recursive_absolute(out)
	var failures:=checks.filter(func(c):return not c.passed).size()
	FileAccess.open(out+"/lamps.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"red_lenses":total,"blue_segments":blue_count},"\t"))
	print("ENV_LAMPS ",checks.size()," failures=",failures);quit(0 if failures==0 else 1)
