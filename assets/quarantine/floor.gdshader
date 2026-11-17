shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_pos;
void vertex(){ world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment(){
 vec2 uv=world_pos.xz / vec2(2.0,4.0);
 vec3 base=texture(color_map,uv).rgb;
 vec3 orm=texture(orm_map,uv).rgb;
 vec2 grid=abs(fract(uv)-.5);
 float seam=smoothstep(.482,.496,max(grid.x,grid.y));
 float slab=hash(floor(uv));
 float flow=sin(world_pos.x*.48+sin(world_pos.z*.21)*1.7)*sin(world_pos.z*.34+1.2);
 float coolant=smoothstep(.78,.96,flow)*.22;
 ALBEDO=base*vec3(.57,.65,.69)*mix(.85,1.1,slab)*(1.0-seam*.42)*(1.0-coolant*.30);
 METALLIC=.025+coolant*.10;
 SPECULAR=.40;
 ROUGHNESS=mix(clamp(orm.g*.94,.62,.88),.29,coolant);
 NORMAL_MAP=texture(normal_map,uv).rgb;
 NORMAL_MAP_DEPTH=.50*(1.0-coolant*.7);
 AO=clamp(orm.r*(1.0-seam*.4),0.0,1.0);
}
