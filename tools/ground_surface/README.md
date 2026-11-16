# ML16 地面复现

1. `uv run --with numpy --with pillow python tools/ground_surface/build.py` 生成三套2K纹理、16位高度源和独立8×8m场景；`--scene-only`仅重建场景，`--seed`控制材质生成。
2. `godot --headless --path . --editor --import --quit` 初次导入。
3. `python3 tools/ground_surface/configure_imports.py` 设置GPU压缩、mipmap、NormalGL；再次执行导入。导入设置已提交。
4. `./launch-ground-sample.command` 运行样板，B切换前后。全场新地面由生成器挂载，发布标志写入场景；旧版用`GROUND_BASELINE=1 ./launch.command`。

`validate_sample.gd`做原生前后/掠射光和真实胶囊检查；`validate_field.gd`检查完整地面、贴图、遮罩与原生对照。未发布候选加`GROUND_CANDIDATE=1`。`validate_masks.gd`读取artifacts/ml16/layouts.json中的20份布局；布局由tools/build_whitebox.layout(20261115+i)生成。

`tools/validate.sh`和`tools/validate_rifle.sh`按AGENTS运行，用LUNA_QA_OUTPUT分离新证据，并归档/还原旧脚本写死的历史证据目录。性能使用tools/environment_refine/performance.gd、ENV_PERF_ROUTE=facility，预热后60秒；期间不运行其他GPU任务。

`report.py`从检查结果生成HTML/Markdown，`publish.py`检查日志、JSON和60秒性能门禁，再生成默认场景。`APPROVED`是构建记录，场景存储published=true，避免导出包缺少扩展名文件时失效。

无需Tripo或imagegen。微细节由高度场生成，不冒充高模投射烘焙；主地面平面保持，盖板等几何为薄装饰，无新碰撞。仅当前固定摄影机/本机验证通过，用户视觉验收独立记录。
