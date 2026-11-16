from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json,zipfile,hashlib
R=Path(__file__).resolve().parents[2];D=R/'docs/art/hunyuan-rifle-input';m=json.loads((D/'manifest.json').read_text());font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',25)
board=Image.new('RGB',(1800,1800),'#e6e9ed');draw=ImageDraw.Draw(board);page=['<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>Hunyuan3D 枪械输入图</title><style>body{max-width:1400px;margin:28px auto;padding:0 20px;background:#18202c;color:#eef;font:16px/1.6 system-ui}.grid{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}img{width:100%}a{color:#77e0df}figure{margin:0}@media(max-width:800px){.grid{grid-template-columns:1fr}}</style><h1>枪械高模 PBR 参考图</h1><p>真实Tripo高模+原始PBR，Blender Cycles离线渲染，非Godot实机。七张独立2048×2048PNG，每张均有纯白背景和透明背景版，无文字/水印/地面投影。所有视图来自同一模型和同一固定光照。预览拼图仅供浏览，上传请用单张原图。</p><p>正面=沿枪口看向枪托，背面=从枪托看向枪口，左右为枪械侧面；具体平台如何命名视图请以该界面定义为准。单图先尝试01-hero；多视图按界面要求选择对应单图。没有预先保证所有Hunyuan3D入口支持多视图。</p><div class="grid">']
for i,v in enumerate(m['views']):
 im=Image.open(D/v['rgba']).convert('RGBA');assert im.size==(2048,2048)
 alpha=im.getchannel('A');assert alpha.getextrema()==(0,255)
 bbox=alpha.getbbox();assert bbox and bbox[0]>0 and bbox[1]>0 and bbox[2]<2048 and bbox[3]<2048,(v['id'],bbox)
 white=Image.new('RGBA',im.size,'white');white.alpha_composite(im);white.convert('RGB').save(D/v['white_background'])
 preview=white.convert('RGB');preview.thumbnail((580,540));x=i%3*600;y=i//3*600;board.paste(preview,(x+(600-preview.width)//2,y+40));draw.text((x+16,y+8),v['id'],font=font,fill='#152638')
 page.append(f'<figure><a href="{v["white_background"]}"><img src="{v["white_background"]}"></a><figcaption>{v["id"]}<br><a href="{v["white_background"]}">白底原图</a> · <a href="{v["rgba"]}">透明原图</a></figcaption></figure>')
 v['foreground_bbox']=bbox
board.save(D/'contact-sheet.jpg',quality=92);page.append('</div><p><a href="README.md">来源与使用说明</a></p>');(D/'review.html').write_text('\n'.join(page))
(D/'manifest.json').write_text(json.dumps(m,indent=2))
(D/'README.md').write_text('''# Hunyuan3D 枪械试验输入图

使用已归档的Tripo高模PBR（1,934,290三角），从同一模型生成7个角度。2048×2048，七张白底PNG+七张RGBA透明PNG；光照固定为中性柔光，不使用强Bloom、文字、水印、地面或投影。PBR保留Tripo材质，未本地重绘。Cycles Metal离线参考图，不是游戏实机。正常金属反射仍存在，不冒充纯BaseColor/去光照扫描图。

01-hero三分之四为建议单图输入；02-right/03-left左右侧；04-front-muzzle沿枪口向后；05-back-stock从枪托向前；06-top俯视；07-hero-reverse反向三分之四。正投影视图统一比例，枪口/枪托正面自然较窄，不能把它们放大到不同尺度再误称统一多视图。平台对front/left/back/right的定义可能不同，请按实际界面配对；本次没有操作Hunyuan3D，也没有验证其所有产品入口支持多视图。

这是最初枪械形体和ML17 Tripo材质，保留枪托镂空、分段弹夹；不包含后加的工业kit、弹药屏、铜管附件或主动发光逻辑。若希望Hunyuan重新生成这些附件，需要另准备新的完整设计参考，不能假设从当前图中自动得到。

contact-sheet.jpg仅供预览，实际输入使用独立PNG。artifacts/exports/hunyuan-rifle-input.zip包含14张原图、来源manifest和本说明，便于带走；压缩包是可再生成副本，不重复进Git。输出检查所有分辨率、alpha及边界，防止枪械截断；源模型哈希见manifest.json。未修改运行时和源模型，本轮付费调用0。

复现：Blender --background --python-exit-code 1 --python tools/hunyuan_export/render.py，然后uv run --with pillow python tools/hunyuan_export/package.py。只导出图片，不保存回模型。
''')
Z=R/'artifacts/exports/hunyuan-rifle-input.zip';Z.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(Z,'w',zipfile.ZIP_DEFLATED) as z:
 for v in m['views']:
  for key in ['rgba','white_background']:z.write(D/v[key],v[key])
 for name in ['manifest.json','README.md']:z.write(D/name,name)
assert hashlib.sha256((R/m['source']).read_bytes()).hexdigest()==m['source_sha256']
print('EXPORT_CHECKED 7 white + 7 transparent PNGs; no clipped silhouettes;',Z)
