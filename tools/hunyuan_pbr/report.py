"""Build inspectable ML19 report from original files and native Godot screenshots."""
from pathlib import Path
import json,re
import numpy as np
from PIL import Image,ImageDraw,ImageFont
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/hunyuan-tripo-pbr-v1'
font=lambda n:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',n)
a=json.loads((D/'audit.json').read_text());c=json.loads((D/'channels.json').read_text());native=json.loads((D/'native.json').read_text());extra=json.loads((D/'basecolor-native.json').read_text());assert native['failures']==extra['failures']==0
stages=[('hy-original','HUNYUAN / ORIGINAL COLOR'),('hy-tripo','HUNYUAN + TRIPO / PBR'),('ml06','ML06 / CURRENT BASELINE')]
# Identical crop and scale for every panel, retaining the complete gun in hero view.
for ident,suffix in [('comparison','neutral-pbr-hero'),('clay-comparison','neutral-clay-hero'),('color-comparison','neutral-basecolor-hero'),('grazing-comparison','grazing-pbr-hero')]:
 board=Image.new('RGB',(2520,520),(18,25,34));draw=ImageDraw.Draw(board)
 for i,(stage,label) in enumerate(stages):
  im=Image.open(D/f'{stage}-{suffix}.png').convert('RGB').crop((150,180,1250,760));im=im.resize((840,443),Image.Resampling.LANCZOS);board.paste(im,(i*840,77));draw.text((i*840+16,12),label,font=font(24),fill='white');draw.text((i*840+16,46),'NATIVE GODOT / '+suffix,font=font(17),fill='#a7dbe0')
 board.save(D/(ident+'.jpg'),quality=94)
# Four actual PBR channels. MR green=roughness, blue=metallic, red is not bound as AO.
mat=c[1]['materials'][0];maps=[]
for name,index,channel in [('BaseColor',mat['pbrMetallicRoughness']['baseColorTexture']['index'],None),('NormalGL',mat['normalTexture']['index'],None),('Roughness',mat['pbrMetallicRoughness']['metallicRoughnessTexture']['index'],1),('Metallic',mat['pbrMetallicRoughness']['metallicRoughnessTexture']['index'],2)]:
 idx=c[1]['textures'][index]['source'];meta=next(i for i in c[1]['images'] if i['index']==idx);img=Image.open(D/meta['path']).convert('RGB')
 if channel is not None:img=img.getchannel(channel).convert('RGB')
 img.thumbnail((1200,1200),Image.Resampling.LANCZOS);namefile=name+'-preview.png';img.save(D/namefile);maps.append({'name':name,'source':meta['path'],'preview':namefile,'channel':channel,'size':meta['size']})
board=Image.new('RGB',(2000,540),(18,25,34));draw=ImageDraw.Draw(board)
for i,m in enumerate(maps):
 im=Image.open(D/m['preview']).resize((480,480));board.paste(im,(i*500+10,55));draw.text((i*500+10,13),m['name']+' / 4K',font=font(24),fill='white')
board.save(D/'pbr-maps.jpg',quality=94)
responses=[]
for stage,_ in stages:
 x=np.array(Image.open(D/f'{stage}-neutral-pbr-hero.png').convert('RGB'))[100:].astype(float);y=np.array(Image.open(D/f'{stage}-neutral-normal-off-hero.png').convert('RGB'))[100:].astype(float);delta=np.abs(x-y).mean(2);responses.append({'stage':stage,'mean_abs_rgb_0_255':float(delta.mean()),'changed_pixels_over_5':int((delta>5).sum())})
