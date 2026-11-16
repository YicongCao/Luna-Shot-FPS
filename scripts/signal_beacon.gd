@tool
extends Node3D
var lens: MeshInstance3D
var sector: MeshInstance3D
var rotor: Node3D
var material: StandardMaterial3D
func _ready() -> void:
	var housing:=StandardMaterial3D.new();housing.albedo_color=Color(.12,.15,.17);housing.metallic=.9;housing.roughness=.3
	for y in [-.075,.075]:
		var ring:=MeshInstance3D.new();var shape:=CylinderMesh.new();shape.top_radius=.17;shape.bottom_radius=.17;shape.height=.025;shape.radial_segments=32
		ring.mesh=shape;ring.position.y=y;ring.material_override=housing;add_child(ring)
	lens=MeshInstance3D.new();var shell:=CylinderMesh.new();shell.top_radius=.147;shell.bottom_radius=.147;shell.height=.14;shell.radial_segments=48;lens.mesh=shell
	var glass:=StandardMaterial3D.new();glass.albedo_color=Color(.12,.035,.004);glass.roughness=.2;glass.emission_enabled=true;glass.emission=Color(1,.24,.008);glass.emission_energy_multiplier=.28
	lens.material_override=glass;lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(lens)
	rotor=Node3D.new();add_child(rotor);sector=MeshInstance3D.new()
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a: float=-.55+float(i)/12*1.1;var b: float=-.55+float(i+1)/12*1.1
		var points: Array[Vector3]=[Vector3(sin(a)*.151,-.055,cos(a)*.151),Vector3(sin(a)*.151,.055,cos(a)*.151),Vector3(sin(b)*.151,.055,cos(b)*.151),Vector3(sin(b)*.151,-.055,cos(b)*.151)]
		for index in [0,1,2,0,2,3]:
			st.set_normal(Vector3(points[index].x,0,points[index].z).normalized());st.add_vertex(points[index])
	sector.mesh=st.commit();sector.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=StandardMaterial3D.new();material.albedo_color=Color(1,.3,.015);material.emission_enabled=true;material.emission=Color(1,.12,.005);material.emission_energy_multiplier=8
	sector.material_override=material;rotor.add_child(sector)
func set_phase(t: float, intensity: float) -> void:
	rotor.rotation.y=fposmod(t,1.0)*TAU
	if not is_equal_approx(material.emission_energy_multiplier,intensity*5.5):material.emission_energy_multiplier=intensity*5.5
	if not is_equal_approx(lens.material_override.emission_energy_multiplier,intensity*.18):lens.material_override.emission_energy_multiplier=intensity*.18
