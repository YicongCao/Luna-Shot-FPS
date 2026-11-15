#!/usr/bin/env python3
"""Deterministic editable Godot scenes. All dimensions in metres, Y up, north -Z."""
from pathlib import Path
import math, json
ROOT=Path(__file__).resolve().parents[1]
def v(a): return 'Vector3('+', '.join(f'{x:.6f}' for x in a)+')'
class Scene:
 def __init__(self, root, script=None):
  self.resources=[]; self.nodes=[]; self.i=0; self.ext=[]; self.inventory=[]
  if script:self.ext.append(f'[ext_resource type="Script" path="res://scripts/{script}.gd" id="script"]')
  self.nodes.append(f'[node name="{root}" type="Node3D"]'+ ('\nscript = ExtResource("script")' if script else ''))
  self.materials={}
  for name,color in [('chalk',(.76,.78,.78)),('light',(.9,.9,.87)),('mid',(.46,.51,.54)),('dark',(.18,.23,.27)),('ground',(.36,.40,.43)),('mark',(.67,.47,.31))]:
   self.materials[name]=self.res('StandardMaterial3D',f'albedo_color = Color({color[0]}, {color[1]}, {color[2]}, 1)\nroughness = 0.88')
 def res(self,typ,props):
  self.i+=1; name=f'R{self.i}';self.resources.append(f'[sub_resource type="{typ}" id="{name}"]\n{props}');return name
 def node(self,name,typ,parent='.',props=''):
  self.nodes.append(f'[node name="{name}" type="{typ}" parent="{parent}"]\n{props}');return name if parent=='.' else parent+'/'+name
 def group(self,name,pos=(0,0,0),parent='.'):
  return self.node(name,'Node3D',parent,f'position = {v(pos)}')
 def box(self,name,pos,size,mat='chalk',parent='.',solid=True,rot=(0,0,0),layer=1):
  mesh=self.res('BoxMesh',f'size = {v(size)}\nmaterial = SubResource("{self.materials[mat]}")')
  return self.primitive(name,pos,mesh,'BoxShape3D',f'size = {v(size)}',parent,solid,rot,layer,size)
 def cyl(self,name,pos,r,h,mat='chalk',parent='.',solid=True,rot=(0,0,0)):
  mesh=self.res('CylinderMesh',f'top_radius = {r}\nbottom_radius = {r}\nheight = {h}\nradial_segments = 24\nmaterial = SubResource("{self.materials[mat]}")')
  return self.primitive(name,pos,mesh,'CylinderShape3D',f'radius = {r}\nheight = {h}',parent,solid,rot,1,(2*r,h,2*r))
 def primitive(self,name,pos,mesh,shape,props,parent,solid,rot,layer,size):
  path=self.node(name,'StaticBody3D' if solid else 'Node3D',parent,f'position = {v(pos)}\nrotation = {v(rot)}'+(f'\ncollision_layer = {layer}\ncollision_mask = 0' if solid else ''))
  self.node('Mesh','MeshInstance3D',path,f'mesh = SubResource("{mesh}")')
  if solid:
   sid=self.res(shape,props);self.node('Collision','CollisionShape3D',path,f'shape = SubResource("{sid}")')
  self.inventory.append(dict(name=path,position=pos,size=size,rotation=rot,collision=solid));return path
 def label(self,name,text,pos,size=55,parent='.',rot=(0,0,0)):
  return self.node(name,'Label3D',parent,f'position = {v(pos)}\nrotation = {v(rot)}\ntext = "{text}"\nfont_size = {size}\npixel_size = 0.012\nmodulate = Color(0.16, 0.21, 0.24, 1)\noutline_size = 0\nno_depth_test = false')
 def save(self,path):
  (ROOT/path).write_text('[gd_scene format=3]\n\n'+'\n\n'.join(self.ext+self.resources+self.nodes)+'\n')

