extends RefCounted
# Quarantine-only visual terrain. Integration/baseline selection belongs to world.gd.
# No collision, lighting, facility geometry or imported resource changes.

const SPAN: float = 600.0
const GRID_STEP: float = 2.5
const CELLS: int = 240
const HOLE_HALF_SIZE: float = 40.0
const SEED: int = 221117
const NOISE_FREQUENCY: float = 0.005
const NOISE_OCTAVES: int = 3
const NOISE_LACUNARITY: float = 2.0
const BASE_COLOR_PATH: String = "res://assets/environment/ground_v1/regolith/BaseColor.png"
const NORMAL_PATH: String = "res://assets/environment/ground_v1/regolith/NormalGL.png"


static func create_sampler() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = NOISE_FREQUENCY
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = NOISE_OCTAVES
	noise.fractal_lacunarity = NOISE_LACUNARITY
	noise.fractal_gain = 0.35
	# Highest octave is .020 cycles/m (~20 grid samples per nominal period),
	# rather than baseline .176 at 5m (~1.14). No domain warp or sharp ridges.
	# This limits the octave spectrum, not a strict Fourier band-limit of noise.
	return noise


static func sample_height(x: float, z: float, noise: FastNoiseLite = null, noise_amplitude: float = 1.0) -> float:
	if noise == null:
		noise = create_sampler()
	# Retain the baseline's flat -2m apron and broad 70–170m terrain rise.
	return -2.0 + smoothstep(70.0, 170.0, Vector2(x, z).length()) * (14.0 + noise.get_noise_2d(x, z) * 45.0 * noise_amplitude)


static func build_mesh(noise: FastNoiseLite = null, grid_step: float = GRID_STEP, noise_amplitude: float = 1.0) -> ArrayMesh:
	if noise == null:
		noise = create_sampler()
	var cells: int = roundi(SPAN / grid_step)
	assert(is_equal_approx(cells * grid_step, SPAN))
	assert(is_equal_approx(roundf(HOLE_HALF_SIZE / grid_step) * grid_step, HOLE_HALF_SIZE))
	var side: int = cells + 1
	var cache_side: int = side + 2
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(cache_side * cache_side)
	# One noise evaluation per lattice point, including a one-cell halo so
	# outer-edge normals use the same central difference as interior normals.
	for z in cache_side:
		for x in cache_side:
			heights[z * cache_side + x] = sample_height((x - 1) * grid_step - SPAN * 0.5, (z - 1) * grid_step - SPAN * 0.5, noise, noise_amplitude)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var grid_indices: PackedInt32Array = PackedInt32Array()
	grid_indices.resize(side * side)
	grid_indices.fill(-1)
	for z in side:
		for x in side:
			var px: float = x * grid_step - SPAN * 0.5
			var pz: float = z * grid_step - SPAN * 0.5
			# No unused vertices inside the 80x80m opening. The 64x66m facility
			# has at least 7m clearance; boundary vertices themselves are retained.
			if absf(px) < HOLE_HALF_SIZE and absf(pz) < HOLE_HALF_SIZE:
				continue
			var h: int = (z + 1) * cache_side + x + 1
			var dx: float = (heights[h + 1] - heights[h - 1]) / (2.0 * grid_step)
			var dz: float = (heights[h + cache_side] - heights[h - cache_side]) / (2.0 * grid_step)
			grid_indices[z * side + x] = vertices.size()
			vertices.append(Vector3(px, heights[h], pz))
			normals.append(Vector3(-dx, 1.0, -dz).normalized())
			uvs.append(Vector2(px, pz) / 8.0)
			# UV +U follows +X along the slope. -1 makes N cross T follow +V/+Z.
			var tangent: Vector3 = Vector3(1.0, dx, 0.0).normalized()
			tangents.append_array(PackedFloat32Array([tangent.x, tangent.y, tangent.z, -1.0]))

	var indices: PackedInt32Array = PackedInt32Array()
	var hole_cells: int = int(2.0 * HOLE_HALF_SIZE / grid_step)
	indices.resize((cells * cells - hole_cells * hole_cells) * 6)
	var cursor: int = 0
	for z in cells:
		for x in cells:
			var center: Vector2 = Vector2((x + 0.5) * grid_step, (z + 0.5) * grid_step) - Vector2.ONE * SPAN * 0.5
			if absf(center.x) < HOLE_HALF_SIZE and absf(center.y) < HOLE_HALF_SIZE:
				continue
			var a: int = grid_indices[z * side + x]
			var b: int = grid_indices[z * side + x + 1]
			var c: int = grid_indices[(z + 1) * side + x]
			var d: int = grid_indices[(z + 1) * side + x + 1]
			# Clockwise front faces viewed from above (Godot convention).
			indices[cursor] = a
			indices[cursor + 1] = b
			indices[cursor + 2] = c
			indices[cursor + 3] = b
			indices[cursor + 4] = d
			indices[cursor + 5] = c
			cursor += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func build(world: Node3D, mesh: ArrayMesh = null) -> MeshInstance3D:
	var mountain: StandardMaterial3D = StandardMaterial3D.new()
	# Same tint/texture scale/roughness/normal strength as the old horizon.
	# Warm art direction continues to come from the unchanged world atmosphere.
	mountain.albedo_color = Color(0.34, 0.38, 0.42)
	mountain.metallic = 0.0
	mountain.roughness = 0.96
	mountain.albedo_texture = load(BASE_COLOR_PATH)
	mountain.normal_enabled = true
	mountain.normal_texture = load(NORMAL_PATH)
	mountain.normal_scale = 0.55
	mountain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "ProceduralLunarHorizon"
	terrain.mesh = build_mesh() if mesh == null else mesh
	terrain.mesh.surface_set_material(0, mountain)
	world.add_child(terrain)
	return terrain
