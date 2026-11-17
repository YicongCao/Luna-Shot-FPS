# Luna-Shot-FPS

独立月球能源设施训练场，64×66 m。A/B1/B2/C/D/E 六件资产完成白模、高模、低模/UV、真实 Normal/AO 烘焙、PBR 和 Godot 集成，复用为 59 个实例。LS01 保留红点瞄准和可击倒靶；新增低角度日照、设施灯、反射探针、能量环轮廓外 Bloom 与 imagegen 镜头光晕。无回合、无刷怪、无游戏流程。

## ML28：方向光软阴影修正与月面候选

清剿与 Benchmark 默认提高方向光软阴影采样，减轻地面细密条纹，保留暖黄雾与柔和半影；`QUARANTINE_SHADOWS=baseline ./launch-benchmark.command` 回看旧采样档。高档有 GPU 成本，实测与边界见报告。

新月面网格更平滑，但同时损失山脊起伏，**未替换默认远景**；仅用 `QUARANTINE_HORIZON=refined` 预览候选，不把几何测试通过当作美术升级。

[原生分项对照](docs/validation/lunar-horizon-v1/review.html) · [验证、性能与取舍](docs/validation/lunar-horizon-v1/REPORT.md)

## ML27：特写景深与实体检修灯

实时 Benchmark 的害虫特写改为近距离三分之四构图，使用原生景深分离背景；实际战斗、ADS、终端和撤离保持清晰。屋架下新增一盏实体检修灯，在正常清剿与演示中共同改善局部暗部，不改变暖黄雾层和全场曝光。

[构图／景深／灯光分项对照](docs/validation/benchmark-lens-v1/review.html) · [验证与边界](docs/validation/benchmark-lens-v1/REPORT.md)。`QUARANTINE_BENCHMARK_LENS=off` 关闭景深；`QUARANTINE_SERVICE_LIGHT=off` 关闭新增检修灯。

## ML26：T-Bug 机械结构精修

清剿关卡与实时 Benchmark 的害虫默认使用分层厚装甲、机械关节、执行器/脚垫及嵌入式发光件；保留六足、三发击杀和当前暖黄氛围。`QUARANTINE_BUG_STYLE=baseline ./launch-benchmark.command` 对照旧版。

[新旧灰模与材质对照](docs/validation/t-bug-refine-v1/review.html) · [验证与取舍](docs/validation/t-bug-refine-v1/REPORT.md)。无新增模型/图像生成调用；用户视觉验收待定。

## 当前氛围：ML25 暖黄体积雾

清剿关卡与 Benchmark 默认恢复暖黄、灰金色的末世氛围，同时保留最新结构、图标 HUD、全息终端与电击反馈。`QUARANTINE_ATMOSPHERE=clear ./launch-benchmark.command` 可查看 ML24 清淡光照对照，不回退玩法或资产。

[同机位原生对照](docs/validation/quarantine-atmosphere-v1/review.html) · [参数与验证](docs/validation/quarantine-atmosphere-v1/REPORT.md)

## ML24：实机 Benchmark 与全息终端

双击 **`launch-benchmark.command`**：约52秒的实时引擎演示，包含设施镜头、T-Bug交战、终端上电和撤离；不是预录视频。结束后 **R重播 / Enter进入可玩关卡 / Esc退出**。可传入 `--fullscreen`。

HUD任务以 `n/8、0/1、0/1` 显示数量，终端/撤离有定位和离屏方向提示。终端只保留一块设备投射的全息面板；靠近、看向且无遮挡时按住E三秒。T-Bug增加命中短路、抽动、局部损伤和残余放电，仍保持三发击杀。

[原生画面与交互](docs/validation/quarantine-benchmark-v1/review.html) · [UX复查](docs/validation/quarantine-benchmark-v1/UX-REVIEW.md) · [验证与性能](docs/validation/quarantine-benchmark-v1/REPORT.md)

镜头/敌人站位有编排，三只由真实射击击杀，其余五只在切镜时清除；不是无人干预通关。结果保存在Godot `user://benchmarks/`，可用 `QUARANTINE_BENCHMARK_OUTPUT` 指定目录。验证入口：`tools/validate_quarantine_benchmark.sh`。

