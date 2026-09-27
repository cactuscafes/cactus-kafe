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
 * ═══ 2026-09-28: TABELA İLE ÖDÜL AYRILDI ═══
 * Tabelaya girmek için AD yeter, telefon istenmiyor. Telefon yalnızca
 * limonata hakkı için. Sebep: numara isteyince rekorlar hiç yazılmıyordu —
 * oyuncu pencereyi kapatıyor, skor sessizce kayboluyordu ve tabela
 * haftalarca donuk kalıyordu. Sunucu tarafı: `ad` var + `telefon` yoksa
 * rekor yazılır, `odul:false` döner.
 *
 * Ödülün gerçek doğrulaması sunucuda — buradaki kontrol sadece kartı
 * gereksiz yere açmamak için.
 * ═══════════════════════════════════════════════════════════════ */
(function (global) {
  'use strict';

  var API = 'https://cactus-rapor-api.batuhanbulut.workers.dev';
  var UYE_ANAHTAR = 'cactus_oyun_uye';
  var AD_ANAHTAR = 'cactus_oyun_ad';       // bir kez sorulur, sonra hatırlanır
  var KUYRUK_ANAHTAR = 'cactus_oyun_kuyruk'; // çevrimdışı gönderilemeyenler
  var BAR_ANAHTAR = 'cactus_oyun_bar';     // son bilinen salon rekoru
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
      '.co-toast{position:fixed;left:50%;bottom:22px;transform:translateX(-50%);z-index:41;' +
      'max-width:min(92vw,420px);display:flex;gap:10px;align-items:center;justify-content:center;' +
      'flex-wrap:wrap;padding:13px 18px;border-radius:14px;background:#1A3310;color:#F7EFDE;' +
      'font-family:Montserrat,-apple-system,sans-serif;font-size:13px;line-height:1.45;text-align:center;' +
      'box-shadow:0 10px 30px rgba(0,0,0,.35);transition:opacity .55s;}' +
      '.co-toast.gizle{opacity:0;}' +
      '.co-toast-btn{border:1px solid rgba(247,239,222,.5);background:transparent;color:inherit;' +
      'font-family:inherit;font-size:12px;padding:7px 12px;border-radius:9px;cursor:pointer;}' +
      '.co-ek{font-size:12px;color:#8a8275;text-align:left;margin:4px 2px 6px;line-height:1.4;}' +
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

  /* ── Kalıcı küçük durumlar ──
     Üçü de localStorage'da: ad (bir kez sorulsun diye), kuyruk (çevrimdışı
     yapılan rekor kaybolmasın diye) ve son bilinen bar (ağ yokken açılan
     oyunda "rekor kırıldı mı" kararı verilebilsin diye). */
  function adOku() {
    try { return localStorage.getItem(AD_ANAHTAR) || null; } catch (e) { return null; }
  }
  function adKaydet(ad) {
    try { localStorage.setItem(AD_ANAHTAR, ad); } catch (e) {}
  }
  function barOku() {
    try {
      var v = JSON.parse(localStorage.getItem(BAR_ANAHTAR) || 'null');
      return (v && typeof v.skor === 'number') ? v : null;
    } catch (e) { return null; }
  }
  function barKaydet(r) {
    try { localStorage.setItem(BAR_ANAHTAR, JSON.stringify({ skor: r.skor, ad: r.ad, taban: r.taban })); } catch (e) {}
  }
  function kuyrukOku() {
    try { var v = JSON.parse(localStorage.getItem(KUYRUK_ANAHTAR) || '[]'); return v.length ? v : []; }
    catch (e) { return []; }
  }
  function kuyrukYaz(l) {
    try { localStorage.setItem(KUYRUK_ANAHTAR, JSON.stringify(l.slice(-20))); } catch (e) {}
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
          barKaydet(j);   // ağ olmadan açılan oyun da barı bilsin
          if (rekorDinleyici) rekorDinleyici(j);
        }
        return rekor;
      })
      .catch(function () { return null; });   // ağ yoksa oyun yine oynanır
  }

  /* ── Gönderim ──
     TEK nokta: hem karttan hem otomatik yoldan buradan geçiliyor. Sonucu üç
     hâlde döndürüyor çünkü çağıranların davranışı farklı:
       'ok'  → yazıldı
       'ret' → sunucu reddetti (bar altı, süre, sıçrama). Kuyruğa ALINMAZ:
               tekrar denemek aynı cevabı verir, kuyruk şişer.
       'ag'  → ağ yok / sunucuya ulaşılamadı. Kuyruğa alınır.
     Bu ayrım olmadan çevrimdışı rekor ya kaybolur ya da sonsuza dek
     yeniden denenir. */
  function sunucuyaGonder(govde) {
    return fetch(API + '/kart/oyun-odul', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(govde)
    }).then(function (r) {
      return r.json().then(function (j) {
        return { durum: j && j.ok ? 'ok' : 'ret', j: j || {} };
      });
    }).catch(function () {
      return { durum: 'ag', j: {} };
    });
  }

  /* Rekor yazıldıysa tabelayı yerel olarak da ilerlet — aynı oturumda tekrar
     oynayan oyuncu eski barı görmesin. */
  function rekoruIlerlet(j) {
    rekor = { ok: true, oyun: ayar.oyun, skor: j.skor, ad: j.ad,
              taban: rekor ? rekor.taban : j.skor, aktif: true };
    barKaydet(rekor);
    if (rekorDinleyici) rekorDinleyici(rekor);
  }

  function kuyrugaEkle(govde) {
    var l = kuyrukOku();
    l.push(govde);
    kuyrukYaz(l);
  }

  /* Bekleyen rekorları sırayla gönderir. Ağ hâlâ yoksa sırada kalırlar.
     Sunucu reddederse (araya başkası girip barı geçmiş olabilir) satır
     düşürülür — o rekor artık gerçekten geçersiz. */
  function kuyrukBosalt() {
    var l = kuyrukOku();
    if (!l.length) return Promise.resolve(0);
    var kalan = [], yazilan = 0;
    return l.reduce(function (zincir, g) {
      return zincir.then(function () {
        return sunucuyaGonder(g).then(function (s) {
          if (s.durum === 'ok') { yazilan++; rekoruIlerlet(s.j); }
          else if (s.durum === 'ag') kalan.push(g);
          // 'ret' → sessizce düşür
        });
      });
    }, Promise.resolve()).then(function () {
      kuyrukYaz(kalan);
      if (yazilan) toast('🏆 Çevrimdışı yaptığın rekor tabelaya yazıldı.');
      return yazilan;
    });
  }

  /* ── Küçük bildirim ── */
  function toast(metin, eylem) {
    stilEkle();
    var d = document.createElement('div');
    d.className = 'co-toast';
    d.textContent = metin;
    if (eylem) {
      var a2 = document.createElement('button');
      a2.className = 'co-toast-btn';
      a2.textContent = eylem.yazi;
      a2.addEventListener('click', function () { d.remove(); eylem.calistir(); });
      d.appendChild(a2);
    }
    document.body.appendChild(d);
    setTimeout(function () { d.classList.add('gizle'); }, eylem ? 9000 : 5000);
    setTimeout(function () { d.remove(); }, eylem ? 9600 : 5600);
  }

  /* Ad biliniyorsa pencere açmadan gönderir. Ağ yoksa kuyruğa alır ve barı
     yerel olarak ilerletir — oyuncu çevrimdışı 50 yaptıysa hedefi 51 olmalı,
     47 değil. */
  function otomatikGonder(skor, sure, ad) {
    var govde = { oyun: ayar.oyun, skor: skor, sure: Math.round(sure || 0), ad: ad };
    var tel = uyeTel || onbellekOku();
    if (tel) govde.telefon = tel;

    sunucuyaGonder(govde).then(function (s) {
      if (s.durum === 'ok') {
        rekoruIlerlet(s.j);
        toast(s.j.mesaj || '🏆 Rekor senin! Tabelaya yazıldı.',
              s.j.odul ? null : { yazi: 'Limonata hakkı', calistir: function () { odulAc(skor, sure); } });
        return;
      }
      if (s.durum === 'ag') {
        kuyrugaEkle(govde);
        rekoruIlerlet({ skor: skor, ad: ad });
        toast('📴 İnternet yok — ' + skor + ' kaydedildi, bağlanınca tabelaya yazılacak.');
        return;
      }
      /* Numara önbellekte ama sadakat kaydı yoksa sunucu `kayitGerek` diyor.
         Bu durumda rekoru DÜŞÜRMEK yanlış olur: numarayı atıp adla tekrar
         gönderiyoruz, tabela her hâlükârda doğru kalsın. */
      if (s.j.kayitGerek && govde.telefon) {
        delete govde.telefon;
        sunucuyaGonder(govde).then(function (s2) {
          if (s2.durum === 'ok') {
            rekoruIlerlet(s2.j);
            toast(s2.j.mesaj || '🏆 Rekor tabelaya yazıldı.',
                  { yazi: 'Limonata hakkı', calistir: function () { odulAc(skor, sure); } });
          } else if (s2.durum === 'ag') {
            kuyrugaEkle(govde); rekoruIlerlet({ skor: skor, ad: ad });
            toast('📴 İnternet yok — rekorun kaydedildi.');
          }
        });
        return;
      }
      if (s.j.error) toast(s.j.error);
    });
  }

  /* ── Ödül ── */
  /* Kartın iki ayrı işi var ve 28 Eylül 2026'da bunlar AYRILDI:
       1) Tabelaya yazmak  → yalnızca AD yeter.
       2) Limonata hakkı   → sadakat kartı, yani TELEFON gerekir.
     Eskiden ikisi tek kapıya bağlıydı: numara vermeyen oyuncunun rekoru hiç
     yazılmıyordu. Sonuç, tabelanın haftalarca donuk kalmasıydı — oyuncu
     pencereyi kapatıyor, skor sessizce kayboluyordu. Tabelanın doğru olması
     kimin yaptığını bilmekten daha önemli. */
  function odulAc(skor, sure) {
    stilEkle();
    var k = kat(
      '<div class="co-ikon">🏆</div>' +
      '<div class="co-bas">Rekoru kırdın!</div>' +
      '<div class="co-metin" id="coOdulMetin"></div>' +
      '<input class="co-tel" id="coOdulAd" type="text" maxlength="40" placeholder="Adın Soyadın" autocomplete="name">' +
      '<div class="co-ek" id="coEkBaslik">İstersen numaranı da ekle — limonata hakkın kartına işlensin.</div>' +
      '<input class="co-tel" id="coOdulTel" type="tel" inputmode="numeric" maxlength="11" placeholder="05XX XXX XX XX (isteğe bağlı)">' +
      '<div id="coOnayYuva"></div>' +
      '<button class="co-btn" id="coAl">TABELAYA YAZ</button>' +
      '<button class="co-btn ikincil" id="coKapat">Kapat</button>' +
      '<div class="co-durum" id="coOdulDurum"></div>'
    );
    var eski = rekor ? rekor.skor : null;
    k.querySelector('#coOdulMetin').textContent =
      skor + ' yaptın' + (eski ? ' — eski rekor ' + eski + '.' : '.') +
      ' Adını yaz, rekor tabelasına geçsin.';
    k.querySelector('#coOdulTel').value = uyeTel || '';
    k.querySelector('#coKapat').addEventListener('click', function () { k.remove(); });
    k.querySelector('#coOdulAd').focus();

    var btn = k.querySelector('#coAl');
    var durum = k.querySelector('#coOdulDurum');
    var kayitModu = false;      // sunucu "önce kaydol" dediyse true

    function basarili(j) {
      // Yalnızca gerçek bir numara varsa önbelleğe al. Adla giren oyuncuda
      // telefon yok; null yazarsak bir sonraki oyunda alana "null" düşer.
      var tel = telDuzelt(k.querySelector('#coOdulTel').value);
      if (tel.length === 11) uyeKaydet(tel);
      // Ad BİR KEZ sorulur: bundan sonraki rekorlar pencere açmadan gider.
      adKaydet((k.querySelector('#coOdulAd').value || '').trim());
      rekoruIlerlet(j);
      durum.style.color = j.odul ? '#2d7a4f' : '#8a6a2a';
      durum.textContent = j.mesaj || '✓ İşlendi.';
      btn.textContent = j.odul ? 'TANIMLANDI' : 'REKOR YAZILDI';
      btn.disabled = true;
    }

    /* Sunucuya gönder. `tel` boşsa telefon alanı HİÇ gönderilmez; sunucu bunu
       "adla giriş" sayıp rekoru yazar, limonatayı vermez. */
    function odulGonder(tel, ad) {
      var govde = { oyun: ayar.oyun, skor: skor, sure: Math.round(sure || 0), ad: ad };
      if (tel) govde.telefon = tel;
      return sunucuyaGonder(govde).then(function (s) {
        if (s.durum === 'ok') { basarili(s.j); return; }
        if (s.durum === 'ag') {
          // Ağ yoksa kart kapansın diye değil, rekor kaybolmasın diye:
          // kuyruğa al, bağlanınca kendiliğinden gidecek.
          adKaydet(ad); kuyrugaEkle(govde); rekoruIlerlet({ skor: skor, ad: ad });
          durum.style.color = '#8a6a2a';
          durum.textContent = '📴 İnternet yok — rekorun kaydedildi, bağlanınca yazılacak.';
          btn.textContent = 'KUYRUĞA ALINDI'; btn.disabled = true;
          return;
        }
        if (s.j.kayitGerek) { kayitAlaniAc(s.j.error); return; }
        durum.style.color = '#c0392b';
        durum.textContent = s.j.error || 'İşlenemedi';
        btn.disabled = false;
      });
    }

    /* Numara girildi ama sadakat kartında yok: KVKK onayını burada alıp
       kaydı açıyoruz, sonra aynı skoru tekrar gönderiyoruz. Oyuncuyu
       "git kaydol, sonra gel" diye göndermek rekorun kaybolması demekti. */
    function kayitAlaniAc(mesaj) {
      kayitModu = true;
      durum.style.color = '#8a6a2a';
      durum.textContent = mesaj || 'Limonata hakkı için bir kerelik kaydolman gerekiyor.';
      btn.textContent = 'KAYDOL VE LİMONATAYI AL';
      btn.disabled = false;
      if (k.querySelector('#coOdulKvkk')) return;
      var onay = document.createElement('label');
      onay.className = 'co-onay';
      onay.innerHTML = '<input type="checkbox" id="coOdulKvkk"> Sadakat kartı için ' +
        'adım ve numaramın saklanmasını kabul ediyorum.';
      k.querySelector('#coOnayYuva').appendChild(onay);
    }

    btn.addEventListener('click', function () {
      var ad = (k.querySelector('#coOdulAd').value || '').trim();
      var tel = telDuzelt(k.querySelector('#coOdulTel').value);
      if (ad.length < 2) {
        durum.style.color = '#c0392b'; durum.textContent = 'Adını yaz'; return;
      }
      // Numara ya boş bırakılır ya da tam girilir; yarım numara sessizce
      // yok sayılırsa oyuncu limonatayı bekler ve gelmez.
      if (tel.length && tel.length !== 11) {
        durum.style.color = '#c0392b';
        durum.textContent = 'Numarayı ya tam gir ya da boş bırak';
        return;
      }
      btn.disabled = true;
      durum.style.color = '#5a5348';

      if (!kayitModu) {
        durum.textContent = 'Gönderiliyor…';
        odulGonder(tel, ad);
        return;
      }
      if (!k.querySelector('#coOdulKvkk').checked) {
        durum.style.color = '#c0392b';
        durum.textContent = 'Kaydolmak için onay kutusunu işaretle';
        btn.disabled = false; return;
      }
      durum.textContent = 'Kaydediliyor…';
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
        return odulGonder(tel, ad);
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

      /* Önce diskteki bar: ağ yavaşsa ya da yoksa oyuncu ilk turunu barı
         bilmeden oynamasın, çünkü bar bilinmezse rekor kırıldığı anlaşılamaz
         ve skor hiç gönderilmez. Sunucudan gelen değer birazdan üstüne yazar. */
      var eski = barOku();
      if (eski) {
        rekor = { ok: true, oyun: ayar.oyun, skor: eski.skor, ad: eski.ad,
                  taban: eski.taban, aktif: true };
        if (rekorDinleyici) rekorDinleyici(rekor);
      }
      rekorCek();

      /* Çevrimdışıyken yapılan rekorlar burada ve ağ geri gelince gider.
         Böylece oyuncu "interneti kapatıp 50 yaptım" dediğinde, bağlandığı
         an tabelaya düşüyor ve herkes görüyor. */
      kuyrukBosalt();
      if (!global.__cactusOdulOnline) {
        global.__cactusOdulOnline = true;
        global.addEventListener('online', function () { kuyrukBosalt(); });
        // Bazı tarayıcılarda 'online' gelmiyor; sekmeye dönüşte de dene.
        document.addEventListener('visibilitychange', function () {
          if (!document.hidden) { kuyrukBosalt(); rekorCek(); }
        });
      }
    },

    /** Bekleyen çevrimdışı rekorları elle göndermek için. */
    kuyruguGonder: function () { return kuyrukBosalt(); },

    /** Oyun bitince çağrılır. Rekor kırıldıysa ödül kartını açar. */
    bitti: function (skor, sure) {
      if (!ayar) return;
      /* Bar: önce sunucudan gelen, yoksa diskteki son bilinen. Eskiden
         rekor yoksa hiçbir şey yapılmıyordu — çevrimdışı açılan oyunda
         rekor kırılsa bile skor kayboluyordu. */
      var r = rekor || barOku();
      if (!r || r.aktif === false) return;
      if (skor <= r.skor) return;
      // Sunucunun süre alt sınırıyla aynı mantık — buradan geçemeyecek bir
      // skoru "kazandın" diye göstermeyelim.
      if (sure < skor * 0.8) return;

      /* ADI BİLİNMİYORSA bir kez sor. Bildikten sonra bir daha sorulmaz:
         her rekor kendiliğinden gider ve tabelada herkese görünür. */
      var ad = adOku();
      if (!ad) {
        if (odulSunuldu) return;   // aynı oturumda kartı tekrar tekrar açma
        odulSunuldu = true;
        setTimeout(function () { odulAc(skor, sure); }, 700);
        return;
      }
      otomatikGonder(skor, sure, ad);
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
