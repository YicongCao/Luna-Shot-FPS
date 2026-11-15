# LC01 · Tripo 辅助完整资产管线试验

2026-11-15。状态：用户明确批准后已执行，三次远端任务全部成功，实际 115 credits。瞄具红点与材料对照已在 Godot 验证。以下为原批准方案；结果、偏差与质量限制见 [执行报告](../../validation/rifle-pipeline-v1/README.md)。方案提出时余额为 2040 credits、冻结 0，并非当前余额。

## 输入

[单枪参考图](../../../art_source/weapons/lc01/pipeline-v1/input/lc01-single-reference.png)由内置 imagegen 根据已有幻想图整理，移除了版式、第二个视图与色板；不是新增设计，也不是实机证据。原始设计及 P01–P12 分件规范见 [SPEC](../rifle-v1/SPEC.md)。图像整理完整提示词见同目录 `input-preparation-prompt.txt`。

已有 B0 白模继续保留，所有试验放在 `art_source/weapons/lc01/pipeline-v1/`，不覆盖基准。场景环境保持白模；本次仅精修虚构游戏道具 LC01。

## 远端调用与预计费用

1. `tripo_image_to_3d`：明确指定 `v3.1-20260211`，`texture=false, pbr=false, geometry_quality=detailed, generate_parts=true, export_uv=false, model_seed=20261115`。无贴图高密度分件毛坯，预检报价 **60 credits**，无参数被剥离。生成结果需要检查及修整，不能凭面数称为已合格高模。
2. `tripo_decimate`：输入经本地高模修整后导出的 GLB，`model=v3.0, face_limit=20000, quad=false, bake=false, smart_uv=true`。目标是约 20k 三角的低模/UV 起点；外形、分件、开口、拓扑与 UV 要另验。公开目录价 **35 credits**。
3. `tripo_texture`：输入检查后的低模，`model=v3.5-20260815, pbr=true, texture_quality=detailed, delight=true, texture_alignment=geometry`，使用文字引导白壳/深色骨架/橙匣/三段青色状态带。公开目录价 **20 credits**。只生成一套候选，不自动重抽。

每个阶段用 `tripo_task_wait` 等待终态，再用 `tripo_download` 保存模型、预览和 task.json；最后 `tripo_usage` 核对所有任务的实际费用。这些查询/下载不收费。

总预计 **115 credits**（按当前官方列表价约 $1.15）。没有预授权重复生成或其它收费路线；失败需要换路线时按 Tripo 工具要求重新列计划。低模与贴图处理的计划工具可能标为 not_estimated；上面的 35/20 来自 [官方 API 价目](https://developers.tripo3d.ai/en/pricing)，最终以任务账单为准。

## 本地阶段与真实产物

| 阶段 | 工作 | 产物与通过条件 |
|---|---|---|
| 白模 B1 | 按参考和生成几何检查比例，保留握持/瞄准基准；清理分件和命名 | 独立可编辑 `.blend`、GLB、中性灰多视图，不以彩色材质隐藏问题 |
| 高模 H1 | 清理 Tripo 毛坯，修复护圈、瞄具、枪托开口、线圈间隙与主要面层；补可控细节 | 独立高模 `.blend`/GLB、网格统计；检查背面、厚度、法线与装配关系 |
| 低模 L1 | Tripo 重拓扑/UV 后检查并修正；保留独立能源匣、必要 Socket；固定三角化 | 低模 `.blend`/GLB，三角数、UV checker、UV 越界/重叠/面积检查 |
| 烘焙 B1 | Blender Cycles 从真实高模投射至低模，按匹配部件选中到活动对象；记录 cage/射线设置 | NormalGL、AO、烘焙设置和日志；比较启用/禁用法线；不得用生成的法线图冒充高低模烘焙 |
| PBR M1 | Tripo 生成一套 PBR 候选，检查颜色空间与各贴图通道，整理 ORM，控制发光 | BaseColor、NormalGL、ORM、Emission（如需要）、材质配置；无烘死强光影 |
| UV 一致性 | 对比 Tripo 贴图前后的网格和 UV；如返回 UV 被修改，在最终低模 UV 上重新烘焙真实法线/AO | 不能把旧 UV 的法线套到新 UV；保留远端材质输出与最终修订来源 |
| Godot 集成 | 使用低模和最终 PBR，保持旧白模可回退；检查瞄准和换弹 | 固定腰射/开镜/换弹截图、实际模型/贴图统计、运行错误检查 |

本地阶段不消耗 Tripo 积分。Blender 程序化工作可继续修复当前产物，但不把“重复细分低模”伪称高模细节，不将减面结果自动视为合格重拓扑。若某阶段质量未通过，报告明确缺陷和证据，而不是把所有步骤打勾。

## PBR 引导词

Fictional LC-01 lunar industrial game prop. Off-white ceramic-coated armor panels over dark blue-grey metal chassis, dark rubber grip, one saturated orange removable energy cell, exactly three narrow cyan emissive energy bands. Clean readable large material regions with very restrained edge wear. Neutral albedo without baked lighting or painted highlights. Preserve the existing geometry, openings, part boundaries and UV layout wherever supported. No extra objects, no camouflage, no heavy dirt, no ornamental engraving.

## 交付清单

- 远端原始输出、所有 task.json 与积分账单。
- 分开的白模、高模、低模 Blender 文件和导出模型。
- 真实高低模烘焙的法线/AO、可复现脚本、参数与日志。
- 最终 PBR 材质与 UV/模型检查报告。
- Godot 第一人称实拍与阶段对照；明确质量限制，不提供无依据的“概念图达成百分比”。
