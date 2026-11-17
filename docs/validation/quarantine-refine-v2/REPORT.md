# ML23 — 工业结构与材质精修

日期：2026-11-17。平台：macOS / Apple M6 (Apple9) / Godot 4.7.2 / Metal Forward+，原生截图 1920×810。

## 本轮范围

只修改独立 Quarantine 关卡实例。原训练场、布局生成器、A/B1/B2/C/D/E 运行时资源和 ML21 枪械几何/贴图保持。

- 程序结构使用真实倒角网格，保留 MultiMesh；倒角区顶点色是几何代理，不叫烘焙曲率。
- 北立面增加分缝面板、通风片、固定件、安装管线、实体门框/门叶/门锁；封闭门有对应碰撞。
- 终端增加底脚、握把、线束、制造标识及带实体支架的工作灯。
- 涂装金属使用历史 imagegen 磨损遮罩与程序粗糙度。地面降低统一金属/湿亮响应。
- 枪械视口改用关卡天空与明确的颜色环境光，而不是原独立摄影棚天空；保留透明视口独立 Bloom，未重开裁剪 alpha 的原生 Glow。
- 去掉没有可见灯具的补光源光晕，只保留太阳与两个有实体灯槽的北侧光源；灯光色温更克制。
- 场外地形同位置使用一致高度梯度法线并索引共享顶点；没有修改任何现有烘焙资源。新程序几何和高度梯度着色不冒充高模投射烘焙。

## 来源与成本

新增 Tripo 调用 **0**，新增 imagegen 调用 **0**。`assets/quarantine/refine/wear_mask.png` 复制自项目历史：

`art_source/weapons/lc01/ls01-refine-v1/01-imagegen/wear.png`

两份 SHA256 均为 `b296ea6f2514f400005e6c9a176a03b03cd522823852ac227a33465a5936517d`。运行时 GPU 压缩、mipmap、各向异性过滤已配置。程序微起伏不是新 imagegen 产物。

## 验证

- 导入无 SCRIPT ERROR / Parse Error。
- 任务逻辑/物理：44 项，0 失败。
- 原训练场 headless：69 项，0 失败。
- 布局生成：20 个种子及非法参数回归通过。
- 原生射击/终端/撤离：6 项，0 失败。
- 精修专项：8 项，0 失败，包括每个三角形的顺时针外表面、每顶点外法线、实体门射线碰撞、光晕源限制与地形索引。
- `geometry/{front,back,left,right}.png` 是启用背面剔除的原生灰模实拍；左右图已人工观察，无外侧消失。不是只凭面数/有符号体积判定朝向。

复现：

```sh
QUARANTINE_QA_OUTPUT=docs/validation/quarantine-refine-v2 ./tools/validate_quarantine.sh --performance
~/Applications/Godot.app/Contents/MacOS/Godot --path . --rendering-method forward_plus --resolution 1920x810 --script tools/quarantine/test_refinement.gd -- --quarantine-qa
```

历史 ML22 的原生证据没有覆盖；本轮初稿保存在 `first-pass/`。采集与录制入口现在支持输出目录覆盖，避免新阶段覆写旧阶段。

## 性能边界

默认窗口模式 60 秒路线：59.94 FPS，P95 17.633 ms，P99 18.558 ms，261.23 m 胶囊移动、11 个路点、119 次开火请求。最后一帧 1,732 draw calls、3,508,592 primitives。详见 `performance/native.json`。

相比 ML22 记录，新增细节和灯光的渲染计数增加；这次帧率接近 60，不把它直接解释成固定比例 GPU 性能退化，也不隐去增加的渲染成本。明确关闭 VSync 的复测单独存档，不能与不同窗口/同步条件的旧结果直接排名。`performance-uncapped/native.json` 记录 60.05 FPS、P95 18.380 ms、P99 19.602 ms、299.79 m/12 路点；本机窗口呈现仍接近 60 FPS，不宣称已测得 GPU 极限。

## 同机位收益与损失

- 收益：终端背景由露出山体的矩形洞口变成可辨认的工业门；面板、固定件和管线建立装配层次，灯具与光照来源更一致。
- 收益：地面湿亮感降低，橙色发光线不再大范围淹没立面，枪械反射来源更接近场景。
- 损失/开放项：北侧立面暗部仍偏弱；弱化发光后部分大字标识不如旧版醒目。增加的结构是程序化装配，不能据此宣称 AAA 照片级。
- T-Bug 形体、山体轮廓、局部材料丰富度与整体戏剧性仍有差距；用户视觉验收 pending。
- Forward+/Metal 退出仍出现 7 个 Texture RID 警告，原始日志保留，根因尚未定位。此处不把退出警告直接认定为持续运行泄漏。
