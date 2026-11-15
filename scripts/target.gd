extends StaticBody3D
@export var label_text: String = "T01"
var hits: int = 0
var flash: float = 0.0
var material: StandardMaterial3D
func _ready() -> void:
	$ID.text = label_text
	material = $Board.mesh.material.duplicate()
	$Board.material_override = material
func register_hit() -> void:
	hits += 1
	flash = 0.18
func reset() -> void:
	hits = 0
	flash = 0
func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	material.albedo_color = Color(0.9, 0.55, 0.29) if flash > 0 else Color(0.86, 0.87, 0.84)
