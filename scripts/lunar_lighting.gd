extends Node3D
# Lighting lives with the range; the independent F3 studio never inherits these nodes.
var world: Node3D
var player: CharacterBody3D
var environment: Environment
var weapon_environment: Environment
var sun: DirectionalLight3D
var fixtures: Array[Dictionary]=[]
var flare_layer: CanvasLayer
var flare_pass: Control
var bloom_enabled := true
var flares_enabled := true
var facility_enabled := true
var sun_visibility := 1.0
var sun_target_visibility := 1.0
var weapon_key: DirectionalLight3D
var shadow_clock := 0.0
var weapon_bloom: CanvasLayer
var module_light_pool: Array[OmniLight3D] = []
var beacon_spot: SpotLight3D
var module_spill_enabled:=true

func _ready() -> void:
	world=get_parent();player=world.get_node("Player")
	# Small 1.4–2m local pools do not need the default full-range shadow atlas.
	get_viewport().positional_shadow_atlas_size=1024
	sun=world.get_node("Sun")
	sun.rotation_degrees=Vector3(-18,-32,0)
	sun.light_color=Color(1,.94,.84);sun.light_energy=1.15
	sun.shadow_enabled=true;sun.directional_shadow_max_distance=100
	environment=world.get_node("Environment").environment
	environment.background_mode=Environment.BG_SKY
	var sky:=Sky.new();var sky_mat:=ShaderMaterial.new()
	sky_mat.shader=load("res://assets/lighting/lunar_sky.gdshader")
	sky_mat.set_shader_parameter("sun_direction",sun.global_basis.z)
	sky.sky_material=sky_mat;environment.sky=sky
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.38,.47,.61);environment.ambient_light_energy=.24
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure=1.0
	environment.glow_hdr_threshold=2.0;environment.glow_hdr_scale=1.3
	environment.glow_intensity=.8;environment.glow_bloom=0
	weapon_environment=player.get_node("WeaponLayer/Container/Viewport/WeaponEnvironment").environment
	weapon_environment.ambient_light_energy=.24
	weapon_environment.glow_hdr_threshold=1.8;weapon_environment.glow_hdr_scale=1.4
	weapon_environment.glow_intensity=1.0
	weapon_key=player.get_node("WeaponLayer/Container/Viewport/Key")
	player.get_node("WeaponLayer/Container/Viewport/Fill").light_energy=.08
	var installed:=get_tree().get_nodes_in_group("facility_lamp_modules")
	if not installed.any(func(m):return m.asset_id in ["C","D"]):
		for x in [-19.75,19.75]:
			for z in [-15.6,15.6]:add_fixture(Vector3(x,1.2,z),Color(.28,.76,1),true,"Ramp")
		add_fixture(Vector3(0,1.35,1.03),Color(.25,.9,1),false,"Control")
	if not installed.any(func(m):return m.asset_id=="E"):
		add_fixture(Vector3(0,14.27,0),Color(1,.29,.075),false,"Beacon")
	for x in [-17,17]:
		var probe:=ReflectionProbe.new();probe.name="StaticFacilityReflection"
		probe.position=Vector3(x,3,0);probe.size=Vector3(32,16,64)
		probe.origin_offset=Vector3(0,0,0);probe.update_mode=ReflectionProbe.UPDATE_ONCE
		probe.max_distance=55;probe.intensity=.7;probe.box_projection=true
		add_child(probe)
	flare_layer=CanvasLayer.new();flare_layer.name="OpticalEffects";flare_layer.layer=3;add_child(flare_layer)
	flare_pass=Control.new();flare_pass.set_script(load("res://scripts/lens_flare.gd"))
	flare_pass.lighting=self;flare_layer.add_child(flare_pass)
	flare_pass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weapon_bloom=CanvasLayer.new();weapon_bloom.name="WeaponBloom"
	weapon_bloom.set_script(load("res://scripts/weapon_bloom.gd"))
	weapon_bloom.source=player.get_node("WeaponLayer/Container/Viewport")
	add_child(weapon_bloom)
	for i in 8:
		var light := OmniLight3D.new()
		light.name = "ModuleSpill" + str(i)
		light.visible = false
		light.shadow_enabled = true
		add_child(light)
		module_light_pool.append(light)
	beacon_spot=SpotLight3D.new();beacon_spot.name="SignalBeaconSweep";beacon_spot.spot_range=3.5;beacon_spot.spot_angle=55;beacon_spot.spot_attenuation=1.5;beacon_spot.shadow_enabled=true;beacon_spot.visible=false;add_child(beacon_spot)
	set_bloom(true)

func add_fixture(pos: Vector3, color: Color, post: bool, label: String) -> void:
	var mesh:=MeshInstance3D.new();var shape:=SphereMesh.new()
	shape.radius=.075;shape.height=.15;shape.radial_segments=12;shape.rings=6;mesh.mesh=shape
	mesh.position=pos;mesh.name=label+str(fixtures.size());mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new();mat.albedo_color=color
	mat.emission_enabled=true;mat.emission=color;mat.emission_energy_multiplier=7
	mesh.material_override=mat;add_child(mesh)
	if post:
		var support:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.1,1.12,.1)
		support.mesh=box;support.position=pos-Vector3(0,.64,0)
		var steel:=StandardMaterial3D.new();steel.albedo_color=Color(.08,.11,.14);steel.metallic=.8;steel.roughness=.4
		support.material_override=steel;add_child(support)
	var light:=OmniLight3D.new();light.position=pos;light.light_color=color
	light.light_energy=1.2;light.omni_range=3.0;light.omni_attenuation=1.4;light.shadow_enabled=false
	add_child(light)
	fixtures.append({"mesh":mesh,"light":light,"material":mat,"color":color,"label":label})

