"""Protection tests: reject geometry/UV edits while allowing index reorder and scale normalization."""
import numpy as np
from audit import compare

def main():
 a={'POSITION':np.array([[0,0,0],[1,0,0],[0,1,0],[2,0,0],[3,0,0],[2,1,0]],float),'NORMAL':np.tile([0.,0.,1.],(6,1)),'TEXCOORD_0':np.array([[0,0],[.4,0],[0,.4],[.5,.5],[.9,.5],[.5,.9]])}
 ai=np.array([[0,1,2],[3,4,5]]);bi=np.array([[4,5,3],[2,0,1]]);center=np.array([1.,.5,0]);scale=.5
 b={k:v.copy() for k,v in a.items()};b['POSITION']=(a['POSITION']-center)*scale
 r=compare(a,ai,b,bi,scale,center);assert r['geometry_preserved'] and r['uv']['max']==0
 c={k:v.copy() for k,v in b.items()};c['POSITION'][0,2]+=.01;r=compare(a,ai,c,bi,scale,center);assert not r['geometry_preserved']
 c={k:v.copy() for k,v in b.items()};c['TEXCOORD_0'][0,0]+=.01;r=compare(a,ai,c,bi,scale,center);assert r['geometry_preserved'] and r['uv']['corners_above_tolerance']>0
 r=compare(a,ai,b,bi[:,::-1],scale,center);assert not r['geometry_preserved']
 c={k:v.copy() for k,v in b.items()};c['NORMAL'][0]=[0,1,0];r=compare(a,ai,c,bi,scale,center);assert r['normals']['corners_above_tolerance']>0
 print('5 protection cases passed: reordering, shape edit, UV edit, reversed winding, normal edit')
if __name__=='__main__':main()
