extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var layouts: Array=JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/ml16/layouts.json"))
	var script=load("res://scripts/ground_surface.gd");var checks: Array=[]
	for layout in layouts:
		var mask: Image=script.make_field_mask(layout)
		var repeated: Image=script.make_field_mask(layout)
		var hits:=0;var samples:=0
		for name in layout.routes:
			var route: Array=layout.routes[name]
			for i in range(1,route.size()):
				var a:=Vector2(route[i-1][0],route[i-1][2]);var b:=Vector2(route[i][0],route[i][2])
				var forward:=(b-a).normalized();var side:=Vector2(-forward.y,forward.x)
				for t in 41:
					for offset in [-1.95,0.0,1.95]:
						var pos: Vector2=(a.lerp(b,t/40.0)+side*float(offset)+Vector2(32,33))*8
						samples+=1
						if mask.get_pixel(clampi(int(pos.x),0,511),clampi(int(pos.y),0,527)).r>.01:hits+=1
		checks.append({"seed":layout.seed,"passed":hits==0 and mask.get_data()==repeated.get_data(),"road_samples":samples,"soil_hits":hits})
	var failures:=checks.filter(func(c):return not c.passed).size()
	FileAccess.open("res://docs/validation/ground-v1/masks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"));print("GROUND_MASKS ",checks.size()," failures=",failures);quit(0 if failures==0 else 1)
