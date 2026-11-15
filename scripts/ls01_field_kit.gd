extends Node3D
var cells: Array[MeshInstance3D] = []
var readout: Label3D
var shown_ammo := -1
var shown_capacity := -1
var active_material: StandardMaterial3D
var off_material: StandardMaterial3D
var baked: StandardMaterial3D
func mat(color: Color, metallic: float=0.0, rough: float=.5) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.metallic=metallic;m.roughness=rough;return m
func box(parent: Node3D,title: String,pos: Vector3,size: Vector3,m: Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();n.name=title;var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.material_override=m;n.position=pos;parent.add_child(n);return n
func polygon(parent: Node3D,title: String,points: PackedVector3Array,m: Material) -> void:
	var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1,points.size()-1):
		for k in [0,i,i+1]:st.add_vertex(points[k])
	st.generate_normals();var n:=MeshInstance3D.new();n.name=title;n.mesh=st.commit();n.material_override=m;parent.add_child(n)
func _ready() -> void:
	var panel:=Node3D.new();panel.name="AmmoPanel";panel.position=Vector3(0,.106,.019);panel.rotation.x=-PI/4;add_child(panel)
	active_material=mat(Color(.01,.7,.85));active_material.emission_enabled=true;active_material.emission=Color(.01,.8,1);active_material.emission_energy_multiplier=1.6
	off_material=mat(Color(.014,.045,.052))
	for i in 20:
		var x: float=-.037+i*.0025+floori(i/4.0)*.0008
		cells.append(box(panel,"AmmoCell%02d"%i,Vector3(x,0,.0041),Vector3(.0018,.010,.00010),off_material))
	readout=Label3D.new();readout.name="AmmoDigits";readout.font_size=48;readout.pixel_size=.000085;readout.position=Vector3(.030,0,.0042);readout.outline_size=0;readout.modulate=Color(.02,.85,1);panel.add_child(readout)
	# Analytic planar markings, independent of generated UV phases.
	var ink=mat(Color(.018,.022,.025),0,.58);ink.cull_mode=BaseMaterial3D.CULL_DISABLED
	var orange=mat(Color(.95,.38,.035),0,.58);orange.cull_mode=BaseMaterial3D.CULL_DISABLED
	for side in [-1,1]:
		var x=side*.05425
		polygon(self,"HazardGround",PackedVector3Array([Vector3(x,.05,-.205),Vector3(x,.05,-.279),Vector3(x,.078,-.279),Vector3(x,.078,-.205)]),orange)
		for i in 6:
			var z=-.205-i*.014
			# Clip stripes to the rectangular sticker region.
			var pts: Array[Vector2]=[Vector2(z,.05),Vector2(z-.007,.05),Vector2(z-.023,.078),Vector2(z-.016,.078)]
			for edge in [-.279,-.205]:
				var result: Array[Vector2]=[]
				for j in pts.size():
					var a=pts[j];var b=pts[(j+1)%pts.size()];var ia=a.x>=edge if edge<-.25 else a.x<=edge;var ib=b.x>=edge if edge<-.25 else b.x<=edge
					if ia:result.append(a)
					if ia!=ib:result.append(a+(b-a)*((edge-a.x)/(b.x-a.x)))
				pts=result
			var poly:=PackedVector3Array()
			for p in pts:poly.append(Vector3(x+side*.00003,p.y,p.x))
			if poly.size()>=3:polygon(self,"HazardStripe",poly,ink)
		# Custom straight industrial glyph strokes, 12 mm cap height.
		var glyphs=[[[0,1],[0,0],[.65,0]],[[.65,1],[.12,1],[0,.85],[0,.6],[.65,.4],[.65,.15],[.5,0],[0,0]],[[.12,0],[0,.15],[0,.85],[.12,1],[.53,1],[.65,.85],[.65,.15],[.53,0],[.12,0]],[[.12,.8],[.35,1],[.35,0]]]
		for g in 4:
			var path=glyphs[g]
			for j in range(path.size()-1):
				var a=Vector2(float(path[j][0]),float(path[j][1]));var b=Vector2(float(path[j+1][0]),float(path[j+1][1]));var d=(b-a).normalized();var v=Vector2(-d.y,d.x)*.055;var poly:=PackedVector3Array()
				for p in [a+v,a-v,b-v,b+v]:poly.append(Vector3(x+side*.00005,.077+p.y*.012,(-.110 if side>0 else -.155)-(g*.010+p.x*.012)*side))
				polygon(self,"LS01_Glyph",poly,ink)
	merge_markings()
	set_ammo(20,20)
func set_ammo(value: int, capacity: int) -> void:
	capacity=maxi(1,capacity);value=clampi(value,0,capacity)
	if value==shown_ammo and capacity==shown_capacity:return
	shown_ammo=value;shown_capacity=capacity
	var color=Color(.015,.85,1) if value>4 else Color(1,.24,.015)
	active_material.albedo_color=color;active_material.emission=color
	for i in cells.size():cells[i].material_override=active_material if i<ceili(float(value)*20.0/capacity) else off_material
	readout.text="%02d/%02d"%[value,capacity];readout.modulate=color if value>0 else Color(1,.08,.02)
func set_surface_mode(mode: int) -> void:
	for child in get_children():
		if child is Node3D:child.visible=mode!=3

func merge_markings() -> void:
	var groups: Dictionary={}
	for child in get_children():
		if child is MeshInstance3D:
			var material=child.material_override
			if not groups.has(material):groups[material]=[]
			groups[material].append(child)
	for material in groups:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for child in groups[material]:
			st.append_from(child.mesh,0,child.transform);child.queue_free()
		var merged:=MeshInstance3D.new();merged.name="PrintedMarkings";merged.mesh=st.commit();merged.material_override=material;add_child(merged)
