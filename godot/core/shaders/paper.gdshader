shader_type spatial;
render_mode cull_disabled;
// Papier dessiné en direct (fiches, post-it) : la texture vivante sert d'albedo, éclairée normalement.

uniform sampler2D paper_tex : source_color, filter_linear;
uniform float roughness_v = 0.9;

void fragment() {
	ALBEDO = texture(paper_tex, UV).rgb;
	ROUGHNESS = roughness_v;
}
