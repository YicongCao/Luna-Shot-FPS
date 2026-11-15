shader_type sky;
uniform vec3 sun_direction = vec3(0.5, 0.309, 0.8);
void sky() {
 float disc = smoothstep(cos(0.006), cos(0.0042), dot(EYEDIR, normalize(sun_direction)));
 COLOR = vec3(1.0, 0.92, 0.79) * disc * 12.0;
}
