@tool
extends Node3D
var asset_id := "B1"
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
	mat.emission_enabled = true; mat.emission = Color(1, .015, .005)
	lens.material_override = mat; add_child(lens)
	fixtures.append({"mesh":lens, "material":mat, "color":Color(1,.025,.008), "range":1.4, "level":0.0})

func _process(delta: float) -> void:
	if is_instance_valid(training) and training.get("paused") == true: return
	elapsed += delta
	refresh()

func refresh() -> void:
	var t := fposmod(elapsed + phase, 2.0)
	var level := smoothstep(0.0, .06, t) * (1.0 - smoothstep(.24, .30, t))
	if forced_level >= 0: level = forced_level
	for fixture in fixtures:
		fixture.level = level
		fixture.material.emission_energy_multiplier = level * 7.0
