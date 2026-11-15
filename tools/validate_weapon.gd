extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var source: Node3D = load("res://assets/whitebox/lc01.tscn").instantiate()
	var exported: Node3D = load("res://art_source/weapons/lc01/lc01-whitebox.glb").instantiate()
	root.add_child(source)
	root.add_child(exported)
	await process_frame
	var checks: Array = []
	for part in source.get_children():
		var other: Node3D = exported.find_child(part.name, true, false)
		var passed := other != null
		var error := -1.0
		if passed:
			error = part.global_position.distance_to(other.global_position)
			passed = error < .0001
			if part.has_node("Mesh"):
				var expected: AABB = part.get_node("Mesh").global_transform * part.get_node("Mesh").mesh.get_aabb()
				var actual: AABB = other.global_transform * other.mesh.get_aabb()
				passed = passed and expected.position.distance_to(actual.position) < .0001 and expected.size.distance_to(actual.size) < .0001
		checks.append({"part":part.name,"passed":passed,"position_error_m":error})
	var failed := checks.filter(func(item):return not item.passed)
	var file := FileAccess.open("res://docs/validation/whitebox-v1/weapon-roundtrip.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failed.size(),"description":"Godot proxy vs Blender-exported GLB: part names, centers, world bounds, socket positions; tolerance 0.1 mm."},"\t")+"\n")
	print("WEAPON_ROUNDTRIP checks=",checks.size()," failures=",failed.size())
	quit(0 if failed.is_empty() else 1)
