"""Build ML15 delivery index from completed evidence; refuse a failed check."""
import json, html
from pathlib import Path
R=Path(__file__).resolve().parents[2]
D=R/'docs/validation/environment-refine-v2';F=D/'final'
def read(p): return json.loads(p.read_text())
evidence=['map/headless.json','map/native.json','rifle/rifle-headless.json','rifle/rifle-native.json','rifle/scene-switch.json','lighting-v1/native.json','b2-cooling-fans/native.json','knockdown-targets/macOS.json','markings/checks.json','lamps.json']
checks=[]
for name in evidence:
 d=read(F/name); assert d.get('failures',0)==0,name
 assert all(c.get('passed',True) for c in d.get('checks',[])),name
 checks.append({'file':name,'checks':len(d.get('checks',[])),'passed':True})
perf=read(F/'performance-comparison.json');assert perf['passed']
assert perf['after']['blue_spill_frames']>0 and perf['after']['spot_spill_frames']>0
retained=read(F/'retained-assets.json');assert retained['passed']
usage=read(R/'art_source/environment/refine-v2/usage.json');assert usage['ledger_verified'] and usage['actual_credits']<=usage['budget']
rows=[]
for asset,budget in [('B1',20000),('B2',20000),('C',12000),('D',16000),('E',24000)]:
 m=read(R/f'art_source/environment/refine-v2/{asset}/manifest.json');audit=read(D/asset/'audit.json');assert audit['passed'] and m['triangles']<=budget
 phase={'B1':'lifting-eyes','B2':'final-bindings'}.get(asset,'candidate')
 assert read(D/asset/phase/'checks.json')['failures']==0
 rows.append({'asset':asset,'low_triangles':m['triangles'],'high_triangles':m['high_triangles'],'bake_groups':len(m['pairs']),'budget':budget,'phase':phase})
