#!/usr/bin/env python3
"""Offline, deterministic four-module lunar power facility. No weapon asset writes."""
import argparse,json,math,random,os,tempfile,re
from collections import Counter,deque
from pathlib import Path
from scene_builder import Scene,ROOT,v
DEFAULT_SEED=20261115
SIZES={'A':(4,4),'B':(4,4),'C':(4,8),'D':(4,12)}

def rail(s,x,y,z,length,parent='.',rot=0):
 s.box('Rail'+str(len(s.nodes)),(x,y,z),(.10,.12,length),'mid',parent,rot=(rot,0,0))

def modules():
 result={}
 for variant in ['A','B1','B2','C','D']:
  kind=variant[0]
  s=Scene('Module'+variant)
  s.nodes[0]+=f'\nmetadata/module_type = "{kind}"\nmetadata/footprint = Vector2({SIZES[kind][0]}, {SIZES[kind][1]})'
  if kind=='A':
   s.box('Plinth',(0,.10,0),(3.8,.2,3.8),'mid')
   s.box('Cabinet',(0,.65,0),(3.6,.9,3.4),'chalk')
   s.box('Top',(0,1.15,0),(3.6,.1,3.4),'light')
   for x in [-1,0,1]:s.box('Panel'+str(x),(x,.65,1.72),(.82,.66,.04),'mid',solid=False)
   s.label('ID','A / POWER',(0,.67,1.76),18)
  if kind=='B':
   s.box('Foot',(0,.2,0),(3.8,.4,3.8),'mid')
   for x in [-1.5,1.5]:
    for z in [-1.5,1.5]:s.box('Frame'+str(x)+str(z),(x,3.1,z),(.25,5.8,.25),'mid')
   if variant=='B1':
    s.box('Core',(0,3.1,0),(2.5,5.4,2.5),'chalk')
    for i in range(6):s.box('Fin'+str(i),(0,.9+i*.85,0),(3.6,.18,3.4),'light')
    s.box('Crown',(0,5.9,0),(3.6,.2,3.6),'mid')
   else:
    # Two separated vertical radiator wings; same foot/frame kit as B1.
    s.box('Manifold',(0,.8,0),(3.2,.55,2.6),'chalk')
    s.box('Spine',(0,2.7,0),(.38,4.5,.45),'dark')
    for side in [-1,1]:
     wing=s.group('Wing'+str(side),(side*1.05,0,0))
     s.box('WingCore',(0,2.9,0),(.65,3.7,2.65),'mid',wing)
     for j in range(5):s.box('VerticalFin'+str(j),(-.56+j*.28,3.05,0),(.10,3.8,3.2),'light',wing)
     s.box('Cap',(0,5.02,0),(1.3,.22,3.3),'chalk',wing)
    s.box('TopLink',(0,5.7,0),(3.2,.2,.4),'mid')
   s.label('ID',variant+' / THERMAL',(0,.65,1.93),21)
   s.nodes[0]+=f'\nmetadata/subtype = "{variant}"'
  if kind=='C':
   s.box('Deck',(0,2.325,0),(4,.15,8),'light')
   for x in [-1.85,1.85]:
    for z in [-3.6,3.6]:s.box('Support'+str(x)+str(z),(x,1.125,z),(.25,2.25,.3),'mid')
    rail(s,x,3.35,0,8)
    s.box('CableTray'+str(x),(x,2.6,0),(.22,.2,8),'dark')
    for z in [-3.5,0,3.5]:s.box('Post'+str(x)+str(z),(x,2.85,z),(.1,.9,.1),'mid')
   for name,z in [('South',4),('North',-4)]:s.node(name,'Marker3D',props=f'position = {v((0,2.4,z))}')
  if kind=='D':
   # Local +Z foot at +6, slope to -2, landing -2..-6; height joins C exactly.
   a=math.atan2(2.4,8);t=.16
   s.box('Landing',(0,2.325,-4),(4,.15,4),'light')
   s.box('Ramp',(0,1.2-t/2*math.cos(a),2-t/2*math.sin(a)),(4,t,math.hypot(8,2.4)),'light',rot=(a,0,0))
   for x in [-1.85,1.85]:
    rail(s,x,2.15,2,math.hypot(8,2.4),rot=a);rail(s,x,3.35,-4,4)
    for z in [-5.5,-2,2,5.5]:
     h=2.4 if z<=-2 else (6-z)*.3
     s.box('Post'+str(x)+str(z),(x,h+.45,z),(.1,.9,.1),'mid')
    s.box('Support'+str(x),(x,1.125,-5.5),(.25,2.25,.25),'mid')
   s.node('Top','Marker3D',props='position = Vector3(0,2.4,-6)')
   s.node('Foot','Marker3D',props='position = Vector3(0,0,6)')
  result[variant]=s.serialize()
 # Central signal landmark: narrow solid foot, open lattice mast, directional aerials.
 s=Scene('SignalTower')
 s.nodes[0]+='\nmetadata/landmark_type = "signal"'
 s.box('Foot',(0,.22,0),(2,.44,2),'mid')
 s.box('ControlCabinet',(0,.8,0),(1.2,1.15,1.15),'chalk')
 for x in [-.65,.65]:
  for z in [-.65,.65]:s.box('Leg'+str(x)+str(z),(x,4.7,z),(.16,8.6,.16),'light')
 for level in range(4):
  y=1.6+level*2
  for z in [-.65,.65]:
   s.box('CrossX'+str(level)+str(z),(0,y+.7,z),(.1,math.hypot(1.3,1.4),.1),'mid',rot=(0,0,(-1 if level%2 else 1)*math.atan2(1.3,1.4)))
  for x in [-.65,.65]:
   s.box('CrossZ'+str(level)+str(x),(x,y+.7,0),(.1,math.hypot(1.3,1.4),.1),'mid',rot=(math.atan2(1.3,1.4),0,0))
  s.box('Collar'+str(level),(0,y,0),(1.55,.15,1.55),'mid')
 s.box('Head',(0,9.1,0),(1.8,.55,1.8),'chalk')
 s.box('AerialMast',(0,11.6,0),(.20,4.8,.20),'light')
 for y,width in [(9.8,3.8),(11.3,2.8),(12.6,1.8)]:
  s.box('Boom'+str(y),(0,y,0),(width,.12,.15),'mid')
  for side in [-1,1]:s.box('Panel'+str(y)+str(side),(side*(width/2-.15),y+.35,0),(.30,.85,.72),'light')
 s.box('Beacon',(0,14.1,0),(.4,.2,.4),'mark')
 s.label('ID','S01 / SIGNAL',(0,.9,.61),15)
 result['Signal']=s.serialize()
 return result

