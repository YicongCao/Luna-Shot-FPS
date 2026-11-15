# Luna-Shot-FPS

独立 Godot 4.7 工程；不要复制 Luna-Shot-Demo / No-Art-FPS 运行时代码或美术资产。
当前范围：一张月球基地训练场、一个玩家、固定靶、一把分件 LC01 枪械。无回合、刷怪、关卡流程。
视觉方向沿用旧策划概念，环境维持白模；LC01 已授权推进高低模、烘焙、PBR 和红点瞄准。不得将概念图、离线渲染当作游戏实机。
先空间与轮廓，再逐件精修。枪械首件：白模 → 高模 → 低模/UV → 烘焙 → PBR → 实机固定镜头对比。
不要直接生成带 PBR 的完整枪来跳过分件与验证。零部件 spec 仅为虚构游戏资产规格。
`tools/build_whitebox.py` 生成可在编辑器查看的关卡和枪械场景；编辑生成场景前应修改生成器，以免重建覆盖。
`scripts/player.gd` 管移动与射击，`scripts/training.gd` 管训练场界面，`scripts/qa.gd` 管实机验证。
执行 `tools/validate.sh` 进行导入、物理和原生渲染回归；`tools/validate_rifle.sh` 检查枪械、红点、材质对照。
枪械运行时位于 `assets/weapons/lc01`，来源与各阶段位于 `art_source/weapons/lc01/pipeline-v2`（.gdignore 避免将高模导入游戏）。
收费授权仅本次已完成的三次 Tripo 任务共 115 积分，不包含自动重抽。证据写入 docs/validation；结论明确平台与边界。
成果使用项目内 Markdown、HTML、标准图片，并提供绝对路径。按现有授权完成例行可逆操作。

网格朝向验收不能只看面数/有符号体积/重算法线成功；需要检查外表面方向和左右侧背面剔除实拍。改变面朝向或顶点法线后必须重新烘焙。LC01 本地修复与复现入口为 `tools/weapon_pipeline/repair_surfaces.sh`。
