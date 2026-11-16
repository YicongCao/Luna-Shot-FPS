"""ML15 precise paired mechanical geometry, constrained by the module interfaces."""
import bpy,bmesh,math,json,sys,argparse
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).parent));from materials import create
R=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--asset',required=True,choices=['B1','B2','C','D','E']);a.add_argument('--out');a.add_argument('--seed',type=int,default=20261116)
args=a.parse_args(sys.argv[sys.argv.index('--')+1:]);A=args.asset;O=Path(args.out or R/'art_source/environment/refine-v2'/A);O.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
M={k:create(k) for k in ['coat','dark','steel','rubber','yellow','core']};parts=[];current=[];groups={};HIGH=False

def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def finish(o,name,kind,bevel=0):
 o.name=name;o.data.materials.clear();o.data.materials.append(M[kind]);active(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 # Converted capped curves have duplicate boundary vertices; weld before normals.
 bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
 bounds=[tuple(fn(v.co[i] for v in o.data.vertices) for i in range(3)) for fn in [min,max]]
 for attr,val in zip(['panel_min','panel_max'],bounds):
  attribute=o.data.attributes.new(attr,'FLOAT_VECTOR','POINT')
  for item in attribute.data:item.vector=val
 if bevel:
  m=o.modifiers.new('Narrow machined bevel','BEVEL');m.width=bevel;m.segments=3 if HIGH else 1;bpy.ops.object.modifier_apply(modifier=m.name)
 # Flat plane normals plus smooth chamfer normals via weighted normals, frozen before bake.
 for p in o.data.polygons:p.use_smooth=True
 m=o.modifiers.new('Stable face normals','WEIGHTED_NORMAL');m.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=m.name)
 current.append(o);return o

def box(name,c,s,k='coat',b=.012,rot=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=c);o=bpy.context.object;o.scale=s
 if rot:o.rotation_euler=rot
 return finish(o,name,k,b)
def cyl(name,c,r,d,k='steel',axis=(0,0,1)):
 bpy.ops.mesh.primitive_cylinder_add(vertices=24 if HIGH else 12,radius=r,depth=d,location=c);o=bpy.context.object;o.rotation_euler=Vector((0,0,1)).rotation_difference(Vector(axis)).to_euler();return finish(o,name,k,.003)
def bolt(c,axis=(0,-1,0),r=.025):
 o=cyl('Captive screw',c,r,.018,'steel',axis)
 if HIGH:
  # Actual recessed slot, not paint: simple machining boolean on high only.
  active(o);bpy.ops.mesh.primitive_cube_add(size=1,location=Vector(c)+Vector(axis)*.008);cut=bpy.context.object;cut.scale=(r*1.3,r*.22,.02);cut.rotation_euler=Vector((0,0,1)).rotation_difference(Vector(axis)).to_euler();bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  active(o);m=o.modifiers.new('Recessed drive slot','BOOLEAN');m.object=cut;m.operation='DIFFERENCE';bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cut,do_unlink=True)
 return o

def tube(name,points,r=.075,k='steel'):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=8 if HIGH else 4;curve.bevel_depth=r;curve.bevel_resolution=3 if HIGH else 1;curve.use_fill_caps=True
 spline=curve.splines.new('BEZIER');spline.bezier_points.add(len(points)-1)
 for p,c in zip(spline.bezier_points,points):p.co=c;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);active(o);bpy.ops.object.convert(target='MESH');return finish(bpy.context.object,name,k)

def group(name,fn,cage=.014):
 global current
 current=[];fn()
 for o in current:active(o);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in current:o.select_set(True)
 bpy.context.view_layer.objects.active=current[0];bpy.ops.object.join();o=bpy.context.object;o.name=name+('_high' if HIGH else '_low')
 groups.setdefault(name,{})['high' if HIGH else 'low']=o;groups[name]['cage_distance']=cage

