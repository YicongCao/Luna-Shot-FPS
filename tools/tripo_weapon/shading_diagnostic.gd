extends "res://tools/tripo_weapon/capture.gd"
# Read-only screen-space face-normal diagnostic. Never saved to the baked asset.
func run() -> void:
 root.size=Vector2i(1400,900);world=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=load("res://scripts/weapon_lighting.gd").environment();world.add_child(env)
 key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-35,0);key.light_energy=1.5;key.light_color=Color(1,.97,.92);world.add_child(key)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_energy=.25;fill.light_color=Color(.7,.82,1);world.add_child(fill)
 camera=Camera3D.new();camera.near=.005;camera.fov=43;world.add_child(camera);camera.current=true;camera.position=Vector3(1.3,.025,0);camera.look_at(Vector3.ZERO)
 var doc:=GLTFDocument.new();var state:=GLTFState.new()
 assert(doc.append_from_file("res://art_source/weapons/lc01/tripo-rebuild-v3/02-low-pbr/model.glb",state)==OK)
 var gun: Node3D=doc.generate_scene(state);var pivot:=Node3D.new();world.add_child(pivot);pivot.add_child(gun)
 var box: AABB;var first:=true
 var all:=meshes(gun)
 for mesh in all:
  var b: AABB=mesh.global_transform*mesh.get_aabb();box=b if first else box.merge(b);first=false
 gun.position=-box.get_center();pivot.scale=Vector3.ONE*(.905/box.size.z);pivot.rotation.y=PI
 var flat:=ShaderMaterial.new();var shader:=Shader.new()
 shader.code="shader_type spatial;render_mode cull_disabled;void fragment(){NORMAL=normalize(cross(dFdx(VERTEX),dFdy(VERTEX)));ALBEDO=vec3(.45);ROUGHNESS=.65;}"
 flat.shader=shader
 var smooth:=StandardMaterial3D.new();smooth.albedo_color=Color(.45,.45,.45);smooth.roughness=.65;smooth.cull_mode=BaseMaterial3D.CULL_DISABLED
 for mode in ["smooth","flat"]:
  for mesh in all:mesh.material_override=flat if mode=="flat" else smooth
  await wait_frames();await RenderingServer.frame_post_draw
  assert(root.get_texture().get_image().save_png("res://docs/validation/tripo-high-performance/low-"+mode+".png")==OK)
 print("SHADING_DIAGNOSTIC_COMPLETE no vertex/UV edits, no baked asset saved");quit()
