"""Build a static local review from actual renders and embedded texture pixels."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,html,re,hashlib,struct
import numpy as np
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/hunyuan-weapon-v1'
font=lambda n:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',n)
records=json.loads((D/'channels.json').read_text());audit=json.loads((D/'audit.json').read_text());native=json.loads((D/'native.json').read_text());assert native['failures']==0
# Source copies are exact, including the original FBX.
source_names={'high.glb':'高模.glb','low.glb':'低模.glb','uv.fbx':'uv展开.fbx','pbr.glb':'pbr材质.glb'}
provenance=[]
for dest,original in source_names.items():
 p=R/'art_source/weapons/lc01/hunyuan-v1'/dest;external=Path('/Users/cong/Downloads/luna-shot-gun')/original
 digest=hashlib.sha256(p.read_bytes()).hexdigest()
 if external.exists():assert digest==hashlib.sha256(external.read_bytes()).hexdigest()
 provenance.append({'archive':str(p.relative_to(R)),'original_path':str(external),'sha256':digest})
(R/'art_source/weapons/lc01/hunyuan-v1/source.json').write_text(json.dumps({'files':provenance,'provenance':'User supplied as Hunyuan3D output; generation version, input views, options, cost and job IDs not supplied. No service generation performed in this review.','runtime_replaced':False},indent=2))
# Consistent full-frame boards. No per-model crops, contrast edits or image synthesis.
def board(name,items,w=700,h=450):
 canvas=Image.new('RGB',(w*2,(h+55)*((len(items)+1)//2)),(18,25,34));draw=ImageDraw.Draw(canvas)
 for i,(p,title) in enumerate(items):
  x=(i%2)*w;y=(i//2)*(h+55);im=Image.open(D/p).convert('RGB').resize((w,h),Image.Resampling.LANCZOS);canvas.paste(im,(x,y+55));draw.text((x+12,y+14),title,font=font(23),fill='white')
 canvas.save(D/name)
labels=[('hy-pbr','HUNYUAN / 20,901 tris'),('tripo-low','TRIPO ML17 / 20,303 tris'),('ml06','ML06 / 19,658 tris'),('ml07','ML07 / 22,272 tris (body)')]
for mode in ['pbr','clay']:
 board(f'comparison-{mode}.jpg',[(f'{stage}-native-{mode}-hero.png',title) for stage,title in labels])
board('comparison-high.jpg',[(stage+'-hero.png',title) for stage,title in [('hy-high','HUNYUAN HIGH / 1,992,214'),('gun-tripo','TRIPO ORIGINAL / 1,934,304'),('gun-ml06-high','ML06 HIGH / 1,934,277'),('gun-ml07-high','ML07 HIGH + LOW CONTEXT / 42,520')]])
# Actual color texture, downscaled for preview; original remains byte-exact.
hy=next(r for r in records if r['id']=='hy-pbr');im=Image.open(D/hy['images'][0]['file']);im.thumbnail((1600,1600),Image.Resampling.LANCZOS);im.save(D/'hy-basecolor-preview.jpg')
# UV wireframe from indexed triangles of the delivered PBR GLB, no UV changes.
p=R/hy['source'];raw=p.read_bytes();n=struct.unpack_from('<I',raw,12)[0];g=json.loads(raw[20:20+n]);blob=raw[28+n:]
def acc(i):
 a=g['accessors'][i];v=g['bufferViews'][a['bufferView']];dt={5126:'<f4',5125:'<u4',5123:'<u2',5121:'u1'}[a['componentType']];cols={'SCALAR':1,'VEC2':2,'VEC3':3}[a['type']];item=np.dtype(dt).itemsize
 return np.ndarray((a['count'],cols),dtype=dt,buffer=blob,offset=v.get('byteOffset',0)+a.get('byteOffset',0),strides=(v.get('byteStride',item*cols),item)).copy()
prim=g['meshes'][0]['primitives'][0];uv=acc(prim['attributes']['TEXCOORD_0']);indices=acc(prim['indices']).reshape(-1,3)
canvas=Image.new('RGB',(1600,1600),(12,18,25));draw=ImageDraw.Draw(canvas);area=0;collapsed=0
for ids in indices:
 t=uv[ids];a=abs(float((t[1,0]-t[0,0])*(t[2,1]-t[0,1])-(t[1,1]-t[0,1])*(t[2,0]-t[0,0])))/2;area+=a;collapsed+=a<1e-12
 pts=[(float(u)*1599,(1-float(v))*1599) for u,v in t];draw.line(pts+[pts[0]],fill=(130,190,205),width=1)
canvas.save(D/'hy-uv-wire.png')
checks={'native_checks':len(native['checks']),'native_failures':native['failures'],'native_screenshots':len(list(D.glob('*-native-*.png'))),'uv_triangle_area_sum_not_occupancy':area,'uv_collapsed_triangles_epsilon_1e12':collapsed,'uv_overlap_tested':False,'original_files_unchanged':True}
# Compare texture normal toggle below the text overlay; exact equality is expected for HY.
responses=[]
for stage,_ in labels:
 a=np.asarray(Image.open(D/f'{stage}-native-pbr-hero.png').convert('RGB')).astype(float)[100:];b=np.asarray(Image.open(D/f'{stage}-native-normal-off-hero.png').convert('RGB')).astype(float)[100:];delta=np.abs(a-b).mean(2)
 responses.append({'stage':stage,'pixels_mean_rgb_change_gt5':int((delta>5).sum()),'mean_abs_channel_difference_0_255':float(delta.mean())})
checks['normal_toggle']=responses;(D/'verification.json').write_text(json.dumps(checks,indent=2))
style='body{max-width:1800px;margin:25px auto;padding:0 22px;background:#101923;color:#edf2f7;font:16px/1.7 system-ui}a{color:#74dbe1}img{width:100%;display:block}.grid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:14px}figure{margin:0;background:#192734}figcaption{padding:8px}table{border-collapse:collapse;width:100%}td,th{padding:9px;border:1px solid #455368;text-align:left}button{padding:8px 15px;background:#25394b;color:white;border:1px solid #52677a;cursor:pointer}.note{background:#213545;padding:18px}h2{margin-top:35px}@media(max-width:800px){.grid{grid-template-columns:1fr}}'
page=[f'<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ML18 · 混元 / Tripo / 本地重建枪械评估</title><style>{style}</style><h1>ML18 · 混元、Tripo 与本地重建枪械对照</h1>', '<p class="note"><b>结论：</b>下一轮几何候选优先混元；完整生成材质与可分件程度目前 Tripo 更齐；已接入游戏继续使用 ML06。ML07 整体重建路线不建议继续推广。混元这批“PBR”实际只有8K底色，尚不能作为完整PBR成品替换默认。</p>', '<p>本页是实际文件审计及 Godot 4.7.2 Compatibility 原生独立材料场景，不是概念图；高模灰色对照另由 Blender Workbench 离线渲染并明确标识。没有修改默认枪械、没有新增付费任务。结论只针对这批文件，未知混元任务版本、输入视图与参数，不能当作两家服务整体排名。</p><p><a href="REPORT.md">完整评估与后续建议</a> · <a href="channels.json">实际材质绑定</a> · <a href="audit.json">几何/UV检查</a> · <a href="verification.json">验证结果</a></p>', '<h2>文件究竟包含什么</h2><table><tr><th>文件</th><th>三角数</th><th>材质/UV</th><th>文件体积</th></tr>']
for title,tri,desc,size in [('混元高模',1992214,'单网格；无UV、无贴图、无存储顶点法线',35856876),('混元低模',20945,'单网格；无UV/贴图/存储顶点法线；Blender导入后20,925',380700),('混元UV FBX',20901,'含UV；与最终GLB位置集合一致到1e-6',1529996),('混元PBR GLB',20901,'1材质、1张8192²底色；metallic=0 / roughness=1',9931456),('Tripo ML17高模',1934290,'18网格/材质，54张图：底色+法线+MR',67156068),('Tripo ML17低模',20303,'18网格/材质，54张图：底色+法线+MR',6963768)]:page.append(f'<tr><td>{title}</td><td>{tri:,}</td><td>{desc}</td><td>{size/1e6:.2f} MB</td></tr>')
page.append('</table><p>MB按十进制。文件大小同时受到贴图、压缩、顶点拆分影响，不代表几何质量。混元UV边界顶点拆分会增加索引边界数，不能把这些数直接解释成破洞。未进行完整UV重叠/自交检测。</p>')
def gallery(ident,title,items,kind='native-pbr',view='hero'):
 page.append(f'<h2>{title}</h2><p>'+''.join(f'<button onclick="change(\'{ident}\',\'{v}\')">{label}</button> ' for v,label in [('hero','三分之四'),('side','侧面'),('reverse','反侧'),('detail','弹夹近景')] if kind.startswith('native'))+f'</p><div class="grid" id="{ident}">')
 for stage,label in items:
  name=f'{stage}-{kind}-{view}.png' if kind else f'{stage}-{view}.png'
  page.append(f'<figure data-prefix="{stage}-{kind}" ><a href="{name}"><img loading="lazy" src="{name}" alt="{html.escape(label)}"></a><figcaption>{label}</figcaption></figure>')
 page.append('</div>')
cnlabels=[('hy-pbr','混元最终网格 · 20,901三角 · 只有底色'),('tripo-low','Tripo全链路低模 · 20,303三角 · 原服务PBR'),('ml06','ML06主体 · 19,658三角 · 原运行时材质'),('ml07','ML07主体/保留件 · 22,272三角 · 原绑定材质')]
page.append('<h2>公平比较边界</h2><p>所有原生图统一1400×900、正交机位、灯光、环境、曝光、0.905m枪长，按整体包围盒居中；只刚性旋转和等比缩放，不镜像或修改模型。只比较主体，排除后加工的铜排/散热片/弹药屏/红点/局部补光；Emission和Bloom均关闭。ML07主体保留导出阶段追加螺钉，因此22,272与源配对低模20,032不同，不是计数错误。原生灰模保留各文件的顶点法线，没有烘焙法线，仍同时反映几何和顶点法线质量。</p>')
gallery('pbr','Godot原生 · 原文件材质',cnlabels)
gallery('clay','Godot原生 · 同一灰材质 / 无贴图法线',cnlabels,'native-clay')
page.append('<p>混元近景仍有大平面波浪阴影、凹槽边缘过渡变软；Tripo低模机匣/弹夹的三角起伏更明显。不能因混元彩色图较清爽而宣称精确硬表面已经通过。</p>')
gallery('high','Blender离线 · 高模来源比较',[('hy-high','混元高模 · 1,992,214三角'),('gun-tripo','原Tripo高模 · 1,934,304三角'),('gun-ml06-high','ML06高模 · 1,934,277三角；保留/修整'),('gun-ml07-high','ML07重建高模＋保留低模参照 · 42,520三角')],kind='')
page.append('<p>高模图不是实机。ML06并非程序化重建全枪：高模保留Tripo形体，低模也包含历史Tripo重拓扑。本地只修整/烘焙/材质处理。ML07才是多主体局部重建；高模列11个未重建件仍用相同低模作装配参照。混元高模没有存储法线，导入器生成；不同法线策略可能影响高光，不能只看软硬阴影判定几何。</p>')
page.append('<h2>混元自己的高 → 低 → UV／材质网格</h2><div class="grid">')
for stage,title in [('hy-high','高模'),('hy-low','裸低模'),('hy-uv','UV FBX'),('hy-pbr','最终材质GLB的网格')]:page.append(f'<figure><a href="{stage}-side.png"><img loading="lazy" src="{stage}-side.png"></a><figcaption>Blender离线 / {title}；同相机，无材质</figcaption></figure>')
page.append('</div><h2>混元原始底色与UV</h2><p>底色中的亮边和暗缝在图像本身可见，存在固定明暗；它们不会随灯光像真实粗糙度/金属反射那样变化。未将它自动猜成高度或粗糙度。</p><div class="grid"><figure><a href="textures/hy-pbr/0.png"><img src="hy-basecolor-preview.jpg"><figcaption>实际8192²底色 · 点击原图</figcaption></a></figure><figure><a href="hy-uv-wire.png"><img src="hy-uv-wire.png"></a><figcaption>最终GLB的UV三角线框；未做完整重叠验收</figcaption></figure></div>')
page.append('<p><a href="../tripo-weapon-v3/review.html">Tripo原始PBR三通道与高低模</a> · <a href="../source-mesh-comparison/review.html">ML06/ML07完整源网格及PBR母版</a></p><h2>建议下一步</h2><p>保留混元高模/低模造型，先核实是否漏导出Normal、Roughness、Metallic；选弹夹和机匣小范围做高→低法线、粗糙度/金属度与UV接缝验证。缺失时再补齐对应材质/烘焙，不整枪程序化重建、不套用Tripo旧UV贴图。混元是单网格，后续需要分离弹夹、枪身、能量环等动画/发光区域，再接回ML06已有附件和接口。先证明一个局部和正常第一人称都升级，再决定默认替换。</p><script>function change(id,v){document.querySelectorAll("#"+id+" figure").forEach(f=>{let p=f.dataset.prefix+"-"+v+".png";f.querySelector("img").src=p;f.querySelector("a").href=p})}</script></html>')
(D/'review.html').write_text('\n'.join(page).replace('textures/hy-pbr/0.png',hy['images'][0]['file']))
# Verify all static file links and previews exist; source channel records are embedded bytes.
for ref in re.findall(r'(?:src|href)="([^"]+)"',(D/'review.html').read_text()):
 if not ref.startswith(('http','#')):assert (D/ref).exists(),ref
print('REVIEW_READY',checks)
