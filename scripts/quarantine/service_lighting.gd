extends RefCounted
# One physical inspection luminaire bolted below the existing z=0 roof truss.
# Shared by normal Quarantine and its benchmark; no camera-following/target light.
static func build(world: Node3D) -> void:
	if OS.get_environment("QUARANTINE_SERVICE_LIGHT") == "off": return
	var rig: Node3D=Node3D.new()
	rig.name="InspectionLuminaire"
	rig.position=Vector3(-3,10.5,0)
	world.add_child(rig)
	rig.look_at(Vector3(1,.45,16),Vector3.UP)
	world.beam(Vector3(-3,10.9,0),rig.position,.065,world.steel)
	world.box("inspectionMount",Vector3(-3,10.83,0),Vector3(.32,.12,.35),world.steel)
	var casing: MeshInstance3D=MeshInstance3D.new()
	casing.name="Housing"
	casing.mesh=preload("res://scripts/quarantine/rounded_geometry.gd").box_mesh(Vector3(.94,.46,.26),.035)
	casing.material_override=world.dark
	rig.add_child(casing)
	var diffuser: MeshInstance3D=MeshInstance3D.new()
	diffuser.name="Diffuser"
	var pane: QuadMesh=QuadMesh.new()
	pane.size=Vector2(.76,.29)
	diffuser.mesh=pane
	diffuser.position.z=-.136
	diffuser.rotation.y=PI
	diffuser.material_override=world.emissive(Color(.78,.83,.88),1.4)
	diffuser.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rig.add_child(diffuser)
	var light: SpotLight3D=SpotLight3D.new()
	light.name="InspectionSpot"
	light.position.z=-.16
	light.light_color=Color(.78,.83,.88)
	light.light_energy=24.0
	light.light_size=.6
	light.light_volumetric_fog_energy=0
	light.spot_range=26
	light.spot_angle=26
	light.spot_attenuation=1.2
	light.shadow_enabled=true
	light.shadow_blur=2.0
	light.shadow_normal_bias=.06
	rig.add_child(light)
