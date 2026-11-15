extends Node
const OUT := "res://docs/validation/rifle-pipeline-v2/"
var checks: Array = []
var world: Node3D
var player: CharacterBody3D
var frames: Array[float] = []
var started: int
func _ready() -> void:
	world=get_parent();player=world.get_node("Player")
	started=Time.get_ticks_msec()
	run.call_deferred()
func _process(delta: float) -> void: frames.append(delta*1000)
func check(label: String, passed: bool, detail: String="") -> void:
	checks.append({"check":label,"passed":passed,"detail":detail})
	print("RIFLE_QA ","PASS " if passed else "FAIL ",label," ",detail)
func settle(n: int=30) -> void:
	for i in n: await get_tree().physics_frame
func capture(name: String) -> Image:
	if DisplayServer.get_name()=="headless": return null
	await settle(10)
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	check("capture_"+name,image.save_png(OUT+name+".png")==OK)
	return image
func dot_visible(image: Image) -> bool:
	var middle := image.get_size()/2
	for x in range(middle.x-3,middle.x+4):
		for y in range(middle.y-3,middle.y+4):
			var color := image.get_pixel(x,y)
			if color.r>.65 and color.r>color.g*2.5 and color.r>color.b*2.5: return true
	return false
func run() -> void:
	await settle()
	var weapon: Node3D=player.weapon
	check("mesh_parts",weapon.meshes.size()==17,str(weapon.meshes.size()))
	var tris := 0
	for mesh: MeshInstance3D in weapon.meshes:
		for surface in mesh.mesh.get_surface_count():
			tris += mesh.mesh.surface_get_array_index_len(surface)/3
	check("triangle_budget",tris==19658,str(tris))
	check("cell_is_two_parts",weapon.get_node("P07_Cell").get_child_count()==2)
	for path in ["BaseColor","NormalGL","ORM","Emission"]:
		var tex: Texture2D=load("res://assets/weapons/lc01/"+path+".png")
		check("texture_"+path,tex.get_size()==Vector2(2048,2048),str(tex.get_size()))
	check("real_bake_loaded",weapon.material.normal_enabled and weapon.material.normal_texture.resource_path.ends_with("NormalGL.png"))
	check("orm_channels",weapon.material.ao_texture_channel==0 and weapon.material.roughness_texture_channel==1 and weapon.material.metallic_texture_channel==2)
	check("opaque_with_backface_culling", weapon.material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and weapon.material.cull_mode == BaseMaterial3D.CULL_BACK)
	check("weapon_glow_enabled", player.get_node("WeaponLayer/Container/Viewport/WeaponEnvironment").environment.glow_enabled)
	check("local_coil_spill", weapon.energy_lights.size() == 2 and weapon.energy_lights[0].visible)
	weapon.set_energy_enabled(false)
	check("energy_switch_off", not weapon.material.emission_enabled and not weapon.energy_lights[0].visible)
	weapon.set_energy_enabled(true)
	check("energy_switch_on", weapon.material.emission_enabled and weapon.energy_lights[0].visible)
	await capture("11-range-hip")
	player.rotation=Vector3.ZERO;player.head.look_at(Vector3(0,1.5,8));player.aiming=true
	await settle(60)
	var point: Vector2=player.weapon_camera.unproject_position(weapon.get_node("RedDot").global_position)
	var expected: Vector2=player.weapon_camera.get_viewport().size/2.0
	check("red_dot_center",point.distance_to(expected)<.75,"error_px=%.4f"%point.distance_to(expected))
	check("hud_cross_hidden",not world.reticle.visible)
	var shot: Image=await capture("12-range-ads")
	if shot: check("red_dot_rendered",dot_visible(shot))
	player.get_node("WeaponLayer/Container/Viewport/Key").light_energy=0
	player.get_node("WeaponLayer/Container/Viewport/Fill").light_energy=0
	var dark: Image=await capture("13-range-dot-unlit")
	if dark: check("red_dot_independent_of_lights",dot_visible(dark))
	player.get_node("WeaponLayer/Container/Viewport/Key").light_energy=.8
	player.get_node("WeaponLayer/Container/Viewport/Fill").light_energy=.4
	player.fire()
	check("ads_target_hit",world.hits==1 and player.ammo==19)
	await settle(35)
	player.head.look_at(Vector3(0,4.7,-20))
	await capture("16-range-dot-clear-background")
	player.reload_weapon()
	await settle(42)
	check("cell_animates",weapon.get_node("P07_Cell").position.y < -.1)
	await capture("14-range-reload")
	await settle(60)
	check("cell_returns",absf(weapon.get_node("P07_Cell").position.y)<.001 and player.ammo==20)
	if DisplayServer.get_name()!="headless":
		get_window().size=Vector2i(1600,700)
		player.aiming=true
		await settle(60)
		point=player.weapon_camera.unproject_position(weapon.get_node("RedDot").global_position)
		expected=player.weapon_camera.get_viewport().size/2.0
		check("ultrawide_dot_center",point.distance_to(expected)<.75,str(point.distance_to(expected)))
		var wide: Image=await capture("15-range-ultrawide-ads")
		check("ultrawide_dot_rendered",dot_visible(wide))
	frames.sort()
	var failures := checks.filter(func(c): return not c.passed)
	var report := {"engine":Engine.get_version_info().string,"platform":OS.get_name(),"display":DisplayServer.get_name(),"seconds":(Time.get_ticks_msec()-started)/1000.0,"frame_ms_p95":frames[int(frames.size()*.95)],"checks":checks,"failures":failures.size(),"note":"Short automated native render/interaction test, not long-duration performance acceptance."}
	var f:=FileAccess.open(OUT+("rifle-headless.json" if DisplayServer.get_name()=="headless" else "rifle-native.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t")+"\n")
	print("RIFLE_QA_COMPLETE failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
