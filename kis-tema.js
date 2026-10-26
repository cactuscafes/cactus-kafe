/* ═══ CACTUS KIŞ TEMASI — davranış ═══
 * site-ayarlar.js yükler ve window.KisTema.ac() / .kapat() çağırır.
 * Kapatınca her şey geri alınır (kar durur, metinler eski hâline döner), çünkü
 * önbellekteki tema ile sunucudaki ayar farklıysa sayfa açıkken değişebilir.
 */
(function () {
  if (window.KisTema) return;

  var SLOGAN = 'Kışın en sıcak köşesi';
  var ALT = '· SICAK İÇECEKLER, TAZE TATLILAR · BURSA’NIN KALBİNDE';
  var acik = false, durdur = [], kaktusGozcu = null;

  // ── Kar ──
  // Önceden çizilmiş yumuşak tane (radyal degrade) her karede ölçeklenerek basılır;
  // her tane için ayrı degrade kurmaktan çok daha ucuz.
  function taneSprite() {
    var s = document.createElement('canvas'); s.width = s.height = 32;
    var c = s.getContext('2d'), g = c.createRadialGradient(16, 16, 0, 16, 16, 16);
    g.addColorStop(0, 'rgba(255,255,255,1)');
    g.addColorStop(.45, 'rgba(255,255,255,.75)');
    g.addColorStop(1, 'rgba(255,255,255,0)');
    c.fillStyle = g; c.beginPath(); c.arc(16, 16, 16, 0, Math.PI * 2); c.fill();
    return s;
  }

  // kap: kar yağacak öğe · alanBasina: kaç px²'ye bir tane · tavan: en fazla tane
  function karYagdir(kap, alanBasina, tavan) {
    var cv = document.createElement('canvas');
    cv.className = 'kis-kar'; cv.setAttribute('aria-hidden', 'true');
    kap.insertBefore(cv, kap.firstChild);
    var ctx = cv.getContext('2d'), sprite = taneSprite();
    var dpr = Math.min(window.devicePixelRatio || 1, 2);
    var W = 0, H = 0, taneler = [], raf = 0, gorunur = true, son = 0;

    function yeni(ilk) {
      var z = Math.random();                 // derinlik: 0 uzak/küçük/yavaş, 1 yakın/büyük/hızlı
      return {
        x: Math.random() * W, y: ilk ? Math.random() * H : -8 - Math.random() * 40,
        r: 1.4 + z * z * 4.6, vy: 16 + z * 52, vx: (Math.random() - .5) * 8,
        faz: Math.random() * 6.283, sal: 6 + z * 16, a: .45 + z * .5
      };
    }
    function boyut() {
      W = kap.clientWidth; H = kap.clientHeight;
      cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var hedef = Math.min(tavan, Math.round(W * H / alanBasina));
      while (taneler.length < hedef) taneler.push(yeni(true));
      taneler.length = hedef;
    }
    function kare(t) {
      raf = 0;
      if (!gorunur || document.hidden) return;
      var dt = son ? Math.min((t - son) / 1000, .05) : 0; son = t;
      ctx.clearRect(0, 0, W, H);
      for (var i = 0; i < taneler.length; i++) {
        var f = taneler[i];
        f.faz += dt * .9;
        f.y += f.vy * dt;
        f.x += (f.vx + Math.sin(f.faz) * f.sal) * dt;
        if (f.y > H + 6) { taneler[i] = f = yeni(false); }
        if (f.x < -6) f.x = W + 6; else if (f.x > W + 6) f.x = -6;
        var d = f.r * 2;
        ctx.globalAlpha = f.a;
        ctx.drawImage(sprite, f.x - f.r, f.y - f.r, d, d);
      }
      ctx.globalAlpha = 1;
      iste();
    }
    function iste() { if (!raf && gorunur && !document.hidden) { raf = requestAnimationFrame(kare); } }

    boyut(); iste();
    var ro = window.ResizeObserver ? new ResizeObserver(boyut) : null;
    if (ro) ro.observe(kap); else window.addEventListener('resize', boyut);
    // Ekranda değilken çizme — pil ve işlemci boşa harcanmasın
    var io = window.IntersectionObserver ? new IntersectionObserver(function (e) {
      gorunur = e[0].isIntersecting; son = 0; iste();
    }) : null;
    if (io) io.observe(kap);
    function gorunurluk() { son = 0; iste(); }
    document.addEventListener('visibilitychange', gorunurluk);

    return function () {
      if (raf) cancelAnimationFrame(raf);
      if (ro) ro.disconnect(); else window.removeEventListener('resize', boyut);
      if (io) io.disconnect();
      document.removeEventListener('visibilitychange', gorunurluk);
      cv.remove();
    };
  }

  // ── Hero kar yığını ──
  function yiginEkle(hero) {
    var ns = 'http://www.w3.org/2000/svg', svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('class', 'kis-yigin'); svg.setAttribute('aria-hidden', 'true');
    svg.setAttribute('viewBox', '0 0 1440 64'); svg.setAttribute('preserveAspectRatio', 'none');
    svg.innerHTML =
      '<path fill="#cfe1e3" d="M0,30 C110,14 210,34 330,22 C450,10 560,30 690,20 C820,10 930,32 1060,18 C1180,6 1310,26 1440,14 L1440,64 L0,64 Z"/>' +
      '<path fill="#f4f8f8" d="M0,42 C140,26 260,46 400,34 C540,22 650,44 790,33 C930,22 1050,44 1190,31 C1300,21 1380,34 1440,28 L1440,64 L0,64 Z"/>';
    hero.appendChild(svg);
    return function () { svg.remove(); };
  }

  // ── Metin değişimi (eskisi saklanır, kapatınca geri döner) ──
  function metin(el, yeni, sinif) {
    if (!el) return function () {};
    var eski = el.textContent;
    el.textContent = yeni; if (sinif) el.classList.add(sinif);
    return function () { el.textContent = eski; if (sinif) el.classList.remove(sinif); };
  }

  // ── Yürüyen kaktüse bere + atkı ──
  // Menüdeki ikon sprite'ına kışlık bir kopya eklenir; kaktüs sahneye girince
  // <use> o kopyaya çevrilir. Menünün kendi koduna dokunulmaz.
  function kaktusGiydir() {
    var defs = document.querySelector('svg.cic-sprite defs');
    if (!defs || !document.getElementById('ci-cactus')) return function () {};
    if (!document.getElementById('ci-cactus-kis')) {
      var ns = 'http://www.w3.org/2000/svg', sym = document.createElementNS(ns, 'symbol');
      sym.setAttribute('id', 'ci-cactus-kis'); sym.setAttribute('viewBox', '0 0 48 48');
      sym.setAttribute('fill', 'none'); sym.setAttribute('stroke', 'currentColor');
      sym.setAttribute('stroke-width', '3'); sym.setAttribute('stroke-linecap', 'round');
      sym.setAttribute('stroke-linejoin', 'round');
      sym.innerHTML =
        '<path d="M18,40 L30,40 L28,46 L20,46 Z" stroke="#c9a86a"/>' +
        '<path d="M21,40 L21,17 Q21,11 24,11 Q27,11 27,17 L27,40"/>' +
        '<path d="M21,26 L16,26 Q13,26 13,22 L13,18"/>' +
        '<path d="M27,30 L33,30 Q36,30 36,26 L36,21"/>' +
        '<path d="M14,16 L11,16 M37,19 L40,19" stroke="#c9a86a" stroke-width="2"/>' +
        // atkı: boyun bandı + sağa sarkan uç, krem çizgili
        '<path d="M19.6,19 L28.4,19 L28.4,22.6 L19.6,22.6 Z" fill="#b8433a" stroke="none"/>' +
        '<path d="M26.4,21.6 L30.2,29.6 L27.6,30.6 L24.6,22.4 Z" fill="#b8433a" stroke="none"/>' +
        '<path d="M27.4,26.2 L29.6,25.4" stroke="#f4ecd8" stroke-width="1.1"/>' +
        // bere: kubbe + krem kenar + ponpon
        '<path d="M20.2,15.4 Q20.2,6.8 24,6.8 Q27.8,6.8 27.8,15.4 Z" fill="#b8433a" stroke="none"/>' +
        '<path d="M19.6,13.6 L28.4,13.6 L28.4,16.2 L19.6,16.2 Z" fill="#f4ecd8" stroke="none"/>' +
        '<circle cx="24" cy="5.6" r="2" fill="#f4ecd8" stroke="none"/>';
      defs.appendChild(sym);
    }
    function giydir(k) {
      var u = k && k.querySelector('use');
      if (u && u.getAttribute('href') === '#ci-cactus') u.setAttribute('href', '#ci-cactus-kis');
    }
    giydir(document.getElementById('absKaktus'));
    kaktusGozcu = new MutationObserver(function (ml) {
      for (var i = 0; i < ml.length; i++) for (var j = 0; j < ml[i].addedNodes.length; j++) {
        var n = ml[i].addedNodes[j]; if (n.id === 'absKaktus') giydir(n);
      }
    });
    kaktusGozcu.observe(document.body, { childList: true });
    return function () { if (kaktusGozcu) { kaktusGozcu.disconnect(); kaktusGozcu = null; } };
  }

  function ac() {
    if (acik || !document.body) return;
    acik = true;
    var hero = document.querySelector('section.hero');
    if (hero) {
      var mobil = window.innerWidth <= 768;
      durdur.push(karYagdir(hero, mobil ? 3600 : 4400, mobil ? 90 : 230));
      durdur.push(yiginEkle(hero));
      durdur.push(metin(hero.querySelector('.hero-tagline'), SLOGAN, 'kis-slogan'));
      durdur.push(metin(hero.querySelector('.hero-subtitle'), ALT));
    }
    var bant = document.querySelector('.sk-banner');
    if (bant) durdur.push(karYagdir(bant, 3200, 90));
    durdur.push(kaktusGiydir());
  }

  function kapat() {
    if (!acik) return;
    acik = false;
    while (durdur.length) { try { durdur.pop()(); } catch (e) {} }
  }

  window.KisTema = { ac: ac, kapat: kapat };
  if (document.documentElement.classList.contains('tema-kis')) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', ac);
    else ac();
  }
})();
