extends Node3D
# Real world-space projected device UI. Not a screen-space floating Label3D.
var mission: Node3D
var readable: bool = false
var opacity: float = 0
var target_visibility: float = 0
var clock: float = 0
var panel: Control
var viewport: SubViewport
var surface: MeshInstance3D
var material: StandardMaterial3D
var projection_lines: MeshInstance3D

func _ready() -> void:
	mission=get_parent().get_parent()
	viewport=SubViewport.new()
	viewport.size=Vector2i(640,384)
	viewport.transparent_bg=true
	viewport.disable_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	panel=Control.new()
	panel.set_script(preload("res://scripts/quarantine/terminal_panel.gd"))
	panel.mission=mission
	panel.size=Vector2(640,384)
	viewport.add_child(panel)
	surface=MeshInstance3D.new()
	var quad: QuadMesh=QuadMesh.new()
	quad.size=Vector2(1.60,.96)
	surface.mesh=quad
	surface.position=Vector3(0,2.14,-21.94)
	material=StandardMaterial3D.new()
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture=viewport.get_texture()
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
	material.cull_mode=BaseMaterial3D.CULL_BACK
	surface.material_override=material
	surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(surface)
	# Four faint rays start at the physical console's projector slot.
	var mesh: ImmediateMesh=ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for x in [-.80,.80]:
		for y in [1.66,2.62]:
			mesh.surface_add_vertex(Vector3(x*.45,1.52,-22.03))
			mesh.surface_add_vertex(Vector3(x,y,-21.94))
	mesh.surface_end()
	projection_lines=MeshInstance3D.new()
	projection_lines.mesh=mesh
	var line_material: StandardMaterial3D=StandardMaterial3D.new()
	line_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	line_material.albedo_color=Color(.20,.78,.90,.14)
	projection_lines.material_override=line_material
	projection_lines.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(projection_lines)

func _physics_process(delta: float) -> void:
	clock-=delta
	if clock>0 or not is_instance_valid(mission.player): return
	clock=.10
	var player: Node=mission.player
	var target: Vector3=surface.global_position
	var distance: float=player.camera.global_position.distance_to(target)
	var front: bool=player.global_position.z>-21.6
	var query: PhysicsRayQueryParameters3D=PhysicsRayQueryParameters3D.create(player.camera.global_position,target,1,[player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	var clear: bool=hit.is_empty() or hit.get("collider")==get_parent().get_node("TerminalCollision")
	target_visibility=1.0 if front and distance<7.0 and clear and mission.stage<3 else 0.0
	panel.can_interact=mission.can_use_terminal()
	readable=target_visibility>0 and opacity>.8 and distance<4.5 and player.camera.is_position_in_frustum(target)

func _process(delta: float) -> void:
	opacity=move_toward(opacity,target_visibility,delta*4)
	surface.visible=opacity>.01
	projection_lines.visible=surface.visible
	material.albedo_color.a=opacity
	projection_lines.material_override.albedo_color.a=opacity*.14
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS if surface.visible else SubViewport.UPDATE_DISABLED
