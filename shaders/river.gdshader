shader_type spatial;
uniform float river_time = 0.0;
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float ripple = sin(world_position.x * 1.7 - river_time * 1.3 + sin(world_position.z * 1.1));
	float detail = sin(world_position.z * 3.2 + world_position.x * 0.4 - river_time * 0.4);
	ALBEDO = mix(vec3(0.10, 0.37, 0.40), vec3(0.16, 0.49, 0.51), 0.5 + ripple * 0.22 + detail * 0.08);
	ROUGHNESS = 0.65;
	SPECULAR = 0.22;
}
