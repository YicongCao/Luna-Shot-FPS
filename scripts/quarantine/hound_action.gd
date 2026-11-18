extends RefCounted
## Presentation only. No rays, target lookup, root motion or damage here.
const STRIKE_TIME := .32
const FLINCH_TIME := .42
var head: Node3D
var aim := Vector3.ZERO
var strike_age := STRIKE_TIME
var impact_age := FLINCH_TIME
var incoming := Vector3.ZERO
var plate: MeshInstance3D
var plate_rest: Transform3D
var folded := false

func _init(pivot: Node3D) -> void:
	head = pivot

func posture(delta: float, patrol_clock: float, pursuing: bool, local_sight: Vector3) -> void:
	# Hold briefly at each side of a scan. Only the existing visible chase supplies a gaze.
	var yaw := .38 * clampf(sin(patrol_clock*1.62)*1.35,-1.,1.)
	var pitch := -.14 + .085*cos(patrol_clock*1.62*2.)
	if pursuing:
		yaw = clampf(atan2(-local_sight.x,-local_sight.z),-.46,.46)
		pitch = clampf(atan2(local_sight.y,Vector2(local_sight.x,local_sight.z).length()),-.15,.24)
	aim = aim.lerp(Vector3(pitch,yaw,0),1.-exp(-delta*8.))

func strike() -> void:
	strike_age = 0.

func release_plate() -> void:
	if is_instance_valid(plate): plate.transform = plate_rest
	plate = null

func impact(panel: MeshInstance3D, outward: Vector3, dead: bool) -> void:
	release_plate()
	incoming = -outward.normalized()
	impact_age = 0.
	if not dead and panel != null:
		plate = panel
		plate_rest = panel.transform

func tick(dt: float) -> void:
	strike_age = minf(STRIKE_TIME,strike_age+dt)
	impact_age = minf(FLINCH_TIME,impact_age+dt)
	var t := impact_age/FLINCH_TIME
	# Fast deflection, one damped overshoot, then exact reseating on the captured mount.
	var kick := sin(t*TAU)*exp(-4.*t)*2.25 if t<1. else 0.
	if is_instance_valid(plate):
		if t>=1.:
			release_plate()
		else:
			plate.position = plate_rest.origin + incoming*.047*kick
			plate.basis = Basis(Vector3.FORWARD,signf(plate_rest.origin.x)*.23*kick)*plate_rest.basis
	if folded: aim = aim.lerp(Vector3(-.56,0,0),1.-exp(-dt*12.))
	var bite := 0. if folded else sin(PI*sqrt(strike_age/STRIKE_TIME))
	head.rotation = aim + Vector3(-.55*bite+incoming.z*.28*kick,-incoming.x*.36*kick,-incoming.x*.18*kick)
