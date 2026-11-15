extends SceneTree
var materials:Dictionary={}
var triangles:=0
var mesh_count:=0
func visit(n:Node) -> void:
	if n is MeshInstance3D and n.mesh:
		mesh_count+=1
		triangles+=n.mesh.get_faces().size()/3
		for surface in n.mesh.get_surface_count():
			var m=n.get_active_material(surface)
			if m:materials[m.get_instance_id()]=m.resource_name if not m.resource_name.is_empty() else m.get_class()
	for c in n.get_children():visit(c)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var w=load("res://scenes/training.tscn").instantiate();root.add_child(w)
	for i in 20:await process_frame
	visit(w.player.weapon)
	var f=FileAccess.open("res://docs/validation/ls01-refine-v1/weapon-metrics-"+("after" if w.player.weapon.ls01 else "before")+".json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"triangles_including_runtime_meshes":triangles,"mesh_instances":mesh_count,"unique_materials":materials.size(),"materials":materials.values(),"label3d_font_material_not_counted":true},"  "))
	quit()
