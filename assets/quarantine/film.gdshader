shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float cinema = 0.0;
uniform float grain_strength = .002;
float random(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void fragment(){
 vec2 uv=SCREEN_UV;
 vec3 col=texture(screen_texture,uv).rgb;
 vec2 d=uv-.5;
 float vignette=smoothstep(.16,.63,length(d*vec2(.82,1.0)));
 col*=1.-vignette*.19;
 // Minimal optical finish: no fake detail, no blurred aiming center.
 col+=vec3(random(FRAGCOORD.xy+floor(TIME*24.))-.5)*grain_strength;
 if(cinema>.5 && (uv.y<.065 || uv.y>.935)) col=vec3(.002,.003,.004);
 COLOR=vec4(col,1.);
}
