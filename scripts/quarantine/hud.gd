extends Control
## Standalone CanvasLayer HUD. Assign `mission` before add_child(); layer belongs
## to the mission (CanvasLayer.layer = 10). No scene, texture, shader or input-map
## dependencies. All distances are metres; headings use world -Z as north.
## Mission owns pause/input policy. RESUME calls mission.set_paused(false), or
## mission.resume() when available; the fallback clears paused/tree pause only.
## restart() is required for the two redeploy/restart buttons.

const INK: Color = Color(0.91, 0.91, 0.85)
const DIM: Color = Color(0.73, 0.80, 0.79)
const CYAN: Color = Color(0.56, 0.88, 0.90)
const MIN_TEXT_PIXELS: float = 13.0
const AMBER: Color = Color(0.96, 0.66, 0.35)
const DAMAGE: Color = Color(0.72, 0.24, 0.18)
const PHASE_ICONS: Array[StringName] = [&"bug", &"power", &"exit"]
const CAPACITY: int = 20
const RANGE_LIMIT: float = 250.0

var mission: Node
var _font: Font
var _scale: float = 1.0
var _extent: Vector2 = Vector2(1440, 900)
var _ads: float = 0.0
var _range: float = -1.0
var _visible_bugs: Array[Node3D] = []
var _resume_button: Button
var _restart_button: Button
var _menu_open: bool = false
var _previous_mouse_mode: int = Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_font = ThemeDB.fallback_font
	_resume_button = _make_button("继续", _resume)
	_restart_button = _make_button("重试", _restart)
	_update_layout()


func _make_button(caption: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = caption
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", _font)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.025, 0.055, 0.065, 0.88)
		style.border_color = Color(CYAN, 0.36)
		style.border_width_bottom = 1
		if state != "normal":
			style.bg_color = Color(0.06, 0.14, 0.16, 0.95)
			style.border_color = Color(CYAN, 0.95)
			style.border_width_top = 1
		if state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_width_left = 1
			style.border_width_right = 1
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	button.hide()
	add_child(button)
	return button


func _process(delta: float) -> void:
	_update_layout()
	var player: Node3D = _player()
	var target: float = 0.0
	if is_instance_valid(player) and bool(_value(player, &"aiming", false)) and not _modal():
		target = 1.0
	_ads = lerpf(_ads, target, 1.0 - exp(-12.0 * delta))
	_sync_buttons()
	queue_redraw()


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	# Scale by the limiting 1440x900 dimension, but extend the logical canvas on
	# ultrawide rather than stretch text or shift the boresight off screen centre.
	_scale = maxf(0.1, minf(viewport_size.x / 1440.0, viewport_size.y / 900.0))
	_extent = viewport_size / _scale
	if is_instance_valid(_resume_button):
		var center: Vector2 = _extent * 0.5
		_resume_button.position = (center + Vector2(-114, 70)) * _scale
		_resume_button.size = Vector2(228, 44) * _scale
		_restart_button.position = (center + Vector2(-114, 126 if _paused() and _stage() < 3 else 70)) * _scale
		_restart_button.size = Vector2(228, 44) * _scale
		_resume_button.add_theme_font_size_override("font_size", maxi(13, roundi(14.0 * _scale)))
		_restart_button.add_theme_font_size_override("font_size", maxi(13, roundi(14.0 * _scale)))


func _physics_process(_delta: float) -> void:
	_visible_bugs.clear()
	_range = -1.0
	if _ads < 0.01 or _modal():
		return
	var player: Node3D = _player()
	var camera: Camera3D = _camera()
	if not is_instance_valid(player) or not is_instance_valid(camera) or not camera.is_inside_tree():
		return
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var excluded: Array[RID] = []
	if player is CollisionObject3D:
		excluded.append((player as CollisionObject3D).get_rid())
	var origin: Vector3 = camera.global_position
	var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin - camera.global_basis.z * RANGE_LIMIT, 0xFFFFFFFF, excluded)
	ray.collide_with_areas = true
	var hit: Dictionary = space.intersect_ray(ray)
	if not hit.is_empty():
		var point: Vector3 = hit["position"]
		_range = origin.distance_to(point)
	var bugs: Array = _value(mission, &"bugs", [])
	var candidates: Array[Node3D] = []
	for item: Variant in bugs:
		if not is_instance_valid(item) or not item is Node3D:
			continue
		var bug: Node3D = item as Node3D
		if not _bug_alive(bug) or not bug.is_inside_tree() or not bug.is_visible_in_tree():
			continue
		var point: Vector3 = _bug_anchor(bug)
		if origin.distance_to(point) > RANGE_LIMIT or camera.is_position_behind(point):
			continue
		var pixel: Vector2 = camera.unproject_position(point)
		if not camera.get_viewport().get_visible_rect().grow(-24.0 * _scale).has_point(pixel):
			continue
		candidates.append(bug)
	# Distance prioritization is only a drawing budget, never targeting/aiming.
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return origin.distance_squared_to(a.global_position) < origin.distance_squared_to(b.global_position))
	for bug: Node3D in candidates:
		var point: Vector3 = _bug_anchor(bug)
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, point, 0xFFFFFFFF, excluded)
		query.collide_with_areas = true
		query.hit_from_inside = true
		var obstruction: Dictionary = space.intersect_ray(query)
		var clear: bool = obstruction.is_empty()
		if not clear:
			var collider: Node = obstruction.get("collider") as Node
			clear = is_instance_valid(collider) and (collider == bug or bug.is_ancestor_of(collider))
		if clear:
			_visible_bugs.append(bug)
		if _visible_bugs.size() >= 3:
			break


