shader_type spatial;
uniform sampler2D hero_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
varying vec3 position_in_piece;
varying vec3 normal_in_piece;
void vertex() { position_in_piece = VERTEX; normal_in_piece = NORMAL; }

vec3 atlas_sample(vec2 uv, vec2 quadrant) {
	// Keep filtering inside each tile, including the mipmap footprint.
	return texture(hero_atlas, quadrant * 0.5 + vec2(0.006) + fract(uv) * 0.488, 1.1).rgb;
}

vec3 painted_pattern(vec3 p, vec3 normal, vec2 tile, float scale) {
	vec3 weight = pow(abs(normalize(normal)), vec3(5.0));
	weight /= max(weight.x + weight.y + weight.z, 0.001);
	return atlas_sample(p.zy * scale, tile) * weight.x
		+ atlas_sample(p.xz * scale, tile) * weight.y
		+ atlas_sample(p.xy * scale, tile) * weight.z;
}
void fragment() {
	vec3 p = position_in_piece;
	// Vertex alpha records the painted surface category; it is not transparency.
	bool skin = COLOR.a < 0.3;
	bool hair = COLOR.a > 0.8;
	bool cloth = COLOR.a > 0.45 && COLOR.a < 0.8;
	float weave = sin(p.x * 600.0) * sin(p.y * 620.0);
	float footprint = max(length(fwidth(p) * 620.0), 0.001);
	float thread = weave * 0.035 * (1.0 - smoothstep(0.5, 2.0, footprint));
	float wash = sin(p.y * 42.0 + sin(p.x * 25.0)) * 0.045 + sin(p.x * 115.0 + p.y * 63.0) * 0.025;
	float folds = sin(p.y * 32.0 + sin(p.x * 24.0) * 1.8) * 0.055;
	bool mantle = COLOR.g > COLOR.r * 1.5;
	// Broad alternating painted folds provide form at the playing distance.
	float drape = sin(p.x * (mantle ? 38.0 : 24.0) + sin(p.y * 8.0) * 0.8);
	float fold_light = drape * 0.13 - pow(max(0.0, -drape), 5.0) * 0.10;
	float twill = sin((p.x + abs(fract(p.y * 170.0) - 0.5) * 0.009) * 900.0);
	float weave_detail = twill * 0.025 * (1.0 - smoothstep(0.5, 2.0, footprint));
	float cloth_wear = wash + thread + folds + weave_detail + (mantle ? fold_light : fold_light * 0.45);
	float wear = skin ? wash * 0.25 : (hair ? wash * 0.5 : cloth_wear);
	vec3 pigment = COLOR.rgb * (1.0 + wear);
	if (cloth || hair) {
		bool linen = COLOR.r < COLOR.g * 1.3 && !mantle;
		vec2 tile = hair ? vec2(1.0, 1.0) : (mantle ? vec2(0.0, 1.0) : (linen ? vec2(0.0, 0.0) : vec2(1.0, 0.0)));
		float mean_value = hair ? 0.0279 : (mantle ? 0.0461 : (linen ? 0.3474 : 0.0294));
		if (OUTPUT_IS_SRGB) {
			mean_value = hair ? 0.1688 : (mantle ? 0.2282 : (linen ? 0.5941 : 0.1590));
		}
		vec3 pattern = painted_pattern(p, normal_in_piece, tile, hair ? 2.5 : 0.9);
		float value = dot(pattern, vec3(0.2126, 0.7152, 0.0722));
		// Measured tile means preserve costume pigments while carrying actual
		// painted creases, woven fibers, rubbed ridges and hair strand strokes.
		float painted_value = clamp(value / mean_value, 0.4, 1.45);
		pigment *= mix(1.0, painted_value, hair ? 0.85 : 0.92);
	}
	ALBEDO = pigment * (skin ? 0.95 : (cloth ? 0.98 : 0.85));
	ROUGHNESS = skin ? 0.8 : (hair ? 0.78 : 0.96);
	SPECULAR = 0.12;
}
