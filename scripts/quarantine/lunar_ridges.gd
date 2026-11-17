extends RefCounted
# Preserve the old terrain's first three octaves, not ML28's lower-frequency dunes.
const Grid = preload("res://scripts/quarantine/lunar_horizon.gd")
const Refinement = preload("res://scripts/quarantine/terrain_refinement.gd")
const NORMAL_STEP: float = Refinement.NORMAL_STEP
const SPAN: float = 600.0
const GRID_STEP: float = 1.25
const CELLS: int = 480
const HOLE_HALF_SIZE: float = 40.0
const NOISE_AMPLITUDE: float = 28.0 / 31.0
const BASE_COLOR_PATH: String = Grid.BASE_COLOR_PATH
const NORMAL_PATH: String = Grid.NORMAL_PATH
static var runtime_mesh: ArrayMesh

static func create_sampler() -> FastNoiseLite:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 221117
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = .011
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = .5
	# FNL normalizes FBM by sum(gain^octave). Match the old five-octave
	# coefficients: (1+.5+.25)/(1+.5+.25+.125+.0625) = 28/31.
	# Only remove the two finest octaves; do not enlarge the remaining hills.
	return noise

static func sample_height(x: float, z: float, noise: FastNoiseLite = null) -> float:
	if noise == null:
		noise = create_sampler()
	return Grid.sample_height(x, z, noise, NOISE_AMPLITUDE)

static func build_mesh() -> ArrayMesh:
	var noise: FastNoiseLite = create_sampler()
	var height: Callable = func(x: float, z: float) -> float: return sample_height(x, z, noise)
	return Refinement.refine(Grid.build_mesh(noise, GRID_STEP, NOISE_AMPLITUDE), height)

static func build(world: Node3D) -> MeshInstance3D:
	if runtime_mesh == null:
		runtime_mesh = build_mesh()
	return Grid.build(world, runtime_mesh)
