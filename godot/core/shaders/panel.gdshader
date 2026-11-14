// Lambris : planches verticales, fil du bois vertical, chaque planche décalée (INSTANCE_CUSTOM)
// pour que le veinage ne se répète pas. Projection dans le plan du mur (monde).
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wear_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 1.4;
uniform float rough = 0.75;
uniform float coat = 0.12;
uniform float normal_depth = 1.0;

varying vec3 wpos;
varying vec3 wnrm;
varying vec4 icustom;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	icustom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 uv;
	if (abs(wnrm.y) > 0.7) {
		uv = wpos.xz;
	} else {
		uv = vec2(abs(wnrm.x) > abs(wnrm.z) ? wpos.z : wpos.x, wpos.y);
	}
	// fil vertical : on échange les axes de la texture (dont le fil est horizontal)
	vec2 st = vec2(uv.y / scale + icustom.y, uv.x / (scale * 3.0) + icustom.x);
	vec3 a = texture(albedo_tex, st).rgb;
	float w = texture(wear_tex, uv * 0.35 + icustom.xy).r;
	ALBEDO = a * tint.rgb * mix(0.82, 1.12, icustom.z) * mix(0.9, 1.0, w);
	vec3 n = texture(normal_tex, st).rgb;
	NORMAL_MAP = vec3(n.g, n.r, n.b);
	NORMAL_MAP_DEPTH = normal_depth;
	ROUGHNESS = clamp(texture(rough_tex, st).r * rough, 0.05, 1.0);
	CLEARCOAT = coat;
	CLEARCOAT_ROUGHNESS = 0.45;
	SPECULAR = 0.5;
}
