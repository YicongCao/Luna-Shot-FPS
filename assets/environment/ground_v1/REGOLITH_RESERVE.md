# 月壤素材保留约定

2026-11-16 用户选择全铺装，同时明确保留月壤，未来可能用于子弹击中地面后铺装破损、露出地下月壤的效果。当前仅保留素材、来源与设计注释，**未实现弹着破损**。

- 运行时素材：regolith/BaseColor.png、regolith/ORM.png、regolith/NormalGL.png及其压缩/mipmap导入设置。
- 制作源：art_source/environment/ground-v1/regolith-height16.png、manifest.json；生成配方tools/ground_surface/build.py。
- 着色器：surface.gdshader保留soil材质通道；主关卡soil_mask全黑，地面全铺装。
- 历史对照：sample_mask.png、scripts/ground_surface.gd中的make_field_mask()、独立8×8m样板与覆盖率对照脚本保留。历史分区遮罩不是弹着损伤遮罩。

未来若另行实施，需要独立设计铺装厚度、破口边缘、露底材质尺度、命中到局部遮罩的坐标映射，以及损伤数量/生命周期和是否影响碰撞。只切换为月壤材质不能表达真实破口。当前射击不修改这些遮罩，不生成碎屑、弹坑、凹陷或可破坏碰撞。
