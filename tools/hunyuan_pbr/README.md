# ML19 本地复现

从项目根目录执行。原始服务结果已归档，本地复现不调用收费API、不改默认资产。

```sh
uv run --with numpy --with scipy --with pillow python tools/hunyuan_pbr/audit.py
uv run --with numpy --with scipy --with pillow python tools/hunyuan_pbr/test_audit.py
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/hunyuan_pbr/capture.gd
ML19_EXTRA_ONLY=1 /Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/hunyuan_pbr/capture.gd
uv run --with numpy --with pillow python tools/hunyuan_pbr/report.py
```

审计限定本轮输入/输出的单网格、单primitive、无节点变换GLB；不支持的结构明确报错，不跳过未检查数据。原服务做了有记录的等比归一，审计逆变换后比较原始位置；不会通过自由拟合掩盖几何变化。

Godot运行会短暂打开原生窗口并自动退出；输出在docs/validation/hunyuan-tripo-pbr-v1。原始模型仍留在art_source的.gdignore目录，通过GLTFDocument加载；不会注册为默认玩家武器。
