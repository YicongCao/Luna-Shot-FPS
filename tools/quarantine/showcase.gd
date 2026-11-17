extends SceneTree
# Native engine movie with scripted cuts, fixed enemy staging and actual weapon shots.
# This is a presentation reel, not an unassisted end-to-end playthrough.
var mission: Node3D
func _initialize() -> void: call_deferred("run")
func aim(point: Vector3) -> void:
	var p: Node = mission.player
	var d: Vector3 = point-p.camera.global_position
	p.rotation.y = atan2(-d.x,-d.z)
	p.head.rotation.x = atan2(d.y,Vector2(d.x,d.z).length())
func run() -> void:
	mission = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	await process_frame
	var player: Node = mission.player
	player.qa_mode = true
	for bug in mission.bugs: bug.set_physics_process(false)
	mission.bugs[0].position = Vector3(1.4,.05,15)
	for frame in 960:
		var t: float = frame/60.0
		mission.health = 100.0
		if frame < 180:
			player.qa_direction = Vector3(0,0,-.3)
			aim(Vector3(sin(t*.45)*2,3.6,-7))
		elif frame < 420:
			if frame == 180:
				player.qa_direction = Vector3.ZERO
				player.position = Vector3(0,.05,22)
			aim(mission.bugs[0].global_position+Vector3(0,.46,0))
			player.aiming = frame >= 230
			if frame in [240,285,330]: player.fire()
		elif frame < 660:
			if frame == 420:
				for bug in mission.bugs:
					while not bug.dead: bug.register_hit()
				player.aiming = false
				player.position = Vector3(0,.05,-20)
			aim(Vector3(0,1.55,-22.4))
			if frame == 450: Input.action_press("interact")
			if frame == 650: Input.action_release("interact")
		elif frame < 840:
			if frame == 660:
				player.position = Vector3(-10,.05,-18)
			aim(Vector3(0,7+(t-11)*1.6,0))
		else:
			if frame == 840:
				player.position = Vector3(0,.05,22)
				player.qa_direction = Vector3(0,0,.6)
			aim(Vector3(0,2.5,31))
		await process_frame
	player.qa_direction = Vector3.ZERO
	mission.queue_free()
	for i in 12: await process_frame
	quit()
