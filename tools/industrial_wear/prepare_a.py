"""Rebuild ONLY the high source. Boolean each closed lid individually, never joined shells."""
from pathlib import Path
import shutil
R=Path(__file__).resolve().parents[2];O=R/'art_source/industrial-wear-v1/A';(O/'02-low').mkdir(parents=True,exist_ok=True)
shutil.copy2(R/'art_source/environment/A-refine-v2/02-low/A-low.blend',O/'02-low/A-low.blend')
s=(R/'tools/a_refine/build.py').read_text().replace('art_source/environment/A-refine-v2','art_source/industrial-wear-v1/A').replace('for HIGH in [True,False]:','for HIGH in [True]:')
s=s.replace(" objs.append(o);return o",''' if HIGH and name.startswith('Lid_'):
  cutters=[];x,y,z=o.location
  for dx in [-.35,.35]:
   bpy.ops.mesh.primitive_cube_add(size=1,location=(x+dx,y,1.192));c=bpy.context.object;c.scale=(.014,1.10,.024);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);cutters.append(c)
  for dx in [-.43,.43]:
   for dy in [-.74,.74]:
    bpy.ops.mesh.primitive_cone_add(vertices=24,radius1=.012,radius2=.029,depth=.022,location=(x+dx,y+dy,1.190));cutters.append(bpy.context.object)
  bpy.ops.object.select_all(action='DESELECT')
  for c in cutters:c.select_set(True)
  bpy.context.view_layer.objects.active=cutters[0];bpy.ops.object.join();c=bpy.context.object
  bpy.context.view_layer.objects.active=o;m=o.modifiers.new('TrueRecesses','BOOLEAN');m.operation='DIFFERENCE';m.solver='EXACT';m.object=c;bpy.ops.object.modifier_apply(modifier=m.name);bpy.data.objects.remove(c,do_unlink=True)
 objs.append(o);return o''')
s=s.replace("cylinder(name,p,.018,.012,'alloy',axis)","p=(p[0],p[1],1.182) if name=='LidCaptiveScrew' else p\n cylinder(name,p,.011 if name=='LidCaptiveScrew' else .018,.003 if name=='LidCaptiveScrew' else .012,'alloy',axis)")
s=s.replace("if HIGH:\n  for x in [-1.29,-.18,.93]:","if False:\n  for x in [-1.29,-.18,.93]:")
exec(compile(s,str(R/'tools/industrial_wear/prepare_a.py'),'exec'))
