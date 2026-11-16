"""Layered, lighting-free source shaders; bake channels remain inspectable."""
import bpy
COLORS={'coat':(.58,.57,.51),'dark':(.035,.047,.058),'steel':(.40,.45,.49),'rubber':(.012,.017,.020),'yellow':(.82,.44,.025),'core':(.065,.078,.087),'tread':(.16,.19,.20)}
def create(kind):
 m=bpy.data.materials.new('ML15_'+kind);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;n.clear()
 def node(t,name=''):
  q=n.new(t)
  if name:q.name=name;q.label=name
  return q
 def math(op,a,b):
  q=node('ShaderNodeMath');q.operation=op
  for i,x in enumerate([a,b]):
   if hasattr(x,'node'):l.new(x,q.inputs[i])
   else:q.inputs[i].default_value=x
  return q.outputs[0]
 def mix(f,a,b):
  q=node('ShaderNodeMixRGB');l.new(f,q.inputs[0])
  for i,x in enumerate([a,b],1):
   if hasattr(x,'node'):l.new(x,q.inputs[i])
   else:q.inputs[i].default_value=(*x,1)
  return q.outputs[0]
 tc=node('ShaderNodeTexCoord');g=node('ShaderNodeNewGeometry')
 def noise(scale):
  q=node('ShaderNodeTexNoise');q.inputs['Scale'].default_value=scale;q.inputs['Detail'].default_value=2;l.new(tc.outputs['Object'],q.inputs['Vector']);return q.outputs['Fac']
 broad=noise(4);micro=noise(480);scuff=noise(60)
 # Per-primitive bounds survive joined bake groups. Pointiness on a sparse box
 # interpolates across the whole face and must not become an all-over wear mask.
 def vec(op,a,b):
  q=node('ShaderNodeVectorMath');q.operation=op;l.new(a,q.inputs[0]);l.new(b,q.inputs[1]);return q.outputs[0]
 mn=node('ShaderNodeAttribute');mn.attribute_name='panel_min'
 mx=node('ShaderNodeAttribute');mx.attribute_name='panel_max'
 near=vec('MINIMUM',vec('SUBTRACT',tc.outputs['Object'],mn.outputs['Vector']),vec('SUBTRACT',mx.outputs['Vector'],tc.outputs['Object']))
 sep=node('ShaderNodeSeparateXYZ');l.new(near,sep.inputs[0]);x,y,z=[sep.outputs[i] for i in range(3)]
 median=math('MINIMUM',math('MINIMUM',math('MAXIMUM',x,y),math('MAXIMUM',x,z)),math('MAXIMUM',y,z))
 edge=math('MAXIMUM',math('SUBTRACT',1,math('MULTIPLY',median,200)),0)
 wear=math('MULTIPLY',edge,math('GREATER_THAN',scuff,.55))
 oil=math('MULTIPLY',math('MAXIMUM',math('SUBTRACT',broad,.55),0),1.8)
 dust=math('MULTIPLY',math('MAXIMUM',math('SUBTRACT',.40,broad),0),.7)
 c=COLORS[kind];coated=kind in ['coat','dark','yellow','tread'];metal=kind in ['steel','core']
 bc=mix(math('MULTIPLY',broad,.10),c,tuple(x*.7 for x in c))
 metallic=wear if coated else (1 if metal else 0)
 if coated:bc=mix(wear,bc,(.28,.32,.35))
 bc=mix(oil,bc,tuple(x*.65 for x in c));bc=mix(dust,bc,(.17,.15,.12))
 rough={'coat':.48,'dark':.42,'steel':.29,'rubber':.8,'yellow':.28,'core':.5,'tread':.66}[kind]
 rough=math('ADD',rough,math('MULTIPLY',math('SUBTRACT',scuff,.5),.14));rough=math('SUBTRACT',rough,math('MULTIPLY',oil,.28));rough=math('ADD',rough,dust)
 metallic=math('MULTIPLY',metallic,math('SUBTRACT',1,math('MINIMUM',dust,1)))
 bs=node('ShaderNodeBsdfPrincipled');out=node('ShaderNodeOutputMaterial');l.new(bs.outputs[0],out.inputs['Surface']);l.new(bc,bs.inputs['Base Color']);l.new(rough,bs.inputs['Roughness']);l.new(metallic,bs.inputs['Metallic'])
 bump=node('ShaderNodeBump','Micropits');bump.inputs['Distance'].default_value=.0003;bump.inputs['Strength'].default_value=.23;l.new(micro,bump.inputs['Height']);l.new(bump.outputs[0],bs.inputs['Normal'])
 if kind=='tread':
  sep=node('ShaderNodeSeparateXYZ');l.new(tc.outputs['Object'],sep.inputs[0])
  ridges=[]
  for operation in ['ADD','SUBTRACT']:
   wave=math('MULTIPLY',math(operation,sep.outputs[0],sep.outputs[1]),48)
   q=node('ShaderNodeMath');q.operation='SINE';l.new(wave,q.inputs[0]);ridges.append(math('GREATER_THAN',q.outputs[0],.90))
  pattern=math('MAXIMUM',ridges[0],ridges[1]);q=node('ShaderNodeBump','Machined nonslip diamonds');q.inputs['Distance'].default_value=.0012;q.inputs['Strength'].default_value=.65;l.new(pattern,q.inputs['Height']);l.new(bump.outputs[0],q.inputs['Normal']);l.new(q.outputs[0],bs.inputs['Normal'])
 for name,socket in [('BaseColor',bc),('Roughness',rough),('Metallic',metallic),('WearMask',wear),('OilMask',oil),('Curvature',edge)]:
  q=node('NodeReroute','CHANNEL_'+name);l.new(socket,q.inputs[0])
 q=node('ShaderNodeRGB','MATERIAL_ID');i=list(COLORS).index(kind)+1;q.outputs[0].default_value=(i/8,i/8,i/8,1)
 return m
