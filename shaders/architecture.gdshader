shader_type spatial;
render_mode diffuse_burley;
uniform vec4 tint : source_color = vec4(1.0);
uniform int surface_kind = 0;
uniform bool vertex_palette = false;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 p;
varying vec4 paint;
float hash(vec3 v) { return fract(sin(dot(v,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 v) {
	vec3 i=floor(v), f=fract(v); f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { p=VERTEX; paint=COLOR; }
void fragment() {
	float coarse=noise(p*3.8), fine=noise(p*65.0);
	float value=0.78+0.20*coarse+0.09*fine;
	if(surface_kind==1) {
		float wave=p.z*48.0+sin(p.x*1.8+p.z*2.0)*1.4+noise(p*2.2)*3.2;
		float grain=sin(wave)*0.5+0.5;
		value=0.73+coarse*0.19+grain*0.09+fine*0.045;
	}
	ALBEDO=tint.rgb*paint.rgb*value;
	if(surface_kind==1) {
		vec2 uv=vertex_palette ? UV : vec2(p.z*0.7+0.17,p.x*0.22);
		vec3 timber=texture(atlas,vec2(0.5,0.0)+(fract(uv)*0.94+0.03)*0.5).rgb;
		float timber_value=dot(timber,vec3(0.25,0.65,0.10));
		timber=mix(timber,vec3(timber_value)*vec3(1.06,1.0,0.92),0.6);
		float pigment_value=dot(paint.rgb,vec3(0.25,0.65,0.10));
		vec3 pigment=vertex_palette ? vec3(pigment_value*3.2) : tint.rgb*1.5;
		ALBEDO=(timber*0.8+vec3(0.025))*pigment*value;
	}
	ROUGHNESS=0.97;
	SPECULAR=0.04;
}
