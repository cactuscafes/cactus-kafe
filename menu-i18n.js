/* ═══ CACTUS MENÜ — TR/EN dil desteği ═══
 * Menü verisi (ürün adı, açıklama, kategori) Türkçe tutulur; burada İngilizce
 * karşılıkları eşlenir. Sözlükte olmayan bir metin OLDUĞU GİBİ kalır — yani
 * admin panelinden yeni ürün eklendiğinde sayfa bozulmaz, sadece o ürün
 * Türkçe görünür (buraya bir satır eklemek yeterlidir).
 *
 * Kullanım (menu-podyum.html içinde):
 *   T(metin)      → aktif dile göre metin
 *   TFiyat(fiyat) → "120 TL" / "120 ₺"
 *   dilDegistir() → TR ⇄ EN, menüyü yeniden çizer
 */
(function () {
  var SOZLUK = {
    // ── Kategoriler ──
    'Sıcak': 'Hot', 'Soğuk': 'Iced', 'Kokteyl': 'Mocktails', 'Cactus Kokteyl': 'Cactus Mocktails',
    'Vitamin': 'Refreshers', 'Serinletici': 'Refreshers', 'Waffle': 'Waffles',
    'Tatlılar': 'Desserts', 'Çaylar': 'Teas', 'Çay': 'Teas', 'Tostlar': 'Toasties',
    'Tost': 'Toasties', 'Meşrubat': 'Soft Drinks', 'Kahveler': 'Coffees',

    // ── Ürün adları (çoğu kahve adı evrensel — yalnız Türkçe olanlar çevrilir) ──
    'Filtre Kahve': 'Filter Coffee',
    'Türk Kahvesi': 'Turkish Coffee',
    'Double Türk Kahvesi': 'Double Turkish Coffee',
    'Dibek Kahvesi': 'Dibek Coffee',
    'Sıcak Çikolata': 'Hot Chocolate',
    'Bardak Süt': 'Glass of Milk',
    'Fincan Çay': 'Turkish Tea (Cup)',
    'Karton Bardak Çay': 'Turkish Tea (To Go)',
    'Ice Filtre': 'Iced Filter Coffee',
    'Ice Espresso': 'Iced Espresso',
    'Limonata': 'Lemonade',
    'Çilekli Limonata': 'Strawberry Lemonade',
    'Ihlamur': 'Linden Tea',
    'Adaçayı': 'Sage Tea',
    'Melisa Çayı': 'Lemon Balm Tea',
    'Hibiskus': 'Hibiscus Tea',
    'Papatya': 'Chamomile Tea',
    'Yeşil Çay': 'Green Tea',
    'Kış Çayı': 'Winter Tea',
    'Mavi Kelebek': 'Blue Butterfly Tea',
    'Kaşarlı Sosyete': 'Cheese Toastie',
    'Sucuklu Sosyete': 'Sucuk Toastie',
    'Karışık Sosyete': 'Cheese & Sucuk Toastie',
    'Kaşarlı Sosyete Tostu': 'Cheese Toastie',
    'Sucuklu Sosyete Tostu': 'Sucuk Toastie',
    'Karışık Sosyete Tostu': 'Cheese & Sucuk Toastie',
    'Kaşarlı Sanayi': 'Cheese Toastie (Large)',
    'Sucuklu Sanayi': 'Sucuk Toastie (Large)',
    'Karışık Sanayi': 'Cheese & Sucuk Toastie (Large)',
    'Damla Cam Şişe Su': 'Still Water (Glass Bottle)',
    'Su': 'Still Water',
    'Sade Soda': 'Sparkling Water',
    'Meyveli Soda': 'Fruit Soda',
    'Coco Cola': 'Coca-Cola',
    'Enerji İçeceği': 'Energy Drink',
    'San Sebastian': 'San Sebastián Cheesecake',
    'Cevizli Çikolatalı Kurabiye': 'Walnut & Chocolate Cookie',
    'Lotus Pasta': 'Lotus Cake',
    'Dubai Spoonful': 'Dubai Spoonful',
    'Buzlu Bardak': 'Cup of Ice',
    'Salep': 'Salep (Orchid Milk Drink)',

    // ── Ürün açıklamaları ──
    'Tek shot, saf ve yoğun.': 'Single shot — pure and intense.',
    'Espresso + hafif süt köpüğü.': 'Espresso with a touch of milk foam.',
    'Espresso + sıcak su.': 'Espresso with hot water.',
    'Espresso + eşit oranda süt.': 'Espresso with an equal part of milk.',
    'Espresso + bol buharda süt.': 'Espresso with plenty of steamed milk.',
    'Latte + karamel sos.': 'Latte with caramel sauce.',
    'Latte + vanilya özü.': 'Latte with vanilla extract.',
    'Latte + fındık aroması.': 'Latte with hazelnut syrup.',
    'Double espresso + mikroköpük süt.': 'Double espresso with silky microfoam.',
    'Espresso + süt + köpük.': 'Espresso, milk and foam.',
    'Espresso + çikolata + süt.': 'Espresso, chocolate and milk.',
    'Espresso + beyaz çikolata + süt.': 'Espresso, white chocolate and milk.',
    'Tek köken, damlatma yöntemi.': 'Single origin, pour-over brewed.',
    'Cezve, tercihe göre şekerli.': 'Brewed in a cezve, sugar to taste.',
    'Çift porsiyon Türk kahvesi.': 'Double portion of Turkish coffee.',
    'Taş dibekte dövülmüş, baharatlı.': 'Stone-ground, lightly spiced.',
    'Salep unu + sıcak süt + tarçın.': 'Orchid root, hot milk and cinnamon.',
    'Gerçek çikolata + sıcak süt.': 'Real chocolate with hot milk.',
    'Sade buharda ısıtılmış süt.': 'Plain steamed milk.',
    'Espresso + soğuk su + buz.': 'Espresso, cold water and ice.',
    'Espresso + soğuk süt + buz.': 'Espresso, cold milk and ice.',
    'Double espresso + soğuk süt.': 'Double espresso with cold milk.',
    'Espresso + çikolata + soğuk süt.': 'Espresso, chocolate and cold milk.',
    'Espresso + beyaz çikolata + buz.': 'Espresso, white chocolate and ice.',
    'Espresso + karamel + soğuk süt.': 'Espresso, caramel and cold milk.',
    'Espresso + vanilya + karamel + buz.': 'Espresso, vanilla, caramel and ice.',
    'Espresso + fındık + soğuk süt.': 'Espresso, hazelnut and cold milk.',
    'Espresso + vanilya + soğuk süt.': 'Espresso, vanilla and cold milk.',
    'Soğuk demleme filtre kahve.': 'Cold brew filter coffee.',
    'Karpuz, limonata, çilek': 'Watermelon, lemonade, strawberry',
    'kuzukulağı, limon': 'Sorrel and lemon',
    'Mango, hindistan cevizi, tarçın': 'Mango, coconut, cinnamon',
    'Acı portakal, çilek, karanfil': 'Bitter orange, strawberry, clove',
    'Soda + limon + tuz': 'Sparkling water, lemon and salt',
    'Misket limonu + nane + su': 'Lime, mint and water',
    'Karpuz, çilek, orman meyvesi, mango': 'Watermelon, strawberry, forest fruits, mango',
    'Çikolata, çilek, vanilya': 'Chocolate, strawberry or vanilla',
    'Ev yapımı': 'Homemade',
    'Ev yapımı limonata + çilek': 'Homemade lemonade with strawberry',
    'Çilek, muz, sütlü çikolata, beyaz çikolata, oreo parçacıkları':
      'Strawberry, banana, milk chocolate, white chocolate, Oreo crumbs',
    'Çilek, muz, sütlü çikolata, antep fıstığı çikolata, kadayıf parçacıkları':
      'Strawberry, banana, milk chocolate, pistachio chocolate, kadayıf crumbs',
    'Çilek, muz, bitter çikolata, pasta süslemeleri':
      'Strawberry, banana, dark chocolate, sprinkles',
    'Çilek, muz, karamel çikolata, sütlü çikolata, lotus parçacıkları':
      'Strawberry, banana, caramel chocolate, milk chocolate, Lotus crumbs',
    'Taze ihlamur çiçeği demlemesi.': 'Freshly brewed linden blossom.',
    'Taze adaçayı yapraklarından.': 'From fresh sage leaves.',
    'Melisa + hafif limon aroması.': 'Lemon balm with a hint of citrus.',
    'Hibiskus çiçeği, ekşimsi.': 'Hibiscus flower, pleasantly tart.',
    'Papatya çiçeği demlemesi.': 'Brewed chamomile flowers.',
    'Hafif demlenmiş, antioksidan.': 'Lightly brewed, rich in antioxidants.',
    'Tarçın + karanfil + zencefil.': 'Cinnamon, clove and ginger.',
    'Butterfly pea flower, renk değiştirir.': 'Butterfly pea flower — changes colour.',
    'İnce ekmek + kaşar peyniri.': 'Thin bread with kaşar cheese.',
    'İnce ekmek + sucuk.': 'Thin bread with Turkish sucuk sausage.',
    'İnce ekmek + kaşar + sucuk.': 'Thin bread with kaşar cheese and sucuk.',
    'Soğuk kaynak suyu.': 'Chilled spring water.',
    'Karbonatlı maden suyu.': 'Sparkling mineral water.',

    // ── Servis bilgisi ──
    '350 ml plastik bardak': '350 ml plastic cup',

    // ── Sabit arayüz metinleri ──
    'Dijital Sadakat Kartı': 'Digital Loyalty Card',
    'Kartımı Gör →': 'View My Card →',
    'Öne Çıkanlar': 'Featured',
    'Yorum Yap →': 'Write a Review →',
    'Yükleniyor…': 'Loading…',
    'Ana Sayfa': 'Home',
    'İletişim': 'Contact',
    'İş Başvurusu': 'Careers',
    'Menü': 'Menu',
    '🎖 Sadakat Kartı': '🎖 Loyalty Card',
    '🎮 Oyun': '🎮 Games',
    'FSM Menü': 'FSM Menu',
    "Waffle'lara Bak": 'See Waffles'
  };

  var dil = 'tr';
  try { dil = localStorage.getItem('cactus_dil') || 'tr'; } catch (e) {}
  // ?lang=en ile gelen ziyaretçi (QR / paylaşılan link) doğrudan İngilizce görsün
  try {
    var q = new URLSearchParams(location.search).get('lang');
    if (q === 'en' || q === 'tr') { dil = q; localStorage.setItem('cactus_dil', dil); }
  } catch (e) {}

  window.CACTUS_DIL = function () { return dil; };

  // Sözlükte varsa çevir, yoksa Türkçesini koru
  window.T = function (metin) {
    if (dil !== 'en' || metin == null) return metin;
    var s = String(metin).trim();
    return SOZLUK[s] || metin;
  };

  window.TFiyat = function (fiyat) {
    return (fiyat || '-') + (dil === 'en' ? ' ₺' : ' TL');
  };

  window.TCesit = function (n) {
    return n + (dil === 'en' ? ' items' : ' cesit');
  };

  // Sabit sayfa metinleri — seçici → {tr, en} (html:true ise innerHTML)
  var SABIT = [
    ['.sk-banner-eyebrow', 'Dijital Sadakat Kartı', 'Digital Loyalty Card'],
    ['.sk-banner-title', '7 içecek, 1 tanesi<br><em>bizden.</em>', '7 drinks, the 8th is <em>on us.</em>', true],
    ['.sk-banner-sub',
      'Her siparişinde yıldız kazan. 7 yıldız doldurduğunda<br>bir içeceğin bizden. Kart yok, uygulama yok — sadece telefon numaran.',
      'Earn a star with every order. Fill 7 stars and your next drink<br>is on us. No card, no app — just your phone number.', true],
    ['.sk-banner-cta', 'Kartımı Gör →', 'View My Card →'],
    ['.sk-stamp-label', '3 / 7 yıldız', '3 / 7 stars'],
    ['.sk-kasiyer-not span:last-child',
      'Yıldız kazanmak için sipariş verirken <strong>telefon numaranı kasiyere söylemeyi unutma!</strong>',
      'To earn a star, <strong>give your phone number to the cashier</strong> when you order.', true],
    ['.menu-header-title', 'C | <em>Menü</em>', 'C | <em>Menu</em>', true],
    ['.spotlight-title', 'Öne Çıkanlar', 'Featured'],
    ['.mg-cta', 'Yorum Yap →', 'Write a Review →'],
    ['.kampanya-eyebrow', "Podyumpark'a Özel", 'Podyumpark Exclusive'],
    ['.kampanya-sub',
      "Sıcacık bubble waffle'ın üzerine taptaze çilek, muz ve dilediğin sos — bitter çikolatadan Antep fıstığına, lotustan beyaz çikolataya. Her kase siparişinle hazırlanır.",
      'Warm bubble waffle topped with fresh strawberries, banana and your choice of sauce — dark chocolate, pistachio, Lotus or white chocolate. Every bowl is made to order.'],
    ['.kampanya-cta', "Waffle'lara Bak", 'See Waffles'],
    ['.kampanya-gec', 'Kapat', 'Close'],
    ['.menu-dipnot', '💧 Su ve soda yalnızca gel-al veya sipariş yanında servis edilir.', '💧 Water and soda are served to-go or alongside an order only.'],
    ['.kampanya-icecek', "🥤 Waffle'ının yanında dilediğin içecek <b>yalnızca 150₺</b>", '🥤 Any drink with your waffle — <b>just 150₺</b>', true],
    ['.pop-badge', '🧇&nbsp; Günlük taze', '🧇&nbsp; Fresh daily', true]
  ];

  function sabitleriUygula() {
    SABIT.forEach(function (s) {
      var el = document.querySelector(s[0]);
      if (!el) return;
      var deger = (dil === 'en') ? s[2] : s[1];
      if (s[3]) el.innerHTML = deger; else el.textContent = deger;
    });
    // Google yorum sayısı: "54 Google yorumu" → "54 Google reviews"
    var mg = document.querySelector('.mg-count');
    if (mg) {
      mg.textContent = dil === 'en'
        ? mg.textContent.replace(/Google yorumu/i, 'Google reviews')
        : mg.textContent.replace(/Google reviews/i, 'Google yorumu');
    }
    // Menüde olmayan sayfalara giden nav linkleri
    document.querySelectorAll('#mainNav a, #mainMobMenu a').forEach(function (a) {
      // Metinsiz bağlantılara DOKUNMA. Logo bağlantısının içinde yalnızca
      // <img> var; textContent'i '' okunuyor ve geri yazılınca görseli
      // DOM'dan siliyordu — nav'daki Cactus logosu bu yüzden kayboluyordu.
      if (!a.textContent.trim()) return;
      var tr = a.dataset.tr || a.textContent.trim();
      if (!a.dataset.tr) a.dataset.tr = tr;
      var en = SOZLUK[tr];
      if (dil === 'en' && en) a.textContent = en;
      else a.textContent = tr;
    });
    document.documentElement.lang = dil;
    var btn = document.getElementById('dilBtn');
    if (btn) btn.textContent = dil === 'en' ? '🇹🇷 Türkçe' : '🇬🇧 English';
  }

  window.dilDegistir = function () {
    dil = (dil === 'en') ? 'tr' : 'en';
    try { localStorage.setItem('cactus_dil', dil); } catch (e) {}
    sabitleriUygula();
    if (typeof renderMenu === 'function' && typeof AKTIF_SUBE !== 'undefined') {
      renderMenu(AKTIF_SUBE);
      if (typeof altKatBarGuncelle === 'function') setTimeout(altKatBarGuncelle, 30);
      if (typeof gozlemUrunler === 'function') setTimeout(gozlemUrunler, 40);
    }
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', sabitleriUygula);
  } else {
    sabitleriUygula();
  }
  // Menü geç yüklendiğinde sabitler yeniden uygulanabilsin
  window.CACTUS_DIL_UYGULA = sabitleriUygula;
})();