func _draw() -> void:
	if _font == null or not is_instance_valid(mission):
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * _scale)
	_draw_edges()
	_draw_mission()
	_draw_equipment()
	_draw_prompt()
	if not _modal():
		_draw_objective_marker()
		_draw_boresight()
		if _ads > 0.01:
			_draw_flight_overlay()
			_draw_contacts()
	else:
		_draw_modal()
	draw_set_transform(Vector2.ZERO)


func _draw_edges() -> void:
	# Shallow edge-only vignette; no white flash, full-screen panel or letterbox.
	var damage: float = clampf(float(_value(mission, &"damage_flash", 0.0)), 0.0, 1.0)
	for i: int in range(16):
		var inset: float = float(i) * 3.0
		var strength: float = pow(1.0 - float(i) / 16.0, 2.0)
		var shade: Color = Color(0.005, 0.014, 0.022, 0.12 * strength)
		if damage > 0.0:
			shade = Color(DAMAGE, damage * 0.25 * strength)
		draw_rect(Rect2(Vector2(inset, inset), _extent - Vector2.ONE * inset * 2.0), shade, false, 3.0)
	if damage > 0.015:
		var c: Color = Color(DAMAGE, damage * 0.8)
		_line(Vector2(26, _extent.y * 0.5 - 32), Vector2(26, _extent.y * 0.5 + 32), c, 2.0)
		_line(Vector2(_extent.x - 26, _extent.y * 0.5 - 32), Vector2(_extent.x - 26, _extent.y * 0.5 + 32), c, 2.0)


