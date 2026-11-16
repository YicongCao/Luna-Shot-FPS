# Hunyuan3D 枪械试验输入图

使用已归档的Tripo高模PBR（1,934,290三角），从同一模型生成7个角度。2048×2048，七张白底PNG+七张RGBA透明PNG；光照固定为中性柔光，不使用强Bloom、文字、水印、地面或投影。PBR保留Tripo材质，未本地重绘。Cycles Metal离线参考图，不是游戏实机。正常金属反射仍存在，不冒充纯BaseColor/去光照扫描图。

01-hero三分之四为建议单图输入；02-right/03-left左右侧；04-front-muzzle沿枪口向后；05-back-stock从枪托向前；06-top俯视；07-hero-reverse反向三分之四。正投影视图统一比例，枪口/枪托正面自然较窄，不能把它们放大到不同尺度再误称统一多视图。平台对front/left/back/right的定义可能不同，请按实际界面配对；本次没有操作Hunyuan3D，也没有验证其所有产品入口支持多视图。

这是最初枪械形体和ML17 Tripo材质，保留枪托镂空、分段弹夹；不包含后加的工业kit、弹药屏、铜管附件或主动发光逻辑。若希望Hunyuan重新生成这些附件，需要另准备新的完整设计参考，不能假设从当前图中自动得到。

contact-sheet.jpg仅供预览，实际输入使用独立PNG。artifacts/exports/hunyuan-rifle-input.zip包含14张原图、来源manifest和本说明，便于带走；压缩包是可再生成副本，不重复进Git。输出检查所有分辨率、alpha及边界，防止枪械截断；源模型哈希见manifest.json。未修改运行时和源模型，本轮付费调用0。

复现：Blender --background --python-exit-code 1 --python tools/hunyuan_export/render.py，然后uv run --with pillow python tools/hunyuan_export/package.py。只导出图片，不保存回模型。
