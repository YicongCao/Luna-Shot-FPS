shader_type sky;
void sky() {
    vec3 d = normalize(EYEDIR);
    vec3 c = mix(vec3(0.045,0.055,0.075), vec3(0.24,0.29,0.36), smoothstep(-0.3,0.9,d.y));
    float key = pow(max(dot(d, normalize(vec3(-0.7,0.8,0.5))),0.0),28.0);
    float fill = pow(max(dot(d, normalize(vec3(0.8,0.4,-0.5))),0.0),18.0);
    c += vec3(3.8,3.5,3.1)*key + vec3(1.2,1.5,2.0)*fill;
    COLOR = c;
}
