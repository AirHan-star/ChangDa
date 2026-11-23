shader_type canvas_item;
render_mode unshaded;

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float critical : hint_range(0.0, 1.0) = 0.0;

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float fog_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash_cell(cell), hash_cell(cell + vec2(1.0, 0.0)), f.x),
		mix(hash_cell(cell + vec2(0.0, 1.0)), hash_cell(cell + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 drift = vec2(TIME * 0.15, -TIME * 0.13);
	vec2 coordinates = UV * vec2(10.0, 6.0);
	float clouds = fog_noise(coordinates + drift) * 0.69;
	clouds += fog_noise(coordinates * 2.3 - drift) * 0.31;
	vec2 sides = abs(UV * 2.0 - 1.0);
	float distance_to_center = max(sides.x, sides.y);
	float edge = smoothstep(0.58, 1.04, distance_to_center + (clouds - 0.5) * 0.17);
	float pulse = 0.88 + 0.12 * sin(TIME * 3.9);
	float density = (critical * 0.39 * pulse + flash * 0.66) * (0.62 + clouds * 0.44);
	vec3 red = mix(vec3(0.32, 0.014, 0.026), vec3(0.73, 0.061, 0.056), flash);
	COLOR = vec4(red, edge * min(density, 0.76));
}
