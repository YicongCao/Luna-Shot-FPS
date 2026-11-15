# ML03 交付清单

六资产首轮管线完成；先完成 A 全流程，再完成其他五件，整体验证后实施 ML04。

|资产|运行时 GLB（绝对路径）|三角数|实例|
|---|---|---:|---:|
|A|`/Users/cong/Documents/Projects/Luna-Shot-FPS/assets/environment/A/A.glb`|7,783|40|
|B1|`/Users/cong/Documents/Projects/Luna-Shot-FPS/assets/environment/B1/B1.glb`|13,685|6|
|B2|`/Users/cong/Documents/Projects/Luna-Shot-FPS/assets/environment/B2/B2.glb`|13,695|6|
|C|`/Users/cong/Documents/Projects/Luna-Shot-FPS/assets/environment/C/C.glb`|14,073|2|
|D|`/Users/cong/Documents/Projects/Luna-Shot-FPS/assets/environment/D/D.glb`|17,793|4|
|E|`/Users/cong/Documents/Projects/Luna-Shot-FPS/assets/environment/E/E.glb`|19,567|1|

每件目录同时包含 BaseColor、NormalGL、ORM、Emission 四张 2K 图及 provenance.json。环境 Emission 图目前为空，设施灯在运行时单独设置；LC01 能量贴图保持实际发光。

完整源文件：`/Users/cong/Documents/Projects/Luna-Shot-FPS/art_source/environment/pipeline-v1/`。各件 00-whitebox / 01-tripo-high / 02-high / 03-tripo-low / 04-low / 05-bake / 06-tripo-pbr / 07-final 分阶段保留（00-whitebox 为共享目录）。

## 验证

- 20 种子重复生成、数量与布局验证；非法布局不覆盖已有输出。
- 188 项模块检查：六资源、59 实例、六共享材质、连接、净空、单位尺度。
- 69 项无界面、81 项原生路线检查；原生运行 148.82 秒，真实玩家胶囊走外围、十字通道、支路、两组高架与桥下。
- 19/29 项枪械检查、材料室和 F3 往返。六资产正背左右、法线开关与统一材质原生对照均已保存。
- 首轮美术仍有局部生成表面起伏与少量 UV 内部重叠，未宣称达到概念图最终质量。

[实际管线数据](PIPELINE.md) · [18 次任务与 690 积分明细](CREDITS.md) · [ML03 日志](../../logs/ML03-环境模块建模.md) · [ML04 光照对照](../lighting-v1/review.html)。
