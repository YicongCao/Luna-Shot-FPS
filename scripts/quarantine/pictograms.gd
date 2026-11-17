extends RefCounted
# Hand-authored functional symbols, rasterized locally from vectors; no generated art/text.
static var textures: Dictionary = {}
const PATHS: Dictionary = {
	"power": '<path d="M64 16v43 M40 30a39 39 0 1 0 48 0"/>',
	"bolt": '<path d="M73 14L33 70h29l-7 44 41-60H68z"/>',
	"lock": '<rect x="34" y="55" width="60" height="49" rx="5"/><path d="M44 55V40a20 20 0 0 1 40 0v15 M64 73v13"/>',
	"exit": '<path d="M60 20H25v88h35 M48 64h58 M84 42l22 22-22 22"/>',
	"check": '<path d="M25 65l25 25 53-55"/>',
	"bug": '<ellipse cx="64" cy="65" rx="22" ry="30"/><path d="M53 36l-8-15 M75 36l8-15 M42 50H29l-9-10 M42 67H18 M42 83H29l-9 13 M86 50h13l9-10 M86 67h24 M86 83h13l9 13"/>',
	"hazard": '<path d="M64 14l51 92H13z M64 47v27 M64 88v1"/>',
}
static func texture_for(kind: String) -> Texture2D:
	if textures.has(kind): return textures[kind]
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 128 128"><g fill="none" stroke="white" stroke-width="7" stroke-linecap="round" stroke-linejoin="round">'+PATHS[kind]+'</g></svg>'
	var image: Image = Image.new()
	image.load_svg_from_string(svg)
	image.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	textures[kind] = texture
	return texture

static func material_for(kind: String, tint: Color, lit: bool = false) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture_for(kind)
	material.albedo_color = tint
	material.roughness = .8
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = .25
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if lit:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
