extends Node3D
## Surface works, fast descent, and drill deck. Ships, hab and moving machinery are separate systems.
const Kit = preload("res://scripts/polar/kit.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const Signs = preload("res://scripts/polar/signs.gd")
const Lighting = preload("res://scripts/polar/lighting.gd")

var polish := Lighting.polished()
var pale := Kit.surface(Color(.71,.747,.768),.18,.55)
var alloy := Kit.surface(Color(.39,.431,.46),.63,.43,1)
var steel := Kit.surface(Color(.23,.273,.31),.58,.54,1)
var shade := Kit.surface(Color(.12,.145,.16),.38,.63)
var stone := Kit.surface(Color(.316,.328,.343),.06,.84,3)
var plate := Kit.surface(Color(.33,.37,.40),.34,.68,4)
var apron := Kit.surface(Color(.46,.465,.468),.07,.83,5)
var frost := Kit.glow(Color(.65,.79,.88),1.7)
var ochre := Kit.surface(Color(.69,.51,.247),.10,.62)
var record_cartridge: Node3D

func _ready() -> void:
	_landing()
	_ledge_route()
	_basin()
	_dock_bypass()
	_drill()
	_services()

func _landing() -> void:
	# The slab stops at the lift aperture; the parapet leaves two visible route mouths.
	Kit.pad(self,Vector3(-4.06,0,55.8),Vector2(39.42,30.24),apron,.48)
	Kit.pad(self,Vector3(-27.09,0,60.96),Vector2(6.65,19.94),apron,.48)
	Kit.pad(self,Vector3(20.6,0,58.1),Vector2(9.9,19.98),apron,.4)
	for x in range(-28,16,3):
		for z in [42.2,48.2,55.8,63.45,69.0]:
			if x < -24 and z < 51: continue
			Kit.box(self,Vector3(x,.006,z),Vector3(2.91,.012,.028),shade,.002)
	for x in [-27.0,-17.75,-4.95,12.22]:
		Kit.box(self,Vector3(x,.011,58.1),Vector3(.072,.015,20.9),alloy,.002)
	for z in range(51,68,2):
		for x in [-18.0,-5.0]:
			Kit.box(self,Vector3(x,.014,z),Vector3(.15,.02,.79),pale,.004)
	for x in [-20.3,-6.8,6.8,13.7]:
		Kit.box(self,Vector3(x,-1.77,41.30),Vector3(6.1,3.04,1.4),stone,.12,true)
		Kit.box(self,Vector3(x,.126,41.30),Vector3(5.8,.25,.29),pale,.045,true)
		Kit.box(self,Vector3(x,.253,41.47),Vector3(5.49,.071,.025),ochre,.005)
		for h in [.54,1.10]:
			Kit.box(self,Vector3(x,h,41.30),Vector3(5.78,.073,.103),alloy,.021,true)
		for off in [-2.79,0.0,2.79]:
			Kit.box(self,Vector3(x+off,.65,41.30),Vector3(.114,.98,.136),steel,.018,true)
			Kit.box(self,Vector3(x+off,.228,41.30),Vector3(.22,.09,.25),pale,.022)
	for x in [-12.0,6.4]:
		Kit.box(self,Vector3(x,.38,46.1),Vector3(.77,.75,.80),stone,.045,true)
		Kit.box(self,Vector3(x,.87,46.1),Vector3(.42,.25,.44),shade,.046)
		Kit.box(self,Vector3(x,1.02,46.1),Vector3(.32,.050,.32),frost,.019)
	_lane_post(Vector3(-24.2,0,51.88),"hab")
	_lane_post(Vector3(16.7,0,49.07),"step")
	# Approach stripe and hold-downs remain painted/installed, not UI in world-space.
	for x in [-17.78,-5.21]:
		for z in [51.43,64.45]:
			Kit.box(self,Vector3(x,.014,z),Vector3(.105,.016,1.92),pale,.003)
			Kit.box(self,Vector3(x+.72*signf(-11.5-x),.013,z-.92*signf(z-57.6)),Vector3(1.51,.015,.105),pale,.003)
		for z in [52.24,63.45]:
			Kit.box(self,Vector3(x,.084,z),Vector3(.23,.16,.34),steel,.035)
			Kit.box(self,Vector3(x,.178,z),Vector3(.145,.036,.18),frost,.013)
	for z in [55.0,59.2,63.4]:
		var at := Vector3(13.1,0,z)
		Kit.box(self,at+Vector3.UP*.13,Vector3(1.46,.26,1.74),shade,.043,true)
		Kit.box(self,at+Vector3.UP*.66,Vector3(1.26,.89,1.49),pale,.095,true)
		for i in 9:
			Kit.box(self,at+Vector3(-.645,.64,-.575+i*.148),Vector3(.04,.56,.060),steel,.008)
		Kit.box(self,at+Vector3(.01,1.14,.10),Vector3(1.01,.063,1.09),alloy,.015)
		Kit.pipe(self,at+Vector3(.42,.195,-.74),at+Vector3(.42,.195,.74),.071,steel,14)
	# High mast and bundled umbilicals: visible from the other end of the excavation.
	var foot := Vector3(7.8,0,44.8)
	Kit.box(self,foot+Vector3.UP*.39,Vector3(1.72,.78,1.66),pale,.074,true)
	Kit.beam(self,foot+Vector3.UP*.36,foot+Vector3.UP*6.7,.36,steel)
	Kit.beam(self,foot+Vector3(-2.9,.28,1.0),foot+Vector3.UP*4.4,.22,steel)
	Kit.beam(self,foot+Vector3(2.2,.28,1.0),foot+Vector3.UP*3.9,.18,steel)
	Kit.box(self,foot+Vector3(0,6.58,-.13),Vector3(1.62,.35,1.06),pale,.062)
	Kit.box(self,foot+Vector3(.53,6.43,-.53),Vector3(.24,.14,.12),frost,.024)
	Kit.spot(self,foot+Vector3(0,6.30,-.48),Vector3(0,-8,31),Color(.77,.88,1),3.9,28,36)
	for i in 3:
		_sag_line(Vector3(7.25+i*.29,6.5,44.7),Vector3(-4.3+i*.35,7.65,-27.5),6.7+i*.10,.042,steel)

func _lane_post(at: Vector3, route: String) -> void:
	Kit.box(self,at+Vector3.UP*.12,Vector3(.62,.24,.56),stone,.043,true)
	Kit.box(self,at+Vector3.UP*.82,Vector3(.17,1.44,.19),steel,.028,true)
	Kit.box(self,at+Vector3.UP*1.57,Vector3(.84,.55,.19),pale,.051)
	Signs.plate(self,at+Vector3(0,1.57,.105),route,.44)
	Kit.box(self,at+Vector3(0,1.90,.01),Vector3(.40,.076,.095),frost,.023)

func _ledge_route() -> void:
	for index in Layout.STEPS.size():
		var step := Layout.STEPS[index]
		var at := Vector3(Layout.STEP_X,step.y,step.x)
		Kit.pad(self,at,Vector2(6.32,6.20),plate,.36)
		for s in [-1.0,1.0]:
			Kit.box(self,at+Vector3(0,-.095,s*2.99),Vector3(6.22,.14,.24),pale,.027)
			Kit.box(self,at+Vector3(0,.009,s*2.63),Vector3(3.80,.018,.072),ochre,.004)
			for x in [-2.7,2.7]:
				Kit.box(self,at+Vector3(x,.049,s*2.56),Vector3(.19,.067,.32),frost,.018)
		for x in [-2.34,2.34]:
			var p := at+Vector3(x,-.23,0)
			Kit.beam(self,p,p+Vector3(.9,-6.4,.98),.28,steel,false,.39)
			Kit.beam(self,p+Vector3(0,0,2.47),p+Vector3(.9,-6.4,.98),.17,alloy)
			Kit.box(self,p+Vector3(0,-.22,0),Vector3(.48,.32,5.81),steel,.037)
		if index % 3 == 0:
			Kit.box(self,at+Vector3(3.05,.71,0),Vector3(.17,1.32,.22),alloy,.022,true)
			Kit.box(self,at+Vector3(3.05,1.40,0),Vector3(.26,.21,.39),pale,.026)
			Signs.plate(self,at+Vector3(3.05,1.40,.218),"step",.21)
	Kit.pad(self,Vector3(14.75,Layout.PIT,1),Vector2(2.25,5.0),plate)

func _basin() -> void:
	# Raised metallic spine, bordered by exposed aggregate rather than uniform paving.
	Kit.pad(self,Vector3(0,Layout.PIT,-.8),Vector2(27.0,66.4),plate,.29)
	Kit.pad(self,Vector3(0,Layout.PIT,33.40),Vector2(6.20,2.54),plate,.24)
	Kit.pad(self,Vector3(-18.25,Layout.PIT,-24.65),Vector2(9.50,6.0),plate,.26)
	Kit.pad(self,Vector3(-19.92,Layout.PIT,-17.65),Vector2(4.2,6.18),plate,.23)
	for z in range(-32,33,4):
		Kit.box(self,Vector3(0,Layout.PIT+.009,z),Vector3(26.7,.014,.031),shade,.001)
		for x in [-12.95,12.95]:
			Kit.box(self,Vector3(x,Layout.PIT+.023,z+.61),Vector3(.073,.031,1.76),ochre,.002)
			if z % 8 == 0:
				Kit.box(self,Vector3(x,Layout.PIT+.075,z-.8),Vector3(.31,.15,.51),steel,.029)
				Kit.box(self,Vector3(x,Layout.PIT+.158,z-.8),Vector3(.22,.044,.35),frost,.011)
	# Lower freight guide, sunken piping, hard stop at the drill platform.
	for x in [-.98,.98]:
		Kit.box(self,Vector3(x,Layout.PIT+.021,10.2),Vector3(.10,.03,51.5),alloy,.009)
		Kit.box(self,Vector3(x,Layout.PIT+.012,-14.62),Vector3(.22,.023,3.3),ochre,.006)
	for z in range(-16,36,4):
		Kit.box(self,Vector3(0,Layout.PIT+.011,z),Vector3(2.20,.014,.065),shade,.002)
	for x in [-11.7,11.7]:
		Kit.pipe(self,Vector3(x,Layout.PIT-.38,-33),Vector3(x,Layout.PIT-.38,29),.17,steel)
		Kit.pipe(self,Vector3(x+.39,Layout.PIT-.33,-33),Vector3(x+.39,Layout.PIT-.33,29),.102,alloy)

func _dock_bypass() -> void:
	# Independent emergency walkway: a real walk-off connection, never a menu teleport.
	Kit.pad(self,Vector3(-13.14,Layout.MID,Layout.SHAFT_Z),Vector2(21.16,3.62),plate,.25)
	Kit.pad(self,Vector3(-22.06,Layout.MID,31.58),Vector2(3.38,8.24),plate,.24)
	Kit.pad(self,Vector3(-22.07,Layout.MID,26.52),Vector2(3.40,1.90),plate,.24)
	for x in [-23.64,-20.43]:
		Kit.box(self,Vector3(x,Layout.MID+1.025,32.12),Vector3(.12,.13,7.26),alloy,.02,true)
		for z in [29.02,32.37,35.36]:
			Kit.box(self,Vector3(x,Layout.MID+.45,z),Vector3(.13,.90,.13),steel,.021)
	for z in [35.77,39.19]:
		var span := 16.74 if z < Layout.SHAFT_Z else 20.67
		Kit.box(self,Vector3(-3.52-span*.5,Layout.MID+1.025,z),Vector3(span,.13,.135),alloy,.020,true)
		for x in range(-23,-3,3):
			Kit.box(self,Vector3(x,Layout.MID+.46,z),Vector3(.14,.92,.12),steel,.022)
			Kit.box(self,Vector3(x,Layout.MID+.04,z),Vector3(.43,.11,.27),steel,.025)
	for x in [-23.4,-17.1,-11.1,-5.0]:
		Kit.beam(self,Vector3(x,Layout.MID-.08,36.3),Vector3(x,Layout.PIT-.77,36.3),.25,steel)
		Kit.beam(self,Vector3(x,Layout.MID-.2,38.77),Vector3(x-2.7,Layout.PIT-.77,38.1),.17,steel)
		Kit.box(self,Vector3(x,Layout.MID+.05,38.97),Vector3(.24,.10,.20),frost,.023)
	Signs.plate(self,Vector3(-22.17,Layout.MID+1.45,39.09),"hab",.35,PI)

func _drill() -> void:
	var base := Vector3(-3.3,Layout.PIT,-29.4)
	for x in [-3.10,3.10]:
		for z in [-3.20,3.30]:
			var foot := base+Vector3(x,0,z)
			var top := base+Vector3(x*.56,24.45,z*.61)
			Kit.box(self,foot+Vector3.UP*.40,Vector3(1.20,.80,1.3),stone,.081,true)
			Kit.beam(self,foot+Vector3.UP*.38,top,.38,pale,true,.32)
			for level in range(3,24,3):
				var a := foot.lerp(top,float(level)/24.45)
				var b := a+Vector3(-signf(x)*(5.88-level*.104),2.86,0)
				Kit.beam(self,a,b,.13,alloy)
				Kit.beam(self,a,a+Vector3(0,0,-signf(z)*(6.1-level*.096)),.21,steel)
	for level in [3.65,9.52,16.4,24.15]:
		Kit.box(self,base+Vector3.UP*level,Vector3(6.87-level*.104,.31,6.90-level*.09),steel,.067)
		for x in [-1.94,1.94]:
			Kit.box(self,base+Vector3(x,level-.155,2.11),Vector3(.67,.14,.11),frost,.021)
	# The telescoping core assembly and shroud are independent nested volumes.
	Kit.pipe(self,base+Vector3.UP*.66,base+Vector3.UP*8.9,.43,alloy,36)
	Kit.pipe(self,base+Vector3.UP*4.35,base+Vector3.UP*16.37,.75,shade,40)
	for y in [1.03,3.13,4.3,7.9,10.1,12.6,15.3]:
		Kit.pipe(self,base+Vector3.UP*y,base+Vector3.UP*(y+.22),.86,alloy,32)
	Kit.pipe(self,base+Vector3.UP*16.41,base+Vector3.UP*22.9,.33,pale,24)
	Kit.box(self,base+Vector3.UP*2.01,Vector3(1.47,2.84,1.59),pale,.086,true)
	Kit.box(self,base+Vector3(.6,1.04,1.10),Vector3(1.6,.20,1.5),steel,.061)
	# An open-fronted data alcove; its geometry blocks the overhead crawler around the corner.
	Kit.pad(self,Vector3(5.29,Layout.PIT,-30.23),Vector2(7.14,6.26),plate,.32)
	Kit.box(self,Vector3(5.29,Layout.PIT+3.19,-30.23),Vector3(7.10,.30,6.45),pale,.061,true)
	Kit.box(self,Vector3(5.29,Layout.PIT+1.51,-33.46),Vector3(7.10,3.02,.33),steel,.066,true)
	Kit.box(self,Vector3(8.77,Layout.PIT+1.51,-30.75),Vector3(.32,3.02,5.45),pale,.044,true)
	Kit.box(self,Vector3(1.80,Layout.PIT+1.51,-31.37),Vector3(.34,3.02,4.25),pale,.041,true)
	for x in [2.15,8.48]:
		Kit.box(self,Vector3(x,Layout.PIT+1.53,-27.20),Vector3(.40,3.17,.43),steel,.052,true)
		Kit.box(self,Vector3(x,Layout.PIT+1.74,-26.976),Vector3(.17,2.35,.026),pale,.011)
	Kit.box(self,Vector3(5.30,Layout.PIT+3.17,-26.95),Vector3(6.65,.40,.48),pale,.072)
	Signs.plate(self,Vector3(5.30,Layout.PIT+3.21,-26.697),"record",.36)
	var tube_light := Kit.glow(Color(.86,.92,.97),3.45) if polish else frost
	for x in [2.9,7.65]:
		Kit.box(self,Vector3(x,Layout.PIT+2.95,-29.35),Vector3(.10,.09,2.71),tube_light,.017)
		var lamp_at := Vector3(x,Layout.PIT+2.70,-29.42)
		if polish and x > 5.0:
			# Key and fill instead of two unshadowed bulbs flattening the recorder and back wall.
			lamp_at.z += .72 # mount the key near the front of the strip, ahead of the cartridge
			var key := Kit.spot(self,lamp_at,Layout.RECORD+Vector3(0,-.23,.28),Color(.86,.92,.97),4.5,5.9,39)
			key.name = "RecorderKey"
			key.light_size = .17
			key.distance_fade_enabled = true
			key.distance_fade_shadow = 14.0
			key.distance_fade_begin = 18.0
			key.distance_fade_length = 7.0
		else:
			Kit.lamp(self,lamp_at,Color(.79,.87,.94),1.30 if polish else 1.85,5.9)
	for x in [2.56,3.47,4.38,5.29,6.20,7.11,8.02]:
		Kit.box(self,Vector3(x,Layout.PIT+1.67,-33.264),Vector3(.88,2.70,.12),alloy,.035)
		Kit.box(self,Vector3(x,Layout.PIT+.43,-33.197),Vector3(.70,.16,.031),shade,.008)
		for y in [.76,2.75]:
			Kit.pipe(self,Vector3(x+.33,Layout.PIT+y,-33.213),Vector3(x+.33,Layout.PIT+y,-33.178),.022,steel,8)
	for y in [2.41,2.57,2.72]:
		Kit.pipe(self,Vector3(2.41,Layout.PIT+y,-33.11),Vector3(8.3,Layout.PIT+y,-33.11),.039,steel,12)
	for z in [-28.15,-29.82,-31.46]:
		Kit.box(self,Vector3(8.594,Layout.PIT+1.44,z),Vector3(.087,2.54,1.61),alloy,.032)
		Kit.box(self,Vector3(8.538,Layout.PIT+2.38,z),Vector3(.049,.27,1.38),steel,.02)
		for i in 7:
			Kit.box(self,Vector3(8.508,Layout.PIT+2.38,z-.58+i*.19),Vector3(.029,.17,.053),shade,.005)
	var p := Layout.RECORD
	Kit.box(self,p+Vector3(0,-.62,-.34),Vector3(1.33,1.31,.62),steel,.066,true)
	Kit.box(self,p+Vector3(0,.02,-.38),Vector3(1.29,.27,.69),shade,.042,true)
	Kit.box(self,p+Vector3(0,.045,-.121),Vector3(.66,.26,.083),alloy,.035)
	record_cartridge = Node3D.new()
	record_cartridge.position = p
	add_child(record_cartridge)
	Kit.box(record_cartridge,Vector3.ZERO,Vector3(.43,.19,.13),pale,.033)
	Kit.box(record_cartridge,Vector3(0,-.036,.077),Vector3(.33,.03,.036),frost,.006)
	Kit.box(self,p+Vector3(0,-.51,-.006),Vector3(1.07,.69,.063),alloy,.034)
	Kit.box(self,p+Vector3(0,-.389,.031),Vector3(.58,.18,.039),shade,.014)
	Signs.plate(self,p+Vector3(-.306,.15,.044),"record",.210)
	for x in [-.42,.42]:
		Kit.box(self,p+Vector3(x,-.49,.043),Vector3(.08,.08,.043),ochre,.013)
		Kit.pipe(self,p+Vector3(x,-1.16,-.65),p+Vector3(x,-.23,-.65),.049,steel,14)
	for z in [-29.05,-31.33]:
		Kit.box(self,Vector3(3.02,Layout.PIT+.64,z),Vector3(1.09,1.28,.91),pale,.065,true)
		for i in 6:
			Kit.box(self,Vector3(3.03,Layout.PIT+.78+i*.051,z+.466),Vector3(.8,.028,.022),steel,.004)
	_drill_lighting(base)

func _drill_lighting(base: Vector3) -> void:
	var mouth := base + Vector3(.016,.88,1.26)
	if polish:
		Kit.pipe(self,mouth-Vector3.BACK*.54,mouth-Vector3.BACK*.12,.19,steel,20)
		Kit.pipe(self,mouth-Vector3.BACK*.14,mouth,.235,alloy,24)
		Kit.pipe(self,mouth-Vector3.BACK*.004,mouth+Vector3.BACK*.002,.164,shade,20)
		Lighting.drill_plume(self,mouth)
	# Fixed work lights, not a camera-following shaft or an extra unshadowed fill over the pit.
	var lens := Kit.glow(Color(.85,.91,.97),4.2) if polish else frost
	for x in [-5.93,-.76]:
		var at := Vector3(x,Layout.PIT+7.88,-27.04)
		var source := at + Vector3(0,-.17,.10)
		var wash := Vector3(x*.5,Layout.PIT,-17.8)
		if not polish:
			Kit.box(self,at,Vector3(.73,.28,.35),frost,.027)
			Kit.spot(self,source,wash,Color(.74,.83,.94),4.3,20,38)
			continue
		var crosses_plume: bool = x > -2.0
		var target := mouth + Vector3(-.22,-.34,2.15) if crosses_plume else wash
		if crosses_plume:
			# Hang below the lower catwalk so the deck itself cannot shadow the whole plume.
			source = base + Vector3(1.98,3.04,2.71)
			Kit.box(self,source+Vector3(.09,.37,-.04),Vector3(.29,.48,.28),steel,.03)
		var fixture := Kit.spot(self,source,target,Color(.85,.91,.97),5.8 if crosses_plume else 4.3,
			7.2 if crosses_plume else 20.0,29.0 if crosses_plume else 38.0)
		if crosses_plume:
			fixture.name = "ExhaustWorkLight"
			fixture.light_volumetric_fog_energy = 4.8
			fixture.distance_fade_enabled = true
			fixture.distance_fade_shadow = 24.0
			fixture.distance_fade_begin = 28.0
			fixture.distance_fade_length = 9.0
		Kit.box(fixture,Vector3(0,0,.24),Vector3(.73,.34,.32),steel,.045)
		Kit.box(fixture,Vector3(0,0,.106),Vector3(.64,.26,.068),shade,.024)
		Kit.box(fixture,Vector3(0,0,.067),Vector3(.55,.18,.034),lens,.016)

func _services() -> void:
	# Pump assemblies provide actual hard cover without filling the central freight path.
	for slot in [Vector3(-8.6,Layout.PIT,-7.0),Vector3(7.8,Layout.PIT,11.7),Vector3(-9.7,Layout.PIT,-19.5)]:
		Kit.box(self,slot+Vector3.UP*.20,Vector3(4.34,.40,3.11),stone,.064,true)
		Kit.box(self,slot+Vector3(0,1.14,.13),Vector3(3.96,1.64,2.48),pale,.12,true)
		for x in [-1.42,1.42]:
			Kit.box(self,slot+Vector3(x,1.22,1.43),Vector3(.32,1.55,.18),steel,.037)
		for i in 10:
			Kit.box(self,slot+Vector3(-1.08+i*.235,1.24,1.409),Vector3(.081,.88,.042),shade,.009)
		for z in [-.68,.70]:
			Kit.pipe(self,slot+Vector3(-1.52,2.01,z),slot+Vector3(1.52,2.01,z),.17,alloy,20)
			Kit.pipe(self,slot+Vector3(.88,2.01,z),slot+Vector3(1.15,2.01,z),.217,steel,20)
		Kit.box(self,slot+Vector3(1.59,.58,1.416),Vector3(.21,.067,.029),frost,.011)
		for i in 3:
			Kit.box(self,slot+Vector3(-1.79,.55+i*.08,1.405),Vector3(.16,.028,.024),ochre,.004)

func _sag_line(a: Vector3, b: Vector3, sag: float, radius: float, mat: Material) -> void:
	var last := a
	for i in range(1,33):
		var t := float(i)/32.0
		var next := a.lerp(b,t)-Vector3.UP*4.0*t*(1.0-t)*sag
		Kit.pipe(self,last,next,radius,mat,8)
		last = next