s=Scene('Training','training')
env=s.res('Environment','background_mode = 1\nbackground_color = Color(0.035, 0.047, 0.06, 1)\nambient_light_source = 3\nambient_light_color = Color(0.78, 0.84, 0.92, 1)\nambient_light_energy = 0.4\ntonemap_mode = 0')
s.node('Environment','WorldEnvironment',props=f'environment = SubResource("{env}")')
s.node('Sun','DirectionalLight3D',props='rotation_degrees = Vector3(-38, -32, 0)\nlight_color = Color(1, 0.95, 0.87, 1)\nlight_energy = 0.8\nshadow_enabled = true\ndirectional_shadow_max_distance = 110.0')
s.box('Ground',(0,-.3,0),(44,.6,48),'ground')
# One-metre ground grid, five-metre major lines. Physical surface stays perfectly flat.
for x in range(-22,23):s.box(f'GridX{x+22}',(x,.003,0),(.025 if x%5==0 else .009,.005,48),'mid',solid=False)
for z in range(-24,25):s.box(f'GridZ{z+24}',(0,.003,z),(44,.005,.025 if z%5==0 else .009),'mid',solid=False)
for name,pos,size in [('West',(-22.4,1.5,0),(.8,3,49)),('East',(22.4,1.5,0),(.8,3,49)),('North',(0,1.5,-24.4),(44,3,.8)),('South',(0,1.5,24.4),(44,3,.8))]:s.box('Boundary'+name,pos,size,'mid')
base=s.group('A01_Base')
s.box('Deck',(0,1.2,-16.5),(28,2.4,3),'chalk',base)
s.box('MainBlock',(0,3.5,-21),(20,7,6),'chalk',base)
s.box('WestModule',(-11.5,2.6,-21),(5,5.2,6),'light',base)
s.box('EastModule',(11.5,2.6,-21),(5,5.2,6),'light',base)
s.box('UpperBlock',(0,7.6,-21),(12,1.2,5),'light',base)
s.box('WindowBand',(0,5.5,-17.96),(17,1,.10),'dark',base)
s.box('AirlockBack',(0,3.7,-17.85),(3.2,2.6,.2),'dark',base)
for x in [-1.95,1.95]:s.box('DoorJamb'+str(x),(x,3.8,-17.55),(.65,2.8,.65),'light',base)
s.box('DoorHeader',(0,5.25,-17.55),(4.5,.5,.65),'light',base)
s.label('BaseID','01 / HABITAT',(0,6.6,-17.9),60,base)
s.label('Closed','SEALED',(0,3.7,-17.7),30,base)
# Actual ramp surfaces: rotated thin boxes, top rises from 0 at z=-7 to 2.4 at z=-15.
a=math.atan2(2.4,8);th=.16
for x in [-5,5]:
 s.box('Ramp'+str(x),(x,1.2-th/2*math.cos(a),-11-th/2*math.sin(a)),(3,th,math.hypot(8,2.4)),'light',base,rot=(a,0,0))
 for edge in [-1.65,1.65]:
  s.box('RampRail'+str(x)+str(edge),(x+edge,1.2+.95,-11),(.1,.12,math.hypot(8,2.4)),'mid',base,rot=(a,0,0))
  for z in [-7,-11,-15]:s.box('Post'+str(x)+str(edge)+str(z),(x+edge,(-z-7)*.3+.45,z),(.12,.9,.12),'mid',base)
for x,w in [(-10.5,7),(0,6),(10.5,7)]:s.box('DeckRail'+str(x),(x,3.4,-14.94),(w,.14,.14),'mid',base)
# West ship proxy: broad delta wings, faceted tapered hull, twin vertical fins.
ship=s.group('A02_Ship',(-12.5,0,-1))
s.box('LandingPad',(0,-.06,0),(12,.12,14),'mid',ship)
s.box('ClosedBelly',(0,.85,0),(3.3,1.6,7),'dark',ship)
s.box('Hull',(0,2,0),(3.7,1.5,7.5),'light',ship)
s.box('Nose',(0,1.75,4.4),(2.2,.9,2.2),'chalk',ship,rot=(.15,0,0))
s.box('Cockpit',(0,2.9,1),(2.5,.65,3),'mid',ship,rot=(.12,0,0))
for side in [-1,1]:
 s.box('Wing'+str(side),(side*3.6,1.65,-.2),(4.1,.45,4.5),'chalk',ship,rot=(0,side*.24,side*.04))
 s.box('Fin'+str(side),(side*2,3.8,-3),( .25,3.2,1.8),'light',ship,rot=(.2,0,side*-.15))
 s.cyl('Engine'+str(side),(side*2,2,-3.4),.6,2.7,'mid',ship,rot=(math.pi/2,0,0))
s.label('PadID','02 / LANDING',(-12.5,.025,7),40,rot=(-math.pi/2,0,0))
oxy=s.group('A03_Oxygen')
for x in [14,18]:
 s.box('Foot'+str(x),(x,.4,-10),(3.2,.8,4),'mid',oxy)
 s.cyl('Tower'+str(x),(x,4.2,-10),1.35,7,'light',oxy)
 s.cyl('Collar'+str(x),(x,6.8,-10),1.5,.35,'mid',oxy)
 s.label('TankID'+str(x),'O2',(x,4.7,-8.63),70,oxy)