def reserved(x,z):
 # Full-width 4m service corridors between device banks, 8m central cross, 4m perimeter ring.
 return abs(x)<=2 or abs(z)<=2 or abs(x) in [10,26] or abs(z) in [18,26] or (abs(x)==18 and abs(z)<16)

def layout(seed):
 rng=random.Random(seed);items=[]
 def add(kind,x,z,turn=0):
  ident=f'{kind}{sum(i["type"]==kind for i in items)+1:02}'
  items.append(dict(id=ident,type=kind,position=[x,0,z],rotation_y=turn*90,footprint=list(SIZES[kind])));return ident
 connections=[]
 for x in [-18,18]:
  c=add('C',x,0);south=add('D',x,10);north=add('D',x,-10,2)
  connections.extend([[south,'Top',c,'South'],[north,'Top',c,'North']])
 slots=[(x,z) for x in range(-30,31,4) for z in range(-30,31,4) if not reserved(x,z)]
 anchors=[(-6,-6),(6,-6),(-6,6),(6,6)]
 rest=[p for p in slots if p not in anchors];rng.shuffle(rest)
 # Spread the other eight towers across quadrants; keep random ordering deterministic.
 for sx,sz in [(-1,-1),(-1,1),(1,-1),(1,1)]:
  anchors += [p for p in rest if p[0]*sx>0 and p[1]*sz>0][:2]
 for index,(x,z) in enumerate(anchors):
  add('B',x,z,rng.randrange(4));items[-1]['subtype']='B1' if index%2==0 else 'B2'
 candidates=[p for p in slots if p not in anchors]
 # Rank by proximity to towers, with seeded tie breaks: single/double rows within device banks.
 ranked=sorted(candidates,key=lambda p:(min(abs(p[0]-q[0])+abs(p[1]-q[1]) for q in anchors),rng.random()))
 for x,z in ranked[:40]:add('A',x,z,rng.randrange(4))
 landmarks=[dict(id='SignalTower',type='Signal',position=[0,0,0],rotation_y=0,footprint=[2,2])]
 markers={'Spawn':[0,.05,29],'FiringLine':[0,.05,20],'OverviewFocus':[0,0,0],
          'OverviewCamera':[52,62,70],'UnderbridgeWest':[-18,.05,0],'UnderbridgeEast':[18,.05,0]}
 targets=[dict(id=f'Target{i+1}',position=p,shoot_from=q) for i,(p,q) in enumerate([
  ([0,0,10],[0,.05,20]),([1.5,0,0],[1.5,.05,20]),([-1.5,0,-10],[-1.5,.05,20]),
  ([-10,0,-8],[-10,.05,12]),([10,0,-8],[10,.05,12])])]
 routes={
 'signal_loop':[[-2.6,0,2.6],[2.6,0,2.6],[2.6,0,-2.6],[-2.6,0,-2.6],[-2.6,0,2.6]],
 'perimeter':[[0,0,29],[0,0,26],[26,0,26],[26,0,-26],[-26,0,-26],[-26,0,26],[0,0,26]],
 'cross':[[0,0,26],[0,0,14],[3,0,14],[3,0,-26],[0,0,-26],[0,0,-2],[-26,0,-2],[26,0,-2]],
 'west_service':[[-10,0,18],[-10,0,-4],[-12,0,-4],[-12,0,-12],[-10,0,-12],[-10,0,-26]],
 'east_service':[[10,0,18],[10,0,-4],[12,0,-4],[12,0,-12],[10,0,-12],[10,0,-26]],
 }
 # Service route detours around targets use x=±10 corridor edges; place targets off route center instead below.
 for side,x in [('west',-18),('east',18)]:
  routes[side+'_elevated']=[[x,0,18],[x,2.4,6],[x,2.4,0],[x,2.4,-6],[x,0,-18],[x,2.4,-6],[x,2.4,6],[x,0,18]]
 # Place side targets against corridor side without obstructing traversal center.
 targets[3]['position'][0]=-11.3;targets[3]['shoot_from'][0]=-11.3
 targets[4]['position'][0]=11.3;targets[4]['shoot_from'][0]=11.3
 routes['west_service']=[[-10,0,18],[-10,0,-26]];routes['east_service']=[[10,0,18],[10,0,-26]]
 return dict(version=3,landmarks=landmarks,theme='lunar_energy',seed=seed,size=[64,66],area_m2=4224,grid_m=4,modules=items,connections=connections,markers=markers,targets=targets,routes=routes,
  boundaries=[dict(position=[-31,0,0],direction=[-1,0,0]),dict(position=[31,0,0],direction=[1,0,0]),dict(position=[0,0,32],direction=[0,0,1]),dict(position=[0,0,-32],direction=[0,0,-1])])

