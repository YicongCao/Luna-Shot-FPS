extends Node3D
# Local attachments leave the original receiver topology and UV untouched.
var baked: StandardMaterial3D
var cells: Array[MeshInstance3D] = []
var readout: Label3D
var shown_ammo := -1
var active_material: StandardMaterial3D
var off_material: StandardMaterial3D
var materials: Array[StandardMaterial3D] = []
# ML21 reuses only the ammo panel; set before add_child.
var screen_only := false
var panel_position := Vector3(0, .106, .019)
var panel_rotation_x := -PI/4
var panel_scale := 1.0
func metal(color: Color, rough: float, metallic: float=1.0) -> StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;m.metallic=metallic
	materials.append(m);return m
func box(parent: Node3D, title: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n:=MeshInstance3D.new();n.name=title;var mesh:=BoxMesh.new();mesh.size=size;n.mesh=mesh;n.material_override=mat;n.position=pos;parent.add_child(n);return n
func screw(parent: Node3D, pos: Vector3, mat: Material, dark: Material) -> void:
	var rim:=MeshInstance3D.new();var torus:=TorusMesh.new();torus.inner_radius=.0017;torus.outer_radius=.0028;torus.rings=16;torus.ring_segments=8;rim.mesh=torus;rim.material_override=mat;rim.rotation.x=PI/2;rim.position=pos;parent.add_child(rim)
	var head:=MeshInstance3D.new();var cylinder:=CylinderMesh.new();cylinder.top_radius=.00165;cylinder.bottom_radius=.00165;cylinder.height=.0005;cylinder.radial_segments=12;head.mesh=cylinder;head.rotation.x=PI/2;head.position=pos-Vector3(0,0,.0006);head.material_override=mat;parent.add_child(head)
	box(parent,"RecessedDrive",pos-Vector3(0,0,.0003),Vector3(.0023,.0005,.0001),dark)
func _ready() -> void:
	var dark:=metal(Color(.018,.026,.035),.43,.65)
	var alloy:=metal(Color(.27,.32,.36),.32)
	var copper:=metal(Color(.7,.36,.12),.38,.72)
	var panel:=Node3D.new();panel.name="AmmoPanel";panel.position=panel_position;panel.rotation.x=panel_rotation_x;panel.scale=Vector3.ONE*panel_scale;add_child(panel)
	box(panel,"ArmoredBack",Vector3.ZERO,Vector3(.099,.035,.004),dark)
	box(panel,"InsetGlass",Vector3(0,0,.0021),Vector3(.087,.024,.0004),metal(Color(.003,.013,.018),.2,.2))
	for side in [-1,1]:
		box(panel,"BezelSide",Vector3(side*.047,0,.003),Vector3(.005,.035,.003),alloy)
		box(panel,"BezelEdge",Vector3(0,side*.015,.003),Vector3(.09,.004,.003),alloy)
		for y in [-.011,.011]:screw(panel,Vector3(side*.046,y,.005),alloy,dark)
	active_material=metal(Color(.01,.7,.85),.3,0);active_material.emission_enabled=true;active_material.emission=Color(.01,.8,1);active_material.emission_energy_multiplier=2.2
	off_material=metal(Color(.014,.055,.065),.6,0)
	for i in 20:
		var x: float=-.039+i*.0027+floori(i/4.0)*.001
		cells.append(box(panel,"AmmoCell%02d"%i,Vector3(x,0,.0026),Vector3(.0019,.012,.00025),off_material))
	readout=Label3D.new();readout.name="AmmoDigits";readout.font_size=48;readout.pixel_size=.00010;readout.position=Vector3(.030,0,.003);readout.outline_size=0;readout.modulate=Color(.02,.85,1);readout.no_depth_test=false;panel.add_child(readout)
	for side in ([] if screen_only else [-1,1]):
		var cassette:=Node3D.new();cassette.name="ConductorCassetteLeft" if side<0 else "ConductorCassetteRight";cassette.position=Vector3(side*.056,.057,-.135);cassette.rotation.y=side*PI/2;add_child(cassette)
		box(cassette,"RecessedChannel",Vector3.ZERO,Vector3(.17,.034,.004),dark)
		for i in 6:box(cassette,"BronzeRibbon%02d"%i,Vector3(0,(i-2.5)*.004,.0026),Vector3(.135,.0025,.001),copper)
		for end in [-1,1]:
			box(cassette,"InsulatedEndClamp",Vector3(end*.073,0,.004),Vector3(.013,.035,.005),dark)
			for y in [-.011,.011]:screw(cassette,Vector3(end*.073,y,.007),alloy,dark)
		var fins:=Node3D.new();fins.name="Heatsink";fins.position=Vector3(side*.047,.106,-.36);add_child(fins)
		box(fins,"HeatSpreader",Vector3.ZERO,Vector3(.015,.006,.092),dark)
		for i in 8:box(fins,"Fin%02d"%i,Vector3(0,.009,(i-3.5)*.011),Vector3(.017,.02,.0025),alloy)
	if ResourceLoader.exists("res://assets/weapons/lc01/field_kit/kit.glb") and OS.get_environment("LUNA_KIT_SOURCE") != "1" and not screen_only:
		for child in get_children():
			if child != panel: child.queue_free()
		for child in panel.get_children():
			if not child.name.begins_with("AmmoCell") and child != readout: child.queue_free()
		var kit: Node3D=load("res://assets/weapons/lc01/field_kit/kit.glb").instantiate()
		baked=StandardMaterial3D.new()
		baked.albedo_texture=load("res://assets/weapons/lc01/field_kit/BaseColor.png")
		baked.metallic=1.0;baked.metallic_texture=load("res://assets/weapons/lc01/field_kit/ORM.png");baked.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_BLUE
		baked.roughness_texture=baked.metallic_texture;baked.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		baked.normal_enabled=true;baked.normal_texture=load("res://assets/weapons/lc01/field_kit/NormalGL.png")
		baked.ao_enabled=true;baked.ao_texture=baked.metallic_texture;baked.ao_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
		baked.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		for m in kit.find_children("*","MeshInstance3D",true,false):m.material_override=baked
		add_child(kit)
	set_ammo(20,20)
func set_ammo(value: int, capacity: int) -> void:
	value=clampi(value,0,capacity)
	if value==shown_ammo:return
	shown_ammo=value
	var color:=Color(.015,.85,1) if value>4 else Color(1,.24,.015)
	active_material.albedo_color=color;active_material.emission=color
	for i in cells.size():cells[i].material_override=active_material if i<value else off_material
	readout.text="%02d/%02d"%[value,capacity];readout.modulate=color if value>0 else Color(1,.08,.02)

func set_surface_mode(mode: int) -> void:
	if baked==null:return
	baked.normal_enabled=mode!=1 and mode!=3
	baked.albedo_texture=null if mode==3 else load("res://assets/weapons/lc01/field_kit/BaseColor.png")
	baked.albedo_color=Color(.5,.5,.5) if mode==3 else Color.WHITE
	baked.metallic_texture=null if mode==2 or mode==3 else load("res://assets/weapons/lc01/field_kit/ORM.png")
	baked.roughness_texture=baked.metallic_texture
	baked.metallic=0.0 if mode==2 or mode==3 else 1.0
	baked.roughness=.55 if mode==2 or mode==3 else 1.0
	baked.ao_enabled=mode!=3
