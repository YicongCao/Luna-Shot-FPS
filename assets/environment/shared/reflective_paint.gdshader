shader_type spatial;
render_mode cull_back;
uniform float specular_strength : hint_range(0.0,1.0)=0.5;
varying vec3 world_position;
float hash21(vec2 p) {return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float grain(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float fine=grain(world_position.xz*95.0);
 float wear=smoothstep(.82,.96,grain(world_position.xz*35.0));
 ALBEDO=mix(vec3(.88,.50,.035),vec3(.12,.13,.12),wear*.85);
 METALLIC=0.0;
 ROUGHNESS=clamp(.24+(fine-.5)*.07+wear*.36,.18,.68);
 SPECULAR=specular_strength;
 EMISSION=vec3(0.0);
}
