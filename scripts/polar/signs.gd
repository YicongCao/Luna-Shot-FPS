extends RefCounted
const Kit = preload("res://scripts/polar/kit.gd")
const PATHS := {
	"ship": '<path d="M24 92h80l-10-21-15-4-9-31H58l-10 31-15 4zm14 0-9 13m61-13 9 13M54 63h20"/>',
	"hab": '<path d="M24 89V53l40-28 40 28v36z M49 89V58h30v31"/>',
	"lift": '<path d="M39 52V21m-13 13 13-13 13 13m37 43v31m-13-13 13 13 13-13M22 56h84v17H22z"/>',
	"step": '<path d="M20 91h27V72h26V53h26V34h12"/>',
	"record": '<path d="M38 21h42l13 13v73H38z M51 44h29M51 60h29m-29 16h29"/>',
	"ice": '<path d="M64 22v84M27 43l74 42M27 85l74-42m-51-8 14 11 14-11m-28 58 14-11 14 11M33 37l1 18-16 7m76 11 2 18 16 6"/>',
	"suit": '<path d="M22 88h84v19H22z M36 88V57a28 28 0 0 1 56 0v31z M37 64h54"/>',
	"arrow": '<path d="M28 69 64 33l36 36M64 37v61"/>',
}
static var icons: Dictionary = {}

static func icon(which: String) -> Texture2D:
	if not icons.has(which):
		var image := Image.new()
		image.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><g fill="none" stroke="white" stroke-width="7" stroke-linejoin="round" stroke-linecap="round">'+PATHS[which]+'</g></svg>')
		image.generate_mipmaps()
		icons[which] = ImageTexture.create_from_image(image)
	return icons[which]

static func plate(root: Node3D, at: Vector3, which: String, size: float, yaw: float = 0.0, tint: Color = Color(.74,.85,.92)) -> void:
	var basis := Basis(Vector3.UP,yaw)
	var backing := Kit.surface(Color(.115,.145,.17),.46,.49)
	Kit.box(root,at,Vector3(size,size,.032),backing,.012,false,yaw)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*size*.93
	var material := StandardMaterial3D.new()
	material.albedo_texture = icon(which)
	material.albedo_color = tint
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = .38
	material.roughness = .83
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = .035
	Kit.part(root,quad,basis,at+basis.z*.019,material)
