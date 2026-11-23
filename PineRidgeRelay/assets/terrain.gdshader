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
	float verge_noise = grain(map_position * 2.4);
	float leaf_litter = smoothstep(0.44, 0.78, verge_noise) * (0.30 + 0.34 * large_grain);
	vec3 woods = mix(vec3(0.155, 0.203, 0.154), vec3(0.29, 0.32, 0.20), large_grain);
	woods = mix(woods, vec3(0.34, 0.28, 0.179), leaf_litter);
	vec3 dirt = mix(vec3(0.32, 0.254, 0.184), vec3(0.49, 0.366, 0.240), large_grain);
	float rut = 1.0 - smoothstep(0.035, 0.17, abs(abs(map_position.x - center) - 0.69));
	dirt *= 1.0 - rut * (0.065 + 0.045 * verge_noise);
	float gravel = smoothstep(0.71, 0.91, fine_grain) * (0.35 + 0.45 * verge_noise);
	ALBEDO = mix(woods, dirt, trail) * (0.89 + fine_grain * 0.18)
		+ vec3(0.10, 0.08, 0.055) * gravel * (0.42 + 0.58 * trail);
	ROUGHNESS = 1.0;
}
