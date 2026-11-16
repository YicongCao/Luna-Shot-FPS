# ML15 最终交付与验证

Godot 4.7.2 Compatibility / macOS Apple M5。技术检查通过；实施视觉复查通过并保留以下限制；用户实机美术验收待确认。概念方向认可不等于本次实机验收。

B1 → B2 → C → D → E 均完成 Tripo 参考、精确高模、受控低模/UV、独立 cage、4K 分组烘焙、2K 运行时分层 PBR，已进入默认关卡。未改 A、ML06 枪械、ML14 风扇源代码或布局。

| 模块 | 低模三角/预算 | 高模三角 | 配对组数 |
|---|---:|---:|---:|
| B1 | 13,460/20,000 | 51,316 | 9 |
| B2 | 8,708/20,000 | 32,748 | 5 |
| C | 7,520/12,000 | 27,920 | 3 |
| D | 11,528/16,000 | 42,152 | 3 |
| E | 10,336/24,000 | 39,392 | 4 |

B2 原有风扇附件另计 15,588 三角/塔，6 塔共 18 个旋转叶轮；灯罩、底座和动态警灯独立共享。静态主体预算没有隐瞒附件成本。

## 灯光和地面

48 盏四角红灯每 2 秒闪一次、单塔同步、塔间固定错相；32 段内嵌蓝灯常亮；橙灯每秒旋转一圈并短闪，实际 Spot 随旋转亮区扫亮塔顶。灯罩、真实局部照明、Bloom 分开验证。局部灯池有 8 个槽，最多同时开启 2 个 Omni 和 1 个 Spot；远处灯罩仍可见。暂停冻结动态相位；F7 控制 Bloom，F8 光晕，F9 实际补光。

新增 48 段道路边缘黄漆，射击线同材质。非金属/不发光，独立粗糙度和小尺度磨损；同镜头关闭 specular 的对照证明高光来自真实反射响应，关闭照明后采样点为黑色。保留反射探针，不制造镜面地板。132 根原地面网格线以同几何/材质批处理降低绘制开销。

## 验证与性能

- [map/headless.json](map/headless.json)：通过（69 条检查）。
- [map/native.json](map/native.json)：通过（81 条检查）。
- [rifle/rifle-headless.json](rifle/rifle-headless.json)：通过（19 条检查）。
- [rifle/rifle-native.json](rifle/rifle-native.json)：通过（29 条检查）。
- [rifle/scene-switch.json](rifle/scene-switch.json)：通过（0 条检查）。
- [lighting-v1/native.json](lighting-v1/native.json)：通过（14 条检查）。
- [b2-cooling-fans/native.json](b2-cooling-fans/native.json)：通过（100 条检查）。
- [knockdown-targets/macOS.json](knockdown-targets/macOS.json)：通过（24 条检查）。
- [markings/checks.json](markings/checks.json)：通过（5 条检查）。
- [lamps.json](lamps.json)：通过（158 条检查）。

近设施同路线：预热后各采集 60 秒、1600×1000、默认 VSync。旧版 P95 9.728 ms，新版 9.958 ms，变化 +2.36%，低于 +10% 门槛。蓝色补光激活 4497 帧，橙色 Spot 激活 4949 帧；这是相机压力路线，真实胶囊通行另由 map 回归验证。

末帧绘制对象 1014→506，三角/图元计数 1,629,970→1,733,404；纹理内存 840.5→787.2 MiB。这些是同镜头渲染计数，包含多遍绘制，不等于资产文件三角预算。静态主体各 1 个导出 surface/atlas；灯具/风扇材质另计。

## 来源、费用与限制

本轮 Tripo 5 次，共 300/400 积分，0 重抽；usage.json 已与工具账单核对。概念阶段 imagegen 6 次，工具未返回货币金额；本实施阶段没有新增 imagegen 调用。历史 690 积分独立保留。

源文件：`art_source/environment/refine-v2/{B1,B2,C,D,E}`；每件 `02-geometry/paired.blend` 保存高模、三角化低模和 cage，`03-bake/body` 保存分层材质源、辅助图及烘焙契约。运行时 `assets/environment/{B1,B2,C,D,E}`；入口 `tools/environment_refine/run.py`。

原始参考 GLB（普通路径，供下载/建模使用）：
- `/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/environment/refine-v2/B1/01-tripo/model.glb`
- `/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/environment/refine-v2/B2/01-tripo/model.glb`
- `/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/environment/refine-v2/C/01-tripo/model.glb`
- `/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/environment/refine-v2/D/01-tripo/model.glb`
- `/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/environment/refine-v2/E/01-tripo/model.glb`

保留的限制：地面主体、围界和靶仍属原型基础设施；本轮未增加内部空间或新的建筑类别。B2 外侧鳍片仍有较大平面，远距离螺钉/微划痕不能逐个分辨；没有宣称像素级复刻概念。旋转警灯只有结构受光与镜头效果，没有真空中的空气光锥。低角度月球日照形成深阴影，最终美术偏好仍待用户实机确认。

性能、截图和视频均来自原生 Godot；MovieMaker 固定 60fps 视频只证明动画，不用于帧时间验收。静态 HTML 对照页已检查链接，未宣称浏览器交互验收。失败尝试保留在各模块诊断目录；后续不要把技术通过改写为用户美术接受。
