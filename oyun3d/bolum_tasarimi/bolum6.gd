extends RefCounted
## Bölüm 6 — "Son Tırmanış"
##
## FİKİR: finalde yeni mekanik YOK. Öğretilenlerin hepsi arka arkaya, dinlenme
## aralıkları kısalmış hâlde: dar taşlar (bölüm 3), hareketli platformlar
## (bölüm 4), düşman baskısı (bölüm 5) ve bölüm 2'nin dikeyliği. Yeni bir şey
## öğretmek yerine öğrenileni sınamak — son bölümün işi bu.
##
## En uzun bölüm: üç kontrol noktası var ama aralar uzun. Zorluk ölüm sayısıyla
## değil, hatanın maliyetiyle artıyor.

const VERI := {
	"kimlik": "bolum6",
	"ad": "BOLUM6_AD",

	"zemin_olcu": 150.0,
	"zemin_tuzakli": true,
	"gok_ufuk": Color(0.85, 0.66, 0.50),
	"gok_ust": Color(0.35, 0.30, 0.42),
	"gok_yer": Color(0.30, 0.22, 0.20),
	"sis_renk": Color(0.82, 0.68, 0.56),
	"sis": 0.0055,
	"gunes_aci": Vector3(-24, 118, 0),   # alçak akşam güneşi, uzun gölgeler
	"gunes_gucu": 1.0,

	"oyuncu": Vector3(0, 2.4, 13.0),

	"tuzaklar": [
		{"konum": Vector3(0, 0.6, 0), "olcu": Vector3(150, 1.2, 150), "gorsel": false},
	],

	"platformlar": [
		{"ad": "Baslangic", "konum": Vector3(0, 1.0, 13.0), "olcu": Vector3(7, 1.2, 7),
			"renk": Color(0.5, 0.45, 0.38)},
		# 1) Dar taşlar — bölüm 3'ün dili, biraz daha aralıklı.
		{"ad": "Tas1", "konum": Vector3(0, 1.2, 6.5), "olcu": Vector3(2.2, 0.6, 2.2),
			"renk": Color(0.56, 0.48, 0.36)},
		{"ad": "Tas2", "konum": Vector3(-2.6, 1.6, 2.5), "olcu": Vector3(2.2, 0.6, 2.2),
			"renk": Color(0.56, 0.48, 0.36)},
		{"ad": "Tas3", "konum": Vector3(0.6, 2.0, -1.5), "olcu": Vector3(2.2, 0.6, 2.2),
			"renk": Color(0.56, 0.48, 0.36)},
		{"ad": "Sahanlik1", "konum": Vector3(0, 2.4, -7.5), "olcu": Vector3(6, 0.8, 6),
			"renk": Color(0.48, 0.44, 0.39)},
		# 2) Hareketli platform zinciri — bölüm 4'ün dili.
		{"ad": "Sahanlik2", "konum": Vector3(0, 3.6, -21.0), "olcu": Vector3(6, 0.8, 6),
			"renk": Color(0.48, 0.44, 0.39)},
		{"ad": "Sahanlik3", "konum": Vector3(-7.0, 6.4, -29.0), "olcu": Vector3(6.5, 0.8, 6.5),
			"renk": Color(0.48, 0.44, 0.39)},
		# 3) Düşman terası — bölüm 5'in dili, ama düşülecek yer var.
		{"ad": "Arena", "konum": Vector3(0, 7.2, -38.0), "olcu": Vector3(13, 0.8, 9),
			"renk": Color(0.5, 0.46, 0.38)},
		{"ad": "ArenaKaya", "konum": Vector3(4.5, 8.3, -39.5), "olcu": Vector3(3, 1.4, 3),
			"renk": Color(0.45, 0.43, 0.42)},
		# 4) Son tırmanış — bölüm 2'nin dili, sarmal basamaklar.
		{"ad": "Sarmal1", "konum": Vector3(-4.0, 8.4, -45.0), "olcu": Vector3(3, 0.5, 3),
			"renk": Color(0.54, 0.47, 0.36)},
		{"ad": "Sarmal2", "konum": Vector3(0.5, 9.6, -48.0), "olcu": Vector3(3, 0.5, 3),
			"renk": Color(0.54, 0.47, 0.36)},
		{"ad": "Sarmal3", "konum": Vector3(5.0, 10.8, -45.5), "olcu": Vector3(3, 0.5, 3),
			"renk": Color(0.54, 0.47, 0.36)},
		{"ad": "Sarmal4", "konum": Vector3(4.0, 12.0, -40.5), "olcu": Vector3(3.6, 0.5, 3.6),
			"renk": Color(0.54, 0.47, 0.36)},
		{"ad": "Zirve", "konum": Vector3(0, 13.0, -37.0), "olcu": Vector3(7, 0.8, 7),
			"renk": Color(0.45, 0.52, 0.42)},
	],

	"hareketliler": [
		{"ad": "Mekik1", "konum": Vector3(0, 2.8, -13.0), "uc": Vector3(0, 0, -5.0),
			"sure": 5.5},
		{"ad": "Asansor1", "konum": Vector3(-4.5, 4.0, -25.0), "uc": Vector3(-1.0, 2.2, 0),
			"sure": 5.0, "faz": 0.2},
		{"ad": "Mekik2", "konum": Vector3(-4.0, 6.8, -33.5), "uc": Vector3(3.0, 0, -3.0),
			"sure": 4.5, "faz": 0.6},
	],

	# On iki çiçek: bölümün uzunluğuyla orantılı. Dördü düşman menzilinde.
	"cicekler": [
		Vector3(0, 2.4, 6.5),
		Vector3(-2.6, 2.8, 2.5),
		Vector3(0.6, 3.2, -1.5),
		Vector3(0, 3.6, -7.5),
		Vector3(0, 4.0, -13.0),
		Vector3(0, 4.8, -21.0),
		Vector3(-4.5, 5.6, -25.0),
		Vector3(-7.0, 7.6, -29.0),
		Vector3(-4.0, 8.4, -38.0),
		Vector3(4.5, 10.0, -39.5),
		Vector3(0.5, 10.8, -48.0),
		Vector3(0, 14.2, -37.0),
	],

	"kontrol_noktalari": [
		Vector3(0, 2.9, -7.5),
		Vector3(0, 4.1, -21.0),
		Vector3(-5.0, 7.7, -38.0),
	],

	"bitis": Vector3(0, 14.6, -37.0),

	"dusmanlar": [
		{"konum": Vector3(0, 2.9, -7.5), "aci": 90.0, "devriye_ucu": Vector3(2.0, 0, 0)},
		{"konum": Vector3(-7.0, 6.9, -29.0), "aci": 0.0, "devriye_ucu": Vector3(0, 0, 2.5)},
		{"konum": Vector3(2.0, 7.7, -38.0), "aci": 90.0, "devriye_ucu": Vector3(-5.0, 0, 0)},
		{"konum": Vector3(-3.0, 7.7, -40.0), "aci": 0.0, "devriye_ucu": Vector3(0, 0, 3.0)},
		{"konum": Vector3(0, 13.5, -37.0), "aci": 180.0, "devriye_ucu": Vector3(0, 0, 2.5)},
		# Final: öğrenilen üç tehdit bir arada. Atıcı arenayı tarıyor,
		# hoplayan zirve yolunu kesiyor.
		{"tur": "atici", "konum": Vector3(4.5, 9.2, -39.5), "aci": 180.0},
		{"tur": "hoplayan", "konum": Vector3(0.5, 10.1, -48.0), "aci": 0.0},
	],

	"susleme": [
		{"tur": "tabela", "konum": Vector3(2.4, 1.6, 15.0), "aci": -25.0},
		{"tur": "kaktus", "konum": Vector3(-2.6, 1.6, 14.8), "aci": 55.0, "olcek": 1.0},
		{"tur": "kaya", "konum": Vector3(2.2, 2.8, -9.2), "aci": 15.0, "olcek": 0.7},
		{"tur": "sandik", "konum": Vector3(-2.0, 4.0, -22.6), "aci": -35.0},
		{"tur": "kaya", "konum": Vector3(-8.8, 6.8, -30.8), "aci": 80.0, "olcek": 0.85},
		{"tur": "kaktus", "konum": Vector3(-5.4, 7.6, -35.6), "aci": -20.0, "olcek": 0.9},
		{"tur": "kaya", "konum": Vector3(5.2, 7.6, -35.0), "aci": 140.0, "olcek": 0.75},
		{"tur": "kaktus", "konum": Vector3(2.6, 13.4, -39.2), "aci": 30.0, "olcek": 1.15},
	],
}
