shader_type spatial;
uniform float river_time = 0.0;
varying vec3 world_position;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 flow = world_position.xz - vec2(river_time * 0.42, 0.0);
	float broad = noise(flow * vec2(0.2, 0.45));
	float detail = noise(flow * vec2(1.0, 3.6) + broad * 2.0);
	float ripple = noise(flow * vec2(0.9, 4.0) + broad) * 2.0 - 1.0;
	float foam = smoothstep(0.72, 0.89, detail) * smoothstep(0.6, 1.0, ripple) * 0.6;
	ALBEDO = mix(vec3(0.055, 0.17, 0.17), vec3(0.15, 0.31, 0.27), broad * 0.75 + detail * 0.25);
	ALBEDO = mix(ALBEDO, vec3(0.24, 0.34, 0.29), foam);
	NORMAL_MAP = normalize(vec3((detail - 0.5) * 0.018, ripple * 0.018, 1.0)) * 0.5 + 0.5;
	ROUGHNESS = 0.65;
	SPECULAR = 0.18;
}
