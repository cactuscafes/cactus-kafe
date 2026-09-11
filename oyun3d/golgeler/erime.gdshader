shader_type spatial;

// Yenilen düşman için erime (dissolve).
//
// `esik` 0'dan 1'e giderken yüzey rastgele noktalardan delinir; deliğin
// kenarı parlar. Doku aramıyor: gürültü üç satırlık bir karma fonksiyonundan
// geliyor, böylece ek doku belleği ve içe aktarım derdi yok.

uniform sampler2D albedo_dokusu : source_color, filter_nearest;
uniform float esik : hint_range(0.0, 1.0) = 0.0;
uniform vec3 kenar_renk : source_color = vec3(1.0, 0.55, 0.35);
uniform float kenar_kalinligi = 0.12;
uniform float gurultu_olcegi = 14.0;

float karma(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// Kafes noktaları arasında yumuşak geçiş: saf karma "kar tanesi" gibi
// titrerdi, bu daha çok "yanarak dağılma" hissi veriyor.
float gurultu(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = karma(i);
	float n100 = karma(i + vec3(1, 0, 0));
	float n010 = karma(i + vec3(0, 1, 0));
	float n110 = karma(i + vec3(1, 1, 0));
	float n001 = karma(i + vec3(0, 0, 1));
	float n101 = karma(i + vec3(1, 0, 1));
	float n011 = karma(i + vec3(0, 1, 1));
	float n111 = karma(i + vec3(1, 1, 1));
	return mix(
		mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

varying vec3 yerel_konum;

void vertex() {
	yerel_konum = VERTEX;
}

void fragment() {
	float g = gurultu(yerel_konum * gurultu_olcegi);
	if (g < esik) {
		discard;
	}
	vec3 renk = texture(albedo_dokusu, UV).rgb;
	// Deliğin kenarını parlat: erimenin nereden ilerlediği görünsün.
	float kenar = 1.0 - smoothstep(esik, esik + kenar_kalinligi, g);
	ALBEDO = mix(renk, kenar_renk, kenar);
	EMISSION = kenar_renk * kenar * 1.6;
	ROUGHNESS = 0.85;
}
