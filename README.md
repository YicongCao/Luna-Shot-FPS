# Luna-Shot-FPS

独立月球训练场。环境为白模；LC01 枪械已完成 Tripo + Blender 高低模、真实烘焙、PBR 和 Godot 集成；v2 已修复枪托/环体反向外表面，并补上能量环辉光。无回合、无刷怪、无游戏流程。

## 运行

macOS 双击 `launch.command`，或用 Godot 4.7.2 打开 `project.godot` 后按 F5。当前验证平台为 macOS / Apple M5 / Compatibility 渲染器。

WASD 移动 · 鼠标视角 · Shift 冲刺 · 空格跳跃 · 左键射击 · **右键红点瞄准** · R 换弹 · F2 总览 · **F3 材料检查室** · F5 重置 · ESC 暂停。

也可单独运行 `launch-weapon-lab.command`：拖动旋转、滚轮缩放、1–4 切换 PBR/关闭法线/统一材质参数/灰模、L 切换灯光、B 能量开关、F3 返回训练场。

## 项目日志

[日志索引](docs/logs/README.md) · [ML01-枪械建模](docs/logs/ML01-枪械建模.md)

## 本轮产物

- [枪械管线、费用、实机证据和限制](docs/validation/rifle-pipeline-v2/README.md)
- [可交互的实机材质对照](docs/validation/rifle-pipeline-v2/review.html)
- [本轮部件实现对照](docs/art/rifle-pipeline-v1/IMPLEMENTATION.md)
- [原枪械幻想图与 spec](docs/art/rifle-v1/SPEC.md)
- [训练场白模设计](docs/design/WHITEBOX.md)
- [原始白模阶段验证](docs/validation/whitebox-v1/README.md)

![Godot 原生 PBR 实拍](docs/validation/rifle-pipeline-v2/01-hero-pbr.png)

运行时资产：`assets/weapons/lc01/lc01.glb`。完整可编辑来源与分阶段产物：`art_source/weapons/lc01/pipeline-v2/`。最终 Blend：`07-final/lc01-final.blend`。原 B0 白模保留在上一层，v1 全部阶段及旧截图保留。

本轮实际使用 115 Tripo 积分（60 + 35 + 20），没有重抽。19,658 三角面、17 部件、四张 2K 贴图。已经打通管线，但自动网格仍有局部折面/接缝和 UV 利用率偏低等限制，不将概念图当作已达到的实机质量。

`tools/validate.sh` 检查训练场回归，`tools/validate_rifle.sh` 检查枪械、红点、场景切换及实际材质截图。二者会打开原生窗口并自动退出。构建入口与范围见 AGENTS.md。