x=np.array(Image.open(D/'hy-original-neutral-clay-hero.png').convert('RGB'))[100:].astype(float);y=np.array(Image.open(D/'hy-tripo-neutral-clay-hero.png').convert('RGB'))[100:].astype(float);diff=np.abs(x-y).mean(2)
verification={'native_record_count':len(native['checks'])+len(extra['checks']),'native_failures':0,'native_screenshots':36,'geometry_uv_gate_passed':a['geometry_uv_gate_passed'],'vertex_normals_byte_identical':False,'normal_toggle':responses,'clay_image_delta':{'mean_abs_rgb_0_255':float(diff.mean()),'pixels_over_5':int((diff>5).sum()),'note':'Includes renderer shading/zero-normal fallback, tiny coordinate differences; use face audit for geometric equivalence, not pixel equality.'},'visual_status':'open; material/color differences documented; not promoted','paid_tasks':1,'actual_credits':20,'rerolls':0,'default_changed':False}
assert responses[0]['changed_pixels_over_5']==0 and responses[1]['changed_pixels_over_5']>100
(D/'verification.json').write_text(json.dumps(verification,indent=2));(D/'selected-maps.json').write_text(json.dumps(maps,indent=2))
style='body{max-width:1800px;margin:24px auto;padding:0 20px;background:#111b25;color:#edf2f6;font:16px/1.7 system-ui}a{color:#74dbe1}img{width:100%;display:block}.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px}.maps{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px}figure{margin:0;background:#1b2937}figcaption{padding:9px}button{background:#273a4d;color:white;border:1px solid #526c85;padding:8px 15px;cursor:pointer}.note{padding:18px;background:#263a49}h2{margin-top:34px}code{overflow-wrap:anywhere}table{border-collapse:collapse}td,th{padding:8px;border:1px solid #506071}@media(max-width:900px){.grid,.maps{grid-template-columns:1fr}}'
page=[f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ML19 · 混元低模 × Tripo PBR</title><style>{style}</style><h1>ML19 · 混元低模 × Tripo PBR 同机位对照</h1>', '<p class="note"><b>生成与检查完成，实际20积分。</b>20,901个三角面全部逐角匹配，UV完全一致；未减面或重建。获得4K底色、法线、金属度/粗糙度。<b>视觉差距仍开放：</b>部分原白色区改成深色，反射偏亮滑，低模原有波浪高光更明显。不替换ML06默认。</p>', '<p><a href="REPORT.md">完整报告/费用/限制</a> · <a href="audit.json">逐角几何与UV审计</a> · <a href="channels.json">实际贴图绑定</a> · <a href="verification.json">验证汇总</a> · <a href="../../../docs/logs/ML19-混元低模Tripo材质试验.md">ML19日志</a></p>', '<p>以下为Godot 4.7.2 Compatibility原生独立材料场景，非概念图、非Blender渲染。统一1400×900、机位、环境和曝光；按0.905m枪长等比归一。比较主体，排除后加工业kit、动态屏幕和红点；Emission/Bloom关闭。不是完整游戏接入或性能测试。</p>', '<a href="comparison.jpg"><img src="comparison.jpg" alt="混元底色、Tripo PBR、ML06原生对比"></a>', '<h2>几何/UV与法线检查</h2><table><tr><th>项目</th><th>实际结果</th></tr><tr><td>三角面</td><td>20,901 → 20,901；全部保持角点对应与绕序</td></tr><tr><td>UV</td><td>每个匹配角点差值0</td></tr><tr><td>位置</td><td>服务进行了居中/等比缩放；逆变换后最大误差4.88e-8源单位</td></tr><tr><td>顶点</td><td>17,971 → 17,981；额外拆点，没有新增面或改变轮廓</td></tr><tr><td>顶点法线</td><td>并非完全保留；18个零法线角点变为非零，另6个有效角点方向变化超过0.1°，最大26.17°；其余变化很小</td></tr></table><p>几何与UV保持通过，不代表法线逐字节相同，也不代表材质美术验收通过。原文件未修改；没有把返回网格进行本地重建或再次减面。</p>']
labels={'hy-original':'混元原底色版 · 8K BaseColor，金属度0/粗糙度1','hy-tripo':'混元＋Tripo · 返回4K PBR，原样导入','ml06':'当前ML06主体 · 现有材质'}
def group(ident,title,suffix,views):
 page.append(f'<h2>{title}</h2><p>'+''.join(f'<button onclick="change(\'{ident}\',\'{v}\')">{label}</button> ' for v,label in views)+f'</p><div class="grid" id="{ident}">')
 for stage,_ in stages:
  prefix=f'{stage}-{suffix}';file=f'{prefix}-{views[0][0]}.png';page.append(f'<figure data-prefix="{prefix}"><a href="{file}"><img src="{file}" loading="lazy"></a><figcaption>{labels[stage]}</figcaption></figure>')
 page.append('</div>')
group('neutral','中性光 · 完整材质','neutral-pbr',[('hero','三分之四'),('side','侧面'),('reverse','反侧'),('detail','弹夹近景')])
group('grazing','掠射光 · 金属反射与表面起伏','grazing-pbr',[('hero','全枪'),('detail','弹夹近景')])
group('clay','同一灰材质 · 无贴图法线','neutral-clay',[('hero','三分之四'),('side','侧面')])
group('color','仅底色 · 排除反射干扰','neutral-basecolor',[('hero','三分之四'),('side','侧面')])
page.append('<p>仅底色模式可确认：枪托上壳和部分机匣白色区被服务重绘为深色；这不是仅由环境反射导致。字标也未忠实保留。原图的白/橙/深色总体调色板仍在，但分区不能算完全保持。</p>')
group('normaloff','关闭贴图法线 · 同一PBR响应','neutral-normal-off',[('hero','三分之四')])
page.append('<p>关闭法线图后仍有大平面波浪式高光，说明问题并非只由新法线贴图造成；低模/顶点法线与较强反射共同影响观感。材质通道齐全，不等于凹坑、油膜和涂漆金属已达到概念效果。</p><h2>Tripo原始4K贴图通道</h2><p>直接提取服务GLB图像；粗糙度取MR绿色、金属度取蓝色，仅缩小显示，未拉伸对比度或重绘。MR红通道全白且未绑定AO，不将其宣称为AO烘焙；没有独立Emission。</p><div class="maps">')
for m in maps:page.append(f'<figure><a href="{m["source"]}"><img src="{m["preview"]}" loading="lazy"></a><figcaption>{m["name"]} · {m["size"][0]}² · <a href="{m["source"]}">原始图</a></figcaption></figure>')
page.append('</div><h2>交付与边界</h2><p>原始生成GLB：<code>art_source/weapons/lc01/hunyuan-tripo-pbr-v1/01-tripo/model.glb</code>。独立验证入口：<code>tools/hunyuan_pbr/capture.gd</code>；保形审计和报告脚本同目录。全部源与截图归档，默认武器、环境和游戏代码未变。当前结果是一次已完成的材质试验，用户美术验收待定。</p><script>function change(id,v){document.querySelectorAll("#"+id+" figure").forEach(f=>{let p=f.dataset.prefix+"-"+v+".png";f.querySelector("img").src=p;f.querySelector("a").href=p})}</script></html>')
(D/'review.html').write_text('\n'.join(page))
for ref in re.findall(r'(?:href|src)="([^"]+)"','\n'.join(page)):
 if not ref.startswith(('http','#')):assert (D/ref).exists(),ref
for suffix,views in [('neutral-pbr',['hero','side','reverse','detail']),('grazing-pbr',['hero','detail']),('neutral-clay',['hero','side']),('neutral-basecolor',['hero','side']),('neutral-normal-off',['hero'])]:
 for stage,_ in stages:
  for v in views:assert (D/f'{stage}-{suffix}-{v}.png').exists()
print(json.dumps(verification,indent=2))
