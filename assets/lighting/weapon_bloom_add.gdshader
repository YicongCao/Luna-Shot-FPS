shader_type canvas_item;
render_mode blend_add, unshaded;
uniform float energy=0.9;
void fragment(){ COLOR=vec4(texture(TEXTURE,UV).rgb*energy,1.0); }
