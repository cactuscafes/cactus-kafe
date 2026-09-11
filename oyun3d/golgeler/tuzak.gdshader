shader_type spatial;
render_mode unshaded, cull_disabled;

// Dikenli alan: kayan uyarı şeritleri + nabız.
//
// ERİŞİLEBİLİRLİK: tehlike yalnızca KIRMIZI ile anlatılırsa kırmızı-yeşil renk
// körü oyuncu (erkeklerin ~%8'i) zemini tehlikeden ayıramaz. Şerit deseni ve
// nabız, renkten bağımsız ikinci bir işaret veriyor.
//
// Dünya koordinatı kullanılıyor çünkü alan çok büyük (90x12 m): UV'ye göre
// desen koyarsak şeritler metrelerce genişler.

uniform vec3 taban_renk : source_color = vec3(0.35, 0.19, 0.21);
uniform vec3 serit_renk : source_color = vec3(0.72, 0.24, 0.24);
uniform float serit_araligi = 1.6;   // metre
uniform float akis_hizi = 0.55;
uniform float nabiz_hizi = 1.8;

varying vec3 dunya_konum;

void vertex() {
	dunya_konum = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Çapraz şerit: x + z ekseninde ilerleyen testere dişi.
	float eksen = (dunya_konum.x + dunya_konum.z) / serit_araligi - TIME * akis_hizi;
	float serit = step(0.5, fract(eksen));

	// Nabız: bütün alan yavaşça parlayıp sönüyor.
	float nabiz = 0.82 + 0.18 * sin(TIME * nabiz_hizi);

	vec3 renk = mix(taban_renk, serit_renk, serit) * nabiz;
	ALBEDO = renk;
	EMISSION = renk * 0.35;
}
