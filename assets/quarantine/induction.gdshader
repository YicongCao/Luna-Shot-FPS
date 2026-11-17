shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
// Cylinder sides only. Object-space height also fades the crown at every view angle.
uniform float power = 0.;
uniform float front = 0.;
varying vec3 local_pos;
void vertex() { local_pos = VERTEX; }
void fragment() {
	float h = clamp(local_pos.y / 22. + .5, 0., 1.);
	vec2 radial = normalize(local_pos.xz + vec2(.00001));
	// Integral angular harmonics join without a UV seam.
	float a = atan(radial.y, radial.x);
	float phase = 7.*a + 12.*h + .8*sin(13.*h - TIME*1.8) - TIME*1.2;
	float ribbons = pow(.5+.5*cos(phase), 5.);
	float fine = pow(.5+.5*cos(13.*a - 19.*h + TIME*1.7), 12.);
	float crest = exp(-pow((h-front)*18., 2.));
	float mask = smoothstep(.02,.12,h)*(1.-smoothstep(.60,1.,h))*(1.-smoothstep(front-.03,front+.03,h));
	ALBEDO = mix(vec3(.045,.42,.85), vec3(.55,.94,1.), crest*.7+ribbons*.25)*4.;
	ALPHA = power*mask*(.035+.32*ribbons+.12*fine+.24*crest);
}
