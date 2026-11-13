"""Reproducible vertex-painted hobbit. Blender 5.3 --background --python this_file.
Helpers use Godot Y-up, +Z-forward; original animation pivots are preserved.
"""
from pathlib import Path
import math, random, json, struct
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=ROOT/'assets/characters/hobbit.glb'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
def coord(v): return (v[0],-v[2],v[1])
def material(name,rgb):
 # Garment pigments are vertex colours; one shared shader means one draw per limb.
 m=bpy.data.materials.get('Painted adventure cloth and skin')
 if m is None:
  m=bpy.data.materials.new('Painted adventure cloth and skin'); m.use_nodes=True
  m.node_tree.nodes.clear()
  bsdf=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
  output=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
  m.node_tree.links.new(bsdf.outputs['BSDF'],output.inputs['Surface'])
  bsdf.inputs['Roughness'].default_value=.91
  col=m.node_tree.nodes.new('ShaderNodeVertexColor'); col.layer_name='Paint'
  m.node_tree.links.new(col.outputs['Color'],bsdf.inputs['Base Color'])
  # glTF exporter preserves COLOR_0 alpha only when the material consumes it.
  # Godot replaces this imported material with an opaque shader; alpha is data.
  m.node_tree.links.new(col.outputs['Alpha'],bsdf.inputs['Alpha'])
 return m,rgb
skin=material('Painted warm skin',(.66,.40,.25))
shirt=material('Weathered cream linen',(.66,.57,.40))
vest=material('Burgundy wool waistcoat',(.34,.115,.065))
edge=material('Waistcoat seam piping',(.38,.17,.075))
pants=material('Worn umber breeches',(.20,.135,.071))
cloak=material('Forest green travel cloak',(.075,.19,.085))
trim=material('Cloak embroidered hem',(.135,.22,.092))
hair=material('Chestnut curl shadows',(.10,.043,.019))
hairlight=material('Chestnut curl ridges',(.19,.083,.033))
eye=material('Iris dark brown',(.018,.013,.008))
white=material('Eye warm ivory',(.75,.68,.51))
lip=material('Mouth and ear shadow',(.30,.105,.065))
gold=material('Aged brass',(.45,.28,.075))
leather=material('Oiled belt leather',(.075,.038,.017))
def pivot(name,at,parent=None):
 o=bpy.data.objects.new(name,None); bpy.context.collection.objects.link(o)
 o.parent=parent; o.location=coord(at); return o
def paint(o,mat):
 o['skin_surface']=mat is skin
 m,rgb=mat; o.data.materials.append(m)
 colors=o.data.color_attributes.new(name='Paint',type='BYTE_COLOR',domain='POINT')
 for v,c in zip(o.data.vertices,colors.data):
  x,z,y=v.co
  grain=math.sin(x*109+y*37)*math.sin(z*83-y*71)*.025
  wash=.97+.025*math.sin(y*13+x*5)+.02*math.cos(z*23+x*19)
  wash += .025*math.sin(x*35+y*18)*math.cos(y*19-z*7)
  if mat in (vest,shirt,pants,cloak):
   # Painted broad fold light/shadow and pigment wear, rather than uniform fills.
   wash += .07*math.sin(x*52+y*11)*math.cos(y*16)
   wash *= .84+.16*max(0,v.normal.z)
   if o.name.startswith('LinenSleeve'):
    wash *= 1-.18*math.exp(-((y+.153)/.025)**2)
   if o.name.startswith('Breeches'):
    wash *= 1-.17*math.exp(-((y+.14)/.026)**2)
  if o.name=='SculptedFace':
   front=max(0,min(1,-z/.12))
   cheek=math.exp(-((abs(x)-.105)/.048)**2-((y+.055)/.048)**2)*front
   socket=math.exp(-((abs(x)-.073)/.040)**2-((y-.029)/.031)**2)*front
   beard=math.exp(-((y+.135)/.032)**2)*front
   rgb=skin[1]
   face_rgb=(rgb[0]+.06*cheek,rgb[1]-.045*cheek,rgb[2]-.025*cheek)
   wash *= 1-.23*socket-.10*beard
  else: face_rgb=rgb
  category=.12 if mat is skin else (.92 if mat in (hair,hairlight) else (.55 if mat in (shirt,vest,pants,cloak) else .35))
  c.color=tuple(max(0,min(1,a*(wash+grain))) for a in face_rgb)+(category,)
 for p in o.data.polygons: p.use_smooth=True
 return o
