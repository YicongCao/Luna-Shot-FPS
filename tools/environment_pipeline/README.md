# 环境资产管线

六资产 A/B1/B2/C/D/E，米制，Blender Z-up 源文件、Godot Y-up 运行时。
远端步骤需已有明确授权，不在本地脚本中隐式提交付费任务。任务和实际费用位于 `art_source/environment/pipeline-v1/{tasks,usage}.json`。

顺序：

1. `export_whiteboxes.gd` 从保留的白模网格导出参考（进入场景树前关闭精模包装脚本；当前已保存 B0，勿无意覆盖原始参考）。
2. Tripo 无材质分件高模 → `geometry.py -- ASSET high`。
3. A 自带紧固件处理；B1/B2/E 用 `refine.py -- ASSET`；C/D 用 `conform.py -- ASSET`。这些修订不是重复执行安全的；重做前从第 2 步恢复。
4. Tripo decimate v3、smart_uv → `geometry.py -- ASSET low`。
5. `orient.py -- ASSET`、`audit.py -- ASSET`。C/D 另用 `check_walkable.py -- ASSET high|low`。
6. `bake.py -- ASSET` 执行 Cycles selected-to-active，真实高低模 NormalGL/AO；法线/面朝向改变后必须重做。
7. Tripo PBR 以检查过的 low GLB 为输入 → `materials.py -- ASSET` 转移到固定 UV、整理语义材质。
8. `ship.py ASSET`，Godot 导入后 `--script tools/environment_pipeline/preview.gd -- ASSET`，检查正背左右和对照。
9. `report.py` 汇总六资产。`tools/build_whitebox.py` 默认 final；`--art whitebox` 可导出白模，运行参数 `--whitebox` 可仅显示原白模。
10. `tools/validate.sh`、`tools/validate_rifle.sh`。通过 `LUNA_QA_OUTPUT` 选择本期证据目录。

所有 Blender Python 用 `--background --python-exit-code 1 --python` 执行；不要将 Blender 默认退出码 0 当作 Python 成功。中间文件有 `.gdignore`，不会把数百万面高模导入 Godot。
