shader_type spatial;
render_mode cull_disabled;

uniform float foliage = 0.0;
uniform vec3 camera_cutout_start = vec3(0.0);
uniform vec3 camera_cutout_end = vec3(0.0);
uniform float camera_cutout_radius = 0.0;
uniform sampler2D painted_atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec3 world_position;
varying vec3 object_position;
varying vec3 world_normal;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.17, 0.31, 0.73));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y), mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	object_position = VERTEX;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
vec3 painted(vec2 uv, vec2 tile) {
	return texture(painted_atlas, tile * 0.5 + vec2(0.008) + fract(uv) * 0.484).rgb;
}
void fragment() {
	vec3 p = world_position;
	if (camera_cutout_radius > 0.0) {
		vec3 segment = camera_cutout_end - camera_cutout_start;
		float along = clamp(dot(p - camera_cutout_start, segment) / max(dot(segment, segment), 0.001), 0.0, 1.0);
		float distance_to_view = distance(p, camera_cutout_start + segment * along);
		float cutout = 1.0 - smoothstep(camera_cutout_radius * 0.65, camera_cutout_radius, distance_to_view);
		// Opaque dithering works in Compatibility without transparent sorting.
		float threshold = fract(dot(floor(FRAGCOORD.xy), vec2(0.754877666, 0.569840296)));
		if (cutout > threshold) { discard; }
	}
	float large = noise3(p * 0.85);
	float fine = noise3(p * 9.0);
	float grain = noise3(p * 38.0);
	float fissure = smoothstep(0.34, 0.42, abs(sin(p.y * 6.0 + noise3(p * 1.3) * 4.0)));
	vec3 stone = COLOR.rgb * (0.72 + large * 0.38 + fine * 0.2 + grain * 0.07);
	stone *= mix(0.8, 1.0, fissure);
	float leaf = smoothstep(0.35, 0.68, noise3(p * 5.0));
	vec3 green = COLOR.rgb * (0.62 + large * 0.40 + leaf * 0.27 + fine * 0.17);
	bool is_green = COLOR.g > COLOR.r * 1.025;
	vec2 tile = foliage > 0.5 ? (is_green ? vec2(1.0, 1.0) : vec2(1.0, 0.0)) : (is_green ? vec2(0.0) : vec2(0.0, 1.0));
	vec3 weights = pow(abs(world_normal), vec3(5.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	float tex_scale = is_green ? 0.23 : 0.16;
	vec3 pigment = painted(p.zy * tex_scale, tile) * weights.x + painted(p.xz * tex_scale, tile) * weights.y + painted(p.xy * tex_scale, tile) * weights.z;
	vec3 textured = pigment * 0.95 * mix(vec3(0.85), COLOR.rgb * 2.0, 0.32);
	float texture_amount = (COLOR.r > 0.7 && COLOR.g > 0.6 && COLOR.b > 0.35) ? 0.0 : 0.82;
	ALBEDO = mix(mix(stone, green, foliage), textured * (0.9 + fine * 0.16), texture_amount);
	ROUGHNESS = 0.94;
}