def mesh(name,verts,faces,mat,parent):
 d=bpy.data.meshes.new(name); d.from_pydata([coord(v) for v in verts],[],faces); d.update()
 o=bpy.data.objects.new(name,d); bpy.context.collection.objects.link(o); o.parent=parent
 return paint(o,mat)
def loft(name,profiles,mat,parent,n=20,folds=0):
 verts=[]
 for profile in profiles:
  y,w,d,z=profile[:4]; cx=profile[4] if len(profile)>4 else 0
  for i in range(n):
   a=i*math.tau/n; f=1+folds*math.sin(a*7+y*4)
   verts.append((cx+math.sin(a)*w*f,y,z+math.cos(a)*d*f))
 faces=[]
 for r in range(len(profiles)-1):
  for i in range(n):
   a=r*n+i; b=r*n+(i+1)%n; faces.append((a,b,b+n,a+n))
 faces += [tuple(reversed(range(n))),tuple((len(profiles)-1)*n+i for i in range(n))]
 return mesh(name,verts,faces,mat,parent)
def oval(name,at,size,mat,parent,segments=20,rings=12):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings)
 o=bpy.context.object; o.name=name; o.scale=(size[0],size[2],size[1])
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 o.parent=parent; o.location=coord(at); return paint(o,mat)
def strand(name,points,radius,mat,parent,sides=6):
 verts=[]; faces=[]; ps=[Vector(p) for p in points]
 for i,p in enumerate(ps):
  tangent=(ps[min(i+1,len(ps)-1)]-ps[max(i-1,0)]).normalized()
  side=tangent.cross(Vector((0,0,1)))
  if side.length<.01: side=tangent.cross(Vector((0,1,0)))
  side.normalize(); other=tangent.cross(side).normalized(); r=radius*(.5 if i in (0,len(ps)-1) else 1)
  for j in range(sides):
   q=p+r*(side*math.cos(j*math.tau/sides)+other*math.sin(j*math.tau/sides)); verts.append(tuple(q))
 for i in range(len(ps)-1):
  for j in range(sides):
   a=i*sides+j; b=i*sides+(j+1)%sides; faces.append((a,b,b+sides,a+sides))
 faces += [tuple(reversed(range(sides))),tuple((len(ps)-1)*sides+j for j in range(sides))]
 return mesh(name,verts,faces,mat,parent)
root=pivot('Hobbit',(0,0,0)); torso=pivot('Torso',(0,0,0),root)
loft('TailoredWaistcoat',[(.44,.18,.135,0),(.48,.235,.16,0),(.54,.246,.169,0),(.62,.25,.172,0),(.69,.25,.169,0),(.76,.245,.16,0),(.82,.233,.145,0),(.86,.22,.135,0),(.91,.12,.09,0)],vest,torso,n=40,folds=.038)
loft('Neck',[(.87,.075,.07,.015),(.99,.075,.073,.015)],skin,torso)
mesh('LinenVOpening',[(-.095,.90,.112),(.095,.90,.112),(-.079,.86,.149),(.079,.86,.149),(-.056,.80,.174),(.056,.80,.174),(-.023,.74,.184),(.023,.74,.184),(0,.708,.186)],[(0,1,3,2),(2,3,5,4),(4,5,7,6),(6,7,8)],shirt,torso)
for s in (-1,1):
 mesh('FoldedShirtCollar',[(s*.012,.906,.097),(s*.09,.925,.09),(s*.135,.868,.128),(s*.059,.832,.155)],[(0,1,2,3)],shirt,torso)
 strand('WaistcoatOpening',[(s*.106,.89,.104),(s*.08,.845,.145),(s*.013,.71,.184),(s*.015,.53,.17),(s*.058,.462,.147)],.006,edge,torso)
 strand('SideSeam',[(s*.22,.84,.057),(s*.245,.72,.045),(s*.249,.59,.04),(s*.224,.48,.052)],.003,edge,torso)
 mesh('WaistcoatPocket',[(s*.07,.605,.178),(s*.19,.61,.123),(s*.186,.585,.128),(s*.075,.58,.182)],[(0,1,2,3)],edge,torso)