def rect(i):
 x,_,z=i['position'];w,d=i['footprint']
 if i['rotation_y']%180:w,d=d,w
 return x-w/2,z-d/2,x+w/2,z+d/2

def validate(data):
 errors=[];items=data['modules'];counts=Counter(i['type'] for i in items)
 subtypes=Counter(i.get('subtype') for i in items if i['type']=='B')
 if subtypes!={'B1':6,'B2':6}:errors.append('thermal subtype budget '+str(subtypes))
 if len(data['landmarks'])!=1 or data['landmarks'][0]['position']!=[0,0,0]:errors.append('central landmark')
 if counts!={'A':40,'B':12,'C':2,'D':4}:errors.append(f'counts {counts}')
 all_items=items+data['landmarks']
 for n,i in enumerate(all_items):
  r=rect(i)
  if r[0]<-32 or r[2]>32 or r[1]<-32 or r[3]>32:errors.append('bounds '+i['id'])
  if i['type'] in 'AB' and reserved(i['position'][0],i['position'][2]):errors.append('reserved '+i['id'])
  for j in all_items[:n]:
   q=rect(j)
   if min(r[2],q[2])-max(r[0],q[0])>1e-5 and min(r[3],q[3])-max(r[1],q[1])>1e-5:errors.append('overlap '+i['id']+' '+j['id'])
 # 1m navigation sample: inflate ground devices by capsule radius. Ramps are checked as elevated routes separately.
 blocked=[rect(i) for i in items if i['type'] in 'ABD']+[rect(i) for i in data['landmarks']]
 def free(x,z):return not any(a-.33<x<b+.33 and c-.33<z<d+.33 for a,c,b,d in blocked)
 space={(x,z) for x in range(-31,32) for z in range(-32,33) if free(x,z)}
 seen={(0,29)};todo=deque(seen)
 while todo:
  x,z=todo.popleft()
  for p in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
   if p in space and p not in seen:seen.add(p);todo.append(p)
 for name,route in data['routes'].items():
  if name.endswith('elevated'):continue
  for x,y,z in route:
   if (round(x),round(z)) not in seen:errors.append('unreachable '+name+str((x,z)))
  for a,b in zip(route,route[1:]):
   for step in range(201):
    t=step/200;x=a[0]+(b[0]-a[0])*t;z=a[2]+(b[2]-a[2])*t
    if not free(x,z):errors.append('route segment blocked '+name);break
 for target in data['targets']:
  x,_,z=target['shoot_from'];tx,_,tz=target['position']
  for step in range(101):
   t=step/100;px=x+(tx-x)*t;pz=z+(tz-z)*t
   if not free(px,pz):errors.append('blocked shot '+target['id']);break
 lookup={i['id']:i for i in items}
 for d,dp,c,cp in data['connections']:
  a=lookup[d];b=lookup[c];topz=a['position'][2]+(-6 if a['rotation_y']==0 else 6);cz=b['position'][2]+(4 if cp=='South' else -4)
  if a['position'][0]!=b['position'][0] or topz!=cz:errors.append('socket '+d)
 if errors:raise ValueError('; '.join(errors))
 return dict(counts=dict(counts),thermal_subtypes=dict(subtypes),unique_theme_resources=6,instances=len(all_items),reachable_ground_samples=len(seen),checks=['counts','bounds','overlaps','reserved_corridors','ground_connectivity','shooting_lanes','elevated_sockets'])

