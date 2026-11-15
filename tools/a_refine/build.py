"""A design refinement: deterministic paired high/low meshes, exact gameplay envelope."""
import bpy,math,json,sys
from pathlib import Path
from mathutils import Vector,Matrix
R=Path(__file__).resolve().parents[2];O=R/'art_source/environment/A-refine-v2';O.mkdir(exist_ok=True)
M={
 'coat':((.42,.45,.47,1),.54,0), 'lid':((.48,.50,.51,1),.5,0),
 'frame':((.035,.052,.065,1),.38,.85), 'door':((.075,.095,.105,1),.5,.05),
 'alloy':((.36,.40,.43,1),.3,.85), 'rubber':((.012,.018,.021,1),.82,0),
 'orange':((.85,.21,.018,1),.58,0), 'cyan':((.025,.65,.8,1),.3,0)}
materials={}
for name,(color,rough,metal) in M.items():
 m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=color;bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal
 materials[name]=m

def finish(o,name,mat,bevel=0):
 o.name=name;o.data.materials.clear();o.data.materials.append(materials[mat])
 bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('ManufacturedEdges','BEVEL');mod.width=bevel;mod.segments=4 if HIGH else 1
  bpy.ops.object.modifier_apply(modifier=mod.name)
 for f in o.data.polygons:f.use_smooth=False
 objs.append(o);return o

def box(name,p,s,mat='coat',bevel=.01):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.scale=s;return finish(o,name,mat,bevel)
def cylinder(name,p,r,h,mat='alloy',axis='Z'):
 rot=(0,math.pi/2,0) if axis=='X' else ((math.pi/2,0,0) if axis=='Y' else (0,0,0))
 bpy.ops.mesh.primitive_cylinder_add(vertices=24 if HIGH else 10,radius=r,depth=h,location=p,rotation=rot)
 return finish(bpy.context.object,name,mat,.004 if HIGH else 0)
def bolt(name,p,axis='Z'):
 if not HIGH:return
 cylinder(name,p,.018,.012,'alloy',axis)
 # Small raised slot in high only, becomes actual tangent-space detail.
 size={'Z':(.023,.004,.002),'Y':(.023,.002,.004),'X':(.002,.023,.004)}[axis]
 box(name+'_slot',p,size,'frame',0)
def cable(name,points,radius):
 # Explicit smooth tube mesh with stable transported cross section, sealed ends.
 steps=8 if HIGH else 4;sides=16 if HIGH else 8
 pts=[]
 for seg in range(len(points)-1):
  p0=Vector(points[max(0,seg-1)]);p1=Vector(points[seg]);p2=Vector(points[seg+1]);p3=Vector(points[min(len(points)-1,seg+2)])
  for j in range(steps):
   t=j/steps;pts.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
 pts.append(Vector(points[-1]));verts=[];faces=[]
 for i,p in enumerate(pts):
  tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized();u=tangent.cross(Vector((0,1,0)))
  if u.length<.01:u=tangent.cross(Vector((1,0,0)))
  u.normalize();v=tangent.cross(u).normalized()
  for j in range(sides):verts.append(p+radius*(math.cos(j*math.tau/sides)*u+math.sin(j*math.tau/sides)*v))
 for i in range(len(pts)-1):
  for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,(i+1)*sides+(j+1)%sides,(i+1)*sides+j))
 faces.append(tuple(reversed(range(sides))));faces.append(tuple((len(pts)-1)*sides+j for j in range(sides)))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);finish(o,name,'rubber')
 for f in o.data.polygons:f.use_smooth=True

