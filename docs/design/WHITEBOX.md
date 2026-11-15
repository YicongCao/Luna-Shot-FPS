# 月球训练场白模 v0.1

2026-11-15。新的独立 Godot 4.7.2 工程，没有复制旧项目运行时代码、PBR 材质或成品模型。沿用旧策划的空间与美术目标，取消 60 秒回合、敌人刷新、狂暴、结算与流程；打开后直接自由训练。

## 空间

| 区域 | 已实现的空间约束 |
|---|---|
| 场地 | X=−22…22、Z=−24…24，44×48 m；北为 −Z；1 m 地面标尺，5 m 主线 |
| 基地 | 北侧总宽 28 m、楼体深 6 m、平台深 3 m；平台顶 Y=2.4；室内封闭 |
| 双坡道 | 中心 X=±5、Z=−11；水平长 8 m、高差 2.4 m；表面宽 3 m，约 16.7° |
| 停机坪 | 中心 (−12.5,−1)，12×14 m；地面齐平，避免踏步卡脚；飞船仅轮廓代理 |
| 西通道 | 坪西沿 X=−18.5 到内墙 X=−22，几何间距 3.5 m |
| 氧气设备 | 两座高塔、横罐、桥接管线和太阳能板代理，保留东侧维修路径 |
| 中央区 | 四组 0.9–1.2 m 低掩体，五个固定靶，南侧射击标线 |
| 靶距 | 南侧射击线 Z=18；前三靶 Z=8/−2/−12，标称 10/20/30 m，横向错开避免完全重叠 |
| 边界 | 四侧可见 3 m 高围墙，胶囊跳跃不能越出；这只是封闭白模，后续替换月面地形轮廓 |

三处尺寸是新项目调整：旧附册的坡道位置改成 ±5 m 对称布置；停机坪改为齐平；双坡道之间保留靶道。概念图中建筑占比、飞船比例、设备疏密仍须由用户实玩评估，自动测试不代表艺术认可。

完整几何与碰撞清单见 [whitebox-inventory.json](whitebox-inventory.json)。节点有 A01–A05 分区和可识别名称；生成结果直接显示于 Godot 编辑器，非仅运行时黑盒生成。

## 训练机制

角色胶囊半径 0.32 m、高 1.8 m，眼高 1.65 m；步行 5 m/s、冲刺 8 m/s、瞄准移动 3.3 m/s。采用受控重力，不在本轮模拟月球弹跳。碰撞覆盖环境与固定靶。

固定靶永不消失；命中闪烁和计数提供反馈。白模枪支持腰射、开镜、20 发弹匣、1.5 秒换弹与无限备弹。没有分数排名、胜负或任务流程。F2 总览暂停角色操作，F5 重置位置、计数和弹匣，ESC 释放鼠标并显示继续/重置/退出。

世界射线从相机发出，另检查枪口前方建筑遮挡。武器独立透明视口，因此不发生贴墙时武器被世界近裁面切掉的表现；这不等于已实现完整的近墙收枪动画。

## 源与重建

- `tools/build_whitebox.py`：确定性生成训练场与 LC01 场景；几何及布局变更在此修改。
- `scenes/training.tscn`：可编辑/检查关卡。
- `scripts/player.gd`、`target.gd`、`training.gd`：独立角色、固定靶和训练界面。
- `tools/build_weapon_source.py`：在 Blender 后台生成同一枪械白模的 `.blend` 和 `.glb`；不调用模型生成服务。
- `tools/validate.sh`：导入、无窗口物理检查、原生窗口检查和实机截图。

```sh
python3 tools/build_whitebox.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_weapon_source.py
./tools/validate.sh
```

源案：`../Luna-Shot-Demo/docs/design/moonbase-plan-2026-11-13/` 与 `../Luna-Shot-Demo/docs/art/moonbase-concepts-2026-11-13/`。仅作历史方向参考；新项目启动不依赖它们。

实现参考：[Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)、[Camera3D](https://docs.godotengine.org/en/stable/classes/class_camera3d.html)。验证结论以本机实际运行版本为准。
