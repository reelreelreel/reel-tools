shader_type spatial;
// Œil de chat : globe dont l'avant (+Z local) porte l'iris ambré strié et la pupille fendue verticale.
// Le vernis (clearcoat) fait la cornée brillante.

uniform vec3 iris_in : source_color = vec3(0.55, 0.42, 0.06);
uniform vec3 iris_out : source_color = vec3(0.85, 0.66, 0.16);
uniform float pupil = 0.18;   // largeur de la fente (0..1)

varying vec3 lp;

void vertex() {
	lp = normalize(VERTEX);
}

void fragment() {
	float r = length(lp.xy);                 // 0 au centre de l'iris
	float front = step(0.0, lp.z);
	float iris = front * (1.0 - smoothstep(0.80, 0.86, r));
	float ang = atan(lp.y, lp.x);
	vec3 col = mix(iris_in, iris_out, smoothstep(0.1, 0.8, r));
	col *= 0.85 + 0.15 * sin(ang * 40.0);
	col *= 1.0 - 0.6 * smoothstep(0.7, 0.84, r);
	// pupille fendue verticale
	float slit = 1.0 - smoothstep(pupil * 0.6, pupil, abs(lp.x) / max(0.05, sqrt(max(0.0, 1.0 - lp.y * lp.y / 0.62))));
	slit *= step(abs(lp.y), 0.78);
	col = mix(col, vec3(0.01), slit * front);
	ALBEDO = mix(vec3(0.06, 0.05, 0.03), col, iris);
	ROUGHNESS = 0.3;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
	SPECULAR = 0.6;
}
