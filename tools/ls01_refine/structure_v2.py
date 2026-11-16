"""ML09 structure recipe, executed in build.py's geometry/material context.
Real silhouette/facet changes exist on both high and low; shallow recesses on highs.
"""
def side_plate(name,yz,x0,x1,kind):
 ob=profile(name,yz,x1-x0,kind)
 for v in ob.data.vertices:v.co.x+=(x0+x1)/2
 return ob

def section_shell(name,sections,kind):
 # Octagonal cross sections: broad manufactured chamfer is an explicit face band.
 verts=[]
 for y,w,z0,z1,c in sections:
  verts += [(x,y,z) for x,z in [(-w+c,z0), (w-c,z0),(w,z0+c),(w,z1-c),(w-c,z1),(-w+c,z1),(-w,z1-c),(-w,z0+c)]]
 faces=[tuple(range(7,-1,-1)),tuple(range((len(sections)-1)*8,len(sections)*8))]
 for j in range(len(sections)-1):
  for i in range(8):faces.append((j*8+i,j*8+(i+1)%8,(j+1)*8+(i+1)%8,(j+1)*8+i))
 return mesh(name,verts,faces,kind)

pair(profile('T03_ReceiverShell',[(-.027,.026),(-.027,.088),(.005,.118),(.255,.118),(.310,.086),(.310,.025),(.285,.014),(.012,.014)],.108,'white'),'body',.0012,.0018,receiver_seams)
# Substantial chamfer bands: not the tiny bevel modifier, not a painted bright line.
pair(section_shell('T08_StockShell',[(-.208,.037,-.065,.090,.009),(-.182,.039,-.069,.102,.010),(-.072,.037,-.032,.102,.009),(-.034,.032,.008,.072,.008)],'white'),'body',.0007)
# Complementary white/black stepped fingers behind the receiver.
for side in [-1,1]:
 x0,x1=sorted([side*.029,side*.042])
 pair(side_plate('StockJointInsert%d'%side,[(-.072,.019),(-.042,.019),(-.018,.043),(-.018,.079),(-.035,.099),(-.051,.085),(-.038,.071),(-.038,.049)],x0,x1,'dark'),'body',.0006)
 x0,x1=sorted([side*.032,side*.040])
 pair(side_plate('StockJointTongue%d'%side,[(-.077,.040),(-.054,.028),(-.041,.048),(-.041,.069),(-.058,.086),(-.076,.092)],x0,x1,'white'),'body',.0006)
# Cell retains ML06 silhouette and articulated end-cap; segment seams are real gaps.
pair(section_shell('T04_EnergyCell',[(.194,.046,-.086,-.018,.006),(.205,.055,-.098,-.012,.006),(.344,.055,-.098,-.012,.006),(.366,.052,-.091,-.016,.006)],'orange'),'body',.0008,.002,dents)
pair(section_shell('Cell_EndCap',[(.368,.050,-.089,-.017,.006),(.393,.049,-.084,-.020,.007),(.402,.040,-.072,-.027,.006)],'orange'),'body',.00075)
pair(profile('Cell_EndSeal',[(.364,-.087),(.369,-.087),(.369,-.018),(.364,-.018)],.099,'rubber'),'body',.0004)
# Three top cover segments with small open seams and recessed service pockets.
for i,(y0,y1) in enumerate([(.202,.253),(.255,.310),(.312,.360)]):
 def pocket(hi,y0=y0,y1=y1):
  if i!=1:
   boolean(hi,box('cover-pocket',(0,(y0+y1)/2,-.011),(.069,(y1-y0)*.5,.003),'black'))
 pair(box('Cell_TopCover%d'%i,(0,(y0+y1)/2,-.013),(.097,y1-y0,.006),'orange'),'body',.00065,.0015,pocket)
# Thin split side skins follow same silhouette; grooves don't erase housing profile.
for side in [-1,1]:
 x0,x1=sorted([side*.0545,side*.0570])
 def cell_grooves(hi,side=side):
  for y in [.246,.255,.264]:
   cut=box('diagonal deboss',(side*.057,y,-.051),(.002,.0018,.021),'black');
   # Rotate in the side plane around the cutter centre.
   centre=Vector((side*.057,y,-.051));mat=Matrix.Translation(centre)@Matrix.Rotation(-.72,4,'X')@Matrix.Translation(-centre)
   cut.matrix_world=mat;boolean(hi,cut)
  for y in [.218,.335]:boolean(hi,box('corner service recess',(side*.057,y,-.028),(.003,.014,.004),'black'))
 name='T11_CellSide' if side==1 else 'Cell_LeftSkin'
 pair(side_plate(name,[(.205,-.024),(.215,-.019),(.347,-.019),(.356,-.030),(.356,-.081),(.344,-.090),(.215,-.090),(.205,-.079)],x0,x1,'orange'),'body',.0005,.0015,cell_grooves)
 # Lower latch, moulded edge and dark retaining slot, kept in magazine animation.
 pair(box('Cell_LatchSeat%d'%side,(side*.0577,.345,-.073),(.002,.018,.038),'dark'),'body',.0005)
 pair(box('Cell_Latch%d'%side,(side*.060,.345,-.072),(.004,.013,.032),'orange'),'body',.00065)
 pair(box('Cell_LatchNotch%d'%side,(side*.0623,.345,-.081),(.0008,.004,.007),'dark'),'body',.00015)
 for y in [.253,.310]:pair(box('Cell_SegmentSeam%d_%s'%(side,y),(side*.0572,y,-.034),(.0007,.0008,.025),'dark'),'body',.00015)
