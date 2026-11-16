# ML15 B1 样板验收

macOS Apple M5 / Godot 4.7.2 Compatibility 原生1280×900；性能1600×1000。技术与实施视觉复查通过，用户实机验收待定。

收益：旧塔的实心白块改为六层有真实间隙的散热芯、象牙白层框、银色弯管、黄色接头及独立检修柜。保留4×4×6 m包络、固定碰撞、地图位置与A/枪械。

保形检查：前后左右灰模和材质图；六层分隔、细鳍片空隙、底座和挂点可辨。红灯并非靠Bloom假造邻面受光。原生截图见candidate目录，基线见baseline目录。正常20 m距离细螺钉不再逐颗可辨，这是距离与采样限制。

证据：audit.json、candidate/checks.json、lamp-checks.json（如有）、performance-comparison.json、map、rifle、lighting-v1、knockdown-targets。全枪保留ML06，未修改其模型或贴图。

失败过程见rejected。B1低模12,884三角/9对烘焙组，4K源→2K运行。Tripo参考任务60积分，详见art_source/environment/refine-v2/usage.json。

60秒P95 +0.30%通过相对10%门槛。旧600帧光照专项16.974ms未达到16.7ms提示目标，功能项通过；报告保留原始数值。
