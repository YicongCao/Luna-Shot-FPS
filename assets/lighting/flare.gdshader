shader_type canvas_item;
render_mode blend_add, unshaded;
void fragment() {
 vec4 tex = texture(TEXTURE, UV);
 float edge = 1.0-smoothstep(0.55, 1.0, length((UV-0.5)*2.0));
 COLOR = vec4(tex.rgb * COLOR.rgb, tex.a * COLOR.a * edge);
}
