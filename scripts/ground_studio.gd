extends "res://scripts/training.gd"
func _ready() -> void:
	super._ready()
	title.text="ML16 / 8 × 8 m GROUND SAMPLE"
	for child in hud.get_children():
		if child is Label and child.text.begins_with("ML—15"):child.text="ML—16   /   GROUND MATERIAL STUDY   /   8 × 8 m"
	help.text="WASD Move · RMB Aim · F2 Overview · B Before / After · F5 Reset · Esc Pause\nF7 Bloom · F8 Flare · F3 Weapon studio"
	# Studio has no remote ramp/beacon fixtures; same sun/sky/exposure as training.
	lighting.set_facility_enabled(false)
	for child in lighting.get_children():
		if child is MeshInstance3D:child.hide()
	var probes:=lighting.get_children().filter(func(n):return n is ReflectionProbe)
	probes[0].position=Vector3(0,2,0);probes[0].size=Vector3(12,8,12);probes[0].max_distance=14
	probes[1].visible=false
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_B:
		$GroundSurface.set_baseline(not $GroundSurface.baseline)
	else:super._unhandled_input(event)
