shader_type canvas_item;
render_mode unshaded;
uniform sampler2D weapon_texture : filter_linear, repeat_disable;
uniform vec2 source_size = vec2(1440.0,900.0);
vec3 bright(vec2 uv) {
 vec4 sample_color=texture(weapon_texture,uv);
 // Cyan energy is the designated emissive material. Reject neutral ceramic whites.
 float energy=max(sample_color.g,sample_color.b);
 float cyan=smoothstep(0.12,0.28,energy-sample_color.r);
 float highlight=smoothstep(0.80,0.98,energy)*cyan*sample_color.a;
 return sample_color.rgb*highlight;
}
void fragment() {
 vec3 sum=vec3(0.0);float weight=0.0;
 for(int i=-5;i<=5;i++) {
  float w=exp(-float(i*i)/8.0);
  sum+=bright(UV+vec2(float(i)*6.0/source_size.x,0.0))*w;weight+=w;
 }
 COLOR=vec4(sum/weight,1.0);
}
