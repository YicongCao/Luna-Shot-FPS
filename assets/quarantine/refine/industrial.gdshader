shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 coating : source_color = vec4(.14,.18,.21,1.);
uniform float base_metal = .06;
uniform float base_roughness = .58;
uniform sampler2D wear_mask : filter_linear_mipmap_anisotropic, repeat_enable;
varying float bevel;
varying vec3 position_world;
void vertex(){bevel=COLOR.r*(1.-COLOR.g);position_world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 uv=UV*.55;
 float scratches=texture(wear_mask,uv).r;
 float broad=noise(UV*1.4+vec2(3.,11.));
 float grain=noise(UV*230.);
 float exposed=clamp(scratches*(.12+bevel*.78)+bevel*.035,0.,.70);
 vec3 paint=coating.rgb*(.94+broad*.10);
 vec3 steel=vec3(.30,.32,.34);
 ALBEDO=mix(paint,steel,exposed);
 METALLIC=mix(base_metal,.88,exposed);
 ROUGHNESS=clamp(base_roughness+(broad-.5)*.10+(grain-.5)*.025-exposed*.14,.25,.9);
 // Submillimetre coating relief; analytic derivatives are not high-poly baking.
 float bump=(grain-.5)*.00004;
 vec3 dpdx=dFdx(VERTEX), dpdy=dFdy(VERTEX);
 vec3 r1=cross(dpdy,NORMAL),r2=cross(NORMAL,dpdx);
 float det=dot(dpdx,r1);
 vec3 gradient=sign(det)*(dFdx(bump)*r1+dFdy(bump)*r2);
 NORMAL=normalize(max(abs(det),1e-12)*NORMAL-gradient);
}
