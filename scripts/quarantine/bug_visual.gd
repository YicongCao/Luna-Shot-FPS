extends RefCounted
# ML26: code-authored service robot, within the existing six-leg/three-hit contract.
# No imported model, high-poly bake or new imagegen call. UVs are metre-scaled.
const Rounded = preload("res://scripts/quarantine/rounded_geometry.gd")
static var mesh_cache: Dictionary = {}
static var material_cache: Dictionary = {}

static func finish_mesh(parent: Node3D, mesh: Mesh, at: Vector3, material: Material, label: String) -> MeshInstance3D:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node

static func box(parent: Node3D, at: Vector3, size: Vector3, material: Material, label: String = "Housing") -> MeshInstance3D:
	var key: String = "box"+str(size)
	if not mesh_cache.has(key): mesh_cache[key] = Rounded.box_mesh(size,minf(size.x,minf(size.y,size.z))*.16)
	return finish_mesh(parent,mesh_cache[key],at,material,label)

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material, label: String = "Shaft") -> MeshInstance3D:
	var key: String = "rod"+str(radius)+":"+str(a.distance_to(b))
	if not mesh_cache.has(key):
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius=radius
		mesh.bottom_radius=radius
		mesh.height=a.distance_to(b)
		mesh.radial_segments=16
		mesh_cache[key]=mesh
	var node: MeshInstance3D=finish_mesh(parent,mesh_cache[key],(a+b)*.5,material,label)
	node.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
	return node

static func coat(key: String, color: Color, metal: float, roughness: float) -> ShaderMaterial:
	if not material_cache.has(key):
		var material: ShaderMaterial=ShaderMaterial.new()
		material.shader=preload("res://assets/quarantine/refine/industrial.gdshader")
		material.set_shader_parameter("coating",color)
		material.set_shader_parameter("base_metal",metal)
		material.set_shader_parameter("base_roughness",roughness)
		material.set_shader_parameter("wear_mask",preload("res://assets/quarantine/refine/wear_mask.png"))
		material_cache[key]=material
	return material_cache[key]

static func panel_mesh() -> ArrayMesh:
	if mesh_cache.has("armor"): return mesh_cache.armor
	# Clipped plan corners, side walls and actual sloping perimeter bevels.
	var outline: Array[Vector2]=[Vector2(-.13,-.14),Vector2(.13,-.14),Vector2(.17,-.095),Vector2(.17,.095),Vector2(.13,.14),Vector2(-.13,.14),Vector2(-.17,.095),Vector2(-.17,-.095)]
	var rings: Array[Vector2]=[Vector2(.88,-.09),Vector2(1,-.065),Vector2(1,.045),Vector2(.83,.09)]
	var surface: SurfaceTool=SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in 3:
		for i in 8:
			var j: int=(i+1)%8
			var a: Vector3=Vector3(outline[i].x*rings[level].x,rings[level].y,outline[i].y*rings[level].x)
			var b: Vector3=Vector3(outline[j].x*rings[level].x,rings[level].y,outline[j].y*rings[level].x)
			var c: Vector3=Vector3(outline[j].x*rings[level+1].x,rings[level+1].y,outline[j].y*rings[level+1].x)
			var d: Vector3=Vector3(outline[i].x*rings[level+1].x,rings[level+1].y,outline[i].y*rings[level+1].x)
			triangle(surface,a,b,c,0.7 if level!=1 else 0.0)
			triangle(surface,a,c,d,0.7 if level!=1 else 0.0)
	for level in [0,3]:
		for i in 8:
			var j: int=(i+1)%8
			triangle(surface,Vector3(0,rings[level].y,0),Vector3(outline[i].x*rings[level].x,rings[level].y,outline[i].y*rings[level].x),Vector3(outline[j].x*rings[level].x,rings[level].y,outline[j].y*rings[level].x),0)
	surface.generate_tangents()
	mesh_cache.armor=surface.commit()
	return mesh_cache.armor

static func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, edge: float) -> void:
	var n: Vector3=(c-a).cross(b-a).normalized() # Godot clockwise front face.
	if n.dot((a+b+c)/3)<0:
		var swap: Vector3=b
		b=c
		c=swap
		n=-n
	for p in [a,b,c]:
		surface.set_normal(n)
		surface.set_color(Color(edge,0,0,1))
		var uv: Vector2=Vector2(p.x,p.z) if absf(n.y)>.5 else (Vector2(p.z,p.y) if absf(n.x)>.5 else Vector2(p.x,p.y))
		surface.set_uv(uv)
		surface.add_vertex(p)

