shader_type canvas_item;
// Grain de pellicule animé + vignettage, posés par-dessus l'image 3D.

uniform float grain_amount = 0.04;
uniform float vignette = 0.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float t = floor(TIME * 7.0);
	float n = hash(floor(FRAGCOORD.xy / 1.5) + vec2(t * 17.13, t * 3.7));
	float r = length((UV - 0.5) / vec2(1.2, 0.95));
	float v = clamp((r - 0.52) / 0.48, 0.0, 1.0) * vignette;
	float g = grain_amount * (1.0 - v);
	float a = v + g;
	COLOR = vec4(vec3(n * g / max(a, 0.0001)), a);
}
