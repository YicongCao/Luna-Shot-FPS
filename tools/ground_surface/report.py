from pathlib import Path
import json
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/ground-v1'
read=lambda p:json.loads(p.read_text())
before=read(D/'baseline-performance/performance.json');after=read(D/'performance/performance.json');assert before['route']==after['route'] and min(before['seconds'],after['seconds'])>=59.9
increase=after['p95_ms']/before['p95_ms']-1
perf={'before':before,'after':after,'p95_increase':increase,'passed':increase<=.10};(D/'performance-comparison.json').write_text(json.dumps(perf,indent=2));assert perf['passed'],perf
for file in ['sample/checks.json','field/checks.json','masks.json','map/native.json','map/headless.json','rifle/rifle-native.json','rifle/scene-switch.json']:
 d=read(D/file);assert d.get('failures',0)==0,file
md=f'''# ML16 地面样板与全场推广

Godot4.7.2 / macOS Apple M5 / Compatibility。技术与实施视觉复查通过；用户实机美术验收待确认。

8×8m可玩样板先独立验证并提交631d3fe，再推广64×66m训练场。左侧道路、右上现有A、右下检修盖/月壤过渡；B切换旧版，F2总览。全场复用40组A座基、8个检修盖，铺装遮罩由当前布局生成，保护中央十字、外围/支路、出生区和设备占地。没有更改布局、主题模型、枪械、靶或碰撞。

三种材质各为2K BaseColor/ORM/NormalGL，启用GPU压缩、mipmap及各向异性过滤；16位高度源保留。程序高度场生成法线，**没有执行Tripo或高模到低模投射烘焙**。几何承载盖板/边框/提手/螺钉与座基，微凹坑和浅接缝由法线表达。路面碰撞仍是原始平面，小装饰高差≤22mm。没有一张覆盖4224m²的独占大UV贴图，也没有Position EXR。

铺装与月壤使用与WorldEnvironment同步的统一环境漫反射，避免大地面跨反射探针边界时出现硬色带；太阳/局部灯直接照明和镜面反射保留。环境与其他资产的探针设置不变。样板自己的单探针覆盖8×8区域，前后相机/曝光相同。正常截图关闭Bloom，避免发光干扰地面判断。

验证：样板真实胶囊沿道路往返、盖板/月壤跨越；20种子遮罩重复生成一致，4m路宽采样保持铺装；关卡原生路线、桥下/坡道、靶/射击/换弹、F2/F3、重置/暂停/超宽窗口回归通过。normal关闭对照有实际像素差异。生成器先改再导出，GROUND_BASELINE=1保留ML15地面对照；launch-ground-sample.command打开独立样板。

性能：同机同近设施路线、1600×1000、预热3秒后各60秒，默认VSync。P95 {before['p95_ms']:.3f}→{after['p95_ms']:.3f}ms（{increase*100:+.2f}%），通过+10%门槛。纹理内存 {before['texture_bytes']/2**20:.1f}→{after['texture_bytes']/2**20:.1f}MiB。此结果限本机与该路线；视频/截图不充当帧时间测量。

限制：微接缝没有真实位移/视差，接近地面的极低视角仍会看到平面；没有真实挖槽或可打开盖板；磨损较克制，没有加入满地污渍/车辆履带。小碎石为无碰撞地表细节，样板保留；全场采用材质颗粒，不增加大量石块实例。用户视觉偏好仍可据对照调整。

本轮付费调用0。可复现源：tools/ground_surface/build.py；运行时scripts/ground_surface.gd与assets/environment/ground_v1。失败初稿保留first-pass。
'''
(D/'REPORT.md').write_text(md)
page=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>ML16 Ground</title><style>body{background:#16202a;color:#eee;font:16px/1.6 system-ui;margin:30px}section{display:grid;grid-template-columns:1fr 1fr;gap:14px}figure{margin:0}img{width:100%}a{color:#5df}@media(max-width:800px){section{grid-template-columns:1fr}}</style><h1>ML16 · 地面样板与全场推广</h1><p>全部为原生Godot，同机位/曝光。技术与实施视觉通过，用户实机美术验收待定。<a href="REPORT.md">验证与限制</a></p>']
for group,views in [('sample',['first-person','overview','cover','soil','seat']),('field',['spawn','overview','road','equipment','underbridge'])]:
 page.append(f'<h2>{"8×8 m 样板" if group=="sample" else "64×66 m 训练场"}</h2><section>')
 for view in views:
  for phase in ['before','after']:page.append(f'<figure>{"ML15旧地面" if phase=="before" else "ML16"} / {view}<img loading="lazy" src="{group}/{phase}-{view}.png"></figure>')
 page.append('</section>')
page.append('<p>通过 launch-ground-sample.command 启动可玩样板，B 切换前后。样板已提交631d3fe；全场提交见ML16日志。</p>');(D/'review.html').write_text('\n'.join(page));print('GROUND_REPORT',round(increase*100,2),'percent')
