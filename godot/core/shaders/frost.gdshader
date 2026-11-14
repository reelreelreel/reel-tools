// Verre dépoli pour l'interface : flou de ce qu'il y a derrière + teinte sombre.
// La forme (coins arrondis, anticrénelage) vient du StyleBox : on garde son alpha comme masque.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.07, 0.07, 0.08, 0.58);
uniform float blur = 3.2;
uniform float lift = 0.04;

void fragment() {
	vec3 b = textureLod(screen_tex, SCREEN_UV, blur).rgb;
	b += textureLod(screen_tex, SCREEN_UV + vec2(0.004, 0.0), blur).rgb;
	b += textureLod(screen_tex, SCREEN_UV - vec2(0.004, 0.0), blur).rgb;
	b += textureLod(screen_tex, SCREEN_UV + vec2(0.0, 0.006), blur).rgb;
	b /= 4.0;
	vec3 c = mix(b, tint.rgb, tint.a) + lift;
	COLOR = vec4(c, COLOR.a);
}
