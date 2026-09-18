extends Node
## Bölüm kütüğü (autoload: Bolumler).
##
## Bölümleri tek bir listede tutmak, "sonraki bölüm" düğmesinden ana menüdeki
## rekor listesine kadar her yerin aynı kaynaktan okumasını sağlıyor. Yeni
## bölüm eklemek = buraya bir satır eklemek.

const LISTE: Array[Dictionary] = [
	{"kimlik": "bolum1", "ad": "BOLUM1_AD", "sahne": "res://sahneler/bolum1.tscn"},
	{"kimlik": "bolum2", "ad": "BOLUM2_AD", "sahne": "res://sahneler/bolum2.tscn"},
	{"kimlik": "bolum3", "ad": "BOLUM3_AD", "sahne": "res://sahneler/bolum3.tscn"},
	{"kimlik": "bolum4", "ad": "BOLUM4_AD", "sahne": "res://sahneler/bolum4.tscn"},
	{"kimlik": "bolum5", "ad": "BOLUM5_AD", "sahne": "res://sahneler/bolum5.tscn"},
	{"kimlik": "bolum6", "ad": "BOLUM6_AD", "sahne": "res://sahneler/bolum6.tscn"},
]

## Demoda yalnızca ilk bölüm açık. Bölüm listesini süzmek, menüden bitiş
## ekranına kadar her yeri kendiliğinden doğru yapıyor — "demoda bu düğmeyi
## gizle" diye yer yer kontrol eklemek yerine.
func liste() -> Array[Dictionary]:
	if Urun.demo:
		return [LISTE[0]] as Array[Dictionary]
	return LISTE

func sayi() -> int:
	return liste().size()

func bilgi(kimlik: String) -> Dictionary:
	for b in LISTE:
		if b["kimlik"] == kimlik:
			return b
	return {}

func sahne(kimlik: String) -> String:
	var b := bilgi(kimlik)
	return b.get("sahne", "")

## Bölüm adı çeviri anahtarı olarak tutuluyor; burada çevrilmiş hâli döner.
func ad(kimlik: String) -> String:
	var b := bilgi(kimlik)
	return tr(b.get("ad", kimlik))

## Sıradaki bölümün kimliği; sonuncudaysa boş metin.
func sonraki(kimlik: String) -> String:
	var l := liste()
	for i in l.size():
		if l[i]["kimlik"] == kimlik:
			return l[i + 1]["kimlik"] if i + 1 < l.size() else ""
	return ""
