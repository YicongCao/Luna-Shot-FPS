extends CanvasLayer
# Separable low-resolution bright-pass from the actual visible weapon render.
# An additive pass survives transparent viewmodel alpha, unlike native viewport Glow.
var source: SubViewport
var horizontal: SubViewport
var vertical: SubViewport
var extract: ShaderMaterial
var blur: ShaderMaterial
var display: TextureRect
var composite: ShaderMaterial
func _ready() -> void:
	layer=2
	horizontal=make_pass("res://assets/lighting/weapon_bloom_extract.gdshader")
	vertical=make_pass("res://assets/lighting/weapon_bloom_blur.gdshader")
	extract=horizontal.get_child(0).material;blur=vertical.get_child(0).material
	extract.set_shader_parameter("weapon_texture",source.get_texture())
	blur.set_shader_parameter("horizontal_texture",horizontal.get_texture())
	display=TextureRect.new();display.texture=vertical.get_texture()
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE;display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	composite=ShaderMaterial.new();composite.shader=load("res://assets/lighting/weapon_bloom_add.gdshader");display.material=composite
	add_child(display);display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resize();get_viewport().size_changed.connect(resize);source.size_changed.connect(resize)
func make_pass(shader_path: String) -> SubViewport:
	var viewport:=SubViewport.new();viewport.disable_3d=true;viewport.transparent_bg=false
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;add_child(viewport)
	var rect:=ColorRect.new();var mat:=ShaderMaterial.new();mat.shader=load(shader_path);rect.material=mat
	viewport.add_child(rect);rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return viewport
func resize() -> void:
	var dimensions:=source.size
	var reduced:=Vector2i(maxi(1,dimensions.x/4),maxi(1,dimensions.y/4))
	horizontal.size=reduced;vertical.size=reduced
	extract.set_shader_parameter("source_size",Vector2(dimensions))
	blur.set_shader_parameter("source_size",Vector2(reduced))
func set_active(value: bool, strength: float) -> void:
	visible=value
	composite.set_shader_parameter("energy",strength)
	horizontal.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
	vertical.render_target_update_mode=SubViewport.UPDATE_ALWAYS if value else SubViewport.UPDATE_DISABLED
