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

ML07 保留枪械分支为 assets/weapons/lc01/ls01_v1，源文件在 art_source/weapons/lc01/ls01-refine-v1，入口 tools/ls01_refine。显式 bindings.json 绑定 body/kit/retained 三套材质，保留两组弹夹动画节点、红点和能量接口。局部重建允许新 UV；十一件保留件按原位置/UV 审计。不要再对本轮枪械运行 ML06 主轴微法线补丁或旧 finalize。A 与环境仍沿用原状态。
主体法线 4K，主体底色/ORM 与其他 atlas 2K，4K 母版另存；使用 GPU 压缩、mipmap、各向异性过滤。Curvature（高模 Pointiness）与 EdgeMask（边界距离代理）分开。修改几何/法线/UV 后必须重烘焙；修改烘焙算法必须作废相关通道缓存。
APPROVED 标记保护已验证资源，不再决定默认版本（用户于 2026-11-16 选择 ML06），LS01_BASELINE=1 强制回到 ML06，LS01_CANDIDATE=1 可预览未发布候选。原生证据在 docs/validation/ls01-refine-v1；用户验收仍 pending，保留件软边、字重和磨损艺术性差距开放，不能在后续日志中改写为全部概念还原成功。

## 阶段提交约定（用户于 2026-11-16 确认）

每完成一个可独立说明、已做相应验证的阶段，就生成一次 Git commit，并在交付时报告提交号；不要将多个已完成阶段长期堆成未提交改动。里程碑更新与对应实现一起提交，提交说明写清变化和验证范围。保留真实历史，不把功能通过写成用户美术验收。提交前检查差异、密钥和大文件；模型、贴图与烘焙二进制使用 Git LFS。远程推送遵循用户授权，本次已授权创建并推送 GitHub 的 Luna-Shot-FPS 仓库。

ML09 结构还原候选/发布路径为 `art_source/weapons/lc01/ls01-refine-v2`、`assets/weapons/lc01/ls01_v2`；`tools/ls01_refine/run.py --revision ml09`选择新配方，ML07原配方保持。`--weapon-revision=ml06|ml07|ml09`显式选择，v2的APPROVED保留作为当时技术门禁记录，不控制默认。源与实际glTF都检查弹夹大平面逐角法线；三角化必须保留custom normals，改变后重烘焙，不能把斜向伪影当做划痕。灰模宽倒角/接口/分段的真实几何验收独立于磨损贴图。屏安装数据由screen.json共用。能量侧向Spot与原Omni统一受F6/F9控制，不调整环境资产。用户于 2026-11-16 对照三版后明确认为 ML06 更好，默认回滚 ML06；以后枪械迭代以 ML06 为基线，不因技术门禁通过自动替换用户选定版本。


## 枪械保形与视觉验收（ML11 复盘）

后续以用户选定的 ML06 为视觉基线。修改前同时列出“待修缺陷”和“不可损失特征”：枪托镂空/内骨架、黑白橙分区、弹夹分段高差/卡扣/端盖、瞄具脚座与顶轨层次、前罩斜切/槽孔。不得把删去这些设计当成拓扑清理或窄倒角优化。
一次先改一个可见问题；几何与材质分阶段比较。新 UV 不兼容旧贴图时使用相同中性灰材质比较几何，再在固定几何上比较材质。先以同镜头灰模/剪影检查轮廓、镂空、装配关系与正常第一人称尺寸，再推进整套烘焙。
验收必须写明相对基线的收益和损失；有某零件、面数/UV/cage通过、微细节更多不等于视觉升级。主要轮廓、镂空、色块或结构层次退步时停止推广；技术标记不得自动替换 ML06 默认。细节与历史误判见 docs/logs/ML11-枪械视觉倒退复盘与保形原则.md。

ML13 默认开火效果为纯代码方案 C：scripts/pulsed_arc.gd 复用 ML12 magnetic_pulse.gd 的基础设施，ML06 几何/贴图保持。--fire-effect=a 仅作历史 A 对照；C 专项 tools/validate_pulsed_arc.sh，证据 docs/validation/pulsed-arc-v1。电弧偏移/分叉须检查实际场景遮挡，不新增追踪或伤害；旧 A 验证入口必须显式选择 A，避免覆盖历史证据。

ML20 用户于 2026-11-17 要求替换 ML06：默认枪械为 `assets/weapons/lc01/ml20`，源与烘焙在 `art_source/weapons/lc01/ml20-hunyuan-bake`，入口 `tools/ml20_weapon/run.sh`。输入为 ML18 混元高模/UV 低模；烘焙前必须清除平台自定义法线并重建 UV 接缝硬边+面积加权法线，修改后重烘焙。ML06 保留，`--weapon-revision=ml06` 或 `LS01_BASELINE=1` 回看。ML20 不装 ML06 动态弹量屏；用户美术验收待定。

ML14 B2 侧面三风扇由 scripts/b2_cooling_fans.gd 程序化构建，module_visual.gd 在 final 视觉加载后挂载，6 塔共 18 叶轮。保留原 B2 GLB/UV/材质；固定护罩与旋转叶轮分离，附件不超出原 4×4 m 占地。专项 tools/validate_b2_fans.sh，证据 docs/validation/b2-cooling-fans。白模模式不加载该附件。

ML15 B1/B2/C/D/E 已完成第二轮精修并发布默认路径；Tripo 5次共300/400积分，0重抽。源文件art_source/environment/refine-v2，入口tools/environment_refine，原生证据docs/validation/environment-refine-v2/review.html。A、ML06枪械、ML14风扇和布局保持。每件高低模/cage/4K烘焙与2K运行图保留；B1补吊耳后的UV为ml15-B1-v2。旧模型在00-baseline及assets/environment/baselines；ENV_BASELINE/ENV_CANDIDATE按逗号列表选择。灯具必须从bindings局部挂点读取，数量B1/B2各4、C4、D6、E1；补光偏移必须随模块旋转。48红灯、32蓝灯、1旋转橙灯；池8槽最多2个Omni+1个Spot，F9只关实际补光、F7控制Bloom。黄色地面反光漆和批处理由生成器挂载ground_markings.gd，重建关卡先改生成器。性能需同时覆盖总览与近灯路线，不能用未激活补光的路线代替。当前技术与实施视觉复查通过，用户实机美术验收仍pending；不要改写为完全复刻概念。

ML16 地面已从8×8m样板推广至全场，源tools/ground_surface与art_source/environment/ground-v1，运行时assets/environment/ground_v1、scripts/ground_surface.gd。launch-ground-sample.command可玩样板，B前后切换；GROUND_BASELINE=1恢复ML15地面。2×4m重复铺装、三套2K材质、40组A座片及8个检修盖，不改变原碰撞平面/布局。用户现已选择默认全铺装，运行时使用全黑soil_mask；历史混合遮罩仍按布局动态生成，只供样板与对照。月壤PBR、高度源及遮罩代码不得删除，将来可研究弹着破损露出地下月壤；当前只保留素材和注释，不实施破损、弹坑或可破坏地形。微细节是高度场法线，不是高模投射烘焙；GPU压缩/mipmap导入配置须保留。地面IRRADIANCE同步WorldEnvironment，避免探针漫反射色带，镜面/直接光保留。生成器根据构建门禁写published=true，运行时不依赖APPROVED文件。技术与实施视觉通过，用户实机美术验收待定；证据docs/validation/ground-v1。