## ML22：SELENE / QUARANTINE 独立关卡小样

双击 **`launch-quarantine.command`**：清理8只程序化 T-Bug → 在北侧终端按住 **E 3秒** → 返回南侧绿色圆形撤离区。包含生命/失败、暂停、重新部署，右键开镜显示战斗机仪表灵感HUD。原训练场入口和 ML21 枪械资产保持。

新关卡单独采用 **Forward+ / 1920×810**，增加工业上部结构、场外程序月面、低角度暖光/冷色环境、SSAO/SSIL/SSR、体积光、真实遮挡的 imagegen 光学素材、能源恢复场面与合成声音。**无新增Tripo调用；无新imagegen调用，复用既有光学纹理。** 这是朝电影化画质推进的可玩样板，不宣称已达到3A照片级画质，用户美术验收待定。

- [原生截图与视频](docs/validation/quarantine-v1/review.html) · [验证、性能与限制](docs/validation/quarantine-v1/REPORT.md)
- 新关卡操作：WASD / Shift / Space / 左键开火 / 右键ADS / R换弹 / E交互 / ESC暂停 / F5重开；F7 Bloom、F8光晕、F10可选电影黑边。
- `QUARANTINE_COMPAT=1 ./launch-quarantine.command` 为兼容渲染回退（不包含Forward+专属效果，不与高质量证据等同）。
- 验证入口：`tools/validate_quarantine.sh --performance`；原生宽荧幕演示录制：`tools/quarantine/record.sh`。

## 运行

macOS 双击 `launch.command`，或用 Godot 4.7.2 打开 `project.godot` 后按 F5。当前验证平台为 macOS / Apple M5 / Compatibility 渲染器。

启动脚本会自动查找 `/Applications`、用户 Applications 目录或 PATH 中的 Godot，并先导入资源。自定义安装路径可用 `GODOT_BIN="/完整路径/Godot" ./launch.command`；导入日志位于 `artifacts/launch/import.log`。脚本支持透传 Godot 启动参数。

WASD 移动 · 鼠标视角 · Shift 冲刺 · 空格跳跃 · 左键射击（一枪击倒 T 系列靶，F5 复位） · **右键红点瞄准** · R 换弹 · F2 总览 · **F3 材料检查室** · F5 重置 · ESC 暂停。

光效调试：**F6 能量环 · F7 Bloom · F8 镜头光晕 · F9 局部补光**。

也可单独运行 `launch-weapon-lab.command`：拖动旋转、滚轮缩放、1–9 切换最终材质/关闭法线/统一响应/灰模/底色/金属度/粗糙度/AO/仅烘焙法线、L 切换灯光、B 能量开关、F3 返回训练场。

## 项目日志

[日志索引](docs/logs/README.md) · [ML01-枪械建模](docs/logs/ML01-枪械建模.md) · [ML02-过程生成白模](docs/logs/ML02-过程生成白模.md)

## 当前地面版本：ML16

当前默认关卡已按用户选择改为全铺装：2×4m工业铺装、检修盖及A设备座基。月壤PBR、高度源和混合遮罩代码保留，未来可研究弹着破损露出月壤，本次未实现破损。双击 `launch-ground-sample.command` 仍可查看历史8×8m混合样板；`GROUND_BASELINE=1 ./launch.command` 查看ML15旧地面。

[当前全铺装验证](docs/validation/ground-paved/README.md) · [三种覆盖对照](docs/validation/ground-coverage/review.html) · [场景与地图进度](docs/design/scene-map-status-2026-11-16.md) · [ML16经验](docs/logs/ML16-工业铺装与月壤地面.md)。

## 环境模块版本：ML15

B1/B2/C/D/E 已精修并接入默认关卡：分层散热结构、开放桁架、连续坡道、48红灯/32蓝灯/旋转橙色警灯和黄色反光标线。Tripo本轮300/400积分；A与ML06枪械保持。

