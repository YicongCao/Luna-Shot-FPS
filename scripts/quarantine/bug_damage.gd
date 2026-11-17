extends Node3D
# Bounded, contact-driven electrical damage presentation. Never changes damage/AI.
const ARC_BRANCHES: int = 4
const ARC_STEPS: int = 6
const LIVE_DURATION: float = .65
const DEAD_DURATION: float = 2.2
var bug: Node3D
var age: float = 10
var duration: float = LIVE_DURATION
var hits: int = 0
var origin_local: Vector3
var last_world_hit: Vector3
var segment_count: int = 0
var refresh_clock: float = 0
var arc_mesh: ImmediateMesh
var arc_node: MeshInstance3D
var arc_material: StandardMaterial3D
var audio: AudioStreamPlayer3D
var burned: Dictionary = {}
static var crackle: AudioStreamWAV

func _ready() -> void:
	arc_mesh = ImmediateMesh.new()
	arc_node = MeshInstance3D.new()
	arc_node.mesh = arc_mesh
	arc_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc_material = StandardMaterial3D.new()
	arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_material.albedo_color = Color(.38,.72,1)
	arc_material.emission_enabled = true
	arc_material.emission = Color(.20,.52,1)
	arc_material.emission_energy_multiplier = 7
	arc_node.material_override = arc_material
	arc_node.hide()
	add_child(arc_node)
	audio = AudioStreamPlayer3D.new()
	audio.max_distance = 20
	audio.unit_size = 3
	audio.volume_db = -17
	audio.max_polyphony = 2
	if crackle == null: crackle = make_crackle()
	audio.stream = crackle
	add_child(audio)
	set_process(false)

func hit(point: Vector3, _normal: Vector3) -> void:
	last_world_hit = point
	origin_local = to_local(point)
	hits += 1
	age = 0
	duration = DEAD_DURATION if bug.dead else LIVE_DURATION
	refresh_clock = 0
	var nearest: MeshInstance3D = null
	var distance: float = INF
	for plate: MeshInstance3D in bug.plates:
		var d: float = plate.global_position.distance_squared_to(point)
		if d < distance:
			distance = d
			nearest = plate
	if nearest != null:
		if not burned.has(nearest.get_instance_id()):
			var damaged: StandardMaterial3D = nearest.material_override.duplicate()
			damaged.albedo_color = damaged.albedo_color.darkened(.58)
			damaged.roughness = .88
			damaged.metallic = .28
			nearest.material_override = damaged
			burned[nearest.get_instance_id()] = true
		if bug.dead:
			# A loosened attached plate, not a claim of simulated fracture/debris physics.
			var peel: Tween = create_tween().set_parallel(true)
			peel.tween_property(nearest,"position",nearest.position+Vector3(signf(nearest.position.x)*.12,.04,0),.22)
			peel.tween_property(nearest,"rotation:z",signf(nearest.position.x)*.55,.22)
	if DisplayServer.get_name() != "headless": audio.play()
	set_process(true)
	refresh_arcs()

func _process(delta: float) -> void:
	age += delta
	if age >= duration:
		arc_node.hide()
		if not bug.dead:
			bug.model.rotation.x = 0
			bug.model.rotation.z = 0
			bug.core_material.emission_energy_multiplier = 3
		for leg: Node3D in bug.legs: leg.rotation.x = 0
		set_process(false)
		return
	var envelope: float = exp(-age*(2.1 if bug.dead else 7.0))
	if not bug.dead:
		bug.model.rotation.x = sin(age*103)*.045*envelope
		bug.model.rotation.z = sin(age*81)*.035*envelope
		bug.core_material.emission_energy_multiplier = 1.0+absf(sin(age*79))*5.0*envelope
	for i in bug.legs.size():
		bug.legs[i].rotation.x = sin(age*74+i*1.7)*.34*envelope
	refresh_clock -= delta
	if refresh_clock <= 0:
		refresh_clock = .045
		refresh_arcs()

func shell_point(value: Vector3) -> Vector3:
	var center: Vector3 = Vector3(0,.49,.02)
	var radius: Vector3 = Vector3(.43,.29,.66)
	var offset: Vector3 = (value-center)/radius
	if offset.length_squared()<.001: offset=Vector3.UP
	return center+offset.normalized()*radius

func refresh_arcs() -> void:
	arc_mesh.clear_surfaces()
	segment_count = 0
	arc_node.visible = age < duration and (age < .14 or sin(age*91)>-.35)
	if not arc_node.visible: return
	var endpoints: Array[Vector3] = []
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var pulse: float = floorf(age/.045)
	for branch in ARC_BRANCHES:
		var destination: Vector3 = Vector3(-.35 if branch%2==0 else .35,.63,-.36 if branch<2 else .32)
		var a: Vector3 = shell_point(origin_local)
		for step in ARC_STEPS:
			var t: float = float(step+1)/ARC_STEPS
			var p: Vector3 = origin_local.lerp(destination,t)
			p += Vector3(sin(step*3.7+branch+pulse),cos(step*2.3+pulse),sin(branch*2.1+step+pulse))*.027
			var b: Vector3 = shell_point(p)
			# Architecture clips actual world-space segments, even during the fall.
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(to_global(a),to_global(b),1)
			if a.distance_squared_to(b)>.000001 and space.intersect_ray(ray).is_empty():
				endpoints.append(a)
				endpoints.append(b)
				segment_count += 1
			a = b
	if endpoints.is_empty():
		arc_node.hide()
		return
	arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(0,endpoints.size(),2):
		segment(endpoints[i],endpoints[i+1],.006*maxf(.2,1-age/duration))
	arc_mesh.surface_end()

func segment(a: Vector3, b: Vector3, radius: float) -> void:
	var axis: Vector3 = (b-a).normalized()
	if axis.length_squared()<.01: return
	var ref: Vector3 = Vector3.UP if absf(axis.y)<.9 else Vector3.RIGHT
	var u: Vector3 = axis.cross(ref).normalized()*radius
	var v: Vector3 = axis.cross(u).normalized()*radius
	var ring: Array[Vector3] = [u,v,-u,-v]
	for i in 4:
		var j: int = (i+1)%4
		for point: Vector3 in [a+ring[i],b+ring[i],a+ring[j],b+ring[i],b+ring[j],a+ring[j]]:
			arc_mesh.surface_add_vertex(point)

static func make_crackle() -> AudioStreamWAV:
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data: PackedByteArray = PackedByteArray()
	data.resize(7056*2)
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = 231117
	for i in 7056:
		var t: float = float(i)/22050
		var envelope: float = exp(-t*15)*minf(1,t*1500)
		var burst: float = .25+.75*maxf(0,sin(t*211))
		var value: float = (random.randf_range(-1,1)*.65+sin(TAU*(1750*t-1400*t*t))*.25)*envelope*burst
		data.encode_s16(i*2,int(clampf(value,-1,1)*20000))
	stream.data=data
	return stream

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream=null
