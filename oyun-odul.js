/* ═══════════════════════════════════════════════════════════════
 * CACTUS OYUN KAMPANYASI — ortak modül
 *
 * Dört oyun da bunu kullanır: üyelik kapısı + limonata ödülü tek yerde.
 * Her oyuna 150 satır kopyalamak yerine burada durur; eşik değiştirmek
 * istendiğinde tek dosya yeter (worker'daki eşikler de aynı tutulmalı).
 *
 * Kullanım (oyun sayfasında):
 *   <script src="oyun-odul.js"></script>
 *   CactusOdul.kur({ oyun:'jump' });
 *   ...oyun bitince:
 *   CactusOdul.bitti(skor, gecenSaniye);
 *
 * ═══ 2026-08-12: SABİT EŞİK → YÜKSELEN REKOR ═══
 * Eskiden sabit bir eşiği geçen HERKES kazanıyordu. Artık yalnızca
 * REKORU KIRAN kazanıyor ve bar her kırılışta yükseliyor. Bu yüzden eşik
 * artık burada yazılı değil — sunucudan (/kart/oyun-rekor) çekiliyor.
 * Sayfaya elle eşik yazma; iki yer ayrışır ve oyuncuya yalan söylersin.
 *
 * ÜYELİK KAPISI KALDIRILDI: oyunlar "Serbest · Herkese açık". Telefon
 * yalnızca rekor kırılınca, limonatayı işlemek için soruluyor.
 *
 * Ödülün gerçek doğrulaması sunucuda — buradaki kontrol sadece kartı
 * gereksiz yere açmamak için.
 * ═══════════════════════════════════════════════════════════════ */
