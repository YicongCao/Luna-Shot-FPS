extends RefCounted
## The shell, collision and pressure cue use the same deck sections. Locks are parked open.

const Kit = preload("res://scripts/polar/kit.gd")

const ENTRY := Vector3(-27.0, 0.0, 51.0)
const UPPER_KNEE := Vector3(-27.0, 0.0, 44.0)
# Land before the dock so its full width is level, not halfway up the ramp.
const ROOM_START := Vector3(-27.0, -8.5, 29.2)
const ROOM_END := Vector3(-27.0, -8.5, 17.0)
const LOWER_KNEE := Vector3(-21.0, -17.0, -10.0)
const EXIT := Vector3(-21.0, -17.0, -24.0)
const SUPPLY_MOUNT := Vector3(-28.9, -7.15, 22.0)

const HALL_HALF := 2.15
const ROOM_HALF := 2.83
const HALL_HEIGHT := 3.08
const ROOM_HEIGHT := 3.39
const WALL := 0.32
const ROOF := 0.26
const DOCK_X := -24.0
const DOCK_Z := 27.0
const DOCK_HALF := 1.55
const LOCK_HEIGHT := 2.62
const UPPER_SEAL := 48.35
const LOWER_SEAL := -21.35


static func build(root: Node3D) -> void:
	var wing := Wing.new(root)
	wing.assemble()


static func pressurized(point: Vector3) -> bool:
	if point.z > UPPER_SEAL or point.z < LOWER_SEAL:
		return false
	var deck := UPPER_KNEE
	var half_width := HALL_HALF
	var height := HALL_HEIGHT
	if point.z <= LOWER_KNEE.z:
		deck = LOWER_KNEE
	elif point.z < ROOM_END.z:
		deck = ROOM_END.lerp(LOWER_KNEE, inverse_lerp(ROOM_END.z, LOWER_KNEE.z, point.z))
	elif point.z <= ROOM_START.z:
		deck = ROOM_START
		half_width = ROOM_HALF
		height = ROOM_HEIGHT
	elif point.z < UPPER_KNEE.z:
		deck = UPPER_KNEE.lerp(ROOM_START, inverse_lerp(UPPER_KNEE.z, ROOM_START.z, point.z))
	var east := deck.x + half_width
	if half_width == ROOM_HALF and absf(point.z - DOCK_Z) < DOCK_HALF:
		east = DOCK_X
	return (point.x >= deck.x - half_width and point.x <= east
		and point.y >= deck.y - 0.08 and point.y <= deck.y + height)


