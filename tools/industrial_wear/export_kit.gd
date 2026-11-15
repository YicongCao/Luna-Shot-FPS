extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var kit:=Node3D.new();kit.set_script(load("res://scripts/weapon_field_kit.gd"));root.add_child(kit)
	for cell in kit.cells:cell.free()
	kit.readout.free()
	var doc:=GLTFDocument.new();var state:=GLTFState.new()
	assert(doc.append_from_scene(kit,state)==OK)
	assert(doc.write_to_filesystem(state,"res://art_source/industrial-wear-v1/kit-whitebox.glb")==OK)
	quit()
