shader_type spatial;
// Afficheur VFD à points : chaque pixel du texte devient un point lumineux.

uniform sampler2D text_tex : filter_nearest;
uniform vec2 cells = vec2(96.0, 24.0);
uniform vec3 on_color : source_color = vec3(0.49, 1.0, 0.9);
uniform float off_level = 0.05;
uniform float energy = 1.6;

void fragment() {
	vec2 g = UV * cells;
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float on = step(0.35, texture(text_tex, (cell + 0.5) / cells).r);
	float dot_mask = 1.0 - smoothstep(0.28, 0.40, length(f));
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.4;
	EMISSION = on_color * dot_mask * mix(off_level, 1.0, on) * energy;
}
