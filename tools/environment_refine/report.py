"""Assemble evidence links, without inferring visual or user acceptance."""
import argparse,json
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--asset',required=True);p.add_argument('--phase',default='candidate');a=p.parse_args();R=Path(__file__).resolve().parents[2];A=a.asset;D=R/'docs/validation/environment-refine-v2'/A
m=json.loads((R/'art_source/environment/refine-v2'/A/'manifest.json').read_text());audit=json.loads((D/'audit.json').read_text())
html=['<!doctype html><meta charset="utf-8"><title>ML15 '+A+'</title><style>body{background:#171c22;color:#eee;font:16px system-ui;margin:30px}section{display:grid;grid-template-columns:1fr 1fr;gap:12px}img{width:100%}figure{margin:0}a{color:#5df}</style>',f'<h1>{A} · 原生 Godot 对照</h1><p>同相机/曝光/分辨率；概念图不在实机栏中。<a href="REPORT.md">检查报告与未完成项</a></p><section>']
for phase,label in [('baseline','旧版'),(a.phase,'ML15')]:html+=[f'<figure>{label}<img src="{phase}/pbr-front.png"></figure>']
for mode in ['gray','pbr']:
 for view in ['front','back','left','right']:html+=[f'<figure>{mode} {view}<img loading="lazy" src="{a.phase}/{mode}-{view}.png"></figure>']
for file in ['range','lights-on-no-bloom','emission-only','lights-off','lights-bloom','distance-3','distance-10','distance-20']:
 if (D/a.phase/(file+'.png')).exists():html+=[f'<figure>{file}<img loading="lazy" src="{a.phase}/{file}.png"></figure>']
html+=['</section>'];(D/'review.html').write_text('\n'.join(html))
print(A,m['triangles'],audit['passed'])
