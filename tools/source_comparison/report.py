"""Contact sheets and browsable source maps. Pixel resizing/channel extraction only."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,os,html
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/source-mesh-comparison';P=D/'textures';P.mkdir(exist_ok=True)
font='/System/Library/Fonts/Supplemental/Arial.ttf'
f=lambda n:ImageFont.truetype(font,n)
rows=[]
sets=[('b2','B2 / ML15 - original 4K bake','art_source/environment/refine-v2/B2/03-bake/body','assets/environment/B2/body'),('gun-ml07-body','LS01 / ML07 body - original 4K bake','art_source/weapons/lc01/ls01-refine-v1/03-bake/body','assets/weapons/lc01/ls01_v1/body'),('gun-ml07-kit','LS01 / ML07 kit - original 4K bake','art_source/weapons/lc01/ls01-refine-v1/03-bake/kit','assets/weapons/lc01/ls01_v1/kit'),('gun-ml06-body','LS01 / ML06 body - current texture files','assets/weapons/lc01',None),('gun-ml06-kit','LS01 / ML06 kit - current texture files','assets/weapons/lc01/field_kit',None)]
for ident,title,src,packed in sets:
 records=[]
 for channel in ['BaseColor','NormalGL','Roughness','Metallic','AO','ORM']:
  path=R/src/(channel+'.png');derived=None
  if not path.exists():
   if channel=='ORM' and packed:path=R/packed/'ORM.png'
   else:path=R/src/'ORM.png';derived={'AO':0,'Roughness':1,'Metallic':2}[channel]
  raw=Image.open(path);original=raw.size
  if derived is not None:raw=raw.convert('RGB').getchannel(derived)
  raw=raw.convert('RGB');raw.thumbnail((1024,1024),Image.Resampling.LANCZOS);preview=P/f'{ident}-{channel}.png';raw.save(preview)
  records.append({'channel':channel,'source':str(path.relative_to(R)),'size':original,'extracted_orm_channel':derived,'preview':str(preview.relative_to(D))})
 board=Image.new('RGB',(1500,1130),(19,26,35));draw=ImageDraw.Draw(board);draw.text((20,14),title,font=f(26),fill='white');draw.text((20,49),'Existing pixels only - no relighting, contrast stretch or generated replacement',font=f(18),fill='#a9b9cc')
 for i,record in enumerate(records):
  x=(i%3)*500;y=85+(i//3)*520
  im=Image.open(D/record['preview']);im.thumbnail((480,460),Image.Resampling.LANCZOS);board.paste(im,(x+(500-im.width)//2,y+44))
  label=record['channel']+(' (ORM channel)' if record['extracted_orm_channel'] is not None else '')
  draw.text((x+12,y+6),label,font=f(24),fill='white')
 board.save(D/f'{ident}-textures.png');rows.append({'id':ident,'title':title,'maps':records})
# Comparison strips use identical full-frame geometry captures, no per-panel crop.
comparisons=[('b2-comparison',['b2-tripo','b2-high','b2-low'],'hero',['TRIPO / RAW DENSE','BLENDER / LOCAL HIGH','BLENDER / LOCAL LOW'],600,600),('gun-ml07-comparison',['gun-tripo','gun-ml07-high','gun-ml07-low'],'side',['TRIPO / RAW DENSE','ML07 / REBUILT HIGH + CONTEXT','ML07 / REBUILT LOW + CONTEXT'],700,450),('gun-ml06-comparison',['gun-tripo','gun-ml06-high','gun-ml06-low'],'side',['TRIPO / RAW DENSE','ML06 / REPAIRED HIGH','ML06 / LOW'],700,450)]
for name,stages,view,labels,w,h in comparisons:
 board=Image.new('RGB',(w*3,h+100),(19,26,35));draw=ImageDraw.Draw(board)
 for i,(stage,label) in enumerate(zip(stages,labels)):
  meta=json.loads((D/(stage+'.json')).read_text());im=Image.open(D/f'{stage}-{view}.png').convert('RGB').resize((w,h),Image.Resampling.LANCZOS);board.paste(im,(i*w,100));draw.text((i*w+12,12),label,font=f(21),fill='white');draw.text((i*w+12,44),f"{meta['triangles_including_context']:,} triangles shown",font=f(18),fill='#a9b9cc')
 draw.text((12,73),'BLENDER OFFLINE GEOMETRY REVIEW / NOT IN-GAME / NO PBR OR BAKED NORMALS',font=f(17),fill='#7ce0df');board.save(D/(name+'.png'))
(D/'textures.json').write_text(json.dumps(rows,indent=2))
# Static document with optional view switches; images and source links work without JS.
page=['''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>枪械与B2 · 原始网格、高低模和PBR</title><style>body{max-width:1800px;margin:24px auto;padding:0 20px;background:#111923;color:#eaf0f7;font:16px/1.65 system-ui}h1{font-size:28px}h2{margin-top:38px}a{color:#72d9e3}button{background:#263749;color:white;border:1px solid #557188;border-radius:4px;padding:8px 16px;cursor:pointer}figure{margin:0;min-width:0}img{width:100%;display:block}figcaption{padding:8px;background:#1e2c3a}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.textures{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:14px}.textures img{max-height:440px;object-fit:contain;background:#080c12}.note{padding:14px;background:#25323f;border-left:4px solid #62d5d9}small{color:#b4c4d6}@media(max-width:900px){.grid,.textures{grid-template-columns:1fr}}code{overflow-wrap:anywhere}</style>
<h1>枪械与 B2：原始网格 → 本地高模／低模 → PBR 原始贴图</h1>
<p class="note">灰模图全部由实际源文件在 Blender Workbench 离线渲染，非游戏实机、非概念图。统一灰色材质、灯光、相机；关闭贴图／烘焙法线和 cavity，观察几何自身。原始网格只做旋转、等比尺寸归一及平移，无镜像或按轴拉伸。图中面数是本次显示的网格，不包含游戏动态附件。</p>
<p>枪械必须分两条历史：当前默认ML06来自Tripo高模的保留/修整；ML07局部重建方案已回滚。B2当前是ML15本地重建。枪械图只比较主体，统一排除后加工业附件；ML07未重建部件在高/低两图中用相同保留低模作装配参照。PBR页另列主体和附件，避免把一张atlas当成整枪。</p>''']
def group(ident,title,stages,labels,note,view='hero'):
 page.append(f'<h2>{title}</h2><p>{note}</p><p>'+''.join(f'<button onclick="setView(\'{ident}\',\'{v}\')">{label}</button> ' for v,label in [('hero','三分之四'),('side','侧面'),('detail','局部近景')])+'</p><div class="grid" id="'+ident+'">')
 for stage,label in zip(stages,labels):
  m=json.loads((D/(stage+'.json')).read_text());page.append(f'<figure data-stage="{stage}"><a class="frame" href="{stage}-{view}.png"><img loading="lazy" src="{stage}-{view}.png" alt="{label}"></a><figcaption><b>{label}</b><br>{m["triangles_including_context"]:,} triangles · <a href="{stage}.json">源文件与相机记录</a></figcaption></figure>')
 page.append('</div>')
group('b2','B2 · Tripo 原始高密度候选与本地高／低模',['b2-tripo','b2-high','b2-low'],['Tripo 原始网格','Blender 本地高模','Blender 本地低模'],'原始模型按6m总高等比归一，中央管路面转至本地-Y正面。候选与本地尺寸比例、侧装配朝向不同，未镜像强行匹配。原始模型的圆形风扇安装位/灯柱保留；本地两图仅静态源主体，未加载游戏独立风扇与灯具，不能据此判定游戏漏了风扇。')
group('ml06','枪械 · 当前 ML06 的真实来源',['gun-tripo','gun-ml06-high','gun-ml06-low'],['Tripo 原始高密度主体','ML06 保留／修整的高模','ML06 低模主体'],'这一组不是“全部程序化重建”。ML06高模保留了Tripo形体并修整局部平面；低模沿用此前Tripo重拓扑及本地修复链路。原始高模保留原始微小残片，本地删除了该残片。','side')
group('ml07','枪械 · ML07 局部重建分支（已回滚）',['gun-tripo','gun-ml07-high','gun-ml07-low'],['Tripo 原始高密度主体','ML07 重建高模＋保留低模参照','ML07 重建低模＋保留低模参照'],'高模列不是全枪高模：只对重建组切换high，11个未重建部件以相同low显示。未显示工业附件、动态屏幕与导出阶段追加的前罩螺钉副本。可直接比较枪托镂空、机匣分层与弹夹结构；不得把灰模图当成完整游戏外观。','side')
page.append('<h2>PBR 文件究竟长什么样</h2><p>以下直接读取已有纹理，仅缩小展示，没有重新生成或增强。点击“原始文件”查看原尺寸。紫蓝色NormalGL和ORM是数据图，不能按普通颜色贴图理解；黑色空白通常是未占用UV区域。灰度图未自动拉伸对比度，原本接近黑/白的区域保留。ML15 B2和ML07提供4K烘焙母版；ORM为对应运行时打包图。ML06展示当前原文件，其中AO/粗糙度/金属度从ORM的R/G/B通道分别抽出。</p>')
for row in rows:
 page.append(f'<h3>{row["title"]}</h3><div class="textures">')
 for m in row['maps']:
  source=os.path.relpath(R/m['source'],D);channel=m['channel'];extra=' · 从ORM通道抽出' if m['extracted_orm_channel'] is not None else ''
  page.append(f'<figure><a href="{html.escape(source)}"><img loading="lazy" src="{m["preview"]}" alt="{row["id"]} {channel}"></a><figcaption>{channel}{extra} · 原尺寸 {m["size"][0]}×{m["size"][1]}<br><a href="{html.escape(source)}">原始文件</a> · <a href="{m["preview"]}">查看通道预览</a><br><small>{html.escape(m["source"])}</small></figcaption></figure>')
 page.append('</div>')
page.append('''<h2>ML07 的 imagegen 输入素材（不是完整 PBR）</h2><p>ML07曾使用以下oil/wear图案作为材质输入；B2的ML15材质没有使用这两张图。它们不是高模，也不是已对齐UV的完整PBR套图。</p><div class="textures">''')
for kind in ['oil','wear']:
 path=R/f'art_source/weapons/lc01/ls01-refine-v1/01-imagegen/{kind}.png';im=Image.open(path);im.thumbnail((1024,1024));preview=P/f'imagegen-{kind}.png';im.save(preview);source=os.path.relpath(path,D);page.append(f'<figure><a href="{source}"><img loading="lazy" src="textures/imagegen-{kind}.png"></a><figcaption>{kind} · imagegen来源图案</figcaption></figure>')
page.append('''</div><p><a href="README.md">范围与核查说明</a> · <a href="textures.json">贴图来源清单</a></p><script>function setView(id,view){document.querySelectorAll('#'+id+' figure').forEach(el=>{let src=el.dataset.stage+'-'+view+'.png';el.querySelector('img').src=src;el.querySelector('a.frame').href=src})}</script></html>''')
(D/'review.html').write_text('\n'.join(page))
print('COMPARISON_REPORT_READY',len(rows),'texture sets')