(function (global) {
  'use strict';

  var API = 'https://cactus-rapor-api.batuhanbulut.workers.dev';
  var UYE_ANAHTAR = 'cactus_oyun_uye';
  var ayar = null;          // { oyun }
  var uyeTel = null;
  var odulSunuldu = false;  // bir oturumda tek kez teklif et
  /* Sunucudan gelen güncel rekor: { skor, ad, taban, aktif }.
     Rekor kırılınca yerel olarak da güncelleniyor ki oyuncu aynı oturumda
     ikinci kez oynadığında eski barı görmesin. */
  var rekor = null;
  var rekorDinleyici = null;

  /* ── Stil: sayfaya bir kez enjekte edilir ── */
  function stilEkle() {
    if (document.getElementById('cactusOdulStil')) return;
    var s = document.createElement('style');
    s.id = 'cactusOdulStil';
    s.textContent =
      '.co-kat{position:fixed;inset:0;display:flex;align-items:center;justify-content:center;' +
      'padding:22px;background:rgba(10,20,8,.82);z-index:40;font-family:Montserrat,-apple-system,sans-serif;}' +
      '.co-kart{background:#F7EFDE;border:3px solid #C8A86A;border-radius:24px;padding:26px 22px 22px;' +
      'max-width:340px;width:100%;text-align:center;box-shadow:0 20px 60px rgba(0,0,0,.45);}' +
      '.co-ikon{font-size:42px;line-height:1;margin-bottom:10px;}' +
      '.co-bas{font-size:20px;font-weight:700;color:#1A3310;margin-bottom:8px;}' +
      '.co-metin{font-size:13px;color:#5a5348;line-height:1.6;margin-bottom:18px;}' +
      '.co-tel{width:100%;padding:13px;border:1.5px solid #d8cfbc;border-radius:12px;font-family:inherit;' +
      'font-size:15px;text-align:center;margin-bottom:10px;outline:none;}' +
      '.co-tel:focus{border-color:#C8A86A;}' +
      '.co-onay{display:flex;gap:8px;align-items:flex-start;text-align:left;font-size:13px;' +
        'color:#5a5348;line-height:1.45;margin:10px 0 4px;}' +
      '.co-onay input{margin-top:2px;flex:none;}' +
      '.co-btn{display:block;width:100%;padding:14px;border:none;border-radius:14px;background:#2D5A27;' +
      'color:#fff;font-family:inherit;font-size:13px;letter-spacing:1.5px;cursor:pointer;margin-bottom:9px;}' +
      '.co-btn:disabled{opacity:.55;cursor:default;}' +
      '.co-btn.ikincil{background:transparent;color:#5a5348;border:1.5px solid #d8cfbc;text-decoration:none;line-height:1.2;}' +
      '.co-durum{font-size:12px;margin-top:10px;min-height:16px;}';
    document.head.appendChild(s);
  }

  function kat(icerik) {
    var d = document.createElement('div');
    d.className = 'co-kat';
    d.innerHTML = '<div class="co-kart">' + icerik + '</div>';
    document.body.appendChild(d);
    return d;
  }

  function telDuzelt(ham) {
    var t = String(ham || '').replace(/\D/g, '');
    if (t.indexOf('5') === 0 && t.length === 10) t = '0' + t;
    return t;
  }

  /* ── Üyelik ── */
  function onbellekOku() {
    try {
      var v = JSON.parse(localStorage.getItem(UYE_ANAHTAR) || 'null');
      if (v && v.tel && Date.now() - v.ts < 7 * 864e5) return v.tel;
    } catch (e) {}
    return null;
  }

  function uyeKaydet(tel) {
    uyeTel = tel;
    try {
      localStorage.setItem(UYE_ANAHTAR, JSON.stringify({ tel: tel, ts: Date.now() }));
      localStorage.setItem('cactus_kart_tel', tel);
    } catch (e) {}
  }

  /* Üyelik kapısı (kapiAc + uyeDogrula) 2026-08-12'de kaldırıldı: oyunlar
     herkese açık, telefon yalnızca rekor kırılınca soruluyor. Kapı geri
     istenirse git geçmişinde duruyor. */

  /* ── Rekor ── */
  function rekorCek() {
    return fetch(API + '/kart/oyun-rekor?oyun=' + encodeURIComponent(ayar.oyun))
      .then(function (r) { return r.json(); })
      .then(function (j) {
        if (j && j.ok) {
          rekor = j;
          if (rekorDinleyici) rekorDinleyici(j);
        }
        return rekor;
      })
      .catch(function () { return null; });   // ağ yoksa oyun yine oynanır
  }

  /* ── Ödül ── */
  function odulAc(skor, sure) {
    stilEkle();
    var k = kat(
      '<div class="co-ikon">🏆</div>' +
      '<div class="co-bas">Rekoru kırdın!</div>' +
      '<div class="co-metin" id="coOdulMetin"></div>' +
      '<input class="co-tel" id="coOdulTel" type="tel" inputmode="numeric" maxlength="11" placeholder="05XX XXX XX XX">' +
      '<button class="co-btn" id="coAl">HAKKIMI AL</button>' +
      '<button class="co-btn ikincil" id="coKapat">Kapat</button>' +
      '<div class="co-durum" id="coOdulDurum"></div>'
    );
    var eski = rekor ? rekor.skor : null;
    k.querySelector('#coOdulMetin').textContent =
      skor + ' yaptın' + (eski ? ' — eski rekor ' + eski + '.' : '.') +
      ' Sadakat kartına kayıtlı numaranı gir: limonata hakkın işlensin ve ' +
      'adın rekor tabelasına yazılsın.';
    k.querySelector('#coOdulTel').value = uyeTel || '';
    k.querySelector('#coKapat').addEventListener('click', function () { k.remove(); });

    var btn = k.querySelector('#coAl');
    var durum = k.querySelector('#coOdulDurum');
    var kayitModu = false;      // sunucu "önce kaydol" dediyse true

    /* Rekoru kıran ama sadakat kartında olmayan oyuncu için: adını alıp
       burada kaydediyoruz, sonra aynı skoru tekrar gönderiyoruz. Oyuncuyu
       "git kaydol, sonra gel" diye göndermek rekorun kaybolması demekti —
       26 Ağustos 2026'da 46'lık bir rekor tam böyle düştü. */
    function kayitAlaniAc(mesaj) {
      kayitModu = true;
      durum.style.color = '#8a6a2a';
      durum.textContent = mesaj || 'Rekoru yazmak için bir kerelik kaydolman gerekiyor.';
      if (k.querySelector('#coOdulAd')) { btn.disabled = false; return; }
      var ad = document.createElement('input');
      ad.className = 'co-tel'; ad.id = 'coOdulAd'; ad.type = 'text';
      ad.placeholder = 'Adın Soyadın'; ad.autocomplete = 'name';
      ad.style.marginTop = '10px';
      btn.parentNode.insertBefore(ad, btn);
      var onay = document.createElement('label');
      onay.className = 'co-onay';
      onay.innerHTML = '<input type="checkbox" id="coOdulKvkk"> Sadakat kartı için ' +
        'adım ve numaramın saklanmasını kabul ediyorum.';
      btn.parentNode.insertBefore(onay, btn);
      btn.textContent = 'KAYDOL VE REKORU YAZ';
      btn.disabled = false;
      ad.focus();
    }

    function odulGonder(tel) {
      return fetch(API + '/kart/oyun-odul', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ telefon: tel, oyun: ayar.oyun, skor: skor, sure: Math.round(sure || 0) })
      }).then(function (r) { return r.json(); }).then(function (j) {
        if (j.ok) {
          uyeKaydet(tel);
          // Tabelayı hemen güncelle: aynı oturumda tekrar oynayan oyuncu
          // kendi kırdığı rekoru görsün, eskisini değil.
          rekor = { ok: true, oyun: ayar.oyun, skor: j.skor, ad: j.ad,
                    taban: rekor ? rekor.taban : j.skor, aktif: true };
          if (rekorDinleyici) rekorDinleyici(rekor);
          durum.style.color = j.odul ? '#2d7a4f' : '#8a6a2a';
          // Haftalık sınıra takılırsa rekor yine yazılır ama limonata çıkmaz;
          // sunucu bunu `odul:false` + açıklayıcı mesajla bildiriyor.
          durum.textContent = j.mesaj || '✓ İşlendi.';
          btn.textContent = j.odul ? 'TANIMLANDI' : 'REKOR YAZILDI';
        } else if (j.kayitGerek) {
          kayitAlaniAc(j.error);
        } else {
          durum.style.color = '#c0392b';
          durum.textContent = j.error || 'İşlenemedi';
          btn.disabled = false;
        }
      }).catch(function () {
        durum.style.color = '#c0392b';
        durum.textContent = 'Bağlantı hatası — tekrar dene';
        btn.disabled = false;
      });
    }

    btn.addEventListener('click', function () {
      var tel = telDuzelt(k.querySelector('#coOdulTel').value);
      if (tel.length !== 11) {
        durum.style.color = '#c0392b'; durum.textContent = 'Geçerli bir telefon numarası gir'; return;
      }
      if (!kayitModu) {
        btn.disabled = true;
        durum.style.color = '#5a5348'; durum.textContent = 'Gönderiliyor…';
        odulGonder(tel);
        return;
      }
      // Kayıt modu: önce sadakat kaydı, hemen ardından aynı skor
      var ad = (k.querySelector('#coOdulAd').value || '').trim();
      var kvkk = k.querySelector('#coOdulKvkk').checked;
      if (ad.length < 2) {
        durum.style.color = '#c0392b'; durum.textContent = 'Adını yaz'; return;
      }
      if (!kvkk) {
        durum.style.color = '#c0392b'; durum.textContent = 'Kaydolmak için onay kutusunu işaretle'; return;
      }
      btn.disabled = true;
      durum.style.color = '#5a5348'; durum.textContent = 'Kaydediliyor…';
      fetch(API + '/kart/kayit', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ telefon: tel, ad: ad, kvkk: true })
      }).then(function (r) { return r.json(); }).then(function (j) {
        if (!j.ok) {
          durum.style.color = '#c0392b';
          durum.textContent = j.error || 'Kayıt yapılamadı';
          btn.disabled = false;
          return;
        }
        durum.textContent = 'Rekor yazılıyor…';
        kayitModu = false;
        return odulGonder(tel);
      }).catch(function () {
        durum.style.color = '#c0392b';
        durum.textContent = 'Bağlantı hatası — tekrar dene';
        btn.disabled = false;
      });
    });
  }

  /* ── Dışa açık API ── */
  global.CactusOdul = {
    /**
     * @param o.oyun     sunucudaki oyun anahtarı ('jump')
     * @param o.rekorGeldi  rekor her değiştiğinde çağrılır ({skor, ad})
     */
    kur: function (o) {
      ayar = o || {};
      rekorDinleyici = ayar.rekorGeldi || null;
      var onbellek = onbellekOku();
      if (onbellek) uyeTel = onbellek;
      // Üyelik kapısı YOK — oyun herkese açık. Telefon yalnızca rekor
      // kırılınca soruluyor.
      rekorCek();
    },

    /** Oyun bitince çağrılır. Rekor kırıldıysa ödül kartını açar. */
    bitti: function (skor, sure) {
      if (!ayar || odulSunuldu) return;
      // Rekor henüz gelmediyse (ağ yavaş) kartı açma: yanlış barla
      // "kazandın" demek, sunucunun reddiyle sonuçlanır ve oyuncuyu kızdırır.
      if (!rekor || !rekor.aktif) return;
      if (skor <= rekor.skor) return;
      // Sunucunun süre alt sınırıyla aynı mantık — buradan geçemeyecek bir
      // skoru "kazandın" diye göstermeyelim.
      if (sure < skor * 0.8) return;
      odulSunuldu = true;
      setTimeout(function () { odulAc(skor, sure); }, 700);
    },

    /** Ekranda "Rekor 45 — Batuhan B." yazmak için. */
    rekor: function () { return rekor; },
    uye: function () { return uyeTel; },

    /** SALT OKUNUR: ödül sistemine bağlanmadan yalnızca salon rekorunu çeker.
     *  Web'deki Cactus Jump bunu kullanır — kampanya yalnızca App Store
     *  uygulamasında geçerli olduğu için skor gönderimi/telefon penceresi yok. */
    rekorOku: function (oyun, cb) {
      fetch(API + '/kart/oyun-rekor?oyun=' + encodeURIComponent(oyun))
        .then(function (r) { return r.json(); })
        .then(function (j) { if (j && j.ok && cb) cb(j); })
        .catch(function () {});
    }
  };
})(window);
