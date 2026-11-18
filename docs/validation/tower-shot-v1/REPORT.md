# ML34 · 上电后给反应塔一个完整远景

[并排看开头、中段和末尾](review.html) · [实际启动器画面](live/06.png) · [相机测量](checks.json)

之前的实时演示在终端解锁后靠近塔脚拍摄：机柜占了画面右侧，蓝色能量柱一直伸出画面。保留这条旧路线作为 `QUARANTINE_TOWER_SHOT=baseline ./launch-benchmark.command`。新版只改演示 39–49 秒这一镜，镜头在东侧屋顶上方升高、侧移；左侧是南门和撤离圈，中央是点亮的塔，背后是天际线。没有加灯、改雾、调高能量亮度、移动资产或改变实玩相机，没有新增 Tripo/imagegen 调用。

**收益与取舍：** 全塔能在一帧内和设施形成尺度对照，能量柱顶部有空间淡出，横向运动令近处屋架与远山有不同的位移。旧版贴近设备时绕组和局部表面更大、更好辨认。新版既不改善原材质的细节，也没有消除远景里相似机柜的重复。这是镜头取舍，不是整场游戏照片级验收。

**验证：** Godot 4.7.2 / Metal Forward+，1920×810。在同一上电状态比较两个机位，沿各自十秒路线等间距取 101 个位置，投影塔脚中心和能量柱顶中心（世界 y=0、23）；两点到最近画边的归一化最小距离，旧镜头 −0.260，新镜头 +0.075。这个数字只检查取景，不证明前面没有遮挡；另看 0.5、5.0、9.5 秒的六张原生图和完整演示。第一版朝向低角度太阳，屋架横穿塔身，留边亦不够；第二版改为侧光，仍有越界。早期诊断还把玩家留在撤离区，可能过早暂停上电，不能拿早期帧对比亮度。最终诊断隔离撤离判定，并检查场景未暂停、着色器 power 已达到 1。诊断场景跳到上电状态；真实启动器另外按原流程开火、按 E 并撤离，不能称为无编排通关。截图运行不用于推断性能变化。

复现：`TOWER_SHOT_OUTPUT=/tmp/luna-tower-review godot --path . --rendering-method forward_plus --resolution 1920x810 --fixed-fps 60 --script tools/quarantine/test_tower_shot.gd -- --quarantine-qa`。完整演示：`QUARANTINE_BENCHMARK_OUTPUT=/tmp/luna-tower-reel ./launch-benchmark.command -- --benchmark-qa --benchmark-capture`。历史退出时 Texture RID 警告仍在。
