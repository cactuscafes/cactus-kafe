extends RefCounted
## Bölüm 8 — "Diken Ana'nın İni"
##
## FİKİR: bölüm 6'da canavarla ZİRVEDE karşılaşıldı ve oyuncu kazandı. Burası
## onun ini — ve bu sefer ev sahibi o. Rövanş, oyunun son sorusu.
##
## CANAVAR TEK SATIR KOD OLMADAN ZORLAŞIYOR: Faz 16'nın boss'u baştan veriden
## ayarlanabilir yazılmıştı (`bolum_uret.gd` → `_boss_ekle` → "ayarlar"). Bu
## bölüm o iddianın SINAVI: dört can, daha kısa nefes, üç yerine beş diken,
## dört saldırılık kalıp — hepsi aşağıdaki sözlükte. Yeni bir boss betiği
## yazmak zorunda kalsaydık Faz 16 "yeniden kullanılabilir içerik" değil,
## tek seferlik bir sahne yapmış olurdu.
##
## ZEMİN GÜVENLİ, tıpkı bölüm 5 ve 6 gibi: dövüşün üstüne düşme baskısı
## bindirmek Faz 14'ün bölüm 3'te öğrendiği hata. Dikenli şeritler yalnızca
## YAKLAŞMAYI daraltıyor, arenanın içinde hiç yok — telgrafı okuyup yana
## kaçmanın karşılığı ölüm olmamalı.
##
## RİTİM: üç düşman türü sırayla (hatırlatma) → dar geçit (nefes) → kontrol
## noktası → arena (doruk). Kontrol noktası arenanın AĞZINDA: rövanşı
## kaybetmenin bedeli dövüşü tekrarlamak, bölümü tekrarlamak değil.

