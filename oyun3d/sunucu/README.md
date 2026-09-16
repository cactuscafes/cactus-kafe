# Telemetri sunucusu

Oyunun `Telemetri` autoload'unun konuştuğu uç. Tek soruyu yanıtlamak için var:
**demo nerede kopuyor?** Yirmi kişiyi omzundan izlemek en iyi yöntemdir ama
ölçeklenmez; ölüm haritası ölçeklenir.

Depoda **yayınlanmamış** durumda: `betikler/urun.gd` içindeki `TELEMETRI_URL`
boş olduğu sürece oyun hiçbir şey göndermiyor. Yayınlamak isteğe bağlı.

## Yayınlama

```sh
cd oyun3d/sunucu                              # kökten çalıştırmayın (bkz. wrangler.toml)
npx wrangler d1 create cactus-3b-telemetri    # dönen database_id'yi wrangler.toml'a yazın
npx wrangler d1 execute cactus-3b-telemetri --remote --file=sema.sql
npx wrangler secret put OZET_ANAHTARI         # /ozet için uzun rastgele bir dize
npx wrangler deploy
```

Çıkan adresi oyuna tanıtın:

```gdscript
# betikler/urun.gd
const TELEMETRI_URL := "https://cactus-3b-telemetri.<hesap>.workers.dev/olay"
```

Adresi depoya yazmak zorunlu değil; dağıtım makinesinde tutup yalnızca yayın
yapılırken doldurmak da geçerli bir tercih.

## Uçlar

| Uç | Yöntem | Ne yapar |
| --- | --- | --- |
| `/olay` | POST | Olay partisini yazar. Açık uç, kimlik doğrulaması yok. |
| `/ozet` | GET | Huni + ölüm noktaları + bitirme süreleri. `X-Cactus-Key` ister. |
| `/saglik` | GET | Ayakta mı? |

```sh
curl -s -H "X-Cactus-Key: $ANAHTAR" \
  "https://cactus-3b-telemetri.<hesap>.workers.dev/ozet?gun=30" | jq .
```

`olum_noktalari`, 2 birimlik ızgaraya yuvarlanmış ölüm yığınlarını çoktan aza
sıralar. Listenin başındaki üç nokta, bölümün en zor üç yeridir. Oyunun zor
olması sorun değil; **istemeden** zor olması sorundur.

## Gizlilik

Üçü de kodda, metinde değil:

1. **Varsayılan kapalı.** `Ayarlar.telemetri` başlangıçta `false`; ayarlardan
   açık rıza gerekiyor.
2. **Adres boşken hiç çalışmıyor.** `Telemetri.etkin_mi()` iki koşulu da arar.
3. **Kimlik yok.** Oturum numarası her açılışta yeniden üretiliyor ve diske
   yazılmıyor: iki oturum birbirine bağlanamıyor.

Sunucu tarafında:

- **IP ve User-Agent hiçbir yere yazılmıyor.** `sema.sql` içinde bunlar için
  sütun yok — şema, gizlilik sözleşmesinin kendisi.
- Şemada olmayan alan veritabanına giremiyor; olay adı beyaz listede
  (`bolum_basladi`, `olum`, `bolum_bitti`, `bolum_birakildi`) değilse parti
  tümden reddediliyor. Yeni bir olay eklemek, gizlilik metnini de güncellemeyi
  gerektiren bir şema değişikliği demek — bilerek zor.
- Worker günlüklerine yalnızca hata mesajı yazılıyor. Cloudflare panelinden
  günlük saklama süresini kısa tutun.

Yayınlarsanız gizlilik metnine tek cümle yetiyor: *"İsteğe bağlı olarak açtığınız
takdirde oyun, hangi bölümde ne kadar oynadığınızı ve nerede öldüğünüzü anonim
olarak gönderir; kişisel veri toplanmaz."*

## Kötüye kullanım

Açık uçta kimlik doğrulaması yok, çünkü oyuna gömülecek bir anahtar zaten
anahtar değildir. Koruma gövde ve olay sayısı sınırlarıyla (16 KB / 60 olay).
Birisi uğraşır da sahte veri basarsa istatistikler bozulur — veri sızmaz.
Rahatsız edici olursa Cloudflare panelinden `/olay` için bir hız sınırı
kuralı (rate limiting rule) ekleyin; kod değişikliği gerekmiyor.

## Veriyi silmek

```sh
npx wrangler d1 execute cactus-3b-telemetri --remote \
  --command "DELETE FROM olaylar WHERE server_ts < strftime('%s','now','-90 days')*1000"
```

Bir oyuncu kendi verisinin silinmesini isterse elinizde bağlayacak kimlik yok —
bu bir eksiklik değil, tasarımın kendisi. Gizlilik metninde bunu böyle yazın.
