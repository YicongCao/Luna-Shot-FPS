# LC01 白模源

`lc01-whitebox.blend` 是分件白模，不含最终 UV/法线烘焙/PBR。`lc01-whitebox.glb` 由同一 Blender 场景导出。各 Pxx 节点和六个 socket 与 Godot 原始代理保持对应。

生成：`/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_weapon_source.py`（项目根目录执行）。

回导验证：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/validate_weapon.gd`。比对名称、位置和各件世界包络，容差 0.1 mm，结果在 `docs/validation/whitebox-v1/weapon-roundtrip.json`。

项目禁用 Godot 自动导入 `.blend`，使用明确导出的 GLB，避免用户编辑器 Blender 路径影响项目启动。运行中的枪目前仍使用原始 `.tscn` 代理。

精修请另存 `lc01-high.blend` / `lc01-low.blend`；不要覆盖白模基准。运行生成器会覆盖这两个白模输出。
