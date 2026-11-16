"""Record native Godot light cycles; MovieMaker output is not a timing benchmark."""
import os,re,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2];tmp=R/'artifacts/ml15/video';tmp.mkdir(parents=True,exist_ok=True)
for asset,name in [('B1','red-cycle'),('D','blue-closeup'),('E','beacon-cycle')]:
 env=os.environ|{'ENV_ASSET':asset,'ENV_PHASE':'final-video'}
 raw=tmp/f'{asset}-final.avi';log=tmp/f'{asset}-final.log'
 with log.open('w') as f:subprocess.run([os.environ.get('GODOT_BIN','godot'),'--path',str(R),'--fixed-fps','60','--write-movie',str(raw),'--script','tools/environment_refine/capture.gd','--','--demo'],env=env,stdout=f,stderr=subprocess.STDOUT,check=True)
 text=log.read_text();assert 'ERROR:' not in text and ' false' not in text,log
 start=int(re.search(r'DEMO_START_FRAME (\d+)',text)[1]);end=int(re.search(r'DEMO_END_FRAME (\d+)',text)[1]);assert end-start==300
 dest=R/f'docs/validation/environment-refine-v2/{asset}/{name}.mp4'
 subprocess.run(['ffmpeg','-y','-loglevel','error','-ss',str(start/60),'-i',str(raw),'-t','5','-an','-c:v','libx264','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(dest)],check=True)
 print('VIDEO',asset,str(dest),flush=True)