[原生对照与视频](docs/validation/environment-refine-v2/review.html) · [完整验证与限制](docs/validation/environment-refine-v2/final/REPORT.md) · [复现入口](tools/environment_refine/README.md)。技术与实施视觉复查通过，用户实机美术验收待定。

![ML15 原生总览](docs/validation/environment-refine-v2/final/release/02-overview.png)

## 历史环境阶段

- [ML05-A 配电机组精修](docs/logs/ML05-A配电机组精修.md)：六块顶盖、检修门、三路接口和线缆；5,180 三角，无新增 Tripo 消费。
- [A 新旧原生对照](docs/validation/A-refine-v2/review.html)。A 的 ML05 基础来源为 `art_source/environment/A-refine-v2/`，后续工业磨损见 ML06；其余五件当前来源为 `art_source/environment/refine-v2/`。

- [ML03-环境模块建模](docs/logs/ML03-环境模块建模.md)：六资产共 690 Tripo 积分，18 次任务全部成功。
- [ML04-光照与镜头效果](docs/logs/ML04-光照与镜头效果.md) · [原生光照对照页面](docs/validation/lighting-v1/review.html)
- [六资产数据](docs/validation/environment-pipeline-v1/PIPELINE.md) · [逐任务费用](docs/validation/environment-pipeline-v1/CREDITS.md)

![最终光照总览](docs/validation/lighting-v1/41-overview.png)

以下为此前白模和枪械阶段记录。

- [能源设施设计、模块规格与生成命令](docs/design/WHITEBOX.md)
- [能源设施实机验证](docs/validation/energy-whitebox-v2/README.md)

![新关卡原生总览](docs/validation/energy-whitebox-v2/02-overview.png)

- [枪械管线、费用、实机证据和限制](docs/validation/rifle-pipeline-v2/README.md)
- [可交互的实机材质对照](docs/validation/rifle-pipeline-v2/review.html)
- [本轮部件实现对照](docs/art/rifle-pipeline-v1/IMPLEMENTATION.md)
- [原枪械幻想图与 spec](docs/art/rifle-v1/SPEC.md)
- [训练场白模设计](docs/design/WHITEBOX.md)
- [原始白模阶段验证](docs/validation/whitebox-v1/README.md)

![Godot 原生 PBR 实拍](docs/validation/rifle-pipeline-v2/01-hero-pbr.png)

运行时资产：`assets/weapons/lc01/lc01.glb`。完整可编辑来源与分阶段产物：`art_source/weapons/lc01/pipeline-v2/`。最终 Blend：`07-final/lc01-final.blend`。原 B0 白模保留在上一层，v1 全部阶段及旧截图保留。

ML01 枪械阶段实际使用 115 Tripo 积分（60 + 35 + 20），没有重抽。19,658 三角面、17 部件、四张 2K 贴图。已经打通管线，但自动网格仍有局部折面/接缝和 UV 利用率偏低等限制，不将概念图当作已达到的实机质量。

`tools/validate.sh` 检查训练场回归，`tools/validate_rifle.sh` 检查枪械、红点、场景切换及实际材质截图。二者会打开原生窗口并自动退出。构建入口与范围见 AGENTS.md。

光照专项：`tools/validate_lighting.sh`。运行时环境 GLB 位于 `assets/environment/{A,B1,B2,C,D,E}/`，ML03历史源位于 `art_source/environment/pipeline-v1/`，B1/B2/C/D/E最新精修源位于 `art_source/environment/refine-v2/`；生成器默认保留精模，`--art whitebox` 可导出原白模。

## ML07 枪械返修

保留的 ML07 LS01 返修资源在 `assets/weapons/lc01/ls01_v1`，可编辑高低模、独立 cage 和材质源在 `art_source/weapons/lc01/ls01-refine-v1`。`APPROVED` 标记仅代表本轮技术与实施复查，不代表用户已验收。原 LC01/ML06 资源保留，双击 `launch-weapon-baseline.command` 可对照。

