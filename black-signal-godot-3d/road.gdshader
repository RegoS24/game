shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 wpos;
float hash(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}
void vertex(){wpos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wpos.xz;
 float grain=hash(floor(p*58.0));
 float patch=hash(floor(p*0.8));
 float wet=smoothstep(0.32,0.7,patch);
 ALBEDO=vec3(0.045,0.052,0.075)*(0.75+grain*0.38);
 ROUGHNESS=mix(0.78,0.16,wet);
 METALLIC=0.43;
 float side=exp(-abs(abs(p.x)-6.0)*0.65);
 float glow=0.55+0.45*sin(p.y*0.27);
 EMISSION=vec3(0.16,0.018,0.22)*side*glow*wet*0.19+vec3(0.012,0.18,0.20)*side*(1.0-glow)*wet*0.17;
}