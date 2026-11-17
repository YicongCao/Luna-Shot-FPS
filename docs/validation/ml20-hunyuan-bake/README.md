# ML20 混元高低模烘焙验证

平台：macOS、Apple M4 Pro、Blender 5.2.2 Cycles Metal、Godot 4.7.2。复现入口：`tools/ml20_weapon/run.sh`。

| 项目 | 结果 |
|---|---|
| 低模 → 高模配准 | 平均 1.60 mm，P95 3.67 mm |
| 低模三角 | 主体 18,794 + 弹夹 2,107 = 20,901 |
| UV | 约 70% 覆盖，1,796 个 UV 岛 |
| 贴图 | NormalGL 4K；BaseColor、ORM、Emission 2K |
| 枪械 QA | headless / native 均 0 失败 |
| 开火效果 | 方案 C headless / native 均 0 失败 |
| 版本选择 | 默认 ML20；ML06 显式参数与 `LS01_BASELINE=1` 均通过 |

## 画面

- Godot 实机：[腰射](native/11-range-hip.png)、[开镜红点](native/12-range-ads.png)、[换弹](native/14-range-reload.png)、[超宽开镜](native/15-range-ultrawide-ads.png)、[开火](native/pulsed-arc-hip-032ms.png)
- 枪械实验室：[主视角](native/01-hero-pbr.png)、[侧视](native/07-side.png)、[反向](native/08-reverse.png)、[灰模](native/04-hero-clay.png)、[关闭法线](native/02-hero-no-normal.png)
- Blender 概念角度预览：[视角 1](blender-concept-view-1.png)、[视角 2](blender-concept-view-2.png)，仅用于检查分区，不代表游戏实机。
- 低模法线修复：[四宫格对照](low-normal-shading-compare.png)、[最终加权法线](low-normal-weighted.png)

数据：[alignment.json](alignment.json)、[bake-report.json](bake-report.json)、[material-report.json](material-report.json)。

限制：ML06 动态弹量屏未接入；没有重拓扑，窄倒角仍有轻微起伏；没有长时间性能测试。用户美术验收待定。
