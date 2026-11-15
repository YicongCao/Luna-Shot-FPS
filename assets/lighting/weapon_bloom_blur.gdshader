shader_type canvas_item;
render_mode unshaded;
uniform sampler2D horizontal_texture : filter_linear, repeat_disable;
uniform vec2 source_size=vec2(360.0,225.0);
void fragment() {
 vec3 sum=vec3(0.0);float weight=0.0;
 for(int i=-5;i<=5;i++) {
  float w=exp(-float(i*i)/8.0);
  sum+=texture(horizontal_texture,UV+vec2(0.0,float(i)*1.5/source_size.y)).rgb*w;weight+=w;
 }
 COLOR=vec4(sum/weight,1.0);
}
