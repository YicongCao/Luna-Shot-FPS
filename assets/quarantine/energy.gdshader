shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform vec4 tint : source_color = vec4(.1,.55,1.,.4);
uniform float power = 1.;
void fragment(){
 float rim=pow(1.-abs(dot(normalize(NORMAL),normalize(VIEW))),1.2);
 float strands=.6+.4*sin(UV.x*75.+UV.y*18.-TIME*5.);
 float pulse=.8+.2*sin(UV.y*46.-TIME*12.);
 ALBEDO=tint.rgb*6.0*power;
 ALPHA=tint.a*rim*strands*pulse*smoothstep(0.,.10,UV.y)*(1.-smoothstep(.86,1.,UV.y));
}