func set_bloom(value: bool) -> void:
	bloom_enabled=value
	if environment:environment.glow_enabled=value
	if weapon_environment:weapon_environment.glow_enabled=false

func set_facility_enabled(value: bool) -> void:
	facility_enabled=value
	for fixture in fixtures:
		fixture.light.visible=value;fixture.material.emission_enabled=value

func world_visible(point: Vector3, cam: Camera3D) -> bool:
	var origin:=cam.global_position
	var direction:=point-origin
	var end:=point-direction.normalized()*.1
	var query:=PhysicsRayQueryParameters3D.create(origin,end,1,[player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):return
	shadow_clock-=delta
	if shadow_clock<=0:
		shadow_clock=.08
		sun_target_visibility=1.0 if world_visible(player.camera.global_position+sun.global_basis.z*180,player.camera) else 0.0
	sun_visibility=lerpf(sun_visibility,sun_target_visibility,1-exp(-12*delta))

func _process(_delta: float) -> void:
	if not weapon_key:return
	update_module_lights()
	weapon_bloom.set_active(bloom_enabled and not world.overview and player.weapon.energy_enabled,.8 if player.aiming else 1.6)
	weapon_key.basis=player.camera.global_basis.inverse()*sun.global_basis
	weapon_key.light_color=sun.light_color
	weapon_key.light_energy=sun.light_energy*lerpf(.12,1.0,sun_visibility)

func update_module_lights() -> void:
	var candidates: Array[Dictionary] = []
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera: return
	var amber: Dictionary={}
	for module in get_tree().get_nodes_in_group("facility_lamp_modules"):
		for fixture: Dictionary in module.fixtures:
			if fixture.material.emission_enabled != facility_enabled: fixture.material.emission_enabled = facility_enabled
			if fixture.get("kind", "red")=="amber":
				amber=fixture;continue
			var distance: float = camera.global_position.distance_squared_to(fixture.mesh.global_position)
			var max_distance:=4.5 if fixture.get("kind", "red")=="blue" else 8.0
			if distance < max_distance * max_distance:
				candidates.append({"fixture":fixture,"distance":distance,"max_distance":max_distance})
	var spot_visible:=false
	if not amber.is_empty():
		var beacon: Node3D=amber.beacon
		if beacon.lens.material_override.emission_enabled!=facility_enabled:beacon.lens.material_override.emission_enabled=facility_enabled
		spot_visible=facility_enabled and module_spill_enabled and camera.global_position.distance_to(beacon.global_position)<24
		if spot_visible:
			var direction: Vector3=beacon.rotor.global_basis.z
			beacon_spot.global_position=beacon.global_position+direction*.18
			beacon_spot.look_at(beacon_spot.global_position+direction-Vector3.UP*.65)
			beacon_spot.light_color=amber.color;beacon_spot.light_energy=2.2*amber.level
	beacon_spot.visible=spot_visible
	candidates.sort_custom(func(a, b): return a.distance < b.distance)
	# Stable fixture-to-slot ownership keeps blink phases from moving all shadow maps.
	candidates=candidates.slice(0,8)
	var used: Array[int]=[]
	var slots: Dictionary={}
	for candidate in candidates:
		var id: int=candidate.fixture.mesh.get_instance_id()
		for i in module_light_pool.size():
			if module_light_pool[i].get_meta("fixture_id",0)==id:
				slots[id]=i;used.append(i);break
	for candidate in candidates:
		var id: int=candidate.fixture.mesh.get_instance_id()
		if slots.has(id):continue
		for i in module_light_pool.size():
			if i not in used:
				slots[id]=i;used.append(i);module_light_pool[i].set_meta("fixture_id",id);break
	for i in module_light_pool.size():
		if i not in used:module_light_pool[i].visible=false
	var activated:=0
	for candidate in candidates:
		var fixture: Dictionary=candidate.fixture
		var light: OmniLight3D=module_light_pool[slots[fixture.mesh.get_instance_id()]]
		var pos: Vector3=fixture.mesh.global_position+fixture.get("spill_offset",Vector3(0,.07,0))
		if not light.global_position.is_equal_approx(pos):light.global_position=pos
		if light.light_color!=fixture.color:light.light_color=fixture.color
		if light.omni_range!=fixture.range:light.omni_range=fixture.range
		if light.omni_attenuation!=2.0:light.omni_attenuation=2.0
		var energy: float=.45*fixture.level*(1.0-smoothstep(candidate.max_distance-1.0,candidate.max_distance,sqrt(candidate.distance)))
		if not is_equal_approx(light.light_energy,energy):light.light_energy=energy
		light.visible=facility_enabled and module_spill_enabled and fixture.level>.001 and activated<2
		if light.visible:activated+=1

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	match event.physical_keycode:
		KEY_F6:player.weapon.set_energy_enabled(not player.weapon.energy_enabled)
		KEY_F7:set_bloom(not bloom_enabled)
		KEY_F8:flares_enabled=not flares_enabled
		KEY_F9:
			player.weapon.set_spill_enabled(not player.weapon.spill_enabled)
			module_spill_enabled=player.weapon.spill_enabled
