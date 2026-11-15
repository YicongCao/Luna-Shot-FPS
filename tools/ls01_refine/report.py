"""Assemble ML07 evidence report; visual decisions must already be recorded by a reviewer."""
from pathlib import Path
import json
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/ls01-refine-v1'
def read(name):return json.loads((D/name).read_text())
p=read('performance-comparison.json');v=read('visual-review.json');geom=read('geometry-audit.json');runtime=read('runtime-audit.json');padding=read('padding-audit.json');ammo=read('ammo-qa.json');before=read('weapon-metrics-before.json');after=read('weapon-metrics-after.json')
passed=p['within_10_percent'] and not any(read(x)['failures'] for x in ['geometry-audit.json','runtime-audit.json','bake-audit.json','padding-audit.json']) and all(x['passed'] for x in ammo)
mem0=p['before'][0]['texture_memory']/1048576;mem1=p['after'][0]['texture_memory']/1048576
s=f'''# ML07 · LS01 原生验证与视觉复查

日期：2026-11-16。平台：本机 macOS / Apple M5，Godot 4.7.2 Compatibility；Blender 5.2.2 Cycles Metal。所有实机 PNG 均由 Godot 原生视口保存。

## 状态与范围

技术门槛：**{'通过' if passed else '未通过'}**。实施视觉复查：**本轮重建范围通过，概念差距仍开放**。用户验收：**待验收**。

本轮重建机匣、两件弹夹、枪托、瞄具、顶轨及工业附件；十一件保留原几何/UV，使用改进的材料分层和此前真实烘焙法线。不能把该结果称为全枪完全重拓扑，也不宣称逐像素达到概念图。

[原生新旧对照](review.html) · [设计](../../art/ls01-refine-v1/DESIGN.md) · [逐件规格](../../art/ls01-refine-v1/PARTS.md) · [最初问题清单](../../research/weapon-material-review-2026-11-15/REVIEW.md)

## R01–R12 逐项复查

“本轮通过”指下表描述的实际实现，不等于右栏概念差距已经关闭。每项用户验收均 pending。

|问题|实施复查与实际证据|保留边界／概念差距|
|---|---|---|
'''
for row in v['issues']:
 links=' · '.join(f'[{Path(x).stem}]({x})' for x in row['evidence'])
 s+=f"|{row['id']} {row['title']}|本轮通过：{row['judgement']}<br>{links}|{row['remaining']}|\n"
