# Workflow'lar

Bu klasördeki GitHub Actions workflow'larının ne yaptığı ve neye ihtiyaç duydukları.

## Claude workflow'ları

### `claude-code-review.yml` — otomatik kod incelemesi

PR açıldığında ve PR'a her yeni push yapıldığında çalışır. Değişikliği inceleyip
bulgularını PR'a yorum olarak bırakır; gerektiğinde ilgili satırlara satır içi
yorum düşer.

- Görsel ve arşiv dosyaları (`png`, `jpg`, `jpeg`, `svg`, `zip`) incelemeyi
  tetiklemez — depoda yüzlerce KB'lık görsel var, sadece onlar değiştiğinde
  inceleme çalıştırmanın anlamı yok.
- Aynı PR'a arka arkaya push atılırsa önceki inceleme iptal edilir.
- Her push'ta yeni yorum açılmaz, tek bir yorum güncellenir.
- İzinler minimumda: koda sadece okuma erişimi var, commit atamaz.

### `claude.yml` — `@claude` ile çağırma

Şu durumlarda devreye girer:

- Issue veya PR yorumunda `@claude` geçtiğinde
- PR satır içi inceleme yorumunda `@claude` geçtiğinde
- PR incelemesi gönderilirken metinde `@claude` geçtiğinde
- Issue başlığında veya gövdesinde `@claude` geçtiğinde
- Bir issue'ya `claude` etiketi eklendiğinde veya issue birine atandığında

İnceleme workflow'undan farklı olarak bu workflow commit atabilir (`contents: write`),
çünkü kendisinden düzeltme yapması istenebiliyor. Ayrıca CI loglarını okuyabilmesi
için `actions: read` izni verilmiş — "şu build neden patladı" sorularını
yanıtlayabilmesi için gerekli.

### Kimlik doğrulama

Her iki workflow da `ANTHROPIC_API_KEY` secret'ını kullanır
(Settings → Secrets and variables → Actions). Depoda Claude GitHub App kurulu
olduğu için kimlik doğrulama bu secret olmadan da yürüyebilir; auth hatası
görülürse secret eklenmelidir.

API anahtarı yerine Claude Code aboneliği kullanmak isterseniz workflow'lardaki
`anthropic_api_key` satırını şununla değiştirmek yeterli:

```yaml
claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### Bilinen davranış: workflow dosyasını değiştiren PR'lar

Claude action'ı, workflow dosyası varsayılan dalda birebir aynı içerikle
bulunmuyorsa kendini durdurur ve şu uyarıyı verir:

> Workflow validation failed. The workflow file must exist and have identical
> content to the version on the repository's default branch.

Bu bir hata değil, PR üzerinden workflow'u değiştirip gizli anahtarlara erişmeyi
engelleyen bir güvenlik kontrolüdür. Bu klasördeki dosyaları değiştiren PR'larda
inceleme çalışmaz; değişiklik `main`'e indikten sonra normale döner.

## Diğer workflow'lar

| Dosya | Tetikleyici | Ne yapar |
|---|---|---|
| `deploy.yml` | `main`'e push | Cloudflare Workers'a deploy eder (ana worker + cron worker'ı) |
| `pages.yml` | `main`'e push | Depo kökünü GitHub Pages'e yayınlar |
| `ios.yml` | Elle | iOS uygulamasını derleyip App Store Connect'e yükler; istenirse sürümü App Review'a gönderir |
| `hesap-silme-kaydi.yml` | Elle | Hesap silme akışını iOS simülatöründe oynatıp ekran videosu kaydeder (artifact olarak iner) |
| `kart-sil-dogrula.yml` | Elle | Canlıdaki `/api/kart-sil` ucunun gerçekten sildiğini uçtan uca test eder; sahte numara kullanır |
| `d1-yedek.yml` | Her gün 03:00 + elle | Adisyon veritabanını (D1) yedekler; dump'ı `d1-yedek` dalına işler. Detay: `ONBOARDING.md` → Yedekleme |
