shader_type fog;

void fog() {
	// Only the drill's discharged material scatters the work light. No self-emission.
	vec3 p = UVW;
	float t = p.z;
	float wobble = sin(t * 13.0 - TIME * 0.85);
	vec2 center = vec2(0.50 - 0.10*t + 0.047*t*wobble, 0.50 + 0.22*t);
	vec2 spread = mix(vec2(0.084, 0.125), vec2(0.44, 0.28), t);
	float r = length((p.xy - center) / spread);
	float edge = 1.0 - smoothstep(0.24, 0.99, r + 0.12*sin(p.x*20.0 + p.y*13.0 + t*15.0));
	float extent = smoothstep(0.015, 0.14, t) * (1.0 - smoothstep(0.45, 0.98, t));
	DENSITY = 0.36 * edge * extent * (0.87 + 0.13*wobble);
	ALBEDO = vec3(0.79, 0.81, 0.84);
}
