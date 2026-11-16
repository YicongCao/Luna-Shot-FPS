extends SceneTree
const OUT="res://docs/validation/tripo-weapon-v3/"
var world: Node3D
var camera: Camera3D
var key: DirectionalLight3D
var label: Label
var checks: Array=[]
func _initialize() -> void: run.call_deferred()
func wait_frames(n:=20) -> void:
 for i in n:await process_frame
func shot(name: String) -> void:
 await wait_frames();await RenderingServer.frame_post_draw
 var ok:=root.get_texture().get_image().save_png(OUT+name+".png")==OK
 checks.append({"check":name,"passed":ok})
func meshes(node: Node) -> Array[MeshInstance3D]:
 var found: Array[MeshInstance3D]=[]
 if node is MeshInstance3D:found.append(node)
 for c in node.get_children():found.append_array(meshes(c))
 return found
func run() -> void:
 root.size=Vector2i(1400,900);world=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=load("res://scripts/weapon_lighting.gd").environment();world.add_child(env)
 key=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-35,0);key.light_energy=1.5;key.light_color=Color(1,.97,.92);world.add_child(key)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_energy=.25;fill.light_color=Color(.7,.82,1);world.add_child(fill)
 camera=Camera3D.new();camera.near=.005;camera.fov=43;world.add_child(camera);camera.current=true
 var layer:=CanvasLayer.new();root.add_child(layer);label=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",19);layer.add_child(label)
 for stage in ["01-high-pbr","02-low-pbr"]:
  var state:=GLTFState.new();var doc:=GLTFDocument.new()
  var path: String="res://art_source/weapons/lc01/tripo-rebuild-v3/"+stage+"/model.glb"
  var err:=doc.append_from_file(path,state)
  checks.append({"check":stage+"_gltf_import","passed":err==OK})
  if err!=OK:quit(1);return
  var gun: Node3D=doc.generate_scene(state);var pivot:=Node3D.new();world.add_child(pivot);pivot.add_child(gun)
  # Remote glTF units are normalized. Only rigid orientation and uniform scale.
  var all:=meshes(gun);var box: AABB;var first:=true
  for mesh in all:
   var b: AABB=mesh.global_transform*mesh.get_aabb()
   box=b if first else box.merge(b);first=false
  var scale_factor:=.905/box.size.z
  gun.position=-box.get_center();pivot.scale=Vector3.ONE*scale_factor;pivot.rotation.y=PI
  var saved: Dictionary={}
  for mesh in all:
   for i in mesh.mesh.get_surface_count():saved[str(mesh.get_instance_id())+"_"+str(i)]=mesh.get_active_material(i)
  for mode in ["pbr","clay","normal-off"]:
   for mesh in all:
    for i in mesh.mesh.get_surface_count():
     var original: Material=saved[str(mesh.get_instance_id())+"_"+str(i)]
     if mode=="clay":
      var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.45,.45,.45);mat.roughness=.65;mesh.set_surface_override_material(i,mat)
     elif mode=="normal-off" and original is BaseMaterial3D:
      var mat: BaseMaterial3D=original.duplicate();mat.normal_enabled=false;mesh.set_surface_override_material(i,mat)
     else:mesh.set_surface_override_material(i,original)
   for view in ["hero","side"]:
    camera.position=Vector3(1.05,.32,.70) if view=="hero" else Vector3(1.3,.025,0)
    camera.look_at(Vector3.ZERO);label.text="ML17 / TRIPO "+stage+" / "+mode+" / "+view+"\nNATIVE GODOT / original service materials / no local PBR rewrite"
    await shot(stage+"-"+mode+"-"+view)
  pivot.queue_free();await wait_frames(3)
 var failures:=checks.filter(func(c):return not c.passed).size()
 FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string},"\t"));quit(0 if failures==0 else 1)
