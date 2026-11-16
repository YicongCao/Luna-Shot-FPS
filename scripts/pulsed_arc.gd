extends "res://scripts/magnetic_pulse.gd"
# ML13: two seeded geometries per discrete shot, one topology change at 24 ms.
# Rendering only: never selects targets or applies damage.
const ARC_LIFE := .050
const LOCAL_LIFE := .018
const RESTRIKE_AT := .024
var arc_variants: Array = []
var branch_variants: Array = []
var coil_geometry := ImmediateMesh.new()
var coil_arc: MeshInstance3D
var arc_phase := 0
var arc_visible := false

func _ready() -> void:
	super._ready()
	name = "PulsedIonArc"
	trail.name = "WorldArcAndImpact"
	flash.name = "MuzzleDischarge"
	sound.name = "SynthesizedElectricalCrack"
	# Keep continuous joins at each kink, unlike the isolated spear in scheme A.
	var arc_shader := Shader.new()
	arc_shader.code = preload("res://assets/effects/magnetic_pulse.gdshader").code.replace(
		"smoothstep(0.0, 0.09, UV.x) * (1.0 - smoothstep(0.80, 1.0, UV.x))", "1.0")
	trail.material_override = trail.material_override.duplicate()
	trail.material_override.shader = arc_shader
	coil_arc = MeshInstance3D.new()
	coil_arc.name = "LocalCoilDischarge"
	coil_arc.mesh = coil_geometry
	coil_arc.material_override = flash.material_override
	coil_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.weapon.add_child(coil_arc)
	coil_arc.hide()