[新旧原生画面对照](docs/validation/ls01-refine-v1/review.html) · [检查报告与开放差距](docs/validation/ls01-refine-v1/REPORT.md) · [逐件规格](docs/art/ls01-refine-v1/PARTS.md) · [复现步骤](tools/ls01_refine/README.md) · [ML07 日志](docs/logs/ML07-枪械精确几何与分层材质返修.md)。

## GitHub 与获取资产

私有仓库：[YicongCao/Luna-Shot-FPS](https://github.com/YicongCao/Luna-Shot-FPS)。需要仓库访问权限及 Git LFS，模型和贴图不能仅靠 ZIP 中的 LFS 指针运行。

```sh
# 先安装 Git LFS（macOS 可用 brew install git-lfs）
git lfs install
git clone git@github.com:YicongCao/Luna-Shot-FPS.git
cd Luna-Shot-FPS
git lfs pull
./launch.command
```

源文件、有效烘焙与验证证据已版本化；失败烘焙的重复二进制、缓存和临时产物留在本地。工作经验与提交约定见 [ML08](docs/logs/ML08-资产管线复盘与版本归档.md)。

## ML09 结构还原

2026-11-16 用户比较三版实机后选择 ML06，当前默认已回滚为 ML06。ML07、ML09 保留为对照，不作为用户认可的视觉升级。

在ML07分层材质基础上，恢复ML06/概念的弹夹分段、枪托宽倒角及黑白斜接、八角瞄具和前后安装鳍片、下移端点的不规则六边形嵌入屏，以及能量环附近护罩支撑。增加两盏受遮挡的青色侧向补光。阶段证据和用户验收分开记录。

[ML06/ML07/ML09 原生对照](docs/validation/ls01-refine-v2/review.html) · [验证报告](docs/validation/ls01-refine-v2/REPORT.md) · [逐件清单](docs/art/ls01-refine-v2/PARTS.md) · [ML09 日志](docs/logs/ML09-枪械结构还原与能量环侧向照明.md)。

Godot命令行显式选择：`-- --weapon-revision=ml06`、`ml07`、`ml09`、`ml20`或`ml21`。不传参数时采用 ML21，APPROVED 不会自动切换默认；`LS01_BASELINE=1`仍可回ML06，`LS01_CANDIDATE=1`保留ML07候选语义。ML09 新源在`art_source/weapons/lc01/ls01-refine-v2`，运行资产在`assets/weapons/lc01/ls01_v2`。重建已发布资产时需选新的`--out`/`--runtime`目录。

## ML21 混元枪械迭代（当前默认）

在 ML20 基础上：机身改为深藏青黑，弹夹壳全部涂橙，两侧铭牌与斜线蚀刻打平后重新烘焙，高模按角度平滑并锐化法线让线条更利，后机匣斜面加装 20 格动态弹量屏。[验证](docs/validation/ml21-hunyuan-refine/README.md) · [ML21 日志](docs/logs/ML21-混元枪械配色弹夹蚀刻与弹量屏迭代.md) · 复现 `tools/hunyuan_weapon/run.sh`。

## ML20 混元烘焙枪械

使用混元高模烘焙到带 UV 的约 2 万面低模，按两张概念图完成材质分区和 PBR 上色，并替换 ML06 成为默认枪械。[验证](docs/validation/ml20-hunyuan-bake/README.md) · [ML20 日志](docs/logs/ML20-混元高低模烘焙与默认枪械替换.md) · 复现：提交 `2dfee1c` 的 `tools/ml20_weapon/run.sh`（工具已改名为 `tools/hunyuan_weapon`，当前输出 ML21）。

## 脉冲电弧开火效果（方案 C）

默认枪械使用纯代码方案 C：短促折线主弧、少量分叉、线圈局部放电及合成电气音效。双击 `launch.command` 游玩；[原生演示](docs/validation/pulsed-arc-v1/review.html) · [ML13 记录](docs/logs/ML13-纯代码脉冲电弧开火效果.md)。专项验证入口 `tools/validate_pulsed_arc.sh`。

历史 A 保留：[ML12](docs/logs/ML12-纯代码聚束磁脉冲开火效果.md)。显式 `./launch.command -- --fire-effect=a` 可对照，不改变默认 C。
