/* ═══ CACTUS SİTE AYARLARI — tek doğruluk kaynağı ═══
 * Admin panelindeki "⚙️ Site Ayarları" bölümünden yönetilen değerleri
 * (çalışma saatleri, duyuru şeridi, kampanya popup'ları, Google puanları, telefon)
 * /ayar/cek'ten çekip sayfadaki data-ayar kancalarına uygular.
 *
 * API erişilemezse HİÇBİR ŞEY yapmaz — sayfadaki gömülü değerler (bugünkü hal) kalır.
 * Sayfalar window.CACTUS_AYAR_P (Promise) üzerinden popup kararlarını bekleyebilir.
 *
 * Kancalar:
 *   data-ayar="tel"               → telefon metni (+ <a> ise tel: href)
 *   data-ayar="saat-fsm|podyum"   → "Her gün <b>11:00 – 00:00</b>" biçimli saat metni
 *   data-ayar="puan-fsm|podyum"   → Google puanı (4.8)
 *   data-ayar="yorum-fsm|podyum"  → "218 Google yorumu"
 *   .acik-rozet[data-branch]      → "Şu an açık/kapalı" (saatlerden hesaplanır)
 *   #promoMarquee + .pm-seg       → duyuru şeridi (şube window.__INITIAL_SUBE'den)
 */
