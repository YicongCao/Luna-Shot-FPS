# ML06 工业细节与使用痕迹

源目录 `art_source/industrial-wear-v1`；机匣平面修整源为 `art_source/weapons/lc01/industrial-wear-v1`。不会覆盖 ML01/ML05 原始阶段。

所有 Blender 脚本使用 Blender 5.2.2，通过 `--background --python-exit-code 1 --python` 执行。运行时文件只在检查后复制，不能把中间失败结果直接当成最终交付。

1. 已批准的单次 Tripo 任务 `f7ac912d-85a0-4356-ba2c-8e221e6dd036`：v3.1 detailed / texture=false，30 积分。源位于 `00-tripo`，`inspect_tripo.py` 生成诊断图。生成件只作为参考，片组和排线精确重建在本地完成，无自动重抽。
2. `prepare_a.py`：重建 A 高模，在六块独立闭合顶盖上加工 12 条凹槽和 24 个沉孔；复制原低模，禁止重跑低模 UV 展开。`bake_a.py`：实际 Cycles selected-to-active，2K Normal/AO/PBR。
3. `LUNA_KIT_SOURCE=1 Godot --headless --path . --script tools/industrial_wear/export_kit.gd`：导出精确附件白模。`build_kit.py`：窄倒角高低模、独立 UV。`bake_kit.py`：附件高低模细节烘焙。输出名 A.glb 是复用烘焙器的内部名称，复制到运行时为 field_kit/kit.glb。
4. `sharpen.py`：机匣/枪托指定侧面限制位移的平面拟合，逐角 UV 和面连接断言不变；不是全模型 remesh。然后设置 `LC01_PIPELINE=industrial-wear-v1` 执行 `tools/weapon_pipeline/bake.py`。
5. `wear.py -- A` / `wear.py -- LC01`：在原 UV 上按物体空间绘制确定性方向擦痕，改变底色/粗糙度。读取保存的干净源，重跑不会累计磨损。
6. 发布：A 只复制 05-wear 四张贴图（原运行时 GLB 不动）；枪械复制修整后 lc01.glb、05-bake/NormalGL.png 以及 05-wear 的 BaseColor/ORM/Emission。再执行 `pack_rifle_ao.py` 更新 ORM 的真实 AO。附件复制 Kit/04-final 中 A.glb → field_kit/kit.glb 及四张贴图。
7. Godot `--headless --editor --import --quit` 后执行 `ammo_qa.gd`、`capture.gd`、`compare_a.gd -- after`。运行 `audit.py` 检查原 UV/拓扑及下载完整性，再执行现有枪械和地图回归。

`weapon_field_kit.gd` 用独立屏幕单元驱动 20 格弹量，静态结构加载单一烘焙网格。程序化构造保留用于可复现白模导出。枪械主体与附件使用不同 atlas，避免再次打包主体 UV。

已知流程教训：不要对多层相交的已合并壳体整体做布尔运算；局部封闭部件加工后再合并。空材质槽、是否命中高模、实际面朝向必须用截图复查；UV 哈希不变只能证明布局未改，不能代替烘焙和高光检查。

8. 用户追加的 imagegen 微表面：运行 `micro_surface.py -- LC01` / `-- Kit`，在保留的修改前贴图上合成微法线、粗糙度和底色；不累计重复叠加。`micro_compare.gd` 从本地文件读取 before/after，固定相机及光照拍摄，不能把两种不同光照的图当作贴图前后对比。
