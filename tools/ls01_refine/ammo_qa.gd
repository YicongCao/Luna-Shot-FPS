extends SceneTree
var checks: Array = []
func _initialize() -> void: run.call_deferred()
func frames(n: int=3) -> void:
	for i in n:await process_frame
func verify(ok: bool, title: String) -> void:
	checks.append({"check":title,"passed":ok})
	if not ok:push_error("FIELD_KIT_QA FAIL "+title)
func display(p, value: int) -> void:
	await frames()
	var kit=p.weapon.field_kit
	var lit:=0
	for c in kit.cells:
		if c.material_override==kit.active_material:lit+=1
	verify(kit.shown_ammo==value and lit==value,"ammo and luminous cells %d"%value)
	verify(kit.readout.text=="%02d/20"%value,"numeric readout %d"%value)
func run() -> void:
	var world=load("res://scenes/training.tscn").instantiate();root.add_child(world);await frames(40)
	var p=world.player;p.qa_mode=true;p.blocked=false
	await display(p,20)
	for i in 20:
		p.cooldown=0
		verify(p.fire(),"fire %d"%i)
		await display(p,19-i)
	p.cooldown=0;verify(not p.fire(),"empty blocks firing");p.reload_weapon();await display(p,0)
	p._physics_process(.5);verify(p.ammo==0,"reload does not fill early")
	p._physics_process(1.5);await display(p,20)
	p.ammo=3;await display(p,3);world.reset_range();await display(p,20)
	p.blocked=true;p.ammo=4;await display(p,4)
	verify(p.weapon.field_kit.active_material.emission.r>p.weapon.field_kit.active_material.emission.b,"low ammo amber")
	var f:=FileAccess.open((OS.get_environment("LS01_REPORT_DIR")+"/" if OS.has_environment("LS01_REPORT_DIR") else "res://docs/validation/ls01-refine-v1/")+"ammo-qa.json",FileAccess.WRITE);f.store_string(JSON.stringify(checks,"\t"));f.close()
	var failed:=false
	for c in checks:failed=failed or not c.passed
	print("FIELD_KIT_QA ",checks.size()," checks, failed=",failed);quit(1 if failed else 0)
