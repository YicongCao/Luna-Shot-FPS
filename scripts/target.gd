extends StaticBody3D
@export var label_text: String = "T01"
const FALL_SECONDS := 0.42
var hits: int = 0
var flash: float = 0.0
var knocked_down := false
var fall_time := 0.0
var animation_paused := false
var material: StandardMaterial3D
func _ready() -> void:
	$Pivot/ID.text = label_text
	material = $Pivot/Board.mesh.material.duplicate()
	$Pivot/Board.material_override = material
func register_hit() -> bool:
	if knocked_down: return false
	knocked_down = true
	hits += 1
	flash = 0.18
	fall_time = 0
	# Remove the standing collider immediately, including subsequent rays in this frame.
	collision_layer = 0
	return true
func reset() -> void:
	hits = 0
	flash = 0
	fall_time = 0
	knocked_down = false
	$Pivot.rotation = Vector3.ZERO
	collision_layer = 4
	material.albedo_color = Color(0.86, 0.87, 0.84)
func _process(delta: float) -> void:
	if animation_paused: return
	flash = maxf(0.0, flash - delta)
	material.albedo_color = Color(0.9, 0.55, 0.29) if flash > 0 else Color(0.86, 0.87, 0.84)
	if knocked_down:
		fall_time = minf(FALL_SECONDS, fall_time + delta)
		var t := fall_time / FALL_SECONDS
		$Pivot.rotation.x = -PI / 2 * t * t
