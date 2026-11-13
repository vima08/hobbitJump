shader_type spatial;
render_mode cull_disabled;
uniform float river_time = 0.0;
uniform vec3 camera_cutout_start = vec3(0.0);
uniform vec3 camera_cutout_end = vec3(0.0);
uniform float camera_cutout_radius = 0.0;
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
	vec3 p = world_position;
	if (camera_cutout_radius > 0.0) {
		vec3 segment = camera_cutout_end - camera_cutout_start;
		float along = clamp(dot(p - camera_cutout_start, segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
		float cutout = 1.0 - smoothstep(camera_cutout_radius * 0.65, camera_cutout_radius,
			distance(p, camera_cutout_start + segment * along));
		float threshold = fract(dot(floor(FRAGCOORD.xy), vec2(0.754877666, 0.569840296)));
		if (cutout > threshold) { discard; }
	}
	float fall = smoothstep(23.0, 24.1, p.x) * smoothstep(-10.15, -9.7, p.y);
	vec2 uv = mix(p.xz - vec2(river_time * 1.5, 0.0), vec2(p.y * 0.75 + river_time * 3.0, p.z * 2.1), fall);
	float broad = noise(uv * vec2(1.1, 1.4));
	float threads = noise(uv * vec2(2.5, 3.8) + broad);
	float crest = smoothstep(20.5, 23.0, p.x) * (1.0 - smoothstep(23.0, 24.0, p.x)) * step(-0.8, p.y);
	float foam = smoothstep(0.53, 0.86, threads) * (fall * 0.7 + crest * 0.65);
	float spray = (1.0 - smoothstep(-9.9, -8.7, p.y)) * (1.0 - smoothstep(28.0, 32.0, p.x));
	foam = max(foam, spray * smoothstep(0.35, 0.8, broad));
	ALBEDO = mix(vec3(0.065, 0.19, 0.18), vec3(0.20, 0.36, 0.31), broad);
	ALBEDO = mix(ALBEDO, vec3(0.62, 0.73, 0.62), foam);
	ROUGHNESS = 0.68;
	SPECULAR = 0.18;
	NORMAL_MAP = normalize(vec3((threads - 0.5) * 0.035, (broad - 0.5) * 0.035, 1.0)) * 0.5 + 0.5;
}
