# ML07 可复现入口

本次平台：Blender 5.2.2 / Cycles Metal、Godot 4.7.2 Compatibility、Apple M5。高模源目录有 `.gdignore`。不要运行旧 finalize 或 ML06 micro_surface 覆盖本轮结果。

## 已交付目录

- `art_source/weapons/lc01/ls01-refine-v1/02-geometry/paired.blend`：逐件高模、低模、独立 cage 和可编辑材质节点。
- `03-bake/body`、`03-bake/kit`：4K 母版、独立投射场景、契约与通道报告。
- `assets/weapons/lc01/ls01_v1`：候选/发布资源。`resolution.json` 决定打包尺寸：主体法线 4K，主体底色/ORM、附件与保留件 2K。
- `docs/art/ls01-refine-v1/PARTS.md`、`parts.json`：120 个配对、42 颗紧固件的逐件规格和落点。
- `docs/validation/ls01-refine-v1/review.html`：原生 Godot 同机位对照。

## 重建

在项目根目录执行。首次使用另一个 `--out` 时，先复制原目录的 `00-baseline` 和 `01-imagegen` 输入，添加 `.gdignore`；不得以空输入目录覆盖现有资源。脚本不自动重新调用付费服务。

```sh
python3 tools/ls01_refine/run.py build --seed 20261115
python3 tools/ls01_refine/run.py audit
python3 tools/ls01_refine/run.py bake
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/ls01_refine/retained.py
uv run --with numpy --with pillow python tools/ls01_refine/retained_materials.py
python3 tools/ls01_refine/run.py export
python3 tools/ls01_refine/run.py pack
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python tools/ls01_refine/specs.py
tools/ls01_refine/validate.sh
tools/ls01_refine/paired_performance.sh
```

`build/bake/export/pack/audit` 支持 `--out`；`export/pack` 支持 `--runtime`，`audit` 支持 `--report-dir`。`bake/pack` 支持 `--group body|kit|all`，`pack --size 2048` 可生成分辨率对照。默认 size=0 读取运行时 resolution.json，无配置时使用 2K。保留件重建及原生测试脚本使用本项目固定路径，迁移时需同步修改；不宣称全部脚本是通用资产框架。

已启用的运行时目录受 APPROVED 保护，export/pack/retained_materials 拒绝直接覆盖；后续迭代先选择新的候选输出。修改源几何、UV、逐角法线或高模材质后，归档对应 `03-bake` 目录后重烘焙。contract.json 会阻止源文件哈希不同却复用旧结果。修改烘焙算法也必须手动使对应通道缓存失效，不能只看源 .blend 哈希。`Curvature` 为 Cycles 高模 Pointiness；`EdgeMask` 为受控边界距离代理，二者不可混称。AO 为爆炸配对局部 AO，装配遮蔽依靠运行时光照与结构。

## 验证与启用

候选环境变量 `LS01_CANDIDATE=1`。`validate.sh` 验证贴图、UV padding、原生射击/换弹/红点/20 格屏幕、F2/F3、超宽、光照，并保存截图。性能单独交替运行，避免同时烘焙影响比较。原生窗口会自动打开并在测试后退出。

实施者看完实际截图后填写 `visual-review.json`，保留概念差距及用户验收状态；然后 `python3 tools/ls01_refine/publish.py`。它检查审计、原生日志、性能和视觉记录，再写 APPROVED；没有付费、上传、Git 提交或推送行为。

默认启动使用 `launch.command`；材料室使用 `launch-weapon-lab.command`。`launch-weapon-baseline.command` 强制加载原 ML06 枪械，可与新版往返比较。移除 `assets/weapons/lc01/ls01_v1/APPROVED` 可撤销默认启用；`LS01_BASELINE=1` 的优先级高于候选变量和标记。历史资源没有被候选覆盖。

## ML09 isolated revision

`python3 tools/ls01_refine/run.py build --revision ml09` selects the explicit structural recipe and v2 source/runtime roots; the default remains ML07. `bake`, `export`, `pack`, `audit` accept the same revision and optional `--out`, `--runtime`, `--report-dir`. Auxiliary Python audit/import commands accept those roots via `paths.py`. Native tools accept `LS01_REPORT_DIR=res://docs/validation/ls01-refine-v2` and Godot `-- --weapon-revision=ml09`; ML06/ML07 explicit choices are also supported. `structure_capture.gd` captures native feature views; `ML09_VIEW=clay` disables final shading for silhouette review. No new Tripo/imagegen generation is needed.

ML09 native regression: `tools/ls01_refine/validate_v2.sh`; paired ML07/ML09 performance: `tools/ls01_refine/performance_v2.sh` (run after other GPU jobs stop). `python3 tools/ls01_refine/review_v2.py` builds the portable gallery. `python3 tools/ls01_refine/publish.py --revision ml09` requires all checks, a human-readable feature review, matching reviewed hashes and the performance gate. Publication does not mark user acceptance. Published build/export/pack defaults are guarded; use fresh source/runtime paths for another iteration. The new source recipe preserves custom normals when freezing triangulation; audits also inspect the actual glTF planar normals.
