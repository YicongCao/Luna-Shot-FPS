extends Node3D
# Game-art sockets in metres; the imported GLB already has applied transforms.
const SIGHT_HEIGHT := 0.178
var material: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var energy_lights: Array[Light3D] = []
var energy_enabled := true
var spill_enabled := true
var surface_mode := 0
var field_kit: Node3D
var ls01 := false
var revision := "ml07"
var asset_root := "res://assets/weapons/lc01/ls01_v1/"
var atlas_materials: Dictionary = {}
func _ready() -> void:
	ls01 = OS.get_environment("LS01_BASELINE") != "1" and (OS.get_environment("LS01_CANDIDATE") == "1" or FileAccess.file_exists("res://assets/weapons/lc01/ls01_v1/APPROVED"))
	var explicit_revision := false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--weapon-revision="):
			explicit_revision=true
			revision=argument.trim_prefix("--weapon-revision=")
			assert(revision in ["ml06","ml07","ml09"],"Unknown weapon revision")
			ls01=revision!="ml06"
	if not explicit_revision:
		if OS.get_environment("LS01_BASELINE")=="1":revision="ml06"
		elif OS.get_environment("LS01_CANDIDATE")!="1" and FileAccess.file_exists("res://assets/weapons/lc01/ls01_v2/APPROVED"):
			revision="ml09";ls01=true
	if revision=="ml09":asset_root="res://assets/weapons/lc01/ls01_v2/"
	if ls01:
		setup_ls01()
		return
	material = StandardMaterial3D.new()
	material.resource_name = "LC01 ceramic / metal / rubber / coating"
	material.albedo_texture = load("res://assets/weapons/lc01/BaseColor.png")
	material.metallic = 1.0
	material.metallic_texture = load("res://assets/weapons/lc01/ORM.png")
	material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	material.roughness = 1.0
	material.roughness_texture = material.metallic_texture
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.ao_enabled = true
	material.ao_texture = material.metallic_texture
	material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.normal_enabled = true
	material.normal_texture = load("res://assets/weapons/lc01/NormalGL.png")
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	material.emission_texture = load("res://assets/weapons/lc01/Emission.png")
	material.emission_energy_multiplier = 4.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var cell := $P07_Cell
	for mesh: MeshInstance3D in $Geometry.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mesh)
		mesh.material_override = material
		if mesh.name.begins_with("T04_") or mesh.name.begins_with("T11_"):
			mesh.reparent(cell, true)
	field_kit = Node3D.new()
	field_kit.name = "IndustrialFieldKit"
	field_kit.set_script(load("res://scripts/weapon_field_kit.gd"))
	add_child(field_kit)
	var dot_material := ShaderMaterial.new()
	dot_material.shader = load("res://assets/weapons/lc01/red_dot.gdshader")
	$RedDot.material_override = dot_material
	# Two short-range proxy lights reproduce local spill from the three emissive rings.
	for side in [-1, 1]:
		var light := OmniLight3D.new()
		light.name = "CoilSpillLeft" if side < 0 else "CoilSpillRight"
		light.position = Vector3(side * .047, .058, -.402)
		light.light_color = Color(.03, .8, 1.0)
		light.light_energy = .045
		light.omni_range = .13
		light.omni_attenuation = 1.7
		light.shadow_enabled = false
		add_child(light)
		energy_lights.append(light)
func set_surface_mode(mode: int) -> void:
	# 0 final / 1 normal off / 2 constant response / 3 clay.
	surface_mode = mode
	if ls01:
		for atlas in atlas_materials:load("res://scripts/ls01_materials.gd").mode(atlas_materials[atlas],atlas,mode,asset_root)
		field_kit.set_surface_mode(mode)
		set_energy_enabled(energy_enabled)
		return
	if is_instance_valid(field_kit): field_kit.set_surface_mode(mode)
	material.normal_enabled = mode != 1 and mode != 3
	material.albedo_texture = null if mode == 3 else load("res://assets/weapons/lc01/BaseColor.png")
	material.albedo_color = Color(.5,.5,.5) if mode == 3 else Color.WHITE
	material.metallic_texture = null if mode == 2 or mode == 3 else load("res://assets/weapons/lc01/ORM.png")
	material.roughness_texture = material.metallic_texture
	material.metallic = 0 if mode == 2 or mode == 3 else 1
	material.roughness = .55 if mode == 2 or mode == 3 else 1
	set_energy_enabled(energy_enabled)
	material.ao_enabled = mode != 3

func set_energy_enabled(value: bool) -> void:
	energy_enabled = value
	material.emission_enabled = value and surface_mode != 3
	if ls01:
		for atlas in atlas_materials:atlas_materials[atlas].emission_enabled=value and surface_mode==0 and atlas=="retained"
	for light in energy_lights: light.visible = value and spill_enabled and surface_mode != 3

func set_spill_enabled(value: bool) -> void:
	spill_enabled=value
	set_energy_enabled(energy_enabled)

func setup_ls01() -> void:
	$Geometry.free()
	var geo=load(asset_root+"weapon.glb").instantiate();geo.name="Geometry";add_child(geo)
	var bindings=JSON.parse_string(FileAccess.get_file_as_string(asset_root+"bindings.json"))
	for atlas in ["body","kit","retained"]:atlas_materials[atlas]=load("res://scripts/ls01_materials.gd").make(atlas,asset_root)
	material=atlas_materials["retained"]
	for mesh in geo.find_children("*","MeshInstance3D",true,false):
		var key=String(mesh.name)
		assert(bindings.has(key),"Missing LS01 binding: "+key)
		var binding=bindings[key];mesh.material_override=atlas_materials[binding.atlas];meshes.append(mesh)
		if binding.moving_cell:mesh.reparent($P07_Cell,true)
	field_kit=Node3D.new();field_kit.name="IndustrialFieldKit";field_kit.set_script(load("res://scripts/ls01_field_kit.gd"));field_kit.asset_root=asset_root;add_child(field_kit)
	var dot_material:=ShaderMaterial.new();dot_material.shader=load("res://assets/weapons/lc01/red_dot.gdshader");$RedDot.material_override=dot_material
	for side in [-1,1]:
		var light:=OmniLight3D.new();light.name="CoilSpillLeft" if side<0 else "CoilSpillRight";light.position=Vector3(side*.047,.058,-.402);light.light_color=Color(.03,.8,1);light.light_energy=.045;light.omni_range=.13;light.omni_attenuation=1.7;add_child(light);energy_lights.append(light)

	if revision=="ml09":
		for side in [-1,1]:
			var spot:=SpotLight3D.new()
			spot.name="CoilSideWashLeft" if side<0 else "CoilSideWashRight"
			spot.position=Vector3(side*.074,.060,-.402)
			spot.light_color=Color(.025,.72,1.0)
			spot.light_energy=.20
			spot.spot_range=.43
			spot.spot_angle=53.0
			spot.spot_attenuation=1.15
			spot.spot_angle_attenuation=1.0
			spot.shadow_enabled=true
			spot.shadow_bias=.10
			spot.shadow_normal_bias=1.0
			add_child(spot)
			spot.look_at(to_global(Vector3(side*.048,.025,-.17)),Vector3.UP)
			energy_lights.append(spot)
