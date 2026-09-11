/**
 * admin.html'i SAHTE VERİYLE render eder.
 *
 * NEDEN: admin paneli kimlik doğrulamadan sonra JS ile kuruluyor ve verisini
 * Worker API'sinden çekiyor. Giriş ekranı yüzünden panelin kendisi hiç
 * denetlenemiyordu — kontrast taraması "0 sorun" diyordu ama ölçülecek bir şey
 * yoktu (görünür 1 öge, metin taşıyan 0).
 *
 * YAKLAŞIM: üretim kodu DEĞİŞMEZ. Ne admin.html'e test bayrağı eklenir, ne de
 * giriş kapısına arka kapı açılır. Her şey tarayıcı tarafında:
 *   1. localStorage'a sahte token konur  -> giriş katmanı hiç görünmez
 *   2. API istekleri yakalanıp sahte JSON döndürülür
 * Parola ne bilinir ne gerekir.
 *
 * KULLANIM:
 *   npm i -D playwright            (bir kez)
 *   python3 -m http.server 8788 &  (ya da kendi sunucun)
 *   node test/admin-onizleme.js                 # hepsi
 *   node test/admin-onizleme.js --shot panel.png
 *   node test/admin-onizleme.js --denetim       # yalnızca kontrast
 */
const { chromium } = require('playwright');
const path = require('path');

const TABAN   = process.env.TABAN || 'http://127.0.0.1:8788';
const SAYFA   = process.env.SAYFA || 'admin.html';
// Kendi makinende boş bırak: Playwright kendi indirdiği tarayıcıyı bulur.
// Yalnızca özel bir tarayıcı gerekiyorsa KROM=/yol/chrome ver.
const KROM    = process.env.KROM || null;
const TKEY    = 'cactus_yonetim_token';

// ── Sahte veri ──────────────────────────────────────────────────────────────
// /islem/listele'nin şekli admin.html:2342 _islemToRapor()'dan okundu.
const URUNLER = [
  { ad: 'Latte',            adet: 3, fiyat: 95,  tip: 'icecek'  },
  { ad: 'Filtre Kahve',     adet: 2, fiyat: 80,  tip: 'icecek'  },
  { ad: 'Bubble Waffle',    adet: 1, fiyat: 240, tip: 'yiyecek' },
  { ad: 'San Sebastian',    adet: 2, fiyat: 180, tip: 'yiyecek' },
  { ad: 'Limonata',         adet: 4, fiyat: 70,  tip: 'icecek'  },
];
function islemler(gunSayisi = 7, gunlukAdet = 6) {
  const out = [];
  for (let g = 0; g < gunSayisi; g++) {
    const d = new Date(Date.now() - g * 864e5);
    const iso = d.toISOString().slice(0, 10);
    for (let i = 0; i < gunlukAdet; i++) {
      const det = URUNLER.slice(0, 2 + ((g + i) % 4));
      const toplam = det.reduce((t, u) => t + u.adet * u.fiyat, 0);
      const nakit = i % 3 === 0 ? toplam : 0;
      out.push({
        id: `${iso}-${i}`, tarih_iso: iso,
        tarih: d.toLocaleDateString('tr-TR'),
        toplam, nakit_tutar: nakit, kart_tutar: toplam - nakit,
        odeme_tipi: nakit ? 'nakit' : 'kart',
        masa: 1 + (i % 12), urun_detay: det,
      });
    }
  }
  return out;
}
const SAHTE = [
  [/\/auth\/login/,      () => ({ ok: true, token: 'test', exp: Date.now() + 864e5 })],
  [/\/islem\/listele/,   () => islemler()],
  [/\/menu\/cek/,        () => ({ ok: true, menu: { kategoriler: [] } })],
  [/\/ayar\/cek/,        () => ({ ok: true, ayar: { telefon: '0538 014 66 00' } })],
  [/\/sync\/durum/,      () => ({ ok: true, masalar: {}, guncelleme: Date.now() })],
  [/api\.github\.com/,   () => ({ content: Buffer.from('<!-- test -->').toString('base64'),
                                  sha: 'test', encoding: 'base64' })],
  [/raw\.githubusercontent\.com/, () => '<!-- test -->'],
  // Aşağıdakiler ilk koşuda gözlemlendi (yakalanan istek listesinden):
  [/\/basvuru\/listele/,  () => []],
  [/\/sikayet\/listele/,  () => []],
  [/\/kart\/listele/,     () => []],
  [/\/api\/events/,       () => []],
];
function sahteYanit(url) {
  for (const [desen, uret] of SAHTE) if (desen.test(url)) return uret();
  // Tanınmayan uç nokta: BOŞ DİZİ. Obje döndürmek liste bekleyen yerlerde
  // "(r[0]||[]).filter is not a function" ile render'ı yarıda kesiyordu.
  return [];
}

