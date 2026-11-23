extends Node3D
## Polar utility lander, a lofted open hull with a walkable pressure cell and working hatch.
const Kit = preload("res://scripts/polar/kit.gd")
const Signs = preload("res://scripts/polar/signs.gd")

var hatch_panels: Array[Node3D] = []
var hatch_lamp: OmniLight3D
var closure := 0.0
var window_view := Vector3(0,2.37,-4.8)

func _ready() -> void:
	var ceramic := Kit.surface(Color(.75,.771,.777),.16,.47)
	var cowl := Kit.surface(Color(.535,.583,.628),.4,.47)
	var dark := Kit.surface(Color(.17,.205,.237),.56,.43,1)
	var graphite := Kit.surface(Color(.101,.126,.153),.12,.63,2)
	var steel := Kit.surface(Color(.42,.45,.49),.8,.34,1)
	var decking := Kit.surface(Color(.31,.36,.42),.27,.68,4)
	var marking := Kit.surface(Color(.62,.45,.25),.15,.69)
	var frost := Kit.glow(Color(.67,.82,.96),1.7)
	var inside := Kit.glow(Color(.90,.94,1.0),1.45)
	var glass := Kit.glass(Color(.39,.56,.68,.13))
	# Fuselage sections at different stations: shoulders, keel, and tapered sensor nose.
	var profiles: Array[PackedVector2Array] = []
	profiles.append(_section(1.68,1.37,3.50))
	profiles.append(_section(2.87,.52,4.55))
	profiles.append(_section(3.23,.44,4.81))
	profiles.append(_section(3.05,.51,4.74))
	profiles.append(_section(2.46,.79,4.19))
	var stations := [-7.35,-4.78,-2.62,2.64,4.23]
	for i in stations.size()-1:
		for face in 8:
			# A structurally framed forward window opens into the same first-person view.
			if i == 0 and face in [1,2,3,5,6,7]:
				continue
			var mat := ceramic if face in [1,2,3,4,5,6,7] else dark
			if face in [1,7]: mat = cowl
			var n: Vector2 = (profiles[i][face]+profiles[i][(face+1)%8])*.5-Vector2(0,2.55)
			_skin(stations[i], profiles[i], stations[i+1], profiles[i+1], face, Vector3(n.x,n.y,0), mat)
	for s in [-1.0,1.0]:
		# Raised overlap seam and ceramic heat tiles, not dark painted fake panel edges.
		for z in [-4.43,-3.69,-2.95,-2.21,-1.45,-.69,.08,.86,1.63,2.38,3.13,3.84]:
			var taper := 1.0 - maxf(0.0,absf(z)-2.62)*.105
			Kit.box(self,Vector3(s*3.15*taper,2.55,z),Vector3(.135,1.11,.68),ceramic,.048)
		for z in [-3.65,2.26]:
			var hip := Vector3(s*2.62,1.20,z)
			var knee := Vector3(s*4.08,.92,z+.21)
			var foot := Vector3(s*5.20,.26,z+.46)
			Kit.pipe(self,hip,knee,.24,dark,24)
			Kit.pipe(self,knee,foot,.17,steel,20)
			Kit.pipe(self,hip+Vector3.UP*.60,foot,.098,steel)
			Kit.pipe(self,hip+Vector3(s*.14,.38,0),foot+Vector3(-s*.4,.25,0),.135,graphite)
			Kit.pipe(self,foot-Vector3.UP*.23,foot,.61,dark,28)
			Kit.pipe(self,foot-Vector3.UP*.135,foot-Vector3.UP*.035,.68,cowl,28)
			Kit.box(self,hip+Vector3(s*.36,.40,0),Vector3(.62,.68,1.1),cowl,.08,true)
			for off in [-.31,.31]:
				Kit.pipe(self,knee+Vector3(0,0,off),knee+Vector3(0,0,off+.15),.27,steel,18)
		# Thruster sacrificial shroud and nozzle rings; moving craft is not simulated.
		for z in [-2.78,1.56]:
			var p := Vector3(s*2.95,1.04,z)
			Kit.pipe(self,p-Vector3.UP*.45,p+Vector3.UP*.30,.46,dark,26)
			Kit.pipe(self,p-Vector3.UP*.49,p-Vector3.UP*.35,.51,steel,26)
			Kit.pipe(self,p-Vector3.UP*.494,p-Vector3.UP*.472,.34,graphite,26)
		# A finned condenser, thruster service panel and stand-off pipework break up the shell.
		Kit.box(self,Vector3(s*3.07,3.0,1.09),Vector3(.31,.94,2.14),cowl,.068)
		Kit.box(self,Vector3(s*3.23,3.0,1.09),Vector3(.08,.75,1.94),graphite,.021)
		for i in 9:
			var z := .23+i*.216
			Kit.box(self,Vector3(s*3.286,2.999,z),Vector3(.13,.641,.054),steel,.013)
		Kit.pipe(self,Vector3(s*3.18,2.60,-2.10),Vector3(s*3.18,2.60,-.23),.071,steel,18)
		for z in [-1.98,-1.10,-.34]:
			Kit.box(self,Vector3(s*3.157,2.60,z),Vector3(.242,.18,.114),cowl,.022)
			Kit.box(self,Vector3(s*3.284,2.60,z),Vector3(.041,.085,.068),dark,.008)
		for i in 5:
			Kit.box(self,Vector3(s*2.98,3.04,2.26+i*.17),Vector3(.18,.54,.07),dark,.012)
		Kit.box(self,Vector3(s*3.128,2.28,1.37),Vector3(.203,.061,1.58),marking,.01)
		Kit.box(self,Vector3(s*1.68,3.86,-2.58),Vector3(.15,.075,4.40),steel,.012)
		Kit.box(self,Vector3(s*1.64,3.28,-6.24),Vector3(.21,.12,1.4),frost,.024)
		Kit.box(self,Vector3(s*2.13,2.58,-1.0),Vector3(.50,2.95,9.2),graphite,.08,true)
		for z in [-4.0,-2.35,-.70,.95,2.60,4.0]:
			Kit.box(self,Vector3(s*1.86,2.49,z),Vector3(.17,2.89,.19),cowl,.035)
			Kit.box(self,Vector3(s*1.83,1.58,z),Vector3(.15,.44,1.12),ceramic,.036)
			Kit.box(self,Vector3(s*1.86,3.57,z),Vector3(.13,.13,1.01),inside,.01)
		Kit.pipe(self,Vector3(s*1.81,3.21,-4.94),Vector3(s*1.81,3.21,3.67),.039,steel)
	# Windows are collision-bearing; no ray or jump exits the nose.
	Kit.box(self,Vector3(0,1.51,-5.90),Vector3(3.50,.89,2.70),graphite,.10,true)
	Kit.box(self,Vector3(0,3.76,-5.86),Vector3(3.55,.49,2.75),ceramic,.11,true)
	Kit.box(self,Vector3(0,2.68,-7.16),Vector3(3.28,1.45,.11),glass,.035,true)
	for x in [-1.64,0.0,1.64]:
		Kit.box(self,Vector3(x,2.68,-7.11),Vector3(.12,1.59,.14),dark,.022)
	for s in [-1.0,1.0]:
		Kit.box(self,Vector3(s*1.69,2.72,-5.96),Vector3(.105,1.38,2.4),glass,.023,true)
		Kit.beam(self,Vector3(s*1.69,3.47,-7.21),Vector3(s*2.68,4.0,-4.8),.15,cowl)
		Kit.beam(self,Vector3(s*1.69,1.92,-7.21),Vector3(s*2.7,1.78,-4.8),.17,cowl)
	Kit.pad(self,Vector3(0,1.05,-.88),Vector2(4.0,10.28),decking,.21)
	Kit.box(self,Vector3(0,4.035,-.38),Vector3(4.12,.18,9.82),cowl,.045,true)
	for z in [-4.82,-3.19,-1.56,.07,1.70,3.33]:
		Kit.box(self,Vector3(0,1.054,z),Vector3(3.93,.009,.07),dark,.002)
	Kit.box(self,Vector3(0,1.41,-4.83),Vector3(1.46,.70,.64),cowl,.075,true)
	Kit.box(self,Vector3(0,1.83,-4.63),Vector3(1.16,.10,.33),frost,.023)
	Signs.plate(self,Vector3(0,1.55,-4.501),"ship",.30)
	Kit.box(self,Vector3(0,4.55,-2.4),Vector3(1.14,.26,1.30),dark,.075)
	Kit.pipe(self,Vector3(0,4.69,-2.4),Vector3(0,5.68,-2.52),.072,steel)
	Kit.box(self,Vector3(0,5.67,-2.52),Vector3(.27,.16,.28),frost,.04)
	# Rear load ramp and thick working airlock.
	Kit.deck_ramp(self,Vector3(0,1.05,4.23),Vector3(0,.03,8.18),2.85,decking,.26)
	for x in [-1.5,1.5]:
		Kit.beam(self,Vector3(x,.07,8.22),Vector3(x,1.11,4.23),.14,marking)
	for s in [-1.0,1.0]:
		Kit.box(self,Vector3(s*2.09,2.46,4.21),Vector3(1.17,3.14,.65),ceramic,.073,true)
		Kit.box(self,Vector3(s*2.09,2.45,4.551),Vector3(.98,2.88,.055),cowl,.031)
		Kit.box(self,Vector3(s*1.44,2.38,4.24),Vector3(.14,2.65,.32),dark,.025,true)
		Kit.box(self,Vector3(s*1.47,2.48,4.470),Vector3(.066,1.85,.022),frost,.01)
		var slider := Node3D.new()
		add_child(slider)
		Kit.box(slider,Vector3(0,2.36,4.17),Vector3(1.38,2.57,.20),graphite,.060)
		Kit.box(slider,Vector3(0,2.36,4.278),Vector3(1.27,2.41,.052),cowl,.049)
		Kit.box(slider,Vector3(0,1.94,4.302),Vector3(1.18,.19,.019),marking,.008)
		hatch_panels.append(slider)
	Kit.box(self,Vector3(0,3.90,4.29),Vector3(3.09,.61,.51),ceramic,.065,true)
	Signs.plate(self,Vector3(0,3.94,4.557),"ship",.49)
	# Freight is held outside the pressure cell in this open hardpoint.
	Kit.box(self,Vector3(4.12,.26,-4.2),Vector3(1.84,.30,2.01),dark,.05,true)
	for x in [3.26,4.97]:
		Kit.box(self,Vector3(x,.60,-4.2),Vector3(.12,.60,1.98),steel,.025)
	Kit.lamp(self,Vector3(0,3.62,-2.30),Color(.78,.87,1),1.17,6.0)
	Kit.lamp(self,Vector3(0,3.55,2.28),Color(.91,.95,1),1.21,6.0)
	hatch_lamp = Kit.lamp(self,Vector3(0,3.64,4.99),Color(.68,.83,1),1.45,5.0)
	seal(0.0)

