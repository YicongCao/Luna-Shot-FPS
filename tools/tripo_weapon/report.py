from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,os
import numpy as np
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/tripo-weapon-v3';O=R/'art_source/weapons/lc01/tripo-rebuild-v3'
a=json.loads((D/'audit.json').read_text());font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',24)
metrics=[]
for stage in ['01-high-pbr','02-low-pbr']:
 x=np.array(Image.open(D/f'{stage}-pbr-hero.png').convert('RGB')).astype(float);y=np.array(Image.open(D/f'{stage}-normal-off-hero.png').convert('RGB')).astype(float)
 delta=np.abs(x[110:850]-y[110:850]).mean(2);metrics.append({'stage':stage,'normal_toggle_changed_pixels_over_2percent':int((delta>5.1).sum())})
 assert (delta>5.1).sum()>100
board=Image.new('RGB',(1800,650),(18,25,34));draw=ImageDraw.Draw(board)
for i,(stage,title) in enumerate([('01-high-pbr','TRIPO HIGH + PBR / 1,934,290 triangles'),('02-low-pbr','TRIPO LOW + TRANSFERRED PBR / 20,303 triangles')]):
 im=Image.open(D/f'{stage}-pbr-hero.png').crop((170,220,1230,800));im.thumbnail((900,570));board.paste(im,(i*900,75));draw.text((i*900+16,16),title,font=font,fill='white')
board.save(D/'native-comparison.png')
# Inspectable input/output textures: receiver, energy cell and stock.
map_records=[]
for r in a[1:]:
 board=Image.new('RGB',(1200,1230),(18,25,34));draw=ImageDraw.Draw(board);draw.text((12,10),r['stage']+' / returned texture pixels',font=font,fill='white')
 for row,part in enumerate([3,4,8]):
  mat=next(m for m in r['materials'] if m['name'].split('_')[2]==str(part))
  for col,(label,index) in enumerate([('BaseColor',mat['pbrMetallicRoughness']['baseColorTexture']['index']),('NormalGL',mat['normalTexture']['index']),('MetallicRoughness',mat['pbrMetallicRoughness']['metallicRoughnessTexture']['index'])]):
   image_index=r['textures'][index]['source'];record=next(x for x in r['images'] if x['index']==image_index);p=R/record['file'];im=Image.open(p).convert('RGB');size=im.size;im.thumbnail((380,340));board.paste(im,(col*400+10,row*390+95));draw.text((col*400+10,row*390+53),f'part {part} / {label}',font=font,fill='white');map_records.append({'stage':r['stage'],'part':part,'channel':label,'size':size,'file':record['file']})
 board.save(D/(r['stage']+'-maps.png'))
(D/'normal-response.json').write_text(json.dumps(metrics,indent=2));(D/'selected-maps.json').write_text(json.dumps(map_records,indent=2))
page=['''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>ML17 Tripo枪械候选</title><style>body{max-width:1500px;margin:24px auto;padding:0 20px;background:#121a23;color:#eef;font:16px/1.6 system-ui}a{color:#7ee5e5}img{width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}h2{margin-top:36px}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>ML17 · 原高模 → Tripo PBR → Tripo低模与贴图转移</h1><p>本轮两项任务成功，20+35=55积分，无重抽。全部以下比较为原生Godot4.7.2 Compatibility独立材料场景；服务返回PBR直接加载，只进行统一坐标、等比恢复0.905m枪长。不代表游戏第一人称或射击/换弹已接入。</p><p>几何结构比ML07重建分支保留得更多；但20k低模仍可见软边、起伏与局部三角阴影。法线图存在且有实际画面作用，不能据此认定视觉已经通过。默认ML06保留，候选未发布。</p><p><a href="REPORT.md">结果/限制/任务账单</a> · <a href="audit.json">真实GLB检查</a> · <a href="normal-response.json">法线开关响应</a></p>''']
for mode in ['pbr','clay','normal-off']:
 for view in ['hero','side']:
  page.append(f'<h2>{mode} / {view}</h2><div class="pair">')
  for stage in ['01-high-pbr','02-low-pbr']:page.append(f'<figure>{stage}<a href="{stage}-{mode}-{view}.png"><img src="{stage}-{mode}-{view}.png" loading="lazy"></a></figure>')
  page.append('</div>')
page.append('<h2>原始PBR：机匣／弹夹／枪托</h2><p>每行依次底色、法线、金属/粗糙度。仅缩小原图，没有重绘或自动对比度增强；全部54张/阶段原图位于对应textures目录，以下列出所示18张原图链接。</p>')
for stage in ['01-high-pbr','02-low-pbr']:page.append(f'<a href="{stage}-maps.png"><img loading="lazy" src="{stage}-maps.png"></a>')
for m in map_records:page.append(f'<p>{m["stage"]} part{m["part"]} {m["channel"]} {m["size"]} <a href="{os.path.relpath(R/m["file"],D)}">原始文件</a></p>')
page.append('<p>ML06/ML07历史：<a href="../source-mesh-comparison/review.html">源网格与PBR对照</a>。本轮使用原始枪械，不包含ML06后加的工业kit、弹药屏和自定义主动发光接口。</p>')
(D/'review.html').write_text('\n'.join(page))
print('REPORT_READY',metrics)