// ── Kontrast (alfa kompozitli) ──────────────────────────────────────────────
const DENETIM = `(() => {
  const par=c=>{const m=(c||'').match(/[\\d.]+/g); return m?{r:+m[0],g:+m[1],b:+m[2],a:m.length>3?+m[3]:1}:null;};
  const ust=(f,bg)=>({r:f.r*f.a+bg.r*(1-f.a),g:f.g*f.a+bg.g*(1-f.a),b:f.b*f.a+bg.b*(1-f.a),a:1});
  const lum=c=>{const [r,g,b]=[c.r,c.g,c.b].map(v=>{v/=255;return v<=.03928?v/12.92:Math.pow((v+.055)/1.055,2.4)});
    return .2126*r+.7152*g+.0722*b;};
  const cr=(x,y)=>{const [h,l]=[lum(x),lum(y)].sort((m,n)=>n-m); return (h+.05)/(l+.05);};
  const zemin=el=>{const kat=[]; let n=el;
    while(n&&n.nodeType===1){const s=getComputedStyle(n);
      if(s.backgroundImage&&s.backgroundImage!=='none') return null;
      const c=par(s.backgroundColor); if(c&&c.a>0) kat.push(c);
      if(c&&c.a===1) break; n=n.parentElement;}
    let acc={r:255,g:255,b:255,a:1};
    for(let i=kat.length-1;i>=0;i--) acc=ust(kat[i],acc); return acc;};
  const kotu=[]; let olculen=0;
  document.querySelectorAll('body *').forEach(el=>{
    if(el.children.length) return;
    const t=(el.textContent||'').trim(); if(!t) return;
    const s=getComputedStyle(el);
    if(s.display==='none'||s.visibility==='hidden'||+s.opacity<.5) return;
    if(el.disabled||el.closest('[disabled]')) return;              // WCAG 1.4.3 muaf
    const r=el.getBoundingClientRect(); if(r.width<3||r.height<3) return;
    if(/^[\\p{Emoji}\\p{Extended_Pictographic}\\s·★⭐→←⇄↔₺|]+$/u.test(t)) return;
    const bg=zemin(el); if(!bg) return;
    let fg=par(s.color); if(!fg) return; if(fg.a<1) fg=ust(fg,bg);
    olculen++;
    const px=parseFloat(s.fontSize);
    const esik=(px>=24||(px>=18.66&&+s.fontWeight>=700))?3:4.5;
    const o=cr(fg,bg);
    if(o<esik) kotu.push({t:t.slice(0,26),c:s.color,b:\`rgb(\${bg.r|0}, \${bg.g|0}, \${bg.b|0})\`,
                          o:+o.toFixed(2),px:Math.round(px),esik});
  });
  const g=new Set(), tekil=[];
  kotu.forEach(k=>{const a=k.c+'|'+k.b; if(!g.has(a)){g.add(a);tekil.push(k);}});
  return {olculen, adet:kotu.length, tekil:tekil.sort((x,y)=>x.o-y.o).slice(0,12)};
})()`;

