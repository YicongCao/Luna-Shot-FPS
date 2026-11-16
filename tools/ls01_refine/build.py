"""ML07 controlled geometry, paired lows/highs/cages and layered source materials.
Blender --background --python build.py -- --out ... --seed 20261115
Coordinates: Blender X right, Y barrel-forward, Z up. Metres.
"""
import bpy, bmesh, math, json, argparse, sys, random
from pathlib import Path
from mathutils import Vector, Matrix
R=Path(__file__).resolve().parents[2]
a=argparse.ArgumentParser();a.add_argument('--out',default=str(R/'art_source/weapons/lc01/ls01-refine-v1'));a.add_argument('--seed',type=int,default=20261115);a.add_argument('--revision',choices=['ml07','ml09'],default='ml07')
args=a.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
O=Path(args.out);O.mkdir(parents=True,exist_ok=True);rng=random.Random(args.seed)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
materials={}; pairs=[]; screws=[]
# Nodes retain all layer masks, rather than baking a single untraceable color recipe.
def material(kind):
 if kind in materials:return materials[kind]
 m=bpy.data.materials.new('LS01_'+kind);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;n.clear()
 def node(t,name=None):
  q=n.new(t)
  if name:q.name=name;q.label=name
  return q
 def mathn(op,x,y=0):
  q=node('ShaderNodeMath');q.operation=op
  for i,v in enumerate([x,y]):
   if hasattr(v,'node'):l.new(v,q.inputs[i])
   else:q.inputs[i].default_value=v
  return q.outputs[0]
 def mix(f,x,y):
  q=node('ShaderNodeMixRGB');q.blend_type='MIX';l.new(f,q.inputs[0])
  for i,v in enumerate([x,y],1):
   if hasattr(v,'node'):l.new(v,q.inputs[i])
   else:q.inputs[i].default_value=(*v,1) if isinstance(v,tuple) else (v,v,v,1)
  return q.outputs[0]
 tc=node('ShaderNodeTexCoord');geom=node('ShaderNodeNewGeometry');vec=tc.outputs['Object']
 def noise(scale,detail=2):
  q=node('ShaderNodeTexNoise');q.inputs['Scale'].default_value=scale;q.inputs['Detail'].default_value=detail;l.new(vec,q.inputs['Vector']);return q.outputs['Fac']
 broad=noise(27);fine=noise(1900);medium=noise(340)
 def image(name,scale):
  v=node('ShaderNodeVectorMath');v.operation='SCALE';v.inputs[3].default_value=scale;l.new(vec,v.inputs[0])
  q=node('ShaderNodeTexImage',name+' artistic source');q.image=bpy.data.images.load(str(O/'01-imagegen'/f'{name}.png'),check_existing=True);q.image.colorspace_settings.name='Non-Color';q.projection='BOX';q.projection_blend=.3;q.extension='REPEAT';l.new(v.outputs[0],q.inputs['Vector']);return q.outputs['Color']
 oil=mathn('MULTIPLY',image('oil',4.7),.85)
 wear=image('wear',7.0)
 edge=mathn('MULTIPLY',mathn('SUBTRACT',geom.outputs['Pointiness'],.498),65)
 edge=mathn('MINIMUM',mathn('MAXIMUM',edge,0),1);edge.node.name='EDGE_INPUT'
 # Expose substrate only along broken convex edges and limited surface scrapes.
 broken=mathn('GREATER_THAN',broad,.48)
 exposed=mathn('MINIMUM',mathn('ADD',mathn('MULTIPLY',edge,broken),mathn('MULTIPLY',wear,.85)),1)
 dust=mathn('MULTIPLY',mathn('MAXIMUM',mathn('SUBTRACT',.42,broad),0),.6)
 colors={'white':(.62,.59,.51),'orange':(.65,.105,.013),'dark':(.035,.047,.063),'steel':(.42,.46,.50),'copper':(.48,.22,.085),'rubber':(.012,.017,.021),'glass':(.002,.012,.018),'black':(.007,.009,.011)}
 color=colors[kind];coated=kind in ['white','orange','dark'];metal=kind in ['steel','copper'];rough={'white':.47,'orange':.38,'dark':.34,'steel':.27,'copper':.25,'rubber':.78,'glass':.16,'black':.56}[kind]
 bc=mix(mathn('MULTIPLY',broad,.13),color,tuple(x*.55 for x in color))
 metallic=1.0 if metal else 0.0
 if coated:
  bc=mix(exposed,bc,(.32,.36,.39));metallic=exposed
 bc=mix(oil,bc,tuple(x*.55 for x in color))
 bc=mix(dust,bc,(.16,.135,.10))
 roughout=mathn('ADD',rough,mathn('MULTIPLY',mathn('SUBTRACT',medium,.5),.16))
 roughout=mathn('SUBTRACT',roughout,mathn('MULTIPLY',oil,.23 if coated or metal else .06));roughout=mathn('ADD',roughout,dust)
 if metal or coated:metallic=mathn('MULTIPLY',metallic,mathn('SUBTRACT',1,dust))
 bs=node('ShaderNodeBsdfPrincipled');out=node('ShaderNodeOutputMaterial');l.new(bs.outputs[0],out.inputs['Surface']);l.new(bc,bs.inputs['Base Color']);l.new(roughout,bs.inputs['Roughness'])
 if hasattr(metallic,'node'):l.new(metallic,bs.inputs['Metallic'])
 else:bs.inputs['Metallic'].default_value=metallic
 # Real shader-normal detail on the high, baked with the high geometry.
 bumps=node('ShaderNodeBump','Micropits + shallow scuffs');bumps.inputs['Distance'].default_value=.000045 if coated else .000012;bumps.inputs['Strength'].default_value=.45
 height=mathn('SUBTRACT',mathn('MULTIPLY',fine,.35),mathn('MULTIPLY',wear,.65));l.new(height,bumps.inputs['Height']);l.new(bumps.outputs[0],bs.inputs['Normal'])
 if kind in ['glass','rubber','black']:bumps.inputs['Strength'].default_value=.10
 # Named emission reroutes are used by the baker for independently inspectable maps.
 for name,sock in [('BaseColor',bc),('Roughness',roughout),('Metallic',metallic),('WearMask',exposed),('OilMask',oil),('Curvature',edge)]:
  q=node('NodeReroute','CHANNEL_'+name)
  if hasattr(sock,'node'):l.new(sock,q.inputs[0])
  else:
   v=node('ShaderNodeValue');v.outputs[0].default_value=sock;l.new(v.outputs[0],q.inputs[0])
 idn=node('ShaderNodeRGB','MATERIAL_ID');idx=list(colors).index(kind)+1;idn.outputs[0].default_value=(idx/10,idx/10,idx/10,1)
 materials[kind]=m;return m

