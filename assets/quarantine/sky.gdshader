shader_type sky;
uniform vec3 sun_direction = vec3(.3,.18,-.9);
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.57+noise(p*2.03+7.)*.28+noise(p*4.11-3.)*.15;}
void sky(){
 vec3 d=normalize(EYEDIR);
 float horizon=exp(-abs(d.y)*14.0);
 vec3 col=mix(vec3(.002,.004,.009),vec3(.065,.105,.14),horizon*.7);
 float s=max(dot(d,normalize(sun_direction)),0.0);
 col+=vec3(1.0,.55,.20)*(pow(s,120.0)*.18+pow(s,4000.0)*12.0);
 // Distant Earth: a procedural sphere, not an image or a painted scene.
 vec3 planet=normalize(vec3(-.38,.27,-1.0));
 float angular=acos(clamp(dot(d,planet),-1.0,1.0));
 float r=.043;
 if(angular<r){
   vec3 right=normalize(cross(planet,vec3(0.,1.,0.)));
   vec3 up=cross(right,planet);
   vec2 p=vec2(dot(d,right),dot(d,up))/r;
   float nz=sqrt(max(0.,1.-dot(p,p)));
   vec3 n=vec3(p,nz);
   float land=fbm(p*3.7+vec2(2.4,7.1));
   vec3 sea=mix(vec3(.015,.10,.22),vec3(.10,.19,.16),smoothstep(.49,.59,land));
   float cloud=smoothstep(.54,.71,fbm(vec2(p.x*6.+sin(p.y*5.)*.5,p.y*14.)));
   sea=mix(sea,vec3(.60,.68,.72),cloud*.85);
   float light=max(dot(n,normalize(vec3(.8,.35,.5))),0.0);
   col=sea*(light*1.4+.035)+vec3(.08,.26,.5)*pow(1.-nz,4.)*.3;
 }
 col+=vec3(.06,.18,.36)*exp(-abs(angular-r)*1700.)*.45;
 COLOR=col;
}
