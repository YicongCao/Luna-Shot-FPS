extends Node3D
# ML22: independent stage dressing. Original training scene/resources remain untouched.
var facility: Node3D
var environment: Environment
var sun: DirectionalLight3D
var emitters: Array[Dictionary] = []
var reactor_rings: Array[Node3D] = []
var terminal_material: StandardMaterial3D
var extraction_material: StandardMaterial3D
var stage_seen: int = -1
var time: float = 0.0
var steel: StandardMaterial3D
var dark: StandardMaterial3D
var concrete: StandardMaterial3D
var amber: StandardMaterial3D
var ice: StandardMaterial3D
var red: StandardMaterial3D
var batches: Dictionary = {}
var terminal_label: Label3D
var activation_age: float = -1.0
var energy_column: MeshInstance3D
var energy_material: ShaderMaterial
var shockwave: MeshInstance3D
var shock_material: StandardMaterial3D
var charge_particles: CPUParticles3D
var weapon_bloom: CanvasLayer
var sun_visibility: float = 1.0
var sun_target: float = 1.0
var shadow_clock: float = 0.0

func _ready() -> void:
	steel = material(Color(.21,.26,.29), .8, .32)
	dark = material(Color(.035,.055,.065), .65, .44)
	concrete = material(Color(.19,.21,.22), .15, .87)
	amber = emissive(Color(1,.40,.085), 5.0)
	ice = emissive(Color(.12,.64,.91), 3.5)
	red = emissive(Color(1,.07,.025), 3.0)
	load_facility()
	build_markers()
	build_enclosure()
	build_terminal()
	build_extraction()
	build_horizon()
	build_reactor()
	flush_batches()
	setup_environment()

