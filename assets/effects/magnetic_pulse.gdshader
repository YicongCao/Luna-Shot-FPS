shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;
// Analytic ribbon: no bitmap texture, no screen-space overlay, depth test stays on.
uniform float gain = 1.0;
void fragment() {
	float across = abs(UV.y * 2.0 - 1.0);
	float core = exp(-across * across * 24.0);
	float halo = exp(-across * across * 5.0) * 0.20;
	float ends = smoothstep(0.0, 0.09, UV.x) * (1.0 - smoothstep(0.80, 1.0, UV.x));
	ALBEDO = COLOR.rgb * gain;
	ALPHA = clamp((core + halo) * ends * COLOR.a, 0.0, 1.0);
}
