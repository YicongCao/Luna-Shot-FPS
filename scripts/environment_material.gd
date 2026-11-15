extends RefCounted
static var cache: Dictionary = {}
static func create(asset: String, mode: int = 0) -> StandardMaterial3D:
	var key := asset+"_"+str(mode)
	if cache.has(key): return cache[key]
	var dir := "res://assets/environment/"+asset+"/"
	var mat:=StandardMaterial3D.new()
	mat.resource_name=asset+" / baked PBR"
	mat.albedo_texture=load(dir+"BaseColor.png")
	mat.metallic=1
	mat.metallic_texture=load(dir+"ORM.png")
	mat.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.roughness_texture=mat.metallic_texture
	mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.ao_enabled=true
	mat.ao_texture=mat.metallic_texture
	mat.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled=mode!=1
	mat.normal_texture=load(dir+"NormalGL.png")
	if asset=="A":
		mat.emission_enabled=true
		mat.emission=Color.WHITE
		mat.emission_texture=load(dir+"Emission.png")
		mat.emission_operator=BaseMaterial3D.EMISSION_OP_MULTIPLY
		mat.emission_energy_multiplier=2.0
	mat.cull_mode=BaseMaterial3D.CULL_BACK
	mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if mode==2:
		mat.metallic_texture=null;mat.roughness_texture=null
		mat.metallic=0;mat.roughness=.6
	cache[key]=mat
	return mat