class Wing:
	const FACE_ORDER = [
		[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3],
		[1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2],
	]
	const LIGHT_COLOR := Color(1.0, 0.945, 0.865)

	var root: Node3D
	var section: Node3D
	var hull: StaticBody3D
	var glazing: StaticBody3D
	var batches: Dictionary = {}

	var jacket := Kit.surface(Color(0.53, 0.575, 0.61), 0.36, 0.52)
	var panel := Kit.surface(Color(0.66, 0.695, 0.715), 0.27, 0.53)
	var rib := Kit.surface(Color(0.22, 0.265, 0.29), 0.63, 0.43, 1)
	var shell := Kit.surface(Color(0.19, 0.22, 0.25), 0.41, 0.56)
	var lining := Kit.surface(Color(0.64, 0.645, 0.61), 0.18, 0.62)
	var tread := Kit.surface(Color(0.26, 0.30, 0.315), 0.34, 0.70, 4)
	var gasket := Kit.surface(Color(0.085, 0.10, 0.11), 0.06, 0.79, 2)
	var rail := Kit.surface(Color(0.44, 0.49, 0.51), 0.67, 0.35, 1)
	var seat := Kit.surface(Color(0.255, 0.32, 0.315), 0.02, 0.80, 2)
	var stripe := Kit.surface(Color(0.62, 0.49, 0.285), 0.07, 0.71)
	var diffuser := Kit.glow(LIGHT_COLOR, 1.25)
	var dock_light := Kit.glow(Color(0.61, 0.76, 0.84), 0.85)
	var display := Kit.glow(Color(0.46, 0.77, 0.72), 0.68)
	var glass := StandardMaterial3D.new()

	func _init(parent: Node3D) -> void:
		root = _node(parent, "PolarHabitation")
		hull = _body("HabitatHull")
		glazing = _body("HabitatGlazing")
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color = Color(0.59, 0.71, 0.76, 0.17)
		glass.metallic = 0.20
		glass.roughness = 0.18
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		glass.disable_receive_shadows = true

	func assemble() -> void:
		_run("RimVestibule", ENTRY, UPPER_KNEE, 2, [1])
		_run("UpperInclinedGallery", UPPER_KNEE, ROOM_START, 4, [0, 1, 3])
		_room()
		_run("LowerInclinedGallery", ROOM_END, LOWER_KNEE, 7, [0, 2, 3, 5, 6])
		_run("PitVestibule", LOWER_KNEE, EXIT, 4, [0, 1])
		section = _node(root, "PressureBulkheads")
		_lock(ENTRY, -1.0)
		_lock(Vector3(ENTRY.x, ENTRY.y, UPPER_SEAL), -1.0)
		_lock(Vector3(EXIT.x, EXIT.y, LOWER_SEAL), 1.0)
		_lock(EXIT, 1.0)
		section = _node(root, "PierBents")
		_pier(UPPER_KNEE, 1.66, -9.2)
		_pier(UPPER_KNEE.lerp(ROOM_START, 0.50), 1.66, -19.65)
		_pier(ROOM_START.lerp(ROOM_END, 0.10), 2.30, -19.65)
		_pier(ROOM_START.lerp(ROOM_END, 0.86), 2.30, -19.65)
		_pier(ROOM_END.lerp(LOWER_KNEE, 0.34), 1.66, -19.65)
		_pier(ROOM_END.lerp(LOWER_KNEE, 0.73), 1.66, -19.65)
		_pier(LOWER_KNEE.lerp(EXIT, 0.29), 1.66, -19.65)
		_pier(LOWER_KNEE.lerp(EXIT, 0.84), 1.66, -19.65)

	func _run(label: String, a: Vector3, b: Vector3, count: int, view_bays: Array[int]) -> void:
		section = _node(root, label)
		_deck(a, b, HALL_HALF, HALL_HEIGHT)
		for i in count:
			var start := a.lerp(b, float(i) / count)
			var end := a.lerp(b, float(i + 1) / count)
			_wall(start, end, -1.0, HALL_HALF, HALL_HEIGHT)
			if i in view_bays:
				_window(start, end, HALL_HALF, HALL_HEIGHT)
			else:
				_wall(start, end, 1.0, HALL_HALF, HALL_HEIGHT)
			_ring(start, HALL_HALF, HALL_HEIGHT)
			_walk_trim(start, end, HALL_HALF)
			_practical(start, end, HALL_HEIGHT, -0.39 if i % 2 == 0 else 0.39)
		_flush()

	func _room() -> void:
		section = _node(root, "PressurizedSupplyDeck")
		_deck(ROOM_START, ROOM_END, ROOM_HALF, ROOM_HEIGHT)
		var before_dock := Vector3(ROOM_START.x, ROOM_START.y, DOCK_Z + DOCK_HALF)
		var after_dock := Vector3(ROOM_START.x, ROOM_START.y, DOCK_Z - DOCK_HALF)
		var view_joint := Vector3(ROOM_START.x, ROOM_START.y, 21.25)
		_wall(ROOM_START, before_dock, 1.0, ROOM_HALF, ROOM_HEIGHT)
		_wall_band(before_dock, after_dock, 1.0, ROOM_HALF, LOCK_HEIGHT, ROOM_HEIGHT)
		_window(after_dock, view_joint, ROOM_HALF, ROOM_HEIGHT)
		_window(view_joint, ROOM_END, ROOM_HALF, ROOM_HEIGHT)
		for i in 3:
			var a := ROOM_START.lerp(ROOM_END, float(i) / 3.0)
			var b := ROOM_START.lerp(ROOM_END, float(i + 1) / 3.0)
			_wall(a, b, -1.0, ROOM_HALF, ROOM_HEIGHT)
			_walk_trim(a, b, ROOM_HALF, false)
			_practical(a, b, ROOM_HEIGHT, -0.80)
		_shoulder(ROOM_START)
		_shoulder(ROOM_END)
		_ring(view_joint, ROOM_HALF, ROOM_HEIGHT)
		_dock(before_dock, after_dock)
		_supply_furnishings()
		_flush()

	func _deck(a: Vector3, b: Vector3, width: float, height: float) -> void:
		var edge := width + WALL
		_prism(a, b, Vector2(-edge, -0.28), Vector2(edge, 0.0), tread, hull)
		_prism(a, b, Vector2(-edge, height), Vector2(edge, height + ROOF), shell, hull)
		_prism(a, b, Vector2(-width, height - 0.035), Vector2(width, height), lining)
		for side: float in [-1.0, 1.0]:
			_side_strip(a, b, side, width + 0.08, edge, -0.47, -0.25, rib)
			_side_strip(a, b, side, 0.11, edge + 0.035, height + ROOF - 0.015, height + ROOF + 0.065, panel)
			_side_strip(a, b, side, edge - 0.075, edge + 0.075, height + 0.10, height + ROOF + 0.095, jacket)
		Kit.pipe(section, a + Vector3(-width + 0.27, height - 0.18, 0),
			b + Vector3(-width + 0.27, height - 0.18, 0), 0.048, rail, 10)

	func _wall(a: Vector3, b: Vector3, side: float, width: float, height: float) -> void:
		_side_strip(a, b, side, width, width + WALL, 0.0, height, shell, hull)
		# The protective skin has seams; the hull and interior fire lining behind it do not.
		var skew := minf(0.037 / (a.z - b.z), 0.13)
		var start := a.lerp(b, skew)
		var end := b.lerp(a, skew)
		_side_strip(start, end, side, width + WALL, width + WALL + 0.054, 0.21, height - 0.17, jacket)
		_side_strip(start, end, side, width - 0.052, width + 0.008, 0.46, height - 0.20, lining)
		_side_strip(start, end, side, width - 0.075, width + 0.018, 0.075, 0.38, rib)
		_side_strip(start, end, side, width + WALL + 0.04, width + WALL + 0.073, 0.26, 0.65, rib)

	func _wall_band(a: Vector3, b: Vector3, side: float, width: float, low: float, high: float) -> void:
		_side_strip(a, b, side, width, width + WALL, low, high, shell, hull)
		_side_strip(a, b, side, width + WALL - 0.01, width + WALL + 0.044, low + 0.042, high - 0.042, panel)
		_side_strip(a, b, side, width - 0.040, width + 0.01, low + 0.060, high - 0.045, lining)

	func _window(a: Vector3, b: Vector3, width: float, height: float) -> void:
		const SILL := 0.91
		const HEAD := 2.48
		var reveal := 0.41 / (a.z - b.z)
		var start := a.lerp(b, reveal)
		var end := b.lerp(a, reveal)
		_wall(a, start, 1.0, width, height)
		_wall(end, b, 1.0, width, height)
		_wall_band(start, end, 1.0, width, 0.0, SILL)
		_wall_band(start, end, 1.0, width, HEAD, height)
		# The glazing has an independent architecture collider; the transparent face does not cast shadows.
		var x := width + WALL * 0.5
		_prism(start, end, Vector2(x - 0.063, SILL), Vector2(x + 0.063, HEAD), null, glazing)
		var p := start + Vector3(x, SILL, 0)
		var q := end + Vector3(x, SILL, 0)
		_pane(p, p + Vector3.UP * (HEAD - SILL), q + Vector3.UP * (HEAD - SILL), q)
		for y: float in [SILL, HEAD]:
			_prism(start, end, Vector2(width - 0.125, y - 0.054), Vector2(width + WALL + 0.105, y + 0.054), rib)
			_prism(start, end, Vector2(x + 0.035, y - 0.067), Vector2(x + 0.055, y + 0.067), gasket)
		for u: float in [reveal, 1.0 - reveal]:
			var left := a.lerp(b, u - 0.06 / (a.z - b.z))
			var right := a.lerp(b, u + 0.06 / (a.z - b.z))
			_prism(left, right, Vector2(width - 0.08, SILL - 0.054), Vector2(width + WALL + 0.105, HEAD + 0.054), rib)
			for y: float in [SILL + 0.17, HEAD - 0.17]:
				Kit.box(section, left.lerp(right, 0.5) + Vector3(width + WALL + 0.11, y, 0), Vector3(0.038, 0.066, 0.062), rail, 0.008)

	func _ring(at: Vector3, width: float, height: float) -> void:
		for side: float in [-1.0, 1.0]:
			Kit.box(section, at + Vector3(side * (width + WALL + 0.028), height * 0.5 - 0.05, 0),
				Vector3(0.25, height + 0.76, 0.16), rib, 0.025)
		Kit.box(section, at + Vector3(0, height + ROOF + 0.04, 0), Vector3(2.0 * (width + WALL + 0.11), 0.19, 0.16), rib)
		Kit.box(section, at + Vector3(0, height - 0.05, 0), Vector3(2.0 * width, 0.13, 0.16), rib)

	func _walk_trim(a: Vector3, b: Vector3, width: float, grab_rail: bool = true) -> void:
		var lip := a.lerp(b, 0.037 / (a.z - b.z))
		_prism(a, lip, Vector2(-width + 0.15, 0.002), Vector2(width - 0.15, 0.009), rib)
		for side: float in [-1.0, 1.0]:
			if not grab_rail:
				continue
			_side_strip(a, b, side, width - 0.31, width - 0.27, 0.003, 0.011, rail)
			var offset := Vector3(side * (width - 0.18), 0.81, 0)
			Kit.pipe(section, a.lerp(b, 0.09) + offset, a.lerp(b, 0.91) + offset, 0.043, rail, 10)
			for t: float in [0.14, 0.86]:
				Kit.box(section, a.lerp(b, t) + offset + Vector3(side * 0.09, -0.015, 0), Vector3(0.23, 0.08, 0.085), rib, 0.014)

	func _practical(a: Vector3, b: Vector3, height: float, x: float) -> void:
		var extent := 0.59 / (a.z - b.z)
		var start := a.lerp(b, 0.5 - extent)
		var end := a.lerp(b, 0.5 + extent)
		_prism(start, end, Vector2(x - 0.215, height - 0.17), Vector2(x + 0.215, height - 0.025), rib)
		_prism(start.lerp(end, 0.075), end.lerp(start, 0.075),
			Vector2(x - 0.146, height - 0.194), Vector2(x + 0.146, height - 0.159), diffuser)
		var spot := SpotLight3D.new()
		spot.position = a.lerp(b, 0.5) + Vector3(x, height - 0.23, 0)
		spot.rotation.x = -PI * 0.5
		spot.light_color = LIGHT_COLOR
		spot.light_energy = 6.2
		spot.spot_range = 4.15
		spot.spot_angle = 43.0
		spot.spot_attenuation = 1.35
		spot.light_volumetric_fog_energy = 0.0
		section.add_child(spot)

	func _shoulder(at: Vector3) -> void:
		var a := at + Vector3(0, 0, 0.125)
		var b := at - Vector3(0, 0, 0.125)
		for side: float in [-1.0, 1.0]:
			_side_strip(a, b, side, HALL_HALF, ROOM_HALF + WALL, 0.0, ROOM_HEIGHT, rib, hull)
		_prism(a, b, Vector2(-ROOM_HALF - WALL, HALL_HEIGHT), Vector2(ROOM_HALF + WALL, ROOM_HEIGHT + ROOF), jacket, hull)

	func _dock(a: Vector3, b: Vector3) -> void:
		# The landing toe overlaps the bypass footprint; the wall opening is 3.10 m clear in Z.
		var x_toe := -23.72 - ROOM_START.x
		_prism(a, b, Vector2(ROOM_HALF, -0.23), Vector2(x_toe, 0.0), tread, hull)
		for side: float in [-1.0, 1.0]:
			var z := DOCK_Z + side * (DOCK_HALF + 0.093)
			Kit.box(section, Vector3(DOCK_X, ROOM_START.y + 1.31, z), Vector3(0.67, LOCK_HEIGHT, 0.18), rib, 0.020, true)
			Kit.box(section, Vector3(DOCK_X - 0.352, ROOM_START.y + 1.88, z), Vector3(0.034, 0.38, 0.066), dock_light, 0.009)
		Kit.box(section, Vector3(DOCK_X, ROOM_START.y + LOCK_HEIGHT + 0.12, DOCK_Z), Vector3(0.70, 0.24, 3.48), rib, 0.034)
		_prism(a, b, Vector2(2.59, 0.004), Vector2(2.66, 0.010), stripe)

	func _lock(at: Vector3, inside: float) -> void:
		const APERTURE := 1.52
		var frame_z := at.z + inside * 0.14
		var span := HALL_HALF + WALL - APERTURE
		for side: float in [-1.0, 1.0]:
			var jamb_x := at.x + side * (APERTURE + span * 0.5)
			Kit.box(section, Vector3(jamb_x, at.y + LOCK_HEIGHT * 0.5, frame_z), Vector3(span, LOCK_HEIGHT, 0.27), rib, 0.040, true)
			# Only the steel edge of each parked sliding leaf is visible past the seal.
			Kit.box(section, Vector3(at.x + side * (APERTURE + 0.080), at.y + 1.32, frame_z), Vector3(0.133, 2.50, 0.135), rail, 0.015)
			Kit.box(section, Vector3(at.x + side * (APERTURE + 0.25), at.y + 1.81, frame_z - inside * 0.174), Vector3(0.13, 0.26, 0.055), gasket, 0.012)
			Kit.box(section, Vector3(at.x + side * (APERTURE + 0.25), at.y + 1.83, frame_z - inside * 0.209), Vector3(0.053, 0.11, 0.018), dock_light, 0.007)
		var top := HALL_HEIGHT + ROOF - LOCK_HEIGHT
		Kit.box(section, Vector3(at.x, at.y + LOCK_HEIGHT + top * 0.5, frame_z), Vector3(2.0 * (HALL_HALF + WALL), top, 0.27), rib, 0.032, true)
		Kit.box(section, Vector3(at.x, at.y + LOCK_HEIGHT + 0.05, frame_z - inside * 0.151), Vector3(2.0 * APERTURE, 0.095, 0.047), jacket, 0.018)
		for side: float in [-1.0, 1.0]:
			Kit.box(section, Vector3(at.x + side * 1.26, at.y + 0.006, frame_z + inside * 0.22), Vector3(0.32, 0.012, 0.068), stripe, 0.003)

	func _supply_furnishings() -> void:
		var p := SUPPLY_MOUNT
		# Everything at the mount is behind its query point; the clear aisle is to +X.
		Kit.box(section, p + Vector3(-0.57, -0.17, 0), Vector3(0.73, 2.25, 1.80), rib, 0.06, true)
		Kit.box(section, p + Vector3(-0.31, -0.27, 0.41), Vector3(0.35, 1.77, 0.70), lining, 0.034)
		Kit.box(section, p + Vector3(-0.28, -0.01, -0.30), Vector3(0.35, 1.08, 0.78), gasket, 0.045)
		Kit.box(section, p + Vector3(-0.126, 0.0, 0), Vector3(0.11, 0.34, 0.46), shell, 0.036)
		Kit.box(section, p + Vector3(-0.062, 0.0, 0), Vector3(0.014, 0.235, 0.348), gasket, 0.009)
		for i in 4:
			Kit.box(section, p + Vector3(-0.052, -0.019, -0.106 + 0.070 * i), Vector3(0.008, 0.095, 0.042), display, 0.003)
		for i in 2:
			var bay := p + Vector3(-0.146, -0.66, -0.46 + i * 0.28)
			Kit.pipe(section, bay - Vector3.UP * 0.25, bay + Vector3.UP * 0.25, 0.098, rail, 12)
			Kit.pipe(section, bay + Vector3.UP * 0.15, bay + Vector3.UP * 0.24, 0.101, gasket, 12)
		Kit.box(section, p + Vector3(-0.35, 0.75, 0), Vector3(0.63, 0.10, 1.85), jacket, 0.025)
		Kit.box(section, p + Vector3(-0.14, 0.69, 0), Vector3(0.16, 0.043, 1.55), diffuser, 0.009)
		Kit.lamp(section, p + Vector3(0.23, 0.58, 0), LIGHT_COLOR, 1.42, 2.5)
		var deck := ROOM_START.y
		# Recessed bench and cargo lockers stay on the service side, out of the dock turning area.
		Kit.box(section, Vector3(-29.39, deck + 0.24, 24.39), Vector3(0.83, 0.48, 2.02), rib, 0.038, true)
		for i in 2:
			var z := 23.91 + i * 0.96
			Kit.box(section, Vector3(-29.36, deck + 0.49, z), Vector3(0.76, 0.13, 0.89), seat, 0.050)
			Kit.box(section, Vector3(-29.74, deck + 0.83, z), Vector3(0.20, 0.58, 0.89), seat, 0.038)
		Kit.box(section, Vector3(-29.43, deck + 0.91, 19.53), Vector3(0.73, 1.82, 1.75), jacket, 0.035, true)
		for i in 3:
			var z := 18.98 + i * 0.55
			Kit.box(section, Vector3(-29.047, deck + 0.94, z), Vector3(0.06, 1.58, 0.506), lining, 0.022)
			Kit.box(section, Vector3(-28.995, deck + 1.07, z - 0.16), Vector3(0.045, 0.19, 0.073), gasket, 0.009)

	func _pier(at: Vector3, half_span: float, ground: float) -> void:
		var cap := at.y - 0.46
		var height := cap - ground
		for side: float in [-1.0, 1.0]:
			var x := at.x + side * half_span
			Kit.box(section, Vector3(x, ground + 0.27, at.z), Vector3(1.24, 0.74, 1.40), jacket, 0.056, true)
			Kit.box(section, Vector3(x, (cap + ground) * 0.5, at.z), Vector3(0.53, height, 0.57), rib, 0.045, true)
			Kit.box(section, Vector3(x, cap - 0.16, at.z), Vector3(0.78, 0.72, 0.83), panel, 0.04)
		Kit.box(section, Vector3(at.x, cap - 0.063, at.z), Vector3(2.0 * half_span + 0.79, 0.36, 0.86), rib, 0.038, true)
		if height > 4.0:
			for side: float in [-1.0, 1.0]:
				var foot := Vector3(at.x + side * half_span, cap - minf(height * 0.52, 4.4), at.z + side * 0.13)
				var head := Vector3(at.x - side * (half_span - 0.20), cap - 0.24, foot.z)
				Kit.beam(section, foot, head, 0.20, rib, true)

	func _side_strip(a: Vector3, b: Vector3, side: float, inner: float, outer: float,
			low: float, high: float, material: Material, body: StaticBody3D = null) -> void:
		var x0 := side * inner
		var x1 := side * outer
		_prism(a, b, Vector2(minf(x0, x1), low), Vector2(maxf(x0, x1), high), material, body)

	func _prism(a: Vector3, b: Vector3, low: Vector2, high: Vector2,
			material: Material, body: StaticBody3D = null) -> void:
		# Sections are vertical at both ends, including on grade. Adjacent slabs share their
		# exact top edge, without a rotated box corner protruding at the grade changes.
		var lo := Vector3(low.x, low.y, 0)
		var hi := Vector3(high.x, high.y, 0)
		var lr := Vector3(high.x, low.y, 0)
		var ul := Vector3(low.x, high.y, 0)
		var corners := PackedVector3Array([a + lo, a + lr, a + hi, a + ul, b + lo, b + lr, b + hi, b + ul])
		if body != null:
			var shape := ConvexPolygonShape3D.new()
			shape.points = corners
			shape.margin = 0.003
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
		if material != null:
			var buffer: SurfaceTool = batches.get(material)
			if buffer == null:
				buffer = SurfaceTool.new()
				buffer.begin(Mesh.PRIMITIVE_TRIANGLES)
				batches[material] = buffer
			for face: Array in FACE_ORDER:
				_quad(buffer, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]])

	func _pane(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var center := (a + b + c + d) * 0.25
		var buffer := SurfaceTool.new()
		buffer.begin(Mesh.PRIMITIVE_TRIANGLES)
		_quad(buffer, a - center, b - center, c - center, d - center)
		var pane := MeshInstance3D.new()
		pane.name = "LaminatedViewPane"
		pane.mesh = buffer.commit()
		pane.material_override = glass
		pane.position = center
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		section.add_child(pane)

	func _quad(buffer: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		var normal := (c - a).cross(b - a).normalized()
		for point: Vector3 in [a, b, c, a, c, d]:
			buffer.set_normal(normal)
			buffer.add_vertex(point)

	func _flush() -> void:
		for material: Material in batches:
			var buffer: SurfaceTool = batches[material]
			var node := MeshInstance3D.new()
			node.mesh = buffer.commit()
			node.material_override = material
			section.add_child(node)
		batches.clear()

	func _body(label: String) -> StaticBody3D:
		var body := StaticBody3D.new()
		body.name = label
		body.collision_layer = 1
		body.collision_mask = 0
		root.add_child(body)
		return body

	func _node(parent: Node3D, label: String) -> Node3D:
		var node := Node3D.new()
		node.name = label
		parent.add_child(node)
		return node
