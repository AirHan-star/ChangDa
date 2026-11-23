shader_type spatial;

uniform int district;
varying vec2 place;

void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float grain(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec2 axis = vec2(127.1, 311.7);
	float a = fract(sin(dot(cell, axis)) * 43758.5);
	float b = fract(sin(dot(cell + vec2(1.0, 0.0), axis)) * 43758.5);
	float c = fract(sin(dot(cell + vec2(0.0, 1.0), axis)) * 43758.5);
	float d = fract(sin(dot(cell + vec2(1.0, 1.0), axis)) * 43758.5);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float strata = grain(place * 0.29);
	float grit = grain(place * 9.6);
	float speckle = grain(place * 24.0);
	float line = abs(place.x - 0.43 * sin(place.y * 0.119));
	float path = 1.0 - smoothstep(2.15, 4.39, line + (strata - 0.5) * 1.35);
	vec3 ground = mix(vec3(0.23, 0.265, 0.195), vec3(0.43, 0.406, 0.292), strata);
	vec3 road = mix(vec3(0.29, 0.25, 0.20), vec3(0.44, 0.365, 0.28), strata);
	if (district == 3) {
		ground = mix(vec3(0.24, 0.22, 0.16), vec3(0.43, 0.378, 0.246), strata);
		road = mix(vec3(0.31, 0.263, 0.189), vec3(0.51, 0.433, 0.299), strata);
	} else if (district == 2) {
		ground = mix(vec3(0.285, 0.300, 0.279), vec3(0.428, 0.417, 0.374), strata);
		road = mix(vec3(0.173, 0.198, 0.198), vec3(0.259, 0.267, 0.252), strata);
		path = 1.0 - smoothstep(3.55, 4.15, abs(place.x));
		float seam = 1.0 - smoothstep(0.006, 0.023, abs(fract(place.y * 0.195 + (strata - 0.5) * 0.06) - 0.5));
		road -= seam * 0.035;
	}
	ALBEDO = mix(ground, road, path) * (0.86 + grit * 0.25);
	ALBEDO += smoothstep(0.78, 0.97, speckle) * vec3(0.061, 0.056, 0.043);
	ROUGHNESS = 0.94;
}