def frame():
 box('Base',(0,0,.16),(3.7,3.6,.30),'dark',.025)
 for x in [-1.55,1.55]:
  for y in [-1.5,1.5]:
   box('Foot',(x,y,.04),(.42,.42,.08),'steel',.012)
   box('Post',(x,y,3),(.16,.16,5.72),'dark',.012)
   bolt((x,y,.089),(0,0,1),.035)
 # Top is lowered locally to fit red lenses within the six metre envelope.
 box('Cap',(0,0,5.69),(3.5,3.45,.17),'dark',.025)
 for x in [-.84,.84]:
  for y in [-.81,.81]:
   box('CapPanel',(x,y,5.787),(1.62,1.56,.025),'dark',.005)
   for dx in [-.65,.65]:bolt((x+dx,y,5.81),(0,0,1))
def cabinet():
 box('Cabinet',(0,0,.53),(2.95,2.85,.46),'coat',.018)
 for x in [-.72,.72]:
  box('DoorGasket',(x,-1.443,.54),(1.39,.018,.38),'rubber',.007)
  box('Door',(x,-1.46,.54),(1.32,.025,.33),'coat',.008)
  box('Latch',(x+.42,-1.482,.54),(.09,.025,.12),'steel',.006)
  for dx in [-.56,.56]:bolt((x+dx,-1.478,.54))
  for y in [-1.46,1.46]:box('Safety',(x,y,.39),(.3,.012,.045),'yellow',.001)

def layer(i):
 z=1.03+i*.77
 # Open frame, not a solid slab; radiator fins retain real dark gaps.
 for y in [-1.42,1.42]:box('Rail',(0,y,z),(3.10,.12,.14),'coat',.012)
 for x in [-1.48,1.48]:box('SideRail',(x,0,z),(.12,2.84,.14),'coat',.01)
 for j in range(11):box('RadiatorFin',(0,0,z+.12+j*.037),(2.72,2.64,.016),'core',.001)
 for x in [-1.37,1.37]:
  box('EndPlate',(x,0,z+.31),(.07,2.67,.43),'dark',.006)
  for y in [-1.489,1.489]:bolt((x,y,z),(0,1 if y>0 else -1,0))

def pipes():
 for y in [-.82,.82]:
  tube('Coolant',[(1.26,y,.65),(1.70,y,.65),(1.79,y,.95),(1.79,y,5.05),(1.67,y,5.38),(1.26,y,5.38)],.085)
  for z in [1.2,2.35,3.5,4.65]:
   cyl('YellowCoupling',(1.79,y,z),.115,.12,'yellow')
   box('PipeClamp',(1.69,y,z),(.22,.27,.055),'steel',.006)
   bolt((1.82,y-.135,z),(0,-1,0),.022)

def b2_frame():
 box('Base',(0,0,.16),(3.7,3.6,.30),'dark',.025)
 for x in [-1.55,1.55]:
  for y in [-1.5,1.5]:
   box('Foot',(x,y,.04),(.42,.42,.08),'steel',.012)
   box('Post',(x,y,3),(.16,.16,5.72),'dark',.012)
 for y in [-1.5,1.5]:box('TopCrossbar',(0,y,5.73),(3.45,.30,.15),'coat',.015)
 for x in [-1.5,1.5]:box('TopSide',(x,0,5.73),(.30,3.0,.15),'coat',.015)
 # Central light service strut keeps a real open shaft down the middle.
 box('TopTie',(0,0,5.73),(.20,3,.15),'dark',.012)

def b2_bank(sign):
 x=sign*1.04
 for z in [.85,5.25]:box('BankCap',(x,0,z),(1.05,2.9,.18),'coat',.015)
 for y in [-1.55,1.55]:
  for z in [1.0,5.1]:box('BankEndRail',(x,y,z),(1.05,.08,.10),'dark',.008)
 for j in range(9):
  xx=x+(j-4)*.105
  box('VerticalFin',(xx,0,3.05),(.045,3.10,4.20),'coat',.004)
 # Visible vertical ivory protection blades, not solid side boxes.
 for xx in [x-.50,x+.50]:
  for y in [-1.48,1.48]:
   box('BankGuard',(xx,y,3.05),(.065,.08,4.35),'coat',.008)
   for z in [1.02,3.05,5.08]:bolt((xx,y,z),(0,1 if y>0 else -1,0))

