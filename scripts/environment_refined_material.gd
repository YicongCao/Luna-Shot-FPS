extends RefCounted
static var cache: Dictionary = {}
static func create(folder: String, atlas: String) -> StandardMaterial3D:
	var key := folder + "/" + atlas
	if cache.has(key): return cache[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "ML15 layered metal / " + atlas
	mat.albedo_texture = load(key + "/BaseColor.png")
	mat.metallic = 1.0
	mat.metallic_texture = load(key + "/ORM.png")
	mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	mat.roughness_texture = mat.metallic_texture
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	mat.ao_enabled = true
	mat.ao_texture = mat.metallic_texture
	mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.normal_enabled = true
	mat.normal_texture = load(key + "/NormalGL.png")
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	cache[key] = mat
	return mat
