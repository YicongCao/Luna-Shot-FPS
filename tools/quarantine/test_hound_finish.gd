extends SceneTree
## Check actual assembled resources, not the selector string. No shot simulation here.
const BUG := preload("res://scripts/quarantine/t_bug.gd")
var failed := false

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool) -> void:
	print("FINISH CHECK ",label," ",ok)
	if not ok: failed = true

func spawn_hound(finish: String) -> CharacterBody3D:
	if finish.is_empty(): OS.unset_environment("QUARANTINE_HOUND_FINISH")
	else: OS.set_environment("QUARANTINE_HOUND_FINISH",finish)
	var bug := BUG.new()
	root.add_child(bug)
	return bug

func count_lenses(bug: CharacterBody3D) -> int:
	var count := 0
	for plate: MeshInstance3D in bug.plates:
		for mesh in plate.get_children():
			if mesh is MeshInstance3D and mesh.material_override == bug.core_material: count += 1
	return count

func run() -> void:
	OS.set_environment("QUARANTINE_BUG_STYLE","hound")
	var base := spawn_hound("baseline")
	var lit := spawn_hound("lit")
	var ceramic := spawn_hound("ceramic")
	var current := spawn_hound("")
	check("only_lit_has_six_powered_plate_inserts",count_lenses(lit)==6 and count_lenses(base)==0 and count_lenses(current)==0)
	var ok := true
	for i in 6:
		ok = ok and current.plates[i].material_override == ceramic.plates[i].material_override
		ok = ok and (current.plates[i].material_override != base.plates[i].material_override) == (i<2)
		ok = ok and lit.plates[i].material_override == base.plates[i].material_override
		ok = ok and current.plates[i].transform == base.plates[i].transform
	check("default_changes_only_two_shoulder_coatings",ok)
	var original: ShaderMaterial = current.plates[0].material_override
	current.show_electrical_hit(current.plates[0].global_position,Vector3.LEFT)
	check("shoulder_burn_is_per_instance",current.plates[0].material_override != original and ceramic.plates[0].material_override == original and current.plates[1].material_override == original)
	for b in [base,lit,ceramic,current]: b.free()
	quit(1 if failed else 0)
