# ML06 验收记录

> 状态更正：用户视觉复查未通过。下文保留功能与技术检查记录，不再作为概念美术验收通过的结论。返修清单与研究见 [2026-11-15 美术复查](../../research/weapon-material-review-2026-11-15/REVIEW.md)。

平台：macOS / Apple M5，Godot 4.7.2 Compatibility，Blender 5.2.2。全部游戏截图来自原生 Godot；概念图与 Blender 诊断图另行标注。

## 清单与证据

| 项目 | 实现与证据 |
|---|---|
| W01–W02 屏幕、弹量 | ammo-20/13/04/01/00.png、ads.png；ammo-qa.json，75 项状态检查 |
| W03 沉头紧固件 | field_kit 独立高低模；micro-0-after.png 可见屏幕框、固定夹凹入螺钉 |
| W04 黑橙警示条 | 主体既有 UV 内按机匣区域投射；腰射与材料室可见 |
| W05–W06 铜排线、散热片 | 两侧六条铜带和两端夹具，各八片散热片；Kit/geometry.json，8,472 三角 |
| W07 材料使用痕迹 | 确定性划痕加 imagegen 微凹坑/划痕，micro-0/1-before/after.png 固定光照对比 |
| W08 平面与倒角修整 | sharpen-report.json，最大位移小于1.5mm；asset-audit.json 验证原 UV 和面连接不变；重新烘焙 |
| A01–A02 槽和沉孔 | 六块顶盖12槽24孔；A/after/lid-close.png，保留原低模，仅高模加工与投射 |
| A03–A04 磨损与标识 | A/after/0-front、lid-close、range-interface；检修接触长擦痕、接口侧警示条和底座积尘 |

## 回归

- 75 项动态弹量检查：逐发20→0、格数与数字一致、空仓禁射、换弹未完成不填满、完成补满、F5与暂停状态同步。
- 枪械：19项无界面、29项原生回归通过；开镜红点、命中、换弹、超宽窗口、F3材料室往返。
- 地图：20固定种子、188模块检查、69无界面与81原生训练检查通过；真实胶囊走外围、主道、支路、双高架与桥下。
- 光照：13项原生检查通过，保留能量环、光晕遮挡与开镜效果。600帧短程数据只代表本机短程运行，不视为长期性能保证。
- 原枪械和 A 的逐角 UV / 面索引审计通过；附件单独UV，无主体重打包；Tripo GLB完整性通过。

## 迭代记录

1. 首版方向擦痕过细、铜排线过暗：减少均匀碎点、加长接触带划痕并调亮铜材质。
2. A 整体布尔误伤合并壳体与空材质槽：拒收首轮，改为逐块闭合顶盖加工、完整重烘焙、四侧实机复查。
3. Tripo 生成片组排列偏离概念：原始模型保留为参考，精确件本地重建，没有付费重抽。
4. imagegen 初版微法线过强：降低高度幅度到45μm参数尺度并去除背景颗粒，只留下较明显的微凹坑/划痕信号。图案是人工美术信号，不声称真实测量高度。

## 资源与费用

Tripo：单次 `tripo_text_to_3d`，任务 `f7ac912d-85a0-4356-ba2c-8e221e6dd036`，30积分。无其他生成任务。

生成原模型：`/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/industrial-wear-v1/00-tripo/model.glb`。该模型是参考源，最终运行时附件为 `assets/weapons/lc01/field_kit/kit.glb`。

来源：`art_source/industrial-wear-v1` 与 `art_source/weapons/lc01/industrial-wear-v1`；复现脚本 `tools/industrial_wear`。imagegen 原图与提示词在 `06-imagegen`，修改前后贴图均保留。没有新增环境类别，也未改变 A 的占地或碰撞。

微表面专项审计：主体法线变化1,095,416像素（含边缘扩展），附件766,856像素；原橡胶和发光区域法线变化为0像素，Emission.png逐字节不变。最终微表面版本再跑枪械19/29项与弹量75项检查，均通过。
