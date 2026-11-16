from pathlib import Path
import json,re,subprocess
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/tripo-high-performance'
rows=[]
for name in ['baseline','normal-off-run1','normal-pbr-run1','normal-pbr','normal-off']:
 j=json.loads((D/(name+'.json')).read_text());assert j['seconds']>=60 and j['frames']>0 and j['vsync']=='disabled';j['run_file']=name;rows.append(j)
for p in D.glob('*.log'):
 assert not any(s in p.read_text() for s in ['SCRIPT ERROR','Parse Error','ERROR:']),p
subprocess.run(['git','diff','--exit-code','--','assets','scripts','scenes','project.godot','art_source'],check=True)
(D/'summary.json').write_text(json.dumps({'runs':rows,'platform':'macOS Apple M5 / Godot4.7.2 Compatibility','resolution':[1600,1000],'weapon_viewport':[1440,900],'warmup_seconds':5,'sample_seconds':60,'paid_calls':0,'default_unchanged':True},indent=2))
md=['# ML17 高模直接渲染与法线成本测试','','macOS Apple M5 / Godot4.7.2 Compatibility。完整64×66m训练场，1600×1000窗口，独立武器视口1440×900；VSync关闭、Engine.max_fps=0，5秒预热后各60秒。读取服务原始高模GLB(1,934,290三角)，18网格/材质，恢复0.905m枪长后替换测试进程中的武器视觉，不保存回默认场景。','','| 模式/轮次 | 平均FPS | P50帧时间ms | P95帧时间ms | 纹理内存MiB |','|---|---:|---:|---:|---:|']
for j in rows:md.append(f"| {j['run_file']} | {j['average_fps']:.1f} | {j['p50_ms']:.3f} | {j['p95_ms']:.3f} | {j['texture_bytes']/2**20:.1f} |")
md+=['','normal-off仅禁用法线贴图，仍保留顶点法线、底色、金属度和粗糙度；normal-pbr启用服务原始法线。两个高模模式的几何/材质数量、贴图加载、灯光及镜头一致。法线关闭时贴图仍驻留内存，因此不能用本测试衡量卸载法线纹理后的省内存幅度。ML06基线含既有工业附件与现有材质，是实际旧版参照；其几何/材质与候选不同，不能将全部差异只归因于三角数。','','测量顺序：normal-off → normal-pbr → ML06 baseline → normal-pbr复测 → normal-off复测。每次独立Godot进程，GPU测试串行；未同时渲染Blender/运行其他Godot验证。此采样包含完整场景与原生武器合成/后期/CPU提交，不是纯GPU计时。平均FPS按帧数/墙钟时间，P50/P95按process_frame间隔；采样中只保存一次同机位截图，截图I/O时间不用于帧间隔但计入总时长。','','玩家固定在出生点做同幅度左右扫视，不射击、不移动胶囊，环境动态与默认后期继续。原ML06能量关闭，原武器视觉在候选测试中隐藏、脚本仍存在；高模候选为静态视觉，未适配换弹、红点或弹药屏。本结果不代表所有路径、射击特效、超宽/4K或其他机器表现，也没有证明长时间无降频。复测范围如有较大波动，应同时报告而非选择最快一轮。','','## 低模平滑诊断','','[原法线灰模](low-smooth.png)与[逐三角面法线灰模](low-flat.png)使用同一个低模、同机位、同光照。诊断shader从位置导数计算面法线，没有改顶点/UV或写回GLB；用于判断平滑插值与实际几何区别，不作为已完成修复。改变正式顶点法线后应重新处理相关烘焙。','','[Tripo参数与网页查看核查](PARAMETERS.md)详细区分API可用字段、Studio文档选项和通用博客说法。当前未找到可直接传入本次v3.0任务的smooth=false。建议先查看/比较现有高模可用性，再决定是否花费预算尝试v1基础减面或分件；本次新增付费调用0。','','## 复现','','RIFLE_PERF_MODE=normal-off|normal-pbr|baseline godot --path . --script tools/tripo_weapon/performance.gd。每轮约65秒加导入。godot --path . --script tools/tripo_weapon/shading_diagnostic.gd生成面法线诊断图。所有原始帧时间摘要/截图和日志在本目录；源资产/默认场景无更改。']
md += ['', '## 波动与追加交替测试', '', 'normal-off两轮65.7～156.7FPS，normal-pbr两轮73.1～86.1FPS；关闭法线复测波动很大，结果范围重叠，不能据首轮差异认定法线使帧率减半。诊断时发现后台Chrome渲染进程约196%CPU、WindowServer也有负载；pmset未记录热/性能警告。该快照不能证明各轮GPU负载或热状态相同，未强制关闭用户其他应用。']
if (D/'paired.json').exists():
 paired=json.loads((D/'paired.json').read_text());assert paired['seconds']>=60
 md += ['', '追加同进程60秒交替测试，每10秒切换一次，排除每段前1.5秒。它缩短设置间的时间差，但完整场景仍在左右扫视，不是纯GPU计时。', '', '| 段 | Normal | 平均FPS | P95 ms |','|---|---|---:|---:|']
 for b in paired['blocks']:md.append(f"| {b['block']} | {b['normal_enabled']} | {b['average_fps']:.1f} | {b['p95_ms']:.3f} |")
 md += ['', '高模在本机确实能实时渲染；这些采样不能承诺所有路径或后台状态都稳定60FPS。无新增付费任务，默认资源未替换。']
(D/'REPORT.md').write_text('\n'.join(md)+'\n')
page=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>ML17 高模实机帧率与平滑诊断</title><style>body{max-width:1500px;margin:30px auto;padding:0 20px;background:#141c26;color:#eef;font:16px/1.6 system-ui}a{color:#7edee9}table{border-collapse:collapse}td,th{padding:8px 16px;border:1px solid #53616e}img{width:100%}.pair{display:grid;grid-template-columns:1fr 1fr;gap:12px}@media(max-width:800px){.pair{grid-template-columns:1fr}}</style><h1>高模直接进入训练场：法线开／关帧率</h1><p>原生Godot4.7.2 / Apple M5。1600×1000窗口、1440×900武器视口；无帧率限制，每轮5秒预热+60秒。默认游戏资源未改变，候选仅替换测试进程视觉。<a href="REPORT.md">完整测量与限制</a> · <a href="PARAMETERS.md">Tripo参数／网页查看</a></p><table><tr><th>轮次</th><th>平均FPS</th><th>P50 ms</th><th>P95 ms</th></tr>']
for j in rows:page.append(f"<tr><td>{j['run_file']}</td><td>{j['average_fps']:.1f}</td><td>{j['p50_ms']:.3f}</td><td>{j['p95_ms']:.3f}</td></tr>")
page.append('</table><p>normal-off复测波动大，两种模式范围重叠，不能据首轮差异认定法线让帧率减半。追加交替测试见完整报告。</p><h2>原生训练场截图</h2><div class="pair">')
for name in ['normal-off','normal-pbr']:page.append(f'<div>{name}<a href="{name}.png"><img src="{name}.png"></a></div>')
page.append('</div><h2>同一个低模：原平滑法线与逐面法线诊断</h2><p>几何、顶点和UV相同。此图只排查法线插值，不是发布修复。</p><div class="pair">')
for name in ['low-smooth','low-flat']:page.append(f'<div>{name}<a href="{name}.png"><img src="{name}.png"></a></div>')
page.append('</div>');(D/'review.html').write_text('\n'.join(page))
print('PERF_REPORT_READY',[(j['run_file'],round(j['average_fps'],1)) for j in rows])