static func merge_hardware(parent: Node3D, retained: Array[MeshInstance3D] = []) -> void:
	# Preserve six damageable panels and animated leg roots. Merge only rigid siblings.
	var groups: Dictionary={}
	for node in parent.get_children():
		if not node is MeshInstance3D or node in retained: continue
		var key: int=node.material_override.get_instance_id()
		if not groups.has(key): groups[key]={"tool":SurfaceTool.new(),"material":node.material_override,"count":0,"vertices":0}
		var group: Dictionary=groups[key]
		if group.count==0: group.tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		# append_from must not mix indexed primitives with unindexed beveled boxes.
		var source: Mesh=node.mesh
		var arrays: Array=source.surface_get_arrays(0)
		if arrays[Mesh.ARRAY_INDEX]==null or arrays[Mesh.ARRAY_INDEX].is_empty():
			var cache_key: String="indexed:"+str(source.get_rid())
			if not mesh_cache.has(cache_key):
				var indexed: SurfaceTool=SurfaceTool.new()
				indexed.create_from(source,0)
				indexed.index()
				mesh_cache[cache_key]=indexed.commit()
			source=mesh_cache[cache_key]
		group.vertices+=source.get_faces().size()
		group.tool.append_from(source,0,node.transform)
		group.count+=1
		parent.remove_child(node)
		node.free()
	for group in groups.values():
		var merged: ArrayMesh=group.tool.commit()
		assert(merged.get_faces().size()==group.vertices,"Rigid merge dropped triangles")
		var instance: MeshInstance3D=finish_mesh(parent,merged,Vector3.ZERO,group.material,"RigidHardware")
		instance.set_meta("source_triangle_count",group.vertices/3)

