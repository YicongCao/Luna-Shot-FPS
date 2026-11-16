# ML19 准备：混元低模 → Tripo PBR

状态：已准备精确请求和输入指纹，尚未创建服务任务、未消费积分、未生成候选。用户要求保留现有造型和UV，仅生成一版完整PBR，再做Godot对比。

输入是已含UV/法线的 `art_source/weapons/lc01/hunyuan-v1/pbr.glb`，20,901三角。`input-baseline.json`保存原文件、索引、位置/法线/UV访问器指纹及节点变换；`texture-request.json`是待提交的实际参数。

一次 `tripo_texture`，v3.5 / detailed / pbr=true / delight=true / bake=true。bake是服务材质兼容处理，不等于高模向低模的cage法线投射。参照原枪械单体概念图，并以文字约束原有白/橙/深色分区和材料响应。固定种子，不减面、不Smart UV、不重建、不自动重抽。

当前[官方价格](https://developers.tripo3d.ai/en/pricing)为HD纹理20积分；最后查实际账单。当前[纹理参数](https://developers.tripo3d.ai/en/docs/models-texture)和工具schema未公开锁定UV参数，工具也没有dry_run；已经逐项检查请求，不虚构支持项或服务端预检。

验收检查原文件不变、面数、按三角面角点匹配的位置/UV/法线、实际贴图通道。顶点或面表重新排序本身不代表形体改变；仅面数一致也不代表保持。若UV或几何确实变化，候选不得通过“保留原模型”的要求，不覆盖原件，不隐瞒变更，不擅自增加付费修复任务。

通过后在Godot独立材料场景与原混元底色版、ML06主体做统一机位/曝光/中性光及掠射光对照，分开灰模、最终材质与法线关闭模式；记录收益和差距。默认ML06、游戏机制和环境不变。结果、费用、验证证据与ML19实施日志随完成阶段提交。

Tripo工具目前明文要求：“show the user the returned plan … then stop and wait for the user's explicit confirmation”。因此需展示工具计划后完成一次确认，之后本轮常规下载、检查、截图与commit不再重复询问。
