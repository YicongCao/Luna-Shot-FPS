extends Control
# Imagegen textures are optical kernels, not painted light sources.
var lighting: Node3D
var streak: Texture2D=preload("res://assets/lighting/streak.png")
var halo: Texture2D=preload("res://assets/lighting/halo.png")
var sources: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
var occluders: Array[Dictionary]=[]
var visible_sources: Array[Dictionary]=[]
var gun_visible_samples := 0
var gun_screen := Vector2.ZERO
var gun_visibility := 0.0
var refresh := 0.0
var sample_cost_usec := 0
var last_camera: Camera3D

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader_mat:=ShaderMaterial.new();shader_mat.shader=load("res://assets/lighting/flare.gdshader");material=shader_mat
	sources.append({"id":"Sun","position":Vector3.ZERO,"color":Color(1,.78,.48),"weight":0.0,"screen":Vector2.ZERO,"kind":"sun"})
	for fixture in lighting.fixtures:
		sources.append({"id":fixture.mesh.name,"position":fixture.mesh.global_position,"color":fixture.color,"weight":0.0,"screen":Vector2.ZERO,"kind":"lamp"})
	for i in 3:
		sources.append({"id":"ModuleLamp"+str(i),"module_index":i,"position":Vector3.ZERO,"color":Color.WHITE,"weight":0.0,"screen":Vector2.ZERO,"kind":"lamp"})
	build_weapon_samples()

func build_weapon_samples() -> void:
	var image_cache: Dictionary={}
	var candidates: Array[Dictionary]=[]
	for mesh: MeshInstance3D in lighting.player.weapon.meshes:
		occluders.append({"mesh":mesh,"tree":mesh.mesh.generate_triangle_mesh()})
		for surface in mesh.mesh.get_surface_count():
			var mat=mesh.get_active_material(surface)
			if not mat is BaseMaterial3D or not mat.emission_enabled or mat.emission_texture==null:continue
			var texture: Texture2D=mat.emission_texture
			if not image_cache.has(texture):
				var pixels:=texture.get_image()
				if pixels.is_compressed():pixels.decompress()
				image_cache[texture]=pixels
			var image: Image=image_cache[texture]
			var arrays:=mesh.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var uvs: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			for f in range(0,indices.size(),3):
				var i:=indices[f];var j:=indices[f+1];var k:=indices[f+2]
				var uv: Vector2=(uvs[i]+uvs[j]+uvs[k])/3
				var c:=image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1))
				if c.g>.35 and c.b>.35:
					candidates.append({"mesh":mesh,"point":(vertices[i]+vertices[j]+vertices[k])/3})
	# Even sampling of actual emissive triangles, not hard-coded centers inside opaque housing.
	for i in mini(32,candidates.size()):samples.append(candidates[int(float(i)*candidates.size()/mini(32,candidates.size()))])

func sample_weapon() -> void:
	var started:=Time.get_ticks_usec()
	sample_cost_usec=0
	gun_visible_samples=0;gun_screen=Vector2.ZERO
	var player: CharacterBody3D=lighting.player
	if lighting.world.overview or not player.weapon.energy_enabled or player.weapon.surface_mode==3:return
	var cam: Camera3D=player.weapon_camera
	for sample in samples:
		var point: Vector3=sample.mesh.to_global(sample.point)
		if cam.is_position_behind(point):continue
		var end: Vector3=point+(cam.global_position-point).normalized()*.0015
		var visible:=true
		for occluder in occluders:
			var mesh: MeshInstance3D=occluder.mesh
			if not mesh.is_visible_in_tree():continue
			var hit: Dictionary=occluder.tree.intersect_segment(mesh.to_local(cam.global_position),mesh.to_local(end))
			if not hit.is_empty():visible=false;break
		if visible:
			gun_screen+=cam.unproject_position(point)/cam.get_viewport().get_visible_rect().size*size
			gun_visible_samples+=1
	if gun_visible_samples>0:gun_screen/=gun_visible_samples
	sample_cost_usec=Time.get_ticks_usec()-started

func _process(delta: float) -> void:
	if not is_instance_valid(lighting) or not lighting.player:return
	var cam: Camera3D=get_viewport().get_camera_3d()
	if not cam:return
	if last_camera!=cam:
		for source in sources:source.weight=0.0
		gun_visibility=0;refresh=0;last_camera=cam
	refresh-=delta
	if refresh<=0:
		refresh=.05
		sample_weapon()
		for source in sources:
			var lamp_level:=1.0
			if source.has("module_index"):
				source.target=0.0
				if source.module_index>=lighting.module_flare_fixtures.size():continue
				var fixture: Dictionary=lighting.module_flare_fixtures[source.module_index]
				source.position=fixture.mesh.global_position;source.color=fixture.color;lamp_level=fixture.level
			var point: Vector3=cam.global_position+lighting.sun.global_basis.z*180 if source.kind=="sun" else source.position
			source.target=0.0
			if cam.is_position_behind(point):continue
			var projected:=cam.unproject_position(point)
			source.screen=projected
			var uv:=projected/size
			var edge:=clampf(minf(minf(uv.x,1-uv.x),minf(uv.y,1-uv.y))/.10,0,1)
			if edge<=0:continue
			if source.kind=="lamp" and not lighting.facility_enabled:continue
			if not lighting.world_visible(point,cam):continue
			var forward:=-cam.global_basis.z
			var facing:=maxf(0,forward.dot((point-cam.global_position).normalized()))
			var strength:=1.0 if source.kind=="sun" else minf(.6,8.0/maxf(1,cam.global_position.distance_to(point)))
			source.target=edge*pow(facing,4)*strength*lamp_level
	visible_sources.clear()
	for source in sources:
		source.weight=lerpf(source.weight,source.get("target",0.0),1-exp(-14*delta))
		if source.weight>.001:visible_sources.append(source)
	gun_visibility=lerpf(gun_visibility,1.0 if gun_visible_samples>0 else 0.0,1-exp(-16*delta))
	queue_redraw()

func optical(position: Vector2, extent: Vector2, texture: Texture2D, tint: Color, power: float) -> void:
	draw_texture_rect(texture,Rect2(position-extent*.5,extent),false,Color(tint,power))

func _draw() -> void:
	if not is_instance_valid(lighting) or not lighting.flares_enabled:return
	var ads: float=.25 if lighting.player.aiming else 1.0
	for source in visible_sources:
		var power: float=source.weight*ads
		var p: Vector2=source.screen
		var tint: Color=source.color
		var sunlight: bool=source.kind=="sun"
		optical(p,Vector2(size.x*(.8 if sunlight else .28),size.y*.045),streak,tint,power*(.7 if sunlight else .42))
		optical(p,Vector2.ONE*size.y*(.24 if sunlight else .07),halo,tint,power*(.16 if sunlight else .13))
		if sunlight:
			var axis:=size*.5-p
			for ghost in [[.65,.07,.07],[1.25,.16,.045],[1.75,.09,.06]]:
				optical(p+axis*ghost[0],Vector2.ONE*size.y*ghost[1],halo,Color(.25,.58,1),power*ghost[2])
	if gun_visibility>.001 and not lighting.world.overview and lighting.player.weapon.energy_enabled:
		optical(gun_screen,Vector2(size.x*.27,size.y*.023),streak,Color(.12,.8,1),gun_visibility*.34*ads)
		optical(gun_screen,Vector2.ONE*size.y*.055,halo,Color(.1,.8,1),gun_visibility*.08*ads)
