@tool
extends Node3D
@export var asset_id: String = "A"
func _ready() -> void:
	if "--whitebox" in OS.get_cmdline_user_args(): return
	var path: String="res://assets/environment/"+asset_id+"/"+asset_id+".glb"
	if not ResourceLoader.exists(path):
		push_error("Missing approved final asset: "+path)
		return
	if has_node("FinalVisual"): return
	for mesh: MeshInstance3D in find_children("*","MeshInstance3D",true,false):mesh.visible=false
	var visual: Node3D=load(path).instantiate()
	visual.name="FinalVisual"
	var material: StandardMaterial3D=load("res://scripts/environment_material.gd").create(asset_id)
	for mesh: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):mesh.material_override=material
	add_child(visual)
