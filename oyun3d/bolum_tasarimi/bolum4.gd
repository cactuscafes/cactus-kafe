extends RefCounted
## Bölüm 4 — "Rüzgâr Terası"
##
## FİKİR: hareketli platform, bölüm 1'de bir kez karşına çıkıyordu. Burada asıl
## dil o. Öğretilen beceri zıplamak değil, BEKLEMEK: platform sana gelene kadar
## durmak, doğru anda binmek, inmeden önce bir tur daha beklemeyi göze almak.
## Hızlı koşan oyuncuyu duvarla değil ritimle yavaşlatmanın tek dürüst yolu.
##
## Dört hareketli platformun üçü farklı eksende gidiyor (ileri, yanal, dikey);
## dördüncüsü çapraz. Aynı mekaniğin dört tadı, dört yeni mekanik değil.

const VERI := {
	"kimlik": "bolum4",
	"ad": "BOLUM4_AD",

	"zemin_olcu": 140.0,
	"zemin_tuzakli": true,
	"gok_ufuk": Color(0.66, 0.71, 0.78),
	"gok_ust": Color(0.27, 0.35, 0.47),
	"gok_yer": Color(0.26, 0.28, 0.32),
	"sis_renk": Color(0.68, 0.72, 0.78),
	"sis": 0.0050,
	"gunes_aci": Vector3(-58, -15, 0),
	"gunes_gucu": 0.9,

	"oyuncu": Vector3(0, 2.6, 12.5),

	"tuzaklar": [
		{"konum": Vector3(0, 0.6, 0), "olcu": Vector3(140, 1.2, 140), "gorsel": false},
	],

	"platformlar": [
		{"ad": "Baslangic", "konum": Vector3(0, 1.0, 12.0), "olcu": Vector3(8, 1.2, 8),
			"renk": Color(0.5, 0.47, 0.42)},
		{"ad": "Sahanlik1", "konum": Vector3(0, 1.4, 4.4), "olcu": Vector3(4.5, 0.8, 4.5),
			"renk": Color(0.47, 0.44, 0.40)},
		# Asansör1'in indiği yer burası; aradaki 3 m'yi platform kapatıyor.
		{"ad": "Sahanlik2", "konum": Vector3(0, 2.2, -11.5), "olcu": Vector3(5.5, 0.8, 5.5),
			"renk": Color(0.47, 0.44, 0.40)},
		{"ad": "Sahanlik3", "konum": Vector3(7.5, 3.0, -21.0), "olcu": Vector3(6, 0.8, 6),
			"renk": Color(0.45, 0.43, 0.40)},
		{"ad": "Sahanlik4", "konum": Vector3(7.5, 5.8, -31.5), "olcu": Vector3(6.5, 0.8, 6.5),
			"renk": Color(0.45, 0.43, 0.40)},
		{"ad": "Tas1", "konum": Vector3(4.0, 6.6, -37.0), "olcu": Vector3(2.8, 0.6, 2.8),
			"renk": Color(0.55, 0.49, 0.38)},
		{"ad": "Tas2", "konum": Vector3(0.5, 7.4, -41.0), "olcu": Vector3(2.8, 0.6, 2.8),
			"renk": Color(0.55, 0.49, 0.38)},
		{"ad": "Tepe", "konum": Vector3(0, 8.0, -47.0), "olcu": Vector3(7, 0.8, 7),
			"renk": Color(0.44, 0.51, 0.42)},
	],

	"hareketliler": [
		# İleri-geri: binip taşınıyorsun, boşluk 9 m ve başka yolu yok.
		{"ad": "Mekik", "konum": Vector3(0, 1.8, -1.5), "uc": Vector3(0, 0, -6.0),
			"sure": 6.5},
		# Yanal: inerken hedef kayıyor, iniş anını seçmek gerekiyor.
		{"ad": "Kaydirak", "konum": Vector3(0.5, 2.6, -16.5), "uc": Vector3(7.0, 0, 0),
			"sure": 5.5, "faz": 0.3},
		# Dikey asansör: klasik, ama 2,8 m yükseliyor — zıplamayla çıkılamaz.
		{"ad": "Asansor", "konum": Vector3(7.5, 3.4, -26.0), "uc": Vector3(0, 2.6, 0),
			"sure": 5.0},
		# Çapraz: hem yükseliyor hem yanaşıyor. Son teras buna bağlı.
		{"ad": "Capraz", "konum": Vector3(0.5, 7.6, -44.0), "uc": Vector3(-0.5, 0.6, -2.0),
			"sure": 4.5, "faz": 0.5},
	],

	"cicekler": [
		Vector3(0, 2.6, 4.4),
		Vector3(0, 3.0, -5.0),
		Vector3(0, 3.4, -11.5),
		Vector3(-2.0, 3.8, -16.5),
		Vector3(7.5, 4.2, -21.0),
		Vector3(7.5, 7.0, -31.5),
		Vector3(4.0, 7.8, -37.0),
		Vector3(0.5, 8.6, -41.0),
		Vector3(0, 9.2, -47.0),
	],

	"kontrol_noktalari": [
		Vector3(0, 2.7, -11.5),
		Vector3(7.5, 6.3, -31.5),
	],

	"bitis": Vector3(0, 10.0, -47.0),

	"dusmanlar": [
		{"konum": Vector3(6.0, 3.5, -21.0), "aci": 90.0, "devriye_ucu": Vector3(3.0, 0, 0)},
		{"konum": Vector3(7.5, 6.3, -33.0), "aci": 0.0, "devriye_ucu": Vector3(0, 0, 3.0)},
		{"konum": Vector3(-2.0, 8.5, -48.0), "aci": 90.0, "devriye_ucu": Vector3(4.0, 0, 0)},
		# HOPLAYAN BURADA TANITILIYOR. Asansörün indirdiği geniş sahanlıkta
		# bekliyor: oyuncu havada da tehdit olduğunu, düşme riskinin düşük
		# olduğu bir yerde öğreniyor.
		{"tur": "hoplayan", "konum": Vector3(0.0, 3.0, -11.5), "aci": 180.0},
	],

	"susleme": [
		{"tur": "tabela", "konum": Vector3(2.8, 1.6, 14.0), "aci": -22.0},
		{"tur": "kaya", "konum": Vector3(-3.0, 1.6, 13.6), "aci": 70.0, "olcek": 0.85},
		{"tur": "kaktus", "konum": Vector3(3.2, 1.6, 10.0), "aci": 10.0, "olcek": 0.95},
		{"tur": "sandik", "konum": Vector3(9.4, 3.4, -22.6), "aci": -40.0},
		{"tur": "kaya", "konum": Vector3(5.6, 6.2, -33.2), "aci": 25.0, "olcek": 0.75},
		{"tur": "kaktus", "konum": Vector3(2.6, 8.4, -48.6), "aci": -15.0, "olcek": 1.1},
	],
}
