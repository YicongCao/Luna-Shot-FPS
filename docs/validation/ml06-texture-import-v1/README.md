# ML06 枪械贴图导入对照

本次只修改 ML06 枪械主体与 field kit 的 8 张运行时贴图导入参数，PNG 像素、模型、UV、材质参数均未改变。BaseColor、ORM、NormalGL、Emission 开启 mipmap；两张 NormalGL 额外按法线贴图导入。

平台：macOS，Godot 4.7.2 stable，原生窗口。修改前后都显式使用 `--weapon-revision=ml06` 运行 `--rifle-qa` 与 `weapon_lab --lab-qa`，两次均为 0 失败。修改后新增的 8 项 mipmap 检查全部通过。

## 结果

| 视角 | 枪械区域拉普拉斯高频均值 | 变化 |
|---|---:|---:|
| 11 第一人称腰射 | 25.65 → 25.61 | -0.2% |
| 09 材质近景 | 18.04 → 17.98 | -0.3% |
| 01 展示主视角 | 32.83 → 30.70 | -6.5% |
| 07 侧视 | 29.41 → 27.19 | -7.5% |
| 08 反向视角 | 34.98 → 31.45 | -10.1% |

结论：mipmap 修正了较远或缩小显示时的高频噪点，属于应保留的导入修正。但实际第一人称腰射和近景下几乎无差异，因此当前看到的破碎、偏软感主要来自贴图内容本身与有效像素密度。ML06 主体 UV 覆盖率约 22.5%，2K 图集的有效像素量约相当于 970² 的满铺贴图；碎 UV 岛和原烘焙/磨损细节也会在近景中形成碎块。

整张腰射截图中环境阴影前后存在时序差异，不能用全图差异判断枪械；判断以枪械裁切图为准。本结果不是用户美术验收。

## 证据

- [腰射枪械放大](crop-11-range-hip.png)、[材质近景](crop-09-surface-close.png)、[反向视角](crop-08-reverse.png)
- [展示主视角](crop-01-hero-pbr.png)、[侧视](crop-07-side.png)
- 原始截图：[before](before/)、[after](after/)；枪械指标：[weapon-metrics.json](weapon-metrics.json)
- `compare-*.png` 与 [metrics.json](metrics.json) 是整图对照，受环境阴影时序影响，只用于定位，不作为枪械贴图结论。
