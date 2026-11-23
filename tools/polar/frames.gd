extends SceneTree
## Native, staged first-person composition checks. Never a substitute for the input traversal.
const Level = preload("res://scenes/polar_extraction.tscn")
const Layout = preload("res://scripts/polar/layout.gd")
const Game = preload("res://scripts/polar/mission.gd")
const Lighting = preload("res://scripts/polar/lighting.gd")
const HAB_FEET := Vector3(-27.9,-8.46,26.25)
const HAB_LOOK := Vector3(-26.5,-6.84,18.0)
const RECORD_FEET := Vector3(5.31,-16.96,-28.02)
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
	# This fast image sweep does not test audio; the continuous native route still does.
	game.audio.muted = true
	await saved("01-arrival",35)
	await v("02-pit-rim",Vector3(9.30,.04,42.82),Vector3(-3.7,-8.2,-19.8))
	await v("03-exterior-steps",Vector3(17.8,-2.81,35.17),Vector3(22.6,-16.6,9.6))
	await v("04-pressurized-hab",HAB_FEET,HAB_LOOK)
	await v("05-hab-window",Vector3(-25.95,-8.46,23.78),Vector3(-1.0,-5.2,-11.0))
	await v("06-drill",Vector3(8.25,-16.96,-19.1),Vector3(-1.9,-12.0,-30.1))
	await v("07-record",RECORD_FEET,Layout.RECORD)
	game.threats.reset()
	await v("08-crawler",Vector3(4.8,-16.96,-18.66),Vector3(1,-13.48,-21.45),48)
	game.freight.lift.position.y = Layout.MID
	game.freight.dock = 1
	game.threats.reset()
	await v("09-mid-dock",Vector3(-.78,Layout.MID+.035,37.73),Vector3(-12.4,-7.4,37.8),16)
	await v("10-ship",Vector3(-10.7,1.10,54.98),Vector3(-11.7,2.65,41.0))
	if "--polar-lighting-qa" in OS.get_cmdline_user_args():
		await _lighting_frames()
	quit(int(failed))

func _lighting_frames() -> void:
	var env := game.environment
	var polished := Lighting.polished()
	var volume := game.site.get_node_or_null("DrillExhaust") as FogVolume
	var spot := game.site.get_node_or_null("ExhaustWorkLight") as SpotLight3D
	_check("native AO, zero global density and no extra full-screen GI or reflections",
		env.ssao_enabled and env.volumetric_fog_enabled and is_zero_approx(env.volumetric_fog_density)
		and not env.sdfgi_enabled and not env.ssil_enabled and not env.ssr_enabled)
	_check("one bounded exhaust volume",game.find_children("*","FogVolume",true,false).size() == 1)
	var profile_ok := (is_instance_valid(volume) and is_instance_valid(spot) if polished
		else game.has_node("SublimationAtDrill") and volume == null and spot == null)
	_check("matching stage lighting profile",profile_ok)
	print("POLAR_LIGHT_PROFILE ","enhanced" if polished else "baseline")
	game.threats.set_physics_process(false)
	var lit := await v("11-exhaust",Vector3(-2.72,-16.96,-20.87),Vector3(-3.23,-15.70,-26.55),38)
	if not polished or not profile_ok: return
	_check("exhaust is lit by a fixed shadowed work light",spot.shadow_enabled and spot.light_volumetric_fog_energy > 0.0)
	var scatter := spot.light_volumetric_fog_energy
	spot.light_volumetric_fog_energy = 0.0
	var unlit := await saved("12-exhaust-no-work-light-scatter",30)
	spot.light_volumetric_fog_energy = scatter
	var scatter_samples := _brighter(lit,unlit,Rect2(.34,.38,.30,.245),.035)
	_check("visible scattering below the work light (%d samples)" % scatter_samples,scatter_samples >= 90)
	# Keep geometry, exposure and sources fixed; revert just AO for the close comparison.
	var tuned_ao := Vector4(env.ssao_radius,env.ssao_intensity,env.ssao_light_affect,env.ssao_detail)
	env.ssao_radius = .84
	env.ssao_intensity = 1.34
	env.ssao_light_affect = .25
	env.ssao_detail = Environment.new().ssao_detail
	var old_ao := await v("13-record-ml35-ao",RECORD_FEET,Layout.RECORD,28)
	var contact := _brighter(old_ao,Image.load_from_file(out.path_join("07-record.png")),Rect2(.075,.615,.55,.31),.012)
	_check("AO adds visible contact contrast at the recorder (%d samples)" % contact,contact >= 40)
	env.ssao_radius = tuned_ao.x
	env.ssao_intensity = tuned_ao.y
	env.ssao_light_affect = tuned_ao.z
	env.ssao_detail = tuned_ao.w
	env.glow_enabled = false
	var no_glow := await v("14-hab-no-glow",HAB_FEET,HAB_LOOK,28)
	var glow := _brighter(Image.load_from_file(out.path_join("04-pressurized-hab.png")),no_glow,Rect2(.39,.025,.13,.19),.024)
	_check("native glow reaches the immediate lamp surround (%d samples)" % glow,glow >= 60)

func _brighter(a: Image, b: Image, bounds: Rect2, threshold: float) -> int:
	if a == null or b == null or a.get_size() != b.get_size(): return 0
	var dims := Vector2(a.get_size())
	var region := Rect2i(bounds.position*dims,bounds.size*dims)
	var hits := 0
	for y in range(region.position.y,region.end.y,3):
		for x in range(region.position.x,region.end.x,3):
			if a.get_pixel(x,y).get_luminance()-b.get_pixel(x,y).get_luminance() > threshold:
				hits += 1
	return hits

func _check(label: String, passed: bool) -> void:
	if not passed: failed = true
	print("POLAR_LIGHT_CHECK ",label," ",passed)

func v(label: String, at: Vector3, look: Vector3, frames: int = 22) -> Image:
	game.player.position = at
	game.player.velocity = Vector3.ZERO
	game.player.look_toward(look)
	return await saved(label,frames)

func saved(label: String, frames: int) -> Image:
	for i in frames:
		await process_frame
	await RenderingServer.frame_post_draw
	var view := root.get_texture().get_image()
	var ok := view.save_png(out.path_join(label+".png")) == OK
	if not ok: failed = true
	print("POLAR_FRAME ",label," ",view.get_width(),"x",view.get_height()," ",ok," at ",game.player.position)
	return view
