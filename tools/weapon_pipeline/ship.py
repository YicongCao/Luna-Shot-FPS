import bpy,shutil
from pathlib import Path
import os
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'art_source/weapons/lc01'/os.environ.get('LC01_PIPELINE','pipeline-v1');DEST=ROOT/'assets/weapons/lc01'
bpy.ops.wm.open_mainfile(filepath=str(BASE/'07-final/lc01-final.blend'))
bpy.ops.export_scene.gltf(filepath=str(DEST/'lc01.glb'),export_format='GLB',export_materials='NONE',export_yup=True,export_extras=True)
for name in ['BaseColor','NormalGL','ORM','Emission']:shutil.copyfile(BASE/'07-final/textures'/f'{name}.png',DEST/f'{name}.png')
(BASE/'.gdignore').touch()
print('SHIPPED')
