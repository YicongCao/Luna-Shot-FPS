# ML29 — 保形月面与局部网格细分

日期：2026-11-18。macOS / Apple M6 (Apple9) / Godot 4.7.2 / Metal Forward+ / 原生1920×810。

[原生同机位对照](review.html)

## 发布内容

清剿与Benchmark默认使用 `lunar_ridges.gd` 的保形月面；`QUARANTINE_HORIZON=baseline` 回旧5m版本，`=refined` 仍为ML28未发布的低频平滑候选，`=ridges` 显式选择本版。

本版保留旧山体的种子221117、基础频率.011、gain .5、前三层噪声的相对位置与振幅，仅移除最细两层。FastNoiseLite会随层数改变归一化，因此乘以 `(1+.5+.25)/(1+.5+.25+.125+.0625)=28/31`，避免剩余山体被放大。不是沿用ML28的.005低频方案。

基础网格1.25m，对法线/实际三角面偏差较大的局部细分。最终350,382顶点、698,391三角，上限700,000。材质、贴图、8m UV尺度、暖雾、曝光、HIGH方向光阴影保持；不修改设施、碰撞或玩家路线。

## 视觉收益与损失

原生总览：旧山脊的主要位置与层次保留，左侧三角形高光折线减轻，不再像ML28候选一样变成连续缓坡。两侧外表面检查保留多个中尺度峰谷、没有通过关闭背面剔除来掩盖面向问题。

损失：最细两层噪声的碎峰被去掉，局部最高点可能降低；增加大量几何与CPU首次生成成本。外侧高机位仍看得出程序噪声地形及600m有限边界，不等同于具有侵蚀/撞击地质细节的照片级月面。

这是限定范围的实施视觉改进，**不是整体AAA照片级完成或用户美术验收**。设施模块重复、非IK害虫步态及整体材质艺术性仍是其他工作，不由地形测试替代。

## 保形量化（不是像素验收）

`test_horizon_shape.gd`：600m方形内、70m半径外每3m采样，共38,692点；另从设施中心按360个方位、70–300m距离采样上轮廓。

| 相对原版 | ML28平滑候选 | ML29保形版 |
|---|---:|---:|
| 高度RMSE | 16.101m | 1.269m |
| 最大高度差 | 52.091m | 4.180m |
| 径向轮廓角度RMSE | 2.979° | 0.377° |
| 最大轮廓角度差 | 7.383° | 1.053° |

7项保形检查通过，数据见 `shape.json`。这些指标衡量形状保留，不能证明美术质量；原生画面独立检查。

## 局部细分与失败记录

1. 1.25m均匀网格保留山形，但最差面/顶点法线点积仅0.91220，未通过原有0.98门禁；保留 `geometry-ridges.log` 和 `first-native/`。
2. `terrain_refinement.gd` 收集需要细分的共享边。相邻三角形即使没有请求细分，也使用同一个边中点，避免T形裂缝；新点高度仍来自同一高度函数，不抹平峰谷。
3. 初次固定对角线会传播细长三角形。两条边细分时，改用剩余四边形的较短对角线；继续迭代处理被相邻细分影响的新三角形。
4. 五轮、十轮未完全通过，日志分别保留；最终最多24轮，最差点积0.98499，0.98门禁没有放宽。实际退化面判断改为正面积且平方长度大于1e-12，因为合法局部小三角形不能沿用5m网格的固定面积下限；同时新增总投影面积守恒检查，防止漏片/重叠被掩盖。
5. 最终投影面积353,600m²，边界只在外缘与80×80m设施开口；所有顶点引用、共享边流形、顶点位置唯一、法线/切线、重复生成一致性检查通过。

生成器共用 `lunar_horizon.gd` 的参数化网格/材质入口，ML28原参数保持。高度/法线来自程序函数；沿用的微法线是旧月壤贴图，**没有声称新增高模投射烘焙**。

## 验证结果

| 范围 | 通过 | 证据 |
|---|---:|---|
| ML29几何、面积、缓存 | 31/31 | final-geometry/ridges-release.log |
| ML28原候选生成回归 | 30/30 | final-geometry/refined.log |
| 原山形保留 | 7/7 | shape.json |
| 原生五机位捕获/相机净空/姿态 | 19/19 | adaptive-native/result.json |
| 清剿任务/物理 | 49/49 | validation/regression/gameplay-qa.log |
| 原训练场 | 69/69 | validation/regression/training-regression/headless.json |
| 布局 | 20种子 | validation/regression/layout-regression.log |
| 任务原生检查 | 6/6 | validation/regression/native/checks.json |
| HUD/终端/电击反馈 | 24/24 | validation/feedback/checks.json |
| 完整实时演示 | 12/12 | validation/native/result.json |
| 重播/进入实玩/移动/暂停、镜头和渲染档衔接 | 20/20 | validation/controls.json |

已检查最终宽镜头与左右外表面原生像素。外侧65m相机是诊断，不是玩家视角。最终日志通过共享fail-closed扫描；故意保留的前期失败日志不作为通过证据。原有7个Texture RID退出警告仍存在，未声称根因已解决。

## 性能与生成成本

实际 `launch-benchmark.command -- --benchmark-qa`，无截图写入、VSync0、剔除4秒预热，HIGH方向光采样与其他效果相同：

| 地形 | 平均FPS | P95 ms | P99 ms | 帧数 / 秒 | 证据 |
|---|---:|---:|---:|---|---|
| ML29首轮 | 103.009 | 11.588 | 12.103 | 4895 / 47.520044 | validation/performance/result.json |
| 原版同条件对照 | 120.005 | 10.264 | 10.749 | 5700 / 47.497940 | performance-baseline/result.json |
| ML29复测 | 103.183 | 11.622 | 12.039 | 4902 / 47.508022 | performance-ridges/result.json |

本组运行增加几何后平均FPS下降约14%，不是性能优化；仍高于60FPS只是当前M6运行结果。窗口/合成器/温度未严格锁定，不外推其他平台或长期稳定性能。

此外，程序细分有首次CPU成本。包含两次完整构建、拓扑审计和确定性比较的headless检查约13.24秒；这不是单次加载耗时，也没有包含在上述演示帧率内。运行时保留静态生成网格，重播和正常实玩切换复用；几何缓存身份检查与真实R/Enter切换均通过。未把预热后FPS冒充冷启动表现。

## 复现与保护范围

```sh
./launch-benchmark.command
QUARANTINE_HORIZON=baseline ./launch-benchmark.command
QUARANTINE_HORIZON=refined ./launch-benchmark.command
LUNAR_RIDGES_OUTPUT=docs/validation/lunar-ridges-v1/recheck ./tools/validate_lunar_ridges.sh
```

本轮执行了各几何/形状/捕获组成命令与完整benchmark包装脚本；新的总包装脚本通过shell语法检查，未额外重复整条执行。

无Tripo、混元或imagegen新调用。原Compatibility训练场、共享环境/ML21枪械、布局生成器不变。实时演示仍为编排镜头，九发真实射击击杀三只、五只切镜清除，使用真实E与胶囊撤离；不是无人干预通关。