func material(color: Color, metal: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func emissive(color: Color, power: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = material(color, .35, .28)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = power
	return m

func load_facility() -> void:
	facility = load("res://scenes/training.tscn").instantiate()
	facility.set_script(null)
	facility.name = "FacilityShell"
	# Remove only the independent instance's training interfaces before entering tree.
	for child in facility.get_children():
		var n: String = str(child.name)
		if n in ["Player", "Overview", "Markers", "Environment", "Sun", "FiringLine"] or n.begins_with("Target") or child is Label3D:
			facility.remove_child(child)
			child.free()
	# Mission-only composition override: free the arrival sightline without deleting assets.
	# (30,6) is an empty outer equipment slot, outside the x=26 perimeter route.
	facility.get_node("Facility/B11").position = Vector3(30,0,6)
	add_child(facility)
	for n in ["BoundaryWest", "BoundaryEast", "BoundaryNorth", "BoundarySouth"]:
		var boundary: Node3D = facility.get_node(n)
		for mesh in boundary.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = dark
	# Existing geometry and normal maps; new per-instance floor shading, no asset overwrite.
	var ground_surface: Node = facility.get_node_or_null("GroundSurface")
	if ground_surface:
		ground_surface.set_process(false)
	var floor_material: ShaderMaterial = ShaderMaterial.new()
	floor_material.shader = load("res://assets/quarantine/floor.gdshader")
	for pair in [["color_map","BaseColor"],["normal_map","NormalGL"],["orm_map","ORM"]]:
		floor_material.set_shader_parameter(pair[0],load("res://assets/environment/ground_v1/paving/"+pair[1]+".png"))
	facility.get_node("Ground/Mesh").material_override = floor_material

func build_markers() -> void:
	var markers: Node3D = Node3D.new()
	markers.name = "Markers"
	add_child(markers)
	for entry in [["Spawn",Vector3(0,.05,28)],["Terminal",Vector3(0,0,-22)],["Extraction",Vector3(0,0,27)]]:
		var point: Marker3D = Marker3D.new()
		point.name = entry[0]
		point.position = entry[1]
		markers.add_child(point)

func box(id: String, pos: Vector3, size: Vector3, mat: Material, yaw: float = 0.0) -> void:
	var key: String = id + str(size) + str(mat.get_instance_id())
	if not batches.has(key):
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = size
		batches[key] = {"mesh":mesh,"material":mat,"poses":[]}
	batches[key].poses.append(Transform3D(Basis(Vector3.UP,yaw),pos))

func beam(a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var key: String = "beam"+str(radius)+str(mat.get_instance_id())
	if not batches.has(key):
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 1.0
		mesh.radial_segments = 10
		batches[key] = {"mesh":mesh,"material":mat,"poses":[]}
	var direction: Vector3 = (b-a).normalized()
	var reference: Vector3 = Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > .98 else Vector3.UP
	var x: Vector3 = direction.cross(reference).normalized()
	var basis: Basis = Basis(x,direction*a.distance_to(b),x.cross(direction).normalized())
	batches[key].poses.append(Transform3D(basis,(a+b)*.5))

func text(value: String, pos: Vector3, font_size: int, tint: Color, pixel: float = .009) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = value
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = tint
	label.outline_size = 0
	label.position = pos
	label.no_depth_test = false
	add_child(label)
	return label

func fixture(pos: Vector3, color: Color, energy: float, range_m: float, shadow: bool = false) -> void:
	var lamp: OmniLight3D = OmniLight3D.new()
	lamp.position = pos
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = range_m
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = shadow
	add_child(lamp)
	emitters.append({"position":pos,"color":color,"light":lamp})

func build_enclosure() -> void:
	# Structural portals stay outside the existing 4m circulation corridors.
	for z in [-29.0,-18.0,0.0,18.0,30.0]:
		for x in [-31.0,31.0]:
			box("pillar",Vector3(x,6,z),Vector3(.65,12,.8),steel)
			box("foot",Vector3(x,.65,z),Vector3(1.15,1.3,1.2),concrete)
			box("pillarInset",Vector3(x*.985,5.8,z),Vector3(.12,9,.32),dark)
			beam(Vector3(x,9,z),Vector3(x-signf(x)*3,11.8,z),.13,steel)
		box("roofSpine",Vector3(0,12,z),Vector3(63,.35,.42),steel)
		box("roofSpine",Vector3(0,10.9,z),Vector3(63,.2,.26),dark)
		for x in range(-30,30,3):
			beam(Vector3(x,10.9,z),Vector3(x+1.5,12,z),.065,steel)
			beam(Vector3(x+1.5,12,z),Vector3(x+3,10.9,z),.065,steel)
	# Side service canopies leave central skylight open and retain lunar horizon.
	for x in [-31.0,-26.0,-20.0,20.0,26.0,31.0]:
		box("canopyLongeron",Vector3(x,12.16,0),Vector3(.22,.30,64),steel)
	for x in [-26.0,26.0]:
		for z in range(-30,31,2):
			box("canopyRib",Vector3(x,12.22,z),Vector3(12,.12,.10),steel)
		for z in [-23.0,-9.0,9.0,23.0]:
			box("roof",Vector3(x,12.35,z),Vector3(12,.18,12),dark)
			var roof_body: StaticBody3D = StaticBody3D.new()
			roof_body.position = Vector3(x,12.35,z)
			var roof_collision: CollisionShape3D = CollisionShape3D.new()
			var roof_shape: BoxShape3D = BoxShape3D.new()
			roof_shape.size = Vector3(12,.18,12)
			roof_collision.shape = roof_shape
			roof_body.add_child(roof_collision)
			add_child(roof_body)
			box("ceilingLight",Vector3(x,12.18,z),Vector3(8,.04,.10),ice)
		for z in [-24.0,0.0,24.0]:
			fixture(Vector3(x,8,z),Color(.20,.48,.69),2.6,15)
	# Ribbed perimeter, no new ground collision: preserve the original enclosing wall.
	for z in range(-30,32,4):
		for x in [-31.8,31.8]:
			box("wallRib",Vector3(x,1.5,z),Vector3(.3,3,.16),steel)
			box("wallCap",Vector3(x,3,z+1.8),Vector3(.48,.18,3.8),steel)
	for x in range(-30,32,4):
		for z in [-32.8,32.8]:
			box("endRib",Vector3(x,1.5,z),Vector3(.16,3,.3),steel)
	# North machine hall facade frames the actual interactive terminal.
	for x in [-12.0,12.0]:
		box("bulkhead",Vector3(x,5.1,-32),Vector3(18,10.2,1),dark)
		for p in range(-8,9,2):
			box("bulkheadSeam",Vector3(x+p,5.1,-31.46),Vector3(.04,9.8,.04),steel)
		box("header",Vector3(x,8,-31.4),Vector3(16,.16,.2),amber)
	box("centerHeader",Vector3(0,9,-32),Vector3(7,2.6,1.2),steel)
	text("SELENE",Vector3(0,9.1,-31.32),84,Color(.78,.86,.9),.018)
	text("03   /   POWER CONVERSION",Vector3(-12,6.8,-31.44),38,Color(.59,.70,.77),.012)
	text("CAUTION   ·   CONTAINMENT",Vector3(12,6.8,-31.44),34,Color(.93,.47,.19),.012)
	# Long narrow service lights establish routes, not random neon everywhere.
	for x in [-3.75,3.75]:
		for z in range(-28,29,8):
			box("guide",Vector3(x,.027,z),Vector3(.045,.018,1.3),ice)
	for x in [-10.0,10.0]:
		for z in [-18.0,18.0]:
			box("warning",Vector3(x,.03,z),Vector3(3.5,.02,.07),amber)
	# Industrial cable trunks ride the outer wall, never cross the player's path.
	for x in [-31.2,31.2]:
		for h in [3.5,3.85,4.2]:
			beam(Vector3(x,h,-31),Vector3(x,h,31),.11,steel)

func build_terminal() -> void:
	terminal_material = emissive(Color(.025,.14,.19),.8)
	box("consoleBase",Vector3(0,.25,-22.4),Vector3(1.8,.5,1.2),steel)
	box("consoleBody",Vector3(0,.90,-22.5),Vector3(1.4,1.2,.7),dark)
	box("consoleFrame",Vector3(0,1.53,-22.3),Vector3(1.65,.82,.18),steel)
	box("consoleScreen",Vector3(0,1.53,-22.195),Vector3(1.38,.57,.025),terminal_material)
	for x in [-.73,.73]:
		box("consoleRail",Vector3(x,.96,-22.1),Vector3(.06,.78,.08),amber)
	box("consolePlaque",Vector3(0,2.16,-22.22),Vector3(1.9,.48,.10),dark)
	box("consoleHood",Vector3(0,1.97,-22.23),Vector3(1.83,.09,.45),steel)
	for side in [-1.0,1.0]:
		for y in [.6,.75,.9,1.05]:
			box("consoleVent",Vector3(side*.715,y,-22.5),Vector3(.035,.045,.42),steel)
	for x in [-.48,-.24,0.0,.24,.48]:
		box("consoleKeys",Vector3(x,1.15,-22.115),Vector3(.10,.04,.03),steel)
	terminal_label = text("ISOLATION CONTROL\nPURGE REQUIRED",Vector3(0,2.16,-22.155),26,Color(.76,.84,.87),.0038)
	text("MANUAL OVERRIDE\n[ E ]   HOLD  /  03 SEC",Vector3(0,1.53,-22.17),26,Color(.62,.86,.91),.0032)
	# Actual solid pedestal; interaction stands in front at z=-20.
	var body: StaticBody3D = StaticBody3D.new()
	body.position = Vector3(0,.9,-22.5)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(1.65,1.8,.9)
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	fixture(Vector3(0,2.8,-22),Color(1,.38,.10),2.0,7,true)

func build_extraction() -> void:
	extraction_material = emissive(Color(.15,.54,.7),1.8)
	for x in [-3.0,3.0]:
		box("exitPost",Vector3(x,2.5,31.4),Vector3(.6,5,1),steel)
		box("exitStrip",Vector3(x,2.5,30.86),Vector3(.12,3.8,.05),extraction_material)
	box("exitLintel",Vector3(0,5,31.4),Vector3(6.6,.7,1),steel)
	var label: Label3D = text("AIRLOCK  /  01",Vector3(0,4.95,30.82),43,Color(.72,.84,.9),.009)
	label.rotation.y = PI
	for i in 48:
		var angle: float = TAU*float(i)/48
		box("extractRing",Vector3(cos(angle)*2.6,.031,27+sin(angle)*2.6),Vector3(.24,.018,.055),extraction_material,-angle)
	fixture(Vector3(0,3,28.5),Color(.17,.60,.83),1.8,8)

func build_reactor() -> void:
	# Suspended inductive collars on existing central tower: no new collision footprint.
	for y in [6.8,8.6,10.4]:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 1.10
		torus.outer_radius = 1.25
		torus.rings = 48
		torus.ring_segments = 8
		ring.mesh = torus
		ring.material_override = ice
		ring.position = Vector3(0,y,0)
		add_child(ring)
		reactor_rings.append(ring)
	fixture(Vector3(0,7,0),Color(.12,.52,.88),3.0,13)
	energy_material = ShaderMaterial.new()
	energy_material.shader = load("res://assets/quarantine/energy.gdshader")
	energy_column = MeshInstance3D.new()
	var column: CylinderMesh = CylinderMesh.new()
	column.top_radius = .6
	column.bottom_radius = 1.0
	column.height = 22
	column.radial_segments = 48
	energy_column.mesh = column
	energy_column.position = Vector3(0,12,0)
	energy_column.material_override = energy_material
	energy_column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	energy_column.visible = false
	add_child(energy_column)
	shockwave = MeshInstance3D.new()
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = .96
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 96
	ring_mesh.ring_segments = 6
	shockwave.mesh = ring_mesh
	shock_material = emissive(Color(.25,.78,1),4)
	shock_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shock_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shockwave.material_override = shock_material
	shockwave.position = Vector3(0,.10,0)
	shockwave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shockwave.visible = false
	add_child(shockwave)
	charge_particles = CPUParticles3D.new()
	charge_particles.amount = 120
	charge_particles.lifetime = 3.5
	charge_particles.emitting = false
	charge_particles.position = Vector3(0,1.2,0)
	charge_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	charge_particles.emission_sphere_radius = 1.5
	charge_particles.direction = Vector3.UP
	charge_particles.spread = 12
	charge_particles.gravity = Vector3(0,.3,0)
	charge_particles.initial_velocity_min = 3
	charge_particles.initial_velocity_max = 6
	charge_particles.scale_amount_min = .02
	charge_particles.scale_amount_max = .07
	var spark: SphereMesh = SphereMesh.new()
	spark.radius = .5
	spark.height = 1
	spark.radial_segments = 6
	spark.rings = 3
	spark.material = ice
	charge_particles.mesh = spark
	add_child(charge_particles)

func build_horizon() -> void:
	var mountain: StandardMaterial3D = material(Color(.34,.38,.42),0,.96)
	mountain.albedo_texture = load("res://assets/environment/ground_v1/regolith/BaseColor.png")
	mountain.normal_enabled = true
	mountain.normal_texture = load("res://assets/environment/ground_v1/regolith/NormalGL.png")
	mountain.normal_scale = .55
	mountain.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = 221117
	noise.frequency = .011
	noise.fractal_octaves = 5
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(mountain)
	# Continuous 5m heightfield, outside the playable perimeter only. No sky billboard.
	for z in range(-60,60):
		for x in range(-60,60):
			if abs(x)<8 and abs(z)<8: continue
			var corners: Array[Vector3] = []
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,1)]:
				var px: float = (x+offset.x)*5.0
				var pz: float = (z+offset.y)*5.0
				var distance: float = Vector2(px,pz).length()
				var ridge: float = smoothstep(70,170,distance)
				var h: float = -2.0+ridge*(14.0+noise.get_noise_2d(px,pz)*45.0)
				corners.append(Vector3(px,h,pz))
			for index in [0,1,2,1,3,2]:
				var p: Vector3 = corners[index]
				surface.set_uv(Vector2(p.x,p.z)/8.0)
				surface.add_vertex(p)
	surface.generate_normals()
	surface.generate_tangents()
	var terrain: MeshInstance3D = MeshInstance3D.new()
	terrain.name = "ProceduralLunarHorizon"
	terrain.mesh = surface.commit()
	add_child(terrain)

func flush_batches() -> void:
	for key in batches:
		var batch: Dictionary = batches[key]
		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = batch.mesh
		multi.instance_count = batch.poses.size()
		for i in multi.instance_count: multi.set_instance_transform(i,batch.poses[i])
		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = batch.material
		add_child(node)

func setup_environment() -> void:
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-23,-148,0)
	sun.light_color = Color(1,.89,.73)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = .04
	add_child(sun)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_mat: ShaderMaterial = ShaderMaterial.new()
	sky_mat.shader = load("res://assets/quarantine/sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction",sun.global_basis.z)
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.31,.46,.63)
	environment.ambient_light_energy = .42
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = .65
	environment.glow_bloom = .02
	environment.glow_hdr_threshold = 1.5
	environment.fog_enabled = true
	environment.fog_light_color = Color(.12,.20,.27)
	environment.fog_light_energy = .6
	environment.fog_density = .0012
	environment.fog_sky_affect = .0
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		get_viewport().use_taa = true
		RenderingServer.directional_shadow_atlas_set_size(4096,true)
		environment.ssao_enabled = true
		environment.ssao_radius = 1.2
		environment.ssao_intensity = 1.5
		environment.ssil_enabled = true
		environment.ssil_intensity = .65
		environment.ssr_enabled = true
		environment.ssr_max_steps = 48
		environment.volumetric_fog_enabled = true
		environment.volumetric_fog_density = .0022
		environment.volumetric_fog_albedo = Color(.62,.72,.78)
		environment.volumetric_fog_length = 90
		environment.volumetric_fog_anisotropy = .45
		environment.volumetric_fog_ambient_inject = .18
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.name = "Environment"
	world_environment.environment = environment
	add_child(world_environment)
	get_viewport().positional_shadow_atlas_size = 2048
	for x in [-17.0,17.0]:
		var probe: ReflectionProbe = ReflectionProbe.new()
		probe.position = Vector3(x,4,0)
		probe.size = Vector3(32,18,65)
		probe.box_projection = true
		probe.intensity = .65
		probe.max_distance = 70
		add_child(probe)
	# Warm north-facing pools act as readable practical sources in the factory.
	for x in [-12.0,12.0]:
		fixture(Vector3(x,6,-28),Color(1,.45,.15),3.5,15,true)
	call_deferred("connect_presentation")

