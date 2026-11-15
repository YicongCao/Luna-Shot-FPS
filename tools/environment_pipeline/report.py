"""Aggregate local stage provenance and recorded billing without contacting generators."""
import json
from pathlib import Path
R=Path(__file__).resolve().parents[2];B=R/'art_source/environment/pipeline-v1';O=R/'docs/validation/environment-pipeline-v1';O.mkdir(parents=True,exist_ok=True)
counts=dict(A=40,B1=6,B2=6,C=2,D=4,E=1);budgets=dict(A=8000,B1=14000,B2=14000,C=16000,D=18000,E=20000);rows=[]
for asset,count in counts.items():
 d=B/asset
 high=json.loads((d/'02-high/geometry-report.json').read_text());low=json.loads((d/'04-low/audit.json').read_text());bake=json.loads((d/'05-bake/bake-report.json').read_text());final=json.loads((d/'07-final/material-transfer-report.json').read_text())
 assert bake['completed'] and final['final_triangles']<=budgets[asset]
 assert final['unmatched_triangles']==0 and final['uv_out_of_bounds_triangles']==0
 assert all(p['uv_oob']==0 and p['degenerate_uv']==0 for p in low['parts'])
 rows.append(dict(asset=asset,instances=count,high_triangles=high['triangles'],runtime_triangles=final['final_triangles'],uv_coverage=final['uv_coverage_fraction'],uv_overlap_pixels=final['strict_interior_overlap_pixels'],actual_bake=True,material_slots=final['material_slots']))
report={'independent_assets':6,'instances':59,'assets':rows,'instanced_triangles':sum(r['instances']*r['runtime_triangles'] for r in rows)}
(O/'pipeline.json').write_text(json.dumps(report,indent=2))
text='# 六资产管线验证\n\n实际数据；原生路线与视觉证据见同目录。\n\n|资产|实例|高模三角|运行时三角|UV 覆盖|内部重叠像素|\n|---|---:|---:|---:|---:|---:|\n'
for r in rows:text+=f"|{r['asset']}|{r['instances']}|{r['high_triangles']:,}|{r['runtime_triangles']:,}|{r['uv_coverage']:.1%}|{r['uv_overlap_pixels']}|\n"
text+='\n每件 2K BaseColor、切线空间 NormalGL、ORM（R 为实际烘焙 AO）。高模和低模均独立保留；运行时合并为一网格、一材质。UV 越界和退化为 0，微量重叠如表记录，不宣称完美拓扑。远端归一化尺度已恢复到米制白模接口。\n\n'
text+=f"实例总计 {report['instanced_triangles']:,} 三角（未计基础设施与枪械）；59 次摆放复用六件资产。\n"
(O/'PIPELINE.md').write_text(text)
print(json.dumps(report,indent=2))
