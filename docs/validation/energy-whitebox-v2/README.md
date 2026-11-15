# 中央信号塔与 B1/B2 散热架实机验证

2026-11-15，Godot 4.7.2 / macOS Apple M5 / Compatibility 原生窗口。仍为环境白模，不代表最终环境美术。

## 本次变化

- 中央 (0,0,0) 信号塔：约 14.2 m 高、格构支架、三层天线横臂、顶部标灯。地面基座 2×2 m，高空横臂最大宽 3.8 m。
- B1：水平层叠散热塔；B2：双翼竖向散热架。各 6 个，保持原 4×4 m 占地和 6 m 高度。共享框架规格，靠轮廓而非换色区分。
- A40/B1 6/B2 6/C2/D4，共 58 个模块实例，加中央塔 1 个；合计 6 个主题 PackedScene、59 个实例。地面、围界、靶等基础设施单列。
- 中心由空旷交汇变为绕行地标，8 m 通道在 2 m 基座两侧各留 3 m；添加 signal_loop 实际胶囊路线。出生、桥梁、设备位置和靶标射击位保持可用。

## 验证结果

| 检查 | 结果 |
|---|---|
| 20 个固定种子、确定性、错误布局拒绝覆盖 | 通过，见 generation.json |
| 实例资源、子类数量、地标位置、桥梁接口与净高 | 68/68，modules.json |
| 无窗口真实胶囊 / 命中 / 重置 | 69/69，headless.json |
| 原生行走、中央绕塔、桥下、高架、护栏、边界、截图与超宽窗口 | 81/81，native.json |
| LC01 红点与射击回归 | 无窗口 19/19、原生 29/29，rifle/ |
| F3 训练场 / 材料室往返 | 通过，rifle/scene-switch.json |
| 材料室法线、粗糙度/金属度、能量开关渲染对照 | 已完成，rifle/render-comparison.json |

原生关卡测试运行约 148 秒，不作为长时间性能验收。中央射击位置可能受塔遮挡，测试保证的是清单中五个既定射击位；塔并非无碰撞装饰。近景由独立 QA 相机在原生场景拍摄，信号塔镜头高度 1.65 m，B 子类镜头高度 2 m；总览与常规行走截图由关卡 QA 保存。

![总览](02-overview.png)
![中央塔](08-signal.png)
![B1 水平散热](09-B1.png)
![B2 双翼竖向散热](09-B2.png)

复现：`python3 tools/test_energy_layout.py`、`./tools/validate.sh`、`./tools/validate_rifle.sh`；补拍地标运行 `Godot --path . --script tools/capture_energy_landmarks.gd`。旧版证据保留在 energy-whitebox-v1。本次无 Tripo 调用，未改变 LC01 模型/贴图。