for y in (.55,.625,.70,.765): oval('BrassButton',(.026,y,.18 if y<.73 else .163),(.010,.010,.006),gold,torso,10,6)
loft('LeatherBelt',[(.455,.231,.164,0),(.491,.243,.174,0)],leather,torso)
for x1,x2,y1,y2 in [(-.037,.037,.459,.468),(-.037,.037,.488,.497),(-.037,-.029,.459,.497),(.029,.037,.459,.497)]:
 mesh('BeltBuckle',[(x1,y1,.166),(x2,y1,.166),(x2,y2,.166),(x1,y2,.166)],[(0,1,2,3)],gold,torso)
for s,suffix in [(-1,'Left'),(1,'Right')]:
 leg=pivot('Leg'+suffix,(s*.145,.43,0),root)
 loft('Breeches'+suffix,[(-.17,.088,.092,0),(-.13,.106,.108,0),(-.02,.115,.12,0),(.058,.113,.12,0)],pants,leg,folds=.035)
 loft('BreechesCuff'+suffix,[(-.177,.091,.095,0),(-.151,.095,.10,0)],edge,leg)
 loft('Calf'+suffix,[(-.355,.063,.064,.008),(-.27,.070,.075,-.002),(-.19,.079,.078,0),(-.145,.074,.072,0)],skin,leg)
 # Heel, low instep and forefoot are separate sections along the foot length.
 verts=[]; faces=[]
 foot_rings=[(-.092,.042,-.404,-.351),(-.055,.070,-.426,-.321),(.022,.086,-.430,-.306),(.105,.106,-.430,-.335),(.19,.113,-.429,-.361),(.235,.098,-.423,-.377)]
 for z,w,sole,top in foot_rings:
  for i in range(16):
   angle=i*math.tau/16
   verts.append((math.sin(angle)*w,(sole+top)/2+math.cos(angle)*(top-sole)/2,z))
 for r in range(len(foot_rings)-1):
  for i in range(16):
   j=r*16+i; k=r*16+(i+1)%16; faces.append((j,j+16,k+16,k))
 faces.extend([tuple(range(16)),tuple(reversed([(len(foot_rings)-1)*16+i for i in range(16)]))])
 mesh('BareFoot'+suffix,verts,faces,skin,leg)
 for i in range(5):
  x=-s*(.077-i*.039); width=.026-i*.0025; z=.250-i*.008
  oval('Toe'+suffix+str(i),(x,-.400,z-.009),(width,.024,.059-i*.005),skin,leg,16,10)
 arm=pivot('Arm'+suffix,(s*.30,.82,0),torso)
 loft('LinenSleeve'+suffix,[(-.186,.052,.056,.043,-s*.012),(-.168,.057,.061,.041,-s*.012),(-.153,.050,.054,.034,-s*.010),(-.137,.059,.063,.026,-s*.013),(-.105,.063,.068,.014,-s*.020),(-.062,.064,.068,.003,-s*.031),(-.015,.066,.068,-.002,-s*.041),(.026,.065,.066,-.003,-s*.060),(.058,.054,.057,-.002,-s*.085),(.078,.032,.037,-.002,-s*.111)],shirt,arm,n=32,folds=.035)
 loft('SleeveCuff'+suffix,[(-.197,.052,.057,.045,-s*.012),(-.191,.057,.061,.043,-s*.012),(-.174,.059,.063,.040,-s*.012),(-.168,.054,.059,.039,-s*.012)],shirt,arm,n=32)
 strand('RolledCuffSeam',[(s*.039,-.185,.046),(s*.026,-.189,.095),(-s*.015,-.191,.103),(-s*.058,-.185,.075)],.0035,edge,arm)
 loft('Forearm'+suffix,[(-.282,.038,.041,.059,s*.008),(-.235,.046,.049,.055,s*.012),(-.18,.054,.056,.034,s*.010)],skin,arm)
 oval('Palm'+suffix,(s*.007,-.296,.061),(.044,.044,.026),skin,arm)
 for finger in range(4):
  x=-.031+finger*.020
  strand('Finger'+suffix+str(finger),[(x,-.303,.065),(x,-.331,.076),(x,-.346+abs(finger-1.5)*.006,.070)],.011 if finger<3 else .009,skin,arm,7)
 strand('Thumb'+suffix,[(-s*.032,-.280,.066),(-s*.055,-.299,.090),(-s*.041,-.319,.099)],.017,skin,arm,8)
 for j in range(2): strand('PalmCrease',[(-.026,-.299-j*.010,.087),(0,-.303-j*.010,.090),(.023,-.299-j*.010,.087)],.0012,lip,arm,4)
