@tool
extends Node3D
var paint: ShaderMaterial
var strips: Array[MeshInstance3D]=[]
func _ready() -> void:
	var baseline:=OS.get_environment("ENV_BASELINE").split(",")
	if "--whitebox" in OS.get_cmdline_user_args() or ["B1","B2","C","D","E"].all(func(a):return a in baseline):return
	batch_grid()
	paint=ShaderMaterial.new();paint.shader=load("res://assets/environment/shared/reflective_paint.gdshader")
	var firing:=get_parent().get_node_or_null("FiringLine/Mesh")
	if firing: firing.material_override=paint
	for side in [-1,1]:
		for i in range(-7,8):
			if abs(i)<=1:continue
			var along:=float(i)*4.0
			strip(Vector3(side*4,.031,along),Vector3(.10,.004,2.4))
			strip(Vector3(along,.031,side*4),Vector3(2.4,.004,.10))
func strip(pos: Vector3, dimensions: Vector3) -> void:
	var mesh:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=dimensions;mesh.mesh=box
	mesh.position=pos;mesh.material_override=paint;mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh);strips.append(mesh)

func batch_grid() -> void:
	var sources: Array[MeshInstance3D]=[]
	for node in get_parent().get_children():
		if str(node.name).begins_with("Grid"):
			var mesh:=node.get_node_or_null("Mesh") as MeshInstance3D
			if mesh and mesh.mesh is BoxMesh:sources.append(mesh)
	if sources.is_empty():return
	var batch:=MultiMeshInstance3D.new();batch.name="SharedGroundGrid"
	var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D
	var unit:=BoxMesh.new();unit.size=Vector3.ONE;data.mesh=unit;data.instance_count=sources.size()
	for i in sources.size():
		var pose: Transform3D=global_transform.affine_inverse()*sources[i].global_transform
		pose.basis=pose.basis.scaled(sources[i].mesh.size);data.set_instance_transform(i,pose);sources[i].visible=false
	batch.multimesh=data;batch.material_override=sources[0].get_active_material(0);add_child(batch)
