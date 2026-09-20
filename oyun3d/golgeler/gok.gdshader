shader_type sky;
// Gökyüzü: degrade + bulut bandı + güneş diski (Faz 13).
//
// NEDEN GÖLGELENDİRİCİ: `ProceduralSkyMaterial` üç renkli bir degrade veriyor
// ve orada bitiyor. Ufukta hiçbir şey yok — oyunun her karesinin üçte biri
// düz bir renk. Bulut bandı ve güneş diski ekranın o üçte birini "gökyüzü"
// yapıyor, üstelik bedeli yok: gökyüzü kare başına bir kez, derinlik testi
// olmadan çiziliyor.
//
// WEB İÇİN: Compatibility (gl_compatibility) render yolunda da çalışması
// gerekiyor — oyunun ana dağıtımı tarayıcı. Bu yüzden döngü sayısı sabit,
// doku örneklemesi yok, türev (dFdx) kullanılmıyor.

uniform vec3 ust_renk : source_color = vec3(0.35, 0.45, 0.62);
uniform vec3 ufuk_renk : source_color = vec3(0.72, 0.75, 0.71);
uniform vec3 yer_renk : source_color = vec3(0.35, 0.37, 0.34);
uniform vec3 bulut_renk : source_color = vec3(1.0, 0.97, 0.93);
// 0 = bulutsuz. Bölüm başına ayarlanıyor: berrak öğle ile akşam farklı.
uniform float bulut_miktari : hint_range(0.0, 1.0) = 0.45;
uniform float bulut_hizi = 0.004;
// Güneşin çevresindeki sıcak hâle — ufuk rengiyle güneş arasını bağlıyor.
uniform float hale_gucu : hint_range(0.0, 3.0) = 1.1;

// Değer gürültüsü (value noise). Doku yok: hash + üç doğrusal aradeğerleme.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float gurultu(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);          // yumuşatma (smoothstep)
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Üç oktav yeter: dördüncüsü bu ölçekte görünmüyor ama maliyeti aynı.
float bulut_deseni(vec2 p) {
	float toplam = gurultu(p) * 0.55;
	toplam += gurultu(p * 2.3) * 0.28;
	toplam += gurultu(p * 4.7) * 0.17;
	return toplam;
}

void sky() {
	float y = EYEDIR.y;
	// Degrade: ufuktan yukarı ve aşağı ayrı eğriler. pow(), ufuk çizgisini
	// keskinleştiriyor — doğrusal karışım gökyüzünü "boyanmış" gösteriyor.
	vec3 renk = mix(ufuk_renk, ust_renk, pow(clamp(y, 0.0, 1.0), 0.45));
	renk = mix(renk, yer_renk, pow(clamp(-y, 0.0, 1.0), 0.35));

	if (y > 0.0 && bulut_miktari > 0.001) {
		// Düzleme izdüşümü: ufka yaklaşırken bulutlar doğal olarak sıkışıyor.
		vec2 uv = EYEDIR.xz / max(y + 0.12, 0.02);
		vec2 kayma = vec2(TIME * bulut_hizi, TIME * bulut_hizi * 0.6);
		float d = bulut_deseni(uv * 0.55 + kayma);
		// Eşik bulut_miktari ile iniyor: az bulut = seyrek ve küçük lekeler.
		float esik = mix(0.75, 0.38, bulut_miktari);
		float ortu = smoothstep(esik, esik + 0.18, d);
		// Ufka doğru sönüm: bulutlar sise karışmalı, çizgide kesilmemeli.
		ortu *= smoothstep(0.0, 0.22, y);
		// Alt kenarları gölgeli: düz beyaz leke "kâğıt" gibi duruyor.
		vec3 b = mix(bulut_renk * 0.72, bulut_renk, smoothstep(esik, esik + 0.45, d));
		renk = mix(renk, b, ortu * 0.85);
	}

	if (LIGHT0_ENABLED) {
		float ac = dot(EYEDIR, LIGHT0_DIRECTION);
		// Hâle: güneşten uzaklaştıkça hızla sönen geniş bir parlaklık.
		renk += LIGHT0_COLOR * hale_gucu * pow(max(ac, 0.0), 28.0) * 0.35;
		// Disk: LIGHT0_SIZE derece cinsinden açısal yarıçap.
		float disk = cos(radians(max(LIGHT0_SIZE, 0.5)));
		renk = mix(renk, LIGHT0_COLOR * 4.0,
			smoothstep(disk - 0.0016, disk + 0.0004, ac));
	}
	COLOR = renk;
}