s.cyl('Header',(16,7.5,-10),.27,4,'mid',oxy,rot=(0,0,math.pi/2))
s.cyl('HorizontalTank',(16,1.65,-1),1.1,6,'chalk',oxy,rot=(0,0,math.pi/2))
s.box('TankSupport',(16,.35,-1),(7,.7,2.6),'mid',oxy)
s.box('SolarPanel',(18.5,7,-17),(5,.15,3.5),'mid',oxy,rot=(.35,0,0))
s.box('SolarMast',(18.5,3.5,-17),(.3,7,.3),'mid',oxy)
s.label('IndustryID','03 / OXYGEN',(16,3.5,1),45,oxy)
for i,(x,z,w,d,h) in enumerate([(-3,3,3,.9,1.05),(4,7,.9,3,1.05),(-4,10,3,.9,.9),(9,-4,1,3,1.2)]):s.box(f'A04_Cover{i}',(x,h/2,z),(w,h,d),'chalk')
for i,(x,z,w,d,h) in enumerate([(-10,16,4,2.4,1.8),(-13.3,16,2,2,1.1),(11,16,5,3,2.5)]):s.box(f'A05_Service{i}',(x,h/2,z),(w,h,d),'light')
s.label('ServiceID','04 / SERVICE',(11,3.1,17.6),40)
# Range lane at x=0, firing mark z=18, targets 10/20/30m away. Side targets give two traversal views.
s.ext.append('[ext_resource type="PackedScene" path="res://scenes/target.tscn" id="target"]')
for i,(x,z) in enumerate([(0,8),(1,-2),(-1,-12),(10,5),(-11,-10)]):
 s.nodes.append(f'[node name="Target{i+1}" parent="." instance=ExtResource("target")]\nposition = {v((x,0,z))}\nlabel_text = "T{i+1:02}"')
for dist in [10,20,30]:
 z=18-dist
 s.box('Distance'+str(dist),(0,.015,z),(4,.02,.08),'light',solid=False)
 s.label('DistanceLabel'+str(dist),str(dist)+' m',(-2.7,.03,z),25,rot=(-math.pi/2,0,0))
s.box('FiringLine',(0,.02,18),(5,.03,.15),'mark',solid=False)
s.label('FiringText','RANGE / 00',(0,.03,19.5),35,rot=(-math.pi/2,0,0))
s.ext.append('[ext_resource type="PackedScene" path="res://scenes/player.tscn" id="player"]')
s.nodes.append('[node name="Player" parent="." instance=ExtResource("player")]\nposition = Vector3(0, 0.05, 18)')
s.node('Overview','Camera3D',props='position = Vector3(36, 43, 49)\nfov = 53.0\nfar = 200.0\ncull_mask = 1')
s.save('scenes/training.tscn')
(ROOT/'docs/design/whitebox-inventory.json').write_text(json.dumps(s.inventory,indent=2)+'\n')
# Gun modules use rear-to-front local -Z. Grip top datum (0,0,0). Visual-only dimensions.
g=Scene('LC01_Whitebox')
parts=[('P01_Chassis',(0,.055,-.17),(.085,.12,.50),'mid'),('P02_LeftShell',(-.058,.085,-.13),(.035,.14,.35),'light'),('P03_RightShell',(.058,.085,-.13),(.035,.14,.35),'light'),('P04_ForeShroud',(0,.065,-.47),(.14,.14,.23),'chalk'),('P05_Stock',(0,.025,.16),(.12,.18,.16),'chalk'),('P06_Grip',(0,-.09,.015),(.075,.18,.085),'dark'),('P07_Cell',(0,-.095,-.15),(.09,.20,.12),'mid'),('P08_SightBase',(0,.17,-.12),(.08,.025,.105),'dark'),('P09_SightLeft',(-.044,.215,-.12),(.012,.075,.07),'chalk'),('P09_SightRight',(.044,.215,-.12),(.012,.075,.07),'chalk'),('P09_SightTop',(0,.2525,-.12),(.10,.012,.07),'chalk'),('P10_TriggerGuard',(0,-.055,-.055),(.025,.025,.065),'mid')]
for name,pos,size,mat in parts:g.box(name,pos,size,mat,solid=False)
g.cyl('P11_Muzzle',(0,.065,-.625),.044,.08,'mid',solid=False,rot=(math.pi/2,0,0))
for i in range(3):g.cyl('P12_Coil'+str(i),(0,.065,-.31-i*.043),.073,.018,'dark',solid=False,rot=(math.pi/2,0,0))
for name,pos in [('MuzzleSocket',(0,.065,-.67)),('SightRear',(0,.216,-.07)),('SightFront',(0,.216,-.17)),('GripR',(0,-.08,.015)),('GripL',(0,-.035,-.43)),('CellSocket',(0,-.04,-.15))]:g.node(name,'Marker3D',props=f'position = {v(pos)}')
g.save('assets/whitebox/lc01.tscn')
(ROOT/'docs/design/rifle-blockout-parts.json').write_text(json.dumps(g.inventory,indent=2)+'\n')
print('Built training scene and LC01 module scene')
