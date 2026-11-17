extends RefCounted
# Conforming local triangle subdivision. Every requested edge is shared by both
# incident triangles, including neighbors that did not request refinement.
const NORMAL_STEP: float = .15625
const TARGET_DOT: float = .985
const MAX_PASSES: int = 24
const MAX_TRIANGLES: int = 700000

static func normal_at(p: Vector3, height: Callable) -> Vector3:
	var dx: float=(height.call(p.x+NORMAL_STEP,p.z)-height.call(p.x-NORMAL_STEP,p.z))/(2*NORMAL_STEP)
	var dz: float=(height.call(p.x,p.z+NORMAL_STEP)-height.call(p.x,p.z-NORMAL_STEP))/(2*NORMAL_STEP)
	return Vector3(-dx,1,-dz).normalized()

static func edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a,b),maxi(a,b))

static func two_edges(a: int, b: int, c: int, ab: int, bc: int, vertices: PackedVector3Array) -> PackedInt32Array:
	# After cutting off B, triangulate the remaining quad along its shorter
	# diagonal. Always choosing one side propagates thin triangles to neighbors.
	if vertices[a].distance_squared_to(vertices[bc]) < vertices[ab].distance_squared_to(vertices[c]):
		return PackedInt32Array([b,bc,ab,a,ab,bc,a,bc,c])
	return PackedInt32Array([b,bc,ab,a,ab,c,ab,bc,c])

static func refine(source: ArrayMesh, height: Callable) -> ArrayMesh:
	var arrays: Array=source.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array=PackedVector3Array()
	normals.resize(vertices.size())
	for i in vertices.size(): normals[i]=normal_at(vertices[i],height)
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
	for iteration in MAX_PASSES:
		var splits: Dictionary={}
		for i in range(0,indices.size(),3):
			var a: int=indices[i]
			var b: int=indices[i+1]
			var c: int=indices[i+2]
			var face: Vector3=(vertices[c]-vertices[a]).cross(vertices[b]-vertices[a]).normalized()
			if minf(face.dot(normals[a]),minf(face.dot(normals[b]),face.dot(normals[c])))<TARGET_DOT:
				splits[edge(a,b)]=-1
				splits[edge(b,c)]=-1
				splits[edge(c,a)]=-1
		if splits.is_empty(): break
		for key: Vector2i in splits:
			var p: Vector3=(vertices[key.x]+vertices[key.y])*.5
			p.y=height.call(p.x,p.z)
			splits[key]=vertices.size()
			vertices.append(p)
			normals.append(normal_at(p,height))
		var next: PackedInt32Array=PackedInt32Array()
		for i in range(0,indices.size(),3):
			var a: int=indices[i]
			var b: int=indices[i+1]
			var c: int=indices[i+2]
			var ab: int=splits.get(edge(a,b),-1)
			var bc: int=splits.get(edge(b,c),-1)
			var ca: int=splits.get(edge(c,a),-1)
			if ab<0 and bc<0 and ca<0:
				next.append_array(PackedInt32Array([a,b,c]))
			elif ab>=0 and bc>=0 and ca>=0:
				next.append_array(PackedInt32Array([a,ab,ca,ab,b,bc,ca,bc,c,ab,bc,ca]))
			elif ab>=0 and bc<0 and ca<0:
				next.append_array(PackedInt32Array([a,ab,c,ab,b,c]))
			elif bc>=0 and ca<0 and ab<0:
				next.append_array(PackedInt32Array([b,bc,a,bc,c,a]))
			elif ca>=0 and ab<0 and bc<0:
				next.append_array(PackedInt32Array([c,ca,b,ca,a,b]))
			elif ab>=0 and bc>=0:
				next.append_array(two_edges(a,b,c,ab,bc,vertices))
			elif bc>=0 and ca>=0:
				next.append_array(two_edges(b,c,a,bc,ca,vertices))
			else:
				next.append_array(two_edges(c,a,b,ca,ab,vertices))
		indices=next
		assert(indices.size()/3<=MAX_TRIANGLES,"Local terrain subdivision exceeded its budget")
	var uvs: PackedVector2Array=PackedVector2Array()
	var tangents: PackedFloat32Array=PackedFloat32Array()
	for i in vertices.size():
		uvs.append(Vector2(vertices[i].x,vertices[i].z)/8)
		var n: Vector3=normals[i]
		var t: Vector3=Vector3(1,-n.x/n.y,0).normalized()
		tangents.append_array(PackedFloat32Array([t.x,t.y,t.z,-1]))
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uvs
	arrays[Mesh.ARRAY_TANGENT]=tangents
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh: ArrayMesh=ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