func make_sound() -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var samples := int(.065 * wav.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1301
	var previous := 0.0
	for i in samples:
		var t := float(i) / wav.mix_rate
		var noise := rng.randf_range(-1, 1)
		var crackle := (noise - previous) * .27
		previous = noise
		var first := exp(-t * 120) * minf(t / .0008, 1)
		var restrike := exp(-maxf(0,t-.018)*200) * clampf((t-.018)/.0008,0,1) * .35
		var sample := (crackle + sin(TAU * 2300 * t) * .12) * (first+restrike) * (1-t/.065)
		bytes.encode_s16(i*2, int(clampf(sample,-.8,.8)*32767))
	wav.data = bytes
	return wav

func emit_shot(from: Vector3, to: Vector3, impact: Dictionary, clear_muzzle: bool) -> void:
	build_paths(from, to, shot_count + 1, player.aiming)
	super.emit_shot(from, to, impact, clear_muzzle)

func clipped_end(a: Vector3, b: Vector3) -> Vector3:
	if a.distance_squared_to(b) < .0000001: return b
	var query := PhysicsRayQueryParameters3D.create(a,b,5,[player.get_rid()])
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("position", b)

func build_paths(a: Vector3, b: Vector3, sequence: int, ads: bool) -> void:
	arc_variants.clear()
	branch_variants.clear()
	var length := a.distance_to(b)
	var direction := (b-a).normalized()
	var right := direction.cross(Vector3.UP).normalized()
	if right.length_squared() < .01: right = Vector3.RIGHT
	var up := right.cross(direction).normalized()
	var amplitude := minf(length*.018,.18) * (.48 if ads else 1.0)
	for variant in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = sequence * 1301 + variant * 79
		var points: Array[Vector3] = [a]
		for i in range(1,12):
			var t := float(i)/12
			var envelope := sin(t*PI)
			var offset := (right*rng.randf_range(-1,1)+up*rng.randf_range(-1,1))*amplitude*envelope
			points.append(a.lerp(b,t)+offset)
		points.append(b)
		# Jitter must not make an otherwise valid hitscan visually pass through cover.
		# In cramped geometry fall back to the clear centerline; don't move the hit.
		for i in range(points.size()-1):
			if clipped_end(points[i],points[i+1]).distance_to(points[i+1]) > .015:
				for j in points.size(): points[j]=a.lerp(b,float(j)/12)
				break
		var branches: Array = []
		if length > .5:
			for index in [4,8]:
				var root_point: Vector3 = points[index]
				var lateral := (right*rng.randf_range(-1,1)+up*rng.randf_range(-1,1)).normalized()
				var middle: Vector3 = root_point + (direction*.35+lateral)*amplitude*.8
				var intended_middle := middle
				middle = clipped_end(root_point,middle)
				if middle.distance_to(intended_middle) > .0001:
					branches.append([root_point,middle])
					continue
				var tip: Vector3 = middle + (direction*.2+lateral*.4)*amplitude
				tip = clipped_end(middle,tip)
				branches.append([root_point,middle,tip])
		arc_variants.append(points)
		branch_variants.append(branches)

func clear() -> void:
	super.clear()
	arc_visible = false
	if is_instance_valid(coil_arc): coil_arc.hide()

func draw_path(mesh: ImmediateMesh, points: Array, width: float, color: Color, eye: Vector3) -> void:
	for i in range(points.size()-1): ribbon(mesh,points[i],points[i+1],width,color,eye)

func refresh() -> void:
	var gun = player.weapon
	var energy: bool = gun.energy_enabled and gun.surface_mode == 0
	var pulse := pow(maxf(0,1-age/.080),2)
	gun.material.emission_energy_multiplier = base_emission * (1+1.25*pulse if energy else 1.0)
	for i in base_lights.size(): gun.energy_lights[i].light_energy = base_lights[i]*(1+2*pulse if energy else 1.0)
	flash_light.light_energy = .24*pulse if energy and gun.spill_enabled and muzzle_clear else 0.0
	flash_light.visible = flash_light.light_energy > 0
	var size_factor := .55 if aimed else 1.0
	flash_extent = minf(.58*size_factor,start.distance_to(finish)*.85)
	flash.visible = age < LOCAL_LIFE and muzzle_clear and flash_extent > .005
	flash_geometry.clear_surfaces()
	if flash.visible:
		flash_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var eye: Vector3 = flash.to_local(player.weapon_camera.global_position)
		var path := [Vector3.ZERO,Vector3(.013*size_factor,.009,-flash_extent*.32),Vector3(-.018*size_factor,-.008,-flash_extent*.57),Vector3(.008*size_factor,.012,-flash_extent*.8),Vector3(0,0,-flash_extent)]
		draw_path(flash_geometry,path,.010*size_factor,Color(.55,.87,1,1-age/LOCAL_LIFE),eye)
		flash_geometry.surface_end()
	if is_instance_valid(coil_arc):
		coil_arc.visible = age < LOCAL_LIFE and energy and muzzle_clear
		coil_geometry.clear_surfaces()
		if coil_arc.visible:
			coil_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			var eye: Vector3 = coil_arc.to_local(player.weapon_camera.global_position)
			for side in [-1,1]:
				# Only adjacent coil supports: below the sight, ahead of the ammo screen.
				var points := [Vector3(side*.052,.085,-.365),Vector3(side*.065,.103,-.383),Vector3(side*.057,.084,-.401),Vector3(side*.068,.096,-.421),Vector3(side*.052,.079,-.440)]
				draw_path(coil_geometry,points,.0028*size_factor,Color(.25,.76,1,(1-age/LOCAL_LIFE)*.8),eye)
			coil_geometry.surface_end()
	arc_phase = 0 if age < RESTRIKE_AT else 1
	arc_visible = age < ARC_LIFE and start.distance_to(finish) > .03
	trail.visible = age < LIFE
	world_geometry.clear_surfaces()
	world_geometry.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var eye: Vector3 = player.camera.global_position
	if arc_visible and not arc_variants.is_empty():
		var width := clampf(start.distance_to(finish)*.0009,.008,.025)*size_factor
		var alpha := pow(1-age/ARC_LIFE,.65)
		draw_path(world_geometry,arc_variants[arc_phase],width,Color(.48,.85,1,alpha),eye)
		for branch in branch_variants[arc_phase]: draw_path(world_geometry,branch,width*.55,Color(.24,.60,1,alpha*.55),eye)
	if has_impact:
		var point := finish + hit_normal*.012
		var alpha := pow(maxf(0,1-age/LIFE),1.6)
		var right: Vector3 = player.camera.global_basis.x
		if age < .04: ribbon(world_geometry,point-right*.035,point+right*.035,.012,Color(.7,.92,1,alpha),eye)
		for velocity in sparks:
			var a := point+velocity*maxf(.001,age-.010)
			var b := point+velocity*maxf(.002,age)
			var kink := a.lerp(b,.5)+hit_normal*.008*alpha
			draw_path(world_geometry,[a,kink,b],.004,Color(.3,.72,1,alpha),eye)
	if not has_impact and not arc_visible:
		ribbon(world_geometry,start,start+Vector3(.001,0,0),.0001,Color(0,0,0,0),eye)
	world_geometry.surface_end()