(async () => {
  const arg = process.argv.slice(2);
  const shotIdx = arg.indexOf('--shot');
  const shot = shotIdx >= 0 ? (arg[shotIdx + 1] || 'admin-panel.png') : null;
  const yalnizDenetim = arg.includes('--denetim');

  const b = await chromium.launch(KROM ? { executablePath: KROM } : {});
  const p = await b.newPage({ viewport: { width: 1440, height: 1200 } });

  // 1) Giriş kapısını sahte token ile geç — parola bilmeye gerek yok
  await p.addInitScript(([k, v]) => localStorage.setItem(k, v),
    [TKEY, JSON.stringify({ token: 'test', exp: Date.now() + 864e5 })]);

  // 2) Dış istekleri yakala
  const yakalanan = [];
  await p.route('**/*', route => {
    const url = route.request().url();
    if (url.startsWith(TABAN)) return route.continue();          // yerel dosyalar
    if (/fonts\.(googleapis|gstatic)/.test(url)) return route.abort();
    yakalanan.push(url.replace(/^https?:\/\//, '').slice(0, 68));
    const govde = sahteYanit(url);
    route.fulfill({
      status: 200,
      contentType: typeof govde === 'string' ? 'text/plain' : 'application/json',
      headers: { 'access-control-allow-origin': '*' },
      body: typeof govde === 'string' ? govde : JSON.stringify(govde),
    });
  });

  const hatalar = [];
  p.on('pageerror', e => hatalar.push('JS: ' + e.message.slice(0, 90)));
  p.on('console', m => { if (m.type() === 'error') hatalar.push('konsol: ' + m.text().slice(0, 90)); });

  await p.goto(`${TABAN}/${SAYFA}`, { waitUntil: 'load', timeout: 30000 });
  // Panel iskeletle açılıp veriyle doluyor. Sabit bir bekleme yetmiyor —
  // yarı yüklü sayfada ölçüm yanıltıcı olur (ilk koşuda görüldü: iskelet
  // haldeyken de "40 öge" sayıldı). Metin öge sayısı DURULANA kadar bekle.
  let onceki = -1, sabit = 0;
  for (let i = 0; i < 40 && sabit < 3; i++) {
    await p.waitForTimeout(400);
    const say = await p.evaluate(() => [...document.querySelectorAll('body *')]
      .filter(el => !el.children.length && (el.textContent || '').trim()).length);
    sabit = (say === onceki) ? sabit + 1 : 0;
    onceki = say;
  }

  const durum = await p.evaluate(() => {
    const giris = document.getElementById('cactusGiris');
    const gor = [...document.querySelectorAll('body *')].filter(el => {
      const s = getComputedStyle(el), r = el.getBoundingClientRect();
      return s.display !== 'none' && s.visibility !== 'hidden' && r.width > 2 && r.height > 2;
    });
    return {
      girisGorunur: !!(giris && getComputedStyle(giris).display !== 'none'),
      gorunur: gor.length,
      metinli: gor.filter(el => !el.children.length && (el.textContent || '').trim()).length,
      ilk: document.body.innerText.replace(/\s+/g, ' ').trim().slice(0, 100),
    };
  });

  console.log(`\n  giriş katmanı görünür : ${durum.girisGorunur ? 'EVET — panel render OLMADI' : 'hayır ✓'}`);
  console.log(`  görünür öge           : ${durum.gorunur}   metin taşıyan: ${durum.metinli}`);
  console.log(`  ekranda               : "${durum.ilk}"`);
  console.log(`  yakalanan dış istek   : ${yakalanan.length}`);
  [...new Set(yakalanan)].slice(0, 8).forEach(u => console.log(`      ${u}`));
  if (hatalar.length) {
    console.log(`  hata (${hatalar.length}):`);
    [...new Set(hatalar)].slice(0, 6).forEach(h => console.log('      ' + h));
  } else console.log('  hata                  : yok ✓');

  if (durum.metinli < 20) {
    console.log('\n  !! Panel yeterince render olmadı — kontrast denetimi ANLAMSIZ olurdu.');
    console.log('     Yukarıdaki hatalara bak; eksik uç nokta varsa SAHTE listesine ekle.');
  } else if (!yalnizDenetim || yalnizDenetim) {
    const d = await p.evaluate(DENETIM);
    console.log(`\n  kontrast: ${d.olculen} öge ölçüldü, AA-altı ${d.adet}`);
    d.tekil.forEach(k => console.log(
      `      ${String(k.o).padStart(5)}:1 (eşik ${k.esik}) ${String(k.px).padStart(3)}px  ${k.c} / ${k.b}  "${k.t}"`));
    if (!d.adet) console.log('      ✓ temiz');
  }

  // fullPage KULLANMA: bu sayfada position:fixed kapsayıcılarla boş kare
  // üretiyor (ilk koşuda görüldü — 90 görünür öge varken kare bomboştu).
  if (shot) {
    await p.screenshot({ path: shot });
    console.log(`\n  ekran görüntüsü: ${path.resolve(shot)}`);
  }
  await b.close();
})();
