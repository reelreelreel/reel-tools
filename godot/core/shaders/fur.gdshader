shader_type spatial;
// Fourrure en coques (shell fur) : chaque partie du chat est dessinée plusieurs fois, gonflée le long
// de sa normale ; à chaque coque on ne garde que les « poils » (cellules aléatoires) assez longs.
// Le pelage tigré est calculé dans le repère du maillage (rayures + ventre clair).
render_mode cull_back, depth_draw_opaque;

uniform vec3 base_col : source_color = vec3(0.82, 0.46, 0.18);
uniform vec3 stripe_col : source_color = vec3(0.42, 0.17, 0.05);
uniform vec3 belly_col : source_color = vec3(0.95, 0.9, 0.82);
uniform float fur_len = 0.008;
uniform vec2 density = vec2(260.0, 150.0);

instance uniform float shell = 0.0;          // 0 = peau, 1 = pointe des poils
instance uniform vec3 stripe_dir = vec3(0.0, 0.0, 1.0);
instance uniform float stripe_freq = 9.0;
instance uniform float belly = 0.0;          // 1 = dessous blanc
instance uniform float white = 0.0;          // 1 = partie entièrement blanche (pattes, museau)
instance uniform float len_scale = 1.0;
instance uniform float seed = 0.0;
instance uniform vec4 hole_a = vec4(0.0);   // trous (orbites des yeux) : xyz = centre, w = rayon
instance uniform vec4 hole_b = vec4(0.0);

varying vec3 mp;
varying vec3 mn;
varying vec2 uvp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	mp = VERTEX;
	mn = NORMAL;
	uvp = UV;
	// les poils retombent un peu vers le bas
	VERTEX += NORMAL * fur_len * len_scale * shell + vec3(0.0, -0.25, 0.0) * fur_len * len_scale * shell * shell;
}

void fragment() {
	vec3 p = mp;
	if ((hole_a.w > 0.0 && distance(p, hole_a.xyz) < hole_a.w) || (hole_b.w > 0.0 && distance(p, hole_b.xyz) < hole_b.w)) {
		discard;
	}
	float st = sin(dot(p, stripe_dir) * stripe_freq * 6.2831 + noise(p * 22.0 + seed) * 3.0);
	float stripe = smoothstep(0.25, 0.85, st) * (0.7 + 0.3 * noise(p * 60.0));
	float bel = max(white, belly * smoothstep(-0.15, -0.65, normalize(mn).y));
	vec3 col = mix(base_col * (0.9 + 0.2 * noise(p * 35.0 + seed)), stripe_col, stripe * 0.9 * (1.0 - bel));
	col = mix(col, belly_col, bel);
	if (shell > 0.0) {
		// poils = petits cônes : chaque cellule de la grille UV porte un poil de longueur aléatoire,
		// de plus en plus fin vers la pointe
		vec2 g = uvp * density * len_scale;
		vec2 cell = floor(g);
		vec2 off = vec2(hash(vec3(cell, seed)), hash(vec3(cell, seed + 7.0))) * 0.5 + 0.25;
		float d = length(fract(g) - off);
		float hair_len = 0.55 + 0.45 * hash(vec3(cell, seed + 3.0));
		if (shell > hair_len || d > 0.42 * (1.0 - shell / hair_len)) {
			discard;
		}
	}
	// racines plus sombres (ombre entre les poils), pointes plus claires
	float ao = mix(0.32, 1.08, shell);
	ALBEDO = col * ao;
	ROUGHNESS = 0.82;
	SPECULAR = 0.3;
	BACKLIGHT = col * 0.15 * shell;
}
