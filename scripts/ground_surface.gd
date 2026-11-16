@tool
extends Node3D
# ML16: shared metre-scaled surface, one cover assembly, and local equipment seats.
@export var sample:=true
var baseline:=false
var surface: ShaderMaterial
var original_material: Material
var ground: MeshInstance3D
var originals: Array[MeshInstance3D]=[]
var batches: Dictionary={}
var counts: Dictionary={}
const DIR:="res://assets/environment/ground_v1/"
func _ready() -> void:
	ground=get_parent().get_node("Ground/Mesh")
	original_material=ground.get_active_material(0)
	for node in get_parent().get_children():
		if str(node.name).begins_with("Grid"):
			originals.append(node.get_node("Mesh"))
	surface=ShaderMaterial.new();surface.shader=load(DIR+"surface.gdshader")
	for pair in [["paving","paving"],["soil","regolith"]]:
		for c in [["color","BaseColor"],["orm","ORM"],["normal","NormalGL"]]:
			surface.set_shader_parameter(pair[0]+"_"+c[0],load(DIR+pair[1]+"/"+c[1]+".png"))
	surface.set_shader_parameter("soil_mask",load(DIR+("sample_mask.png" if sample else "field_mask.png")))
	surface.set_shader_parameter("area_origin",Vector2(-4,-4) if sample else Vector2(-32,-33))
	surface.set_shader_parameter("area_size",Vector2(8,8) if sample else Vector2(64,66))
	var metal:=StandardMaterial3D.new();metal.albedo_texture=load(DIR+"metal/BaseColor.png");metal.metallic=1;metal.metallic_texture=load(DIR+"metal/ORM.png");metal.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	metal.roughness_texture=metal.metallic_texture;metal.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN;metal.normal_enabled=true;metal.normal_texture=load(DIR+"metal/NormalGL.png");metal.normal_scale=.5;metal.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var trim:=StandardMaterial3D.new();trim.albedo_color=Color(.10,.12,.13);trim.metallic=.8;trim.roughness=.46
	var steel:=StandardMaterial3D.new();steel.albedo_color=Color(.35,.38,.39);steel.metallic=1;steel.roughness=.32
	var dark:=StandardMaterial3D.new();dark.albedo_color=Color(.025,.03,.032);dark.roughness=.9
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/design/ground-sample.json" if sample else "res://docs/design/energy-layout.json"))
	for module in layout.modules:
		if module.type=="A":seat(Vector3(module.position[0],0,module.position[2]),trim,steel,deg_to_rad(module.rotation_y))
	if sample:cover(Vector3(1.45,0,1.45),metal,trim,steel,dark)
	else:
		for x in [-2.8,2.8]:
			for z in [-24,-12,8,24]:cover(Vector3(x,0,z),metal,trim,steel,dark)
	if sample:
		var paint:=ShaderMaterial.new();paint.shader=load("res://assets/environment/shared/reflective_paint.gdshader")
		for z in [-3.0,0.0,3.0]:box("mark",Vector3(-.15,.018,z),Vector3(.09,.002,1.3),paint)
		pebbles()
	flush_batches()
	set_baseline(OS.get_environment("GROUND_BASELINE")=="1")
func set_baseline(value: bool) -> void:
	baseline=value;ground.material_override=original_material if value else surface
	for mesh in originals:mesh.visible=value
	for node in get_children():
		if node is GeometryInstance3D:node.visible=not value
	var markings:=get_parent().get_node_or_null("ReflectiveMarkings")
	if markings and markings.has_node("SharedGroundGrid"):markings.get_node("SharedGroundGrid").visible=value
func box(id: String,pos: Vector3,size: Vector3,mat: Material,yaw:=0.0) -> void:
	# Reuse exact dimensions through MultiMesh; no individual draw per repeated screw/frame.
	var key:=id+str(size)
	if not batches.has(key):
		var mesh:=BoxMesh.new();mesh.size=size;batches[key]={"mesh":mesh,"material":mat,"poses":[]}
	batches[key].poses.append(Transform3D(Basis(Vector3.UP,yaw),pos))
func bolt(pos: Vector3,steel: Material,dark: Material) -> void:
	if not batches.has("bolts"):
		var shape:=CylinderMesh.new();shape.top_radius=.014;shape.bottom_radius=.018;shape.height=.004;shape.radial_segments=12;batches.bolts={"mesh":shape,"material":steel,"poses":[]}
	batches.bolts.poses.append(Transform3D(Basis.IDENTITY,pos))
	box("cross_x",pos+Vector3(0,.0021,0),Vector3(.016,.0003,.003),dark)
	box("cross_z",pos+Vector3(0,.0021,0),Vector3(.003,.0003,.016),dark)
func seat(pos: Vector3,trim: Material,steel: Material,yaw: float) -> void:
	counts.seats=counts.get("seats",0)+1
	for s in [-1,1]:
		box("seat_x",pos+Vector3(s*1.955,.008,0),Vector3(.07,.016,3.98),trim)
		box("seat_z",pos+Vector3(0,.008,s*1.955),Vector3(3.84,.016,.07),trim)
	# Coordinates match A-refine foot plates (Blender Y becomes -Godot Z).
	for x in [-1.61,1.28]:
		for z in [-1.57,1.57]:box("anchor",pos+Vector3(x,.006,z).rotated(Vector3.UP,yaw),Vector3(.50,.012,.58),steel,yaw)
func cover(pos: Vector3,metal: Material,trim: Material,steel: Material,dark: Material) -> void:
	counts.covers=counts.get("covers",0)+1
	box("recess",pos+Vector3(0,.003,0),Vector3(1.46,.006,1.86),dark)
	box("lid",pos+Vector3(0,.010,0),Vector3(1.32,.014,1.72),metal)
	for s in [-1,1]:
		box("rim_x",pos+Vector3(s*.70,.009,0),Vector3(.05,.018,1.86),trim)
		box("rim_z",pos+Vector3(0,.009,s*.90),Vector3(1.35,.018,.05),trim)
		box("handle_recess",pos+Vector3(s*.48,.0172,0),Vector3(.065,.001,.24),dark)
		box("handle",pos+Vector3(s*.48,.018,0),Vector3(.022,.004,.18),steel)
		for z in [-.72,0,.72]:bolt(pos+Vector3(s*.59,.019,z),steel,dark)
func pebbles() -> void:
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.075,.073,.070);mat.roughness=.95
	var mesh:=PrismMesh.new();mesh.size=Vector3(.05,.025,.045)
	batches.pebbles={"mesh":mesh,"material":mat,"poses":[]}
	var rng:=RandomNumberGenerator.new();rng.seed=20261116
	for i in 28:
		var x:=rng.randf_range(.4,3.85);var z:=rng.randf_range(3.5,3.9)
		var basis:=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3.ONE*rng.randf_range(.35,1))
		batches.pebbles.poses.append(Transform3D(basis,Vector3(x,.006,z)))
func flush_batches() -> void:
	for id in batches:
		var batch: Dictionary=batches[id]
		var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=batch.mesh;multi.instance_count=batch.poses.size()
		for i in batch.poses.size():multi.set_instance_transform(i,batch.poses[i])
		var node:=MultiMeshInstance3D.new();node.name=id.validate_node_name();node.multimesh=multi;node.material_override=batch.material;node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(node)
