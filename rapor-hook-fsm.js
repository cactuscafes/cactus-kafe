(function(){
  var API='https://cactus-rapor-api.batuhanbulut.workers.dev';
  var SUBE='fsm';
  var LK='cactus_satis_fsmlar';
  var _sonKayit=0;

  function d1Gonder(satis){
    var tarih=satis.tarihISO||new Date().toISOString().split('T')[0];
    (satis.urunDetay||[]).forEach(function(u){
      fetch(API+'/rapor/kaydet',{
        method:'POST',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify({sube:SUBE,tarih:tarih,urun_adi:u.ad,kategori:u.tip||'',adet:u.adet||1,birim_fiyat:u.fiyat||0})
      }).catch(function(){});
    });
  }

  function kontrol(){
    try{
      var s=JSON.parse(localStorage.getItem(LK)||'[]');
      if(s.length>_sonKayit){
        for(var i=_sonKayit;i<s.length;i++) d1Gonder(s[i]);
        _sonKayit=s.length;
      }
    }catch(e){}
  }

  window.addEventListener('load',function(){
    setTimeout(function(){
      var s=JSON.parse(localStorage.getItem(LK)||'[]');
      _sonKayit=s.length;
      setInterval(kontrol,2000);
    },1000);
  });
})();