def build():
 # Hollow manufactured shell; actual recessed side bay, not a dark patch on a solid box.
 box('Floor',(-.18,0,.27),(3.28,3.62,.18),'frame',.02)
 box('LeftWall',(-1.76,0,.72),(.12,3.56,.8),'coat',.025)
 for y in [-1.74,1.74]:box('EndWall',(-.18,y,.72),(3.28,.12,.8),'coat',.025)
 for y in [-1.38,1.38]:box('PowerBaySide',(1.40,y,.72),(.12,.72,.8),'coat',.02)
 box('PowerBayUpper',(1.40,0,1.04),(.12,2.08,.16),'coat',.01)
 box('PowerBayLower',(1.40,0,.37),(.12,2.08,.16),'coat',.01)
 box('PowerBayBack',(1.25,0,.70),(.08,2.06,.58),'frame',.015)
 # Six segmented lift-off lids and a continuous gasket bed.
 box('TopGasket',(-.18,0,1.113),(3.36,3.64,.046),'rubber',.015)
 for i,x in enumerate([-1.29,-.18,.93]):
  for j,y in enumerate([-.89,.89]):
   box(f'Lid_{i}_{j}',(x,y,1.159),(1.078,1.735,.072),'lid',.025)
   # Recessed-looking flush lifting pocket with small inset metal grip.
   box('LiftPocket',(x,y-.53,1.197),(.23,.10,.006),'rubber',.012)
   box('LiftGrip',(x,y-.53,1.199),(.16,.027,.002),'alloy',0)
   for dx in [-.43,.43]:
    for dy in [-.74,.74]:bolt('LidCaptiveScrew',(x+dx,y+dy,1.194))
 # Front access doors with real overlapping seals, two hinges and visible latches.
 for i,x in enumerate([-1.28,-.18,.92]):
  box('DoorSeal',(x,-1.81,.69),(1.04,.028,.72),'rubber',.022)
  box('AccessDoor',(x,-1.836,.69),(.982,.035,.66),'door',.025)
  for z in [.48,.9]:
   box('Hinge',(x-.46,-1.868,z),(.075,.035,.13),'alloy',.009)
   box('Latch',(x+.41,-1.871,z),(.095,.035,.09),'alloy',.012)
   box('LatchInset',(x+.41,-1.891,z),(.041,.003,.035),'frame',.003)
  box('DoorLabel',(x,-1.857,.9),(.19,.008,.033),'alloy',.003)
  if i==1:box('DiagnosticStrip',(x,-1.864,.83),(.28,.009,.025),'cyan',.003)
  for dx in [-.4,.4]:bolt('DoorFastener',(x+dx,-1.86,.43),'Y')
 # Rear service panels, different function but same manufacturing grammar.
 for x in [-1.02,.66]:
  box('RearSeal',(x,1.807,.70),(1.5,.025,.66),'rubber',.016)
  box('RearCover',(x,1.83,.70),(1.44,.03,.60),'coat',.016)
  for dx in [-.62,.62]:
   for z in [.47,.93]:bolt('RearScrew',(x+dx,1.85,z),'Y')
 # Three recessed, keyed power sockets, strain relief boots and curved cables.
 for n,y in enumerate([-.62,0,.62]):
  box('SocketMount',(1.31,y,.78),(.04,.31,.32),'alloy',.015)
  cylinder('SocketGasket',(1.34,y,.78),.115,.04,'rubber','X')
  cylinder('KeyedCollar',(1.385,y,.78),.093,.07,'orange','X')
  cylinder('ConnectorPlug',(1.445,y,.78),.072,.08,'alloy','X')
  cylinder('StrainBoot',(1.515,y,.78),.068,.10,'rubber','X')
  for dx in [1.49,1.52,1.55]:cylinder('BootRib',(dx,y,.78),.072,.012,'rubber','X')
  cable('PowerCable',[(1.55,y,.78),(1.73,y,.73),(1.80,y,.49),(1.80,y+.08,.27),(1.72,y+.23,.18),(1.52,y+.28,.18)],.043)
  box('CableClip',(1.80,y+.03,.42),(.115,.13,.06),'alloy',.008)
  box('PortID',(1.305,y,.97),(.012,.14,.034),'orange',.002)
 # Side cable trough fits inside footprint, cable ends terminate inside the skid.
 box('CableTrough',(1.61,.16,.15),(.36,2.38,.09),'frame',.015)
 # Four foot assemblies with actual fork/lifting openings.
 for x in [-1.61,1.28]:
  for y in [-1.57,1.57]:
   box('FootPlate',(x,y,.035),(.40,.48,.07),'alloy',.012)
   for dx in [-.14,.14]:box('FootWeb',(x+dx,y,.13),(.09,.40,.16),'frame',.008)
   box('FootRoof',(x,y,.225),(.39,.43,.07),'frame',.01)
   for dy in [-.19,.19]:bolt('Anchor',(x,y+dy,.075))
 # Skid rails and small functional safety colors, no decorative wall of greebles.
 for y in [-1.85,1.85]:box('SkidRail',(-.18,y,.20),(3.42,.09,.20),'frame',.012)
 for x in [-1.65,1.29]:
  box('SafetyCorner',(x,-1.803,.34),(.22,.016,.12),'orange',.006)
 box('TopWarning',(-.18,-1.64,1.199),(.34,.13,.002),'orange',0)
 # High-only shallow panel grooves provide genuine projected detail.
 if HIGH:
  for x in [-1.29,-.18,.93]:
   for y in [-.89,.89]:
    for dx in [-.35,.35]:box('PressedLidLine',(x+dx,y,1.197),(.006,1.10,.004),'coat',.001)

reports={}
for HIGH in [True,False]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);objs=[];build()
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name='A_high' if HIGH else 'A_low'
 bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # Consistent outer winding on authored closed shells.
 import bmesh
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 if not HIGH:
  mod=o.modifiers.new('Triangulate','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
  bm=bmesh.new();bm.from_mesh(o.data)
  dead=[f for f in bm.faces if f.calc_area()<1e-12]
  bmesh.ops.delete(bm,geom=dead,context='FACES_ONLY')
  bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001)
  bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
  bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.008);bpy.ops.uv.average_islands_scale();bpy.ops.uv.pack_islands(rotate=True,margin_method='FRACTION',margin=.004);bpy.ops.object.mode_set(mode='OBJECT')
 tris=sum(len(f.vertices)-2 for f in o.data.polygons);stage='high' if HIGH else 'low'
 points=[v.co for v in o.data.vertices];bounds=[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]]
 assert all(bounds[0][i]>=[-1.9,-1.9,0][i]-.001 and bounds[1][i]<=[1.9,1.9,1.201][i]+.001 for i in range(3)),bounds
 if not HIGH:assert tris<=8000,tris
 folder=O/('01-high' if HIGH else '02-low');folder.mkdir(exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(folder/f'A-{stage}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(folder/f'A-{stage}.glb'),export_format='GLB',use_selection=True,export_materials='NONE',export_tangents=not HIGH)
 reports[stage]={'triangles':tris,'bounds':bounds,'vertices':len(o.data.vertices),'materials':len(o.data.materials)}
 print('A_BUILD',stage,tris,flush=True)
(O/'geometry.json').write_text(json.dumps(reports,indent=2))