const VERI := {
	"kimlik": "bolum8",
	"ad": "BOLUM8_AD",

	# Alacakaranlık: oyunun ilk yedi bölümü gündüz. Son bölümün kendi saati
	# olması, "buraya kadar geldim" hissini renkten de veriyor.
	"zemin_olcu": 140.0,
	"zemin_renk": Color(0.34, 0.28, 0.33),
	"tepe_renk": Color(0.22, 0.18, 0.24),
	"gok_ufuk": Color(0.78, 0.44, 0.34),
	"gok_yer": Color(0.20, 0.15, 0.22),
	"sis_renk": Color(0.62, 0.40, 0.40),
	"sis": 0.0052,
	"gunes_aci": Vector3(-14, 8, 0),
	"gunes_gucu": 0.75,
	"gunes_renk": Color(1.0, 0.74, 0.55),
	"bulut": 0.6,

	"oyuncu": Vector3(0, 1.5, 16.0),

	# Şeritler yalnızca YAKLAŞMADA: arena temiz. Hiçbiri bir platformun
	# kenarına yapışmıyor — dikenin dibinden zıplamak gerekirse kalkış
	# noktası dikenin içinde kalıyor ve o geçiş hesapta "yok" sayılıyor
	# (bkz. bolum_grafi.kalkis_noktasi). İlk yerleşimde tam bu oldu.
	"tuzaklar": [
		{"konum": Vector3(0, 0.3, 8.0), "olcu": Vector3(24, 0.6, 3.0)},
		{"konum": Vector3(-7, 0.3, -5.0), "olcu": Vector3(22, 0.6, 3.0)},
		{"konum": Vector3(8, 0.3, -20.0), "olcu": Vector3(20, 0.6, 3.0)},
	],

	"platformlar": [
		# Şeridin üstünden geçiren taşlar — bölüm 5'in dili, tanıdık olsun.
		{"ad": "Gecit1", "konum": Vector3(-5.0, 0.9, 8.0), "olcu": Vector3(3.4, 0.6, 5),
			"renk": Color(0.44, 0.36, 0.38)},
		{"ad": "Gecit2", "konum": Vector3(6.0, 0.9, 8.0), "olcu": Vector3(3.4, 0.6, 5),
			"renk": Color(0.44, 0.36, 0.38)},
		{"ad": "Kaya1", "konum": Vector3(-6.0, 1.0, 1.0), "olcu": Vector3(3.5, 1.2, 3.5),
			"renk": Color(0.38, 0.32, 0.36)},
		{"ad": "Kaya2", "konum": Vector3(5.5, 1.0, -1.5), "olcu": Vector3(3.5, 1.2, 3.5),
			"renk": Color(0.38, 0.32, 0.36)},
		# İkinci şeridin açık koridoru sağda (x > 4); taş orada.
		{"ad": "Gecit3", "konum": Vector3(6.0, 0.9, -5.0), "olcu": Vector3(4, 0.6, 5),
			"renk": Color(0.44, 0.36, 0.38)},
		{"ad": "Sahanlik", "konum": Vector3(0, 0.8, -12.5), "olcu": Vector3(13, 0.7, 8),
			"renk": Color(0.40, 0.34, 0.38)},
		# Sahanlık'ın ÜSTÜNDE değil YANINDA: üst üste binen iki durak
		# arasında yatay yer değişimi olmuyor ve bot "aşağı in" hamlesini
		# yerinde zıplayarak deniyor (bölüm 5'te Kaya1 aynı sebeple onun
		# da başını yiyor). Kaya zemine indi, aradaki adım gerçek oldu.
		{"ad": "Kaya3", "konum": Vector3(-8.5, 0.65, -13.0), "olcu": Vector3(3.5, 1.3, 3.5),
			"renk": Color(0.38, 0.32, 0.36)},
		# Üçüncü şeridin açık koridoru solda (x < -2); taş orada.
		{"ad": "Gecit4", "konum": Vector3(-5.0, 0.9, -20.0), "olcu": Vector3(4, 0.6, 5),
			"renk": Color(0.44, 0.36, 0.38)},

		# İnin ağzı: arenaya tek giriş. Kontrol noktası burada.
		{"ad": "Agiz", "konum": Vector3(0, 0.8, -25.0), "olcu": Vector3(8, 1.0, 6),
			"renk": Color(0.42, 0.34, 0.36)},

		# ARENA: bölüm 6'nın zirvesinden (15x13) geniş. Çarpma menzili 4,6 m;
		# yana kaçacak en az bir menzil boşluk gerekiyor.
		{"ad": "Arena", "konum": Vector3(0, 0.9, -34.0), "olcu": Vector3(18, 1.2, 15),
			"renk": Color(0.36, 0.34, 0.30)},

		# Çıkış canavarın ARKASINDA: kaçarak bitirmek diye bir şey yok,
		# üstelik bitiş zaten canavar yenilene kadar kilitli.
		{"ad": "Kule", "konum": Vector3(0, 1.9, -44.0), "olcu": Vector3(6, 1.6, 6),
			"renk": Color(0.40, 0.44, 0.34)},
	],

	"cicekler": [
		Vector3(-5.0, 2.1, 8.0),
		Vector3(6.0, 2.1, 8.0),
		Vector3(-6.0, 2.6, 1.0),
		Vector3(5.5, 2.6, -1.5),
		Vector3(0, 2.1, -12.5),
		Vector3(-8.5, 2.4, -13.0),
		Vector3(-5.0, 2.1, -20.0),
		Vector3(0, 2.2, -25.0),
		Vector3(-6.5, 2.4, -34.0),
		Vector3(6.5, 2.4, -34.0),
		Vector3(0, 2.4, -29.5),
		Vector3(0, 4.6, -44.0),
	],

	"kontrol_noktalari": [
		Vector3(0, 1.4, -12.5),
		Vector3(0, 1.6, -25.0),
	],

	"bitis": Vector3(0, 4.4, -44.0),

	# Üç tür sırayla: hatırlatma turu. Arenada düşman YOK — dövüşün içine
	# üçüncü bir şey karıştırmak, kalıbı okunamaz yapardı.
	"dusmanlar": [
		{"konum": Vector3(-3.0, 0.2, 3.0), "aci": 90.0, "devriye_ucu": Vector3(6.0, 0, 0)},
		{"tur": "hoplayan", "konum": Vector3(4.0, 0.2, -9.0), "aci": 180.0},
		{"tur": "atici", "konum": Vector3(-7.5, 0.2, -16.0), "aci": 90.0,
			"ayarlar": {"atis_menzili": 14.0}},
		{"konum": Vector3(3.0, 1.3, -12.5), "aci": 180.0, "devriye_ucu": Vector3(-5.0, 0, 0)},
	],

	# RÖVANŞ — hepsi veri. Bölüm 6: 3 can, 1,1 sn nefes, 2'lik kalıp, 3 diken.
	"boss": {
		"konum": Vector3(0, 1.6, -39.0), "aci": 180.0,
		"ayarlar": {
			"can_max": 4,
			"bekleme": 0.9,
			"carpma_telgrafi": 0.40,
			"atis_telgrafi": 0.34,
			"sersem_suresi": 2.0,
			"kalip_uzunlugu": 3,
			"yagmur_adedi": 5,
			"yagmur_acisi": 17.0,
			"yurume_hizi": 3.0,
		},
	},

	"susleme": [
		{"tur": "tabela", "konum": Vector3(2.6, 0.0, 17.6), "aci": -16.0},
		{"tur": "kaktus", "konum": Vector3(-3.8, 0.0, 17.0), "aci": 40.0, "olcek": 1.0},
		{"tur": "kaya", "konum": Vector3(7.4, 0.0, 12.0), "aci": 110.0, "olcek": 1.0},
		{"tur": "kaya", "konum": Vector3(-8.2, 0.0, -1.0), "aci": 40.0, "olcek": 0.85},
		{"tur": "sandik", "konum": Vector3(5.2, 1.15, -14.4), "aci": 18.0},
		{"tur": "kaktus", "konum": Vector3(-7.4, 0.0, -24.0), "aci": -30.0, "olcek": 0.9},
		{"tur": "kaya", "konum": Vector3(-9.8, 1.5, -34.0), "aci": 70.0, "olcek": 1.2},
		{"tur": "kaya", "konum": Vector3(9.8, 1.5, -34.0), "aci": -70.0, "olcek": 1.2},
		{"tur": "kaktus", "konum": Vector3(-3.6, 0.0, -47.0), "aci": 25.0, "olcek": 1.1},
	],
}
