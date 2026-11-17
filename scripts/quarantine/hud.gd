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
const STAGES: Array[String] = ["CLEAR", "ACTIVATE", "EXTRACT", "COMPLETE", "FAILED"]
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
	_resume_button = _make_button("RESUME", _resume)
	_restart_button = _make_button("REDEPLOY", _restart)
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
	var x: float = 46.0
	_text(Vector2(x, 49), "SELENE  //  QUARANTINE", 15, Color(INK, alpha))
	_line(Vector2(x, 63), Vector2(x + 36, 63), Color(CYAN, 0.65 * alpha))
	_text(Vector2(x + 46, 67), "LUNAR OPERATIONS   /   " + STAGES[stage], 10, Color(DIM, alpha))
	var objective: String = str(_value(mission, &"objective_text", ""))
	_wrap(Vector2(x, 100), objective, minf(360.0, _extent.x * 0.3), 15, Color(INK, alpha))
	# A compact phase index, not a large card or objective waypoint obscuring aim.
	for i: int in range(3):
		var phase_color: Color = Color(CYAN if i == stage else DIM, (1.0 if i == stage else 0.68) * alpha)
		_text(Vector2(x + i * 76.0, 162), "%02d %s" % [i + 1, ["CLR", "ACT", "EXT"][i]], 10, phase_color)
	var kills: int = int(_value(mission, &"kills", 0))
	var total: int = int(_value(mission, &"total_bugs", 0))
	_text(Vector2(x, 188), "HOSTILES CLEARED   %02d / %02d" % [kills, total], 11, Color(DIM, alpha))
	var elapsed: float = maxf(0.0, float(_value(mission, &"elapsed", 0.0)))
	_text(Vector2(_extent.x - 46, 49), "SURFACE  /  %02d:%02d" % [int(elapsed) / 60, int(elapsed) % 60], 12, Color(INK, alpha), HORIZONTAL_ALIGNMENT_RIGHT)
	if stage < 3 and mission.has_method("objective_position"):
		var location: Variant = mission.call("objective_position")
		var player: Node3D = _player()
		if location is Vector3 and is_instance_valid(player):
			var distance: float = player.global_position.distance_to(location)
			_text(Vector2(_extent.x - 46, 73), "OBJECTIVE  /  %03.0f M" % distance, 11, Color(DIM, alpha), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_equipment() -> void:
	var y: float = _extent.y - 76.0
	var health: float = maxf(0.0, float(_value(mission, &"health", 0.0)))
	var color: Color = AMBER if health <= 25.0 else INK
	_text(Vector2(46, y - 30), "SUIT INTEGRITY", 10, DIM)
	_text(Vector2(46, y + 3), "%03.0f" % health, 28, color)
	_text(Vector2(110, y), "VITAL", 10, Color(color, 0.55))
	_line(Vector2(46, y + 16), Vector2(192, y + 16), Color(CYAN, 0.28))
	var player: Node3D = _player()
	var ammo: int = int(_value(player, &"ammo", 0))
	var reload: float = float(_value(player, &"reload_left", 0.0))
	var right: float = _extent.x - 46.0
	_text(Vector2(right, y - 30), "LS01  /  PULSE RIFLE", 11, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(right - 54, y + 3), "%02d" % ammo, 32, AMBER if ammo <= 4 else INK, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(right, y), "/ %02d" % CAPACITY, 14, DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	var status: String = "CELL READY" if ammo > 0 else "R  /  RELOAD CELL"
	if reload > 0.0:
		status = "RECHARGING  /  %.1f S" % reload
	_text(Vector2(right, y + 24), status, 10, AMBER if reload > 0.0 or ammo == 0 else DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	if not _modal():
		_text(Vector2(46, _extent.y - 26), "WASD  MOVE     SHIFT  SPRINT     R  RELOAD     E  INTERACT     ESC  PAUSE     F5  REDEPLOY", 10, Color(DIM, lerpf(0.95, 0.82, _ads)))
		_text(Vector2(right, _extent.y - 26), "LMB  FIRE   /   RMB  ADS", 10, Color(DIM, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_prompt() -> void:
	if _modal():
		return
	var hint: String = str(_value(mission, &"interact_hint", ""))
	var progress: float = clampf(float(_value(mission, &"progress", 0.0)), 0.0, 1.0)
	var center: Vector2 = Vector2(_extent.x * 0.5, _extent.y - 164)
	if not hint.is_empty():
		_wrap(center, hint, 410.0, 14, INK, true)
	if progress > 0.0 and _stage() == 1:
		_text(center + Vector2(0, 34), "UPLINK  /  %03.0f%%" % (progress * 100.0), 11, CYAN, HORIZONTAL_ALIGNMENT_CENTER)


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
	_text(Vector2(center.x, tape_y - 33), "HDG  %03d" % posmod(roundi(heading), 360), 11, Color(INK, _ads * 0.8), HORIZONTAL_ALIGNMENT_CENTER)
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
	_text(center + Vector2(247, -83), "CELL", 9, c)
	_text(center + Vector2(247, 99), "%02d" % ammo, 12, Color(INK, _ads * 0.8))
	_text(center + Vector2(-246, -83), "PULSE", 10, c, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(center + Vector2(-246, -65), "/ MANUAL", 10, c, HORIZONTAL_ALIGNMENT_RIGHT)
	_text(center + Vector2(-246, 78), "RNG", 9, c, HORIZONTAL_ALIGNMENT_RIGHT)
	var distance_text: String = "%05.1f M" % _range if _range >= 0.0 else "---.- M"
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
	var title: String = "MISSION PAUSED"
	var subtitle: String = "SURFACE LINK  /  STANDBY"
	var accent: Color = CYAN
	if stage == 3:
		title = "QUARANTINE LIFTED"
		subtitle = "EXTRACTION CONFIRMED  /  OPERATION COMPLETE"
	elif stage == 4:
		title = "SIGNAL LOST"
		subtitle = "OPERATOR OFFLINE  /  OPERATION FAILED"
		accent = AMBER
	# Only the central menu receives a restrained backing, never the gameplay HUD.
	draw_rect(Rect2(center + Vector2(-292, -116), Vector2(584, 320 if stage < 3 else 260)), Color(0.012, 0.025, 0.035, 0.88))
	_line(center + Vector2(-260, -94), center + Vector2(-218, -94), accent)
	_text(center + Vector2(0, -57), "SELENE  /  MISSION CONTROL", 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_text(center + Vector2(0, -13), title, 28, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_text(center + Vector2(0, 17), subtitle, 11, accent, HORIZONTAL_ALIGNMENT_CENTER)
	if stage >= 3:
		var elapsed: int = int(_value(mission, &"elapsed", 0.0))
		_text(center + Vector2(0, 44), "%02d CLEARED    /    %02d:%02d ELAPSED" % [int(_value(mission, &"kills", 0)), elapsed / 60, elapsed % 60], 11, DIM, HORIZONTAL_ALIGNMENT_CENTER)


func _sync_buttons() -> void:
	var stage: int = _stage()
	var menu: bool = _modal() and is_instance_valid(mission)
	_resume_button.visible = menu and stage < 3
	_restart_button.visible = menu
	_restart_button.text = "REDEPLOY" if stage >= 3 else "RESTART"
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


func _wrap(at: Vector2, text: String, width: float, font_size: int, color: Color, centered: bool = false) -> void:
	# The engine owns Unicode shaping and line breaks, including localized text.
	var readable_size: int = maxi(font_size, ceili(MIN_TEXT_PIXELS / _scale))
	var start: Vector2 = at - Vector2(width * 0.5, 0) if centered else at
	var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	var shadow: Color = Color(0.005, 0.012, 0.018, color.a * 0.85)
	draw_multiline_string_outline(_font, start, text, alignment, width, readable_size, 2, maxi(1, ceili(1.0 / _scale)), shadow)
	draw_multiline_string(_font, start + Vector2(0, 1.0 / _scale), text, alignment, width, readable_size, 2, shadow)
	draw_multiline_string(_font, start, text, alignment, width, readable_size, 2, color)
