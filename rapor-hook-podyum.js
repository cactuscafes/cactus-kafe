(function(){
  var API='https://cactus-rapor-api.batuhanbulut.workers.dev';
  var SUBE='podyum';
  var LK='cactus_satislar';
  var _sonKayitSayisi=0;

  function d1Gonder(satis){
    var tarih=satis.tarihISO||new Date().toISOString().split('T')[0];
    var urunler=satis.urunDetay||[];
    urunler.forEach(function(u){
      fetch(API+'/rapor/kaydet',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({sube:SUBE,tarih:tarih,urun_adi:u.ad,kategori:u.tip||'',adet:u.adet||1,birim_fiyat:u.fiyat||0})
      }).catch(function(){});
    });
  }

  function kontrol(){
    try{
      var satislar=JSON.parse(localStorage.getItem(LK)||'[]');
      if(satislar.length>_sonKayitSayisi){
        for(var i=_sonKayitSayisi;i<satislar.length;i++){
          d1Gonder(satislar[i]);
        }
        _sonKayitSayisi=satislar.length;
      }
    }catch(e){}
  }

  // Sayfa yüklenince mevcut sayıyı kaydet (önceki kayıtları gönderme)
  window.addEventListener('load',function(){
    setTimeout(function(){
      var satislar=JSON.parse(localStorage.getItem(LK)||'[]');
      _sonKayitSayisi=satislar.length;
      // Sonraki değişiklikleri izle
      setInterval(kontrol,2000);
    },1000);
  });
})();