"""Seeded, tileable ground material authoring. No generated lighting, no paid calls."""
from pathlib import Path
import sys,json,hashlib,argparse
import numpy as np
from PIL import Image
R=Path(__file__).resolve().parents[2];sys.path.insert(0,str(R/'tools'));from scene_builder import Scene,v
p=argparse.ArgumentParser();p.add_argument('--size',type=int,default=2048);p.add_argument('--seed',type=int,default=20261116);p.add_argument('--scene-only',action='store_true');a=p.parse_args();N=a.size;rng=np.random.default_rng(a.seed)
D=R/'assets/environment/ground_v1';D.mkdir(parents=True,exist_ok=True)
S=R/'art_source/environment/ground-v1';S.mkdir(parents=True,exist_ok=True);(S/'.gdignore').touch()
def noise(n):
 grid=rng.random((n,n)).astype('float32');g=np.pad(grid,((0,1),(0,1)),mode='wrap');t=np.arange(N)*n/N;i=np.floor(t).astype(int);f=(t-i).astype('float32');f=f*f*(3-2*f)
 return (g[i[:,None],i[None,:]]*(1-f[None,:])+g[i[:,None],i[None,:]+1]*f[None,:])*(1-f[:,None])+(g[i[:,None]+1,i[None,:]]*(1-f[None,:])+g[i[:,None]+1,i[None,:]+1]*f[None,:])*f[:,None]
def smooth(lo,hi,x):
 t=np.clip((x-lo)/(hi-lo),0,1);return t*t*(3-2*t)
def png(path,arr):Image.fromarray(np.uint8(np.clip(arr,0,1)*255+.5)).save(path)
def material(name,meters):
 out=D/name;out.mkdir(exist_ok=True)
 macro=noise(5);grain=noise(180);fine=noise(640);mids=noise(35)
 yy,xx=np.mgrid[0:N,0:N].astype('float32')/N
 rough=np.full((N,N),.78,dtype='float32');metal=np.zeros_like(rough);ao=np.ones_like(rough)
 if name=='paving':
  # 2 x 4 m repeat, 12 mm recessed joint. Broad surfaces stay quiet.
  edge=np.minimum(np.minimum(xx,1-xx)*2,np.minimum(yy,1-yy)*4)
  panel=smooth(.006,.013,edge)
  pores=smooth(.70,.84,grain)
  height=(grain-.5)*.00008+(fine-.5)*.00006-pores*.0002-(1-panel)*.003
  shade=.43+(macro-.5)*.035+(grain-.5)*.012-pores*.025
  base=np.stack([shade*.94,shade*.98,shade],2)*( .42+.58*panel[:,:,None])
  rough=.83+(grain-.5)*.05+pores*.04;ao=.6+.4*panel
 elif name=='regolith':
  flecks=smooth(.55,.80,mids)*smooth(.48,.78,grain)
  height=(mids-.5)*.002+(grain-.5)*.0015+(fine-.5)*.0003+flecks*.003
  shade=.285+(macro-.5)*.045+(grain-.5)*.07+flecks*.10
  base=np.stack([shade,shade*.99,shade*.98],2);rough=.91+(grain-.5)*.1;ao=np.clip(.90+(mids-.5)*.18,.7,1)
 else:
  # Metal cover: geometry carries frame/fasteners; shallow cross-hatch is height.
  dx=np.abs(np.sin((xx+yy)*np.pi*22));dy=np.abs(np.sin((xx-yy)*np.pi*22))
  tread=smooth(.94,.995,np.maximum(dx,dy));scratches=smooth(.77,.90,noise(300))*smooth(.55,.8,noise(12))
  height=tread*.00065-scratches*.00016+(fine-.5)*.00008
  shade=.62+(macro-.5)*.035+tread*.028
  base=np.stack([shade*.90,shade*.98,shade*1.03],2);rough=.47+(grain-.5)*.12;metal[:]=.92
 # OpenGL tangent normals: U maps to +X; V maps to -Z in runtime shader.
 gx=(np.roll(height,-1,1)-np.roll(height,1,1))/(2*meters[0]/N)
 gy=(np.roll(height,-1,0)-np.roll(height,1,0))/(2*meters[1]/N)
 norm=np.stack([-gx,-gy,np.ones_like(gx)],2);norm/=np.linalg.norm(norm,axis=2)[:,:,None]
 png(out/'BaseColor.png',base);png(out/'ORM.png',np.stack([ao,rough,metal],2));png(out/'NormalGL.png',norm*.5+.5)
 lo,hi=float(height.min()),float(height.max());Image.fromarray(np.uint16((height-lo)/(hi-lo)*65535)).save(S/f'{name}-height16.png')
 return {'meters':meters,'height_min_max_m':[lo,hi],'normal':'OpenGL tangent +Y; U=world X, V=-world Z','channels':'sRGB BaseColor; linear ORM R=AO/G=roughness/B=metallic; NormalGL linear','source':'deterministic height field; not high-poly selected-to-active bake'}
