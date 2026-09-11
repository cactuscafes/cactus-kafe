extends Node
## Bölüm kütüğü (autoload: Bolumler).
##
## Bölümleri tek bir listede tutmak, "sonraki bölüm" düğmesinden ana menüdeki
## rekor listesine kadar her yerin aynı kaynaktan okumasını sağlıyor. Yeni
## bölüm eklemek = buraya bir satır eklemek.

const LISTE: Array[Dictionary] = [
	{"kimlik": "bolum1", "ad": "BOLUM1_AD", "sahne": "res://sahneler/bolum1.tscn"},
	{"kimlik": "bolum2", "ad": "BOLUM2_AD", "sahne": "res://sahneler/bolum2.tscn"},
]

func sayi() -> int:
	return LISTE.size()

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
	for i in LISTE.size():
		if LISTE[i]["kimlik"] == kimlik:
			return LISTE[i + 1]["kimlik"] if i + 1 < LISTE.size() else ""
	return ""
