extends SceneTree
const OUT="res://docs/validation/hunyuan-weapon-v1/"
var world: Node3D
var camera: Camera3D
var label: Label
var checks: Array=[]
func _initialize() -> void: run.call_deferred()
func frames(n:=8) -> void:
 for i in n:await process_frame
func meshes(node: Node) -> Array[MeshInstance3D]:
 var all: Array[MeshInstance3D]=[]
 if node is MeshInstance3D:all.append(node)
 for c in node.get_children():all.append_array(meshes(c))
 return all
func run() -> void:
 root.size=Vector2i(1400,900);world=Node3D.new();root.add_child(world)
 var env:=WorldEnvironment.new();env.environment=load("res://scripts/weapon_lighting.gd").environment();world.add_child(env)
 env.environment.glow_enabled=false
 var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-35,-35,0);key.light_energy=1.5;key.light_color=Color(1,.97,.92);world.add_child(key)
 var fill:=DirectionalLight3D.new();fill.rotation_degrees=Vector3(20,140,0);fill.light_energy=.25;fill.light_color=Color(.7,.82,1);world.add_child(fill)
 camera=Camera3D.new();camera.near=.005;camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=.72;world.add_child(camera);camera.current=true
 var layer:=CanvasLayer.new();root.add_child(layer);label=Label.new();label.position=Vector2(24,20);label.add_theme_font_size_override("font_size",19);layer.add_child(label)
 var stages={"hy-high":"art_source/weapons/lc01/hunyuan-v1/high.glb","hy-low":"art_source/weapons/lc01/hunyuan-v1/low.glb","hy-pbr":"art_source/weapons/lc01/hunyuan-v1/pbr.glb","tripo-high":"art_source/weapons/lc01/tripo-rebuild-v3/01-high-pbr/model.glb","tripo-low":"art_source/weapons/lc01/tripo-rebuild-v3/02-low-pbr/model.glb","ml06":"assets/weapons/lc01/lc01.glb","ml07":"assets/weapons/lc01/ls01_v1/weapon.glb"}
 for stage in stages:
  var state:=GLTFState.new();var doc:=GLTFDocument.new();var err:=doc.append_from_file("res://"+stages[stage],state)
  checks.append({"id":stage+"_import","passed":err==OK})
  if err!=OK:quit(1);return
  var gun: Node3D=doc.generate_scene(state);var pivot:=Node3D.new();world.add_child(pivot);pivot.add_child(gun)
  if stage=="ml07":
   for m in meshes(gun):
    if m.name=="IndustrialKit":m.free()
  var all:=meshes(gun);var box: AABB;var first:=true;var triangle_count:=0
  for mesh in all:
   var b: AABB=mesh.global_transform*mesh.get_aabb();box=b if first else box.merge(b);first=false
   for i in mesh.mesh.get_surface_count():
    var arrays=mesh.mesh.surface_get_arrays(i);triangle_count+=(arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null and arrays[Mesh.ARRAY_INDEX].size()>0 else arrays[Mesh.ARRAY_VERTEX].size()/3)
  gun.position=-box.get_center();pivot.scale=Vector3.ONE*(.905/box.size.z)
  if stage.begins_with("tripo") or stage.begins_with("hy-"):pivot.rotation.y=PI
  var bindings={}
  if stage=="ml07":bindings=JSON.parse_string(FileAccess.get_file_as_string("res://assets/weapons/lc01/ls01_v1/bindings.json"))
  var saved={}
  for mesh in all:
   for i in mesh.mesh.get_surface_count():
    var mat: Material=mesh.get_active_material(i)
    if stage=="ml06":mat=load("res://scripts/ls01_materials.gd").make("","res://assets/weapons/lc01/")
    elif stage=="ml07":mat=load("res://scripts/ls01_materials.gd").make(bindings[String(mesh.name)].atlas)
    if mat is BaseMaterial3D:
     mat=mat.duplicate();mat.emission_enabled=false
    saved[str(mesh.get_instance_id())+"_"+str(i)]=mat
  var modes=["clay"] if stage in ["hy-high","hy-low"] else ["pbr","clay","normal-off"]
  for mode in modes:
   for mesh in all:
    for i in mesh.mesh.get_surface_count():
     var original: Material=saved[str(mesh.get_instance_id())+"_"+str(i)]
     if mode=="clay":
      var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.45,.45,.45);mat.roughness=.65;mesh.set_surface_override_material(i,mat)
     elif mode=="normal-off" and original is BaseMaterial3D:
      var mat: BaseMaterial3D=original.duplicate();mat.normal_enabled=false;mesh.set_surface_override_material(i,mat)
     else:mesh.set_surface_override_material(i,original)
   for view in ["hero","side","reverse","detail"]:
    if mode=="normal-off" and view!="hero":continue
    var center:=Vector3.ZERO
    camera.size=.72
    if view=="hero":camera.position=Vector3(1.05,.32,.70)
    elif view=="side":camera.position=Vector3(1.3,.025,0)
    elif view=="reverse":camera.position=Vector3(-1.05,.32,-.70)
    else:camera.size=.32;center=Vector3(0,-.06,-.03);camera.position=center+Vector3(1.3,.06,0)
    camera.look_at(center);label.text=stage+" / "+mode+" / "+view+" / "+str(triangle_count)+" tris\nNATIVE GODOT / SAME LIGHT + CAMERA / BODY ONLY / EMISSION & BLOOM OFF"
    await frames();await RenderingServer.frame_post_draw
    var name=stage+"-native-"+mode+"-"+view
    checks.append({"id":name,"passed":root.get_texture().get_image().save_png(OUT+name+".png")==OK})
  checks.append({"id":stage+"_metrics","passed":true,"triangles":triangle_count,"surfaces":saved.size(),"bounds_before_normalize":str(box)})
  pivot.free();await frames(2)
 var fail=checks.filter(func(c):return not c.passed).size()
 FileAccess.open(OUT+"native.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":fail,"engine":Engine.get_version_info().string,"renderer":RenderingServer.get_current_rendering_method(),"scope":"static isolated native material scene, no gameplay or performance claim"},"\t"));quit(0 if fail==0 else 1)
