# ML07 · LS01 原生验证与视觉复查

日期：2026-11-16。平台：本机 macOS / Apple M5，Godot 4.7.2 Compatibility；Blender 5.2.2 Cycles Metal。所有实机 PNG 均由 Godot 原生视口保存。

## 状态与范围

技术门槛：**通过**。实施视觉复查：**本轮重建范围通过，概念差距仍开放**。用户验收：**待验收**。

本轮重建机匣、两件弹夹、枪托、瞄具、顶轨及工业附件；十一件保留原几何/UV，使用改进的材料分层和此前真实烘焙法线。不能把该结果称为全枪完全重拓扑，也不宣称逐像素达到概念图。

[原生新旧对照](review.html) · [设计](../../art/ls01-refine-v1/DESIGN.md) · [逐件规格](../../art/ls01-refine-v1/PARTS.md) · [最初问题清单](../../research/weapon-material-review-2026-11-15/REVIEW.md)

## R01–R12 逐项复查

“本轮通过”指下表描述的实际实现，不等于右栏概念差距已经关闭。每项用户验收均 pending。

|问题|实施复查与实际证据|保留边界／概念差距|
|---|---|---|
|R01 弹夹凹痕与油污|本轮通过：弹夹主壳与可见侧板均有真实高模浅压伤；法线、油膜低粗糙度和干漆区域分别成立。<br>[magazine](magazine.png) · [magazine-light-1](magazine-light-1.png) · [magazine-light-2](magazine-light-2.png) · [magazine-channel-6](magazine-channel-6.png) · [magazine-channel-8](magazine-channel-8.png)|第一人称下细小凹坑比近景弱，不能把材质台放大效果等同正常游玩尺寸。|
|R02 掉漆／露底／氧化|本轮通过：露底在底色、金属度与粗糙度通道共用遮罩；钢、涂层和铜分层。未把铝壳画成大面积红锈。<br>[magazine-channel-4](magazine-channel-4.png) · [magazine-channel-5](magazine-channel-5.png) · [magazine-channel-6](magazine-channel-6.png) · [kit-close](kit-close.png)|氧化采用局部暗化和粗糙度变化，未追求概念图每一处锈斑的逐像素还原。|
|R03 金属材料识别|本轮通过：中性光下钢螺钉、铜管、涂漆壳与橡胶反射不同；关卡使用原独立武器视口的反射环境。<br>[studio-0](studio-0.png) · [studio-1](studio-1.png) · [studio-2](studio-2.png) · [ammo-13](ammo-13.png)|月面硬光与概念的柔和暗调不同；白漆应保留非金属面层，不能全壳设 metallic=1。|
|R04 钢色十字紧固件|本轮通过：42 颗有清册；高模真实交叉切槽，主体 4K 法线可辨十字；补齐左右前罩各四颗。<br>[screw-close](screw-close.png) · [screen-close](screen-close.png) · [front-fasteners](front-fasteners.png) · [front-fasteners-reverse](front-fasteners-reverse.png)|前罩原有涂漆孔缘保留，因此钢头外仍有浅色壳体孔缘；不能将其误记为整颗钢头发白。|
|R05 弯曲圆截面铜管|本轮通过：两侧各六管，端部弯入夹具，弯曲和圆截面在低模几何中，镜面高光沿管轴连续。<br>[kit-close](kit-close.png) · [reverse](reverse.png)|弯曲幅度服从原枪侧凹槽空间，不是大幅外露软管。|
|R06 LS01 字标|本轮通过：左右矢量 LS01 可读且无镜像；HUD、材料室与窗口使用 LS01，lc01 路径保留。<br>[kit-close](kit-close.png) · [reverse](reverse.png) · [ammo-13](ammo-13.png)|字形为手工工业线性字形；并非识别出概念图的原始字体，字重仍有概念差异。|
|R07 六边形弹药屏|本轮通过：六边形外框、内嵌玻璃、四角钢螺钉成立；20 格与 20/13/4/1/0 及换弹同步。<br>[screen-close](screen-close.png) · [ammo-20](ammo-20.png) · [ammo-13](ammo-13.png) · [ammo-04](ammo-04.png) · [ammo-01](ammo-01.png) · [ammo-00](ammo-00.png)|保留现有枪托和开镜接口，外框比例为本轮工程尺寸，未宣称与概念完全相同。|
|R08 警示条相位|本轮通过：独立平面标记按相同条宽和相位裁切，不跨机匣折面；修正橙色偏暗发紫。<br>[kit-close](kit-close.png) · [reverse](reverse.png)|标记保持完整印刷区域，本轮未给独立矢量贴纸新增单独剥落贴图。|
|R09 磨损分区|本轮通过：删除大平面迷彩和硬阈值脏点；边界距离控制断续露底，长向刮擦、浅压伤、微坑与低频油膜分层。<br>[magazine](magazine.png) · [kit-close](kit-close.png) · [studio-0](studio-0.png)|接触故事仍为规则与艺术遮罩组合；个别边缘磨损较规则，后续手工遮罩精修继续开放。|
|R10 UV 与烘焙|本轮通过：独立 cage、固定三角和切线；新 UV 无严格重叠，2K 换算岛间最小约 33px；4K 主体对照提高槽口可读性。<br>[clay](clay.png) · [screw-close](screw-close.png) · [magazine-channel-8](magazine-channel-8.png)|保留件沿用旧 atlas，不因旧 UV 相同而宣称其像素利用率已改善。|
|R11 受控低模轮廓|本轮通过：机匣、两件弹夹、枪托、瞄具、顶轨及附件使用受控几何，灰模平面和窄倒角稳定。<br>[clay](clay.png) · [studio-1](studio-1.png) · [reverse](reverse.png)|T01 前罩、T06 枪口、T14 前支架等保留件仍能看到生成网格的软边；属于仍开放的概念差距，未标为全枪精确重拓扑完成。|
|R12 验收证据分离|本轮通过：每项挂接原生截图、判断和局限；功能、实施视觉复查和用户验收分别记录，拒绝轮次保留。<br>[review](review.html)|用户验收 pending；实现复查通过只适用于已说明的本轮范围，概念一致性未全部关闭。|

