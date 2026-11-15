shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_never;
void fragment() {
    float r = length(UV - vec2(0.5));
    float core = 1.0 - smoothstep(0.027, 0.048, r);
    float halo = exp(-r*r*180.0) * 0.38;
    ALBEDO = mix(vec3(1.0, 0.015, 0.008), vec3(1.0, 0.48, 0.3), core * 0.35);
    ALPHA = clamp(core + halo, 0.0, 1.0) * pow(max(dot(NORMAL, VIEW), 0.0), 12.0);
}