func _section(width: float, floor_y: float, top: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-width*.56,floor_y),Vector2(width*.56,floor_y),Vector2(width*.96,floor_y+.88),Vector2(width,top-.95),Vector2(width*.63,top),Vector2(-width*.63,top),Vector2(-width,top-.95),Vector2(-width*.96,floor_y+.88)])

func _skin(z0: float, section0: PackedVector2Array, z1: float, section1: PackedVector2Array, i: int, normal: Vector3, mat: Material) -> void:
	var j := (i+1)%8
	var a := Vector3(section0[i].x,section0[i].y,z0)
	var b := Vector3(section0[j].x,section0[j].y,z0)
	var c := Vector3(section1[j].x,section1[j].y,z1)
	var d := Vector3(section1[i].x,section1[i].y,z1)
	var n := (c-a).cross(b-a).normalized()
	if n.dot(normal) < 0:
		var swap := b
		b = d
		d = swap
		n = -n
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p: Vector3 in [a,b,c,a,c,d]:
		surf.set_normal(n)
		surf.add_vertex(p)
	Kit.part(self,surf.commit(),Basis.IDENTITY,Vector3.ZERO,mat)

func seal(value: float) -> void:
	closure = clampf(value,0,1)
	for i in hatch_panels.size():
		var part := hatch_panels[i]
		part.position.x = (2.16 if i == 1 else -2.16)*lerpf(1.0,.32,smoothstep(0.0,1.0,closure))
		part.visible = closure > .025
	hatch_lamp.light_energy = lerpf(1.45,.25,closure)

func is_inside(point: Vector3) -> bool:
	var p := to_local(point)
	return absf(p.x) < 1.86 and p.z > -6.12 and p.z < 3.65 and p.y > .76 and p.y < 4.03
