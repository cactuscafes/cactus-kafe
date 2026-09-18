extends RefCounted
## Bölüm 3 — "Diken Köprüsü"
##
## FİKİR: bölüm 1 geniş ve affedici, bölüm 2 dikey. Bu bölüm DAR: zeminin
## tamamı dikenli, ilerlemenin tek yolu taştan taşa geçmek. Yeni beceri değil,
## aynı becerinin daha az hata payıyla kullanılması isteniyor.
##
## ÖLÇÜ KURALLARI (oyuncu.gd'den): zıplama yüksekliği 1,65 m; koşu hızı
## 7,4 m/sn; yürüme 4,2 m/sn. Havada ivme sınırlı olduğu için teorik menzil
## (~8 m) gerçekte yakalanmıyor — bu yüzden boşluklar 4,5 m'yi aşmıyor,
## basamak yükselmesi 1,2 m'yi geçmiyor. `bolum_hatti_testi` bunu ölçüyor.
##
## RİTİM: üç kısa atlayış (ısınma) → geniş alan + düşman (nefes) → asansör
## (bekleme) → yükselen basamaklar (baskı) → yanal asansör (son sınav) → bitiş.
## Her zor bölümden önce bir kontrol noktası var: ölüm cezası 15 saniye,
## 90 saniye değil.

const VERI := {
	"kimlik": "bolum3",
	"ad": "BOLUM3_AD",

	# Zemin görünüyor ama üstünde durulmuyor: tamamı dikenli. Çizgili
	# gölgelendirici bunu söylüyor — bölüm 2'deki ile aynı dil.
	"zemin_olcu": 130.0,
	"zemin_tuzakli": true,
	"gok_ufuk": Color(0.78, 0.72, 0.62),
	"gok_yer": Color(0.30, 0.28, 0.26),
	"sis_renk": Color(0.76, 0.71, 0.63),
	"sis": 0.0042,
	"gunes_aci": Vector3(-46, 24, 0),

	"oyuncu": Vector3(0, 2.4, 10.5),

	# Tek büyük tuzak: düşmek = ölmek.
	"tuzaklar": [
		{"konum": Vector3(0, 0.6, 0), "olcu": Vector3(130, 1.2, 130), "gorsel": false},
	],   # görseli yok, çünkü zeminin kendisi dikenli çiziliyor

	"platformlar": [
		{"ad": "Baslangic", "konum": Vector3(0, 1.0, 10.0), "olcu": Vector3(8, 1.2, 8),
			"renk": Color(0.53, 0.46, 0.34)},
		# Isınma: üç kısa atlayış, hepsi yürüyerek geçilir.
		{"ad": "Kopru1", "konum": Vector3(0, 1.0, 3.6), "olcu": Vector3(2.4, 0.8, 3.0),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Kopru2", "konum": Vector3(0, 1.0, -0.9), "olcu": Vector3(2.4, 0.8, 3.0),
			"renk": Color(0.58, 0.5, 0.36)},
		# Köşegen: düz çizgide koşan oyuncu buradan düşer, yön değiştirmesi gerek.
		{"ad": "Kopru3", "konum": Vector3(2.0, 1.2, -5.4), "olcu": Vector3(2.4, 0.8, 2.4),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Genis1", "konum": Vector3(0, 1.4, -11.5), "olcu": Vector3(9, 0.8, 7),
			"renk": Color(0.53, 0.46, 0.34)},
		{"ad": "Genis2", "konum": Vector3(0, 1.8, -26.5), "olcu": Vector3(8, 0.8, 7),
			"renk": Color(0.53, 0.46, 0.34)},
		# Yükselen basamaklar: her biri 1,0 m yukarıda, 3,3 m ileride.
		{"ad": "Basamak1", "konum": Vector3(3.2, 2.7, -31.0), "olcu": Vector3(3, 0.6, 3),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Basamak2", "konum": Vector3(3.2, 3.6, -34.3), "olcu": Vector3(3, 0.6, 3),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Basamak3", "konum": Vector3(0.4, 4.5, -37.2), "olcu": Vector3(3.4, 0.6, 3.4),
			"renk": Color(0.58, 0.5, 0.36)},
		{"ad": "Son", "konum": Vector3(6.0, 5.2, -44.5), "olcu": Vector3(7, 0.8, 7),
			"renk": Color(0.45, 0.52, 0.42)},
	],

	# Asansör1 boşluğu kendisi kapatıyor: oyuncu bekleyip binmek zorunda.
	# Bekleme, hızlı koşanı yavaşlatan tek dürüst araç — duvar koymadan.
	"hareketliler": [
		{"ad": "Asansor1", "konum": Vector3(0, 1.8, -17.0), "uc": Vector3(0, 0, -6.0),
			"sure": 6.0},
		{"ad": "Asansor2", "konum": Vector3(0.4, 5.0, -40.6), "uc": Vector3(5.6, 0, -3.4),
			"sure": 5.0, "faz": 0.25},
	],

	# Sekiz çiçek: dördü yolun üstünde, dördü sapmayı gerektiriyor.
	"cicekler": [
		Vector3(0, 2.6, 3.6),
		Vector3(0, 2.6, -0.9),
		Vector3(2.0, 2.8, -5.4),
		Vector3(-3.2, 3.0, -11.5),
		Vector3(3.2, 3.0, -13.5),
		Vector3(-2.8, 3.4, -26.5),
		Vector3(3.2, 4.3, -31.0),
		Vector3(0.4, 6.1, -37.2),
	],

	"kontrol_noktalari": [
		Vector3(0, 1.9, -11.5),
		Vector3(0, 2.3, -26.5),
	],

	"bitis": Vector3(6.0, 7.0, -44.5),

	"dusmanlar": [
		{"konum": Vector3(-2.5, 1.9, -11.5), "aci": 90.0, "devriye_ucu": Vector3(5.0, 0, 0)},
		{"konum": Vector3(2.5, 2.3, -26.5), "aci": 180.0, "devriye_ucu": Vector3(-4.5, 0, 0)},
		{"konum": Vector3(-2.5, 2.3, -24.5), "aci": 0.0, "devriye_ucu": Vector3(0, 0, -3.0)},
	],

	# Süsleme yalnızca geniş platformlarda: dar köprülerde göz karıştırıyor
	# ve çarpışması olmadığı için oyuncu "üstüne basarım" sanıp düşüyor.
	"susleme": [
		{"tur": "tabela", "konum": Vector3(2.6, 1.6, 12.0), "aci": -18.0},
		{"tur": "kaktus", "konum": Vector3(-2.8, 1.6, 12.4), "aci": 35.0, "olcek": 0.9},
		{"tur": "kaya", "konum": Vector3(3.0, 1.6, 8.6), "aci": 120.0, "olcek": 0.8},
		{"tur": "kaya", "konum": Vector3(3.6, 1.8, -9.6), "aci": 40.0, "olcek": 0.7},
		{"tur": "sandik", "konum": Vector3(-3.4, 2.2, -28.6), "aci": -25.0},
		{"tur": "kaktus", "konum": Vector3(2.4, 5.6, -46.6), "aci": 15.0, "olcek": 1.05},
	],
}
