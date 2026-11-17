# ML28 — 方向光软阴影与月面候选

日期：2026-11-18。平台：macOS / Apple M6 (Apple9) / Godot 4.7.2 / Metal Forward+，原生 1920×810。

## 发布决定

- **发布方向光软阴影 HIGH 采样**：减轻地面暗部的细密斜纹，保留太阳角直径、软边、暖黄/灰金体积雾与曝光。`QUARANTINE_SHADOWS=baseline` 恢复 LOW。
- **不发布新月面为默认**：`QUARANTINE_HORIZON=refined` 仅预览候选。候选减少三角折面，但也损失崎岖山脊与中尺度地形层次，不能把“更平滑”自动当成更真实。旧月面仍默认。
- 本阶段不代表整体3A照片级目标完成，不代表用户美术验收。

[原生对照页](review.html)

## 阴影排查

`shadow-probe/` 保留八组原生诊断：baseline、no-directional、no-local、no-ssao（同时关SSIL）、no-ssr、hard、high、ultra。分别只切换相关变量。

关闭局部灯阴影、SSAO/SSIL或SSR后，斜纹仍可见；关闭方向光阴影可消除该模式，但损失设施的空间关系。硬阴影也消除采样纹理，却产生更硬、更锯齿的边界。HIGH/ULTRA减轻该模式，保留半影；选择HIGH而非更昂贵的ULTRA。

这不是地面贴图重绘，也不是取消阴影或用更浓雾遮盖。原4096方向光阴影图、太阳方向/角直径、材质、局部灯光、曝光保持。阴影边缘和地面本身的微表面纹理并非全部消失，不宣称所有锯齿/噪声已根治。

`final/shadow/` 是移除诊断残留枪械辉光后的最终LOW/HIGH同机位对照。ProjectSettings日志仍显示原默认质量2，因为实际覆盖使用RenderingServer API，没有改project.godot。诊断脚本每次先明确重置LOW，再切所选变量，避免新默认污染旧档对照。

## 月面候选与视觉取舍

`lunar_horizon.gd`：600×600m范围，2.5m索引网格，57,120顶点/113,152三角；80×80m设施开口，无碰撞。高度缓存包含一格halo，中心差分法线与切线来自实际高度。三层噪声、频率.005、lacunarity2、gain.35；最高名义频率约20个网格采样/周期。它限制噪声层数，不是严格傅里叶带限算法。

与旧版复用相同月壤底色/法线、8m UV尺度、粗糙度和色调。没有新图像生成或高低模烘焙；程序几何法线不冒充高模烘焙。

收益：远景三角高光带减轻，背景更安静，设施轮廓更突出。

损失：宽镜头左侧山脊接近连续圆坡，右侧起伏降低；孤立检查更像软丘/沙丘，不够崎岖。独立只读图片复查也建议暂缓默认推广。这是实施复查，不是用户评价。

**决定：保留候选与重现入口，但保持旧默认。下一次应保留旧山体大轮廓，单独解决欠采样/法线，而非继续压低整个地形频谱。**

### 诊断纠偏

- `terrain/` 首轮检查机位受近处坡面/围界遮挡，不能凭成功写图即认定视图合格。
- `terrain-clearance/` 提高检查相机，新增“同时高于两版表面5m以上”和实际相机朝向/位置断言；外侧检查改为65m高度，仍可见残留青色辉光。
- 原因是隐藏Player/WeaponLayer不会关闭world拥有的独立weapon_bloom合成层。仅在诊断里显式关闭该层；正常玩法和世界Bloom不变。
- `shadow-clean/` 是第一次不完整的隐藏尝试；仍有残留，不作为最终干净对照。
- `final/terrain/` 为最终双版本五机位，青色残留已消失。左右外侧视图开启背面剔除，所见坡面连续，没有首轮的大块近景遮挡。65m机位暴露了有限600m场景边缘和设施开口，**不是可玩视角或照片级景观证据**。总览是场内视角，东西与外侧检查是诊断高机位。

## 验证

已执行各组成命令与完整benchmark验证脚本；新增`tools/validate_lunar_horizon.sh`将几何、双版本捕获和完整回归串联，shell语法检查通过，本轮证据由等价分项命令生成，并非声称额外运行过整条新包装脚本。

| 范围 | 结果 | 证据 |
|---|---|---|
| 候选几何 | 29/29；最小面/顶点法线点积0.98885；拓扑、切线、确定性、无碰撞 | geometry-final.log |
| 双版本最终捕获 | 每版19/19；保存、渲染设置、相机净空/姿态 | final/terrain/*/result.json |
| 任务/物理 | 49/49 | validation/regression/gameplay-qa.log |
| 原训练场 | 69/69 | validation/regression/training-regression/headless.json |
| 布局 | 20种子，确定性与非法布局保护 | validation/regression/layout-regression.log |
| 原生任务镜头 | 6/6 | validation/regression/native/checks.json |
| HUD/终端/电击反馈 | 24/24 | validation/feedback/checks.json |
| 完整实机演示 | 12/12 | validation/native/result.json |
| 重播/实玩/移动/暂停及镜头与渲染档衔接 | 20/20 | validation/controls.json |
| 实际启动器无截图运行 | 三次各12/12 | 下表对应result.json |

原生人工查看范围包括最终阴影同机位、候选左右外侧剔除、宽镜头、正常ADS。几何/捕获断言不代替视觉判断。全目录日志经共享fail-closed扫描，无脚本/解析/门禁错误；**原有7个Texture RID退出警告仍存在**，未定位根因。

## 性能成本

以下均使用实际`launch-benchmark.command -- --benchmark-qa`，无截图写入、不含4秒预热、VSync0，原月面与其他默认效果相同。按运行顺序列出，不与含截图运行混用。

| 采样 | 平均FPS | P95 ms | P99 ms | 帧数 / 实测秒 | 证据 |
|---|---:|---:|---:|---|---|
| HIGH 首次 | 114.510 | 10.847 | 11.391 | 5440 / 47.506946 | validation/performance/result.json |
| LOW 旧档 | 134.128 | 9.061 | 9.499 | 6372 / 47.506892 | baseline-performance/result.json |
| HIGH 复测 | 117.489 | 10.427 | 10.936 | 5581 / 47.502446 | high-performance-repeat/result.json |

高采样在这组运行中平均FPS降低约12–15%，有明确质量成本，不是性能优化。窗口/系统合成器状态与温度未严格控制，不能外推所有机器或长期稳定帧率。月面候选未做完整无截图性能测量，不能拿默认旧月面的这些结果当作候选预算通过。

## 复现

```sh
# 默认旧月面 + HIGH阴影
./launch-benchmark.command
# 只恢复旧阴影
QUARANTINE_SHADOWS=baseline ./launch-benchmark.command
# 候选月面，不改变默认发布决策
QUARANTINE_HORIZON=refined ./launch-quarantine.command
# 重跑到新目录，避免覆盖本次证据
LUNAR_HORIZON_OUTPUT=docs/validation/lunar-horizon-v1/recheck ./tools/validate_lunar_horizon.sh
```

## 保护范围与未完成项

原Compatibility训练场、生成器/布局、共享环境及ML21枪械资产不变；无Tripo、混元或imagegen新调用。任务、真实命中伤害与终端/撤离契约不变。演示仍有镜头/敌人编排、九发真实射击击杀三只、五只切镜清除，不是无人干预通关。

模块重复、原远景棱角、害虫非IK步态和整体照片级艺术质量仍开放；本阶段只发布经验证的阴影改进，并保留没有获得明确视觉收益的地形候选。
