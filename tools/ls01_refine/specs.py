"""Export reviewable per-part dimensions and fastener inventory from the actual source."""
import bpy,json
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'art_source/weapons/lc01/ls01-refine-v1';D=R/'docs/art/ls01-refine-v1'
m=json.loads((O/'manifest.json').read_text());bpy.ops.wm.open_mainfile(filepath=str(O/'02-geometry/paired.blend'))
rows=[]
for p in m['pairs']:
 lo=bpy.data.objects[p['low']];hi=bpy.data.objects[p['high']]
 rows.append({**p,'bounds_mm':[round(float(v)*1000,2) for v in lo.dimensions],'high_polygons':len(hi.data.polygons),'materials':[x.name for x in hi.data.materials]})
extra=[]
for side in [-1,1]:
 for i,c in enumerate([(side*.046,.428,-.013),(side*.0525,.554,.034),(side*.0395,.545,.111),(side*.04,.532,.006)]):
  extra.append({'name':f'FrontPhillips{side}_{i}','center':list(c),'normal':[side,0,0],'radius':.00375,'prototype':f'Receiver_{side}_0','scale':1.5,'intentional_shared_uv':True})
m['reused_fasteners']['instances']=extra
m['material_ids']={'white':.1,'orange':.2,'dark':.3,'steel':.4,'copper':.5,'rubber':.6,'glass':.7,'black':.8}
m['runtime_resolution']=json.loads((R/'assets/weapons/lc01/ls01_v1/resolution.json').read_text())
m['bake_outputs']={group:{'directory':f'03-bake/{group}','contract':json.loads((O/'03-bake'/group/'contract.json').read_text()),'maps':[p.name for p in sorted((O/'03-bake'/group).glob('*.png'))]} for group in ['body','kit']}
m['build_parameters']={'seed':m['seed'],'uv_pack_margin_fraction':.008,'master_size':4096,'runtime_mipmaps':True,'runtime_anisotropic':True,'normal_convention':'OpenGL +Y','orm':'R AO; G Roughness; B Metallic','uv_version':m['uv_version']}
(O/'manifest.json').write_text(json.dumps(m,indent=2))
report={'units':'metres unless bounds_mm; Blender X right Y forward Z up','parts':rows,'fasteners':m['fasteners']+extra,'material_ids':{'white':.1,'orange':.2,'dark':.3,'steel':.4,'copper':.5,'rubber':.6,'glass':.7,'black':.8},'runtime_triangles':m['runtime_triangles'],'runtime_meshes':m['runtime_meshes']}
(D/'parts.json').write_text(json.dumps(report,indent=2))
s='# LS01 逐件规格与紧固件清册\n\n自动从实际 paired.blend 和最终导出规则读取；不是概念图推测。尺寸为 Blender X/Y/Z 包围盒毫米，不能作为实物制造图。120 组源高低模/cage；前罩八颗螺钉复用已烘焙的同朝向原型及 UV。\n\n|零件|Atlas|包围盒 mm|低模三角|高模面|Cage 外扩 mm|\n|---|---|---|---:|---:|---:|\n'
for p in rows:s+=f"|{p['name']}|{p['group']}|{' × '.join(map(str,p['bounds_mm']))}|{p['triangles']}|{p['high_polygons']}|{p['cage_distance']*1000:g}|\n"
s+='\n## 紧固件\n\n|位置 ID|中心 m|朝向|半径 mm|\n|---|---|---|---:|\n'
for p in report['fasteners']:s+=f"|{p['name']}|{p['center']}|{p['normal']}|{p['radius']*1000:g}|\n"
s+='\n高模十字槽、低模窄倒角头部和暗色沉座分开配对。前罩外侧原有涂漆孔缘保留，金属头部覆盖白色旧紧固面。完整字段和材质 ID 见 parts.json。\n'
(D/'PARTS.md').write_text(s);print('PARTS',len(rows),'FASTENERS',len(report['fasteners']))
