extends RefCounted
## Hound bodywork only. Metres in model space; the nose points down -Z.
## The stationary neck ends at the moving head's axle. No physics, plate meshes,
## gait or damage state here. In particular, `light` belongs to this bug.

const HEAD_AXLE := Vector3(0, .841, -.505)

static func build(bug: Node3D, shell: Material, pale: Material, dark: Material,
		metal: Material, orange: Material, light: Material) -> Node3D:
	# Loaded at build time because the visual assembler may itself preload us.
	var v: Script = load("res://scripts/quarantine/bug_visual.gd")
	var root: Node3D = bug.model
	var fixed := Node3D.new()
	fixed.name = "HoundChassis"
	root.add_child(fixed)
	var head := Node3D.new()
	head.name = "HoundHead"
	head.position = HEAD_AXLE
	root.add_child(head)

	# Each station is (z, half breadth, keel height, crown height). The paint
	# breaks belong to the casting itself; no second skin or coplanar decals.
	_loft(fixed, "Monocoque", [
		Vector4(-.489,.125,.398,.598), Vector4(-.453,.203,.347,.661),
		Vector4(-.340,.318,.285,.715), Vector4(-.225,.324,.307,.744),
		Vector4(-.165,.290,.330,.749), Vector4(.015,.229,.372,.716),
		Vector4(.122,.193,.399,.659), Vector4(.188,.201,.394,.639),
		Vector4(.309,.296,.320,.659), Vector4(.395,.285,.334,.637),
		Vector4(.491,.188,.398,.562), Vector4(.516,.134,.420,.530)
	], [dark, shell, shell, orange, shell, dark, dark, shell, pale, pale, dark])
	# A narrow, rising counterweight leaves daylight behind the haunch, rather
	# than extending the rump with a full-width box.
	_loft(fixed, "BalanceHeel", [
		Vector4(.461,.073,.466,.548), Vector4(.521,.082,.461,.556),
		Vector4(.571,.070,.473,.569), Vector4(.674,.045,.523,.597),
		Vector4(.695,.033,.541,.589)
	], [dark, orange, shell, dark])
	_loft(fixed, "NeckCasting", [
		Vector4(-.551,.065,.790,.840), Vector4(-.515,.094,.746,.878),
		Vector4(-.462,.107,.673,.852), Vector4(-.420,.124,.604,.788),
		Vector4(-.330,.121,.583,.716)
	], [dark, metal, dark, orange])
	for side: float in [-1.0, 1.0]:
		# Bosses fill the span from the tucked body to the original six hip axes.
		for z: float in [-.32, 0.0, .32]:
			v.rod(fixed, Vector3(side*.15,.43,z), Vector3(side*.279,.43,z), .077, dark, "BearingSeat")
		# Visible cheek links seat on the neck and terminate at the common axle.
		var foot := Vector3(side*.127,.674,-.391)
		var pin := HEAD_AXLE + Vector3(side*.106,0,0)
		v.rod(fixed, foot, foot.lerp(pin,.63), .034, shell, "NeckLink")
		v.rod(fixed, foot.lerp(pin,.58), pin, .020, metal, "LinkStem")
		v.rod(fixed, foot-Vector3(side*.022,0,0), foot+Vector3(side*.024,0,0), .041, metal, "ClevisPin")

	# Head-local coordinates. Broad elevated poll, stepped brow, long lower
	# snout. The dark gasket continues under the nose; no ears or antennae.
	_loft(head, "Poll", [
		Vector4(-.203,.127,.076,.175), Vector4(-.185,.168,.046,.203),
		Vector4(-.142,.184,.015,.224), Vector4(-.060,.178,-.018,.229),
		Vector4(.019,.146,-.028,.191), Vector4(.075,.111,.012,.147),
		Vector4(.088,.088,.040,.125)
	], [dark, pale, pale, pale, orange, shell])
	_loft(head, "Snout", [
		Vector4(-.376,.064,.015,.071), Vector4(-.362,.088,.001,.087),
		Vector4(-.319,.096,-.003,.090), Vector4(-.300,.099,-.003,.091),
		Vector4(-.223,.122,-.016,.105), Vector4(-.158,.136,-.008,.127),
		Vector4(-.116,.108,.011,.118)
	], [dark, dark, orange, shell, shell, dark])
	# A recessed chin and cheek break keep the nose from reading as a single beak.
	_loft(head, "LowerJaw", [Vector4(-.336,.062,-.038,-.016),
		Vector4(-.288,.081,-.052,-.022),Vector4(-.213,.098,-.061,-.021),
		Vector4(-.154,.120,-.053,.028),Vector4(-.078,.102,-.023,.056)],
		[dark, pale, metal, dark])
	v.rod(head, Vector3(-.118,0,0), Vector3(.118,0,0), .060, dark, "NuchalBearing")
	for side: float in [-1.0, 1.0]:
		# Back-swept directional receiver on a cheek mount, with an exposed orange insulator.
		_loft(head,"Receiver",[Vector4(-.103,.023,.128,.198),Vector4(-.044,.032,.135,.233),
			Vector4(.001,.035,.153,.269),Vector4(.014,.034,.163,.282),
			Vector4(.075,.026,.221,.324),Vector4(.107,.018,.289,.339)],
			[shell,pale,orange,pale,dark],Vector3(side*.148,0,0))
		v.rod(head, Vector3(side*.115,0,0), Vector3(side*.131,0,0), .046, metal, "BearingCap")
		v.rod(head, Vector3(side*.130,0,0), Vector3(side*.135,0,0), .019, dark, "KeywayPlug")
		# Shallow lenses seated on the brow's flat forward bulkhead, above the
		# muzzle. These use the caller's live core, not a shared emissive coat.
		var eye := Vector3(side*.078,.132,-.202)
		v.rod(head, eye, eye+Vector3.FORWARD*.014, .036, metal, "LensSeat")
		v.rod(head, eye+Vector3.FORWARD*.013, eye+Vector3.FORWARD*.020, .030, dark, "LensSeal")
		v.rod(head, eye+Vector3.FORWARD*.019, eye+Vector3.FORWARD*.022, .023, light, "Optic")
		# Inspection plugs on the vertical cheek flats; not floating rivets.
		for z: float in [-.139, -.071]:
			var x := lerpf(.184, .178, (z+.142)/.082)
			var seat := Vector3(side*x,.108,z)
			v.rod(head, seat-Vector3(side*.002,0,0), seat+Vector3(side*.006,0,0), .016, metal, "CheekPlug")
			v.rod(head, seat+Vector3(side*.005,0,0), seat+Vector3(side*.007,0,0), .007, dark, "PlugSocket")
	# Only merge our rigid siblings. Never absorb a plate, leg, or the head
	# pivot into the static mesh, even if the caller built those first.
	v.merge_hardware(fixed)
	v.merge_hardware(head)
	return head


