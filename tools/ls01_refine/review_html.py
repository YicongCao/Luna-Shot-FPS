from pathlib import Path
import html,json
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/ls01-refine-v1'
sections=[('同机位：中性光','studio-0.png'),('同机位：暖色掠射','studio-1.png'),('同机位：冷色逆光','studio-2.png'),('受控几何灰模','clay.png'),('橙色弹夹近景','magazine.png'),('屏框／管线／字标','kit-close.png'),('反面检查','reverse.png'),('六边形屏框与四颗螺钉','screen-close.png'),('十字槽近景','screw-close.png'),('前罩紧固件','front-fasteners.png'),('前罩反面','front-fasteners-reverse.png'),('训练场第一人称','ammo-13.png'),('开镜红点','ads.png')]
css='body{background:#121821;color:#dbe7ee;font:16px system-ui;margin:32px}h1{font-size:28px}section{margin:38px 0} .pair{display:grid;grid-template-columns:1fr 1fr;gap:16px}img{width:100%;border:1px solid #526171}figure{margin:0}figcaption{padding:10px}a{color:#6ae3ef}table{border-collapse:collapse}td,th{padding:10px;border:1px solid #526171} @media(max-width:800px){.pair{grid-template-columns:1fr}}'
body='<h1>LS01 · ML07 原生 Godot 对照</h1><p>所有画面为本机 Godot Compatibility 渲染。左为 ML06 基线，右为本轮候选；同相机、灯光、曝光。材料台关闭 Bloom。功能通过与视觉结论分开记录，最终状态见 REPORT.md。</p><p><a href="REPORT.md">验收报告</a> · <a href="geometry-audit.json">几何／UV 审计</a> · <a href="runtime-audit.json">保留件与环境审计</a> · <a href="bake-audit.json">烘焙通道检查</a></p>'
body+='<section><h2>目标概念（非实机）</h2><img style="max-width:1000px" src="../../research/weapon-material-review-2026-11-15/concept.png"><p>概念与实机不等价；剩余差距见报告，不能用下方功能检查代替还原验收。</p></section>'
for title,name in sections:
 if not (D/name).exists():continue
 body+=f'<section><h2>{html.escape(title)}</h2><div class="pair">'
 for phase,label in [('before/','ML06 基线'),('','ML07 候选')]:
  if (D/(phase+name)).exists():body+=f'<figure><img loading="lazy" src="{phase+name}"><figcaption>{label}</figcaption></figure>'
 body+='</div></section>'
body+='<section><h2>主体 2K / 4K 同镜头：十字槽分辨率</h2><div class="pair"><figure><img src="resolution-study/2k/screw-close.png"><figcaption>2K：槽口过软</figcaption></figure><figure><img src="screw-close.png"><figcaption>4K 主体法线 + 2K 底色/ORM + GPU 压缩：最终版本</figcaption></figure></div></section>'
body+='<section><h2>材质通道与掠射光</h2><div class="pair">'
for p in sorted(D.glob('magazine-channel-*.png')):body+=f'<figure><img loading="lazy" src="{p.name}"><figcaption>{p.stem}</figcaption></figure>'
body+='</div></section>'
(D/'review.html').write_text('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>LS01 ML07 实机对照</title><style>'+css+'</style><body>'+body+'</body></html>')
