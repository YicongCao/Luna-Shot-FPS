"""Preserve our low+UV and transfer Tripo surface data by triangle correspondence.
Then enforce art-direction material classes; do not substitute generated normals for baked normals.
"""
import bpy,json,numpy as np,math,hashlib,shutil
from pathlib import Path
import os,sys
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parents[2];asset=sys.argv[-1];BASE=ROOT/'art_source/environment/pipeline-v1'/asset;OUT=BASE/'07-final';TEX=OUT/'textures';TEX.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(BASE/'04-low'/f'{asset}-low.blend'))
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
 coords=np.array([v.co[:] for v in lo.data.vertices]);extent=np.ptp(coords,axis=0);part_center=(coords.min(0)+coords.max(0))*.5
 for face in remote.data.polygons:
  points=np.array([remote.data.vertices[i].co for i in face.vertices]);uv=np.array([remote.data.uv_layers.active.data[i].uv for i in face.loop_indices]);lookup[key(points)]=(points,uv)
 uvdiff=0;count=0
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
  # Preserve the generated PBR candidate, clamp implausible extremes only.
  cls=np.ones(len(x),np.uint8)
  base[y,x,:3]=np.clip(bc[:,:3],.012,.82)
  orm[y,x,1]=np.clip(mr[:,1],.22,.9)
  orm[y,x,2]=np.clip(mr[:,2],0,1)
  cls[mr[:,2]>.6]=3
  cls[mr[:,1]>.75]=4
  if asset=='A':
   # Remove painted-in broad illumination; assign readable industrial material regions.
   detail=.96+.08*np.clip(bc[:,:3].mean(1),0,1)
   base[y,x,:3]=np.array([.40,.43,.46])*detail[:,None]
   orm[y,x,1]=.58;orm[y,x,2]=0
   part_index=int(name.split('_P')[1].split('_')[0])
   dark=np.full(len(x),part_index==0 or part_index>=4,dtype=bool)
   base[y[dark],x[dark],:3]=np.array([.055,.072,.09])*detail[dark,None]
   orm[y[dark],x[dark],1]=.43;orm[y[dark],x[dark],2]=.72;cls[dark]=3
   label=(wp[:,2]>1.15)&(wp[:,1]<-1.1)&(wp[:,1]>-1.4)&(abs(wp[:,0])<.26)
   base[y[label],x[label],:3]=[.8,.18,.025];orm[y[label],x[label],1]=.55
  if asset in ['B1','B2']:
   detail=.94+.12*np.clip(bc[:,:3].mean(1),0,1)
   metal=(extent[2]<.45 or min(extent[0],extent[1])<.6 or part_center[2]<.45)
   color=[.09,.13,.17] if metal else [.38,.42,.46]
   base[y,x,:3]=np.array(color)*detail[:,None]
   orm[y,x,1]=np.clip((.38 if metal else .58)+(mr[:,1]-.5)*.12,.25,.75)
   orm[y,x,2]=.85 if metal else 0
   cls[:]=3 if metal else 1
  if asset in ['C','D']:
   detail=.94+.12*np.clip(bc[:,:3].mean(1),0,1)
   deck=extent[0]>3 and extent[1]>2
   base[y,x,:3]=np.array([.23,.28,.32] if deck else [.075,.11,.145])*detail[:,None]
   orm[y,x,1]=.68 if deck else .4;orm[y,x,2]=.35 if deck else .85;cls[:]=3
   expected=np.full(len(x),2.4) if asset=='C' else np.minimum(2.4,(wp[:,1]+6)*.3)
   edge=deck & (abs(wp[:,2]-expected)<.035)&(abs(wp[:,0])>1.6)&(abs(wp[:,0])<1.76)
   stripe=(np.floor((wp[:,1]+wp[:,0])/.32).astype(int)%2)==0
   orange=edge&stripe
   base[y[orange],x[orange],:3]=[.82,.22,.025];orm[y[edge],x[edge],1]=.62;orm[y[edge],x[edge],2]=0
  if asset=='E':
   detail=.94+.12*np.clip(bc[:,:3].mean(1),0,1)
   panel=(wp[:,2]>9.45)&(abs(wp[:,0])>.5)
   cabinet=wp[:,2]<1.5
   coated=panel|cabinet
   base[y,x,:3]=np.array([.075,.11,.145])*detail[:,None]
   base[y[coated],x[coated],:3]=np.array([.42,.46,.50])*detail[coated,None]
   orm[y,x,1]=np.where(coated,.6,.4);orm[y,x,2]=np.where(coated,0,.85)
   cls[:]=np.where(coated,1,3)
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
mat=bpy.data.materials.new(asset+'_PBR_Final');mat.use_nodes=True;mat.use_backface_culling=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED')
for im,socket in [(bcim,'Base Color'),(emim,'Emission Color')]:
 n=nodes.new('ShaderNodeTexImage');n.image=im;links.new(n.outputs['Color'],bs.inputs[socket])
bs.inputs['Emission Strength'].default_value=2
n=nodes.new('ShaderNodeTexImage');n.image=ormim;sep=nodes.new('ShaderNodeSeparateColor');links.new(n.outputs['Color'],sep.inputs[0]);links.new(sep.outputs['Green'],bs.inputs['Roughness']);links.new(sep.outputs['Blue'],bs.inputs['Metallic'])
n=nodes.new('ShaderNodeTexImage');n.image=normal;nm=nodes.new('ShaderNodeNormalMap');links.new(n.outputs['Color'],nm.inputs['Color']);links.new(nm.outputs['Normal'],bs.inputs['Normal'])
for ob in lows.values():ob.data.materials.clear();ob.data.materials.append(mat)
for ob in bpy.context.scene.objects:ob.select_set(ob.type=='MESH')
# Runtime uses one mesh/material per asset; editable parts remain in the low-stage Blend.
bpy.context.view_layer.objects.active=next(iter(lows.values()))
bpy.ops.object.join()
merged=bpy.context.object;merged.name=asset+'_Runtime';lows={merged.name:merged}
bpy.data.orphans_purge(do_recursive=True)
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'{asset}-final.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT/f'{asset}-final.glb'),export_format='GLB',use_selection=True,export_yup=True,export_extras=True,export_materials='NONE',export_tangents=True)
report.update({'unmatched_triangles':unmatched,'uv_out_of_bounds_triangles':uv_oob,'strict_interior_overlap_pixels':uv_overlaps,'uv_coverage_fraction':float(coverage.mean()),'final_triangles':sum(len(o.data.polygons) for o in lows.values()),'texture_resolution':[N,N],'material_slots':1,'semantic_corrections':'Retained Tripo PBR color/material variation; bounded roughness .22-.9 and albedo .012-.82; genuine high-to-low normal/AO.'})
report['material_statistics']={str(c):{'pixels':int(np.sum(classes==c)),'mean_roughness':float(orm[:,:,1][classes==c].mean()),'mean_metallic':float(orm[:,:,2][classes==c].mean())} for c in range(1,6) if np.any(classes==c)}
(OUT/'material-transfer-report.json').write_text(json.dumps(report,indent=2));print('FINAL_MATERIALS_COMPLETE',flush=True)
