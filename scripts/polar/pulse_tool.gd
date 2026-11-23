extends Node3D
## Parametric survey pulse tool. No imported viewmodel or textures.
const Kit = preload("res://scripts/polar/kit.gd")
var muzzle := Vector3(0,.015,-.510)
var cells: Array[MeshInstance3D] = []
var live := Kit.glow(Color(.50,.79,.94),1.3)
var off := Kit.surface(Color(.17,.22,.25),.15,.54)

func _ready() -> void:
	var armor := Kit.surface(Color(.71,.748,.777),.22,.44)
	var body := Kit.surface(Color(.14,.17,.20),.46,.48)
	var rubber := Kit.surface(Color(.092,.118,.14),.07,.62,2)
	var brushed := Kit.surface(Color(.35,.409,.462),.73,.37,1)
	var titanium := Kit.surface(Color(.42,.46,.49),.54,.42,1)
	var cork := Kit.surface(Color(.54,.38,.24),.18,.52)
	Kit.box(self,Vector3(0,-.018,-.14),Vector3(.199,.174,.52),body,.032)
	Kit.box(self,Vector3(0,.061,-.16),Vector3(.171,.056,.46),brushed,.019)
	Kit.box(self,Vector3(0,-.044,.107),Vector3(.218,.178,.120),rubber,.039)
	Kit.box(self,Vector3(0,-.069,-.175),Vector3(.187,.091,.310),cork,.019)
	Kit.box(self,Vector3(0,-.14,-.027),Vector3(.108,.145,.09),rubber,.019)
	for x in [-1.0,1.0]:
		Kit.box(self,Vector3(x*.096,.002,-.202),Vector3(.048,.126,.332),armor,.016)
		Kit.box(self,Vector3(x*.109,.024,-.373),Vector3(.034,.102,.135),armor,.013)
		Kit.box(self,Vector3(x*.093,-.061,.038),Vector3(.036,.078,.205),body,.015)
		Kit.box(self,Vector3(x*.116,.041,-.289),Vector3(.009,.034,.088),cork,.003)
		for z in [-.327,-.302,-.153,-.129,-.105]:
			Kit.box(self,Vector3(x*.119,-.038,z),Vector3(.008,.034,.010),body,.002)
		for z in [-.366,-.127,.028]:
			Kit.pipe(self,Vector3(x*.121,.038,z),Vector3(x*.130,.038,z),.010,titanium,14)
		Kit.beam(self,Vector3(x*.083,.081,-.34),Vector3(x*.083,.081,-.059),.017,body)
	Kit.pipe(self,Vector3(0,.015,-.375),Vector3(0,.015,-.489),.073,brushed,32)
	Kit.pipe(self,Vector3(0,.015,-.423),Vector3(0,.015,-.465),.083,body,32)
	Kit.pipe(self,Vector3(0,.015,-.480),Vector3(0,.015,-.508),.064,armor,32)
	Kit.pipe(self,Vector3(0,.015,-.505),Vector3(0,.015,-.511),.042,body,28)
	Kit.pipe(self,Vector3(0,.015,-.511),Vector3(0,.015,-.513),.022,live,24)
	# Recessed rear cell meter; actual ammunition updates its twelve inlaid segments.
	Kit.box(self,Vector3(0,.036,.146),Vector3(.179,.057,.039),body,.011)
	for i in 12:
		cells.append(Kit.box(self,Vector3((i-5.5)*.012,.040,.167),Vector3(.008,.017,.006),live,.001))
	# Open aiming frame sits above the receiver, with a clear native reticle gap.
	Kit.box(self,Vector3(0,.097,-.096),Vector3(.132,.051,.118),body,.014)
	for x in [-.062,.062]:
		Kit.beam(self,Vector3(x,.113,-.088),Vector3(x*.91,.218,-.095),.015,brushed,false,.025)
	Kit.box(self,Vector3(0,.222,-.096),Vector3(.117,.014,.028),brushed,.006)
	# A pair of articulated pressure-gauntlet volumes support the tool below the sightline.
	Kit.box(self,Vector3(.062,-.138,.064),Vector3(.130,.158,.22),rubber,.039)
	Kit.box(self,Vector3(.070,-.142,.154),Vector3(.137,.141,.075),armor,.029)
	Kit.box(self,Vector3(-.062,-.105,-.249),Vector3(.140,.090,.168),rubber,.033)
	for i in 3:
		Kit.box(self,Vector3(-.132,-.078,-.198-i*.026),Vector3(.030,.045,.021),titanium,.008)

func set_charge(count: int) -> void:
	for i in cells.size():
		cells[i].material_override = live if i < count else off
