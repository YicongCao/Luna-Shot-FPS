extends SceneTree
# Outward-facing geometry assertions plus native backface-culling views.
var output: String = "res://docs/validation/quarantine-refine-v2/geometry"
var results: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func check(id: String, ok: bool) -> void:
	results.append({"id":id,"ok":ok})
	print("CHECK ",id," ",ok)
func frames(count: int) -> void:
	for i in count: await process_frame

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var mesh: ArrayMesh = load("res://scripts/quarantine/rounded_geometry.gd").box_mesh(Vector3(2,1.4,1),.12)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var outward: bool = true
	var winding: bool = true
	for i in vertices.size():
		outward = outward and vertices[i].dot(normals[i]) > 0 and absf(normals[i].length()-1)<.001
	for i in range(0,vertices.size(),3):
		var front: Vector3 = -(vertices[i+1]-vertices[i]).cross(vertices[i+2]-vertices[i]).normalized()
		winding = winding and front.dot(normals[i]+normals[i+1]+normals[i+2]) > 0
	check("rounded_box_all_exterior_normals",outward)
	check("rounded_box_all_clockwise_front_faces",winding)
	check("rounded_box_has_real_bevel_faces",vertices.size()==324)
	var mission: Node3D = load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	await frames(5)
	var door: StaticBody3D = mission.get_node("World/ReactorDoorCollision")
	var hit: Dictionary = mission.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,2,-29),Vector3(0,2,-32),1))
	check("sealed_door_blocks_forward_hitscan",not hit.is_empty() and hit.collider==door)
	var shape: BoxShape3D = door.get_child(0).shape
	check("door_collision_outside_terminal_and_routes",door.position.z+shape.size.z*.5 < -30 and shape.size.x<=6.6)
	var optics: Node = null
	for child in mission.get_node("World").get_children():
		if child is CanvasLayer:
			for node in child.get_children():
				if node.get_script()==load("res://scripts/quarantine/optics.gd"): optics=node
	check("optics_present",optics!=null)
	check("only_two_visible_practicals_optical",mission.get_node("World").emitters.filter(func(e):return e.get("optical",false)).size()==2)
	var terrain: ArrayMesh = mission.get_node("World/ProceduralLunarHorizon").mesh
	check("terrain_indexed_for_shared_vertices",not terrain.surface_get_arrays(0)[Mesh.ARRAY_INDEX].is_empty())
	mission.queue_free()
	await frames(20)
	if DisplayServer.get_name()!="headless":
		var stage: Node3D = Node3D.new()
		root.add_child(stage)
		var instance: MeshInstance3D = MeshInstance3D.new()
		instance.mesh=mesh
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color=Color(.42,.45,.49)
		material.roughness=.4
		material.cull_mode=BaseMaterial3D.CULL_BACK
		instance.material_override=material
		stage.add_child(instance)
		var env: WorldEnvironment=WorldEnvironment.new()
		env.environment=Environment.new()
		env.environment.background_mode=Environment.BG_COLOR
		env.environment.background_color=Color(.055,.065,.08)
		env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color=Color(.6,.65,.7)
		env.environment.ambient_light_energy=.5
		stage.add_child(env)
		var camera: Camera3D=Camera3D.new()
		camera.fov=38
		stage.add_child(camera)
		camera.make_current()
		var light: DirectionalLight3D=DirectionalLight3D.new()
		light.rotation_degrees=Vector3(-35,-35,0)
		stage.add_child(light)
		var views: Dictionary={"front":Vector3(2,1.3,4),"back":Vector3(-2,1.3,-4),"left":Vector3(-4,1,1),"right":Vector3(4,1,-1)}
		for name in views:
			camera.position=views[name]
			camera.look_at(Vector3.ZERO)
			await frames(8)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output+"/"+name+".png")
		stage.queue_free()
		await frames(4)
	var file: FileAccess=FileAccess.open(output+"/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":results,"native":DisplayServer.get_name()!="headless","boundary":"Synthetic native geometry views complement exterior normal/winding assertions; not final art acceptance."},"\t"))
	file.close()
	quit(0 if results.all(func(item):return item.ok) else 1)
