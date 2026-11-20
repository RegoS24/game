shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 wall_color : source_color = vec4(0.08, 0.11, 0.17, 1.0);
uniform vec4 window_color : source_color = vec4(0.2, 0.8, 0.95, 1.0);
varying vec3 wpos;
varying vec3 wn;
void vertex() {
 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
 wn = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p = vec2(abs(wn.x)>0.5 ? wpos.z : wpos.x,wpos.y);
 vec2 tile = p / vec2(2.45,3.25);
 vec2 f = fract(tile);
 float glass = step(0.17,f.x)*step(f.x,0.78)*step(0.25,f.y)*step(f.y,0.77);
 glass *= 1.0-step(0.6,abs(wn.y));
 float light = step(0.46,hash(floor(tile)));
 float frame = step(0.475,f.x)*step(f.x,0.515);
 float detail = 0.85 + 0.15*hash(floor(p*7.0));
 float band = step(0.94,f.y);
 ALBEDO = mix(wall_color.rgb*detail + vec3(band*0.045),vec3(0.025,0.049,0.079),glass);
 ALBEDO += glass*light*(1.0-frame)*window_color.rgb*0.23;
 EMISSION = glass*light*(1.0-frame)*window_color.rgb*0.67;
 ROUGHNESS = mix(0.72,0.19,glass);
 METALLIC = mix(0.2,0.48,glass);
}