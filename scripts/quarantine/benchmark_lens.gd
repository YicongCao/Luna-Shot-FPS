extends RefCounted
# Native depth-of-field for the scripted close-up only, never a screen blur.
# Gameplay, ADS, terminal and normal playable mission keep their original camera attributes.
var attributes: CameraAttributesPractical = CameraAttributesPractical.new()
var original: CameraAttributes
var enabled: bool = OS.get_environment("QUARANTINE_BENCHMARK_LENS") != "off"
var focus_distance: float = 0

func _init(camera: Camera3D) -> void:
	original = camera.attributes
	attributes.auto_exposure_enabled = false
	attributes.exposure_multiplier = 1.0
	attributes.dof_blur_amount = .12
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_transition = 4.0

func focus(camera: Camera3D, target: Vector3) -> void:
	focus_distance = maxf(.1,-camera.to_local(target).z)
	# Keep the full robot sharp; ramp into background blur behind its rear armor.
	attributes.dof_blur_far_distance = focus_distance+.65
	camera.attributes = attributes if enabled else original

func clear(camera: Camera3D) -> void:
	camera.attributes = original
