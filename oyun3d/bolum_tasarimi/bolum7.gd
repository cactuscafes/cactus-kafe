extends RefCounted
## Bölüm 7 — "Kum Kanyonu"
##
## FİKİR: oyunun İDDİA ettiği ama hiçbir bölümün ÖĞRETMEDİĞİ şey: siper.
## Mağaza metni "siper gerçekten siperdir: diken duvardan geçmez" diyor;
## atıcı (Faz 14) bölüm 5'te açık bir bahçede duruyor ve orada siper almak
## bir seçenek, gereklilik değil. Burada gereklilik.
##
## İKİ ATICI, ÇAPRAZ ATEŞ HATTI: biri soldaki çıkıntıda, biri sağdaki. İkisi
## de yerinden kıpırdamıyor (Faz 14'ün adalet kuralı), yani hatları SABİT ve
## öğrenilebilir. Platoların üstündeki sütunlar o hatları kesiyor: ilerlemek
## "sütundan sütuna, atış arasında" demek.
##
## FAZ 14'ÜN DERSİNE UYULUYOR: menzilli düşman + ölümcül zemin bölüm 3'te
## denenmiş ve ölüm makinesi olmuştu (süre 45 → 105 sn, ölüm 7 → 15). Sebep
## menzil değil, İKİ BASKININ ÜST ÜSTE BİNMESİ: geri tepme + dar köprü =
## düşme. Burada zemin yine ölümcül ama platolar GENİŞ ve boşluklar kısa
## (en fazla 2,5 m); zıplama baskısı bilerek sıfıra yakın. Yeni eksen bir
## tane: nerede durduğun.
##
## ÖLÇÜ KURALLARI (bolum3.gd ile aynı): boşluk ≤ 4,5 m, basamak ≤ 1,2 m.
## Sütunların tepesine çıkılamıyor (3+ m) — onlar durak değil, duvar.