func connect_presentation() -> void:
	var mission: Node = get_parent()
	var player: Node = mission.get("player")
	if not is_instance_valid(player): return
	var view_env: WorldEnvironment = player.get_node("WeaponLayer/Container/Viewport/WeaponEnvironment")
	view_env.environment.ambient_light_color = Color(.3,.46,.65)
	view_env.environment.ambient_light_energy = .45
	view_env.environment.glow_enabled = false
	player.get_node("WeaponLayer/Container/Viewport/Fill").light_energy = .20
	var bloom: CanvasLayer = CanvasLayer.new()
	bloom.set_script(load("res://scripts/weapon_bloom.gd"))
	bloom.source = player.get_node("WeaponLayer/Container/Viewport")
	add_child(bloom)
	bloom.set_active(true,.65)
	weapon_bloom = bloom
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	var optics: Control = Control.new()
	optics.set_script(load("res://scripts/quarantine/optics.gd"))
	optics.world = self
	optics.mission = mission
	layer.add_child(optics)
	if ResourceLoader.exists("res://scripts/quarantine/combat_fx.gd"):
		var fx: Node3D = Node3D.new()
		fx.set_script(load("res://scripts/quarantine/combat_fx.gd"))
		fx.player = player
		fx.set("mission",mission)
		add_child(fx)