def training(data):
 s=Scene('Training','training');s.nodes[0]+='\nmetadata/layout_path = "res://docs/design/energy-layout.json"'
 env=s.res('Environment','background_mode = 1\nbackground_color = Color(0.035,0.047,0.06,1)\nambient_light_source = 3\nambient_light_color = Color(0.78,0.84,0.92,1)\nambient_light_energy = 0.4')
 s.node('Environment','WorldEnvironment',props=f'environment = SubResource("{env}")')
 s.node('Sun','DirectionalLight3D',props='rotation_degrees = Vector3(-38,-32,0)\nlight_energy = 0.8\nshadow_enabled = true\ndirectional_shadow_max_distance = 150.0')
 s.box('Ground',(0,-.3,0),(64,.6,66),'ground')
 for x in range(-32,33):s.box(f'GridX{x+32}',(x,.003,0),(.025 if x%4==0 else .008,.005,66),'mid',solid=False)
 for z in range(-33,34):s.box(f'GridZ{z+33}',(0,.003,z),(64,.005,.025 if z%4==0 else .008),'mid',solid=False)
 for name,pos,size in [('West',(-32.4,1.5,0),(.8,3,66)),('East',(32.4,1.5,0),(.8,3,66)),('North',(0,1.5,-33.4),(65.6,3,.8)),('South',(0,1.5,33.4),(65.6,3,.8))]:s.box('Boundary'+name,pos,size,'mid')
 s.group('Facility')
 for kind in ['A','B1','B2','C','D','Signal']:s.ext.append(f'[ext_resource type="PackedScene" path="res://assets/industrial/module_{kind}.tscn" id="{kind}"]')
 for i in data['modules']:s.nodes.append(f'[node name="{i["id"]}" parent="Facility" instance=ExtResource("{i.get("subtype",i["type"])}")]\nposition = {v(i["position"])}\nrotation_degrees = Vector3(0,{i["rotation_y"]},0)')
 s.group('Landmarks')
 for i in data['landmarks']:s.nodes.append(f'[node name="{i["id"]}" parent="Landmarks" instance=ExtResource("Signal")]\nposition = {v(i["position"])}')
 s.group('Markers')
 for name,pos in data['markers'].items():s.node(name,'Marker3D','Markers',f'position = {v(pos)}')
 s.ext += ['[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="player"]','[ext_resource type="PackedScene" path="res://scenes/target.tscn" id="target"]']
 s.nodes.append(f'[node name="Player" parent="." instance=ExtResource("player")]\nposition = {v(data["markers"]["Spawn"])}')
 for i,t in enumerate(data['targets']):s.nodes.append(f'[node name="{t["id"]}" parent="." instance=ExtResource("target")]\nposition = {v(t["position"])}\nlabel_text = "T{i+1:02}"')
 s.node('Overview','Camera3D',props=f'position = {v(data["markers"]["OverviewCamera"])}\nfov = 53.0\nfar = 220.0')
 s.box('FiringLine',(0,.015,20),(7,.025,.12),'mark',solid=False)
 for dist in [10,20,30]:s.label('Distance'+str(dist),str(dist)+' m',(-3,.02,20-dist),25,rot=(-math.pi/2,0,0))
 for x,label in [(-18,'WEST / POWER'),(18,'EAST / POWER')]:s.label('Zone'+str(x),label,(x,.025,23),32,rot=(-math.pi/2,0,0))
 s.label('Entry','LUNAR ENERGY / TRAINING',(0,.03,31),36,rot=(-math.pi/2,0,0))
 return s.serialize()

