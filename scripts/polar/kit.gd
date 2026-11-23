extends RefCounted
## Shared parametric pieces for static architecture and animated machinery.

const Rounded = preload("res://scripts/quarantine/rounded_geometry.gd")
const Surface = preload("res://assets/polar/surface.gdshader")
static var box_meshes: Dictionary = {}
static var tube_meshes: Dictionary = {}

static func surface(color: Color, metallic: float, roughness: float, finish: int = 0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Surface
	material.set_shader_parameter("tint", color)
	material.set_shader_parameter("base_metal", metallic)
	material.set_shader_parameter("base_rough", roughness)
	material.set_shader_parameter("finish", finish)
	return material

static func glow(color: Color, power: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .35
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = power
	return material

static func collider(root: Node3D, at: Vector3, size: Vector3, axes: Basis = Basis.IDENTITY) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_mask = 0
	body.transform = Transform3D(axes, at)
	var shape := CollisionShape3D.new()
	var bounds := BoxShape3D.new()
	bounds.size = size
	shape.shape = bounds
	body.add_child(shape)
	root.add_child(body)
	return body

static func _box_mesh(size: Vector3, bevel: float) -> Mesh:
	# Round lengths only for the cache key; maximum displacement is < 1 mm.
	var key := Vector4(roundf(size.x*1000), roundf(size.y*1000), roundf(size.z*1000), roundf(bevel*1000))
	if not box_meshes.has(key):
		if bevel > 0.0:
			box_meshes[key] = Rounded.box_mesh(size, bevel)
		else:
			var primitive := BoxMesh.new()
			primitive.size = size
			box_meshes[key] = primitive
	return box_meshes[key]

static func part(root: Node3D, mesh: Mesh, axes: Basis, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	item.transform = Transform3D(axes, at)
	root.add_child(item)
	return item

static func box(root: Node3D, at: Vector3, size: Vector3, mat: Material, bevel: float = .025, solid: bool = false, yaw: float = 0.0) -> MeshInstance3D:
	var basis := Basis(Vector3.UP, yaw)
	if solid:
		collider(root, at, size, basis)
	return part(root, _box_mesh(size, bevel), basis, at, mat)

static func along(a: Vector3, b: Vector3) -> Basis:
	var y := (b-a).normalized()
	var reference := Vector3.BACK if absf(y.y) > .98 else Vector3.UP
	var x := y.cross(reference).normalized()
	return Basis(x, y, x.cross(y))

static func beam(root: Node3D, a: Vector3, b: Vector3, width: float, mat: Material, solid: bool = false, depth: float = 0.0) -> MeshInstance3D:
	var axes := along(a, b)
	var size := Vector3(width, a.distance_to(b), depth if depth > 0.0 else width)
	if solid:
		collider(root, (a+b)*.5, size, axes)
	return part(root, _box_mesh(size, minf(.019, width*.12)), axes, (a+b)*.5, mat)

static func pipe(root: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material, segments: int = 16) -> MeshInstance3D:
	var key := Vector2(roundf(radius*10000), segments)
	if not tube_meshes.has(key):
		var tube := CylinderMesh.new()
		tube.height = 1.0
		tube.top_radius = radius
		tube.bottom_radius = radius
		tube.radial_segments = segments
		tube.rings = 0
		tube_meshes[key] = tube
	var axes := along(a, b)
	axes.y *= a.distance_to(b)
	return part(root, tube_meshes[key], axes, (a+b)*.5, mat)

static func lamp(root: Node3D, at: Vector3, color: Color, energy: float, radius: float, shadows: bool = false) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.5
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 0.0
	root.add_child(light)
	return light

static func spot(root: Node3D, at: Vector3, target: Vector3, color: Color, energy: float, radius: float, angle: float, shadows: bool = true) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.spot_range = radius
	light.spot_angle = angle
	light.spot_attenuation = 1.3
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 0.0
	root.add_child(light)
	light.look_at(root.to_global(target), Vector3.FORWARD if absf(at.direction_to(target).y) > .98 else Vector3.UP)
	return light

static func pad(root: Node3D, top: Vector3, span: Vector2, material: Material, thickness: float = .24) -> void:
	box(root, top-Vector3.UP*thickness*.5, Vector3(span.x,thickness,span.y), material, .018, true)

static func deck_ramp(root: Node3D, a: Vector3, b: Vector3, width: float, material: Material, thickness: float = .24) -> void:
	var forward := a.direction_to(b)
	var side := Vector3.UP.cross(forward).normalized()
	var up := forward.cross(side).normalized()
	var basis := Basis(side, up, forward)
	var center := (a+b)*.5-up*thickness*.5
	var size := Vector3(width,thickness,a.distance_to(b)+.04)
	collider(root, center, size, basis)
	part(root, _box_mesh(size, .012), basis, center, material)

static func glass(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.roughness = .17
	material.metallic = .18
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.disable_receive_shadows = true
	return material