manifest=json.loads((S/'manifest.json').read_text()) if a.scene_only else {'seed':a.seed,'resolution':N,'materials':{name:material(name,m) for name,m in [('paving',(2,4)),('regolith',(1,1)),('metal',(1,1))]},'paid_calls':0}
# Sample masks: left 4m road remains clean; soil wraps the southeast service apron.
def mask_sample():
 n=512;z,x=np.mgrid[0:n,0:n].astype('float32');x=x/n*8-4;z=z/n*8-4
 edge=np.maximum(x-3.15,z-3.15)+.075*np.sin(x*8+np.sin(z*5))+.035*np.sin(z*17)
 return smooth(-.2,.25,edge)*smooth(-.1,.3,x)*smooth(-.1,.3,z)
png(D/'sample_mask.png',mask_sample())
# Scene generated with the same base material, player, A, sun and exposure as range.
s=Scene('GroundStudio','ground_studio');s.nodes[0]+='\nmetadata/layout_path = "res://docs/design/ground-sample.json"'
s.box('Ground',(0,-.3,0),(8,.6,8),'ground')
for x in range(-4,5):s.box('GridX'+str(x+4),(x,.003,0),(.008,.005,8),'mid',solid=False)
for z in range(-4,5):s.box('GridZ'+str(z+4),(0,.003,z),(8,.005,.008),'mid',solid=False)
s.group('Facility');s.group('Landmarks');s.group('Markers')
markers={'Spawn':[-2,.05,3],'OverviewFocus':[0,0,0],'OverviewCamera':[9,10,11]}
for name,pos in markers.items():s.node(name,'Marker3D','Markers','position = '+v(pos))
s.ext+=['[ext_resource type="PackedScene" path="res://assets/industrial/module_A.tscn" id="A"]','[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="player"]','[ext_resource type="Script" path="res://scripts/ground_surface.gd" id="surface"]']
s.nodes+=['[node name="A01" parent="Facility" instance=ExtResource("A")]\nposition = Vector3(2,0,-2)','[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector3(-2,0.05,3)']
s.node('Overview','Camera3D',props='fov = 53.0');s.node('Sun','DirectionalLight3D');env=s.res('Environment','background_mode = 1');s.node('Environment','WorldEnvironment',props=f'environment = SubResource("{env}")')
s.node('GroundSurface','Node3D',props='script = ExtResource("surface")\nsample = true')
(R/'scenes/ground_studio.tscn').write_text(s.serialize());(R/'docs/design/ground-sample.json').write_text(json.dumps({'size':[8,8],'markers':markers,'modules':[{'id':'A01','type':'A','position':[2,0,-2],'rotation_y':0}],'targets':[]},indent=2))
manifest['files']={str(f.relative_to(R)):hashlib.sha256(f.read_bytes()).hexdigest() for f in D.rglob('*.png')}
(S/'manifest.json').write_text(json.dumps(manifest,indent=2));print('GROUND_MATERIALS',N,'seed',a.seed)
