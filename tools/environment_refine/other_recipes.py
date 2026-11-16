"""C/D/E precision recipes. Constructed with the same frozen pair/UV contract."""
import math

def configure(namespace):globals().update({k:namespace[k] for k in ['box','cyl','bolt','tube','group']})

def beam(name,a,b,width=.08,kind='dark'):
 from mathutils import Vector
 d=Vector(b)-Vector(a);mid=(Vector(a)+Vector(b))*.5
 box(name,mid,(width,width,d.length),kind,.006,Vector((0,0,1)).rotation_difference(d.normalized()).to_euler())

def deck(ramp=False):
 if not ramp:
  for y in [-3.5,-2.5,-1.5,-.5,.5,1.5,2.5,3.5]:
   for x in [-.90,.90]:
    box('ServicePlate',(x,y,2.35),(1.78,.984,.1),'tread',.004)
    for xx in [-.76,.76]:bolt((x+xx,y-.36,2.402),(0,0,1),.024)
  for x in [-1.90,1.90]:box('EdgeBeam',(x,0,2.30),(.18,8,.18),'dark',.008)
 else:
  angle=math.atan(.3);n=(0,-math.sin(angle),math.cos(angle))
  for y in [-5.5,-4.5,-3.5,-2.5,-1.5,-.5,.5,1.5,2.5,3.5,4.5,5.5]:
   slope=y<2;h=(y+6)*.3 if slope else 2.4;ang=angle if slope else 0
   for x in [-.90,.90]:
    box('RampPlate',(x,y+.05*math.sin(ang),h-.05*math.cos(ang)),(1.78,math.hypot(1,.3)-.016 if slope else .984,.1),'tread',.004,(ang,0,0))
    for xx in [-.76,.76]:bolt((x+xx,y,h+.003),n if slope else (0,0,1),.024)
  for x in [-1.90,1.90]:
   box('SlopedBeam',(x,-2+.09*math.sin(angle),1.2-.09*math.cos(angle)),(.18,math.hypot(8,2.4),.18),'dark',.008,(angle,0,0))
   box('PlatformBeam',(x,4,2.30),(.18,4,.18),'dark',.008)

def side(ramp,sign):
 x=sign*1.84;ys=[-3.65,0,3.65] if not ramp else [-5.65,-3,0,2,5.65]
 height=lambda y:min(2.4,(y+6)*.3) if ramp else 2.4
 for y in ys:
  z=height(y)
  box('GuardPost',(x,y,z+.47),(.085,.085,.94),'dark',.008)
  box('PostSocket',(x,y,z+.055),(.18,.18,.11),'steel',.005)
  bolt((x-sign*.055,y,z+.13),(-sign,0,0))
 segments=[(-4,4,2.4,2.4)] if not ramp else [(-6,2,0,2.4),(2,6,2.4,2.4)]
 for ya,yb,za,zb in segments:
  for dz in [.52,.95]:beam('GuardRail',(x,ya,za+dz),(x,yb,zb+dz),.07,'coat')
  beam('CableTray',(x,ya,za+.17),(x,yb,zb+.17),.14,'dark')
  for offset in [-.04,.04]:
   tube('InsulatedCable',[(x-sign*.07,ya+.05,za+.21+offset),(x-sign*.07,(ya+yb)/2,(za+zb)/2+.21+offset),(x-sign*.07,yb-.05,zb+.21+offset)],.018,'rubber')
 for y in ([-3.6,3.6] if not ramp else [2.3,5.5]):
  z=height(y)-.15
  box('EdgeSupport',(sign*1.85,y,z/2),(.24,.27,z),'dark',.012)
  box('Foot',(sign*1.85,y,.045),(.29,.40,.09),'steel',.006)
  bolt((sign*1.85,y-.12,.095),(0,0,1))
  inward=-1 if y>0 else 1
  beam('CornerBrace',(sign*1.85,y,z-.65),(sign*1.85,y+inward*.6,z),.08,'steel')
 # Separate inset light housings; emissive lenses are attached at runtime.
 for y in ([-2,2] if not ramp else [-4,0,4]):
  z=height(y)+.17;ang=math.atan(.3) if ramp and y<2 else 0
  box('BlueHousing',(sign*1.92,y,z),(.10,1.35,.10),'dark',.009,(ang,0,0))

