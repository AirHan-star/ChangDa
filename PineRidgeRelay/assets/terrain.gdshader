shader_type spatial;

// World-space bands keep the trail aligned with the supply locations.
varying vec2 map_position;

void vertex() {
	map_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	vec2 s = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(cell), hash(cell + vec2(1.0, 0.0)), s.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0, 1.0)), s.x),
		s.y
	);
}

void fragment() {
	float z = map_position.y;
	float center = min(max(z, 0.0), 10.0) * 0.23 - clamp(z - 10.0, 0.0, 14.0) * 0.36;
	float large_grain = grain(map_position * 0.32);
	float fine_grain = grain(map_position * 5.3);
	float edge = abs(map_position.x - center) + (large_grain - 0.5) * 0.95;
	float trail = (1.0 - smoothstep(1.19, 1.98, edge))
		* smoothstep(-9.0, -6.5, z) * (1.0 - smoothstep(28.0, 34.0, z));
	vec3 woods = mix(vec3(0.17, 0.23, 0.17), vec3(0.32, 0.36, 0.23), large_grain);
	vec3 dirt = mix(vec3(0.38, 0.29, 0.19), vec3(0.57, 0.43, 0.27), large_grain);
	ALBEDO = mix(woods, dirt, trail) * (0.86 + fine_grain * 0.26);
	ROUGHNESS = 1.0;
}
