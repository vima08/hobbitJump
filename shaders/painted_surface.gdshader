shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform int material_kind = 0;
uniform float texture_scale = 0.45;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX * vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_normal = NORMAL;
}

vec3 sample_panel(vec2 p) {
	int panel = material_kind >= 4 ? 1 : material_kind;
	vec2 offset = vec2(float(panel % 2), float(panel / 2)) * 0.5;
	return texture(atlas, offset + (fract(p) * 0.94 + 0.03) * 0.5).rgb;
}

void fragment() {
	vec3 weights = pow(abs(local_normal), vec3(5.0));
	weights /= max(weights.x + weights.y + weights.z, 0.001);
	vec3 p = local_position * texture_scale;
	vec3 painted = sample_panel(p.zy) * weights.x + sample_panel(p.zx) * weights.y + sample_panel(p.xy) * weights.z;
	if (material_kind == 1) {
		// Thin grain along the board, with broad knots subdued by a second wash.
		vec3 grain = sample_panel(vec2(p.z * 2.7 + p.y, p.x * 0.22 + 0.31));
		painted = mix(painted, grain, 0.58);
	}
	if (material_kind == 4) {
		vec2 cap_center = vec2(sign(local_position.x) * 0.65, -0.25);
		float radius = length(local_position.xy - cap_center);
		float ring = sin(radius * 100.0 + sin(local_position.x * 31.0) * 0.4);
		painted = mix(vec3(0.22,0.13,0.058),vec3(0.43,0.29,0.13),0.55 + ring * 0.18);
	}
	if (material_kind == 5) {
		float bark = sin(local_position.z * 47.0 + sin(local_position.x * 3.0 + local_position.y * 6.0) * 1.7);
		painted *= 0.55 + smoothstep(-0.65, -0.1, bark) * 0.32;
		if (abs(local_normal.x) > 0.8) {
			float z = mod(local_position.z + 0.285, 0.57) - 0.285;
			float radius = length(vec2(local_position.y + 0.06, z));
			float rings = sin(radius * 110.0 + sin(local_position.y * 32.0) * 0.5);
			painted = mix(vec3(0.19,0.105,0.045), vec3(0.36,0.235,0.115),0.6 + rings * 0.18);
		}
	}
	ALBEDO = painted * tint.rgb;
	ROUGHNESS = 0.93;
	SPECULAR = 0.08;
}