def walkway(ramp):
 group('Deck',lambda:deck(ramp),.008)
 for sign in [-1,1]:group('Services'+str(sign),lambda sign=sign:side(ramp,sign),.012)

def e_base():
 box('Foundation',(0,0,.21),(2,2,.42),'dark',.018)
 box('ControlBox',(0,0,.99),(1.18,1.15,1.10),'coat',.018)
 box('DoorSeal',(0,-.587,1.0),(1.05,.02,.92),'rubber',.005)
 box('Door',(0,-.608,1.0),(1.00,.025,.87),'coat',.008)
 for x in [-.44,.44]:
  for z in [.62,1.38]:bolt((x,-.63,z))
 box('Handle',(.33,-.65,.98),(.06,.07,.20),'steel',.008)
 for x in [-.65,.65]:
  for y in [-.65,.65]:
   box('Foot',(x,y,.47),(.33,.33,.1),'steel',.008)
   bolt((x,y,.53),(0,0,1),.04)

def e_frame():
 for x in [-.65,.65]:
  for y in [-.65,.65]:box('MastLeg',(x,y,4.70),(.14,.14,8.58),'coat',.012)
 for z in [1.6,3.6,5.6,7.6,8.9]:
  for y in [-.65,.65]:box('CollarBeam',(0,y,z),(1.47,.15,.12),'dark',.007)
  for x in [-.65,.65]:box('CollarSide',(x,0,z),(.15,1.47,.12),'dark',.007)
 for i in range(4):
  lo=1.65+i*1.80;hi=lo+1.65
  for side in [-1,1]:
   beam('XBrace',(-.65,side*.65,lo),(.65,side*.65,hi),.065)
   beam('XBrace',(.65,side*.65,lo),(-.65,side*.65,hi),.065)
   beam('XBrace',(side*.65,-.65,lo),(side*.65,.65,hi),.065)
   beam('XBrace',(side*.65,.65,lo),(side*.65,-.65,hi),.065)
  for x in [-.65,.65]:
   for y in [-.65,.65]:
    box('Gusset',(x,y,lo),(.21,.21,.20),'steel',.005)
    bolt((x,y-.11,lo),(0,-1,0))

def e_head():
 box('Head',(0,0,9.12),(1.7,1.7,.42),'coat',.018)
 cyl('AerialMast',(0,0,11.6),.105,4.7,'steel')
 for z,w in [(9.8,3.8),(11.3,2.8),(12.6,1.8)]:
  box('Boom',(0,0,z),(w,.14,.12),'dark',.007)
  cyl('Clamp',(0,0,z),.15,.18,'steel')
  for side in [-1,1]:
   x=side*(w/2-.15)
   box('Antenna',(x,0,z+.37),(.30,.72,.82),'coat',.014)
   box('AntennaBack',(x,.37,z+.37),(.22,.035,.7),'dark',.006)
   tube('Feeder',[(x,.40,z+.2),(x,.48,z),(side*.20,.48,z-.12),(.15,.25,z-.4)],.023,'rubber')
 box('BeaconBase',(0,0,13.94),(.40,.40,.09),'dark',.01)

def e_cables():
 for x in [-.45,.45]:
  tube('MastCable',[(x,.67,1.2),(x,.67,4.5),(x,.67,8.9),(x,.2,9.3)],.033,'rubber')
  for z in [2,3.8,5.6,7.4,8.7]:
   box('CableClip',(x,.69,z),(.13,.10,.045),'steel',.003)
   bolt((x,.75,z),(0,1,0),.02)

def signal():
 group('Base',e_base);group('Lattice',e_frame,.009);group('Antenna',e_head,.012);group('Feeders',e_cables,.008)
