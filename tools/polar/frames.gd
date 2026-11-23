extends SceneTree
## Native, staged first-person composition checks. Never a substitute for the input traversal.
const Level = preload("res://scenes/polar_extraction.tscn")
const Layout = preload("res://scripts/polar/layout.gd")
const Game = preload("res://scripts/polar/mission.gd")
var game: Game
var out: String
var failed := false

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native viewport required")
		quit(1)
		return
	out = OS.get_environment("POLAR_FRAMES")
	if out.is_empty(): out = ProjectSettings.globalize_path("res://artifacts/polar-frames")
	DirAccess.make_dir_recursive_absolute(out)
	game = Level.instantiate()
	root.add_child(game)
	await saved("01-arrival",35)
	await v("02-pit-rim",Vector3(9.30,.04,42.82),Vector3(-3.7,-8.2,-19.8))
	await v("03-exterior-steps",Vector3(17.8,-2.81,35.17),Vector3(22.6,-16.6,9.6))
	await v("04-pressurized-hab",Vector3(-27.9,-8.46,26.25),Vector3(-26.5,-6.84,18.0))
	await v("05-hab-window",Vector3(-25.95,-8.46,23.78),Vector3(-1.0,-5.2,-11.0))
	await v("06-drill",Vector3(8.25,-16.96,-19.1),Vector3(-1.9,-12.0,-30.1))
	await v("07-record",Vector3(5.31,-16.96,-28.02),Layout.RECORD)
	game.threats.reset()
	await v("08-crawler",Vector3(4.8,-16.96,-18.66),Vector3(1,-13.48,-21.45),48)
	game.freight.lift.position.y = Layout.MID
	game.freight.dock = 1
	game.threats.reset()
	await v("09-mid-dock",Vector3(-.78,Layout.MID+.035,37.73),Vector3(-12.4,-7.4,37.8),16)
	await v("10-ship",Vector3(-10.7,1.10,54.98),Vector3(-11.7,2.65,41.0))
	quit(int(failed))

func v(label: String, at: Vector3, look: Vector3, frames: int = 22) -> void:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.player.look_toward(look)
	await saved(label,frames)

func saved(label: String, frames: int) -> void:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var view := root.get_texture().get_image()
	var ok := view.save_png(out.path_join(label+".png")) == OK
	if not ok: failed = true
	print("POLAR_FRAME ",label," ",view.get_width(),"x",view.get_height()," ",ok," at ",game.player.position)
