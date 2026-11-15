extends Node3D
# Game-art sockets in metres; the imported GLB already has applied transforms.
const SIGHT_HEIGHT := 0.178
var material: StandardMaterial3D
var meshes: Array[MeshInstance3D] = []
var energy_lights: Array[OmniLight3D] = []
var energy_enabled := true
var spill_enabled := true
var surface_mode := 0
var field_kit: Node3D
func _ready() -> void:
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
	for light in energy_lights: light.visible = value and spill_enabled and surface_mode != 3

func set_spill_enabled(value: bool) -> void:
	spill_enabled=value
	set_energy_enabled(energy_enabled)
