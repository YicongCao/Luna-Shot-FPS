shader_type sky;

float hash(vec3 p) {
	p = fract(p*vec3(0.1031,0.1030,0.0973));
	p += dot(p,p.yxz+33.33);
	return fract((p.x+p.y)*p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),
		mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),
		mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}

float cloud(vec3 p) {
	return value_noise(p)*0.57 + value_noise(p*2.17+4.6)*0.28 + value_noise(p*4.81-2.3)*0.15;
}

void sky() {
	vec3 ray = EYEDIR;
	// Low viewing exposure: barely visible stars, no atmospheric gradient over hard vacuum.
	vec3 col = vec3(0.0029,0.0043,0.0064);
	if (!AT_CUBEMAP_PASS) {
		vec3 v = ray*219.0;
		float star = (1.0-smoothstep(0.04,0.19,length(fract(v)-0.5)))*step(0.991,hash(floor(v)));
		col += star*vec3(0.075,0.088,0.12);
		// Earth, just above the far ridge. A shaded sphere in direction-space.
		vec3 earth = normalize(vec3(0.44,0.225,-0.89));
		vec3 right = normalize(cross(earth,vec3(0,1,0)));
		vec3 up = cross(right,earth);
		vec2 q = vec2(dot(ray,right),dot(ray,up))/0.020;
		float rr = dot(q,q);
		if (rr < 1.07 && dot(ray,earth) > 0.0) {
			vec3 n = vec3(q,sqrt(max(1.0-rr,0.0)));
			float day = smoothstep(-0.07,0.75,dot(n,normalize(vec3(-0.59,0.32,0.74))));
			float land = cloud(n*2.9+vec3(12.4,9.3,-4.6));
			float warp = cloud(n*3.9+vec3(-11.9,3.0,8.4));
			float vapor = cloud(n*8.0+vec3(warp*3.9,n.x*.2,n.y*2.0));
			vec3 albedo = mix(vec3(0.023,0.089,0.20),vec3(0.24,0.27,0.20),smoothstep(0.51,0.6,land));
			albedo = mix(albedo,vec3(0.62,0.68,0.73),smoothstep(0.52,0.71,vapor));
			vec3 orb = albedo*(0.021+day*0.93)+vec3(0.032,0.104,0.21)*pow(rr,12.0)*day;
			col = mix(col,orb,1.0-smoothstep(0.965,1.04,rr));
		}
		if (LIGHT0_ENABLED) {
			float sun = dot(ray,LIGHT0_DIRECTION);
			col += vec3(9.0)*smoothstep(0.999972,0.999990,sun);
		}
	}
	COLOR = col;
}