def b2_pipes():
 for x in [-.22,.22]:
  tube('CentralCoolant',[(x*3,-1.32,.65),(x,-1.32,.95),(x,-1.32,1.5),(x,-1.32,4.4),(x,-1.32,4.9),(x*3,-1.32,5.40)],.065)
  for z in [1.3,2.6,3.9,5.0]:
   cyl('Coupling',(x,-1.32,z),.09,.10,'yellow')
   box('Clamp',(x,-1.4,z),(.21,.05,.06),'steel',.005)
 # Clear mounting pads behind ML14's cassette; no generated or duplicate blades.
 for z in [1.7,3.0,4.3]:
  for y in [-.70,.70]:
   box('FanMount',(1.62,y,z),(.10,.13,1.10),'dark',.01)
   bolt((1.68,y,z),(1,0,0))

def build():
 if A=='B1':
  group('Frame',frame);group('BaseCabinet',cabinet)
  for i in range(6):group('Radiator%02d'%i,lambda i=i:layer(i),.004)
  group('CoolantPipes',pipes,.018)
 elif A=='B2':
  group('Frame',b2_frame);group('BaseCabinet',cabinet)
  for sign in [-1,1]:group('VerticalBank'+str(sign),lambda sign=sign:b2_bank(sign),.005)
  group('PipesAndMounts',b2_pipes,.018)
 else:raise RuntimeError('Asset recipe not authored yet; do not fall back to generic geometry')

for HIGH in [True,False]:build()
# Fixed triangles and common atlas layout across all groups.
lows=[v['low'] for v in groups.values()]
for lo in lows:
 active(lo);m=lo.modifiers.new('Frozen triangles','TRIANGULATE');m.keep_custom_normals=True;bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.object.select_all(action='DESELECT')
for lo in lows:lo.select_set(True)
bpy.context.view_layer.objects.active=lows[0];bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.16,island_margin=.008);bpy.ops.uv.pack_islands(rotate=True,margin=.008,margin_method='FRACTION');bpy.ops.object.mode_set(mode='OBJECT')
records=[]
for name,p in groups.items():
 lo=p['low'];hi=p['high'];ca=lo.copy();ca.data=lo.data.copy();bpy.context.collection.objects.link(ca);ca.name=name+'_cage'
 for v in ca.data.vertices:v.co+=v.normal*p['cage_distance']
 ca.hide_render=True;ca.hide_set(True);ca.display_type='WIRE';hi.hide_render=True;hi.hide_set(True)
 records.append({'name':name,'group':'body','low':lo.name,'high':hi.name,'cage':ca.name,'cage_distance':p['cage_distance'],'triangles':len(lo.data.polygons)})
points=[v.co for lo in lows for v in lo.data.vertices];bounds=[[min(v[i] for v in points) for i in range(3)],[max(v[i] for v in points) for i in range(3)]]
triangles=sum(p['triangles'] for p in records);assert triangles<=dict(B1=20000,B2=20000,C=12000,D=16000,E=24000)[A],triangles
assert bounds[0][0]>=-2 and bounds[1][0]<=2 and bounds[0][1]>=-2 and bounds[1][1]<=2 and bounds[1][2]<=6,bounds
(O/'02-geometry').mkdir(exist_ok=True);bpy.ops.wm.save_as_mainfile(filepath=str(O/'02-geometry/paired.blend'))
manifest={'asset':A,'seed':args.seed,'pairs':records,'triangles':triangles,'bounds_blender':bounds,'uv_version':'ml15-v1','tripo_role':'Shape reference; precise open assemblies authored locally; generated candidate archived separately','materials':list(M),'high_triangles':sum(sum(len(f.vertices)-2 for f in p['high'].data.polygons) for p in groups.values())}
(O/'manifest.json').write_text(json.dumps(manifest,indent=2));print('ENV_BUILD_COMPLETE',A,triangles,len(records),flush=True)
