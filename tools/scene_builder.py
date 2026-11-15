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
  (ROOT/path).write_text(self.serialize())
 def serialize(self):
  return '[gd_scene format=3]\n\n'+'\n\n'.join(self.ext+self.resources+self.nodes)+'\n'