def localize_edge_mask(ob):
 # Flat polygons do not carry useful interpolated pointiness. Restrict wear to a
 # controlled distance from intersections of bounding planes instead.
 pts=[v.co for v in ob.data.vertices];mn=Vector(tuple(min(p[i] for p in pts) for i in range(3)));mx=Vector(tuple(max(p[i] for p in pts) for i in range(3)));width=min(.0025,min(mx-mn)*.16)
 for slot in ob.material_slots:
  if slot.material is None:slot.material=next(m for m in ob.data.materials if m is not None)
  m=slot.material.copy();slot.material=m;n=m.node_tree.nodes;l=m.node_tree.links;tc=next(q for q in n if q.type=='TEX_COORD')
  def vec(op,a,b):
   q=n.new('ShaderNodeVectorMath');q.operation=op
   for i,v in enumerate([a,b]):
    if hasattr(v,'node'):l.new(v,q.inputs[i])
    else:q.inputs[i].default_value=v
   return q.outputs[0]
  def mathn(op,a,b):
   q=n.new('ShaderNodeMath');q.operation=op
   for i,v in enumerate([a,b]):
    if hasattr(v,'node'):l.new(v,q.inputs[i])
    else:q.inputs[i].default_value=v
   return q.outputs[0]
  near=vec('MINIMUM',vec('SUBTRACT',tc.outputs['Object'],mn),vec('SUBTRACT',mx,tc.outputs['Object']))
  sep=n.new('ShaderNodeSeparateXYZ');l.new(near,sep.inputs[0]);x,y,z=[sep.outputs[i] for i in range(3)]
  # Second-smallest axis distance: zero at edges, not over whole side faces.
  median=mathn('MINIMUM',mathn('MINIMUM',mathn('MAXIMUM',x,y),mathn('MAXIMUM',x,z)),mathn('MAXIMUM',y,z))
  remap=n.new('ShaderNodeMapRange');remap.name='ControlledEdgeDistance';remap.interpolation_type='SMOOTHSTEP';remap.clamp=True;l.new(median,remap.inputs['Value']);remap.inputs['From Min'].default_value=0;remap.inputs['From Max'].default_value=width;remap.inputs['To Min'].default_value=1;remap.inputs['To Max'].default_value=0
  old=n['EDGE_INPUT'].outputs[0]
  for link in list(old.links):target=link.to_socket;l.remove(link);l.new(remap.outputs[0],target)

