"""Preserve our low+UV and transfer Tripo surface data by triangle correspondence.
Then enforce art-direction material classes; do not substitute generated normals for baked normals.
"""
import bpy,json,numpy as np,math,hashlib,shutil
from pathlib import Path
import os
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'art_source/weapons/lc01'/os.environ.get('LC01_PIPELINE','pipeline-v1');OUT=BASE/'07-final';TEX=OUT/'textures';TEX.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'04-low/lc01-low.blend'))
lows={o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
for ob in lows.values():ob.name='FINAL_'+ob.name
# Load raw generated texture source as a second independent object set.
bpy.ops.import_scene.gltf(filepath=str(BASE/'06-tripo-pbr/model.glb'))
pbr={o.name:o for o in bpy.context.selected_objects if o.type=='MESH'}
def bounds(objects):
 p=np.array([list(o.matrix_world@Vector(c)) for o in objects for c in o.bound_box]);return p.min(0),p.max(0)
amin,amax=bounds(lows.values());bmin,bmax=bounds(pbr.values());scale=(amax[1]-amin[1])/(bmax[1]-bmin[1]);shift=(amax+amin)/2-(bmax+bmin)/2*scale
for ob in pbr.values():
 mw=ob.matrix_world.copy()
 for v in ob.data.vertices:v.co=Vector(np.array(mw@v.co)*scale+shift)
 ob.matrix_world=Matrix.Identity(4)
# Pixel arrays are Blender linear color floats, with bottom-left UV origin.
N=2048
base=np.ones((N,N,4),np.float32);base[:,:,:3]=.3
orm=np.ones((N,N,4),np.float32);orm[:,:,1]=.5;orm[:,:,2]=0
emit=np.zeros((N,N,4),np.float32);emit[:,:,3]=1
coverage=np.zeros((N,N),np.uint8);interior=np.zeros((N,N),bool);classes=np.zeros((N,N),np.uint8)
worldmap=np.zeros((N,N,3),np.float32)
rawatlas=np.ones((N,N,4),np.float32)
report={'source':'Tripo PBR -> triangle-correspondence transfer into fixed low UV','normal_source':'05-bake/NormalGL.png, real high-to-low Cycles projection','parts':[],'tripo_uv_changed':False}
def imgarray(im):
 a=np.empty(im.size[0]*im.size[1]*4,np.float32);im.pixels.foreach_get(a);return a.reshape(im.size[1],im.size[0],4)
def texture_nodes(ob):
 mat=ob.data.materials[0];bs=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
 bc=bs.inputs['Base Color'].links[0].from_node.image
 sep=bs.inputs['Roughness'].links[0].from_node
 mr=sep.inputs[0].links[0].from_node.image
 return imgarray(bc),imgarray(mr)
def key(points):return tuple(sorted(tuple(round(float(v),5) for v in p) for p in points))
def sample(image,uv):
 h,w=image.shape[:2];x=np.clip(uv[:,0]*(w-1),0,w-1);y=np.clip(uv[:,1]*(h-1),0,h-1)
 x0=x.astype(int);y0=y.astype(int);x1=np.minimum(x0+1,w-1);y1=np.minimum(y0+1,h-1);fx=(x-x0)[:,None];fy=(y-y0)[:,None]
 return image[y0,x0]*(1-fx)*(1-fy)+image[y0,x1]*fx*(1-fy)+image[y1,x0]*(1-fx)*fy+image[y1,x1]*fx*fy
unmatched=0;uv_overlaps=0;uv_oob=0
for name,lo in lows.items():
 remote=pbr[name];rawbc,rawmr=texture_nodes(remote);lookup={}
 for face in remote.data.polygons:
  points=np.array([remote.data.vertices[i].co for i in face.vertices]);uv=np.array([remote.data.uv_layers.active.data[i].uv for i in face.loop_indices]);lookup[key(points)]=(points,uv)
 idx=int(name[1:3]);uvdiff=0;count=0
 for face in lo.data.polygons:
  pos=np.array([lo.data.vertices[i].co for i in face.vertices]);uv=np.array([lo.data.uv_layers.active.data[i].uv for i in face.loop_indices]);match=lookup.get(key(pos))
  if match is None:
   # Rare tiny normalization round-off; find the same triangle by nearest centroid.
   candidates=[(np.linalg.norm(p.mean(0)-pos.mean(0)),p,u) for p,u in lookup.values()]
   dist,mp,mu=min(candidates,key=lambda x:x[0]);match=(mp,mu) if dist<.00005 else None
  if match is None:unmatched+=1;continue
  mp,mu=match;order=[int(np.argmin(np.linalg.norm(mp-p,axis=1))) for p in pos];ruv=mu[order]
  uvdiff=max(uvdiff,float(np.max(np.abs(uv-ruv))))
  if uv.min()<-.00001 or uv.max()>1.00001:uv_oob+=1
  screen=uv*N-.5
  x0=max(0,int(np.floor(screen[:,0].min())));x1=min(N-1,int(np.ceil(screen[:,0].max())))
  y0=max(0,int(np.floor(screen[:,1].min())));y1=min(N-1,int(np.ceil(screen[:,1].max())))
  if x0>x1 or y0>y1:continue
  xx,yy=np.meshgrid(np.arange(x0,x1+1),np.arange(y0,y1+1));p=np.stack([xx,yy],-1)
  a,b,c=screen;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-8:continue
  w0=((b[1]-c[1])*(p[:,:,0]-c[0])+(c[0]-b[0])*(p[:,:,1]-c[1]))/den
  w1=((c[1]-a[1])*(p[:,:,0]-c[0])+(a[0]-c[0])*(p[:,:,1]-c[1]))/den;w2=1-w0-w1
  inside=(w0>=0)&(w1>=0)&(w2>=0)
  if not inside.any():continue
  x=xx[inside];y=yy[inside];weights=np.stack([w0[inside],w1[inside],w2[inside]],-1)
  ip=(weights.min(1)>.001);uv_overlaps+=int(np.count_nonzero(interior[y,x]&ip));interior[y,x]|=ip;coverage[y,x]=1
  wp=weights@pos;worldmap[y,x]=wp
  bc=sample(rawbc,weights@ruv);mr=sample(rawmr,weights@ruv);rawatlas[y,x]=bc
  # Stable semantic classes: 1 ceramic, 2 coated orange, 3 exposed metal, 4 rubber, 5 cyan emissive.
  cls=np.full(len(x),3,np.uint8)
  if idx in [1,3,8,13,14,16]:cls[:]=1
  if idx in [4,11]:cls[:]=2
  if idx in [10,12]:cls[:]=4
  if idx==0:cls[(wp[:,2]<-.015)&(wp[:,1]<.14)]=4
  if idx==2:
   ringdistance=np.min(np.abs(wp[:,1,None]-np.array([.326,.402,.478])),axis=1)
   cls[ringdistance<.0045]=5
  # Deliberate diagonal orange identification bands, independent of generated fake lettering.
  if idx==8:cls[np.abs(wp[:,1]+.135+.6*wp[:,2])<.011]=2
  if idx==1:cls[np.abs(wp[:,1]-.505+.5*wp[:,2])<.010]=2
  colors={1:(.62,.59,.53),2:(.82,.115,.018),3:(.12,.16,.21),4:(.014,.019,.025),5:(.018,.57,.75)}
  roughs={1:.46,2:.36,3:.28,4:.84,5:.23};metals={1:0,2:0,3:.95,4:0,5:.1}
  luminance=bc[:,:3]@np.array([.2126,.7152,.0722]);detail=.94+.10*np.clip(luminance,0,1)
  for cl in colors:
   mask=cls==cl
   if not mask.any():continue
   base[y[mask],x[mask],:3]=np.array(colors[cl])*detail[mask,None]
   orm[y[mask],x[mask],1]=np.clip(roughs[cl]+(mr[mask,1]-.5)*.14,.12,.95)
   orm[y[mask],x[mask],2]=metals[cl]
   if cl==5:emit[y[mask],x[mask],:3]=np.array([.015,.65,1.0])
  classes[y,x]=cls;count+=len(x)
 report['parts'].append({'name':name,'triangles':len(lo.data.polygons),'uv_max_change':uvdiff,'rasterized_pixels':count})
 report['tripo_uv_changed']|=uvdiff>1e-5
 print('TRANSFERRED',name,'uvchange',uvdiff,flush=True)
assert unmatched==0,unmatched
assert uv_oob==0,uv_oob
# Record residual self-overlap from the generated unwrap. Reject above 0.01% of atlas.
assert uv_overlaps/(N*N)<0.0001,uv_overlaps
# Embed the true high-to-low AO in the red ORM channel.
ao=bpy.data.images.load(str(BASE/'05-bake/AO.png'),check_existing=False);ao.colorspace_settings.name='Non-Color';orm[:,:,0]=np.clip(imgarray(ao)[:,:,0],.15,1)
# Dilate color/data maps out of UV islands for 16 px gutters; do not edit baked normal tangents.
filled=coverage.astype(bool)
for step in range(16):
 old=filled.copy()
 for dy,dx in [(1,0),(-1,0),(0,1),(0,-1)]:
  shifted=np.roll(old,(dy,dx),(0,1));eligible=shifted&~filled
  if dy==1:eligible[0,:]=False
  if dy==-1:eligible[-1,:]=False
  if dx==1:eligible[:,0]=False
  if dx==-1:eligible[:,-1]=False
  for array in [base,orm,emit,rawatlas]:array[eligible]=np.roll(array,(dy,dx),(0,1))[eligible]
  filled|=eligible

def save_image(name,array,color):
 # Byte-backed generated images expect encoded values when tagged sRGB.
 if color:
  array=array.copy();rgb=np.clip(array[:,:,:3],0,1);array[:,:,:3]=np.where(rgb<=.0031308,rgb*12.92,1.055*np.power(rgb,1/2.4)-.055)
 im=bpy.data.images.new(name,N,N,alpha=True);im.colorspace_settings.name='sRGB' if color else 'Non-Color';im.pixels.foreach_set(array.ravel());im.filepath_raw=str(TEX/(name+'.png'));im.file_format='PNG';im.save();return im
bcim=save_image('BaseColor',base,True);ormim=save_image('ORM',orm,False);emim=save_image('Emission',emit,True)
save_image('TripoBaseColorTransferred',rawatlas,True)
np.savez_compressed(OUT/'material-masks.npz',classes=classes,coverage=coverage)
# Keep final geometry and its original UV and custom normals; discard imported remote geometry.
for ob in list(pbr.values()):bpy.data.objects.remove(ob,do_unlink=True)
for ob in lows.values():ob.name=ob.name.removeprefix('FINAL_')
shutil.copyfile(BASE/'05-bake/NormalGL.png',TEX/'NormalGL.png')
normal=bpy.data.images.load(str(TEX/'NormalGL.png'),check_existing=False);normal.colorspace_settings.name='Non-Color'
mat=bpy.data.materials.new('LC01_PBR_Final');mat.use_nodes=True;mat.use_backface_culling=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
for im,socket in [(bcim,'Base Color'),(emim,'Emission Color')]:
 n=nodes.new('ShaderNodeTexImage');n.image=im;links.new(n.outputs['Color'],bs.inputs[socket])
bs.inputs['Emission Strength'].default_value=2
n=nodes.new('ShaderNodeTexImage');n.image=ormim;sep=nodes.new('ShaderNodeSeparateColor');links.new(n.outputs['Color'],sep.inputs[0]);links.new(sep.outputs['Green'],bs.inputs['Roughness']);links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
n=nodes.new('ShaderNodeTexImage');n.image=normal;nm=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
for ob in lows.values():ob.data.materials.clear();ob.data.materials.append(mat)
for ob in bpy.context.scene.objects:ob.select_set(ob.type=='MESH')
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'lc01-final.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/'lc01-final.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True)
report.update({'unmatched_triangles':unmatched,'uv_out_of_bounds_triangles':uv_oob,'strict_interior_overlap_pixels':uv_overlaps,'uv_coverage_fraction':float(coverage.mean()),'final_triangles':sum(len(o.data.polygons) for o in lows.values()),'texture_resolution':[N,N],'material_slots':1,'semantic_corrections':'Reassigned white grip to rubber, dark cell to orange, orange muzzle to metal; removed strong generated lettering via low-contrast albedo detail; added exactly 3 cyan bands.'})
report['material_statistics']={str(c):{'pixels':int(np.sum(classes==c)),'mean_roughness':float(orm[:,:,1][classes==c].mean()),'mean_metallic':float(orm[:,:,2][classes==c].mean())} for c in range(1,6)}
(OUT/'material-transfer-report.json').write_text(json.dumps(report,indent=2));print('FINAL_MATERIALS_COMPLETE',flush=True)