# Shoulder-width drape ends above knees, leaving feet visible from behind.
cape_profiles=[(.91,.12,.106),(.88,.24,.17),(.79,.278,.195),(.65,.283,.217),(.50,.276,.235)]
verts=[]
for row,(h,w,d) in enumerate(cape_profiles):
 for j in range(25):
  a=-1.53+j*3.06/24
  verts.append((math.sin(a)*w,h+(.017*math.cos(a*6) if row==4 else 0),-.018-math.cos(a)*d+math.sin(a*7)*.023*(row/4)))
faces=[]
for i in range(4):
 for j in range(24):
  a=i*25+j; faces.append((a,a+25,a+26,a+1))
cape=mesh('ShortTravelCloak',verts,faces,cloak,torso)
solid=cape.modifiers.new('ClothThickness','SOLIDIFY'); solid.thickness=.005
bpy.context.view_layer.objects.active=cape; bpy.ops.object.modifier_apply(modifier=solid.name)
strand('CloakHem',verts[-25:],.006,trim,torso)
for column in (4,8,12,16,20):
 points=[]
 for row in range(1,5):
  x,y,z=verts[row*25+column]; points.append((x,y,z-.004))
 strand('CloakGather',points,.003,trim if column in (4,20) else cloak,torso)
for side in (-1,1):
 strand('BackPanelSeam',[(side*.052,.855,-.189),(side*.106,.738,-.225),(side*.14,.61,-.248),(side*.16,.51,-.252)],.004,trim,torso)
