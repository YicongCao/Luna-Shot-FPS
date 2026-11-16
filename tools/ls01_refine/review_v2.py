"""Portable native evidence gallery; no synthetic renders substituted."""
from pathlib import Path
import html,json
R=Path(__file__).resolve().parents[2];D=R/'docs/validation/ls01-refine-v2'
views={'hero':'整体','magazine':'弹夹右侧','magazine-reverse':'弹夹左侧','magazine-rig-1':'弹夹掠射光','stock':'枪托与双棱','stock-reverse':'枪托反侧','joint':'黑白斜接','optic':'瞄具正面','optic-side':'瞄具前后鳍片','optic-front':'瞄具背面','screen':'异形屏框','screen-side':'屏幕嵌入','coil':'护罩与线圈','coil-reverse':'护罩反侧'}
s='''<!doctype html><meta charset="utf-8"><title>ML09 原生 Godot 对比</title><style>body{font:16px system-ui;background:#111821;color:#dce5ee;margin:24px}h1{font-size:28px}nav{position:sticky;top:0;background:#18222e;padding:12px;z-index:2}button,select{font:inherit;margin:4px;padding:7px;background:#263747;color:white;border:1px solid #62798b}main{display:grid;grid-template-columns:repeat(3,1fr);gap:12px}figure{margin:0}img{width:100%;background:black}a{color:#60d9ed}.wide{max-width:1600px}small{color:#a4bac9}@media(max-width:900px){main{grid-template-columns:1fr}}</style><h1>ML09 — 枪械结构还原与侧向照明</h1><p>以下均为 Godot 4.7.2 Compatibility 原生截图，1600×1000，同镜头/曝光。结构对比关闭能量与 Bloom。2026-11-16 用户比较三版实机后选择 ML06，默认已回滚 ML06。ML07/ML09 保留对照；以下为当时实施证据，不代表用户认可其视觉升级。</p><p><a href="REPORT.md">检查报告</a> · <a href="../../research/weapon-material-review-2026-11-15/concept.png">目标概念（非实机）</a></p><nav><label>结构视图 <select id="feature">'''
for k,v in views.items():s+=f'<option value="{k}">{html.escape(v)}</option>'
s+='</select></label></nav><main>'
for rev in ['ml06','ml07','ml09']:s+=f'<figure><h2>{rev.upper()}</h2><a id="link-{rev}" href="{rev}-pbr-hero.png"><img id="{rev}" src="{rev}-pbr-hero.png"></a></figure>'
s+='''</main><h2>ML09 灰模</h2><figure class="wide"><a id="clay-link" href="ml09-clay-hero.png"><img id="clay" src="ml09-clay-hero.png"></a></figure><h2>侧向补光：同曝光，关闭Bloom</h2>'''
for side in [-1,1]:
 s+='<main style="grid-template-columns:1fr 1fr">'
 for state in ['off','on']:s+=f'<figure><p>侧面 {side} · {state}</p><a href="spill-{side}-{state}.png"><img loading="lazy" src="spill-{side}-{state}.png"></a></figure>'
 s+='</main>'
s+='<h2>真实遮挡检查</h2><p>同一只投影、不显示表面的挡板；只切换Spot阴影，检查下游表面照明差异。</p><main style="grid-template-columns:1fr 1fr">'
for state in ['on','off']:s+=f'<figure><p>阴影 {state}</p><img loading="lazy" src="spill-blocker-shadow-{state}.png"></figure>'
s+='</main><h2>实际第一人称</h2><main>'
for name in ['ammo-13','ads','lighting/42-ultrawide']:s+=f'<figure><p>{name}</p><a href="{name}.png"><img loading="lazy" src="{name}.png"></a></figure>'
s+='''</main><script>document.querySelector('#feature').onchange=e=>{let f=e.target.value;for(let r of ['ml06','ml07','ml09']){let p=r+'-pbr-'+f+'.png';document.getElementById(r).src=p;document.getElementById('link-'+r).href=p}let c='ml09-clay-'+(f.startsWith('magazine-rig')?'magazine':f)+'.png';document.querySelector('#clay').src=c;document.querySelector('#clay-link').href=c}</script>'''
(D/'review.html').write_text(s)
