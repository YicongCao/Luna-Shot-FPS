extends SceneTree
const OUT="res://docs/validation/tripo-high-performance/"
func _initialize() -> void:run.call_deferred()
func meshes(node: Node) -> Array[MeshInstance3D]:
 var found: Array[MeshInstance3D]=[]
 if node is MeshInstance3D:found.append(node)
 for c in node.get_children():found.append_array(meshes(c))
 return found
func run() -> void:
 var mode:="normal-pbr"
 var bins: Dictionary={};var switch_materials: Array[BaseMaterial3D]=[]
 if mode not in ["baseline","normal-off","normal-pbr"]:push_error("Set RIFLE_PERF_MODE");quit(1);return
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1600,1000);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
 var world: Node3D=load("res://scenes/training.tscn").instantiate();root.add_child(world)
 world.player.qa_mode=true;world.player.set_physics_process(false);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 world.player.weapon.set_energy_enabled(false)
 var candidate: Node3D
 var import_start:=Time.get_ticks_msec()
 if mode!="baseline":
  var doc:=GLTFDocument.new();var state:=GLTFState.new()
  var err:=doc.append_from_file("res://art_source/weapons/lc01/tripo-rebuild-v3/01-high-pbr/model.glb",state)
  if err!=OK:push_error("High mesh import failed");quit(1);return
  var gun: Node3D=doc.generate_scene(state);candidate=Node3D.new();world.player.weapon.get_parent().add_child(candidate)
  var align:=Node3D.new();candidate.add_child(align);align.add_child(gun)
  var box: AABB;var first:=true
  for mesh in meshes(gun):
   var b: AABB=mesh.global_transform*mesh.get_aabb();box=b if first else box.merge(b);first=false
   if true:
    for i in mesh.mesh.get_surface_count():
     var mat: BaseMaterial3D=mesh.get_active_material(i).duplicate();mat.normal_enabled=true;mesh.set_surface_override_material(i,mat);switch_materials.append(mat)
  gun.position=-box.get_center();align.scale=Vector3.ONE*(.905/box.size.z);align.rotation.y=PI;align.position=Vector3(0,.034,-.2125)
  world.player.weapon.hide()
 var import_ms:=Time.get_ticks_msec()-import_start
 # Full training map and original independent weapon viewport are both active.
 # Freeze player motion/collisions only, then sweep spawn camera through equal angles.
 var started:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-started<5000:
  if candidate:candidate.transform=world.player.weapon.transform
  await process_frame
 var samples: Array[float]=[];started=Time.get_ticks_msec();var last:=Time.get_ticks_usec();var shot:=false
 while Time.get_ticks_msec()-started<60000:
  var elapsed_ms:=Time.get_ticks_msec()-started
  var block:=mini(int(elapsed_ms/10000),5)
  var enabled:=block%2==1
  for mat in switch_materials:mat.normal_enabled=enabled
  var t: float=elapsed_ms/60000.0
  world.player.rotation.y=sin(t*TAU)*.55;world.player.head.rotation.x=-.08+.035*sin(t*TAU*2)
  if candidate:candidate.transform=world.player.weapon.transform
  await process_frame
  var now:=Time.get_ticks_usec();var interval: float=(now-last)/1000.0;samples.append(interval);last=now
  if elapsed_ms%10000>1500:
   if not bins.has(str(block)):bins[str(block)]=[]
   bins[str(block)].append(interval)
  if t>.49 and not shot:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+"paired.png");shot=true;last=Time.get_ticks_usec()
 var seconds: float=(Time.get_ticks_msec()-started)/1000.0
 var total:=0.0
 for sample in samples:total+=sample
 samples.sort()
 var block_results: Array=[]
 for id in bins:
  var b: Array=bins[id];b.sort();var sum_ms:=0.0
  for value in b:sum_ms+=value
  block_results.append({"block":int(id),"normal_enabled":int(id)%2==1,"frames":b.size(),"average_fps":1000.0*b.size()/sum_ms,"p50_ms":b[int(b.size()*.5)],"p95_ms":b[int(b.size()*.95)]})
 var result={"blocks":block_results,"mode":mode,"seconds":seconds,"frames":samples.size(),"average_fps":samples.size()/seconds,"mean_frame_ms":total/samples.size(),"p50_ms":samples[int(samples.size()*.5)],"p95_ms":samples[int(samples.size()*.95)],"import_ms":import_ms,"vsync":"disabled","max_fps":0,"resolution":[1600,1000],"weapon_viewport_size":world.player.weapon_camera.get_viewport().size,"renderer":RenderingServer.get_current_rendering_method(),"engine":Engine.get_version_info().string,"route":"full training map, spawn yaw sweep +-0.55rad; no shooting, no physics movement; default lighting/bloom active; weapon energy off","source":"ML06 default" if mode=="baseline" else "Tripo 1,934,290 triangle high PBR; normal map toggle only","texture_bytes":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED),"objects_last_frame":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),"primitives_last_frame":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)}
 FileAccess.open(OUT+"paired.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("RIFLE_PERF ",JSON.stringify(result));quit()