for j in [0,24]: strand('CloakEdge',[verts[i*25+j] for i in range(5)],.005,trim,torso)
mesh('FoldedHood',[(-.11,.91,-.108),(.11,.91,-.108),(.14,.84,-.177),(.08,.74,-.222),(0,.685,-.235),(-.08,.74,-.222),(-.14,.84,-.177),(0,.83,-.22)],[(0,1,7),(1,2,7),(2,3,7),(3,4,7),(4,5,7),(5,6,7),(6,0,7)],trim,torso)
strand('HoodFold',[(-.104,.9,-.119),(0,.855,-.218),(.104,.9,-.119)],.005,cloak,torso)
for s in (-1,1): strand('CloakClasp',[(s*.22,.877,.009),(s*.14,.88,.11),(s*.06,.866,.142)],.008,trim,torso)
oval('LeafBrooch',(0,.867,.145),(.024,.015,.007),gold,torso,12,6)
head=pivot('Head',(0,1.075,.02),torso)
face_profiles=[(-.177,.058,.071,.027),(-.157,.105,.105,.025),(-.126,.143,.123,.018),(-.085,.164,.133,.011),(-.038,.182,.144,0),(.005,.177,.143,-.003),(.05,.175,.144,-.007),(.10,.170,.139,-.012),(.15,.151,.12,-.017),(.19,.105,.089,-.02),(.205,.025,.025,-.024)]
face_profiles=[tuple(a[k]*(1-t)+b[k]*t for k in range(4)) for a,b in zip(face_profiles,face_profiles[1:]) for t in (0,1/3,2/3)]+[face_profiles[-1]]
verts=[]; faces=[]
for y,w,d,zcenter in face_profiles:
 for i in range(64):
  a=i*math.tau/64; x=math.sin(a)*w; front=max(0,math.cos(a))
  cheek=.029*math.exp(-((abs(x)-.109)/.047)**2-((y+.048)/.041)**2)
  socket=.023*math.exp(-((abs(x)-.072)/.034)**2-((y-.029)/.027)**2)
  brow=.016*math.exp(-((abs(x)-.073)/.051)**2-((y-.062)/.022)**2)
  nose=.075*math.exp(-(x/.032)**2-((y+.037)/.037)**2)
  bridge=.026*math.exp(-(x/.023)**2-((y-.013)/.060)**2)
  muzzle=.012*math.exp(-(x/.066)**2-((y+.102)/.034)**2)
  upperlip=.010*math.exp(-(x/.043)**4-((y+.108)/.009)**2)
  lowerlip=.014*math.exp(-(x/.041)**4-((y+.128)/.011)**2)
  mouth=.008*math.exp(-(x/.045)**4-((y+.117)/.006)**2)
  verts.append((x,y,zcenter+math.cos(a)*d+front*(cheek-socket+brow+nose+bridge+muzzle+upperlip+lowerlip-mouth)))
for row in range(len(face_profiles)-1):
 for i in range(64):
  a=row*64+i; b=row*64+(i+1)%64; faces.append((a,b,b+64,a+64))
faces.extend([tuple(reversed(range(64))),tuple((len(face_profiles)-1)*64+i for i in range(64))])
mesh('SculptedFace',verts,faces,skin,head)
for s in (-1,1):
 oval('Ear',(s*.181,.006,-.008),(.052,.075,.034),skin,head)
 oval('EarFold',(s*.206,.005,.018),(.016,.043,.009),lip,head,12,8)
 # A fleshy orbital rim connects eye to cheek and brow, rather than flat eyes.
 lidverts=[]; lidfaces=[]
 for ring in range(4):
  t=ring/3
  for j in range(32):
   a=j*math.tau/32
   lidverts.append((s*.074+math.cos(a)*(.027+t*.014),.027+math.sin(a)*(.015+t*.014),.153-t*.043+.005*math.sin(t*math.pi)))
 for ring in range(3):
  for j in range(32):
   a=ring*32+j; b=ring*32+(j+1)%32; lidfaces.append((a,a+32,b+32,b))
 lid=mesh('OrbitalRim',lidverts,lidfaces,skin,head)
 solid=lid.modifiers.new('LidThickness','SOLIDIFY'); solid.thickness=.005
 bpy.context.view_layer.objects.active=lid; bpy.ops.object.modifier_apply(modifier=solid.name)
 oval('EyeWhite',(s*.074,.027,.136),(.028,.020,.017),white,head)
 oval('Iris',(s*.074,.026,.153),(.011,.013,.003),eye,head,16,10)
 oval('EyeGlint',(s*.071,.031,.157),(.0025,.003,.001),white,head,8,4)
 strand('Eyebrow',[(s*.040,.077,.142),(s*.071,.084,.147),(s*.105,.072,.135)],.009,hair,head)
