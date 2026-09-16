#!/usr/bin/env bash
# Telemetri testi: önce oyun tarafı (gizlilik kuralları), sonra istemci ile
# sunucunun aynı gövde biçimini konuşup konuşmadığı.
#
#   testler/telemetri_testi.sh [godot yolu]
#
# NEDEN KABUK BETİĞİ: sözleşmenin iki ucu iki ayrı dilde. Oyunun ürettiği
# GERÇEK gövdeyi alıp Worker'ın KENDİ doğrulayıcısından geçirmeden, "istemci
# gönderiyor, sunucu kabul ediyor" cümlesi bir varsayımdan ibaret kalıyor.
set -uo pipefail

GODOT="${1:-godot}"
PROJE="$(cd "$(dirname "$0")/.." && pwd)"
LOG=$(mktemp)

timeout 120 "$GODOT" --headless --path "$PROJE" res://testler/telemetri_testi.tscn > "$LOG" 2>&1
oyun_sonuc=$?
grep -E "TELEMETRI TESTI|  !" "$LOG"
if [ $oyun_sonuc -ne 0 ]; then
  rm -f "$LOG"; exit 1
fi

govde=$(grep -o 'GOVDE .*' "$LOG" | head -1 | cut -d' ' -f2-)
rm -f "$LOG"
if [ -z "$govde" ]; then
  echo "  ! Oyun gövde basmadı"; echo "SUNUCU TESTI: KALDI"; exit 1
fi

# Oyunun kodda kullandığı olay adları — sunucunun beyaz listesiyle
# karşılaştırılacak. Yeni bir olay eklenip sunucuya tanıtılmazsa parti TÜMDEN
# reddedilir; bu da "hiç veri gelmiyor" diye haftalar sonra fark edilir.
adlar=$(grep -rho 'Telemetri\.olay("[a-z_]*"' "$PROJE/betikler" \
  | sed 's/.*("\(.*\)"/\1/' | sort -u | tr '\n' ',')

GOVDE="$govde" ADLAR="$adlar" node --input-type=module -e '
import { satirlastir, OLAYLAR, AZAMI_OLAY } from "'"$PROJE"'/sunucu/src/index.js";

const hatalar = [];
const dogrula = (k, m) => { if (!k) hatalar.push(m); };
const simdi = Date.now();

// 1) Oyunun gerçek gövdesi sunucudan geçiyor mu?
const govde = JSON.parse(process.env.GOVDE);
const { hata, satirlar } = satirlastir(govde, simdi);
dogrula(!hata, `Sunucu oyunun gövdesini reddetti: ${hata}`);
if (satirlar) {
  dogrula(satirlar.length === 3, `3 satır bekleniyordu, ${satirlar.length} çıktı`);
  const olum = satirlar.find((s) => s.ad === "olum");
  dogrula(olum && olum.x === 4.5 && olum.z === -8.0, "Ölüm konumu satıra geçmedi");
  dogrula(olum && olum.bolum === "bolum1", "Bölüm kimliği satıra geçmedi");
  const bitti = satirlar.find((s) => s.ad === "bolum_bitti");
  dogrula(bitti && bitti.sure === 61.2 && bitti.yenilen === 2, "Bitiş alanları satıra geçmedi");
  dogrula(satirlar.every((s) => s.oturum === govde.oturum), "Oturum satırlara geçmedi");
  dogrula(satirlar.every((s) => s.server_ts === simdi), "Sunucu saati yazılmadı");
  // Gizlilik: şemada olmayan hiçbir alan satıra sızmamalı.
  const izinli = new Set(["oturum","ad","bolum","t","server_ts","surum","demo",
    "sure","x","y","z","toplanan","olum","yenilen"]);
  for (const s of satirlar)
    for (const alan of Object.keys(s))
      dogrula(izinli.has(alan), `Şemada olmayan alan satıra girdi: ${alan}`);
}

// 2) Oyunun gönderdiği her olay adı sunucunun beyaz listesinde mi?
const adlar = process.env.ADLAR.split(",").filter(Boolean);
dogrula(adlar.length >= 4, `Kodda olay çağrısı bulunamadı (${adlar.length})`);
for (const ad of adlar) dogrula(OLAYLAR.has(ad), `Sunucu bu olayı tanımıyor: ${ad}`);

// 3) Reddedilmesi gerekenler gerçekten reddediliyor mu?
const ret = (g, neden) => dogrula(!!satirlastir(g, simdi).hata, `Reddedilmeliydi: ${neden}`);
ret({ olaylar: [{ ad: "olum", surum: "1" }] }, "oturum yok");
ret({ oturum: "a", olaylar: [] }, "boş parti");
ret({ oturum: "a", olaylar: [{ ad: "sifre_calindi", surum: "1" }] }, "beyaz listede olmayan olay");
ret({ oturum: "a", olaylar: [{ ad: "olum" }] }, "sürüm yok");
ret({ oturum: "x".repeat(200), olaylar: [{ ad: "olum", surum: "1" }] }, "aşırı uzun oturum");
ret({ oturum: "a", olaylar: Array(AZAMI_OLAY + 1).fill({ ad: "olum", surum: "1" }) }, "parti sınırı");
ret("merhaba", "gövde nesne değil");

// 4) Saçma sayı satıra girmiyor ama parti düşmüyor: bozuk tek alan yüzünden
//    oturumun tamamını kaybetmek, veriyi hiç toplamamaktan beter.
const tasma = satirlastir({ oturum: "a",
  olaylar: [{ ad: "olum", surum: "1", x: 1e9, sure: -5, y: 2.0 }] }, simdi);
dogrula(!tasma.hata, "Sınır dışı sayı partiyi düşürdü");
if (tasma.satirlar) {
  dogrula(tasma.satirlar[0].x === null, "Sınır dışı x satıra girdi");
  dogrula(tasma.satirlar[0].sure === null, "Negatif süre satıra girdi");
  dogrula(tasma.satirlar[0].y === 2.0, "Geçerli alan da düştü");
}

if (hatalar.length) {
  for (const h of hatalar) console.log("  ! " + h);
  console.log(`SUNUCU TESTI: KALDI (${hatalar.length})`); process.exit(1);
}
console.log(`sözleşme: ${satirlar.length} satır, ${adlar.length} olay adı, 7 ret kuralı`);
console.log("SUNUCU TESTI: GECTI");
'
