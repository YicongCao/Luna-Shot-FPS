@tool
extends Node3D
var asset_id := "B1"
var mounts: Array = []
var fixtures: Array[Dictionary] = []
var elapsed := 0.0
var phase := 0.0
var forced_level := -1.0
var training: Node

func _ready() -> void:
	name = "FacilityLamps"
	phase = float(absi(str(get_parent().name).hash()) % 2000) / 1000.0
	training = get_parent()
	while training and not training.has_method("set_paused"): training = training.get_parent()
	if asset_id in ["B1", "B2"]:
		for x in [-1.5, 1.5]:
			for z in [-1.5, 1.5]: add_red(Vector3(x, 5.82, z))
	if asset_id in ["C", "D"]:
		for mount in mounts: add_blue(Vector3(mount.position[0],mount.position[1],mount.position[2]), mount.rotation_x, mount.side)
	if asset_id=="E":
		for mount in mounts:add_amber(Vector3(mount.position[0],mount.position[1],mount.position[2]))
	if asset_id in ["B1","B2","C","D"]:batch_lamp_geometry()
	add_to_group("facility_lamp_modules")
	set_process(not Engine.is_editor_hint())
	refresh()

func add_red(pos: Vector3) -> void:
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = .075; cylinder.bottom_radius = .095; cylinder.height = .055
	cylinder.radial_segments = 16; base.mesh = cylinder; base.position = pos
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(.14, .17, .19); metal.metallic = .85; metal.roughness = .3
	base.material_override = metal
	add_child(base)
	var lens := MeshInstance3D.new()
	# The luminous lens transmits its own light; an opaque shadow here creates
	# a large false dark cone directly under the source.
	lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := CylinderMesh.new()
	shape.top_radius = .052; shape.bottom_radius = .058; shape.height = .115; shape.radial_segments = 20
	lens.mesh = shape; lens.position = pos + Vector3(0, .085, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(.22, .006, .003); mat.roughness = .22
	mat.emission_enabled = true; mat.emission = Color(1, .015, .005); mat.emission_energy_multiplier = 0.0
	lens.material_override = mat; add_child(lens)
	fixtures.append({"mesh":lens, "material":mat, "color":Color(1,.025,.008), "range":1.0, "level":0.0,"kind":"red","base":base,"spill_offset":Vector3(0,.07,0)})

func _process(delta: float) -> void:
	if is_instance_valid(training) and training.get("paused") == true: return
	elapsed += delta
	refresh()

func refresh() -> void:
	var t := fposmod(elapsed + phase, 2.0)
	var level := smoothstep(0.0, .06, t) * (1.0 - smoothstep(.24, .30, t))
	if asset_id in ["C", "D"]: level = 1.0
	if asset_id=="E":
		var pulse:=fposmod(elapsed+phase,1.0)
		level=.35+.65*smoothstep(0.0,.04,pulse)*(1.0-smoothstep(.12,.20,pulse))
	if forced_level >= 0: level = forced_level
	for fixture in fixtures:
		if asset_id=="E":
			fixture.level=level;fixture.beacon.set_phase(elapsed+phase,level);continue
		if not is_equal_approx(fixture.level,level):
			fixture.level = level
			if not is_equal_approx(fixture.material.emission_energy_multiplier,level*7.0):fixture.material.emission_energy_multiplier = level * 7.0

func add_blue(pos: Vector3, angle: float, side: float) -> void:
	var lens:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=Vector3(.015,.05,1.20)
	lens.mesh=shape;lens.position=pos;lens.rotation.x=angle;lens.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.005,.10,.20);mat.roughness=.24
	mat.emission_enabled=true;mat.emission=Color(.015,.34,1);mat.emission_energy_multiplier=7
	lens.material_override=mat;add_child(lens)
	fixtures.append({"mesh":lens,"material":mat,"color":Color(.025,.36,1),"range":2.0,"level":1.0,"kind":"blue","spill_offset":Vector3(side*.12,.03,0)})

func add_amber(pos: Vector3) -> void:
	var beacon:=Node3D.new();beacon.set_script(load("res://scripts/signal_beacon.gd"));beacon.position=pos;add_child(beacon)
	fixtures.append({"mesh":beacon.sector,"material":beacon.material,"color":Color(1,.24,.01),"range":3.5,"level":.35,"kind":"amber","beacon":beacon})

func batch_lamp_geometry() -> void:
	# A module's synchronized lenses share one material and one instanced draw.
	# Marker transforms remain individual light/camera attachment points.
	if fixtures.is_empty():return
	var bases: Array[MeshInstance3D]=[]
	var lenses: Array[MeshInstance3D]=[]
	for fixture in fixtures:
		lenses.append(fixture.mesh)
		if fixture.has("base"):bases.append(fixture.base)
	if not bases.is_empty():
		make_batch(bases,"LampBases",GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		for base in bases:base.free()
	var shared_material: StandardMaterial3D=lenses[0].material_override
	make_batch(lenses,"LampLenses",GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for i in fixtures.size():
		var anchor:=Node3D.new();anchor.name="LightAnchor"+str(i);anchor.transform=lenses[i].transform;add_child(anchor)
		fixtures[i].mesh=anchor;fixtures[i].material=shared_material;fixtures[i].erase("base")
		lenses[i].free()
func make_batch(instances: Array[MeshInstance3D], label: String, shadow: int) -> void:
	var batch:=MultiMeshInstance3D.new();batch.name=label
	var data:=MultiMesh.new();data.transform_format=MultiMesh.TRANSFORM_3D;data.mesh=instances[0].mesh;data.instance_count=instances.size()
	for i in instances.size():data.set_instance_transform(i,instances[i].transform)
	batch.multimesh=data;batch.material_override=instances[0].material_override;batch.cast_shadow=shadow;add_child(batch)
