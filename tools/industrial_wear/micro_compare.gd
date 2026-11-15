extends SceneTree
func _initialize() -> void: run.call_deferred()
func frames(n: int=30) -> void:
	for i in n:await process_frame
func file_tex(path: String) -> ImageTexture:
	return ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path(path)))
func run() -> void:
	root.size=Vector2i(1600,1000)
	var lab=load("res://scenes/weapon_lab.tscn").instantiate();root.add_child(lab)
	await frames();lab.qa=true;lab.center=Vector3(0,.075,-.09);lab.distance=.5;lab.yaw=1.13;lab.pitch=.32;lab.update_camera();lab.gun.field_kit.set_ammo(13,20)
	for rig in [0,1]:
		lab.set_rig(rig);lab.update_label()
		for phase in ["before","after"]:
			for pair in [["LC01",lab.gun.material],["Kit",lab.gun.field_kit.baked]]:
				var prefix="res://art_source/industrial-wear-v1/06-imagegen/"+pair[0]+"/"
				var mat=pair[1];mat.albedo_texture=file_tex(prefix+"BaseColor-"+phase+".png");mat.normal_texture=file_tex(prefix+"NormalGL-"+phase+".png");mat.metallic_texture=file_tex(prefix+"ORM-"+phase+".png");mat.roughness_texture=mat.metallic_texture;mat.ao_texture=mat.metallic_texture
			await frames();await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://docs/validation/industrial-wear-v1/micro-%d-%s.png"%[rig,phase])
	quit()
