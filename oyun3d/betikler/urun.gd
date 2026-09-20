extends Node
## Ürün bilgisi (autoload: Urun) — adı, sürümü, bağlantıları.
##
## Tek kaynak: krediler ekranı, demo çağrısı, basın kiti ve mağaza metni hep
## buradan okuyor. Sürüm numarasını üç yerde güncellemeyi unutmanın bedeli,
## yanlış sürümü yayınlamaktır.

const AD := "Cactus 3B"
## Anlamlı sürümleme: BÜYÜK.KÜÇÜK.YAMA. Çıkışa kadar 0.x, çıkışta 1.0.
const SURUM := "0.13.0"
const GELISTIRICI := "Cactus Cafe"

## Steam sayfası açılınca burayı doldur; demo içindeki "dilek listesine ekle"
## düğmesi ve basın kiti bu adresi kullanıyor. Boşken düğme gizleniyor —
## çalışmayan düğme, olmayan düğmeden kötüdür.
const MAGAZA_URL := ""
const SITE_URL := "https://cactuscafes.com"
const ILETISIM := "batuhanbulut@cactuscafes.com"

## Anonim oynanış verisinin gideceği adres. DEPODA BİLEREK BOŞ: adres boşken
## telemetri hiç çalışmıyor. `sunucu/` altındaki Worker'ı yayınlayınca buraya
## yazılacak (ör. "https://cactus-3b-telemetri.<hesap>.workers.dev/olay").
## `demo` gibi bu da sabit değil değişken: telemetri testi, adresi geçici
## doldurup gövdenin sunucunun beklediği biçimde olduğunu doğruluyor.
var TELEMETRI_URL := ""

## Demo sürümü mü? Dışa aktarım ön ayarında `demo` özellik etiketi ile
## açılıyor. Değişken olması test içindir: `OS.has_feature` çalışma anında
## taklit edilemiyor, ama demo davranışını test etmek gerekiyor.
var demo := OS.has_feature("demo")

func surum_metni() -> String:
	return "%s %s%s" % [AD, SURUM, "  (demo)" if demo else ""]
