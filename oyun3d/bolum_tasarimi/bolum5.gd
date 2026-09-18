extends RefCounted
## Bölüm 5 — "Kaya Bahçesi"
##
## FİKİR: üç bölümdür ölüm sebebi düşmek. Burada düşman. Zemin GÜVENLİ (dikenli
## şeritler dışında), platformlar geniş — yani zıplama baskısı yok, dövüş
## baskısı var. Beş düşman, hepsi geniş alanlarda; üstlerine binmeden geçmek de
## mümkün ama çiçeklerin yarısı onların devriye alanında.
##
## Zemin güvenli olduğu için düşmanlar zeminde de yürüyebiliyor: navigasyon
## örgüsü buraya asıl işini yapıyor. Dikenli şeritler geçişleri daraltıyor;
## "kaçacak yer var ama dar" hissi bundan geliyor.

const VERI := {
	"kimlik": "bolum5",
	"ad": "BOLUM5_AD",

	"zemin_olcu": 140.0,
	"zemin_renk": Color(0.55, 0.50, 0.40),
	"gok_ufuk": Color(0.80, 0.74, 0.60),
	"gok_yer": Color(0.38, 0.34, 0.28),
	"sis_renk": Color(0.80, 0.76, 0.66),
	"sis": 0.0030,
	"gunes_aci": Vector3(-64, 32, 0),
	"gunes_gucu": 0.95,

	"oyuncu": Vector3(0, 1.5, 14.0),

	# Şeritler geçişi daraltıyor: düşmandan kaçarken nereye basacağın önemli.
	"tuzaklar": [
		{"konum": Vector3(0, 0.3, 6.0), "olcu": Vector3(26, 0.6, 3.0)},
		{"konum": Vector3(-9, 0.3, -12.0), "olcu": Vector3(18, 0.6, 3.0)},
		{"konum": Vector3(10, 0.3, -24.0), "olcu": Vector3(20, 0.6, 3.0)},
	],

	"platformlar": [
		# Şeridin üstünden geçiren üç taş: koşarak da geçilir, basarak da.
		{"ad": "Gecit1", "konum": Vector3(-4.0, 0.9, 6.0), "olcu": Vector3(3, 0.6, 5),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Gecit2", "konum": Vector3(5.0, 0.9, 6.0), "olcu": Vector3(3, 0.6, 5),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Meydan", "konum": Vector3(0, 1.0, -3.0), "olcu": Vector3(16, 0.5, 12),
			"renk": Color(0.53, 0.48, 0.37)},
		{"ad": "Kaya1", "konum": Vector3(-5.0, 1.9, -5.0), "olcu": Vector3(3, 1.3, 3),
			"renk": Color(0.47, 0.44, 0.42)},
		# 1,9 m yüksekti: üstüne zıplanamıyordu (zıplama 1,65 m). Doğrulayıcı
		# yakaladı; kaya 1,3 m'ye indi, çiçek de onunla birlikte.
		{"ad": "Kaya2", "konum": Vector3(5.5, 1.85, -1.0), "olcu": Vector3(3.5, 1.3, 3.5),
			"renk": Color(0.47, 0.44, 0.42)},
		{"ad": "Gecit3", "konum": Vector3(3.0, 0.9, -12.0), "olcu": Vector3(4, 0.6, 5),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Teras", "konum": Vector3(0, 1.2, -19.0), "olcu": Vector3(14, 0.7, 10),
			"renk": Color(0.53, 0.48, 0.37)},
		{"ad": "Kaya3", "konum": Vector3(-4.0, 2.3, -21.0), "olcu": Vector3(3.5, 1.5, 3.5),
			"renk": Color(0.47, 0.44, 0.42)},
		{"ad": "Gecit4", "konum": Vector3(-3.0, 0.9, -24.0), "olcu": Vector3(4, 0.6, 5),
			"renk": Color(0.58, 0.5, 0.36)},
		# Bitiş kulesi: üç kademe, her biri 1,2 m. Bölümün tek dikey parçası.
		{"ad": "Kule1", "konum": Vector3(0, 0.8, -31.0), "olcu": Vector3(6, 1.6, 6),
			"renk": Color(0.5, 0.45, 0.35)},
		{"ad": "Kule2", "konum": Vector3(3.5, 1.9, -35.5), "olcu": Vector3(4.5, 1.6, 4.5),
			"renk": Color(0.5, 0.45, 0.35)},
		{"ad": "Kule3", "konum": Vector3(0, 3.0, -39.5), "olcu": Vector3(6, 1.6, 6),
			"renk": Color(0.45, 0.52, 0.42)},
	],

	"hareketliler": [
		{"ad": "Salincak", "konum": Vector3(-6.0, 1.6, -30.0), "uc": Vector3(0, 0, -6.0),
			"sure": 6.0, "faz": 0.4},
	],

	"cicekler": [
		Vector3(-4.0, 2.2, 6.0),
		Vector3(5.0, 2.2, 6.0),
		Vector3(-5.0, 3.4, -5.0),
		Vector3(5.5, 3.4, -1.0),
		Vector3(0, 2.3, -3.0),
		Vector3(3.0, 2.2, -12.0),
		Vector3(-4.0, 3.8, -21.0),
		Vector3(4.5, 2.5, -19.0),
		Vector3(-6.0, 3.0, -33.0),
		Vector3(0, 4.9, -39.5),
	],

	"kontrol_noktalari": [
		Vector3(0, 1.6, -3.0),
		Vector3(0, 1.9, -19.0),
	],

	"bitis": Vector3(0, 5.8, -39.5),

	"dusmanlar": [
		{"konum": Vector3(-3.0, 1.4, -3.0), "aci": 90.0, "devriye_ucu": Vector3(6.0, 0, 0)},
		{"konum": Vector3(4.0, 1.4, -6.0), "aci": 0.0, "devriye_ucu": Vector3(0, 0, 4.0)},
		{"konum": Vector3(-4.0, 1.7, -17.0), "aci": 90.0, "devriye_ucu": Vector3(7.0, 0, 0)},
		{"konum": Vector3(3.0, 1.7, -22.0), "aci": 180.0, "devriye_ucu": Vector3(-5.0, 0, 0)},
		{"konum": Vector3(0, 1.8, -31.0), "aci": 0.0, "devriye_ucu": Vector3(0, 0, -3.0)},
	],

	"susleme": [
		{"tur": "tabela", "konum": Vector3(2.4, 0.0, 15.6), "aci": -12.0},
		{"tur": "kaktus", "konum": Vector3(-3.6, 0.0, 15.0), "aci": 40.0, "olcek": 1.1},
		{"tur": "kaya", "konum": Vector3(6.6, 0.0, 12.0), "aci": 130.0, "olcek": 0.9},
		{"tur": "kaktus", "konum": Vector3(-7.4, 1.25, -1.0), "aci": -30.0, "olcek": 0.85},
		{"tur": "sandik", "konum": Vector3(6.8, 1.25, -6.4), "aci": 18.0},
		{"tur": "kaya", "konum": Vector3(-6.2, 1.55, -22.4), "aci": 95.0, "olcek": 0.8},
		{"tur": "kaktus", "konum": Vector3(5.8, 1.55, -21.6), "aci": -55.0, "olcek": 1.0},
		{"tur": "kaya", "konum": Vector3(-2.6, 0.0, -36.0), "aci": 20.0, "olcek": 1.2},
	],
}
