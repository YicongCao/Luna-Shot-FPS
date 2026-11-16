# ML04 原生证据

[打开同机位对照](review.html)。全部截图来自 Godot 4.7.2 macOS / Apple M5 / Compatibility；imagegen 只提供运行时光学纹理，不作为场景实拍。

- `native.json` / `pixel-comparison.json`：运行检查、短程实际渲染帧时间与图像差异。
- `00`–`04`：依次开启 Emission、局部灯、Bloom、镜头光晕；`03a` 只开启枪械 Bloom。
- `20`–`22`：设施灯无 Bloom / Bloom / 加镜头光晕。
- `30`–`33`：太阳正对、遮挡、侧视、背对。
- `40`–`42`：桥下、总览、超宽。
- `50`–`52`：固定姿势下的腰射强度、开镜强度、关闭光晕，用实际像素测量衰减比例。
- `weapon-bloom-pass.png`：真实枪械画面的高亮模糊缓冲，可与 `weapon-no-bloom-rgba.png` 比较轮廓外贡献。
- `rifle/`：最终枪械、红点、材质室与 F3 回归；`map/`：光照接入后的无界面训练回归。
- `native-alpha-clipping/`：原生透明视口 Bloom 轮廓外贡献为零的失败记录。
- `first-additive-pass/`：早期测试记录；其中设施灯淡出检查曾因按帧等待不足而失败，现改为实际时间；旧枪械断言依赖原生 Glow 参数，现改查真实独立 Bloom 通路，并以像素验证补足。

性能为每模式 600 个渲染帧的短程比较，不代表长时间压力或跨设备验收。详见 [ML04 日志](../../logs/ML04-光照与镜头效果.md)。
