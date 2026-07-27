/* ═══════════════════════════════════════════════════════════════
 * CACTUS OYUN KAMPANYASI — ortak modül
 *
 * Dört oyun da bunu kullanır: üyelik kapısı + limonata ödülü tek yerde.
 * Her oyuna 150 satır kopyalamak yerine burada durur; eşik değiştirmek
 * istendiğinde tek dosya yeter (worker'daki eşikler de aynı tutulmalı).
 *
 * Kullanım (oyun sayfasında):
 *   <script src="oyun-odul.js"></script>
 *   CactusOdul.kur({ oyun:'jump', esik:25 });          // yüksek skor iyi
 *   CactusOdul.kur({ oyun:'hafiza', esik:14, tersYon:true, birim:'hamle' });
 *   ...oyun bitince:
 *   CactusOdul.bitti(skor, gecenSaniye);
 *
 * Ödülün gerçek doğrulaması sunucuda. Buradaki kapı kampanyayı üyeliğe
 * bağlamak için; üye olmayana zaten hak tanımlanmıyor.
 * ═══════════════════════════════════════════════════════════════ */
(function (global) {
  'use strict';

  var API = 'https://cactus-rapor-api.batuhanbulut.workers.dev';
  var UYE_ANAHTAR = 'cactus_oyun_uye';
  var ayar = null;          // { oyun, esik, tersYon, birim }
  var uyeTel = null;
  var odulSunuldu = false;  // bir oturumda tek kez teklif et

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

  /* /kart/bak hız sınırlı olduğu için sonuç 7 gün önbelleklenir —
   * her oyun açılışında sorgulamak oyuncuyu kendi kapısında kilitlerdi. */
  function uyeDogrula(tel) {
    return fetch(API + '/kart/bak?telefon=' + encodeURIComponent(tel))
      .then(function (r) { return r.json().then(function (j) { return { s: r.status, j: j }; }); })
      .then(function (o) {
        if (o.j && o.j.ok && o.j.musteri) { uyeKaydet(tel); return true; }
        if (o.s === 429) throw new Error('Çok fazla deneme — birazdan tekrar dene');
        throw new Error('Bu numara sadakat kartına kayıtlı değil');
      });
  }

  function kapiAc() {
    stilEkle();
    var k = kat(
      '<div class="co-ikon">🎖</div>' +
      '<div class="co-bas">Önce sadakat kartı</div>' +
      '<div class="co-metin">Bu oyun sadakat üyelerine özel. Telefonunu gir, üyeliğini doğrulayalım.</div>' +
      '<input class="co-tel" id="coTel" type="tel" inputmode="numeric" maxlength="11" placeholder="05XX XXX XX XX">' +
      '<button class="co-btn" id="coGir">DOĞRULA VE OYNA</button>' +
      '<a class="co-btn ikincil" href="kart.html">Üye değilim — kaydol</a>' +
      '<div class="co-durum" id="coDurum"></div>'
    );
    var giris = k.querySelector('#coTel');
    var btn = k.querySelector('#coGir');
    var durum = k.querySelector('#coDurum');

    var kayitli = '';
    try { kayitli = localStorage.getItem('cactus_kart_tel') || ''; } catch (e) {}
    giris.value = kayitli;
    if (kayitli.length === 11) {
      durum.style.color = '#5a5348';
      durum.textContent = 'Üyelik kontrol ediliyor…';
      uyeDogrula(kayitli).then(function () { k.remove(); })
        .catch(function () { durum.textContent = ''; });
    }

    btn.addEventListener('click', function () {
      var tel = telDuzelt(giris.value);
      if (tel.length !== 11) {
        durum.style.color = '#c0392b'; durum.textContent = 'Geçerli bir numara gir'; return;
      }
      btn.disabled = true;
      durum.style.color = '#5a5348'; durum.textContent = 'Kontrol ediliyor…';
      uyeDogrula(tel).then(function () {
        durum.style.color = '#2d7a4f'; durum.textContent = '✓ Hoş geldin!';
        setTimeout(function () { k.remove(); }, 400);
      }).catch(function (e) {
        durum.style.color = '#c0392b'; durum.textContent = e.message;
        btn.disabled = false;
      });
    });
    giris.addEventListener('keydown', function (e) { if (e.key === 'Enter') btn.click(); });
  }

  /* ── Ödül ── */
  function odulAc(skor, sure) {
    stilEkle();
    var k = kat(
      '<div class="co-ikon">🍋</div>' +
      '<div class="co-bas">Limonata kazandın!</div>' +
      '<div class="co-metin" id="coOdulMetin"></div>' +
      '<input class="co-tel" id="coOdulTel" type="tel" inputmode="numeric" maxlength="11" placeholder="05XX XXX XX XX">' +
      '<button class="co-btn" id="coAl">HAKKIMI AL</button>' +
      '<button class="co-btn ikincil" id="coKapat">Kapat</button>' +
      '<div class="co-durum" id="coOdulDurum"></div>'
    );
    var birim = ayar.birim || 'skor';
    k.querySelector('#coOdulMetin').textContent =
      skor + ' ' + birim + ' yaptın! Hakkını sadakat kartına işleyelim, tezgâhta göster ve limonatanı al.';
    k.querySelector('#coOdulTel').value = uyeTel || '';
    k.querySelector('#coKapat').addEventListener('click', function () { k.remove(); });

    var btn = k.querySelector('#coAl');
    var durum = k.querySelector('#coOdulDurum');
    btn.addEventListener('click', function () {
      var tel = telDuzelt(k.querySelector('#coOdulTel').value);
      if (tel.length !== 11) {
        durum.style.color = '#c0392b'; durum.textContent = 'Geçerli bir telefon numarası gir'; return;
      }
      btn.disabled = true;
      durum.style.color = '#5a5348'; durum.textContent = 'Gönderiliyor…';
      fetch(API + '/kart/oyun-odul', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ telefon: tel, oyun: ayar.oyun, skor: skor, sure: Math.round(sure || 0) })
      }).then(function (r) { return r.json(); }).then(function (j) {
        if (j.ok) {
          uyeKaydet(tel);
          durum.style.color = '#2d7a4f';
          durum.textContent = '✓ Limonata hakkın kartına işlendi. Tezgâhta göster.';
          btn.textContent = 'TANIMLANDI';
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
    });
  }

  /* ── Dışa açık API ── */
  global.CactusOdul = {
    kur: function (o) {
      ayar = o || {};
      var onbellek = onbellekOku();
      if (onbellek) uyeTel = onbellek;
      else if (document.body) kapiAc();
      else document.addEventListener('DOMContentLoaded', kapiAc);
    },

    /** Oyun bitince çağrılır. Eşik geçildiyse ödül kartını açar. */
    bitti: function (skor, sure) {
      if (!ayar || odulSunuldu) return;
      var gecti = ayar.tersYon ? (skor > 0 && skor <= ayar.esik) : (skor >= ayar.esik);
      if (!gecti) return;
      odulSunuldu = true;
      setTimeout(function () { odulAc(skor, sure); }, 700);
    },

    /** Başlık ekranlarında "X skor yap, limonata kazan" yazmak için. */
    esik: function () { return ayar ? ayar.esik : null; },
    uye: function () { return uyeTel; }
  };
})(window);