static func _ring(s: Vector4) -> PackedVector3Array:
	var w := s.y
	var lo := s.z
	var hi := s.w
	var h := hi-lo
	# Broad brow chamfer, narrower rolled keel. Clockwise in the XY diagram.
	return PackedVector3Array([
		Vector3(-w*.66,hi,s.x), Vector3(w*.66,hi,s.x),
		Vector3(w,hi-h*.24,s.x), Vector3(w,lo+h*.20,s.x),
		Vector3(w*.73,lo,s.x), Vector3(-w*.73,lo,s.x),
		Vector3(-w,lo+h*.20,s.x), Vector3(-w,hi-h*.24,s.x)])


static func _loft(parent: Node3D, label: String, stations: Array[Vector4], paints: Array[Material], at := Vector3.ZERO) -> void:
	assert(stations.size() == paints.size()+1)
	var tools := {}
	var ring := _ring(stations[0])
	for i in paints.size():
		var paint := paints[i]
		if not tools.has(paint):
			var tool := SurfaceTool.new()
			tool.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[paint] = tool
		var st: SurfaceTool = tools[paint]
		var next := _ring(stations[i+1])
		for j in 8:
			var k := (j+1)%8
			var edge := .65 if j%2 == 1 else .0
			_tri(st, ring[j], ring[k], next[k], edge)
			_tri(st, ring[j], next[k], next[j], edge)
			if i == 0:
				_tri(st, (ring[0]+ring[4]+ring[1]+ring[5])*.25, ring[k], ring[j], .0)
			if i == paints.size()-1:
				_tri(st, (next[0]+next[4]+next[1]+next[5])*.25, next[j], next[k], .0)
		ring = next
	for paint: Material in tools:
		var st: SurfaceTool = tools[paint]
		st.index()
		st.generate_tangents()
		var node := MeshInstance3D.new()
		node.name = label
		node.position = at
		node.mesh = st.commit()
		node.material_override = paint
		parent.add_child(node)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, edge: float) -> void:
	var n := (c-a).cross(b-a).normalized() # Godot's clockwise front face.
	for p: Vector3 in [a,b,c]:
		var uv := Vector2(p.x,p.z)
		match n.abs().max_axis_index():
			Vector3.AXIS_X: uv = Vector2(p.z,p.y)
			Vector3.AXIS_Z: uv = Vector2(p.x,p.y)
		st.set_normal(n)
		st.set_color(Color(edge,0,0,1))
		st.set_uv(uv)
		st.add_vertex(p)