strand('Smile',[(-.049,-.106,.157),(-.028,-.117,.167),(0,-.120,.168),(.028,-.117,.167),(.049,-.106,.157)],.0026,lip,head)
for side in (-1,1):
 strand('Nostril',[(side*.016,-.057,.197),(side*.026,-.061,.187),(side*.032,-.056,.179)],.003,lip,head)
# Broad overlapping scalp ribbons with incised strand grooves. These are
# flattened swept locks, not round beads or tubes around the head.
def scalp(t,a,extra=0):
 q=t*math.pi*.5
 baseline=.015+.060*math.cos(a)+.009*math.sin(a*7) # shorter fringe, scalloped nape
 y=baseline+(.265-baseline)*math.cos(q)
 radius=math.sin(q)*(.188+extra)
 return (math.sin(a)*radius,y,-.024+math.cos(a)*radius*.85)
verts=[]; faces=[]
for row in range(13):
 for col in range(72): verts.append(scalp(.025+row*.975/12,col*math.tau/72))
for row in range(12):
 for col in range(72):
  a=row*72+col; b=row*72+(col+1)%72; faces.append((a,a+72,b+72,b))
mesh('HairScalp',verts,faces,hair,head)
for lock in range(24):
 verts=[]; faces=[]; base=lock*math.tau/24
 for row in range(17):
  progress=row/16
  t=.04+(.96+.065*math.sin(base*3)+.035*math.cos(base*5))*progress
  curl=max(0,(progress-.65)/.35)
  center=base+.33*math.sin(t*math.pi)-.22*t+.06*math.sin(t*math.tau+base)+.15*math.sin(curl*math.pi*1.6)*curl
  taper=1-.84*max(0,(progress-.76)/.24)
  for col in range(9):
   u=col/8; a=center+(u-.5)*.31*taper
   ridge=math.sin(u*math.pi)*(.006+.002*math.cos(u*math.tau*3))+.012*math.sin(curl*math.pi)
   p=scalp(t,a,.004+ridge)
   # Long curl tips bend away from the scalp without forming spherical knots.
   bend=max(0,(t-.83)/.17)
   verts.append((p[0],p[1]+.012*math.sin(base*3)*bend,p[2]))
 for row in range(16):
  for col in range(8):
   a=row*9+col; faces.append((a,a+9,a+10,a+1))
 obj=mesh('SweptHairLock%02d'%lock,verts,faces,hair,head)
 colors=obj.data.color_attributes['Paint'].data
 for index,c in enumerate(colors):
  u=(index%9)/8; t=(index//9)/16
  # Painted broad highlights and dark incisions travel along the locks.
  highlight=.76+.42*math.sin(u*math.pi)**2+.12*math.cos(u*math.tau*3)
  warm=(.16,.064,.024) if lock%5 else (.20,.082,.031)
  c.color=tuple(channel*highlight*(.88+.12*math.sin(t*math.pi)) for channel in warm)+(.92,)
# Union the skin volumes in each animated part: toes/instep/ankle and
# fingers/palm/forearm become a single continuous, softly sculpted surface.
for group in (head,bpy.data.objects['LegLeft'],bpy.data.objects['LegRight'],bpy.data.objects['ArmLeft'],bpy.data.objects['ArmRight']):
 parts=[o for o in group.children if o.type=='MESH' and o.get('skin_surface',False)]
 bpy.ops.object.select_all(action='DESELECT')
 for o in parts: o.select_set(True)
 bpy.context.view_layer.objects.active=parts[0]; bpy.ops.object.join()
 united=bpy.context.object
 united.name='SculptedFace' if group is head else group.name+'ContinuousSkin'
 # Apply every local transform before remeshing; original animation empties stay.
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 remesh=united.modifiers.new('ContinuousAnatomy','REMESH'); remesh.mode='VOXEL'
 remesh.voxel_size=.0055 if group is head else (.005 if group.name.startswith('Leg') else .0035)
 remesh.use_smooth_shade=True
 bpy.ops.object.modifier_apply(modifier=remesh.name)
 smooth=united.modifiers.new('SoftTissue','SMOOTH'); smooth.factor=.45; smooth.iterations=3
 bpy.ops.object.modifier_apply(modifier=smooth.name)
 target=3400 if group is head else (2100 if group.name.startswith('Leg') else 1250)
 if len(united.data.vertices)>target:
  decimate=united.modifiers.new('GameplayDensity','DECIMATE'); decimate.ratio=target/len(united.data.vertices)
  bpy.ops.object.modifier_apply(modifier=decimate.name)
 # Remesh must not interpolate material IDs: reapply categorical alpha exactly.
 united.data.materials.clear()
 for attribute in list(united.data.color_attributes): united.data.color_attributes.remove(attribute)
 paint(united,skin)
 if group.name.startswith('Leg'):
  # Keep the lowest sole at the existing y=0 contact plane.
  lowest=min(v.co.z for v in united.data.vertices)
  for v in united.data.vertices:
   if v.co.z<-.39: v.co.z-=lowest+.43
 print('CONTINUOUS_SKIN',group.name,len(united.data.vertices),'vertices')
# Consolidate static detail in each animated group, keeping all pivot transforms.
for group in (torso,head,bpy.data.objects['LegLeft'],bpy.data.objects['LegRight'],bpy.data.objects['ArmLeft'],bpy.data.objects['ArmRight']):
 children=[o for o in group.children if o.type=='MESH']
 if not children: continue
 bpy.ops.object.select_all(action='DESELECT')
 for o in children: o.select_set(True)
 bpy.context.view_layer.objects.active=children[0]
 bpy.ops.object.join()
 merged=bpy.context.object; merged.name=group.name+'Surface'; merged.data.name=group.name+'Geometry'
 # All slots reference the same shader; collapse them without changing pigments.
 shared=merged.data.materials[0]; merged.data.materials.clear(); merged.data.materials.append(shared)
 for polygon in merged.data.polygons: polygon.material_index=0
 if merged.data.validate(verbose=False,clean_customdata=False):
  print('MESH_REPAIRED',merged.name,'removed duplicate/degenerate faces after remesh')
 assert not merged.data.validate(verbose=False,clean_customdata=False), 'Mesh validation failed: '+merged.name
 merged.data.update()
OUTPUT.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT),export_format='GLB',export_yup=True,export_animations=False,export_cameras=False,export_lights=False,export_attributes=True)
# Vertex alpha carries material categories, not opacity. Preserve the exported
# COLOR_0 bytes while making the standalone GLB opaque in other applications.
data=OUTPUT.read_bytes(); chunks=[]; offset=12
while offset<len(data):
 length,kind=struct.unpack_from('<II',data,offset); payload=data[offset+8:offset+8+length]; offset+=8+length
 if kind==0x4E4F534A:
  document=json.loads(payload)
  for mat in document.get('materials',[]): mat['alphaMode']='OPAQUE'
  payload=json.dumps(document,separators=(',',':')).encode('utf8')
  payload+=b' '*((-len(payload))%4)
 chunks.append(struct.pack('<II',len(payload),kind)+payload)
body=b''.join(chunks); OUTPUT.write_bytes(struct.pack('<III',0x46546C67,2,12+len(body))+body)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
print('HOBBIT_EXPORTED',OUTPUT)
print('HOBBIT_STATS',len(meshes),'meshes',sum(len(o.data.vertices) for o in meshes),'vertices',sum(len(p.vertices)-2 for o in meshes for p in o.data.polygons),'triangles')
print('HOBBIT_PIVOTS',[(bpy.data.objects[n].name,tuple(round(x,4) for x in bpy.data.objects[n].location)) for n in ['Torso','LegLeft','LegRight','ArmLeft','ArmRight']])
points=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
print('HOBBIT_BOUNDS_YUP',[(round(min(v[a] for v in points),4),round(max(v[a] for v in points),4)) for a in (0,2,1)])
