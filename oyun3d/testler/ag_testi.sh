#!/usr/bin/env bash
# İki süreçli ağ testi: bir Godot sunucu, bir Godot istemci, 127.0.0.1.
#
#   testler/ag_testi.sh [godot yolu]
#
# Ağ kodunu tek süreçte test etmek mümkün değil: asıl sorular (paket geç
# gelirse, kaybolursa, sahte gelirse ne olur) ancak iki ayrı süreç arasında
# sorulabiliyor. Bu yüzden diğer testler gibi tek sahne değil, kabuk betiği.
set -uo pipefail

GODOT="${1:-godot}"
PROJE="$(cd "$(dirname "$0")/.." && pwd)"
SUNUCU_LOG=$(mktemp)
ISTEMCI_LOG=$(mktemp)

"$GODOT" --headless --path "$PROJE" res://testler/ag_sunucu.tscn > "$SUNUCU_LOG" 2>&1 &
SUNUCU_PID=$!
sleep 2
"$GODOT" --headless --path "$PROJE" res://testler/ag_istemci.tscn > "$ISTEMCI_LOG" 2>&1
wait $SUNUCU_PID

sunucu_json=$(grep -o 'SONUC .*' "$SUNUCU_LOG" | head -1 | cut -d' ' -f2-)
istemci_json=$(grep -o 'SONUC .*' "$ISTEMCI_LOG" | head -1 | cut -d' ' -f2-)

python3 - "$sunucu_json" "$istemci_json" <<'PY'
import json, sys
hatalar = []
try:
    sunucu = json.loads(sys.argv[1]); istemci = json.loads(sys.argv[2])
except Exception as e:
    print("  ! Sonuç okunamadı: %s" % e); print("AG TESTI: KALDI"); sys.exit(1)

print("sunucu : %s" % sunucu)
print("istemci: %s" % istemci)

if sunucu.get("oyuncu_sayisi", 0) < 2:
    hatalar.append("İstemci sunucuya kaydolmadı (oyuncu sayısı %s)" % sunucu.get("oyuncu_sayisi"))
if istemci.get("olcum", 0) < 100:
    hatalar.append("Durum paketleri gelmiyor (%s ölçüm)" % istemci.get("olcum"))
# Sunucu 5 m yarıçaplı çemberde; aradeğerleme kirişten geçtiği için küçük bir
# sapma normal, 0.5 m'den fazlası veri bozulması demek.
if istemci.get("yaricap_hatasi", 99) > 0.5:
    hatalar.append("Konumlar çemberden sapıyor: %.2f m" % istemci["yaricap_hatasi"])
# 20 Hz gönderimde bir adım ~0.25 m; 1 m üstü ışınlanma demek.
if istemci.get("en_buyuk_adim", 99) > 1.0:
    hatalar.append("Hareket akıcı değil, en büyük adım %.2f m" % istemci["en_buyuk_adim"])
if istemci.get("toplam_yol", 0) < 5.0:
    hatalar.append("Uzak oyuncu hareket etmiyor (%.2f m)" % istemci.get("toplam_yol"))
if sunucu.get("reddedilen", 0) < 1:
    hatalar.append("Sunucu ışınlanma paketini reddetmedi")
# Tek hile paketi gönderildi. Fazlası masum paketlerin de reddedildiği
# (yanlış pozitif) anlamına gelir; doğrulama o zaman kullanılamaz hale gelir.
if sunucu.get("reddedilen", 0) > 2:
    hatalar.append("Doğrulama masum paketleri de reddediyor (%s ret)" % sunucu["reddedilen"])

if hatalar:
    for h in hatalar: print("  ! " + h)
    print("AG TESTI: KALDI (%d)" % len(hatalar)); sys.exit(1)
print("AG TESTI: GECTI"); sys.exit(0)
PY
sonuc=$?
rm -f "$SUNUCU_LOG" "$ISTEMCI_LOG"
exit $sonuc