def active(o):
 bpy.ops.object.select_all(action='DESELECT');o.hide_set(False);o.select_set(True);bpy.context.view_layer.objects.active=o

def mesh(name,verts,faces,kind):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob)
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free();ob.data.materials.append(material(kind));return ob

def box(name,center,size,kind):
 x,y,z=center;a,b,c=[v/2 for v in size];vs=[(x+i*a,y+j*b,z+k*c) for i,j,k in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
 return mesh(name,vs,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],kind)

def profile(name,yz,width,kind):
 n=len(yz);vs=[(x,y,z) for x in [-width/2,width/2] for y,z in yz];faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return mesh(name,vs,faces,kind)

def bevel(ob,width,segs):
 active(ob);b=ob.modifiers.new('Manufactured radius','BEVEL');b.width=width;b.segments=segs;b.limit_method='ANGLE';b.angle_limit=.5;b.affect='EDGES';bpy.ops.object.modifier_apply(modifier=b.name)
 for p in ob.data.polygons:p.use_smooth=True
 w=ob.modifiers.new('Face weighted normals','WEIGHTED_NORMAL');w.keep_sharp=True;w.weight=50;bpy.ops.object.modifier_apply(modifier=w.name)

def pair(ob,group,width=.0006,cage=.0018,detail=None):
 name=ob.name;lo=ob;lo.name=name+'_low';hi=lo.copy();hi.data=lo.data.copy();bpy.context.collection.objects.link(hi);hi.name=name+'_high'
 if detail:detail(hi)
 bevel(hi,width,3);bevel(lo,width,1);localize_edge_mask(hi)
 pairs.append({'name':name,'group':group,'low':lo,'high':hi,'cage_distance':cage});return lo,hi

def boolean(ob,cutter):
 active(ob);m=ob.modifiers.new('Machined recess','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=cutter;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(cutter,do_unlink=True)

def cylinder(name,center,r,depth,axis,kind,segments=20):
 bpy.ops.mesh.primitive_cylinder_add(vertices=segments,radius=r,depth=depth,location=center);o=bpy.context.object;o.name=name;o.rotation_euler=Vector((0,0,1)).rotation_difference(Vector(axis)).to_euler();bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);o.data.materials.append(material(kind));return o

def screw(name,center,normal,group,r=.0025):
 # Low retains inset rim and head silhouette; high includes actual intersecting cross cuts.
 n=Vector(normal);c=Vector(center);head=cylinder(name,c,r,.001,normal,'steel',16)
 def cuts(hi):
  basis=n.to_track_quat('Z','Y').to_matrix().to_4x4()
  for size in [(r*1.35,r*.28,.0012),(r*.28,r*1.35,.0012)]:
   cut=box('slot',(0,0,0),size,'black');cut.matrix_world=Matrix.Translation(c+n*.0005)@basis;boolean(hi,cut)
 pair(head,group,.00012,.0007,cuts)
 screws.append({'name':name,'center':list(center),'normal':list(normal),'type':'steel countersunk Phillips','radius':r})
 # Dark recessed seating ring is recessed behind the metal head, not a white fastener.
 seat=cylinder(name+'_seat',c-n*.0008,r*1.38,.0007,normal,'dark',20);pair(seat,group,.0001,.0005)

def dents(hi):
 # Two shallow physical dishes on each visible magazine face.
 for side in [-1,1]:
  for y,z,ry,rz in [(.255,-.057,.014,.010),(.342,-.047,.010,.016)]:
   bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=(side*.062,y,z));c=bpy.context.object;c.scale=(.0065,ry,rz);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);boolean(hi,c)

def panel_dents(hi):
 for y,z,ry,rz in [(.255,-.057,.010,.007),(.330,-.045,.007,.011),(.295,-.067,.004,.003)]:
  bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=1,location=(.0645,y,z));c=bpy.context.object;c.scale=(.0065,ry,rz);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);boolean(hi,c)
def receiver_seams(hi):
 for y in [.035,.145,.248]:
  cut=box('Top panel separation',(0,y,.1182),(.090,.00075,.001),'dark');boolean(hi,cut)

if args.revision=='ml09':
 exec(compile((R/'tools/ls01_refine/structure_v2.py').read_text(),'structure_v2.py','exec'))
