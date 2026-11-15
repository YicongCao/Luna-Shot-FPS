# Luna-Shot-FPS

独立 Godot 4.7 工程；不要复制 Luna-Shot-Demo / No-Art-FPS 运行时代码或美术资产。
当前范围：一张 64×66 m 月球能源设施训练场、一个玩家、固定靶、一把分件 LS01 枪械（内部 lc01 路径兼容）。无回合、刷怪、关卡流程。
视觉方向沿用旧策划概念，环境已授权推进 A/B1/B2/C/D/E 六资产完整建模管线，随后制作低角度日照、Bloom 与 imagegen 镜头光晕；LC01 已授权推进高低模、烘焙、PBR 和红点瞄准。不得将概念图、离线渲染当作游戏实机。
先空间与轮廓，再逐件精修。枪械首件：白模 → 高模 → 低模/UV → 烘焙 → PBR → 实机固定镜头对比。
不要直接生成带 PBR 的完整枪来跳过分件与验证。零部件 spec 仅为虚构游戏资产规格。
`tools/build_whitebox.py` 只生成能源设施关卡与 A/B/C/D 四类共享模块（B1/B2 两个子类）及中央信号塔，默认种子 20261115。旧枪械白模入口为 `tools/build_weapon_whitebox.py`。修改生成场景前应改生成器，以免重建覆盖。
用户已批准环境主题资产预算为 A/B1/B2/C/D 五个模块资源，加一个中央信号塔资源，共 59 个实例；不要通过新增飞机、基地、储罐或大量变体扩大独立建模量。地面、围界、标线、靶属于基础设施。布局与路线来源为 `docs/design/energy-layout.json`。
`scripts/player.gd` 管移动与射击，`scripts/training.gd` 管训练场界面，`scripts/qa.gd` 管实机验证。
执行 `tools/validate.sh` 进行导入、物理和原生渲染回归；`tools/validate_rifle.sh` 检查枪械、红点、材质对照。
枪械运行时位于 `assets/weapons/lc01`，来源与各阶段位于 `art_source/weapons/lc01/pipeline-v2`（.gdignore 避免将高模导入游戏）。
历史 LC01 三次 Tripo 任务共 115 积分已完成。本轮六环境资产 18 次 Tripo 任务已获授权，上限 690 积分，不包含自动重抽；先 A 完整管线，再 B1/B2/C/D/E，环境验收后做光照。证据写入 docs/validation；结论明确平台与边界。
成果使用项目内 Markdown、HTML、标准图片，并提供绝对路径。按现有授权完成例行可逆操作。

网格朝向验收不能只看面数/有符号体积/重算法线成功；需要检查外表面方向和左右侧背面剔除实拍。改变面朝向或顶点法线后必须重新烘焙。LC01 本地修复与复现入口为 `tools/weapon_pipeline/repair_surfaces.sh`。

ML03 六资产首轮已完成，18 次任务实际 690 积分。环境源文件在 art_source/environment/pipeline-v1，运行时在 assets/environment；生成器默认 final，--art whitebox 可导出白模，不要重建枪械。ML04 使用 Compatibility 原生场景 Glow 与独立枪械高亮模糊合成（透明视口原生 Glow 会裁剪 alpha）；不要仅为通过旧参数检查重新开启裁剪的方案。光照专项入口 tools/validate_lighting.sh，真实像素证据在 docs/validation/lighting-v1。F6/F7/F8/F9 分别控制能量、Bloom、光晕、局部补光。

A 最新版本为 ML05 概念精修样板：运行时路径不变，源文件在 art_source/environment/A-refine-v2，脚本在 tools/a_refine。当前 5,180 三角、40 实例；旧版完整副本在 00-baseline。不要用 pipeline-v1 的 A 导出覆盖当前样板。新旧原生对照见 docs/validation/A-refine-v2。

ML06 工业细节来源在 art_source/industrial-wear-v1，枪械受限平面修整在 art_source/weapons/lc01/industrial-wear-v1；脚本 tools/industrial_wear。A 仍使用原低模/UV，更新高模槽孔烘焙与磨损贴图；枪械新增独立 field_kit/kit.glb 和动态20格屏幕。imagegen 微表面在06-imagegen，经去低频、边界处理、RNM合成保留原烘焙法线。不要用ML05或旧pipeline直接覆盖当前运行时贴图。复现时先完成原高低模烘焙与磨损，再合成微表面。

ML07 当前枪械分支为 assets/weapons/lc01/ls01_v1，源文件在 art_source/weapons/lc01/ls01-refine-v1，入口 tools/ls01_refine。显式 bindings.json 绑定 body/kit/retained 三套材质，保留两组弹夹动画节点、红点和能量接口。局部重建允许新 UV；十一件保留件按原位置/UV 审计。不要再对本轮枪械运行 ML06 主轴微法线补丁或旧 finalize。A 与环境仍沿用原状态。
主体法线 4K，主体底色/ORM 与其他 atlas 2K，4K 母版另存；使用 GPU 压缩、mipmap、各向异性过滤。Curvature（高模 Pointiness）与 EdgeMask（边界距离代理）分开。修改几何/法线/UV 后必须重烘焙；修改烘焙算法必须作废相关通道缓存。
APPROVED 标记控制默认启用，LS01_BASELINE=1 强制回到 ML06，LS01_CANDIDATE=1 可预览未发布候选。原生证据在 docs/validation/ls01-refine-v1；用户验收仍 pending，保留件软边、字重和磨损艺术性差距开放，不能在后续日志中改写为全部概念还原成功。

## 阶段提交约定（用户于 2026-11-16 确认）

每完成一个可独立说明、已做相应验证的阶段，就生成一次 Git commit，并在交付时报告提交号；不要将多个已完成阶段长期堆成未提交改动。里程碑更新与对应实现一起提交，提交说明写清变化和验证范围。保留真实历史，不把功能通过写成用户美术验收。提交前检查差异、密钥和大文件；模型、贴图与烘焙二进制使用 Git LFS。远程推送遵循用户授权，本次已授权创建并推送 GitHub 的 Luna-Shot-FPS 仓库。