## 几何、UV 与烘焙

- 120 组高模/低模/cage，42 颗螺钉清册。GLB 静态低模 **39,400 三角、15 网格**。包含程序化屏幕、字标等的武器网格总计 **39,748 三角**，低于 60,000。
- 新件无退化面、意外非流形边或负体积，cage 与低模拓扑一致。保留十一件逐三角位置及 UV 对照相同；全部导出切线。环境与 A 资产哈希不变。
- 新 atlas 严格内部重叠为 0。UV 覆盖率主体 51.7%、附件 26.1%。连续 UV 岛 ID 审计的最小间距换算到 2K 为 33px；栅格估算误差约 2px，扩边为每侧 16px。
- 高低模按零件爆炸隔离，单独 cage 外扩范围见清册；4K Cycles selected-to-active 实际输出 NormalGL、AO、BaseColor、Roughness、Metallic、Curvature、EdgeMask、Position PNG/EXR、WorldNormal、MaterialID、WearMask、OilMask。
- Curvature 是高模 Cycles Pointiness（0.5 表示平坦的近似编码），EdgeMask 是受控边界距离代理，不能混称。AO 为配对内局部 AO，不能证明装配后遮挡已全部烘入。
- 保留件使用 ML06 微法线叠加之前的真实烘焙法线，移除逐面主轴微法线补丁。源分层材质和实际投射场景均保留。

[几何审计](geometry-audit.json) · [UV padding](padding-audit.json) · [保留件/环境](runtime-audit.json) · [贴图审计](bake-audit.json)

## 材质与分辨率决定

涂层保持非金属，露底遮罩同时控制底色、金属度和粗糙度；钢头、铜管、暗色涂层、玻璃、橡胶分别绑定。油膜与积尘使用不同粗糙度，表面高模 bump 和真实浅压伤统一进入法线烘焙。imagegen 仅提供艺术遮罩，不是测量高度或完整物理 PBR。

初始主体 2K 的十字槽近景偏软。[2K 证据](resolution-study/2k/screw-close.png) 与 [最终证据](screw-close.png) 使用相同机位。最终尺寸以 [resolution.json](../../../assets/weapons/lc01/ls01_v1/resolution.json) 为准。4K 母版保留，运行时仅为实际需要的通道增加分辨率。GPU 压缩、mipmap 和各向异性过滤开启，NormalGL 不翻转 Y；ORM 为线性数据。

未压缩全主体 4K 的 +21.3% P95 版本被拒绝。压缩后仍进行平衡顺序复测，不用一次较快样本替代完整比较。所有失败/中间轮次保存在 performance-history。

压缩设置依据 [Godot 图像导入文档](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html)：Compatibility 使用相应桌面压缩格式，法线单独启用 normal-map 导入。源 PNG 母版不进行有损覆盖。

## 游戏功能与性能

弹量专项 **75 项检查通过**，覆盖逐发扣弹、20/13/4/1/0、换弹和20格显示。原生枪械检查、开镜红点、命中、两弹夹动画、F2、F3 往返、能量环、Bloom、光晕遮挡和超宽窗口见对应日志与截图；不能由这些功能断言推出美术一致性。

|指标|ML06 基线|ML07|
|---|---:|---:|
|武器三角（含运行时网格）|28,372|39,748|
|武器 MeshInstance 数|39|38|
|武器唯一材质（不含 Label3D 字体内部材质）|4|7|
|整个场景纹理内存|882.7 MiB|816.0 MiB|
|P95 帧时间中位数|32.330 ms|31.150 ms|

相对变化 **-3.6%**；10% 门槛 **通过**。1600×1000，每次预热 150 帧后测 600 帧，ABBA ABBA 顺序，各版 4 次。测量为真实渲染帧间单调时钟时间，不是固定 physics delta。后台仍有用户原有游戏窗口及桌面应用，因此绝对 FPS 是本次机器负载下的结果，不代表独占性能或长时间稳定帧率。

[完整性能样本](performance-comparison.json) · [弹量检查](ammo-qa.json) · [原生枪械日志](rifle/native.log) · [F3 往返](scene-switch.log) · [光照专项](lighting.log)

## 交付与仍开放事项

- 主要概念差距：保留前罩/枪口/支架的生成轮廓仍偏软；LS01 字重与概念不同；个别边缘磨损仍偏规则；关卡硬光氛围与概念不同。以上保持开放，不记为用户验收通过。
- 旧资源和参数在 art_source/weapons/lc01/ls01-refine-v1/00-baseline。通过 launch-weapon-baseline.command 可查看原版。
- 付费调用：imagegen **2 次**，Tripo **0 次 / 0 积分**。imagegen 工具未返回金额，因此实际货币费用未知；提示词与调用记录在 docs/art/ls01-refine-v1/imagegen.json。
- 本轮没有 Git 提交或推送，保护既有未提交改动；A 和其他环境资源未修改。

复现、候选启用及回退方法见 [工具说明](../../../tools/ls01_refine/README.md)。

默认启用及旧版回退选择已分别验证：[默认原生日志](default-native.log)、[旧版选择日志](baseline-qa.log)。[写入保护检查](write-guard.json) 验证已启用目录拒绝 export/pack 覆盖，运行时哈希未变。
