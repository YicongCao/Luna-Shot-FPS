# ML33 · 暗处先辨肩，不给整只敌人描边

[同机位原生三版图集](review.html) · [腰射原图](ceramic/hound/03-hip-scale.webp) · [动作和弹着检查](default-checks/headless.json)

检查的问题是：在暖雾厂房的地面阴影里，玩家已经能看到橙眼，能否看清**眼睛下面的躯干**？不是要让目标穿墙可见、增加伤害、降低环境对比或者证明画质达到了 3A。三版保持相同的曝光、现有灯光、体积雾、碰撞、机位及动作。未调用 Tripo、imagegen 或其他外部服务。

- **ML32 / baseline**：深色肩甲接近地面亮度。5.59 m 腰射时眼睛与腿间缺一块可识别的表面。
- **检修灯 / lit**：每侧三条逐渐变短的发光嵌件安装在护板原有金属轨上，随护板动，使用本机体的核心电源材质。侧面近看能数清三片板，但接近正面的腰射镜头只剩小亮点。这些灯没有解决普通距离的主要问题，**不设为默认**。
- **浅色肩甲 / ceramic（默认）**：只改变靠近头部的一对护板的涂层，不改几何或光源。正面腰射时能辨别头下的两块肩面；逆光侧拍的肩也和后躯分开。代价是原版从肩到背的一体深色被打断，后腿和腰线在暗地面上仍不清晰。没有把这些观察推广为所有距离、机位或光照下的效果。

Godot 4.7.2 / Apple M6 / Metal Forward+。九种相同时刻每版各一张原生图；`off`、`lit`、`ceramic` 的 `hound/frames.json` 逐帧相同（包括相机、FOV、姿态、弹药与 HP）。每版 17 项脚本化捕获检查；只有灰模图带诊断补光，腰射/巡逻/实际命中图没有。默认版本通过 33 项动作与实射检查；另有 3 项装配检查确认只有两片肩甲换材质，只有灯条候选有 6 个带电嵌件，肩甲烧痕未污染其他个体。真实启动器另跑一次 1920×810 演示，结果见 [launcher/result.json](launcher/result.json)。不是无人通关，没有测定本次改动的独立 GPU 成本。历史退出时 Texture RID 警告仍在。

复现：在项目根目录设 `QUARANTINE_BUG_STYLE=hound`，用 `QUARANTINE_HOUND_FINISH=baseline|lit|ceramic` 分别运行 `launch-quarantine.command`（三选一；不设置 finish 就是 ceramic）。测试调用见 `tools/quarantine/capture_hound.gd` 文件头；分别指定新的 `HOUND_VIEWS` 根目录，避免覆盖历史证据。`godot --headless --path . --script tools/quarantine/test_hound_finish.gd` 检查实际资源。美术验收保留给用户。
