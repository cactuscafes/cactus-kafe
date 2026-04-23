(function(){
  var API='https://cactus-rapor-api.batuhanbulut.workers.dev',SUBE='podyum',LK='cactus_satislar',_son=0;
  function gonder(s){
    var tarih=s.tarihISO||new Date().toISOString().split('T')[0];
    // odeme_tipi: 'Nakit' veya 'Kredi Karti'
    var tip=(s.odeme_tipi&&s.odeme_tipi.toLowerCase().includes('kredi'))?'kredi':'nakit';
    (s.urunDetay||[]).forEach(function(u){
      fetch(API+'/rapor/kaydet',{method:'POST',headers:{'Content-Type':'application/json'},
      body:JSON.stringify({sube:SUBE,tarih:tarih,urun_adi:u.ad,kategori:u.tip||'',adet:u.adet||1,birim_fiyat:u.fiyat||0,odeme_tipi:tip})}).catch(function(){});
    });
  }
  function kontrol(){
    try{var s=JSON.parse(localStorage.getItem(LK)||'[]');if(s.length>_son){for(var i=_son;i<s.length;i++)gonder(s[i]);_son=s.length;}}catch(e){}
  }
  window.addEventListener('load',function(){setTimeout(function(){var s=JSON.parse(localStorage.getItem(LK)||'[]');_son=s.length;setInterval(kontrol,2000);},1000);});
})();