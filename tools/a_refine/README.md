# A 配电机组概念精修

纯本地可复现修整，不提交 Tripo 任务。几何、源材质、尺寸均在 build.py 中；Blender 原文件与原始 ML03 管线另行保留。

按顺序使用 Blender `--background --python-exit-code 1 --python` 执行：

1. `build.py`：高/低模分别生成；低模固定三角化、清除零面积三角、展开 UV。4×4 m 规划占地内，实际外包络不超过原 3.8×3.8×1.2 m。
2. `inspect.py`：UV 越界与退化检查、离线结构预览（不是实机）。
3. `bake.py`：真实 selected-to-active NormalGL / AO / Roughness；BaseColor 经 emission 通道投射以避免金属漫反射衰减；独立金属度和指示条 Emission 投射；拼装 ORM，导出单网格单材质。
4. `audit.py`：2K UV 严格内部重叠、覆盖率、尺寸、面数与烘焙来源审计。
5. 将 `art_source/environment/A-refine-v2/04-final/` 中 GLB、四张 PNG 与 provenance.json 复制到 `assets/environment/A/`，Godot editor --import。
6. 原生 `--script tools/a_refine/compare.gd -- after` 输出同机位四侧/顶部、法线关闭、恒定材质、3/10/20 m 独立视距、关卡近景与总览。

旧版运行时完整副本在 `00-baseline`；before 图片已固定，不要用新版覆盖。关卡近景 range-3m 为距实例中心 3 m，约距前面板 1.2 m；distance-3m/10m/20m 为独立观察场景距前面板的距离。before/discarded-outside-range 是首次选点越出关卡的弃用图片，不用于比较。

改几何、法线或 UV 后必须重新烘焙。修改后执行 `LUNA_QA_OUTPUT=docs/validation/A-refine-v2/map tools/validate.sh`；共享材质或枪械相关更改另执行枪械回归，不能用离线预览代替 Godot 背面剔除和通行检查。
