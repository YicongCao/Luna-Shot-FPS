extends RefCounted
# Rounded cuboids with actual bevel geometry and matched analytic normals.
# Vertex red records the bevel region, not a claim of baked curvature.
static func box_mesh(size: Vector3, bevel: float) -> ArrayMesh:
	var half: Vector3 = size*.5
	var radius: float = minf(bevel,minf(half.x,minf(half.y,half.z))*.45)
	var inner: Vector3 = half-Vector3.ONE*radius
	var tool: SurfaceTool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[Vector3.RIGHT,Vector3.BACK,Vector3.UP],[Vector3.LEFT,Vector3.FORWARD,Vector3.UP],[Vector3.UP,Vector3.RIGHT,Vector3.BACK],[Vector3.DOWN,Vector3.RIGHT,Vector3.FORWARD],[Vector3.BACK,Vector3.LEFT,Vector3.UP],[Vector3.FORWARD,Vector3.RIGHT,Vector3.UP]]:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var hu: float = absf(half.dot(u))
		var hv: float = absf(half.dot(v))
		var hn: float = absf(half.dot(normal))
		var us: Array[float] = [-hu,-hu+radius,hu-radius,hu]
		var vs: Array[float] = [-hv,-hv+radius,hv-radius,hv]
		for j in 3:
			for i in 3:
				for index in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
					var raw: Vector3 = normal*hn+u*us[i+index.x]+v*vs[j+index.y]
					var closest: Vector3 = raw.clamp(-inner,inner)
					var n: Vector3 = (raw-closest).normalized()
					var p: Vector3 = closest+n*radius
					tool.set_normal(n)
					tool.set_uv(Vector2(p.dot(u),p.dot(v)))
					var edge: float = clampf((1.0-maxf(absf(n.x),maxf(absf(n.y),absf(n.z))))*2.8,0,1)
					tool.set_color(Color(edge,0,0,1))
					tool.add_vertex(p)
	tool.generate_tangents()
	return tool.commit()
