extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene: Node3D=load("res://scenes/training.tscn").instantiate()
	root.add_child(scene)
	scene.player.qa_mode=true
	await process_frame
	var sources: Dictionary={}
	var checks: Array=[]
	for module: Node3D in scene.get_node("Facility").get_children():
		sources[module.scene_file_path]=true
		checks.append({"check":str(module.name)+"_unit_scale","passed":module.scale.is_equal_approx(Vector3.ONE)})
	checks.append({"check":"five_module_resources_with_B_subtypes","passed":sources.size()==5})
	var variants: Dictionary={}
	for module: Node3D in scene.get_node("Facility").get_children():
		if module.has_meta("subtype"):
			var key: String=module.get_meta("subtype")
			variants[key]=variants.get(key,0)+1
	checks.append({"check":"six_each_thermal_subtype","passed":variants.get("B1",0)==6 and variants.get("B2",0)==6})
	var signal_tower: Node3D=scene.get_node("Landmarks/SignalTower")
	if scene.layout.get("asset_mode", "whitebox") == "final":
		var assets: Dictionary={}
		var material_ids: Dictionary={}
		var all_modules: Array=scene.get_node("Facility").get_children()
		all_modules.append(signal_tower)
		for module: Node3D in all_modules:
			var visual := module.get_node_or_null("FinalVisual")
			checks.append({"check":str(module.name)+"_final_visual","passed":visual!=null})
			if visual==null: continue
			var asset: String=module.get("asset_id")
			assets[asset]=assets.get(asset,0)+1
			var meshes:=visual.find_children("*","MeshInstance3D",true,false)
			checks.append({"check":str(module.name)+"_single_mesh","passed":meshes.size()==1})
			for mesh: MeshInstance3D in meshes:
				material_ids[mesh.material_override.get_instance_id()]=true
		checks.append({"check":"six_assets_59_instances","passed":assets=={"A":40,"B1":6,"B2":6,"C":2,"D":4,"E":1}})
		checks.append({"check":"six_shared_materials","passed":material_ids.size()==6})
	checks.append({"check":"signal_at_center","passed":signal_tower.position==Vector3.ZERO})
	var foot: CollisionShape3D=signal_tower.get_node("Foot/Collision")
	checks.append({"check":"three_metre_side_clearance","passed":foot.shape.size.x==2 and foot.shape.size.z==2})
	for link in scene.layout.connections:
		var a: Node3D=scene.get_node("Facility/"+link[0]+"/"+link[1])
		var b: Node3D=scene.get_node("Facility/"+link[2]+"/"+link[3])
		checks.append({"check":"socket_"+link[0],"passed":a.global_position.distance_to(b.global_position)<.001})
	for name in ["C01","C02"]:
		var bridge: Node3D=scene.get_node("Facility/"+name)
		var deck: CollisionShape3D=bridge.get_node("Deck/Collision")
		var clearance: float=deck.global_position.y-deck.shape.size.y/2
		checks.append({"check":name+"_headroom","passed":clearance>=2.2,"metres":clearance})
	var failures:=checks.filter(func(c):return not c.passed)
	var out: String="res://"+OS.get_environment("LUNA_QA_OUTPUT")+"/" if OS.has_environment("LUNA_QA_OUTPUT") else "res://docs/validation/energy-whitebox-v2/"
	DirAccess.make_dir_recursive_absolute(out)
	var f:=FileAccess.open(out+"modules.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures.size(),"sources":sources.keys()},"\t"))
	print("MODULE_CHECKS ",checks.size()," failures=",failures.size())
	quit(0 if failures.is_empty() else 1)