static func build(bug: Node3D) -> void:
	var root: Node3D=bug.model
	var shell: Material=coat("graphite",Color(.27,.30,.29),.12,.56)
	var pale: Material=coat("ceramic",Color(.57,.56,.49),.05,.63)
	var dark: Material=coat("rubber",Color(.028,.033,.035),.02,.78)
	var metal: Material=coat("machined",Color(.33,.36,.38),.86,.32)
	var orange: Material=coat("warning",Color(.61,.19,.035),.08,.61)
	bug.core_material=bug._material(Color(1,.24,.025),.25)
	bug.core_material.emission_enabled=true
	bug.core_material.emission=Color(1,.16,.015)
	bug.core_material.emission_energy_multiplier=3.0
	var light: Material=bug.core_material
	box(root,Vector3(0,.44,.02),Vector3(.57,.25,.9),dark,"SealedChassis")
	box(root,Vector3(0,.305,.02),Vector3(.40,.045,.76),metal,"BellySkid")
	box(root,Vector3(0,.605,.025),Vector3(.16,.16,.91),dark,"RecessedSpine")
	# Recessed luminous cells, not a broad glowing sphere.
	for i in 9:
		box(root,Vector3(0,.692,-.34+i*.09),Vector3(.075,.015,.047),light,"PowerCell")
	for segment in 3:
		for side in [-1,1]:
			var plate: MeshInstance3D=finish_mesh(root,panel_mesh(),Vector3(side*.21,.57,-.27+segment*.3),pale if segment==1 else shell,"ArmorPanel")
			plate.rotation.z=side*-.18
			bug.plates.append(plate)
			# Raised top strip and gasket seam; hardware follows the loosened plate.
			box(plate,Vector3(side*.11,.094,0),Vector3(.025,.012,.16),orange if segment==1 else metal,"EdgeRail")
			for z in [-.082,.082]:
				for x in [-.09,.07]:
					rod(plate,Vector3(x,.089,z),Vector3(x,.098,z),.012,metal,"CaptiveBolt")
					box(plate,Vector3(x,.099,z),Vector3(.012,.002,.003),dark,"BoltSlot")
			for slot in 4:
				box(plate,Vector3(-side*.015,.092,-.055+slot*.036),Vector3(.09,.009,.011),dark,"RecessedVent")
			merge_hardware(plate)
	box(root,Vector3(0,.43,-.51),Vector3(.43,.22,.23),shell,"SensorHousing")
	box(root,Vector3(0,.47,-.633),Vector3(.32,.12,.025),dark,"SensorGasket")
	box(root,Vector3(0,.343,-.59),Vector3(.29,.04,.16),metal,"ImpactJaw")
	for side in [-1,1]:
		rod(root,Vector3(side*.12,.48,-.64),Vector3(side*.12,.48,-.67),.047,metal,"OpticBezel")
		rod(root,Vector3(side*.12,.48,-.67),Vector3(side*.12,.48,-.674),.029,light,"OpticLens")
		var base: Vector3=Vector3(side*.16,.53,-.53)
		var joint: Vector3=Vector3(side*.27,.79,-.7)
		var tip: Vector3=Vector3(side*.4,.78,-.93)
		rod(root,base,base.lerp(joint,.32),.034,dark,"AntennaBoot")
		rod(root,base,joint,.014,metal)
		rod(root,joint,tip,.011,metal)
		box(root,tip,Vector3(.05,.04,.065),dark,"AntennaCap")
		box(root,tip+Vector3(0,.025,0),Vector3(.028,.008,.035),light,"AntennaStatus")
		for segment in 3:
			var leg: Node3D=Node3D.new()
			leg.name="ArticulatedLeg"
			leg.position=Vector3(side*.28,.43,(segment-1)*.32)
			root.add_child(leg)
			bug.legs.append(leg)
			var knee: Vector3=Vector3(side*.37,.02,(segment-1)*.09)
			var foot: Vector3=Vector3(side*.51,-.38,(segment-1)*.16)
			# Author in the original leg frame, then recenter each rigid assembly.
			var upper := leg
			var lower := leg
			var pad := leg
			if bug.gait != null:
				upper = pivot(leg,"Upper")
				lower = pivot(leg,"Lower")
				pad = pivot(leg,"Pad")
			var arm: MeshInstance3D=box(upper,knee*.5,Vector3(.085,knee.length(),.085),pale,"UpperLink")
			arm.quaternion=Quaternion(Vector3.UP,knee.normalized())
			var shin: MeshInstance3D=box(lower,knee.lerp(foot,.46),Vector3(.06,knee.distance_to(foot)*.86,.07),shell,"LowerLink")
			shin.quaternion=Quaternion(Vector3.UP,(foot-knee).normalized())
			for p in [Vector3.ZERO,knee]:
				var joint_parent := upper if p==Vector3.ZERO else lower
				rod(joint_parent,p-Vector3(0,0,.059),p+Vector3(0,0,.059),.068,dark,"RotaryJoint")
				rod(joint_parent,p+Vector3(0,0,.058),p+Vector3(0,0,.066),.049,metal,"JointCap")
				rod(joint_parent,p+Vector3(0,0,.066),p+Vector3(0,0,.072),.018,dark,"JointPin")
			var piston_a: Vector3=knee*.18+Vector3(0,-.05,.06)
			var piston_b: Vector3=knee.lerp(foot,.35)+Vector3(0,0,.06)
			rod(leg,piston_a,piston_a.lerp(piston_b,.60),.027,dark,"ActuatorSleeve")
			rod(leg,piston_a.lerp(piston_b,.45),piston_b,.012,metal,"ActuatorRod")
			rod(lower,knee.lerp(foot,.80),foot+Vector3(0,.025,0),.023,metal,"AnkleShaft")
			box(pad,foot,Vector3(.13,.05,.15),dark,"TractionPad")
			box(pad,foot+Vector3(0,.025,0),Vector3(.09,.025,.10),metal,"FootMount")
			if bug.gait == null:
				merge_hardware(leg)
			else:
				center_assembly(upper,Vector3.ZERO)
				center_assembly(lower,knee)
				center_assembly(pad,foot-Vector3.UP*.025)
				bug.gait.bind_leg(leg,knee,foot)
	merge_hardware(root,bug.plates)

static func pivot(parent: Node3D, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	return node

static func center_assembly(node: Node3D, origin: Vector3) -> void:
	for child in node.get_children(): child.position -= origin
	node.position = origin
	merge_hardware(node)
