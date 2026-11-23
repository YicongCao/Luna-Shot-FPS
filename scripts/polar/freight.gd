extends Node3D
## The ice core remains one physical object through all three freight stages.
const Kit = preload("res://scripts/polar/kit.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const Signs = preload("res://scripts/polar/signs.gd")
const HANDLE := Vector3(-1.62,1.28,1.416)
const RECEIVER := Vector3(2.67,1.25,45.10)
const CALL: Array[Vector3] = [Vector3(3.54,-15.75,32.53), Vector3(-3.69,-7.25,38.6), Vector3(3.23,1.25,42.92)]
const CRADLE := Vector3(-7.38,.42,53.40)
const PALE := Color(.70,.72,.73)
enum Cargo { AVAILABLE, TO_LIFT, ON_LIFT, TO_SHIP, STOWED }

var cargo: Cargo = Cargo.AVAILABLE
var dock := 0
var goal := -1
var unlocked := false
var lift: AnimatableBody3D
var crate: AnimatableBody3D
var crate_path: Array[Vector3] = []
var dock_lights: Array[MeshInstance3D] = []
var present_light := Kit.glow(Color(.53,.79,.87),1.85)
var locked_light := Kit.surface(Color(.26,.32,.35),.44,.55)
var motor_speed := 0.0
var hoist_drum: Node3D
var lift_departures := 0
var cargo_departures := 0

func _ready() -> void:
	var paint := Kit.surface(PALE,.19,.56)
	var steel := Kit.surface(Color(.26,.30,.34),.68,.43,1)
	var alloy := Kit.surface(Color(.49,.53,.57),.84,.36,1)
	var deck := Kit.surface(Color(.323,.363,.398),.28,.65,4)
	var black := Kit.surface(Color(.11,.132,.158),.27,.66)
	var hazard := Kit.surface(Color(.64,.50,.30),.12,.62)
	var ice := Kit.glow(Color(.64,.81,.94),1.25)
	var mid_z: float = Layout.SHAFT_Z
	for x in [-3.0,3.0]:
		for z in [mid_z-2.72,mid_z+2.62]:
			Kit.box(self,Vector3(x,-5.9,z),Vector3(.34,23.25,.41),paint,.042,true)
			Kit.box(self,Vector3(x*.92,-6.7,z),Vector3(.08,21.0,.29),alloy,.015)
			Kit.box(self,Vector3(x,Layout.PIT+.16,z),Vector3(.71,.31,.62),steel,.052,true)
			for y in [-15.5,-12.6,-9.7,-6.8,-3.9,-1.0,1.9,4.8]:
				Kit.box(self,Vector3(x,y,z),Vector3(.53,.13,.63),steel,.024)
		for y in [-15.7,-11.0,-5.55,-1.64,3.0]:
			# Leave the west mid-landing route open and the pit/top approach clear.
			Kit.beam(self,Vector3(x,y,mid_z-2.72),Vector3(x,y,mid_z+2.62),.16,steel)
		Kit.pipe(self,Vector3(x*1.075,-16.2,mid_z-2.82),Vector3(x*1.075,4.97,mid_z-2.82),.053,black)
	Kit.box(self,Vector3(0,5.39,mid_z),Vector3(6.36,.54,5.88),steel,.053)
	Kit.box(self,Vector3(0,5.67,mid_z),Vector3(3.08,.31,2.40),paint,.068)
	Kit.box(self,Vector3(0,4.69,mid_z+2.69),Vector3(5.96,.30,.47),paint,.055)
	Signs.plate(self,Vector3(0,4.69,mid_z+2.935),"lift",.37)
	for x in [-1.4,1.4]:
		Kit.pipe(self,Vector3(x,-16.46,mid_z-2.31),Vector3(x,5.10,mid_z-2.31),.030,black)
	Kit.box(self,Vector3(0,4.31,mid_z+2.44),Vector3(2.60,.121,.115),ice,.034)
	Kit.spot(self,Vector3(0,4.17,mid_z+2.36),Vector3(0,-6.0,mid_z+1.36),Color(.75,.85,.98),3.3,25,36)
	hoist_drum = Node3D.new()
	hoist_drum.position = Vector3(0,5.98,mid_z-.68)
	add_child(hoist_drum)
	Kit.pipe(hoist_drum,Vector3(-.88,0,0),Vector3(.88,0,0),.31,steel,28)
	for i in 15:
		var x := -.72+i*.103
		Kit.pipe(hoist_drum,Vector3(x,0,0),Vector3(x+.031,0,0),.327,alloy,24)
	for i in CALL.size():
		var p := CALL[i]
		_control(self,p,paint,steel,ice,"lift",i == 1)
		dock_lights.append(Kit.box(self,Vector3(2.73,Layout.DOCKS[i]+.58,mid_z+2.58),Vector3(.132,.061,.29),locked_light,.012))
	_control(self,RECEIVER,paint,steel,ice,"ice")
	for x in [.39,2.01]:
		Kit.box(self,Vector3(x,.015,43.59),Vector3(.053,.026,5.73),alloy,.008)
	for z in [46.82,48.24]:
		Kit.box(self,Vector3(-3.11,.016,z),Vector3(8.70,.027,.055),alloy,.008)
	for x in [-8.15,-6.62]:
		Kit.box(self,Vector3(x,.018,50.58),Vector3(.054,.027,5.61),alloy,.008)

	lift = AnimatableBody3D.new()
	lift.name = "LiftPlatform"
	lift.collision_mask = 0
	lift.sync_to_physics = false
	lift.position = Vector3(0,Layout.PIT,mid_z)
	add_child(lift)
	_shape(lift,Vector3(0,-.16,0),Vector3(5.14,.32,5.82))
	Kit.box(lift,Vector3(0,-.16,0),Vector3(5.14,.32,5.82),deck,.053)
	for x in [-2.32,2.32]:
		Kit.box(lift,Vector3(x,.019,0),Vector3(.118,.032,5.50),hazard,.008)
	for z in [-2.48,2.48]:
		Kit.box(lift,Vector3(0,.022,z),Vector3(4.88,.034,.14),hazard,.011)
		for x in [-2.36,2.36]:
			Kit.box(lift,Vector3(x,.42,z),Vector3(.165,.82,.18),steel,.028)
			Kit.box(lift,Vector3(x,.823,z),Vector3(.21,.082,.21),ice,.023)
	Kit.box(lift,Vector3(-1.62,.53,1.72),Vector3(.33,1.067,.34),steel,.034)
	Kit.box(lift,Vector3(-1.62,1.18,1.64),Vector3(.52,.33,.33),paint,.055)
	Signs.plate(lift,Vector3(-1.62,1.27,1.461),"lift",.21,PI)

	crate = AnimatableBody3D.new()
	crate.name = "IceCoreCrate"
	crate.collision_mask = 0
	crate.sync_to_physics = false
	crate.position = context_core_floor()
	add_child(crate)
	_shape(crate,Vector3(0,.63,0),Vector3(1.44,1.24,1.55))
	Kit.box(crate,Vector3(0,.146,0),Vector3(1.48,.26,1.54),steel,.046)
	Kit.box(crate,Vector3(0,.71,0),Vector3(1.33,.95,1.42),paint,.069)
	Kit.box(crate,Vector3(0,1.207,0),Vector3(1.35,.126,1.45),alloy,.042)
	for x in [-.62,.62]:
		Kit.box(crate,Vector3(x,.70,0),Vector3(.16,1.06,1.47),steel,.029)
		for z in [-.56,.56]:
			Kit.pipe(crate,Vector3(x-.075,.164,z),Vector3(x+.075,.164,z),.162,black,16)
	for z in [-.723,.723]:
		Kit.box(crate,Vector3(0,.95,z),Vector3(.66,.055,.022),ice,.01)
		Signs.plate(crate,Vector3(0,.67,z*1.014),"ice",.30,0.0 if z > 0 else PI)
	_update_indicators()

func _shape(body: CollisionObject3D, at: Vector3, size: Vector3) -> void:
	var part := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	part.position = at
	part.shape = shape
	body.add_child(part)

func _control(root: Node3D, at: Vector3, pale: Material, steel: Material, ice: Material, icon: String, side: bool = false) -> void:
	var back := Vector3(.18,0,0) if side else Vector3(0,0,-.18)
	var angle := -PI*.5 if side else 0.0
	Kit.box(root,at+back-Vector3.UP*.713,Vector3(.34,1.074,.30),steel,.049,true,angle)
	Kit.box(root,at+back,Vector3(.51,.48,.29),pale,.054,true,angle)
	Kit.box(root,at+Vector3.UP*.13,Vector3(.33,.037,.025),ice,.004,false,angle)
	Signs.plate(root,at,icon,.21,angle)

func context_core_floor() -> Vector3:
	return Vector3(Layout.CORE.x,Layout.PIT,Layout.CORE.z)

func set_unlocked(value: bool) -> void:
	unlocked = value
	_update_indicators()

func _update_indicators() -> void:
	for i in dock_lights.size():
		dock_lights[i].material_override = present_light if unlocked and dock == i and goal == -1 else locked_light

func can_call(index: int) -> bool:
	return unlocked and goal == -1 and cargo not in [Cargo.TO_LIFT,Cargo.TO_SHIP] and dock != index

func call_dock(index: int) -> bool:
	if not can_call(index): return false
	_go(index)
	return true

func _go(index: int) -> void:
	goal = index
	motor_speed = 0.0
	lift_departures += 1
	_update_indicators()

func advance() -> bool:
	return call_dock(dock+1 if dock < 2 else 0)

func receive_core() -> bool:
	if not unlocked or cargo != Cargo.AVAILABLE: return false
	cargo = Cargo.TO_LIFT
	cargo_departures += 1
	if goal == -1 and dock != 0:
		_go(0)
	return true

func can_store() -> bool:
	return unlocked and dock == 2 and goal == -1 and cargo == Cargo.ON_LIFT

func store_core() -> bool:
	if not can_store(): return false
	cargo = Cargo.TO_SHIP
	crate.reparent(self,true)
	# A short rise finishes before the crate's front face reaches the hardpoint lip.
	crate_path = [Vector3(Layout.CORE.x,0,47.53),Vector3(CRADLE.x,0,47.53),Vector3(CRADLE.x,0,50.49),Vector3(CRADLE.x,CRADLE.y,51.38),CRADLE]
	return true

func tick(delta: float) -> void:
	if goal != -1:
		var height: float = Layout.DOCKS[goal]
		var distance := absf(height-lift.position.y)
		motor_speed = move_toward(motor_speed,minf(3.15,sqrt(2.0*2.8*distance)),2.8*delta)
		var gap := move_toward(lift.position.y,height,maxf(motor_speed,.15)*delta)
		hoist_drum.rotation.x += (gap-lift.position.y)*2.7
		lift.position.y = gap
		if is_equal_approx(gap,height):
			dock = goal
			goal = -1
			motor_speed = 0.0
			_update_indicators()
			if cargo == Cargo.TO_LIFT and dock != 0: _go(0)
	if cargo == Cargo.TO_LIFT:
		# Stop at the shaft lip until the moving deck is actually in position.
		var next_z := Layout.SHAFT_Z+.70 if dock == 0 and goal == -1 else 33.4
		crate.position.z = move_toward(crate.position.z,next_z,6.7*delta)
		if is_equal_approx(crate.position.z,Layout.SHAFT_Z+.70):
			crate.reparent(lift,true)
			cargo = Cargo.ON_LIFT
			crate_path.clear()
	elif cargo == Cargo.TO_SHIP:
		var target: Vector3 = crate_path[0]
		crate.position = crate.position.move_toward(target,3.45*delta)
		if crate.position.is_equal_approx(target):
			crate_path.pop_front()
			if crate_path.is_empty(): cargo = Cargo.STOWED

func on_lift(point: Vector3) -> bool:
	var p := lift.to_local(point)
	return absf(p.y) < .40 and absf(p.x) < 2.50 and absf(p.z) < 2.79

func reset() -> void:
	if crate.get_parent() != self: crate.reparent(self,true)
	cargo = Cargo.AVAILABLE
	crate_path.clear()
	crate.position = context_core_floor()
	dock = 0
	goal = -1
	motor_speed = 0.0
	lift.position.y = Layout.PIT
	hoist_drum.rotation.x = 0.0
	lift_departures = 0
	cargo_departures = 0
	set_unlocked(false)