report={'technical':'passed','implementation_visual_review':'passed with documented limits','user_runtime_acceptance':'pending','usage':usage,'modules':rows,'checks':checks,'performance':perf,'protected_assets':retained['passed']}
(F/'delivery.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
md=['# ML15 最终交付与验证','', 'Godot 4.7.2 Compatibility / macOS Apple M5。技术检查通过；实施视觉复查通过并保留以下限制；用户实机美术验收待确认。概念方向认可不等于本次实机验收。','', 'B1 → B2 → C → D → E 均完成 Tripo 参考、精确高模、受控低模/UV、独立 cage、4K 分组烘焙、2K 运行时分层 PBR，已进入默认关卡。未改 A、ML06 枪械、ML14 风扇源代码或布局。','', '| 模块 | 低模三角/预算 | 高模三角 | 配对组数 |','|---|---:|---:|---:|']
for row in rows:md.append(f"| {row['asset']} | {row['low_triangles']:,}/{row['budget']:,} | {row['high_triangles']:,} | {row['bake_groups']} |")
md += ['', 'B2 原有风扇附件另计 15,588 三角/塔，6 塔共 18 个旋转叶轮；灯罩、底座和动态警灯独立共享。静态主体预算没有隐瞒附件成本。', '', '## 灯光和地面', '', '48 盏四角红灯每 2 秒闪一次、单塔同步、塔间固定错相；32 段内嵌蓝灯常亮；橙灯每秒旋转一圈并短闪，实际 Spot 随旋转亮区扫亮塔顶。灯罩、真实局部照明、Bloom 分开验证。局部灯池有 8 个槽，最多同时开启 2 个 Omni 和 1 个 Spot；远处灯罩仍可见。暂停冻结动态相位；F7 控制 Bloom，F8 光晕，F9 实际补光。', '', '新增 48 段道路边缘黄漆，射击线同材质。非金属/不发光，独立粗糙度和小尺度磨损；同镜头关闭 specular 的对照证明高光来自真实反射响应，关闭照明后采样点为黑色。保留反射探针，不制造镜面地板。132 根原地面网格线以同几何/材质批处理降低绘制开销。','', '## 验证与性能', '']
for row in checks:md.append(f"- [{row['file']}]({row['file']})：通过（{row['checks']} 条检查）。")
b,a=perf['before'],perf['after']
md += ['',f"近设施同路线：预热后各采集 60 秒、1600×1000、默认 VSync。旧版 P95 {b['p95_ms']:.3f} ms，新版 {a['p95_ms']:.3f} ms，变化 {perf['p95_increase']*100:+.2f}%，低于 +10% 门槛。蓝色补光激活 {a['blue_spill_frames']} 帧，橙色 Spot 激活 {a['spot_spill_frames']} 帧；这是相机压力路线，真实胶囊通行另由 map 回归验证。",'',f"末帧绘制对象 {b['objects_last_frame']}→{a['objects_last_frame']}，三角/图元计数 {b['primitives_last_frame']:,}→{a['primitives_last_frame']:,}；纹理内存 {b['texture_bytes']/2**20:.1f}→{a['texture_bytes']/2**20:.1f} MiB。这些是同镜头渲染计数，包含多遍绘制，不等于资产文件三角预算。静态主体各 1 个导出 surface/atlas；灯具/风扇材质另计。", '', '## 来源、费用与限制','', '本轮 Tripo 5 次，共 300/400 积分，0 重抽；usage.json 已与工具账单核对。概念阶段 imagegen 6 次，工具未返回货币金额；本实施阶段没有新增 imagegen 调用。历史 690 积分独立保留。', '', '源文件：`art_source/environment/refine-v2/{B1,B2,C,D,E}`；每件 `02-geometry/paired.blend` 保存高模、三角化低模和 cage，`03-bake/body` 保存分层材质源、辅助图及烘焙契约。运行时 `assets/environment/{B1,B2,C,D,E}`；入口 `tools/environment_refine/run.py`。', '', '原始参考 GLB（普通路径，供下载/建模使用）：']
for row in rows:md.append(f"- `{R}/art_source/environment/refine-v2/{row['asset']}/01-tripo/model.glb`")
md += ['', '保留的限制：地面主体、围界和靶仍属原型基础设施；本轮未增加内部空间或新的建筑类别。B2 外侧鳍片仍有较大平面，远距离螺钉/微划痕不能逐个分辨；没有宣称像素级复刻概念。旋转警灯只有结构受光与镜头效果，没有真空中的空气光锥。低角度月球日照形成深阴影，最终美术偏好仍待用户实机确认。', '', '性能、截图和视频均来自原生 Godot；MovieMaker 固定 60fps 视频只证明动画，不用于帧时间验收。静态 HTML 对照页已检查链接，未宣称浏览器交互验收。失败尝试保留在各模块诊断目录；后续不要把技术通过改写为用户美术接受。']
(F/'REPORT.md').write_text('\n'.join(md)+'\n')
page=['<!doctype html><html lang="zh"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>ML15 原生交付</title><style>body{max-width:1500px;margin:32px auto;padding:0 20px;background:#111820;color:#e5edf2;font:16px/1.6 system-ui}a{color:#64dfe7}h1,h2{color:#fff}section{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:18px}figure{margin:0;background:#1c2631;padding:12px}img,video{width:100%;height:auto}small{color:#b8c3ca}@media(max-width:700px){section{grid-template-columns:1fr}}</style><h1>ML15 · 月球能源设施</h1><p>以下均为原生 Godot，概念非实机图片在独立页面。技术通过 / 实施视觉复查通过 / 用户实机验收待定。</p><p><a href="final/REPORT.md">完整验证、费用与限制</a> · <a href="../../art/environment-concept-v3/review.html">已认可的概念方向</a></p><section>']
for n,t in [('02-overview','默认关卡总览'),('01-spawn','出生第一人称'),('west_elevated-deck','高架通行'),('underbridge_-18','桥下通行')]:page.append(f'<figure><img src="final/{"release" if n in ["02-overview","01-spawn"] else "map"}/{n}.png"><figcaption>{t}</figcaption></figure>')
page.append('</section><h2>同相机旧版 / ML15</h2>')
for row in rows:
 asset=row['asset'];phase=row['phase'];page.append(f'<h3>{asset} · <a href="{asset}/review.html">四侧/灰模/灯光检查</a></h3><section>')
 for state,label in [('baseline','旧版'),(phase,'ML15')]:page.append(f'<figure><img loading="lazy" src="{asset}/{state}/pbr-front.png"><figcaption>{label}</figcaption></figure>')
 page.append('</section>')
page.append('<h2>主动灯光与反光漆</h2><section>')
for asset,file,caption in [('B1','red-cycle.mp4','红灯：两秒周期'),('D','blue-closeup.mp4','蓝灯：连续坡面与侧梁'),('E','beacon-cycle.mp4','橙灯：旋转亮区、脉冲与扫光')]:page.append(f'<figure><video controls muted loop preload="metadata" src="{asset}/{file}"></video><figcaption>{caption} · 原生固定 60fps 采集</figcaption></figure>')
for name,caption in [('grazing-reflection','真实反光高光'),('same-light-specular-disabled','相同灯光，关闭黄漆 specular'),('unlit-no-emission','关闭照明，不自发光')]:page.append(f'<figure><img loading="lazy" src="final/markings/{name}.png"><figcaption>{caption}</figcaption></figure>')
page.append('</section><p>不以烘焙成功、测试数量或面数增加代替用户视觉判断。所有阶段记录见 ML15 项目日志。</p></html>');(D/'review.html').write_text('\n'.join(page))
print('ML15_DELIVERY_INDEX',len(checks),'regression reports')