else:
 # Core silhouettes retain original nominal bounds and animation roots.
 pair(profile('T03_ReceiverShell',[(-.027,.026),(-.027,.088),(.005,.118),(.255,.118),(.310,.086),(.310,.025),(.285,.014),(.012,.014)],.108,'white'),'body',.0012,.0018,receiver_seams)
 pair(profile('T04_EnergyCell',[(.194,-.018),(.210,-.098),(.372,-.098),(.402,-.075),(.402,-.018)],.112,'orange'),'body',.0011,.002,dents)
 # A separate inset panel on right side, attached to the same magazine animation.
 pair(box('T11_CellSide',(.0575,.29,-.052),(.002,.127,.055),'orange'),'body',.00065,.0018,panel_dents)
 pair(profile('T08_StockShell',[(-.208,-.065),(-.208,.090),(-.187,.102),(-.052,.102),(-.034,.072),(-.057,-.030),(-.177,-.070)],.075,'white'),'body',.0012)
 pair(profile('T07_TopRail',[(.195,.108),(.210,.132),(.490,.132),(.530,.112),(.530,.092),(.205,.092)],.075,'dark'),'body',.0007)
 # Recessed rail breaks, made as deliberate separate raised mechanical blocks.
 for i in range(6):pair(box('RailLug%02d'%i,(0,.230+i*.044,.135),(.087,.030,.008),'dark'),'body',.00065)
 # Hollow sight frame: front/back loops, closed thickness, no solid face across aperture.
 outer=[(-.060,.110),(-.060,.190),(-.043,.216),(.043,.216),(.060,.190),(.060,.110)]
 inner=[(-.047,.123),(-.047,.185),(-.036,.202),(.036,.202),(.047,.185),(.047,.123)]
 verts=[(x,y,z) for y in [.049,.066] for loop in [outer,inner] for x,z in loop];fs=[]
 for i in range(6):
  j=(i+1)%6;fs.extend([(i,j,j+12,i+12),(i+6,i+18,j+18,j+6),(i,i+6,j+6,j),(i+12,j+12,j+18,i+18)])
 pair(mesh('T05_Optic',verts,fs,'dark'),'body',.0009)
 pair(box('OpticFoot',(0,.063,.108),(.084,.070,.014),'dark'),'body',.0008)
# Main body screw inventory, placed on actual flat support faces.
for side in [-1,1]:
 for i,(y,z) in enumerate([(.015,.083),(.085,.091),(.190,.091),(.267,.064),(.015,.039),(.250,.036)]):screw(f'Receiver_{side}_{i}',(side*.0551,y,z),(side,0,0),'body')
 for i,(y,z) in enumerate([(-.18,.071),(-.071,.068),(-.17,-.040)]):screw(f'Stock_{side}_{i}',(side*.0385,y,z),(side,0,0),'body')
 for i,(y,z) in enumerate([(.225,-.039),(.325,-.065)] if args.revision=='ml09' else [(.225,-.039),(.365,-.065)]):screw(f'Cell_{side}_{i}',(side*.0571,y,z),(side,0,0),'body',.002)

# Kit panel local XYZ maps through Godot screen transform into Blender coordinates.
def panel_point(v):
 x,y,z=v;c=math.sqrt(.5);gy=.106+c*y+c*z;gz=.019-c*y+c*z;return (x,-gz,gy)
def panel_mesh(name,poly,front,back,kind):
 n=len(poly);v=[panel_point((x,y,z)) for z in [back,front] for x,y in poly];fs=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)];return mesh(name,v,fs,kind)
poly=[(-.052,-.016),(.052,-.016),(.044,.016),(-.044,.016),(-.054,.002),(-.054,-.004)]
# Symmetric elongated hexagon, sloped ends.
poly=[(-.054,0),(-.044,-.017),(.044,-.017),(.054,0),(.044,.017),(-.044,.017)]
if args.revision=='ml09':poly=[(-.054,-.0102),(-.05076,-.017),(.05076,-.017),(.054,-.0102),(.04428,.017),(-.04428,.017)]
inner=[(x*.83,y*.72) for x,y in poly]
back=panel_mesh('ScreenArmor',poly,.003,-.005 if args.revision=='ml09' else -.003,'dark');pair(back,'kit',.0005)
# Bezel ring around actual inner glass (closed polygon ring).
v=[panel_point((x,y,z)) for z in [.003,.005] for loop in [poly,inner] for x,y in loop];fs=[]
for i in range(6):
 j=(i+1)%6;fs.extend([(i,j,j+12,i+12),(i+6,i+18,j+18,j+6),(i,i+6,j+6,j),(i+12,j+12,j+18,i+18)])
pair(mesh('ScreenBezel',v,fs,'dark'),'kit',.00025,.0008)
pair(panel_mesh('ScreenGlass',inner,.0038,.0032,'glass'),'kit',.00012,.0004)
n=(0,-math.sqrt(.5),math.sqrt(.5))
for x in [-.043,.043]:
 for y in [-.014,.013] if args.revision=='ml09' else [-.012,.012]:screw(f'Screen_{x}_{y}',panel_point((x,y,.0055)),n,'kit',.0018)
