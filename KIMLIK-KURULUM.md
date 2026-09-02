# Cactus — Kimlik & Token Kurulumu

Bu doküman **şifre yerine token** kullanmak ve geliştirme makinesinde bir daha
giriş sorulmaması için tek seferlik kurulumu anlatır.

Hedef: "bir kere gir, bir daha sorma" — ama **süresiz anahtar taşımadan**.

---

## Prensip: şifreyi değil, oturumu sakla

| | Şifre saklamak | Oturum/token saklamak |
|---|---|---|
| Kapsam | Her şeyi açar | Tek servise özel |
| Ömür | Sen değiştirene kadar | Saatler — sessizce yenilenir |
| İptal | Rotasyon + her yeri güncelleme | Panelden tek tık |
| Sızarsa | Ciddi olay | Sınırlı ve kısa süreli |

Doğru kalıp şudur: diskte **uzun ömürlü bir yenileme kimliği** durur, o kimlik
arka planda **kısa ömürlü erişim jetonu** üretir. Sana bir daha sorulmaz, ama
kullanımdaki jeton birkaç saatte ölür.

> Bu projenin Worker'ı bunu zaten yapıyor: `src/index.js` → `yonetimJetonu()`
> `KART_YONETIM_SIFRE` secret'ından ~1 saatlik jeton alır, önbelleğe koyar,
> süresi dolunca yeniler. Şifre hiçbir zaman istemciye gitmez.

---

## Tek seferlik kurulum (geliştirme makinesi)

Aşağıdakiler makinede **bir kere** çalıştırılır. Sonrasında hiçbiri şifre sormaz.

### 1. Cloudflare

```bash
wrangler login          # tarayıcıda onayla — OAuth
wrangler whoami         # doğrula
```

Kimlik `~/.wrangler/` altına yazılır ve kendini yeniler. API token'ı elle
oluşturup kopyalamaya **gerek yok** — o yöntem uzun ömürlü sır taşır, bu taşımaz.

### 2. GitHub

```bash
gh auth login           # HTTPS + tarayıcı ile giriş
gh auth setup-git       # git push artık kimlik sormaz
gh auth status          # doğrula
```

Token macOS Keychain'e yazılır; Keychain girişte açıldığı için tekrar sorulmaz.

### 3. SSH (git için alternatif)

`~/.ssh/config` içine:

```
Host github.com
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_ed25519
```

Anahtar parolası Keychain'de tutulur, her açılışta otomatik yüklenir.

---

## Token envanteri — ne nerede duruyor

| Kimlik | Yeri | Kullanan | İptal / yenileme |
|---|---|---|---|
| `CLOUDFLARE_API_TOKEN` | GitHub Actions secret | `deploy.yml` | Cloudflare → My Profile → API Tokens |
| `CLOUDFLARE_ACCOUNT_ID` | Actions secret | `deploy.yml` | Sır değil, kimlik numarası |
| `ASC_KEY_P8` / `ASC_KEY_ID` / `ASC_ISSUER_ID` | Actions secret | `ios.yml` | App Store Connect → Users and Access → Integrations |
| `APPLE_TEAM_ID` | Actions secret | `ios.yml` | Sır değil |
| `KART_YONETIM_SIFRE` | Wrangler secret (Worker) | `src/index.js` | `wrangler secret put KART_YONETIM_SIFRE` |
| GitHub Pages yayını | OIDC (`id-token: write`) | `pages.yml` | Saklanan sır yok — en iyisi |
| Admin panel GitHub token'ı | Tarayıcı `localStorage` (`cactus_gh_token`) | `admin.html` | github.com/settings/personal-access-tokens |

Actions secret'ları: **repo → Settings → Secrets and variables → Actions**

Worker secret'ları:

```bash
wrangler secret list
wrangler secret put KART_YONETIM_SIFRE      # değeri sorar, ekrana basmaz
wrangler secret delete <AD>
```

---

## Kurallar

**Yapılır**

- Servisin kendi OAuth akışı varsa onu kullan (`wrangler login`, `gh auth login`).
- Token'ı mümkün olan **en dar yetkiyle** üret. Admin panelinin GitHub token'ı
  fine-grained ve yalnızca bu repoya yazma yetkili olmalı.
- Sırlar Actions secret / Wrangler secret içinde dursun; koda ve depoya girmesin.
- `.dev.vars` ve `.env` yereldedir, `.gitignore` bunları zaten dışlıyor.

**Yapılmaz**

- Şifre veya token'ı sohbete, issue'ya, commit mesajına yazmak — hepsi loglanır.
- Geniş yetkili classic GitHub token'ı üretmek.
- Süresiz token oluşturmak. Zaten sormuyorsa süresizlik hiçbir şey kazandırmaz,
  sızıntı hâlinde her şeyi kaybettirir.
- `.dev.vars`, `auth.json`, `*.p8` gibi dosyaları depoya eklemek.

---

## Bir şey sızarsa

1. **İptal et** — yenisini üretmeden önce eskisini öldür.
   - Cloudflare: My Profile → API Tokens → Roll/Delete
   - GitHub: `gh auth logout` + settings'ten token'ı sil
   - Apple: App Store Connect → Integrations → anahtarı Revoke
   - Worker: `wrangler secret put KART_YONETIM_SIFRE` (yeni değerle üzerine yaz)
2. **Yerine koy** — yeni değeri Actions secret / Wrangler secret olarak gir.
3. **Depoyu tara** — sır commit'e girdiyse iptal etmek şart; geçmişten silmek
   tek başına yetmez, çünkü klonlarda ve fork'larda kalır.

---

## Sınırlar

- **Düz web panelleri** (Trendyol, CallMeBot vb.) için token yolu yoktur; elde
  yalnızca oturum çerezi vardır ve ömrünü site belirler — süresiz yapılamaz.
- Tarayıcı oturum dosyası (`storageState`, `auth.json`) pratikte şifre kadar
  değerlidir: onu alan giriş yapmış sayılır. Depoya asla girmemeli.
- **Bankacılık, e-devlet ve kurumsal SSO hesaplarında bu yöntemler kullanılmaz.**