# Existing top rail proportions, plus sight-specific fore and aft mounts.
pair(profile('T07_TopRail',[(.195,.108),(.210,.132),(.490,.132),(.530,.112),(.530,.092),(.205,.092)],.075,'dark'),'body',.0007)
for i in range(6):pair(box('RailLug%02d'%i,(0,.230+i*.044,.135),(.087,.030,.008),'dark'),'body',.00065)
# Eight actual corners; tapered sides, lower corner bevels, shallow front/back cuts.
outer=[(-.048,.110),(-.060,.123),(-.053,.199),(-.041,.216),(.041,.216),(.053,.199),(.060,.123),(.048,.110)]
inner=[(-.041,.123),(-.047,.131),(-.041,.187),(-.033,.201),(.033,.201),(.041,.187),(.047,.131),(.041,.123)]
verts=[]
for y,scale in [(.043,.97),(.047,1.0),(.067,1.0),(.071,.97)]:
 for loop in [outer,inner]:
  verts.extend([(x*scale,y,.163+(z-.163)*scale) for x,z in loop])
faces=[]
for k in range(3):
 for i in range(8):
  j=(i+1)%8;a=k*16;b=(k+1)*16
  faces.extend([(a+i,a+j,b+j,b+i),(a+8+i,b+8+i,b+8+j,a+8+j)])
for k in [0,3]:
 for i in range(8):
  j=(i+1)%8;a=k*16;faces.append((a+i,a+8+i,a+8+j,a+j))
pair(mesh('T05_Optic',verts,faces,'dark'),'body',.0005)
pair(box('OpticFoot',(0,.061,.107),(.085,.110,.014),'dark'),'body',.0007)
for end,ys in [('Rear',[.009,.021,.033]),('Front',[.083,.095,.107])]:
 for i,y in enumerate(ys):pair(box('OpticMount%sFin%d'%(end,i),(0,y,.119+i*.001),(.077,.007,.013),'dark'),'body',.0005)
# Open front shroud: annular octagonal collar, side struts and open coil window.
# It replaces the old fused shell without adding a filled box across the coil.
outer_loop=[(-.031,-.038),(-.054,-.016),(-.054,.105),(-.031,.132),(.031,.132),(.054,.105),(.054,-.016),(.031,-.038)]
inner_loop=[(-.025,-.022),(-.043,-.008),(-.043,.097),(-.025,.117),(.025,.117),(.043,.097),(.043,-.008),(.025,-.022)]
v=[(x,y,z) for y in [.516,.565] for loop in [outer_loop,inner_loop] for x,z in loop];f=[]
for i in range(8):
 j=(i+1)%8;f.extend([(i,j,j+16,i+16),(i+8,i+24,j+24,j+8),(i,i+8,j+8,j),(i+16,j+16,j+24,i+24)])
pair(mesh('T01_FrontShroud',v,f,'white'),'body',.001)
for side in [-1,1]:
 x0,x1=sorted([side*.043,side*.054])
 pair(side_plate('ShroudLowerStrut%d'%side,[(.404,-.025),(.420,-.037),(.550,-.037),(.550,-.022),(.435,-.022),(.419,-.010)],x0,x1,'dark'),'body',.0007)
 pair(side_plate('ShroudUpperStrut%d'%side,[(.410,.112),(.536,.112),(.552,.100),(.552,.123),(.529,.134),(.410,.134)],x0,x1,'white'),'body',.0007)
 pair(box('ShroudInnerRail%d'%side,(side*.0485,.472,.016),(.009,.094,.006),'dark'),'body',.0005)
 # Narrow bare-metal ribs catch ring light; real gaps reveal the coil.
 for i,y in enumerate([.435,.473,.511]):
  pair(side_plate('ShroudRib%d_%d'%(side,i),[(y,-.021),(y+.006,-.021),(y+.012,.006),(y+.006,.018),(y,.012),(y+.005,-.008)],x0,x1,'steel'),'body',.0005)
 pair(side_plate('T14_FrontBracket%d'%side,[(.528,-.030),(.553,-.030),(.553,.024),(.544,.024),(.544,-.019),(.528,-.019)],x0,x1,'dark'),'body',.0006)
# Exposed front collar fasteners have supported seats, generated and baked in place.
for side in [-1,1]:
 for i,z in enumerate([.006,.082]):screw('ShroudBolt%d_%d'%(side,i),(side*.055,.553,z),(side,0,0),'body',.0025)

# End coupling sleeves the retained coil termination inside the new collar.
pair(cylinder('CoilTerminalCoupling',(0,.520,.055),.0445,.066,(0,1,0),'dark',32),'body',.0007)
