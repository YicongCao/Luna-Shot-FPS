# ML21 混元枪械迭代验证

平台：macOS、Apple M4 Pro、Blender 5.2.2 Cycles Metal、Godot 4.7.2。复现入口：`tools/hunyuan_weapon/run.sh`（输入仍为 ML18 归档的混元高模/UV 低模，不调用付费服务）。

| 项目 | 结果 |
|---|---|
| 两侧蚀刻打平 | 机匣铭牌、斜线刻痕、前护罩小刻痕共 6 处；高模移动 19,522 顶点，低模 330 顶点；删除折叠碎面 高模 4,675 / 低模 44，叠层共面面 41 |
| 低模三角 | 主体 18,693 + 弹夹 2,107 = 20,800（ML20 为 20,901） |
| 配色 | 机身岩石灰 (74,79,86) → 深藏青黑 (28,35,46)；握把黑 (19,20,22)、粗糙度 0.78，与机身区分 |
| 弹夹 | 弹夹壳按 UV 岛整体投票：壳体全部安全橙，端块与底轨为机身色；新增橙色纹素 40,449 |
| 线条 | 高模按 35° 角度平滑后再投射法线；4K 法线反锐化 σ=1.6 px、强度 0.55，平均法线梯度 +22% |
| 弹量屏 | 复用 ML06 20 格动态屏（仅屏幕，无导线盒/散热片），0.7 倍尺寸贴合后机匣斜面，后倾 37.6°，高出表面 4 mm |
| 枪械 QA | headless / native 均 0 失败（含 `ml21_ammo_screen`） |
| 开火效果 | 方案 C headless / native 均 0 失败，`default_ml21` |
| 版本选择 | 默认 ML21；`--weapon-revision=ml20`、`LS01_BASELINE=1`（ML06）均通过 |

## 画面

- Godot 实机：[腰射](native/11-range-hip.png)、[开镜](native/12-range-ads.png)、[换弹](native/14-range-reload.png)、[开火后 19/20](pulsed-arc/hip-032ms.png)、[超宽开镜](native/15-range-ultrawide-ads.png)
- 枪械实验室：[主视角](native/01-hero-pbr.png)、[侧视](native/07-side.png)、[反向](native/08-reverse.png)、[灰模](native/04-hero-clay.png)、[近景](native/09-surface-close.png)
- Blender 前后对照（离线预览，不代表实机）：[蚀刻打平](blender-etch-flatten-compare.png)、[弹夹](blender-magazine-compare.png)、[侧视](blender-side-compare.png)、[近景线条](blender-close-compare.png)、[概念角度 1](blender-concept-view-1.png)、[概念角度 2](blender-concept-view-2.png)

数据：[alignment.json](alignment.json)、[bake-report.json](bake-report.json)、[material-report.json](material-report.json)。

## 过程中发现并修复

最初打平后，铭牌位置仍有约 11×7 mm 的暗块。逐项排除：贴图数值一致、关闭法线贴图仍在、纯灰模仍在。根因是字形笔画面与凹槽底面打平后落在同一平面，发生 z-fighting。现在删除被更大共面面完全覆盖的面、删除折叠碎面，并给打平区与周边侧板统一平面着色法线，灰模中已完全平整。

## 限制

- 左侧原铭牌处 UV 接缝有一条约 1 px 的橙色渗色，近距离才可见。
- 磨损按用户要求本次未调整；颜色更深后，少量掉漆点比 ML20 更显眼。
- 前护罩下方大斜槽、长条槽孔属于概念图散热口，保留。
- 没有长时间性能测试。技术与实施检查通过，用户美术验收待定。
