(function(){
  var API='https://cactus-rapor-api.batuhanbulut.workers.dev';
  var SUBE='podyum';
  function hook(){
    var orig=window.odemeyiKaydet;
    if(!orig||orig._raporHook)return;
    window.odemeyiKaydet=function(masa,toplam,ic,yi,tip,urunler){
      var t=new Date().toISOString().split('T')[0];
      (urunler||[]).forEach(function(u){
        fetch(API+'/rapor/kaydet',{method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({sube:SUBE,tarih:t,urun_adi:u.ad,kategori:u.tip||'',adet:u.adet||1,birim_fiyat:u.fiyat||0})}).catch(function(){});
      });
      return orig.apply(this,arguments);
    };
    window.odemeyiKaydet._raporHook=true;
  }
  if(document.readyState==='loading'){document.addEventListener('DOMContentLoaded',function(){setTimeout(hook,500);});}
  else{setTimeout(hook,500);}
})();