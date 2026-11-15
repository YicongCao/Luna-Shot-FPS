from scene_builder import Scene, ROOT
import math,json
# Gun modules use rear-to-front local -Z. Grip top datum (0,0,0). Visual-only dimensions.
g=Scene('LC01_Whitebox')
parts=[('P01_Chassis',(0,.055,-.17),(.085,.12,.50),'mid'),('P02_LeftShell',(-.058,.085,-.13),(.035,.14,.35),'light'),('P03_RightShell',(.058,.085,-.13),(.035,.14,.35),'light'),('P04_ForeShroud',(0,.065,-.47),(.14,.14,.23),'chalk'),('P05_Stock',(0,.025,.16),(.12,.18,.16),'chalk'),('P06_Grip',(0,-.09,.015),(.075,.18,.085),'dark'),('P07_Cell',(0,-.095,-.15),(.09,.20,.12),'mid'),('P08_SightBase',(0,.17,-.12),(.08,.025,.105),'dark'),('P09_SightLeft',(-.044,.215,-.12),(.012,.075,.07),'chalk'),('P09_SightRight',(.044,.215,-.12),(.012,.075,.07),'chalk'),('P09_SightTop',(0,.2525,-.12),(.10,.012,.07),'chalk'),('P10_TriggerGuard',(0,-.055,-.055),(.025,.025,.065),'mid')]
for name,pos,size,mat in parts:g.box(name,pos,size,mat,solid=False)
g.cyl('P11_Muzzle',(0,.065,-.625),.044,.08,'mid',solid=False,rot=(math.pi/2,0,0))
for i in range(3):g.cyl('P12_Coil'+str(i),(0,.065,-.31-i*.043),.073,.018,'dark',solid=False,rot=(math.pi/2,0,0))
for name,pos in [('MuzzleSocket',(0,.065,-.67)),('SightRear',(0,.216,-.07)),('SightFront',(0,.216,-.17)),('GripR',(0,-.08,.015)),('GripL',(0,-.035,-.43)),('CellSocket',(0,-.04,-.15))]:g.node(name,'Marker3D',props=f'position = {v(pos)}')
g.save('assets/whitebox/lc01.tscn')
(ROOT/'docs/design/rifle-blockout-parts.json').write_text(json.dumps(g.inventory,indent=2)+'\n')
print('Built legacy LC01 whitebox only')