# Tubes sweep a rounded path. Ends curl down into clamps; shape is geometry.
for side in [-1,1]:
 pair(box(f'ConductorWell{side}',(side*.0555,.139,.057),(.005,.170,.034),'dark'),'kit',.0007)
 for i in range(6):
  z=.046+i*.0042;points=[]
  for j in range(25):
   t=j/24;y=.066+t*.140;x=side*(.059+.0045*math.sin(math.pi*t)**.55);points.append(Vector((x,y,z+.0015*math.sin(math.pi*t))))
  verts=[];sides=10;r=.00145
  for j,p in enumerate(points):
   tangent=(points[min(j+1,24)]-points[max(j-1,0)]).normalized();u=tangent.cross(Vector((0,0,1))).normalized();v=tangent.cross(u)
   for k in range(sides):verts.append(p+r*(u*math.cos(2*math.pi*k/sides)+v*math.sin(2*math.pi*k/sides)))
  faces=[tuple(range(sides-1,-1,-1)),tuple(range(24*sides,25*sides))]
  for j in range(24):
   for k in range(sides):faces.append((j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k))
  pair(mesh(f'CopperTube{side}_{i}',verts,faces,'copper'),'kit',.00008,.0005)
 for y in [.064,.209]:
  pair(box(f'Clamp{side}_{y}',(side*.062,y,.0565),(.012,.011,.035),'dark'),'kit',.0005)
  for z in [.045,.068]:screw(f'ClampScrew{side}_{y}_{z}',(side*.0685,y,z),(side,0,0),'kit',.0017)
 pair(box(f'HeatsinkBase{side}',(side*.047,.36,.106),(.018,.094,.006),'dark'),'kit',.0005)
 for i in range(8):pair(box(f'Fin{side}_{i}',(side*.047,.3215+i*.011,.118),(.018,.0025,.022),'steel'),'kit',.00022,.0006)
# Highs retain material-driven micro detail. Lows are triangulated then collectively unwrapped.
for group in ['body','kit']:
 objs=[p['low'] for p in pairs if p['group']==group]
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objs:
  active(ob);m=ob.modifiers.new('Frozen triangles','TRIANGULATE');m.keep_custom_normals=args.revision=='ml09';bpy.ops.object.modifier_apply(modifier=m.name)
 bpy.ops.object.select_all(action='DESELECT')
 for ob in objs:ob.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(angle_limit=1.10,island_margin=.016);bpy.ops.uv.pack_islands(rotate=True,margin=.008,margin_method='FRACTION');bpy.ops.object.mode_set(mode='OBJECT')
for p in pairs:
 lo=p['low'];c=lo.copy();c.data=lo.data.copy();bpy.context.collection.objects.link(c);c.name=p['name']+'_cage'
 # Vertex normal expansion, with topology exactly corresponding to the low.
 for v in c.data.vertices:v.co+=v.normal*p['cage_distance']
 c.display_type='WIRE';c.hide_render=True;c.hide_set(True);p['cage']=c
 for k in ['low','high','cage']:p[k]['atlas']=p['group'];p[k]['part_id']=p['name']
 p['high'].hide_render=True;p['high'].hide_set(True)
(O/'02-geometry').mkdir(exist_ok=True)
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(O/'02-geometry/paired.blend'))
records=[{**{k:v for k,v in p.items() if k not in ['low','high','cage']},**{k:p[k].name for k in ['low','high','cage']},'triangles':len(p['low'].data.polygons)} for p in pairs]
(O/'manifest.json').write_text(json.dumps({'seed':args.seed,'pairs':records,'fasteners':screws,'replaced_prefixes':['T03','T04','T05','T07','T08','T11']+(['T01','T14'] if args.revision=='ml09' else []),'new_triangles':sum(p['triangles'] for p in records),'revision':args.revision,'imagegen_calls':0 if args.revision=='ml09' else 2,'reused_imagegen_masks':2,'tripo_calls':0,'units':'metres; Blender X right Y forward Z up','uv_version':('ls01-v2' if args.revision=='ml09' else 'ls01-v1')+'; unchanged parts keep old atlas'},indent=2))
print('BUILD_COMPLETE',len(records),sum(p['triangles'] for p in records),flush=True)

if args.revision=='ml09':
 (O/'screen.json').write_text(json.dumps({'position':[0,.106,.019],'rotation_x':-math.pi/4,'contour':poly,'glass_contour':inner,'cells_origin':[-.037,0,.0041],'readout_position':[.030,0,.0042]},indent=2))
