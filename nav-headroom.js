/* ═══ CACTUS — NAV HEADROOM ═══
 * Aşağı kaydırırken üst menü yukarı kayıp gizlenir, yukarı kaydırınca hemen geri gelir.
 * Amaç: telefonda okuma alanını büyütmek ama menüyü bir parmak hareketi uzakta tutmak.
 *
 * Kancalar (sayfada varsa kullanılır, yoksa sessizce atlanır):
 *   #mainNav        → gizlenen/gösterilen üst menü ("nav-gizli" sınıfı)
 *   #promoMarquee   → duyuru şeridi; nav gizlenince onun yerine tepeye yapışır
 *   #mainMobMenu    → tam ekran mobil menü; açıkken nav asla gizlenmez
 *   #mainBurger     → menüyü açan buton; basılınca nav geri gelir
 *
 * Not: hareket-azalt (prefers-reduced-motion) muafiyeti YOK — sahibin isteğiyle
 * sitedeki animasyonlar herkeste oynuyor, bu da onlardan biri.
 */
(function () {
  // Admin "Ana Sayfa" editörünün iframe'i içinde çalışma: editör iframe DOM'unu
  // GitHub'a kaydediyor, buradaki sınıf/stiller kaynak koda pişerdi.
  try { if (window.frameElement && window.frameElement.id === 'as-iframe') return; } catch (e) {}

  var nav = document.getElementById('mainNav');
  if (!nav) return;

  var mq  = document.getElementById('promoMarquee');
  var mob = document.getElementById('mainMobMenu');
  var brg = document.getElementById('mainBurger');

  var ESIK  = 120; // bu kadar kaydırılmadan gizleme yok (nav yüksekliği + pay)
  var DELTA = 6;   // titremeyi önleyen en küçük parmak hareketi (px)

  // Geçiş stilleri: index.html'deki #mainNav transition'ını ezmemek için
  // padding/background/box-shadow geçişleri burada da tekrarlanıyor.
  var st = document.createElement('style');
  st.textContent =
    '#mainNav{will-change:transform;transition:transform .38s cubic-bezier(.2,.7,.2,1),' +
    'padding .35s ease,background .35s ease,box-shadow .35s ease;}' +
    '#mainNav.nav-gizli{transform:translateY(-105%);}' +
    '#promoMarquee{transition:transform .38s cubic-bezier(.2,.7,.2,1);}';
  (document.head || document.documentElement).appendChild(st);

  var sonY = window.pageYOffset || 0, gizli = false, bekleyen = false;

  function mobAcik() {
    if (!mob) return false;
    var d = mob.style.display;
    return d ? d !== 'none' : getComputedStyle(mob).display !== 'none';
  }

  function goster() {
    if (!gizli) return;
    gizli = false;
    nav.classList.remove('nav-gizli');
    if (mq) mq.style.transform = '';
  }

  // Kaydırma payı bir ekrandan azsa headroom'a hiç girme: kısa sayfalarda
  // (ör. sadakat kartı) menü tam dipte kaybolur, kazanılan yer de olmaz.
  function kisaSayfa() {
    var d = document.documentElement;
    return (d.scrollHeight - window.innerHeight) < window.innerHeight;
  }

  function gizle() {
    if (gizli || mobAcik() || kisaSayfa()) return;
    gizli = true;
    nav.classList.add('nav-gizli');
    // Şerit navın boşalttığı yere kayar: duyuru görünür kalır, nav yer kaplamaz.
    if (mq) mq.style.transform = 'translateY(-' + nav.offsetHeight + 'px)';
  }

  function hesapla() {
    bekleyen = false;
    var y = window.pageYOffset || document.documentElement.scrollTop || 0;
    if (y < 0) y = 0; // iOS elastik kaydırma
    // Tepedeyken veya mobil menü açıkken nav hep açık
    if (y <= ESIK || mobAcik()) { sonY = y; goster(); return; }
    var fark = y - sonY;
    // Eşiğin altındaki hareketlerde sonY'yi güncelleme ki küçük kaydırmalar birikip
    // bir noktada gerçek bir karara dönüşsün.
    if (fark > -DELTA && fark < DELTA) return;
    if (fark > 0) gizle(); else goster();
    sonY = y;
  }

  function tetik() {
    if (bekleyen) return;
    bekleyen = true;
    requestAnimationFrame(hesapla);
  }

  window.addEventListener('scroll', tetik, { passive: true });
  window.addEventListener('resize', function () {
    if (gizli && mq) mq.style.transform = 'translateY(-' + nav.offsetHeight + 'px)';
  }, { passive: true });

  // Klavyeyle nava sekildiğinde, bağlantı hedefine atlandığında ve mobil menü
  // açılırken nav görünür olmalı.
  nav.addEventListener('focusin', goster);
  window.addEventListener('hashchange', goster);
  if (brg) brg.addEventListener('click', goster);

  // Geri/ileri (bfcache) dönüşünde durumu tazele
  window.addEventListener('pageshow', function () {
    sonY = window.pageYOffset || 0;
    goster();
  });
})();
