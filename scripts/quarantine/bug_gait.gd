extends RefCounted
## Cosmetic tripod walk. Targets are world-space sole contacts, not body offsets.
## The character capsule still owns navigation, collisions, speed and damage.
const STRIDE: float = .135
const STEP_SECONDS: float = .115
const LIFT: float = .105
const PAD_HEIGHT: float = .025

class Link:
	var hip: Node3D
	var upper: Node3D
	var lower: Node3D
	var pad: Node3D
	var sleeve: MeshInstance3D
	var piston: MeshInstance3D
	var knee: Vector3
	var foot: Vector3
	var sole_rest: Vector3
	var last_home: Vector3
	var start: Transform3D
	var goal: Transform3D
	var supported := false
	var reach_ok := true

var links: Array[Link] = []
var planted: Array[bool] = []
var group := 0
var swinging := false
var elapsed := 0.
var initialized := false
var previous_body: Vector3
var support_clock := 0.

func bind_leg(leg: Node3D, knee: Vector3, foot: Vector3) -> void:
	var l := Link.new()
	l.hip = leg
	l.upper = leg.get_node("Upper")
	l.lower = leg.get_node("Lower")
	l.pad = leg.get_node("Pad")
	l.sleeve = leg.get_node("ActuatorSleeve")
	l.piston = leg.get_node("ActuatorRod")
	l.knee = knee
	l.foot = foot
	l.sole_rest = l.pad.position
	links.append(l)
	planted.append(false)

func place(bug: CharacterBody3D, l: Link, p: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(p+Vector3.UP*.48,p-Vector3.UP*.46,1,[bug.get_rid()])
	var hit := bug.get_world_3d().direct_space_state.intersect_ray(q)
	l.supported = not hit.is_empty() and hit.normal.y >= .68
	var up: Vector3 = hit.normal if l.supported else Vector3.UP
	var z := bug.global_basis.z.slide(up).normalized()
	l.goal = Transform3D(Basis(up.cross(z),up,z),hit.position if l.supported else l.hip.to_global(l.sole_rest))

func update(bug: CharacterBody3D, dt: float) -> void:
	var reset := not initialized or previous_body.distance_squared_to(bug.global_position) > .8*.8
	previous_body = bug.global_position
	if reset:
		swinging = false
		group = 0
		initialized = true
	support_clock -= dt
	var recheck := support_clock <= 0.
	if recheck: support_clock = .10
	var error := [0.,0.]
	for i in links.size():
		var l := links[i]
		var home := l.hip.to_global(l.sole_rest)
		if reset:
			place(bug,l,home)
			l.last_home = home
			l.start = l.goal
		elif recheck and l.supported:
			# Keep stance orientation as well as position. Reject a stale foothold if
			# the floor disappears or the body has fallen clear of its former level.
			var p := l.goal.origin
			var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*.06,p-Vector3.UP*.06,1,[bug.get_rid()])
			l.supported = absf(home.y-p.y)<.46 and not bug.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		if l.supported:
			var gap := l.goal.origin-home
			error[i%2] = maxf(error[i%2],Vector2(gap.x,gap.z).length())
		else:
			# Retract over void rather than anchoring to an imaginary plane.
			error[i%2] = maxf(error[i%2],STRIDE+.001)
	if not swinging and not reset and maxf(error[0],error[1])>STRIDE:
		if error[group] <= STRIDE: group = 1-group
		swinging = true
		elapsed = 0.
		for i in range(group,links.size(),2):
			var l := links[i]
			var home := l.hip.to_global(l.sole_rest)
			# Includes real translation and yaw; blocked movement doesn't wind up a gait clock.
			var lead := ((home-l.last_home)/maxf(dt,.001)*STEP_SECONDS*1.1).limit_length(.24)
			l.start = l.pad.global_transform
			place(bug,l,home+lead)
	elapsed += dt
	var t := clampf(elapsed/STEP_SECONDS,0.,1.)
	for i in links.size():
		var l := links[i]
		var in_air := swinging and i%2==group and t<1.
		var target := l.goal
		if not l.supported:
			target = Transform3D(bug.global_basis,l.hip.to_global(l.sole_rest+Vector3.UP*.055))
		if in_air:
			target = l.start.interpolate_with(target,smoothstep(0.,1.,t))
			if l.supported: target.origin.y += 4.*t*(1.-t)*LIFT
		solve(l,target)
		planted[i] = not in_air and l.supported and l.reach_ok
		l.last_home = l.hip.to_global(l.sole_rest)
	if swinging and t>=1.:
		swinging = false
		group = 1-group

func solve(l: Link, sole: Transform3D) -> void:
	var ankle := l.hip.to_local(sole.origin+sole.basis.y*PAD_HEIGHT)
	var d := ankle.normalized()
	if d.is_zero_approx(): d = Vector3.DOWN
	var a := l.knee.length()
	var b := (l.foot-l.knee).length()
	var r := clampf(ankle.length(),absf(a-b)+.001,a+b-.001)
	l.reach_ok = absf(r-ankle.length()) < .001
	var along := (r*r+a*a-b*b)/(2.*r)
	var pole := (Quaternion(l.foot.normalized(),d)*l.knee).slide(d).normalized()
	var knee := d*along + pole*sqrt(maxf(0.,a*a-along*along))
	ankle = d*r
	l.upper.quaternion = Quaternion(l.knee.normalized(),knee.normalized())
	l.lower.position = knee
	l.lower.quaternion = Quaternion((l.foot-l.knee).normalized(),(ankle-knee).normalized())
	l.pad.global_transform = Transform3D(sole.basis,l.hip.to_global(ankle)-sole.basis.y*PAD_HEIGHT)
	var origin := l.upper.transform*(l.knee*.18+Vector3(0,-.05,.06))
	var end := l.lower.transform*((l.foot-l.knee)*.35+Vector3(0,0,.06))
	var axis := (end-origin).normalized()
	var shaft_length: float = l.sleeve.mesh.height
	l.sleeve.position = origin+axis*shaft_length*.5
	l.sleeve.quaternion = Quaternion(Vector3.UP,axis)
	var exposed := maxf(.002,origin.distance_to(end)-shaft_length+.008)
	l.piston.position = end-axis*exposed*.5
	l.piston.quaternion = l.sleeve.quaternion
	l.piston.scale.y = exposed/l.piston.mesh.height
