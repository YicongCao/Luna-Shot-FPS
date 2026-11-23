shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.6, 0.65, 0.7, 1.0);
uniform float base_metal = 0.2;
uniform float base_rough = 0.58;
// Coating, brushed alloy, elastomer, regolith, treadplate.
uniform int finish = 0;
varying vec3 object_p;
varying vec3 object_n;

float hash31(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash31(i),hash31(i+vec3(1,0,0)),f.x),
		mix(hash31(i+vec3(0,1,0)),hash31(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash31(i+vec3(0,0,1)),hash31(i+vec3(1,0,1)),f.x),
		mix(hash31(i+vec3(0,1,1)),hash31(i+vec3(1,1,1)),f.x),f.y),f.z);
}

void vertex() {
	object_p = VERTEX;
	object_n = NORMAL;
}

void fragment() {
	vec3 p = object_p;
	vec3 n = normalize(NORMAL);
	float footprint = length(fwidth(p));
	float visible_grain = 1.0-smoothstep(0.008,0.055,footprint);
	float grain = (noise3(p*93.0)-0.5) * visible_grain;
	float dirt = noise3(p*3.2);
	float marbling = noise3(p*0.43);
	float rough = base_rough + grain*0.12 + (dirt-0.5)*0.13;
	float metal = base_metal;
	vec3 base = tint.rgb * (0.87 + 0.17*dirt + grain*0.11);
	float h = grain * 0.00024;
	if (finish == 3) {
		float slope = 1.0-abs(normalize(object_n).y);
		float bedding = p.y*2.08 + 2.2*noise3(p*0.21) + 0.27*p.x;
		float seams = smoothstep(0.70,0.94,noise3(vec3(p.x*.25,bedding,p.z*.24)));
		float gravel = noise3(p * 5.3);
		float deposits = noise3(vec3(p.x*0.31,p.y*0.14,p.z*0.34));
		float mottled = 0.75 + 0.28 * deposits + 0.14 * dirt - 0.25 * slope * seams;
		float grit = (noise3(p*24.0)-0.5)*(1.0-smoothstep(0.02,0.15,footprint));
		base = tint.rgb * mottled * (1.0+0.14*grain+0.17*grit+0.08*gravel);
		base *= mix(vec3(0.94,0.96,1.01),vec3(1.06,1.01,0.96),marbling);
		h = grit*0.0039 + grain*0.00065 + dirt*0.018 + gravel*0.024 - slope*seams*0.018;
		rough += deposits*0.07;
	} else if (finish == 1) {
		float brush = (noise3(p*vec3(220.0,12.0,205.0))-0.5)*visible_grain;
		base *= 1.0+brush*0.09;
		rough += brush*0.16;
		h += brush*0.00025;
	} else if (finish == 4) {
		// Close range grip texture only; no metre-scale checkerboard in route views.
		vec2 q = fract(p.xz*21.0+vec2(floor(p.z*21.0)*0.5,0.0))-0.5;
		float tread = (1.0-smoothstep(0.16,0.28,abs(q.x*0.56+q.y))) * (1.0-smoothstep(0.20,0.47,abs(q.x)));
		tread *= (1.0-smoothstep(0.012,0.039,footprint))*abs(object_n.y);
		base *= (0.93+0.16*tread)*(0.81+0.34*marbling);
		h += tread*0.00046;
	} else if (finish == 5) {
		// Ceramic blast pavers are matte; wheel marks, binder and dust vary at several scales.
		vec3 world = (INV_VIEW_MATRIX*vec4(VERTEX,1.0)).xyz;
		float abrasion = noise3(world*vec3(.91,.3,.053));
		float patches = noise3(world*.39+vec3(4.3,-2.1,1.7));
		float powder = smoothstep(.34,.75,patches*.64+abrasion*.36);
		float fleck = noise3(world*22.0)*(1.0-smoothstep(.018,.083,footprint));
		base = mix(tint.rgb*(.76+.34*abrasion),tint.rgb*vec3(1.14,1.13,1.10),powder) * (0.916+fleck*.17);
		rough += powder*.12;
		h += patches*.0032+dirt*.0018+fleck*.0011;
	} else if (finish == 0) {
		// Vertex curvature proxy from the real rounded mesh, not a baked normal map.
		float exposed = step(COLOR.r,0.99) * COLOR.r * smoothstep(0.51,0.83,noise3(p*51.0));
		base = mix(base,vec3(0.27,0.30,0.32),exposed*0.66);
		rough -= exposed*0.23;
		metal += exposed*0.51;
		h += dirt*0.0006;
	}
	vec3 sx = dFdx(VERTEX);
	vec3 sy = dFdy(VERTEX);
	vec3 rx = cross(sy,n);
	vec3 ry = cross(n,sx);
	float det = dot(sx,rx);
	vec3 grad = sign(det)*(dFdx(h)*rx+dFdy(h)*ry);
	if (abs(det) > 0.00000001) {
		NORMAL = normalize(abs(det)*n - grad);
	}
	ALBEDO = base;
	METALLIC = clamp(metal,0.0,1.0);
	ROUGHNESS = clamp(rough,0.18,1.0);
	SPECULAR = 0.46;
}
