@tool
extends Node3D
## Additive B2 side cassette. Geometry is shared; only the three rotors move.
const HEIGHTS := [1.7, 3.0, 4.3]
const RPM := [43.0, 49.0, 46.0]
static var fixed_mesh: ArrayMesh
static var rotor_mesh: ArrayMesh
var rotors: Array[Node3D] = []
var training: Node

func _ready() -> void:
	if not fixed_mesh: build_meshes()
	name = "CoolingFans"
	# The cassette faces local +X, on the outer radiator cheek; max X < 2 m.
	position = Vector3(1.68, 0, 0)
	rotation.y = PI / 2.0
	var housing := MeshInstance3D.new()
	housing.name = "FixedHousing"
	housing.mesh = fixed_mesh
	add_child(housing)
	for i in HEIGHTS.size():
		var rotor := MeshInstance3D.new()
		rotor.name = "Rotor%d" % (i + 1)
		rotor.mesh = rotor_mesh
		rotor.position = Vector3(0, HEIGHTS[i], .145)
		rotor.rotation.z = i * .37
		add_child(rotor)
		rotors.append(rotor)
	# Static sealed guard volume: decorative spinning blades never drive physics.
	var body := StaticBody3D.new()
	body.name = "GuardCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 4.0, .30)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = Vector3(0, 3.0, .14)
	body.add_child(collision)
	add_child(body)
	training = get_parent()
	while training and not training.has_method("set_paused"):
		training = training.get_parent()
	set_process(not Engine.is_editor_hint())

func _process(delta: float) -> void:
	if is_instance_valid(training) and training.get("paused") == true: return
	advance(delta)

func advance(delta: float) -> void:
	for i in rotors.size():
		rotors[i].rotation.z = fposmod(rotors[i].rotation.z + delta * RPM[i] * TAU / 60.0, TAU)

static func material(color: Color, metal: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metal
	mat.roughness = roughness
	return mat

static func stamp(st: SurfaceTool, mesh: Mesh, pos: Vector3, angles := Vector3.ZERO) -> void:
	st.append_from(mesh, 0, Transform3D(Basis.from_euler(angles), pos))

static func box(st: SurfaceTool, pos: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	stamp(st, mesh, pos)

static func disc(st: SurfaceTool, pos: Vector3, radius: float, depth: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = depth
	mesh.radial_segments = 32
	stamp(st, mesh, pos, Vector3(PI / 2.0, 0, 0))

static func ring(st: SurfaceTool, pos: Vector3, radius: float, thickness: float) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 48
	mesh.ring_segments = 8
	stamp(st, mesh, pos, Vector3(PI / 2.0, 0, 0))

static func surface(mat: Material) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	return st

static func build_meshes() -> void:
	var dark := surface(material(Color(.055, .075, .085), .7, .40))
	var steel := surface(material(Color(.42, .49, .53), .85, .29))
	var orange := surface(material(Color(.85, .24, .045), .05, .42))
	for x in [-.66, .66]:
		box(dark, Vector3(x, 3, .08), Vector3(.085, 3.95, .16))
	for y: float in HEIGHTS:
		# Dark recessed back, substantial shroud, fine stationary safety grille.
		disc(dark, Vector3(0, y, .035), .61, .045)
		ring(dark, Vector3(0, y, .15), .59, .055)
		ring(steel, Vector3(0, y, .225), .59, .015)
		for radius in [.28, .43]: ring(steel, Vector3(0, y, .235), radius, .008)
		for i in 4:
			var bar := BoxMesh.new()
			bar.size = Vector3(1.15, .012, .018)
			stamp(steel, bar, Vector3(0, y, .245), Vector3(0, 0, i * PI / 4))
		disc(steel, Vector3(0, y, .25), .115, .03)
		disc(orange, Vector3(0, y, .268), .07, .012)
		for x in [-.64, .64]:
			box(dark, Vector3(x, y, .12), Vector3(.14, .24, .14))
			disc(steel, Vector3(x, y, .202), .035, .025)
		box(orange, Vector3(-.66, y + .38, .172), Vector3(.087, .20, .015))
	fixed_mesh = dark.commit()
	steel.commit(fixed_mesh)
	orange.commit(fixed_mesh)
	# Swept, pitched vanes with thickness: actual geometry, no generated texture.
	var blades := surface(material(Color(.52, .60, .64), .8, .32))
	var outline := [Vector3(.10, -.065, -.018), Vector3(.36, -.18, -.035),
		Vector3(.53, -.10, -.012), Vector3(.50, .075, .025), Vector3(.16, .075, .025)]
	for i in 7:
		var basis := Basis(Vector3.FORWARD, i * TAU / 7)
		var vertices: Array[Vector3] = []
		for depth in [-.009, .009]:
			for p: Vector3 in outline: vertices.append(basis * (p + Vector3(0, 0, depth)))
		# Front/back triangulation and closed edge faces (front faces clockwise in Godot).
		var indices := [5, 7, 6, 5, 8, 7, 5, 9, 8, 0, 1, 2, 0, 2, 3, 0, 3, 4]
		for j in 5:
			var k := (j + 1) % 5
			indices.append_array([j, k + 5, k, j, j + 5, k + 5])
		for index: int in indices: blades.add_vertex(vertices[index])
	blades.generate_normals()
	rotor_mesh = blades.commit()
