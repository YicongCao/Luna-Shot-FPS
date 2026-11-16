shader_type spatial;
render_mode cull_back;
uniform sampler2D paving_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D paving_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_mask : filter_linear, repeat_disable;
uniform vec2 area_origin=vec2(-4.0,-4.0);
uniform vec2 area_size=vec2(8.0,8.0);
uniform float normal_strength=0.75;
uniform int debug_channel=0;
uniform vec3 ground_ambient=vec3(.0912,.1128,.1464);
varying vec3 world_position;
varying float top_face;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 top_face=abs(NORMAL.y);
 TANGENT=vec3(1,0,0);BINORMAL=vec3(0,0,-1);
}
void fragment(){
 vec2 p=world_position.xz;
 vec2 drift=vec2(sin(p.y*3.0+sin(p.x*4.0)),cos(p.x*4.0+sin(p.y*3.0)))*.07;
 float soil=texture(soil_mask,(p+drift-area_origin)/area_size).r;
 vec2 uv=vec2(p.x,-p.y);
 vec3 bc=mix(texture(paving_color,uv/vec2(2,4)).rgb,texture(soil_color,uv).rgb,soil);
 vec3 orm=mix(texture(paving_orm,uv/vec2(2,4)).rgb,texture(soil_orm,uv).rgb,soil);
 vec2 nxy=mix(texture(paving_normal,uv/vec2(2,4)).rg*2.0-1.0,texture(soil_normal,uv).rg*2.0-1.0,soil);
 vec3 n=vec3(nxy,sqrt(max(.001,1.0-dot(nxy,nxy))));
 // Gentle metre-scale variation breaks repetition without adding baked lighting.
 float broad=sin(p.x*.21+sin(p.y*.34))*.025+sin(p.x*.73-p.y*.26)*.012;
 ALBEDO=bc*(1.0+broad);
 ROUGHNESS=orm.g;METALLIC=orm.b;AO=orm.r;SPECULAR=.4;
 // Stable global diffuse ambient across probe boundaries; keep specular reflections.
 IRRADIANCE=vec4(ground_ambient,1.0);
 NORMAL_MAP=n*.5+.5;NORMAL_MAP_DEPTH=normal_strength*top_face;
 if(top_face<.5){ALBEDO=vec3(.08,.085,.09);NORMAL_MAP_DEPTH=0.0;ROUGHNESS=.9;METALLIC=0.0;}
 if(debug_channel==1){ALBEDO=vec3(.35);ROUGHNESS=.7;METALLIC=0.0;NORMAL_MAP_DEPTH=0.0;}
 if(debug_channel==2){ALBEDO=vec3(soil);ROUGHNESS=1.0;NORMAL_MAP_DEPTH=0.0;}
}