func _draw_mission() -> void:
	var alpha: float = lerpf(1.0, 0.82, _ads)
	var stage: int = _stage()
	var kills: int = int(_value(mission, &"kills", 0))
	var total: int = int(_value(mission, &"total_bugs", 0))
	# One shared pictogram per phase; the underline marks the current objective.
	for i: int in range(3):
		var at: Vector2 = Vector2(76 + i * 102, 49)
		var phase_color: Color = Color(CYAN if i == stage else DIM, (1.0 if i <= stage else 0.5) * alpha)
		_icon(at, PHASE_ICONS[i], phase_color)
		if i == stage:
			_line(at + Vector2(-19, 42), at + Vector2(19, 42), phase_color, 2.0)
		if i == 0:
			_text(at + Vector2(0, 33), "%d/%d" % [kills, total], 14, phase_color, HORIZONTAL_ALIGNMENT_CENTER)
		elif i == 1:
			_text(at + Vector2(0, 33), "%d/1" % (1 if bool(_value(mission, &"terminal_completed", false)) else 0), 14, phase_color, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_text(at + Vector2(0, 33), "%d/1" % (1 if stage == 3 else 0), 14, phase_color, HORIZONTAL_ALIGNMENT_CENTER)
		if i < 2:
			_icon(at + Vector2(51, 0), &"chevron", Color(DIM, alpha * 0.4), 5.0)
	var elapsed: float = maxf(0.0, float(_value(mission, &"elapsed", 0.0)))
	_icon(Vector2(_extent.x - 134, 44), &"clock", Color(DIM, alpha), 9.0)
	_text(Vector2(_extent.x - 46, 49), "%02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], 14, Color(INK, alpha), HORIZONTAL_ALIGNMENT_RIGHT)
	if stage < 3 and mission.has_method("objective_position"):
		var location: Variant = mission.call("objective_position")
		var player: Node3D = _player()
		if location is Vector3 and is_instance_valid(player):
			var distance: float = player.global_position.distance_to(location)
			_icon(Vector2(_extent.x - 134, 77), PHASE_ICONS[stage], Color(CYAN, alpha), 10.0)
			_text(Vector2(_extent.x - 46, 82), "%.0f m" % distance, 14, Color(DIM, alpha), HORIZONTAL_ALIGNMENT_RIGHT)


## Pure projection/layout helper: no nodes, physics, drawing or mutable HUD state.
## local_position is in camera space (-Z forward); viewport_size and returned
## position share units (the HUD passes logical pixels). Direction is screen-space
## outward, normalized; state is inside/offscreen/behind. "inside" means inside
## the inset safe rectangle, not merely inside the camera frustum.
static func objective_marker_layout(local_position: Vector3, projection: Projection, viewport_size: Vector2, margin: Vector2 = Vector2(64, 128)) -> Dictionary:
	var center: Vector2 = viewport_size * 0.5
	var safe_half: Vector2 = Vector2(maxf(1.0, center.x - margin.x), maxf(1.0, center.y - margin.y))
	var clip: Vector4 = projection * Vector4(local_position.x, local_position.y, local_position.z, 1.0)
	var behind: bool = local_position.z >= 0.0
	# abs(w) avoids the left/right reversal of normal perspective division behind
	# the camera. It also keeps the direction continuous across the camera plane.
	var offset: Vector2 = Vector2(clip.x, -clip.y) / maxf(absf(clip.w), 0.00001) * center
	var inside: bool = not behind and absf(offset.x) <= safe_half.x and absf(offset.y) <= safe_half.y
	if behind:
		# These are ground-level objectives. Looking up must not turn an aft
		# destination into an upward/sky instruction; use the lower side to turn back.
		offset = Vector2(local_position.x,maxf(absf(local_position.z)*.35,absf(local_position.y)*.15))
	var direction: Vector2 = offset.normalized()
	var position: Vector2 = center + offset
	if not inside:
		# Exactly aft has no unique turn direction; consistently point down rather
		# than leaving an apparently in-front marker on the boresight.
		if direction.length_squared() < 0.00001:
			direction = Vector2.DOWN
		var edge_scale: float = 1.0 / maxf(absf(direction.x) / safe_half.x, absf(direction.y) / safe_half.y)
		position = center + direction * edge_scale
	return {"position": position, "direction": direction, "inside": inside, "behind": behind,
		"state": &"behind" if behind else (&"inside" if inside else &"offscreen")}


func _draw_objective_marker() -> void:
	var stage: int = _stage()
	if stage != 1 and stage != 2:
		return
	# The existing contextual hold-E ring takes over at the terminal. Never draw
	# a second E prompt or a locator over the terminal/reticle while interacting.
	if stage == 1 and (_terminal_panel_readable() or not str(_value(mission, &"interact_hint", "")).is_empty() or float(_value(mission, &"progress", 0.0)) > 0.0):
		return
	var camera: Camera3D = _camera()
	if not is_instance_valid(camera) or not camera.is_inside_tree() or not mission.has_method("objective_position"):
		return
	var target: Variant = mission.call("objective_position")
	if not target is Vector3:
		return
	var location: Vector3 = target+Vector3(0,2.14 if stage == 1 else .08,0)
	var local_position: Vector3 = camera.get_camera_transform().affine_inverse() * location
	var layout: Dictionary = objective_marker_layout(local_position, camera.get_camera_projection(), _extent)
	var at: Vector2 = layout["position"]
	var text_offset: Vector2 = Vector2(0, 30)
	var c: Color = Color(CYAN, lerpf(0.92, 0.7, _ads))
	if bool(layout["inside"]):
		# Keep a small clear boresight corridor even when aiming directly at the
		# objective. A short leader still identifies its exact projected position.
		var center: Vector2 = _extent * 0.5
		if at.distance_to(center) < 60.0:
			var anchor: Vector2 = at
			at.y = center.y - 64.0
			text_offset = Vector2(0, -20)
			_line(at + Vector2(0, 16), Vector2(anchor.x, minf(anchor.y - 24.0, center.y - 26.0)), Color(c, c.a * 0.4))
	else:
		var direction: Vector2 = layout["direction"]
		if direction.y > 0.35:
			text_offset = Vector2(0, -20)
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		var tip: Vector2 = at + direction * 23.0
		_line(tip - direction * 8.0 + normal * 5.0, tip, c, 1.5)
		_line(tip, tip - direction * 8.0 - normal * 5.0, c, 1.5)
	# Static mission locations intentionally remain visible through structures.
	# Enemy contacts exclusively use the separate physics/LOS path above.
	_icon(at, PHASE_ICONS[stage], c, 11.0)
	var player: Node3D = _player()
	var distance: float = player.global_position.distance_to(location) if is_instance_valid(player) else camera.global_position.distance_to(location)
	_text(at + text_offset, "%.0f m" % distance, 13, Color(INK, c.a), HORIZONTAL_ALIGNMENT_CENTER)


func _draw_equipment() -> void:
	var y: float = _extent.y - 76.0
	var health: float = maxf(0.0, float(_value(mission, &"health", 0.0)))
	var color: Color = AMBER if health <= 25.0 else INK
	_icon(Vector2(59, y - 7), &"health", color)
	_text(Vector2(84, y + 3), "%03.0f" % health, 28, color)
	var player: Node3D = _player()
	var ammo: int = int(_value(player, &"ammo", 0))
	var reload: float = float(_value(player, &"reload_left", 0.0))
	var right: float = _extent.x - 46.0
	_icon(Vector2(right - 123, y - 9), &"ammo", AMBER if ammo <= 4 else INK)
	_text(Vector2(right - 54, y + 3), "%02d" % ammo, 32, AMBER if ammo <= 4 else INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(right, y), "/ %02d" % CAPACITY, 14, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	if reload > 0.0:
		_icon(Vector2(right - 78, y + 26), &"reload", AMBER, 9.0)
		_text(Vector2(right, y + 31), "%.1f s" % reload, 14, AMBER, HORIZONTAL_ALIGNMENT_RIGHT)
	elif ammo < CAPACITY and not _modal():
		_key(Vector2(right - 12, y + 28), "R", AMBER if ammo <= 4 else DIM)


func _terminal_panel_readable() -> bool:
	var panel: Node = mission.get_node_or_null("World/HolographicTerminal")
	return panel != null and bool(panel.get("readable"))

func _draw_prompt() -> void:
	if _modal() or _terminal_panel_readable():
		return
	var hint: String = str(_value(mission, &"interact_hint", ""))
	var progress: float = clampf(float(_value(mission, &"progress", 0.0)), 0.0, 1.0)
	var center: Vector2 = Vector2(_extent.x * 0.5, _extent.y - 164)
	# Mission-owned hint availability is the proximity gate, not the prose itself.
	if not hint.is_empty() and _stage() == 0:
		_icon(center + Vector2(-30, 0), &"power", DIM)
		_line(center + Vector2(-43, 13), center + Vector2(-17, -13), AMBER)
		_icon(center + Vector2(8, 0), &"bug", AMBER)
		var remaining: int = maxi(0, int(_value(mission, &"total_bugs", 0)) - int(_value(mission, &"kills", 0)))
		_text(center + Vector2(32, 5), str(remaining), 16, AMBER)
	elif _stage() == 1 and (not hint.is_empty() or progress > 0.0):
		_icon(center + Vector2(-39, 0), &"power", CYAN)
		if not hint.is_empty():
			_key(center, "E", INK)
		_text(center + Vector2(30, 5), "%.1f s" % ((1.0 - progress) * 3.0), 14, CYAN)
		# A filling ring and countdown communicate holding E without a sentence.
		_arc(center, 22.0, -PI * 0.5, TAU, Color(DIM, 0.3))
		if progress > 0.0:
			_arc(center, 22.0, -PI * 0.5, TAU * progress, CYAN)


func _draw_boresight() -> void:
	var center: Vector2 = _extent * 0.5
	var c: Color = Color(CYAN, lerpf(0.36, 0.78, _ads))
	var gap: float = lerpf(5.0, 8.0, _ads)
	_line(center + Vector2(-gap - 5, 0), center + Vector2(-gap, 0), c)
	_line(center + Vector2(gap, 0), center + Vector2(gap + 5, 0), c)
	_line(center + Vector2(0, gap), center + Vector2(0, gap + 4), c)
	if _ads < 0.5:
		draw_circle(center, 1.0, Color(INK, 0.5 * (1.0 - _ads)), false, 1.0, true)
	var hit: float = clampf(float(_value(mission, &"hit_flash", 0.0)), 0.0, 1.0)
	if hit > 0.0:
		for direction: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			_line(center + direction * 14.0, center + direction * 19.0, Color(INK, hit * 0.85))


func _draw_flight_overlay() -> void:
	var camera: Camera3D = _camera()
	if not is_instance_valid(camera):
		return
	var center: Vector2 = _extent * 0.5
	var c: Color = Color(CYAN, _ads * 0.94)
	var faint: Color = Color(CYAN, _ads * 0.62)
	var forward: Vector3 = -camera.global_basis.z
	var heading: float = fposmod(rad_to_deg(atan2(forward.x, -forward.z)), 360.0)
	var tape_y: float = center.y - 208.0
	# Fixed-width heading tape is centred on the actual camera, not the canvas edge.
	for tick: int in range(-8, 9):
		var degrees: float = floorf(heading / 5.0) * 5.0 + tick * 5.0
		var offset: float = (degrees - heading) * 5.2
		if absf(offset) > 190.0:
			continue
		var major: bool = posmod(roundi(degrees), 15) == 0
		_line(Vector2(center.x + offset, tape_y), Vector2(center.x + offset, tape_y + (8.0 if major else 4.0)), c if major else faint)
		if major:
			_text(Vector2(center.x + offset, tape_y - 8), "%03d" % posmod(roundi(degrees), 360), 10, c, HORIZONTAL_ALIGNMENT_CENTER)
	_line(Vector2(center.x - 4, tape_y + 17), Vector2(center.x, tape_y + 12), c)
	_line(Vector2(center.x, tape_y + 12), Vector2(center.x + 4, tape_y + 17), c)
	_text(Vector2(center.x, tape_y - 33), "%03d°" % posmod(roundi(heading), 360), 11, Color(INK, _ads * 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	var head: Node3D = _value(_player(), &"head", null) as Node3D
	var pitch: float = rad_to_deg(head.rotation.x) if is_instance_valid(head) else rad_to_deg(asin(clampf(forward.y, -1.0, 1.0)))
	# Sparse ladder with a 144 px empty central corridor and no surrounding ring.
	for rung: int in range(-90, 91, 10):
		var offset: float = (pitch - float(rung)) * 5.0
		if absf(offset) > 128.0:
			continue
		var fade: float = 1.0 - smoothstep(88.0, 128.0, absf(offset))
		var rung_color: Color = Color(CYAN, _ads * 0.78 * fade)
		var y: float = center.y + offset
		for side: float in [-1.0, 1.0]:
			var inner: Vector2 = Vector2(center.x + side * 72, y)
			var outer: Vector2 = Vector2(center.x + side * 111, y)
			if rung < 0:
				draw_dashed_line(inner, outer, Color(0.005, 0.012, 0.018, rung_color.a * 0.65), 2.55 / _scale, 5.0, true)
				draw_dashed_line(inner, outer, rung_color, 1.15 / _scale, 5.0, true)
			else:
				_line(inner, outer, rung_color)
			_line(outer, outer + Vector2(0, 4 if rung >= 0 else -4), rung_color)
			_text(Vector2(center.x + side * 134, y + 4), "%+02d" % rung if rung != 0 else "0", 10, rung_color, HORIZONTAL_ALIGNMENT_CENTER)
	var ammo: int = clampi(int(_value(_player(), &"ammo", 0)), 0, CAPACITY)
	for i: int in range(CAPACITY):
		var y: float = center.y + 72.0 - float(i) * 7.0
		var active: bool = i < ammo
		var tick_color: Color = Color(AMBER if ammo <= 4 else CYAN, _ads * (0.88 if active else 0.26))
		_line(Vector2(center.x + 246, y), Vector2(center.x + 246 + (10 if i % 5 == 0 else 5), y), tick_color)
	_icon(center + Vector2(251, -92), &"ammo", c, 9.0)
	_text(center + Vector2(247, 99), "%02d" % ammo, 12, Color(INK, _ads * 0.8))
	_icon(center + Vector2(-256, 70), &"range", c, 10.0)
	var distance_text: String = "%05.1f m" % _range if _range >= 0.0 else "---.- m"
	_text(center + Vector2(-246, 99), distance_text, 12, Color(INK, _ads * 0.8), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_contacts() -> void:
	var camera: Camera3D = _camera()
	if not is_instance_valid(camera):
		return
	for bug: Node3D in _visible_bugs:
		if not is_instance_valid(bug) or not bug.is_inside_tree() or not _bug_alive(bug):
			continue
		var anchor: Vector3 = _bug_anchor(bug)
		if camera.is_position_behind(anchor):
			continue
		var pixel: Vector2 = camera.unproject_position(anchor) / _scale
		if not Rect2(Vector2(24, 24), _extent - Vector2(48, 48)).has_point(pixel):
			continue
		var distance: float = camera.global_position.distance_to(anchor)
		var radius: float = clampf(100.0 / maxf(distance, 1.0), 3.0, 11.0)
		var stroke: float = clampf(radius * 0.38, 1.5, 4.0)
		var c: Color = Color(CYAN, _ads * 0.43)
		for side: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			var corner: Vector2 = pixel + side * radius
			_line(corner, corner - Vector2(side.x * stroke, 0), c)
			_line(corner, corner - Vector2(0, side.y * stroke), c)


func _draw_modal() -> void:
	var center: Vector2 = _extent * 0.5
	var stage: int = _stage()
	var title: String = "已暂停"
	var symbol: StringName = &"pause"
	var accent: Color = CYAN
	if stage == 3:
		title = "撤离成功"
		symbol = &"exit"
	elif stage == 4:
		title = "任务失败"
		symbol = &"cross"
		accent = AMBER
	# Only the central menu receives a restrained backing, never the gameplay HUD.
	draw_rect(Rect2(center + Vector2(-220, -116), Vector2(440, 320 if stage < 3 else 260)), Color(0.012, 0.025, 0.035, 0.88))
	_icon(center + Vector2(0, -70), symbol, accent, 18.0)
	_text(center + Vector2(0, -13), title, 28, INK, HORIZONTAL_ALIGNMENT_CENTER)
	if stage >= 3:
		var elapsed: int = int(_value(mission, &"elapsed", 0.0))
		_icon(center + Vector2(-94, 33), &"bug", DIM, 10.0)
		_text(center + Vector2(-73, 38), "%d/%d" % [int(_value(mission, &"kills", 0)), int(_value(mission, &"total_bugs", 0))], 14, DIM)
		_icon(center + Vector2(13, 33), &"clock", DIM, 10.0)
		_text(center + Vector2(34, 38), "%02d:%02d" % [elapsed / 60, elapsed % 60], 14, DIM)


func _sync_buttons() -> void:
	var stage: int = _stage()
	var menu: bool = _modal() and is_instance_valid(mission)
	_resume_button.visible = menu and stage < 3
	_restart_button.visible = menu
	_restart_button.text = "重试"
	if menu and not _menu_open:
		_previous_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if stage < 3:
			_resume_button.grab_focus()
		else:
			_restart_button.grab_focus()
	elif not menu and _menu_open:
		_resume_button.release_focus()
		_restart_button.release_focus()
		# A mission with a pause API also owns capture (including QA/free cursor).
		# Do not undo the mouse mode it just selected in set_paused()/restart().
		if not mission.has_method("set_paused") and not mission.has_method("resume"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _previous_mouse_mode == Input.MOUSE_MODE_VISIBLE else _previous_mouse_mode
	_menu_open = menu


func _resume() -> void:
	if not is_instance_valid(mission) or _stage() >= 3:
		return
	if mission.has_method("set_paused"):
		mission.call("set_paused", false)
	elif mission.has_method("resume"):
		mission.call("resume")
	else:
		mission.set("paused", false)
		get_tree().paused = false
	_sync_buttons()


func _restart() -> void:
	if is_instance_valid(mission) and mission.has_method("restart"):
		mission.call_deferred("restart")


func _value(object: Object, property: StringName, fallback: Variant) -> Variant:
	if not is_instance_valid(object):
		return fallback
	var value: Variant = object.get(property)
	return fallback if value == null else value


func _player() -> Node3D:
	return _value(mission, &"player", null) as Node3D


func _camera() -> Camera3D:
	return _value(_player(), &"camera", null) as Camera3D


func _stage() -> int:
	return clampi(int(_value(mission, &"stage", 0)), 0, 4)


func _paused() -> bool:
	return bool(_value(mission, &"paused", false))


func _modal() -> bool:
	return _paused() or _stage() >= 3


func _bug_alive(bug: Node3D) -> bool:
	var alive: Variant = bug.get("alive")
	if alive is bool:
		return bool(alive)
	# Compatibility with the initial mission's inverse flag; unknown state is
	# never eligible for a contact. Public alive remains the preferred contract.
	var dead: Variant = bug.get("dead")
	return not bool(dead) if dead is bool else false


func _bug_anchor(bug: Node3D) -> Vector3:
	return bug.global_position + Vector3.UP * 0.35


func _line(start: Vector2, end: Vector2, color: Color, width: float = 1.0) -> void:
	var stroke: float = maxf(width, 1.15 / _scale)
	# A narrow dark keyline survives sunlit panels without a filled HUD backing.
	draw_line(start, end, Color(0.005, 0.012, 0.018, color.a * 0.65), stroke + 1.4 / _scale, true)
	draw_line(start, end, color, stroke, true)


func _text(at: Vector2, text: String, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	# Letterboxed/ultrawide viewports can be shorter than 900 even on a 1080p
	# display. Enforce a physical pixel floor, not merely a logical font size.
	var readable_size: int = maxi(font_size, ceili(MIN_TEXT_PIXELS / _scale))
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size).x
	var start: Vector2 = at
	if alignment == HORIZONTAL_ALIGNMENT_CENTER:
		start.x -= width * 0.5
	elif alignment == HORIZONTAL_ALIGNMENT_RIGHT:
		start.x -= width
	var shadow: Color = Color(0.005, 0.012, 0.018, color.a * 0.85)
	draw_string_outline(_font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size, maxi(1, ceili(1.0 / _scale)), shadow)
	draw_string(_font, start + Vector2(0, 1.0 / _scale), text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size, shadow)
	draw_string(_font, start, text, HORIZONTAL_ALIGNMENT_LEFT, -1, readable_size, color)


func _key(at: Vector2, caption: String, color: Color) -> void:
	var half: float = maxf(12.0, 10.0 / _scale)
	var corners: Array[Vector2] = [Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	for i: int in range(4):
		_line(at + corners[i], at + corners[(i + 1) % 4], color)
	_text(at + Vector2(0, maxf(5.0, 4.0 / _scale)), caption, 14, color, HORIZONTAL_ALIGNMENT_CENTER)


func _arc(at: Vector2, radius: float, start: float, sweep: float, color: Color) -> void:
	var steps: int = maxi(2, ceili(absf(sweep) * 8.0))
	for i: int in range(steps):
		var a: float = start + sweep * float(i) / float(steps)
		var b: float = start + sweep * float(i + 1) / float(steps)
		_line(at + Vector2(cos(a), sin(a)) * radius, at + Vector2(cos(b), sin(b)) * radius, color)


func _icon(at: Vector2, symbol: StringName, color: Color, radius: float = 12.0) -> void:
	# Shared normalized linework keeps objective, equipment and ADS icons identical.
	# Keylined strokes remain legible over both sunlit panels and the lunar shadows.
	var paths: Array = []
	match symbol:
		&"bug":
			_arc(at + Vector2(0, radius * 0.18), radius * 0.55, 0.0, TAU, color)
			_arc(at + Vector2(0, -radius * 0.55), radius * 0.28, PI, PI, color)
			paths = [[Vector2(0, -0.35), Vector2(0, 0.72)]]
			for side: float in [-1.0, 1.0]:
				for leg: int in range(3):
					var y: float = -0.3 + leg * 0.45
					paths.append([Vector2(side * 0.45, y), Vector2(side * 0.82, y - 0.15), Vector2(side, y + 0.1)])
				paths.append([Vector2(side * 0.15, -0.78), Vector2(side * 0.42, -1.0)])
		&"power":
			_arc(at, radius * 0.85, -PI * 0.28, PI * 1.56, color)
			paths = [[Vector2(0, -1), Vector2(0, 0.1)]]
		&"exit":
			paths = [
				[Vector2(0.2, -0.5), Vector2(0.2, -1), Vector2(-0.85, -1), Vector2(-0.85, 1), Vector2(0.2, 1), Vector2(0.2, 0.5)],
				[Vector2(-0.4, 0), Vector2(1, 0)],
				[Vector2(0.55, -0.45), Vector2(1, 0), Vector2(0.55, 0.45)]]
		&"health":
			paths = [[Vector2(-0.8, 0), Vector2(0.8, 0)], [Vector2(0, -0.8), Vector2(0, 0.8)]]
		&"ammo":
			paths = [
				[Vector2(-0.4, 1), Vector2(-0.4, -0.45), Vector2(0, -1), Vector2(0.4, -0.45), Vector2(0.4, 1), Vector2(-0.4, 1)],
				[Vector2(-0.4, 0.65), Vector2(0.4, 0.65)]]
		&"clock":
			_arc(at, radius, 0.0, TAU, color)
			paths = [[Vector2(0, -0.6), Vector2(0, 0), Vector2(0.5, 0.25)]]
		&"reload":
			_arc(at, radius * 0.85, -PI * 0.5, PI * 1.7, color)
			paths = [[Vector2(-0.45, -1), Vector2(0, -0.85), Vector2(-0.2, -0.4)]]
		&"range":
			paths = [
				[Vector2(-1, -0.5), Vector2(-1, 0.5)],
				[Vector2(-1, 0), Vector2(1, 0)],
				[Vector2(1, -0.5), Vector2(1, 0.5)]]
		&"check":
			paths = [[Vector2(-0.7, 0), Vector2(-0.2, 0.5), Vector2(0.8, -0.6)]]
		&"chevron":
			paths = [[Vector2(-0.4, -0.7), Vector2(0.4, 0), Vector2(-0.4, 0.7)]]
		&"pause":
			paths = [[Vector2(-0.4, -0.8), Vector2(-0.4, 0.8)], [Vector2(0.4, -0.8), Vector2(0.4, 0.8)]]
		&"cross":
			paths = [[Vector2(-0.7, -0.7), Vector2(0.7, 0.7)], [Vector2(-0.7, 0.7), Vector2(0.7, -0.7)]]
	for path: Array in paths:
		for i: int in range(path.size() - 1):
			_line(at + Vector2(path[i]) * radius, at + Vector2(path[i + 1]) * radius, color)