s+=f'''
## 几何、UV 与烘焙

- 120 组高模/低模/cage，42 颗螺钉清册。GLB 静态低模 **{runtime['triangles']:,} 三角、{runtime['meshes']} 网格**。包含程序化屏幕、字标等的武器网格总计 **{after['triangles_including_runtime_meshes']:,} 三角**，低于 60,000。
- 新件无退化面、意外非流形边或负体积，cage 与低模拓扑一致。保留十一件逐三角位置及 UV 对照相同；全部导出切线。环境与 A 资产哈希不变。
- 新 atlas 严格内部重叠为 0。UV 覆盖率主体 {geom['atlases']['body_uv']['coverage']:.1%}、附件 {geom['atlases']['kit_uv']['coverage']:.1%}。连续 UV 岛 ID 审计的最小间距换算到 2K 为 {padding['body']['minimum_separation_px_at_2k']:.0f}px；栅格估算误差约 2px，扩边为每侧 16px。
- 高低模按零件爆炸隔离，单独 cage 外扩范围见清册；4K Cycles selected-to-active 实际输出 NormalGL、AO、BaseColor、Roughness、Metallic、Curvature、EdgeMask、Position PNG/EXR、WorldNormal、MaterialID、WearMask、OilMask。
- Curvature 是高模 Cycles Pointiness（0.5 表示平坦的近似编码），EdgeMask 是受控边界距离代理，不能混称。AO 为配对内局部 AO，不能证明装配后遮挡已全部烘入。
- 保留件使用 ML06 微法线叠加之前的真实烘焙法线，移除逐面主轴微法线补丁。源分层材质和实际投射场景均保留。

[几何审计](geometry-audit.json) · [UV padding](padding-audit.json) · [保留件/环境](runtime-audit.json) · [贴图审计](bake-audit.json)

## 材质与分辨率决定

涂层保持非金属，露底遮罩同时控制底色、金属度和粗糙度；钢头、铜管、暗色涂层、玻璃、橡胶分别绑定。油膜与积尘使用不同粗糙度，表面高模 bump 和真实浅压伤统一进入法线烘焙。imagegen 仅提供艺术遮罩，不是测量高度或完整物理 PBR。

初始主体 2K 的十字槽近景偏软。[2K 证据](resolution-study/2k/screw-close.png) 与 [最终证据](screw-close.png) 使用相同机位。最终尺寸以 [resolution.json](../../../assets/weapons/lc01/ls01_v1/resolution.json) 为准。4K 母版保留，运行时仅为实际需要的通道增加分辨率。GPU 压缩、mipmap 和各向异性过滤开启，NormalGL 不翻转 Y；ORM 为线性数据。

未压缩全主体 4K 的 +21.3% P95 版本被拒绝。压缩后仍进行平衡顺序复测，不用一次较快样本替代完整比较。所有失败/中间轮次保存在 performance-history。

压缩设置依据 [Godot 图像导入文档](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)：Compatibility 使用相应桌面压缩格式，法线单独启用 normal-map 导入。源 PNG 母版不进行有损覆盖。

## 游戏功能与性能

弹量专项 **{len(ammo)} 项检查通过**，覆盖逐发扣弹、20/13/4/1/0、换弹和20格显示。原生枪械检查、开镜红点、命中、两弹夹动画、F2、F3 往返、能量环、Bloom、光晕遮挡和超宽窗口见对应日志与截图；不能由这些功能断言推出美术一致性。

|指标|ML06 基线|ML07|
|---|---:|---:|
|武器三角（含运行时网格）|{before['triangles_including_runtime_meshes']:,}|{after['triangles_including_runtime_meshes']:,}|
|武器 MeshInstance 数|{before['mesh_instances']}|{after['mesh_instances']}|
|武器唯一材质（不含 Label3D 字体内部材质）|{before['unique_materials']}|{after['unique_materials']}|
|整个场景纹理内存|{mem0:.1f} MiB|{mem1:.1f} MiB|
|P95 帧时间中位数|{p['before_p95_median_ms']:.3f} ms|{p['after_p95_median_ms']:.3f} ms|

相对变化 **{p['increase_fraction']:+.1%}**；10% 门槛 **{'通过' if p['within_10_percent'] else '未通过'}**。1600×1000，每次预热 150 帧后测 600 帧，ABBA ABBA 顺序，各版 4 次。测量为真实渲染帧间单调时钟时间，不是固定 physics delta。后台仍有用户原有游戏窗口及桌面应用，因此绝对 FPS 是本次机器负载下的结果，不代表独占性能或长时间稳定帧率。

[完整性能样本](performance-comparison.json) · [弹量检查](ammo-qa.json) · [原生枪械日志](rifle/native.log) · [F3 往返](scene-switch.log) · [光照专项](lighting.log)

## 交付与仍开放事项

- 主要概念差距：保留前罩/枪口/支架的生成轮廓仍偏软；LS01 字重与概念不同；个别边缘磨损仍偏规则；关卡硬光氛围与概念不同。以上保持开放，不记为用户验收通过。
- 旧资源和参数在 art_source/weapons/lc01/ls01-refine-v1/00-baseline。通过 launch-weapon-baseline.command 可查看原版。
- 付费调用：imagegen **2 次**，Tripo **0 次 / 0 积分**。imagegen 工具未返回金额，因此实际货币费用未知；提示词与调用记录在 docs/art/ls01-refine-v1/imagegen.json。
- 本轮没有 Git 提交或推送，保护既有未提交改动；A 和其他环境资源未修改。

复现、候选启用及回退方法见 [工具说明](../../../tools/ls01_refine/README.md)。
'''
(D/'REPORT.md').write_text(s)
print('REPORT_WRITTEN technical_pass=',passed)