def build(seed=DEFAULT_SEED,art='final'):
 data=layout(seed);data['validation']=validate(data);data['asset_mode']=art
 output={}
 for k,text in modules().items():
  if art=='final':
   asset='E' if k=='Signal' else k
   if not (ROOT/f'assets/environment/{asset}/{asset}.glb').exists():raise ValueError('Missing final asset '+asset)
   text=text.replace('[gd_scene format=3]', '[gd_scene format=3]\n\n[ext_resource type="Script" path="res://scripts/module_visual.gd" id="environment_art"]')
   text=re.sub(r'(\[node name="[^"]+" type="Node3D"\]\n)',lambda m:m.group(1)+f'script = ExtResource("environment_art")\nasset_id = "{asset}"\n',text,count=1)
  output[f'assets/industrial/module_{k}.tscn']=text
 output['docs/design/energy-layout.json']=json.dumps(data,indent=2)+'\n';output['scenes/training.tscn']=training(data)
 return output

def main():
 p=argparse.ArgumentParser();p.add_argument('--seed',type=int,default=DEFAULT_SEED);p.add_argument('--output-dir',type=Path,default=ROOT);p.add_argument('--art',choices=['whitebox','final'],default='final');a=p.parse_args()
 output=build(a.seed,a.art) # Validate and serialize all data before touching accepted outputs.
 for name,text in output.items():
  dest=a.output_dir/name;dest.parent.mkdir(parents=True,exist_ok=True)
  with tempfile.NamedTemporaryFile(mode='w',dir=dest.parent,delete=False) as f:f.write(text);tmp=f.name
  os.replace(tmp,dest)
 print(f'Built lunar energy facility seed={a.seed}, 4 families (B1/B2) + signal / 59 instances / 4224 m2')
if __name__=='__main__':main()