(function () {
  // Admin "Ana Sayfa" editörünün iframe'i içinde ÇALIŞMA: editör iframe DOM'unu
  // GitHub'a kaydediyor — burada uygulanan canlı değerler kaynak koda pişerdi.
  try { if (window.frameElement && window.frameElement.id === 'as-iframe') return; } catch (e) {}
  var API = 'https://cactus-rapor-api.batuhanbulut.workers.dev';

  // Basit vurgu: *italik* → <em>, **kalın** → <strong>, satır sonu → <br> (önce HTML kaçışı)
  function md(s) {
    s = String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    return s.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
            .replace(/\*([^*]+)\*/g, '<em>$1</em>')
            .replace(/\n/g, '<br>');
  }
  function dk(hhmm) { // "11:00" → dakika
    var p = String(hhmm || '').split(':');
    return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0);
  }
  function aralik(s) { // {ac,kap} → [acDk, kapDk] (gece yarısını aşan kapanış +1440)
    var a = dk(s[0]), k = dk(s[1]);
    if (k <= a) k += 1440;
    return [a, k];
  }
  function saatAralik(sube, g) { // g: 0=Paz..6=Cmt
    var haftaSonu = (g === 0 || g === 6);
    return haftaSonu ? aralik([sube.hs_ac, sube.hs_kap]) : aralik([sube.hi_ac, sube.hi_kap]);
  }
  function acikMi(sube) {
    var now = new Date();
    var tr = new Date(now.getTime() + (now.getTimezoneOffset() + 180) * 60000);
    var g = tr.getDay(), dkNow = tr.getHours() * 60 + tr.getMinutes();
    var bug = saatAralik(sube, g);
    if (dkNow >= bug[0] && dkNow < bug[1]) return true;
    var dun = saatAralik(sube, (g + 6) % 7);
    if (dun[1] > 1440 && dkNow < (dun[1] - 1440)) return true;
    return false;
  }
  function saatMetni(s) { // "Her gün <b>…</b>" ya da "Hafta içi <b>…</b> · Hafta sonu <b>…</b>"
    var hi = s.hi_ac + ' – ' + s.hi_kap, hs = s.hs_ac + ' – ' + s.hs_kap;
    if (hi === hs) return 'Her gün <b>' + hi + '</b>';
    return 'Hafta içi <b>' + hi + '</b> · Hafta sonu <b>' + hs + '</b>';
  }
  function telHref(t) { // "0538 014 66 00" → "tel:+905380146600"
    var d = String(t || '').replace(/\D/g, '');
    if (d.charAt(0) === '0') d = d.slice(1);
    return 'tel:+90' + d;
  }

  function uygula(a) {
    if (!a) return;
    try {
      // ── Telefon ──
      if (a.telefon) {
        document.querySelectorAll('[data-ayar="tel"]').forEach(function (el) {
          // İkon vb. baştaki metni koru: "📞 0538 …" biçimini yakala
          var m = (el.textContent || '').match(/^([^\d]*)/);
          el.textContent = (m ? m[1] : '') + a.telefon;
          if (el.tagName === 'A') el.setAttribute('href', telHref(a.telefon));
        });
      }
      // ── Saat metinleri ──
      if (a.saatler) {
        ['fsm', 'podyum'].forEach(function (b) {
          if (!a.saatler[b]) return;
          document.querySelectorAll('[data-ayar="saat-' + b + '"]').forEach(function (el) {
            el.innerHTML = saatMetni(a.saatler[b]);
          });
        });
      }
      // ── Google puanları ──
      if (a.puan) {
        ['fsm', 'podyum'].forEach(function (b) {
          if (!a.puan[b]) return;
          document.querySelectorAll('[data-ayar="puan-' + b + '"]').forEach(function (el) { el.textContent = a.puan[b].puan; });
          document.querySelectorAll('[data-ayar="yorum-' + b + '"]').forEach(function (el) { el.textContent = a.puan[b].yorum + ' Google yorumu'; });
        });
      }
      // ── Açık/kapalı rozetleri ──
      if (a.saatler) {
        var rozetTick = function () {
          document.querySelectorAll('.acik-rozet[data-branch]').forEach(function (el) {
            var s = a.saatler[el.getAttribute('data-branch')];
            if (!s) return;
            var ac = acikMi(s);
            el.textContent = ac ? 'Şu an açık' : 'Şu an kapalı';
            el.classList.toggle('acik', ac);
            el.classList.toggle('kapali', !ac);
          });
        };
        rozetTick();
        setInterval(rozetTick, 60000);
        window.__ayarRozetAktif = true; // sayfadaki eski gömülü rozet script'i bunu görünce devreye girmez
      }
      // ── Duyuru şeridi (menü sayfaları) ──
      var mq = document.getElementById('promoMarquee');
      var sube = (window.__INITIAL_SUBE === 'podyum') ? 'podyum' : 'fsm';
      if (mq && a.serit && a.serit[sube]) {
        var st = a.serit[sube];
        if (st.acik === false) {
          mq.style.display = 'none';
          document.body.style.paddingTop = '';
        } else if (st.metin) {
          var seg = st.metin + '   ✦   ';
          mq.querySelectorAll('.pm-seg').forEach(function (el) { el.textContent = seg; });
        }
      }
      // ── FSM çay/ikram popup içeriği (görünürlük kararı sayfadaki tetikte) ──
      if (a.popup_fsm) {
        var p = document.getElementById('isBasvuruPop');
        if (p) {
          var eb = p.querySelector('.ib-eyebrow'), tt = p.querySelector('.ib-title'), sb = p.querySelector('.ib-sub');
          if (eb && a.popup_fsm.eyebrow) eb.textContent = a.popup_fsm.eyebrow;
          if (tt && a.popup_fsm.baslik) tt.innerHTML = md(a.popup_fsm.baslik);
          if (sb && a.popup_fsm.metin) sb.innerHTML = md(a.popup_fsm.metin);
        }
      }
      // ── Podyum kampanya popup içeriği ──
      if (a.popup_podyum) {
        var kb = document.getElementById('kampanyaBg');
        if (kb) {
          var ke = kb.querySelector('.kampanya-eyebrow'), kt = kb.querySelector('.kampanya-title'),
              kf = kb.querySelector('.kampanya-price'), ks = kb.querySelector('.kampanya-sub'),
              kn = kb.querySelector('.kampanya-note');
          if (ke && a.popup_podyum.eyebrow) ke.textContent = a.popup_podyum.eyebrow;
          if (kt && a.popup_podyum.baslik) kt.innerHTML = md(a.popup_podyum.baslik);
          if (kf && a.popup_podyum.fiyat) kf.innerHTML = md(String(a.popup_podyum.fiyat)) + '<small>₺</small>';
          if (ks && a.popup_podyum.metin) ks.innerHTML = md(a.popup_podyum.metin);
          if (kn && a.popup_podyum.not) kn.textContent = a.popup_podyum.not;
        }
      }
      // ── schema.org JSON-LD (ana sayfa): saat + telefon tazele ──
      try {
        var ld = document.querySelector('script[type="application/ld+json"]');
        if (ld && a.saatler) {
          var j = JSON.parse(ld.textContent);
          (j['@graph'] || []).forEach(function (n) {
            var b = (n['@id'] || '').indexOf('podyum') >= 0 ? 'podyum' : 'fsm';
            var s = a.saatler[b];
            if (!s) return;
            if (a.telefon) n.telephone = '+90 ' + String(a.telefon).replace(/^0/, '');
            var gunler = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
            var hafta = [{ '@type': 'OpeningHoursSpecification', dayOfWeek: gunler, opens: s.hi_ac, closes: s.hi_kap }];
            if (s.hi_ac === s.hs_ac && s.hi_kap === s.hs_kap) {
              hafta[0].dayOfWeek = gunler.concat(['Saturday', 'Sunday']);
            } else {
              hafta.push({ '@type': 'OpeningHoursSpecification', dayOfWeek: ['Saturday', 'Sunday'], opens: s.hs_ac, closes: s.hs_kap });
            }
            n.openingHoursSpecification = hafta;
          });
          ld.textContent = JSON.stringify(j);
        }
      } catch (e) {}
    } catch (e) {}
    return a;
  }

  function basla(a) {
    if (document.readyState === 'loading') {
      return new Promise(function (res) {
        document.addEventListener('DOMContentLoaded', function () { res(uygula(a)); });
      });
    }
    return uygula(a);
  }

  window.CACTUS_AYAR_P = fetch(API + '/ayar/cek?t=' + Date.now())
    .then(function (r) { return r.ok ? r.json() : null; })
    .then(function (a) { window.CACTUS_AYAR = a; return basla(a); })
    .catch(function () { return null; });
})();
