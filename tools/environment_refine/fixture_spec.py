"""Local Godot Y-up mounts; lenses and spill share a single specification."""
import math
def fixtures(asset):
 if asset in ['B1','B2']:return [{'kind':'red','position':[x,5.82,z]} for x in [-1.5,1.5] for z in [-1.5,1.5]]
 if asset in ['C','D']:
  result=[]
  for side in [-1,1]:
   for z in ([-2,2] if asset=='C' else [-4,0,4]):
    slope=asset=='D' and z>-2;h=(6-z)*.3 if slope else 2.4
    result.append({'kind':'blue','position':[side*1.978,h+.17,z],'rotation_x':math.atan(.3) if slope else 0,'side':side})
  return result
 return [{'kind':'amber','position':[0,14.075,0]}]
