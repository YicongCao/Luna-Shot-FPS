# LC01 · 本轮实现与原 spec 对照

本文件仅描述虚构游戏资产，不是现实制造规格。原始幻想图与 P01–P12 设计意图继续保留。此次 Tripo 分件并不等于原设计编号，采用 T00–T16 记录真实来源。

| 来源件 | 视觉职责 | 运行时处理 |
|---|---|---|
| T00 CoreGrip | 内部骨架、主握把、护圈 | 上部金属，握持区橡胶 |
| T01 FrontShroud | 前部外壳 | 陶瓷涂层、橙色识别带 |
| T02 CoilAssembly | 能源环组件 | 金属；三段青色状态带 |
| T03 ReceiverShell | 侧面外壳 | 陶瓷涂层 |
| T04 EnergyCell | 能源匣主体 | 橙色涂层；重挂到 P07_Cell |
| T05 Optic | 开放式瞄具外框 | 金属；独立 RedDot 平面放在框内 |
| T06 Muzzle | 枪口外观件 | 金属 |
| T07 TopRail | 顶部安装轨外观 | 金属 |
| T08 StockShell | 枪托外壳 | 陶瓷涂层、橙色识别带 |
| T09 StockBrace | 枪托支撑 | 金属 |
| T10 ButtPad | 枪托尾垫 | 橡胶 |
| T11 CellSide | 能源匣侧件 | 与 T04 同组换弹，避免侧盖悬空 |
| T12 Foregrip | 前握持区 | 橡胶 |
| T13 CheekRest | 托上部外壳 | 陶瓷涂层 |
| T14 FrontBracket | 前部支架外观 | 陶瓷涂层 |
| T15 RailInset | 导轨嵌件 | 金属 |
| T16 FrontLatch | 前壳扣件外观 | 陶瓷涂层 |

模型总长 0.905 m。原白模光轴 Y=0.216 m；当前模型开口经检查后将光轴修订为 Y=0.178 m。`SightRear` 与 `SightFront` 标记共享光轴；`RedDot` 位于 Z=−0.060 m，`Muzzle` 位于 (0, 0.063, −0.665)。这些是游戏导入坐标，非机械尺寸设计。

运行时 `weapon_asset.gd` 负责共享 PBR、能源匣重挂和材料对照开关。`player.gd` 控制开镜、后坐和整组能源匣移动；枪械实体不参与刚体碰撞，射击使用训练场射线。独立枪械视口保留固定近裁剪面与受控反射，避免穿入环境造成视觉裁切。

## 本地复现顺序

这些命令读取已保存的 Tripo 原始输出，不调用远端、不产生新积分消费。必须使用已安装的 Blender 运行各 Python 脚本。脚本目录：`tools/weapon_pipeline/`。

1. `inspect_raw.py` → `prepare_high.py`：检查原始几何、统一坐标和单位，保存 H1。
2. `inspect_low.py` → `prepare_low.py`：恢复远端减面被归一化的坐标，固定三角化、UV 和加权法线。
3. `bake.py`：按部件从 H1 烘焙到 L1，输出 NormalGL/AO 和对应源文件。
4. `inspect_pbr.py` → `finalize_materials.py`：检查远端 UV/材质，转移至固定 UV，做语义颜色修订和 ORM 整理，打包最终 Blend。
5. `whitebox_review.py` → `audit_sources.py` → `ship.py`：控制代理、UV/网格/贴图审计，以及无重复贴图的运行时 GLB。
6. 项目根目录运行 `tools/validate.sh` 与 `tools/validate_rifle.sh`。

这是一条针对本次资产和任务 ID 的可复现管线，不是已经泛化到任意 Tripo 模型的自动美术工具。更换远端几何后，部件映射、坐标归一化、材质遮罩和瞄具光轴都需要重新检查。

## v2 修正

当前运行时使用 [v2 外表面修复与辉光版本](../../validation/rifle-pipeline-v2/README.md)。上文为 v1 初始管线；当前本地重建入口是 `tools/weapon_pipeline/repair_surfaces.sh`，读取 v1 来源后完成逐件朝向修正和重烘焙。
