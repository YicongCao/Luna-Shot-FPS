extends RefCounted

const Kit = preload("res://scripts/polar/kit.gd")
const Layout = preload("res://scripts/polar/layout.gd")
const EXTENT := 110
const CELLS := 200
var erosion := FastNoiseLite.new()
var grit := FastNoiseLite.new()
var relief := FastNoiseLite.new()

func _init() -> void:
	erosion.seed = 188419
	erosion.frequency = .038
	erosion.fractal_octaves = 4
	grit.seed = 5507
	grit.frequency = .23
	grit.fractal_octaves = 2
	relief.seed = 34327
	relief.frequency = .0093
	relief.fractal_octaves = 3

func height(x: float, z: float) -> float:
	var r := Vector2(x/59.0, (z+4.0)/57.0).length()
	var weathered := erosion.get_noise_2d(x,z)
	var ledge := smoothstep(.72,1.21,r+weathered*.12)
	var outer := smoothstep(.99,1.85,r)
	var basin := -19.15 + weathered*.74 + grit.get_noise_2d(x,z)*.26
	var raised := 27.0*ledge + outer*(relief.get_noise_2d(x,z)*21 + weathered*9)
	var result := basin+raised
	# The south landing slab sits on a graded shelf. The center is excavated for the lift.
	var apron := (1.0-smoothstep(29.0,40.0,absf(x+3.0))) * smoothstep(40.5,48.0,z) * (1.0-smoothstep(72.0,89.0,z))
	result = lerpf(result,-.36+weathered*.10,apron)
	# Cut behind the occupied rim and around the suspended pressure crossing.
	var hab_cut := (1.0-smoothstep(3.4,4.7,absf(x+27.0))) * smoothstep(24.0,28.5,z) * (1.0-smoothstep(47.0,51.1,z))
	var hab_grade := clampf((z-44.0)*(.5/.87),-8.5,0.0)-.76
	result = lerpf(result,minf(result,hab_grade),hab_cut)
	var cut := (1.0-smoothstep(4.0,7.5,absf(x))) * smoothstep(27.0,32.0,z) * (1.0-smoothstep(40.7,44.0,z))
	result = lerpf(result,minf(result,-18.2),cut)
	# Preserve all seven tops; the excavated low side and weathered high side meet below them.
	for step in Layout.STEPS:
		if absf(z-step.x) < 5.0 and absf(x-Layout.STEP_X) < 5.0:
			var trim := (1.0-smoothstep(3.15,5.0,absf(x-Layout.STEP_X))) * (1.0-smoothstep(3.12,5.0,absf(z-step.x)))
			result = lerpf(result,minf(result,step.y-.45),trim)
	var trough := (1.0-smoothstep(24.0,29.0,absf(x))) * smoothstep(-45.0,-34.0,z)
	if z < 31.0 and z > -44.0:
		result = lerpf(result,minf(result,-17.35),trough*(1.0-smoothstep(25.0,31.0,z)))
	if r > 1.24:
		# Broad, differentiable overlapping ejecta rims. Avoid turning coarse distant
		# rings into a second, visibly sawtoothed copy of the nearby detail band.
		var p := Vector2(x,z)
		var ridge_a := exp(-pow((p.distance_to(Vector2(-126,-174))-92.0)/27.0,2.0))*32.0
		var ridge_b := exp(-pow((p.distance_to(Vector2(107,-234))-142.0)/37.0,2.0))*39.0
		var ridge_c := exp(-pow((p.distance_to(Vector2(262,76))-113.0)/33.0,2.0))*23.0
		var bed := 5.4 + relief.get_noise_2d(x+42.0,z-61.0)*10.0
		var far := bed + maxf(ridge_a,ridge_b)*(.94+relief.get_noise_2d(x,z)*.37)+ridge_c
		result = lerpf(result, far, smoothstep(1.24,2.28,r))
	return result

func build(root: Node3D) -> void:
	var mat := Kit.surface(Color(.385,.393,.408),.02,.91,3)
	var near := _mesh(EXTENT, CELLS, 0.0)
	var apron := Kit.part(root, near, Basis.IDENTITY, Vector3.ZERO, mat)
	apron.name = "CutRegolith"
	apron.create_trimesh_collision()
	var horizon := Kit.part(root, _mesh(620.0, 192, EXTENT-10.0), Basis.IDENTITY, Vector3.ZERO, mat)
	horizon.name = "Horizon"
	# Far ring hides the LOD boundary without extending the gameplay collision cost.
	horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_scree(root)

func _mesh(extent: float, cells: int, skip_core: float) -> ArrayMesh:
	var stride := cells+1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.resize(stride*stride)
	normals.resize(verts.size())
	uv.resize(verts.size())
	for row in stride:
		var z := lerpf(-extent,extent,float(row)/cells)
		for col in stride:
			var x := lerpf(-extent,extent,float(col)/cells)
			var index := row*stride+col
			var y := height(x,z)
			if skip_core > 0.0:
				y -= (1.0-smoothstep(skip_core,skip_core+16.0,maxf(absf(x),absf(z))))*.76
			verts[index] = Vector3(x,y,z)
			normals[index] = Vector3(height(x-.32,z)-height(x+.32,z), .64, height(x,z-.32)-height(x,z+.32)).normalized()
			uv[index] = Vector2(x,z)
			if row == cells or col == cells or (skip_core > 0.0 and maxf(absf(x),absf(z)) < skip_core):
				continue
			indices.append_array(PackedInt32Array([index,index+1,index+stride,index+1,index+stride+1,index+stride]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _scree(root: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 293381
	var source := SphereMesh.new()
	source.radial_segments = 13
	source.rings = 7
	var colors := [Color(.36,.368,.374),Color(.41,.415,.421),Color(.30,.313,.335),Color(.47,.465,.457)]
	for variant in 4:
		var arrays := source.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms := PackedVector3Array()
		norms.resize(verts.size())
		var k := Vector3(variant*12.41, -variant*4.1, 7.93)
		for i in verts.size():
			var p := verts[i].normalized()
			var jag := grit.get_noise_3dv(p*13.0+k)
			var swell := erosion.get_noise_3dv(p*50.0+k)
			verts[i] = p*(.94+jag*.36+swell*.42)
			verts[i].y = minf(verts[i].y*.79, .57+erosion.get_noise_3dv(p*24.0+k)*.16)
			norms[i] = Vector3(p.x,p.y*1.18,p.z).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		var rock := ArrayMesh.new()
		rock.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		for quad in 4:
			var transforms: Array[Transform3D] = []
			for i in 265:
				var x := rng.randf_range(0.0,107.0) * (-1.0 if quad % 2 == 0 else 1.0)
				var z := rng.randf_range(0.0,107.0) * (-1.0 if quad < 2 else 1.0)
				if (absf(x) < 31.0 and z > 38.0 and z < 72.0) or (absf(x) < 27.0 and z > -34.0 and z < 38.0):
					continue
				var size := .06 + pow(rng.randf(),4.1)*1.34
				var axes := Basis(Vector3.UP,rng.randf_range(-PI,PI)).scaled(Vector3(size, size*rng.randf_range(.42,.83),size*rng.randf_range(.65,1.3)))
				transforms.append(Transform3D(axes, Vector3(x,height(x,z)-size*.1,z)))
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.mesh = rock
			multi.instance_count = transforms.size()
			for i in transforms.size():
				multi.set_instance_transform(i, transforms[i])
			var node := MultiMeshInstance3D.new()
			node.multimesh = multi
			node.material_override = Kit.surface(colors[variant],.015,.93,3)
			root.add_child(node)
