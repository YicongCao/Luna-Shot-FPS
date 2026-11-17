extends SceneTree
# Deterministic presentation-state checks, not a claim of actual mission completion.
var checks: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mission: Node3D = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	var world: Node3D = mission.get_node("World")
	world.set_process(false)
	world._process(0.)
	checks["offline"] = not world.energy_column.visible and world.activation_age < 0.
	checks["three_unique_windings"] = world.winding_materials.size()==3 and world.winding_materials[0]!=world.winding_materials[1] and world.winding_materials[1]!=world.winding_materials[2]
	checks["no_caps"] = not world.energy_column.mesh.cap_top and not world.energy_column.mesh.cap_bottom
	mission.stage = mission.ACTIVATE
	world._process(.4)
	checks["waiting_for_terminal"] = not world.energy_column.visible
	mission.stage = mission.EXTRACT
	world._process(.48)
	checks["lower_coil_first"] = world.winding_materials[0].emission_energy_multiplier>2. and world.winding_materials[2].emission_energy_multiplier<.3
	checks["surface_not_floating_ring"] = not world.shockwave.visible and is_equal_approx(world.floor_material.get_shader_parameter("surge_age"),.48)
	world._process(2.8)
	checks["online"] = world.energy_column.visible and world.winding_materials.all(func(m):return m.emission_energy_multiplier>3.)
	mission.stage = mission.COMPLETE
	world._process(.01)
	checks["no_second_ignition"] = world.activation_age>3. and not world.shockwave.visible
	mission.restart()
	world._process(0.)
	checks["restart_clears_surge"] = world.activation_age<0. and world.floor_material.get_shader_parameter("surge_age")<0. and not world.energy_column.visible and world.winding_materials.all(func(m):return m.emission_energy_multiplier<.3)
	for id in checks: print("REACTOR CHECK ",id," ",checks[id])
	mission.queue_free()
	await process_frame
	await process_frame
	quit(0 if checks.values().all(func(ok):return ok) else 1)
