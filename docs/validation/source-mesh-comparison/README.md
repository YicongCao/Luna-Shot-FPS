# 枪械与B2：源网格和原始PBR对照

2026-11-16。用户要求查看Tripo原始高密度网格、本地高低模及实际PBR贴图。入口review.html；本次从真实源文件重新渲染24张几何检查图，生成三组对照板、五套材质通道板和可点击原始文件的图库。没有AI重绘，没有修改模型或游戏默认资源，无新增付费任务。

## 阅读边界

所有灰模图片是Blender 5.2.2 Workbench离线检查，**不是Godot实机**。相同资产各阶段共用相机、正交尺寸、工作室光照和灰色材质；不加载PBR/烘焙法线，不做Cavity强化。没有改变原有平滑/顶点法线。三分之四、侧面和局部机位均可切换。

原始Tripo只按统一单位等比缩放、旋转和平移，未清理、删件或镜像；枪械按原prepare_high.py的坐标变换，B2按6m高归一、绕Z轴-90°对齐中央管路面。本地B2静态源主体高约5.86m，灯具另装；保留原始候选的比例差异，不按三轴强制拉伸到一致。

- **枪械ML06**：当前默认来源。高模是保留/修整Tripo密集几何，并非整件重新构造；低模来自原远端重拓扑与本地修复。主体对照统一排除后加field kit。原始高模包含一个27三角微小残片，后续被删除。
- **枪械ML07**：局部重建、已回滚分支。使用paired.blend内body组的high或low，加相同11个保留低模作装配参照。高模列因此不是全枪所有部件的高模。没有加载kit组、动态屏幕或导出阶段新增的前罩螺钉副本，避免把附件差异当主体差异。
- **B2 ML15**：只渲染本地静态源主体。游戏中的独立ML14风扇与设施灯具不在这两份高/低源对象中；原始Tripo上的安装位/灯柱则完整保留。因此不能据图中没有风扇叶轮推断游戏未实现风扇。

几何图不显示高模材质Bump，也不加载低模NormalGL，低模显得圆润不代表实机法线效果。图片用于比较轮廓/镂空/装配；PBR视觉应参考既有Godot证据。

## 贴图含义与来源

五套图：B2的4K烘焙母版；ML07枪械body/kit的4K烘焙母版；当前ML06枪械body/field kit实际原文件。ML15与ML07的ORM来自2K运行打包；ML06的AO/Roughness/Metallic预览从原ORM的R/G/B抽取，没有伪造独立源文件。每张图记录实际尺寸及原路径于textures.json，图库可直接打开原图。

BaseColor是颜色；NormalGL是切线法线；Roughness越亮越粗糙；Metallic越亮越偏金属；AO越暗表示更多遮蔽；ORM的RGB分别存AO、Roughness、Metallic，因此其彩色外观不是物体本色。涂漆区域金属度接近黑色可以是正确设计。UV空区不代表表面有黑色孔洞。

预览仅缩小/提取通道，没有重绘、重新打光或自动对比度拉伸。ML07 oil/wear imagegen输入另列，不能与完整PBR或B2材质混淆。ML07未重建零件继续使用retained atlas；本页以本次重建body/kit与当前ML06主atlas展示主要差别，不宣称单张贴图覆盖整枪。

## 验证与复现

- tools/source_comparison/render.py：Blender --background --python-exit-code 1 --python tools/source_comparison/render.py -- --stage b2-tripo（或b2-high/b2-low/gun-tripo/gun-ml06-high/gun-ml06-low/gun-ml07-high/gun-ml07-low）。只读源，不保存回blend。
- tools/source_comparison/report.py：uv run --with pillow python tools/source_comparison/report.py。合成有标注的对照板并生成静态HTML。
- 各阶段JSON保存来源、变换说明、所示面数、机位与保留参照部件名单。check.json记录24张图、共用机位、来源链接及贴图清单检查。
- 已目视检查主对照板及PBR板。HTML图源/链接静态检查通过，未宣称浏览器交互实测。本次无运行时变化，未重复游戏回归或性能测试。

观察：ML06主体高模明显继承Tripo装配特征；ML07机匣/枪托/弹夹的简化已发生在其重建高模阶段。B2同样在本地高模阶段减少了底脚、接头和框架连接层次。不能将这些变化归因为低模减面或贴图分辨率不足；本图不构成对所有生成部件可直接生产的质量认证。