const VERI := {
	"kimlik": "bolum7",
	"ad": "BOLUM7_AD",

	# Kanyon: bölüm 3'ün dilini kullanıyor (zeminin tamamı dikenli) ama
	# rengi kızıl. Aynı kural, başka yer.
	"zemin_olcu": 130.0,
	"zemin_tuzakli": true,
	"zemin_renk": Color(0.58, 0.34, 0.26),
	"gok_ufuk": Color(0.86, 0.66, 0.50),
	"gok_yer": Color(0.34, 0.24, 0.22),
	"sis_renk": Color(0.82, 0.62, 0.50),
	"sis": 0.0040,
	"gunes_aci": Vector3(-38, -20, 0),
	"gunes_gucu": 1.0,

	"oyuncu": Vector3(0, 2.4, 13.0),

	"tuzaklar": [
		{"konum": Vector3(0, 0.6, 0), "olcu": Vector3(130, 1.2, 130), "gorsel": false},
	],

	"platformlar": [
		{"ad": "Baslangic", "konum": Vector3(0, 1.0, 13.0), "olcu": Vector3(9, 1.2, 8),
			"renk": Color(0.60, 0.44, 0.32)},

		# --- Birinci plato: tek atıcı, iki sütun. Ders burada VERİLİYOR.
		{"ad": "Plato1", "konum": Vector3(0, 1.0, 2.5), "olcu": Vector3(12, 1.2, 8),
			"renk": Color(0.56, 0.41, 0.30)},
		# Sütun tepesi 4,6 m: çıkılamaz. İşi durak olmak değil, hattı kesmek.
		{"ad": "Sutun1", "konum": Vector3(-3.2, 2.6, 3.6), "olcu": Vector3(1.6, 4.0, 1.6),
			"renk": Color(0.45, 0.33, 0.27)},
		{"ad": "Sutun2", "konum": Vector3(2.6, 2.6, 0.4), "olcu": Vector3(1.6, 4.0, 1.6),
			"renk": Color(0.45, 0.33, 0.27)},
		# Atıcının çıkıntısı platoya BİTİŞİK: "yanına varmak her zaman işe
		# yarar" kuralı (Faz 14) ulaşılamayan bir atıcıyla bozulurdu.
		{"ad": "Cikinti1", "konum": Vector3(-8.8, 1.2, 1.0), "olcu": Vector3(4, 1.2, 4.5),
			"renk": Color(0.50, 0.37, 0.29)},

		# --- Köprü: iki taş, atış hattı burada AÇIK. Boşluklar 2,5 m —
		# yürüyerek bile geçilir; zorluk zıplamada değil, zamanlamada.
		{"ad": "Kopru1", "konum": Vector3(-2.0, 1.2, -5.8), "olcu": Vector3(3.2, 0.8, 3.2),
			"renk": Color(0.62, 0.46, 0.33)},
		{"ad": "Kopru2", "konum": Vector3(2.0, 1.4, -11.5), "olcu": Vector3(3.2, 0.8, 3.2),
			"renk": Color(0.62, 0.46, 0.33)},

		# --- İkinci plato: iki atıcı birden, çapraz hat. Sınav burada.
		{"ad": "Plato2", "konum": Vector3(0, 1.6, -20.0), "olcu": Vector3(12, 1.2, 9),
			"renk": Color(0.56, 0.41, 0.30)},
		{"ad": "Sutun3", "konum": Vector3(-2.8, 3.4, -17.8), "olcu": Vector3(1.6, 4.0, 1.6),
			"renk": Color(0.45, 0.33, 0.27)},
		{"ad": "Sutun4", "konum": Vector3(3.0, 3.4, -22.2), "olcu": Vector3(1.6, 4.0, 1.6),
			"renk": Color(0.45, 0.33, 0.27)},
		{"ad": "Cikinti2", "konum": Vector3(9.2, 1.8, -20.5), "olcu": Vector3(4, 1.2, 4.5),
			"renk": Color(0.50, 0.37, 0.29)},

		# --- Çıkış: iki taş + üç kademeli kule. Burada atıcı YOK; son
		# tırmanışta iki baskıyı üst üste bindirmek Faz 14'ün hatası olurdu.
		{"ad": "Kopru3", "konum": Vector3(-1.6, 1.8, -28.5), "olcu": Vector3(3.2, 0.8, 3.2),
			"renk": Color(0.62, 0.46, 0.33)},
		{"ad": "Kopru4", "konum": Vector3(2.2, 2.0, -33.4), "olcu": Vector3(3.2, 0.8, 3.2),
			"renk": Color(0.62, 0.46, 0.33)},
		{"ad": "Plato3", "konum": Vector3(0, 2.2, -41.0), "olcu": Vector3(11, 1.2, 8),
			"renk": Color(0.56, 0.41, 0.30)},
		{"ad": "Kule1", "konum": Vector3(0, 3.0, -47.5), "olcu": Vector3(7, 1.4, 6),
			"renk": Color(0.52, 0.40, 0.31)},
		{"ad": "Kule2", "konum": Vector3(2.8, 3.9, -50.5), "olcu": Vector3(5, 1.4, 5),
			"renk": Color(0.52, 0.40, 0.31)},
		{"ad": "Zirve", "konum": Vector3(-1.0, 4.8, -53.5), "olcu": Vector3(7, 1.6, 6),
			"renk": Color(0.46, 0.48, 0.36)},
	],

	# HAREKETLİ PLATFORM YOK — ve bu bir ihmal değil, karar.
	# Önce bir salıncak vardı: ölümcül zeminin üstünde, iki atıcının
	# hattında, üstelik yalnızca kestirme olarak. Bot ölçtü: rotasını oraya
	# çeviriyor ve arka arkaya düşüyordu. Sebep salıncağın kendisi değil,
	# bu bölümün KURALI: baskı tek eksende (nerede durduğun). Bekleme
	# baskısını da eklemek, Faz 14'ün bölüm 3'te öğrendiği hatanın aynısı.
	# Aynısı bölüm 8'de de ölçüldü ve oradan da kaldırıldı: iki yeni
	# bölümde de salıncak, botun rotasını kendine çekip onu düşürdü.
	# Hareketli platform bölüm 3 ve 4'ün dersi; burada yeri yok.


	"cicekler": [
		Vector3(0, 2.6, 13.0),
		Vector3(-5.5, 2.6, 0.5),
		Vector3(-8.8, 2.8, 1.0),
		Vector3(-2.0, 2.8, -5.8),
		Vector3(4.5, 3.2, -20.0),
		Vector3(9.2, 3.4, -20.5),
		Vector3(-1.6, 3.4, -28.5),
		Vector3(0, 3.8, -41.0),
		Vector3(0, 4.7, -47.5),
		Vector3(-1.0, 6.6, -53.5),
	],

	"kontrol_noktalari": [
		Vector3(0, 2.2, 2.5),
		Vector3(0, 2.8, -20.0),
		Vector3(0, 3.4, -41.0),
	],

	"bitis": Vector3(-1.0, 6.4, -53.5),

	"dusmanlar": [
		# Isınma: tanıdık temel düşman, geniş platoda.
		{"konum": Vector3(3.5, 1.9, 3.5), "aci": 180.0, "devriye_ucu": Vector3(-5.0, 0, 0)},
		# Birinci atıcı: menzili kısaltıldı (bölüm 5'te 16 m). Amaç öldürmek
		# değil, oyuncuyu sütunun arkasına ÖĞRETMEK.
		{"tur": "atici", "konum": Vector3(-8.8, 2.0, 1.0), "aci": 90.0,
			"ayarlar": {"atis_menzili": 13.0}},
		# İkinci atıcı karşı taraftan: iki hat birden, aralarında sütunlar.
		{"tur": "atici", "konum": Vector3(9.2, 2.6, -20.5), "aci": -90.0,
			"ayarlar": {"atis_menzili": 13.0}},
		# Hoplayan platoyu kapatıyor: sütunun arkasında SÜREKLİ durulamasın.
		{"tur": "hoplayan", "konum": Vector3(-4.0, 2.5, -21.5), "aci": 0.0},
		{"konum": Vector3(3.5, 3.1, -38.5), "aci": 90.0, "devriye_ucu": Vector3(-5.0, 0, 0)},
	],

	"susleme": [
		{"tur": "tabela", "konum": Vector3(2.6, 1.6, 15.4), "aci": -14.0},
		{"tur": "kaktus", "konum": Vector3(-3.4, 1.6, 15.0), "aci": 35.0, "olcek": 1.0},
		{"tur": "kaya", "konum": Vector3(4.8, 1.6, 0.0), "aci": 120.0, "olcek": 0.9},
		{"tur": "sandik", "konum": Vector3(-5.2, 2.2, -18.5), "aci": 22.0},
		{"tur": "kaya", "konum": Vector3(4.6, 2.2, -23.0), "aci": 60.0, "olcek": 0.8},
		{"tur": "kaktus", "konum": Vector3(-4.6, 2.8, -43.0), "aci": -40.0, "olcek": 1.1},
		{"tur": "kaya", "konum": Vector3(1.4, 5.6, -53.0), "aci": 15.0, "olcek": 0.7},
	],
}
