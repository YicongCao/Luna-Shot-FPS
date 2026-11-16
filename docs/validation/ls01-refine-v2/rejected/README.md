# 已排除的中间证据

- incomplete-*：附件烘焙未完成时的打包/预览失败；最终两套atlas完成后重做，未启用默认。
- old-qa-assumptions.log：旧脚本写死15网格/2灯；ML09为13网格/4灯，后续同时修正真实所选贴图路径检查。
- shadow-bias/：过小偏移产生阴影条纹的首轮截图；后续调整偏移和能量再检查真实遮挡。
- pre-normal-fix/：custom normals修正前图与被中止的性能试跑；不用于最终性能结论。有效八轮数据位于上一级。
- edge-probe-spill-pixels.json：护罩采样误落在支撑肋自由边缘的失败值；最终点位改到真实内支撑表面，原阈值保留。
