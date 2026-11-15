extends RefCounted
const ROOT := "res://assets/weapons/lc01/ls01_v1/"
static func make(atlas: String) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new()
	m.resource_name="LS01_"+atlas
	var dir=ROOT+atlas+"/"
	if not ResourceLoader.exists(dir+"BaseColor.png"):
		m.albedo_color=Color(.48,.48,.48);m.roughness=.4
		return m
	m.albedo_texture=load(dir+"BaseColor.png")
	m.metallic=1.0;m.roughness=1.0
	m.metallic_texture=load(dir+"ORM.png");m.roughness_texture=m.metallic_texture
	m.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE;m.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.normal_enabled=true;m.normal_texture=load(dir+"NormalGL.png")
	m.ao_enabled=true;m.ao_texture=m.metallic_texture;m.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if ResourceLoader.exists(dir+"Emission.png"):
		m.emission_enabled=true;m.emission=Color.WHITE;m.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY;m.emission_texture=load(dir+"Emission.png");m.emission_energy_multiplier=4.0
	return m
static func mode(mat: StandardMaterial3D, atlas: String, value: int) -> void:
	var source=make(atlas)
	for prop in ["albedo_texture","albedo_color","metallic_texture","metallic","roughness_texture","roughness","normal_texture","normal_enabled","ao_enabled","ao_texture","emission_enabled","shading_mode"]:mat.set(prop,source.get(prop))
	if value==1:mat.normal_enabled=false
	if value==2 or value==3:
		mat.metallic_texture=null;mat.roughness_texture=null;mat.metallic=0;mat.roughness=.55
	if value==3:
		mat.normal_enabled=false;mat.ao_enabled=false;mat.emission_enabled=false;mat.albedo_texture=null;mat.albedo_color=Color(.5,.5,.5)
	if value>=4 and value<=7:
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.normal_enabled=false;mat.ao_enabled=false;mat.emission_enabled=false
		var map=["BaseColor","Metallic","Roughness","AO"][value-4]
		if ResourceLoader.exists(ROOT+atlas+"/"+map+".png"):mat.albedo_texture=load(ROOT+atlas+"/"+map+".png")
	if value==8:
		mat.albedo_texture=null;mat.albedo_color=Color(.5,.5,.5);mat.metallic_texture=null;mat.roughness_texture=null;mat.metallic=0;mat.roughness=.4;mat.ao_enabled=false;mat.emission_enabled=false
