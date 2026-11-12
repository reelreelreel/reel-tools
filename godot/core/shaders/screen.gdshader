shader_type spatial;
// Écran vivant (LED, oscillo, TV) : l'image émet sa propre lumière.

uniform sampler2D screen_tex : source_color, filter_linear;
uniform float energy = 1.4;

void fragment() {
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.4;
	EMISSION = texture(screen_tex, UV).rgb * energy;
}
