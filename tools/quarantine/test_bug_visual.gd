extends SceneTree
# Native in-world diagnostic turntable; staged bug/camera, not normal gameplay.
var mission: Node3D
var output: String
var checks: Array[Dictionary]=[]
var inspection_fill: OmniLight3D
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in count: await process_frame
func check(id: String, ok: bool) -> void:
	checks.append({"id":id,"ok":ok})
	print("BUG VISUAL CHECK ",id," ",ok)
func camera_at(at: Vector3, focus: Vector3) -> void:
	var player: Node=mission.player
	player.position=at-Vector3(0,1.65,0)
	var d: Vector3=focus-player.camera.global_position
	player.rotation.y=atan2(-d.x,-d.z)
	player.head.rotation.x=atan2(d.y,Vector2(d.x,d.z).length())
	player.camera.fov=43
	if is_instance_valid(inspection_fill): inspection_fill.position=at+Vector3(0,.7,0)
func gray_tree(node: Node, material: Material) -> void:
	if node is MeshInstance3D: node.material_override=material
	for child in node.get_children(): gray_tree(child,material)
func merge_counts_match(node: Node) -> bool:
	if node is MeshInstance3D and node.has_meta("source_triangle_count"):
		if node.mesh.get_faces().size()!=int(node.get_meta("source_triangle_count"))*3: return false
	for child in node.get_children():
		if not merge_counts_match(child): return false
	return true
func capture(name: String) -> void:
	await frames(45)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	# This is the ML26 turntable, not the ML32 hound comparison.
	if OS.get_environment("QUARANTINE_BUG_STYLE").is_empty(): OS.set_environment("QUARANTINE_BUG_STYLE","refined")
	output=OS.get_environment("BUG_VISUAL_OUTPUT")
	if output.is_empty(): output="res://artifacts/bug-visual"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	mission=load("res://scenes/quarantine.tscn").instantiate()
	root.add_child(mission)
	await frames(60)
	var player: Node=mission.player
	player.qa_mode=true
	player.set_physics_process(false)
	player.set_process(false) # Keep the diagnostic lens, rather than player FOV interpolation.
	mission.hud.hide()
	player.get_node("WeaponLayer").hide()
	mission.health=100
	for b in mission.bugs:
		b.set_physics_process(false)
		b.hide()
	var bug: Node=mission.bugs[0]
	bug.show()
	bug.position=Vector3(0,.05,18)
	bug.rotation=Vector3.ZERO
	check("merged_hardware_preserves_all_triangles",merge_counts_match(bug.model))
	check("six_independent_damage_panels",bug.plates.size()==6)
	check("six_animated_leg_roots",bug.legs.size()==6)
	check("unchanged_three_hit_health",bug.health==3)
	var collider: CapsuleShape3D=bug.get_node("Collider").shape
	check("unchanged_capsule",is_equal_approx(collider.radius,.43) and is_equal_approx(collider.height,.9))
	var panel: ArrayMesh=preload("res://scripts/quarantine/bug_visual.gd").panel_mesh()
	var data: Array=panel.surface_get_arrays(0)
	var vertices: PackedVector3Array=data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=data[Mesh.ARRAY_NORMAL]
	var outward: bool=true
	var winding: bool=true
	for i in vertices.size(): outward=outward and normals[i].dot(vertices[i])>0
	for i in range(0,vertices.size(),3):
		winding=winding and (vertices[i+2]-vertices[i]).cross(vertices[i+1]-vertices[i]).normalized().dot(normals[i])>.99
	check("armor_exterior_normals",outward)
	check("armor_clockwise_front_faces",winding)
	check("armor_has_real_beveled_sides",vertices.size()==192)
	var gray: bool=OS.get_environment("BUG_REVIEW_GRAY")=="1"
	if gray:
		var material: StandardMaterial3D=StandardMaterial3D.new()
		material.albedo_color=Color(.42,.42,.42)
		material.roughness=.65
		gray_tree(bug.model,material)
		# Inspection-only fill exposes both sides; identical for both versions.
		inspection_fill=OmniLight3D.new()
		inspection_fill.light_energy=2.5
		inspection_fill.omni_range=5
		mission.add_child(inspection_fill)
	camera_at(Vector3(-1.5,1.1,15.7),Vector3(0,.45,18))
	await capture("01-front-left")
	check("diagnostic_lens_43_degrees",is_equal_approx(player.camera.fov,43))
	camera_at(Vector3(1.5,1.1,15.7),Vector3(0,.45,18))
	await capture("02-front-right")
	camera_at(Vector3(1.5,1.2,20.1),Vector3(0,.45,18))
	await capture("03-rear-right")
	camera_at(Vector3(0,1.65,22),Vector3(0,.45,18))
	player.get_node("WeaponLayer").show()
	player.camera.fov=78
	await capture("04-player-scale")
	var file: FileAccess=FileAccess.open(output+"/checks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"style":OS.get_environment("QUARANTINE_BUG_STYLE"),"gray":gray,"checks":checks,"boundary":"Staged native in-world turntable. Gray-only local fill is identical in both versions; colour images use unchanged game lighting. No unassisted playthrough claim."},"\t"))
	file.close()
	mission.queue_free()
	await frames(5)
	quit(0 if checks.all(func(c):return c.ok) else 1)
