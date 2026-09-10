/* ═══ CACTUS REKLAM TAKİBİ — kaynak yakalama + Meta Pixel ═══
 *
 * Ne yapar:
 *   1. Reklamdan gelen ziyaretçinin UTM etiketlerini yakalar, 30 gün saklar.
 *      (Kişi bugün reklamı tıklayıp bir hafta sonra kart açsa bile kaynağı bilinir.)
 *   2. Meta Pixel'i yükler ve PageView bildirir.
 *   3. Dönüşüm anında (kart oluşturma) Meta'ya olay gönderir.
 *
 * ÖNEMLİ: PIXEL_ID boş olduğu sürece Facebook'a HİÇBİR istek gitmez.
 * Sadece kaynak bilgisi tarayıcıda saklanır. Yani bu dosya bugün yayına
 * alınsa da siteye üçüncü taraf takip kodu eklenmiş olmaz.
 *
 * Kurulum:  <script src="reklam-takip.js?v=1"></script>   (</head> öncesi)
 *
 * Kullanım:
 *   cactusReklam.kaynak()                → {utm_source, utm_campaign, ...} | null
 *   cactusReklam.olay('KartOlusturuldu') → dönüşümü Meta'ya bildirir
 */
(function () {
  'use strict';

  // ── Meta Pixel ID — Etkinlik Yöneticisi'nden alınan 15-16 haneli sayı ──
  // Boş bırakıldığında Pixel yüklenmez. Tek yapılacak: tırnakların arasına yazmak.
  var PIXEL_ID = '';

  var ANAHTAR   = 'cactus_reklam_kaynak';
  var SAKLA_GUN = 30;
  // fbclid: UTM'i olmayan ama Facebook/Instagram'dan gelen tıklamayı da yakalar
  var ALANLAR = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid'];

  // ── Kaynak yakalama ───────────────────────────────────────────────────────
  function urldenOku() {
    try {
      var q = new URLSearchParams(location.search), bulunan = null;
      ALANLAR.forEach(function (a) {
        var v = q.get(a);
        if (v) { (bulunan = bulunan || {})[a] = String(v).slice(0, 120); }
      });
      return bulunan;
    } catch (e) { return null; }
  }

  function yaz(k) {
    try {
      k.ts = Date.now();
      k.giris = location.pathname;
      localStorage.setItem(ANAHTAR, JSON.stringify(k));
    } catch (e) {}
  }

  function oku() {
    try {
      var ham = localStorage.getItem(ANAHTAR);
      if (!ham) return null;
      var k = JSON.parse(ham);
      // Süresi dolduysa kaynağı unut — 30 gün önceki reklam bugünkü ziyareti açıklamaz
      if (!k.ts || Date.now() - k.ts > SAKLA_GUN * 864e5) {
        localStorage.removeItem(ANAHTAR);
        return null;
      }
      return k;
    } catch (e) { return null; }
  }

  // Yeni etiket varsa üzerine yazar (son tıklama kazanır); yoksa eskisi korunur.
  var yeniKaynak = urldenOku();
  if (yeniKaynak) yaz(yeniKaynak);

  // ── Meta Pixel ────────────────────────────────────────────────────────────
  function pixelYukle(id) {
    if (!id || window.fbq) return;
    /* eslint-disable */
    !function (f, b, e, v, n, t, s) {
      if (f.fbq) return; n = f.fbq = function () {
        n.callMethod ? n.callMethod.apply(n, arguments) : n.queue.push(arguments);
      };
      if (!f._fbq) f._fbq = n; n.push = n; n.loaded = !0; n.version = '2.0'; n.queue = [];
      t = b.createElement(e); t.async = !0; t.src = v;
      s = b.getElementsByTagName(e)[0]; s.parentNode.insertBefore(t, s);
    }(window, document, 'script', 'https://connect.facebook.net/en_US/fbevents.js');
    /* eslint-enable */
    window.fbq('init', id);
    window.fbq('track', 'PageView');
  }

  // Pixel ID önceliği: bu dosyadaki sabit → sayfada tanımlı global
  pixelYukle(PIXEL_ID || window.CACTUS_PIXEL_ID);

  // ── Dönüşüm olayı ─────────────────────────────────────────────────────────
  // Her olaya benzersiz bir kimlik veriyoruz: ileride Conversions API (sunucu
  // tarafı) devreye girdiğinde aynı dönüşüm iki kez sayılmasın diye Meta bu
  // kimliğe bakarak tekilleştirir.
  function olayId() {
    return 'ck-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 8);
  }

  function olay(ad, ek) {
    var p = {}, k = oku();
    if (k) {
      p.kaynak   = k.utm_source   || (k.fbclid ? 'facebook' : 'dogrudan');
      p.kampanya = k.utm_campaign || '';
      p.kreatif  = k.utm_content  || '';
    }
    if (ek) { for (var x in ek) if (Object.prototype.hasOwnProperty.call(ek, x)) p[x] = ek[x]; }

    var id = olayId();
    try {
      if (window.fbq) {
        // Lead: Meta'nın optimize edeceği standart olay.
        // Ayrıca aynı dönüşümü kendi adıyla da bildiriyoruz — raporda
        // "KartOlusturuldu" diye okunsun diye. Farklı isimler, çift sayım yok.
        window.fbq('track', 'Lead', p, { eventID: id });
        window.fbq('trackCustom', ad, p, { eventID: id + '-c' });
      }
    } catch (e) {}
    return id;
  }

  window.cactusReklam = { kaynak: oku, olay: olay, pixelVar: function () { return !!window.fbq; } };
})();
