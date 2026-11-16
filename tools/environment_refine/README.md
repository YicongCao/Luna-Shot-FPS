# ML15 环境精修（本地阶段）

远端任务由已授权 Tripo 工具显式提交；本地入口不花积分。先完成 B1 实机门禁，再逐件推广。源目录 art_source/environment/refine-v2，候选 assets/environment/candidates；原运行时仍可使用。

```sh
python3 tools/environment_refine/run.py build --asset B1
python3 tools/environment_refine/run.py bake --asset B1
python3 tools/environment_refine/run.py pack --asset B1
python3 tools/environment_refine/run.py export --asset B1
python3 tools/environment_refine/run.py audit --asset B1
```

每一步必须以前一步成功退出为前提。烘焙尚未完成时打包会拒绝；源或配方变化必须归档旧03-bake，再重新烘焙，不能沿用旧图。源保存逐组高/低/cage、分层节点和基础件边界属性；Pointiness仅作辅助Curvature，实际磨损用几何边界距离遮罩。

- 原生候选：`ENV_CANDIDATE=B1 ENV_ASSET=B1 ENV_PHASE=candidate`，运行Godot `--script tools/environment_refine/capture.gd`。未指定ENV_CANDIDATE时加载默认资源。
- 录制：同上，增加 `--fixed-fps 60 --write-movie artifacts/.../demo.avi`，用户参数 `-- --demo`。
- 性能：`ENV_QA_OUT=res://docs/validation/environment-refine-v2/B1/performance`，运行 `--script tools/environment_refine/performance.gd`。预热3秒、固定轨迹60秒，采样期间不要运行Blender或另一游戏实例。
- 模块显式bindings.json将导出网格映射到atlas；灯罩/动态附件独立材质。旧无bindings资产仍走既有材质流程。
- 灯罩不投射不透明阴影，结构继续投影，避免光源自遮挡产生假暗锥；灯罩Emission与实际局部灯分开验收。

当前实现进度以 docs/logs/ML15 和每件验证报告为准，不以候选文件存在推断已发布。
