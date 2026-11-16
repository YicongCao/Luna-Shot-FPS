@tool
extends Node3D
@export var asset_id: String = "A"
func _ready() -> void:
	if "--whitebox" in OS.get_cmdline_user_args(): return
	var folder := "res://assets/environment/" + asset_id
	if asset_id in OS.get_environment("ENV_CANDIDATE").split(","):
		folder = "res://assets/environment/candidates/" + asset_id
	if asset_id in OS.get_environment("ENV_BASELINE").split(","):
		folder = "res://assets/environment/baselines/" + asset_id
	var path: String=folder+"/"+asset_id+".glb"
	if not ResourceLoader.exists(path):
		push_error("Missing approved final asset: "+path)
		return
	if has_node("FinalVisual"): return
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):mesh.visible=false
	var visual: Node3D=load(path).instantiate()
	visual.name="FinalVisual"
	var binding_path := folder + "/bindings.json"
	var bindings: Dictionary = {}
	if FileAccess.file_exists(binding_path):
		bindings = JSON.parse_string(FileAccess.get_file_as_string(binding_path))
		for mesh: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			if not bindings.meshes.has(str(mesh.name)):
				push_error("Missing ML15 material binding: " + str(mesh.name))
				continue
			mesh.material_override = load("res://scripts/environment_refined_material.gd").create(folder, bindings.meshes[str(mesh.name)])
	else:
		var material: StandardMaterial3D=load("res://scripts/environment_material.gd").create(asset_id)
		for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=material
	add_child(visual)
	if not bindings.is_empty():
		var lamps := Node3D.new()
		lamps.set_script(load("res://scripts/facility_lamps.gd"))
		lamps.asset_id = asset_id
		lamps.mounts = bindings.fixtures.get("mounts", [])
		if lamps.mounts.size() != {"B1":4,"B2":4,"C":4,"D":6,"E":1}.get(asset_id,0):
			push_error("Invalid ML15 fixture mount count: " + asset_id)
		add_child(lamps)
	# Added after whitebox hiding/material binding so animated parts stay visible
	# and keep their own metal/paint materials. Regenerating the map retains this.
	if asset_id == "B2" and not has_node("CoolingFans"):
		var fans := Node3D.new()
		fans.set_script(load("res://scripts/b2_cooling_fans.gd"))
		add_child(fans)