func set_bloom(value: bool) -> void:
	environment.glow_enabled = value
	if is_instance_valid(weapon_bloom): weapon_bloom.set_active(value,.65)

func _physics_process(delta: float) -> void:
	shadow_clock -= delta
	if shadow_clock > 0: return
	shadow_clock = .10
	var player: Node = get_parent().get("player")
	if not is_instance_valid(player): return
	var origin: Vector3 = player.camera.global_position
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin,origin+sun.global_basis.z*250,1,[player.get_rid()])
	sun_target = 1.0 if get_world_3d().direct_space_state.intersect_ray(ray).is_empty() else 0.0

func _process(delta: float) -> void:
	time += delta
	sun_visibility = lerpf(sun_visibility,sun_target,1.0-exp(-10.0*delta))
	var mission: Node = get_parent()
	var player: Node = mission.get("player")
	if is_instance_valid(player):
		var key: DirectionalLight3D = player.get_node("WeaponLayer/Container/Viewport/Key")
		key.basis = player.camera.global_basis.inverse()*sun.global_basis
		key.light_color = sun.light_color
		key.light_energy = sun.light_energy*lerpf(.12,.85,sun_visibility)
	var stage_value: Variant = mission.get("stage")
	var current: int = int(stage_value) if stage_value != null else 0
	if current != stage_seen:
		stage_seen = current
		if current >= 2 and current != 4:
			activation_age = 0.0
			energy_column.visible = true
			charge_particles.emitting = true
			terminal_material.emission = Color(.1,.9,.65)
			terminal_material.albedo_color = Color(.1,.9,.65)
			extraction_material.emission = Color(.1,1,.6)
			extraction_material.emission_energy_multiplier = 5
			terminal_label.text = "GRID SYNCHRONIZED\nPROCEED TO AIRLOCK 01"
		else:
			activation_age = -1.0
			energy_column.visible = false
			charge_particles.emitting = false
			shockwave.visible = false
			terminal_material.emission = Color(.025,.14,.19)
			terminal_material.albedo_color = Color(.025,.14,.19)
			terminal_label.text = "ISOLATION CONTROL\nPURGE REQUIRED"
			extraction_material.emission = Color(.15,.54,.7)
			extraction_material.emission_energy_multiplier = 1.8
	if activation_age >= 0:
		activation_age += delta
		energy_material.set_shader_parameter("power",minf(1.0,activation_age*.7))
		shockwave.visible = activation_age < 3.0
		if shockwave.visible:
			shockwave.scale = Vector3.ONE * (1.0+activation_age*9.0)
			shock_material.albedo_color.a = maxf(0.0,1.0-activation_age/3.0)
	for i in reactor_rings.size():
		reactor_rings[i].rotation.z = sin(time*.3+i*.8)*.09
	ice.emission_energy_multiplier = 3.5 + (1.5+sin(time*2)*.35 if current == 2 else 0.0)
