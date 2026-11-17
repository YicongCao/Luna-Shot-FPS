extends RefCounted
# ML23 architectural finish. All additions are built in the mission instance.
static func build(w: Node3D) -> void:
	var panel: Material = w.industrial_material(Color(.25,.29,.30),.07,.61)
	var frame: Material = w.industrial_material(Color(.13,.17,.19),.15,.48)
	var white: Material = w.industrial_material(Color(.51,.53,.50),.02,.57)
	var orange: Material = w.industrial_material(Color(.55,.21,.06),.03,.59)
	var rubber: Material = w.material(Color(.018,.023,.025),0,.88)
	var lamp: Material = w.emissive(Color(.74,.86,.89),2.1)
	var amber: Material = w.emissive(Color(1,.47,.12),1.6)
	# A restrained sheet-metal facade with seams, countersunk fasteners and vents.
	for side in [-1,1]:
		for col in 6:
			var x: float = side*(4.5+col*2.9)
			for row in 4:
				var y: float = 1.3+row*2.5
				w.box("wallGasket",Vector3(x,y,-31.27),Vector3(2.86,2.46,.14),rubber)
				w.box("wallCassette",Vector3(x,y,-31.13),Vector3(2.76,2.36,.18),panel if (row+col)%3 else frame)
				w.box("panelInset",Vector3(x,y,-31.025),Vector3(2.28,1.80,.05),frame)
				for sx in [-1.0,1.0]:
					for sy in [-1.0,1.0]:
						var p: Vector3 = Vector3(x+sx*1.24,y+sy*1.04,-31.01)
						w.beam(p,p+Vector3(0,0,.035),.028,w.steel)
				if row == 0 and col%2 == 1:
					for index in 9:
						w.box("ventSlat",Vector3(x,y-.6+index*.15,-30.97),Vector3(1.8,.06,.11),w.steel)
		# Practical ceiling light in a metal trough; don't expose a naked neon line.
		w.box("northLampHousing",Vector3(side*12,8.0,-31.16),Vector3(16.5,.40,.40),rubber)
		w.box("northLampLens",Vector3(side*12,8.0,-30.94),Vector3(15.9,.10,.03),amber)
		w.emitters.append({"position":Vector3(side*12,8,-30.90),"color":Color(1,.47,.12),"optical":true})
		w.box("northLampLip",Vector3(side*12,8.25,-30.98),Vector3(16.5,.10,.62),frame)
		for z in [-29.5,-25.5]:
			# Junction cabinets remain against the wall, outside established circulation.
			w.box("junctionBox",Vector3(side*29.7,1.4,z),Vector3(.9,1.6,.55),white)
			w.box("junctionDoor",Vector3(side*29.7,1.4,z+.3),Vector3(.76,1.40,.10),frame)
			w.box("warningTab",Vector3(side*29.7,1.75,z+.36),Vector3(.32,.16,.02),orange)
		# Continuous mounted conduits, with clamps, elbows and small diameter hierarchy.
		for y in [3.4,3.75,4.05]:
			w.beam(Vector3(side*4,y,-30.7),Vector3(side*30,y,-30.7),.09,w.steel)
		for x in range(5,30,3):
			w.box("pipeClamp",Vector3(side*x,3.75,-30.7),Vector3(.08,.96,.29),frame)
	# Central door reads as a sealed industrial opening, not a hole into the mountains.
	w.box("doorRecess",Vector3(0,3.6,-31.15),Vector3(6.6,7.2,.65),rubber)
	var door: StaticBody3D = StaticBody3D.new()
	door.name = "ReactorDoorCollision"
	door.position = Vector3(0,3.6,-30.85)
	door.collision_layer = 1
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(6.6,7.2,.65)
	collision.shape = shape
	door.add_child(collision)
	w.add_child(door)
	for side in [-1,1]:
		w.box("blastDoorLeaf",Vector3(side*1.53,3.35,-30.76),Vector3(3.0,6.5,.25),frame)
		w.box("doorInner",Vector3(side*1.53,3.5,-30.60),Vector3(2.65,5.7,.12),panel)
		w.box("doorFrame",Vector3(side*3.43,3.8,-30.85),Vector3(.38,7.6,.8),white)
		w.box("doorPiston",Vector3(side*2.63,3.35,-30.47),Vector3(.17,4.6,.22),w.steel)
		w.box("doorLock",Vector3(side*.3,3.0,-30.40),Vector3(.32,.90,.24),w.steel)
		w.box("doorIndicator",Vector3(side*3.45,4.5,-30.42),Vector3(.045,1.8,.03),lamp)
	w.box("doorHeader",Vector3(0,7.5,-30.87),Vector3(7.2,.55,.78),white)
	w.box("doorThreshold",Vector3(0,.03,-30.5),Vector3(6.7,.06,1.3),w.steel)
	w.sign_icon("lock",Vector3(0,5.1,-30.48),.9,Color(.57,.63,.61))
	# Terminal feet, grips, service connectors and a routed cable bundle establish scale.
	for x in [-.70,.70]:
		for z in [-22.0,-22.8]:
			w.box("consoleFoot",Vector3(x,.06,z),Vector3(.30,.12,.28),rubber)
			w.beam(Vector3(x,.12,z),Vector3(x,.16,z),.04,w.steel)
		w.beam(Vector3(x,.7,-22.07),Vector3(x,1.0,-22.07),.035,w.steel)
		w.beam(Vector3(x,.7,-22.07),Vector3(x,.7,-22.2),.035,w.steel)
		w.beam(Vector3(x,1.0,-22.07),Vector3(x,1.0,-22.2),.035,w.steel)
	for i in 4:
		var x: float = -.12+i*.08
		w.beam(Vector3(x,.04,-23),Vector3(x,.04,-30.4),.024,rubber)
		w.beam(Vector3(x,.04,-23),Vector3(x,.4,-22.8),.024,rubber)
	# Discreet maintenance labels anchor a human scale, no oversized floating prompts.
	for side in [-1,1]:
		w.box("safetyPlaque",Vector3(side*5,1.6,-30.87),Vector3(1.4,.60,.06),white)
		w.sign_icon("bolt",Vector3(side*5,1.6,-30.83),.48,Color(.17,.13,.08))
	# Physical emitter housings on existing guide strips soften the digital-line appearance.
	for x in [-3.75,3.75]:
		for z in range(-28,29,8):
			w.box("guideSocket",Vector3(x,.014,z),Vector3(.12,.025,1.43),frame)
	# Extra portal support: visible flanges, gussets, fixing collars rather than flat rods.
	for z in [-29.0,-18.0,0.0,18.0,30.0]:
		for x in [-31.0,31.0]:
			for y in [1.1,9.7,11.7]:
				w.box("portalCollar",Vector3(x,y,z),Vector3(.86,.18,1.02),w.steel)
			w.box("portalPlate",Vector3(x,.06,z),Vector3(1.5,.12,1.6),frame)
			for sx in [-.53,.53]:
				for sz in [-.6,.6]:
					w.beam(Vector3(x+sx,.12,z+sz),Vector3(x+sx,.20,z+sz),.055,w.steel)
