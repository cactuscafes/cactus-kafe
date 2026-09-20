shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
// Dünya malzemesi: kutulara yüzey verir (Faz 13).
//
// SORUN: oyunun geometrisi kutudan ibaret ve her kutu TEK renkti. Dört metre
// eninde düz bir renk, ışık ne yaparsa yapsın "boyanmış karton" gibi duruyor;
// iki platform yan yana geldiğinde aralarındaki çizgi kayboluyor.
//
// ÇÖZÜM DOKU DEĞİL: her kutuya doku açmak UV, atlas ve bellek demek — üstelik
// kutular farklı ölçeklerde, doku gerilirdi. Bunun yerine yüzey DÜNYA
// KONUMUNDAN üretiliyor: bitişik iki kutu aynı desenin devamını taşıyor,
// ölçek ne olursa olsun desen aynı sıklıkta kalıyor.
//
// ÜÇ KATMAN, üçü de ayrı bir işi görüyor:
//   1. üç eksenli gürültü — yüzeyin düz renk olmaması
//   2. tabakalar          — yan yüzlerde yatay çökelti çizgileri (kaya hissi)
//   3. dip karartması     — kutunun alt kenarına doğru koyulaşma; yığılmış
//                           kutuların birbirinden ayrılmasını sağlayan şey bu
//
// WEB İÇİN: doku örneklemesi yok, döngü yok, türev yok — Compatibility
// (gl_compatibility) yolunda da aynı çalışıyor. Maliyeti ölçüldü:
// `araclar/olcum.tscn` sayıları Faz 12 ile aynı bandda.

uniform vec3 renk : source_color = vec3(1.0);
uniform float puruzluluk : hint_range(0.0, 1.0) = 0.9;
/// Desenin sıklığı (metre başına). Büyütmek deseni küçültür.
uniform float desen_olcek = 1.1;
uniform float desen_gucu : hint_range(0.0, 1.0) = 0.2;
/// Üste bakan yüzler güneşte ağarmış: yatay ile dikeyi ayıran şey.
uniform float ust_agarma : hint_range(0.0, 1.0) = 0.13;
/// Yan yüzlerdeki yatay tabakalar.
uniform float tabaka_gucu : hint_range(0.0, 1.0) = 0.07;
uniform float tabaka_sikligi = 2.6;
/// Kutunun dibine doğru karartma ve kaç metrede sönümlendiği.
uniform float dip_gucu : hint_range(0.0, 1.0) = 0.3;
uniform float dip_yukseklik = 0.8;

varying vec3 dunya_poz;
varying float dip_h;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gurultu(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Üç eksenli izdüşüm: UV'siz yüzey deseninin standart yolu. Ağırlıklar
// normalin karesinden geliyor — köşelerde üç izdüşüm yumuşak karışıyor.
float uc_eksenli(vec3 p, vec3 n) {
	vec3 a = abs(n);
	a = a / max(a.x + a.y + a.z, 0.0001);
	return gurultu(p.yz) * a.x + gurultu(p.xz) * a.y + gurultu(p.xy) * a.z;
}

void vertex() {
	dunya_poz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Kutunun KENDİ tabanından yükseklik (metre). Birim kutu -0,5..0,5
	// arasında; MODEL_MATRIX'in ikinci sütununun boyu kutunun gerçek boyu.
	// MultiMesh'te de doğru çalışıyor: örnek dönüşümü model matrisinde.
	dip_h = (VERTEX.y + 0.5) * length(MODEL_MATRIX[1].xyz);
}

void fragment() {
	// NORMAL görüş uzayında; dünya uzayına çevrilmeden üç eksenli izdüşüm
	// kamera döndükçe kayardı.
	vec3 dn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);

	float n = uc_eksenli(dunya_poz * desen_olcek, dn);
	// İkinci oktav yalnızca yakın plan için: daha ince benek.
	n = mix(n, gurultu(dunya_poz.xz * desen_olcek * 3.7), 0.25);
	float ton = 1.0 + (n - 0.5) * 2.0 * desen_gucu;

	// Tabakalar: yalnızca yan yüzlerde (dikeylik) ve gürültüyle kırılarak,
	// yoksa cetvelle çizilmiş gibi duruyor.
	float dikey = 1.0 - abs(dn.y);
	float tabaka = sin(dunya_poz.y * tabaka_sikligi + n * 2.5);
	ton += tabaka * tabaka_gucu * dikey;

	// Üst yüzeyler açılıyor.
	ton += smoothstep(0.55, 0.95, dn.y) * ust_agarma;

	// Dip karartması: kutunun alt kenarına doğru koyulaşma. Yığılmış
	// kutuların ayrışmasını sağlayan katman bu — SSAO'nun web'de olmadığı
	// yerde işi gören ucuz ama doğru yönde bir yaklaşım.
	ton -= dip_gucu * (1.0 - smoothstep(0.0, dip_yukseklik, dip_h));

	ALBEDO = renk * COLOR.rgb * max(ton, 0.05);
	ROUGHNESS = puruzluluk;
	SPECULAR = 0.18;
}
