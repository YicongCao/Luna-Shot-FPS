# Tripo重拓扑参数与网页查看核查

2026-11-16，查阅官方接口/Studio文档与当前连接器schema；本次未提交任何Tripo付费任务。

## 可以调节什么

公开mesh/decimate参数：input、model(v1.0/v2.0/v3.0)、face_limit、quad、smart_uv(v3.0)、bake、part_names。未暴露smooth、smoothing_iterations、preserve_sharp、hard_edge_angle或auto_smooth；不能把这些名字擅自当API有效参数。bake=false只关闭纹理转移，不会关闭几何平滑；关闭Normal贴图也不会还原已被重拓扑移动的顶点。

v3.0与v2.0的三角目标500–20,000，四边面500–10,000；v1.0基础减面支持更高目标(最多2M三角)，但不支持bake/part_names。v2.0官方描述含edge preservation，但没有可控制锐边阈值的参数，不能预先保证比v3.0更好。可另行试验高面数v1.0、按部件分配预算或不同算法，但需要另列费用并检查UV/材质保持，不在本次自动重抽。

Studio的Retopo文档列500–50,000、Triangle/Quad和Smart Mesh P1.0开关，范围与当前API v3.0不同；该开关控制重拓扑算法，并非“关闭平滑”。本次没有登录用户Studio界面实测，不把文档清单当作当前账户全部可用功能。

官方博客确有“Smoothing Pass”文章，讨论顶点平均、0/1/2次迭代等通用流程；但没有给出可对应本次API的请求字段。当前API schema与Studio参数表都未列该开关，因此不能仅凭文章宣称已有可调用的smooth=false。若网页实际出现额外开关，可再据该界面的版本和任务类型核实。

需区分三种问题：

- **平滑着色/顶点法线**让原本平面产生渐变，可做面法线诊断。它不改变外轮廓。
- **几何重拓扑/平滑**可能移动顶点，使直线弯曲和倒角变宽；关平滑着色无法恢复丢失形状。
- **法线贴图**进一步改变表面照明；关normal是排查，不等于关闭重拓扑平滑。

本次low-smooth/low-flat.png使用同一低模、同一相机和灰材质，只在诊断shader里改用逐三角面法线，顶点/UV完全不改、不保存为默认资产。观察三角分面与轮廓是否仍不规则，判断是否只是插值问题。任何正式更改顶点法线/切线都应重新处理相关烘焙，不能把此诊断直接发布为修复。

## 网页端能否看

可以用浏览器检查本地GLB。最直接方式是官方Online 3D Viewer，选择已下载文件；文档说明浏览器本地解析，可旋转/缩放查看几何和PBR，最大200MB。本轮高模约64MiB、低模约6.6MiB，均在其文档范围。也可在Studio上传外部模型，进入工作区查看；继续Retopo/Texture会产生独立费用，单纯查看不要重新点生成。

官方API FAQ说明任务历史/消费在平台History查看。我们的任务属于API连接账户；请使用对应API账户。该说明不能证明API任务自动出现在Studio的Assets—Models；Studio与API独立计费，本次未核实账户资产同步。因此建议：History查任务与费用，本地GLB用Viewer检查；需要Studio资产时显式上传。没有编造一个task_id直达Studio模型的链接。

本轮任务ID：212a9dac-9cdb-43e5-9379-75ea6bf74903（高模PBR），beeb5377-422a-4028-bc0d-a452188847a9（低模）。模型文件分别在art_source/weapons/lc01/tripo-rebuild-v3/{01-high-pbr,02-low-pbr}/model.glb。

## 官方来源

- [API重拓扑参数](https://developers.tripo3d.ai/en/docs/mesh-decimate)
- [Studio Retopo参数](https://www.tripo3d.ai/product-doc/module-post-processing/retopo)
- [Smoothing Pass博客](https://www.tripo3d.ai/blog/explore/ai-3d-model-generator-and-smoothing-pass-parameter-tuning)
- [API任务历史与独立计费FAQ](https://docs.tripo3d.ai/other/support-faq.html)
- [Studio外部模型与资产FAQ](https://www.tripo3d.ai/product-doc/support/faq)
- [官方在线查看器](https://www.tripo3d.ai/3d-tools/3d-viewer)
