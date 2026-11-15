import bpy,numpy as np
from pathlib import Path
R=Path(__file__).resolve().parents[2];N=2048
p=R/'assets/weapons/lc01/ORM.png';im=bpy.data.images.load(str(p));im.colorspace_settings.name='Non-Color';ar=np.empty(N*N*4,np.float32);im.pixels.foreach_get(ar);ar=ar.reshape(-1,4)
ao=bpy.data.images.load(str(R/'art_source/weapons/lc01/industrial-wear-v1/05-bake/AO.png'));ao.colorspace_settings.name='Non-Color';data=np.empty(N*N*4,np.float32);ao.pixels.foreach_get(data);ar[:,0]=np.clip(data.reshape(-1,4)[:,0],.15,1);im.pixels.foreach_set(ar.ravel());im.filepath_raw=str(p);im.file_format='PNG';im.save()
