#!/usr/bin/env bash
# D1 adisyon eventlerini worker'in acik /api/events endpoint'i uzerinden NDJSON'a doker.
# Cloudflare API token'i GEREKTIRMEZ — `wrangler d1 export` yetki hatasi verdiginde
# yedek yol olarak kullanilir. Sema depoda: schema-adisyon-events.sql
#
# Kullanim: d1-yedek-api.sh <worker-kok-adresi> <cikti.ndjson> [sube ...]
# stdout: toplam event sayisi   stderr: ilerleme
set -euo pipefail

KOK="${1:?worker kok adresi gerekli}"
CIKTI="${2:?cikti dosyasi gerekli}"
shift 2
SUBELER=("$@")
[ "${#SUBELER[@]}" -gt 0 ] || SUBELER=(podyum fsm)

LIMIT=5000
MAX_SAYFA=2000   # sonsuz donguye karsi tavan (5000*2000 = 10M event)

: > "$CIKTI"
TOPLAM=0

for sube in "${SUBELER[@]}"; do
  since=0; sayfa=0; alt=0
  while :; do
    sayfa=$((sayfa + 1))
    if [ "$sayfa" -gt "$MAX_SAYFA" ]; then
      echo "HATA: $sube icin sayfa siniri ($MAX_SAYFA) asildi — donguye girmis olabilir." >&2
      exit 1
    fi

    gecici=$(mktemp)
    kod=$(curl -sS --max-time 60 --retry 3 --retry-delay 2 -o "$gecici" -w '%{http_code}' \
      "$KOK/api/events?sube=$sube&since=$since&limit=$LIMIT") || {
        echo "HATA: istek basarisiz ($sube, since=$since)" >&2; rm -f "$gecici"; exit 1; }

    if [ "$kod" != 200 ]; then
      echo "HATA: HTTP $kod ($sube, since=$since)" >&2; head -c 300 "$gecici" >&2; rm -f "$gecici"; exit 1
    fi
    if ! jq -e '.ok == true' "$gecici" >/dev/null 2>&1; then
      echo "HATA: yanit ok:true degil ($sube, since=$since)" >&2; head -c 300 "$gecici" >&2; rm -f "$gecici"; exit 1
    fi

    adet=$(jq -r '.count' "$gecici")
    if [ "$adet" -eq 0 ]; then rm -f "$gecici"; break; fi

    # sube alani yanitta yok (sorgu parametresi) — yedege geri koyuyoruz
    jq -c --arg sube "$sube" '.events[] | {sube:$sube} + .' "$gecici" >> "$CIKTI"
    yeni=$(jq -r '.last_seq' "$gecici")
    rm -f "$gecici"

    if [ "$yeni" -le "$since" ]; then
      echo "HATA: last_seq ilerlemiyor ($sube: $since -> $yeni) — eksik yedek riski." >&2; exit 1
    fi
    since="$yeni"; alt=$((alt + adet)); TOPLAM=$((TOPLAM + adet))
  done
  echo "  $sube: $alt event (son seq: $since)" >&2
done

echo "$TOPLAM"
