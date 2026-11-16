import bpy,json,sys,argparse
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent));from fixture_spec import fixtures
R=Path(__file__).resolve().parents[2];a=argparse.ArgumentParser();a.add_argument('--asset',required=True);a.add_argument('--out');a.add_argument('--runtime');args=a.parse_args(sys.argv[sys.argv.index('--')+1:]);A=args.asset;O=Path(args.out or R/'art_source/environment/refine-v2'/A);D=Path(args.runtime or R/'assets/environment/candidates'/A);D.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'));m=json.loads((O/'manifest.json').read_text());lows=[bpy.data.objects[p['low']] for p in m['pairs']]
bpy.ops.object.select_all(action='DESELECT')
for lo in lows:lo.hide_set(False);lo.hide_render=False;lo.select_set(True)
bpy.context.view_layer.objects.active=lows[0];bpy.ops.object.join();ob=bpy.context.object;ob.name=A+'_Static'
mat=bpy.data.materials.new(A+'_Atlas');mat.diffuse_color=(.55,.55,.55,1);ob.data.materials.clear();ob.data.materials.append(mat)
for p in ob.data.polygons:p.material_index=0
bpy.ops.export_scene.gltf(filepath=str(D/(A+'.glb')),export_format='GLB',use_selection=True,export_tangents=True,export_materials='NONE')
(D/'bindings.json').write_text(json.dumps({'version':'ml15-v1','asset':A,'meshes':{A+'_Static':'body'},'atlases':{'body':'body'},'fixtures':{'mounts':fixtures(A)}},indent=2))
(D/'provenance.json').write_text(json.dumps({'asset':A,'revision':'ml15-v1','triangles':m['triangles'],'source':str(O.relative_to(R)),'normal':'Cycles selected-to-active explicit cage bake','texture_resolution':2048,'source_resolution':4096},indent=2))
print('ENV_EXPORTED',A)
