"""Cactus 3B — Faz 11-12: rig'li, iskeletli oyuncu karakteri (Blender / bpy).

    pip install bpy pillow
    python3 oyun3d/araclar/karakter.py

Ne yapar: low-poly bir kaktüs karakteri modeller, ona on bir kemikli bir
iskelet kurar (Faz 12'de bacak uyluk + baldır + ayak olarak üçe bölündü),
mesh'i kemiklere bağlar (skinning), beş animasyonu (boşta, yürüme, koşma,
zıplama, düşme) keyframe'ler ve hepsini tek bir glTF olarak
`varliklar/oyuncu.gltf` dosyasına yazar.

ADIM TEMPOSU ÖLÇÜLÜYOR (Faz 12): yürüme ve koşmanın süresi elle yazılmıyor;
animasyonun adım boyu pozdan ölçülüp oyunun hızına göre hesaplanıyor
(bkz. KAYMA_HEDEFI). Elle yazılan süre, hareket hızı değiştiğinde sessizce
yanlış kalıyordu.

NEDEN ŞİMDİ: Faz 1'den beri karakter beş kutudan ibaretti ve animasyon,
kutuların dönüşünü sinüsle üreten bir Godot betiğiydi (`animasyon_uret.gd`).
O dosyanın kendi yorumunda yazıyordu: "Blender'dan gerçek bir model
geldiğinde bu dosya silinecek, AnimationTree yapısı aynen kalabilir." Faz 11
tam olarak bunu yapıyor — durum makinesi ve `oyuncu.gd` değişmiyor, altındaki
iskelet değişiyor.

DİKENLER MESH'TE DEĞİL DOKUDA: kaburgalar ve dikenler atlasın `oyuncu`
bölgesinde çiziliyor. Geometriye diken koymak üçgen sayısını üçe katlar ve
skinning'i zorlaştırır; low-poly stilinde silueti mesh, detayı doku taşır.

KEMİK EKSENİ TUZAĞI: Blender'da kemikler kendi +Y'si boyunca uzar. Bacak
kemiği aşağı bakıyor, yani onun yerel X'i dünya X'iyle aynı yöne bakmıyor.
Bu yüzden salınımlar kemiğin YEREL ekseninde veriliyor ve yönü her kemik için
bir kez ölçülüp sabitlendi (`_YON` çarpanları); "sağ bacak ters sallanıyor"
hatasının kaynağı hep budur.

ORTAK HAT (Faz 14): iskelet kurma, ağırlık, poz yazma, f-eğrisi erişimi ve
glTF dışa aktarımı `araclar/rig.py` içinde — düşman da aynı hattı kullanıyor.
Burada kalan her şey BU karaktere özgü: ölçüler, kemik tablosu, mesh, ağırlık
bölgeleri ve animasyonlar.
"""

import json
import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

BURASI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BURASI)
PROJE = os.path.dirname(BURASI)
VARLIK = os.path.join(PROJE, "varliklar")

import modeller  # atlas, UV açma, malzeme ve ölçüm ortak
import rig       # iskelet, ağırlık, animasyon ve dışa aktarım hattı (Faz 14)

# --- ölçüler (metre, Blender Z-up; ayak tabanı z=0) -------------------------
AYAK = 0.0
KALCA_Z = 0.62
GOVDE_Z = 1.05
KAFA_Z = 1.58
## Kapsul 1,70 m: model kapsulun icinde kalmali ama kafasi kapsulun
## altinda da durmamali. Kutu karakterin boyu 1,74'tu; silueti korumak
## icin ayni banda oturtuldu.
BOY = 1.72           # kafa tepesi
KOL_Z = 0.92         # omuz yüksekliği
KOL_X = 0.24         # gövde kenarından omuz
BACAK_X = 0.13
## Faz 12: bacak iki kemiğe bölündü. Tek kemikli bacakta IK diye bir şey yok —
## çözülecek zincir yok, diz yok. Ayak IK'sının anlamı "dizi nereye kıracağım"
## sorusudur; o soru ancak uyluk + baldır varken sorulabiliyor.
DIZ_Z = 0.34         # diz yüksekliği
BILEK_Z = 0.10       # ayak bileği
AYAK_UZUNLUK = 0.17  # bilekten parmağa (Godot'da ileri = -Z)

## Kemik adları Godot'ya aynen geçiyor; animasyon izleri bu adlara bağlı.
KEMIKLER = [
    # ad, baş, uç, ebeveyn
    ("Kalca", (0, 0, KALCA_Z), (0, 0, KALCA_Z + 0.18), None),
    ("Govde", (0, 0, KALCA_Z + 0.18), (0, 0, GOVDE_Z), "Kalca"),
    ("Kafa", (0, 0, GOVDE_Z), (0, 0, KAFA_Z), "Govde"),
    ("KolSol", (-KOL_X, 0, KOL_Z), (-KOL_X - 0.10, 0, KOL_Z + 0.34), "Govde"),
    ("KolSag", (KOL_X, 0, KOL_Z), (KOL_X + 0.10, 0, KOL_Z + 0.34), "Govde"),
    ("BacakSol", (-BACAK_X, 0, KALCA_Z), (-BACAK_X, 0, DIZ_Z), "Kalca"),
    ("BacakSag", (BACAK_X, 0, KALCA_Z), (BACAK_X, 0, DIZ_Z), "Kalca"),
    ("DizSol", (-BACAK_X, 0, DIZ_Z), (-BACAK_X, 0, BILEK_Z), "BacakSol"),
    ("DizSag", (BACAK_X, 0, DIZ_Z), (BACAK_X, 0, BILEK_Z), "BacakSag"),
    # Ayak ileri bakıyor: Blender +Y, Godot'da -Z (ileri).
    ("AyakSol", (-BACAK_X, 0, BILEK_Z), (-BACAK_X, AYAK_UZUNLUK, BILEK_Z * 0.4), "DizSol"),
    ("AyakSag", (BACAK_X, 0, BILEK_Z), (BACAK_X, AYAK_UZUNLUK, BILEK_Z * 0.4), "DizSag"),
]

KARE_HIZI = rig.KARE_HIZI

# --- adım kalibrasyonu (Faz 12) --------------------------------------------
## Oyunun yatay hızları — `betikler/oyuncu.gd` içindeki `yurume_hizi` ve
## `kosma_hizi` ile aynı olmak zorunda. `testler/karakter_testi.gd` ikisini
## karşılaştırıyor: biri değişip diğeri unutulursa test düşüyor.
HIZ = {"yurume": 4.2, "kosma": 7.4}
## KAYMA ORANI: bir çevrimde ayak yerde kaç kat "kayıyor".
##
## Gövde bir çevrimde `hiz * sure` metre gidiyor; bacaklar ise ancak
## `adim` metre atabiliyor (adım, bacak uzunluğunun ve salınım genliğinin
## geometrik sonucu — 0,52 m'lik bacakla en fazla ~1,5 m). Oran ikisinin
## bölümü: 1,0 = ayak yere yapışık, 2,0 = ayak yerde iki katı kayıyor.
##
## NEDEN 1,0 DEĞİL: oyunun koşma hızı 7,4 m/s — 1,72 m'lik bir karakter için
## saniyede 4,3 boy. Kaymayı tamamen kapatmak çevrimi 0,21 sn'ye indirir,
## yani saniyede ~9 adım: bacaklar görünmez bir pervaneye döner. Hızı
## düşürmek ise oyunun bütün denge bütçesini (Faz 10) ve hayalet turlarını
## bozar. 2,0 bu ikisinin arasındaki bilinçli seçim: kayma Faz 11'deki
## ~4,6 kattan yarıdan fazla azalıyor, adım sıklığı saniyede ~4,5'te —
## hızlı ama okunabilir — kalıyor.
KAYMA_HEDEFI = 2.0




def govde_mesh() -> bpy.types.Object:
    """Kaktüs karakter: gövde, kafa, iki kol pedi, iki bacak.

    Parçalar ayrı ada değil tek mesh: iskelet zaten hareketi taşıyor, ayrı
    nesneler olsa her biri ayrı draw call olurdu.
    """
    bm = bmesh.new()
    # Gövde: yukarı doğru hafif incelen bir prizma.
    rig.kutu(bm, (0, 0, (KALCA_Z + GOVDE_Z) * 0.5 - 0.03),
          (0.46, 0.34, GOVDE_Z - KALCA_Z + 0.30), egim=0.12)
    # Kafa: kaktüsün tepesi, gövdeden dar.
    rig.kutu(bm, (0, 0, (GOVDE_Z + KAFA_Z) * 0.5 + 0.06),
          (0.36, 0.30, KAFA_Z - GOVDE_Z + 0.16), egim=0.18)
    # Kollar: saguaro pedi gibi yana çıkıp yukarı dönüyor.
    for isaret in (-1, 1):
        rig.kutu(bm, (isaret * (KOL_X + 0.02), 0, KOL_Z + 0.02), (0.20, 0.17, 0.15))
        rig.kutu(bm, (isaret * (KOL_X + 0.07), 0, KOL_Z + 0.20), (0.15, 0.15, 0.30))
    # Bacaklar: uyluk, baldır ve ayak ayrı parçalar — diz kırılınca mesh de
    # kırılsın diye. Tek kutu olsaydı diz bükülünce kutu esneyip "lastik bacak"
    # görüntüsü verirdi.
    for isaret in (-1, 1):
        rig.kutu(bm, (isaret * BACAK_X, 0, (KALCA_Z + DIZ_Z) * 0.5),
              (0.17, 0.17, KALCA_Z - DIZ_Z + 0.06))
        rig.kutu(bm, (isaret * BACAK_X, 0, (DIZ_Z + BILEK_Z) * 0.5),
              (0.15, 0.15, DIZ_Z - BILEK_Z + 0.06))
        rig.kutu(bm, (isaret * BACAK_X, AYAK_UZUNLUK * 0.35, BILEK_Z * 0.5),
              (0.15, AYAK_UZUNLUK + 0.10, BILEK_Z + 0.02))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("oyuncu")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("oyuncu", me)
    bpy.context.collection.objects.link(obj)
    return obj



def _kemik_sec(ko: Vector) -> str:
    """Bir köşe hangi kemiğe ait? Bölgeye göre: bacak / kol / kafa / gövde.

    Ağırlıklar keskin (0/1) değil, eklem çevresinde yumuşatılıyor
    (`agirlik_ata`); burada yalnızca ana kemik seçiliyor.
    """
    if ko.z < KALCA_Z - 0.02 and abs(ko.x) > 0.04:
        sag = ko.x > 0
        if ko.z < BILEK_Z + 0.03 or ko.y > 0.06:
            return "AyakSag" if sag else "AyakSol"
        if ko.z < DIZ_Z + 0.02:
            return "DizSag" if sag else "DizSol"
        return "BacakSag" if sag else "BacakSol"
    if abs(ko.x) > KOL_X - 0.06 and ko.z > KOL_Z - 0.12:
        return "KolSol" if ko.x < 0 else "KolSag"
    if ko.z > GOVDE_Z - 0.02:
        return "Kafa"
    if ko.z > KALCA_Z + 0.16:
        return "Govde"
    return "Kalca"


def agirlik_ata(obj: bpy.types.Object) -> dict[str, int]:
    """Her köşeyi bir kemiğe bağlar, eklem çevresinde iki kemiğe paylaştırır.

    Otomatik ağırlık (`parent_set(type='ARMATURE_AUTO')`) arayüzsüz ortamda da
    çalışıyor ama sonucu tahmin edilemez: kol pedinin ağırlığı bacağa sıçrayınca
    karakter yürürken esniyordu. Bölgeye göre elle atamak hem okunur hem
    tekrarlanabilir.
    """
    for ad, *_ in KEMIKLER:
        obj.vertex_groups.new(name=ad)
    sayim: dict[str, int] = {ad: 0 for ad, *_ in KEMIKLER}
    for v in obj.data.vertices:
        ana = _kemik_sec(v.co)
        sayim[ana] += 1
        # Eklem yumuşatma: kalça hizasındaki bacak köşeleri kalçayla paylaşılır,
        # omuz hizasındaki kol köşeleri gövdeyle. Tek kemiğe bağlı köşe,
        # eklemde "makas" kırılması yapıyor.
        if ana.startswith("Bacak") and v.co.z > KALCA_Z - 0.16:
            pay = min(1.0, (v.co.z - (KALCA_Z - 0.16)) / 0.16) * 0.5
            obj.vertex_groups[ana].add([v.index], 1.0 - pay, "REPLACE")
            obj.vertex_groups["Kalca"].add([v.index], pay, "REPLACE")
        elif ana.startswith("Diz") and v.co.z > DIZ_Z - 0.06:
            # Diz çevresi: baldır ile uyluk paylaşıyor, yoksa diz kırılınca
            # mesh makas gibi ayrılıyor.
            ust = "BacakSol" if ana.endswith("Sol") else "BacakSag"
            obj.vertex_groups[ana].add([v.index], 0.6, "REPLACE")
            obj.vertex_groups[ust].add([v.index], 0.4, "REPLACE")
        elif ana.startswith("Kol") and v.co.z < KOL_Z + 0.06:
            obj.vertex_groups[ana].add([v.index], 0.65, "REPLACE")
            obj.vertex_groups["Govde"].add([v.index], 0.35, "REPLACE")
        elif ana == "Kafa" and v.co.z < GOVDE_Z + 0.08:
            obj.vertex_groups[ana].add([v.index], 0.7, "REPLACE")
            obj.vertex_groups["Govde"].add([v.index], 0.3, "REPLACE")
        else:
            obj.vertex_groups[ana].add([v.index], 1.0, "REPLACE")
    return sayim


# --- animasyon --------------------------------------------------------------

## Kemiğin yerel X ekseninde pozitif dönüş, dünyada hangi yöne gidiyor?
## Bacaklar aşağı, kollar yukarı baktığı için işaretler ters. Bir kez ölçüldü.
_YON = {"BacakSol": -1.0, "BacakSag": -1.0, "DizSol": -1.0, "DizSag": -1.0,
        "AyakSol": -1.0, "AyakSag": -1.0, "KolSol": 1.0, "KolSag": 1.0,
        "Govde": 1.0, "Kafa": 1.0, "Kalca": 1.0}


def _anahtar(arm: bpy.types.Object, kare: float, acilar: dict[str, tuple],
             konum: tuple | None = None) -> None:
    """Ortak poz yazıcısına bu karakterin işaret tablosunu ve kök kemiğini
    bağlar (`araclar/rig.py`)."""
    rig.anahtar(arm, kare, acilar, _YON, "Kalca", konum)







def animasyonlari_uret(arm: bpy.types.Object) -> tuple[dict, dict]:
    """Beş animasyon. Hareket dili Faz 1'deki yordamsal sürümle aynı tutuldu:
    oyunun hissi değişmemeli, yalnızca altındaki iskelet değişmeli.

    Faz 12: yürüme ve koşmanın SÜRESİ artık elle yazılmıyor; adım boyu
    ölçülüp oyunun hızına göre hesaplanıyor (bkz. KAYMA_HEDEFI)."""
    sureler: dict[str, float] = {}
    adimlar: dict[str, float] = {}

    def kare(sn: float) -> float:
        return 1.0 + sn * KARE_HIZI

    # boşta: hafif nefes, kollar dışa açık
    eylem = rig.eylem(arm, "bosta")
    for t, yuk in ((0.0, 0.0), (1.3, 0.022), (2.6, 0.0)):
        _anahtar(arm, kare(t), {
            "Govde": (0.0, 0.0, 0.0), "Kafa": (0.0, 0.0, 0.0),
            "KolSol": (0.05 if t == 1.3 else 0.0, 0.0, 0.10),
            "KolSag": (-0.05 if t == 1.3 else 0.0, 0.0, -0.10),
            "BacakSol": (0.0, 0.0, 0.0), "BacakSag": (0.0, 0.0, 0.0),
            # Dizler tam düz değil: kilitli diz hem doğal durmuyor hem de
            # ayak IK'sına çözüm alanı bırakmıyor (tam düz bacak, hedefe
            # uzanmak için kıracak açı bulamaz).
            "DizSol": (-0.08, 0.0, 0.0), "DizSag": (-0.08, 0.0, 0.0),
            "AyakSol": (0.04, 0.0, 0.0), "AyakSag": (0.04, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, True)
    sureler["bosta"] = 2.6

    # yürüme / koşma: aynı kalıp, farklı genlik. Süre geçici — ölçümden sonra
    # ölçekleniyor; buradaki değer yalnızca anahtarların aralığını belirliyor.
    for ad, sure, bacak, kol, zipzip, egim in (
            ("yurume", 0.9, 0.45, 0.28, 0.04, 0.03),
            ("kosma", 0.55, 0.85, 0.55, 0.09, 0.16)):
        eylem = rig.eylem(arm, ad)
        diz_genlik = bacak * 1.25
        for k in range(9):
            t = sure * k / 8.0
            f = math.tau * k / 8.0
            # DİZ: ayak yere bastığında (bacak önde, f=0) düz, geri savrulurken
            # bükülü. Bu olmadan bacak sopa gibi salınıyor ve adım "yürüyüş"
            # değil "pergel" gibi görünüyor.
            diz_sol = -diz_genlik * (0.5 - 0.5 * math.cos(f))
            diz_sag = -diz_genlik * (0.5 - 0.5 * math.cos(f + math.pi))
            bacak_sol = math.sin(f) * bacak
            bacak_sag = math.sin(f + math.pi) * bacak
            _anahtar(arm, kare(t), {
                "BacakSol": (bacak_sol, 0.0, 0.0),
                "BacakSag": (bacak_sag, 0.0, 0.0),
                "DizSol": (diz_sol, 0.0, 0.0),
                "DizSag": (diz_sag, 0.0, 0.0),
                # AYAK: uyluk + baldırın tersi kadar döndürülüyor ki taban
                # yere paralel kalsın (ayak ucu havaya kalkmasın).
                "AyakSol": (-(bacak_sol + diz_sol) * 0.55, 0.0, 0.0),
                "AyakSag": (-(bacak_sag + diz_sag) * 0.55, 0.0, 0.0),
                "KolSol": (math.sin(f + math.pi) * kol, 0.0, 0.10),
                "KolSag": (math.sin(f) * kol, 0.0, -0.10),
                "Govde": (egim, 0.0, 0.0),
                "Kafa": (-egim * 0.6, 0.0, 0.0),   # baş yere değil ileri baksın
            }, (0.0, 0.0, abs(math.sin(f)) * zipzip - zipzip * 0.5))
        # Adım boyu ölçülüyor, sonra süre oyunun hızına oturtuluyor.
        adim = rig.adim_olc(arm, sure, ("AyakSol", "AyakSag"))
        gereken = adim * KAYMA_HEDEFI / HIZ[ad]
        rig.zamani_olcekle(eylem, gereken / sure)
        rig.bitir(eylem, arm, True)
        sureler[ad] = gereken
        adimlar[ad] = adim

    # zıplama: çöküp itme
    eylem = rig.eylem(arm, "zipla")
    for t, bacak_s, bacak_g, kol, egim, yuk in (
            (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
            (0.18, -0.9, 0.5, -1.1, -0.12, 0.05),
            (0.45, -0.5, 0.25, -0.8, -0.05, 0.02)):
        _anahtar(arm, kare(t), {
            "BacakSol": (bacak_s, 0.0, 0.0), "BacakSag": (bacak_g, 0.0, 0.0),
            "DizSol": (-0.75 if t > 0.0 else -0.1, 0.0, 0.0),
            "DizSag": (-0.35 if t > 0.0 else -0.1, 0.0, 0.0),
            "AyakSol": (0.25, 0.0, 0.0), "AyakSag": (0.15, 0.0, 0.0),
            "KolSol": (kol, 0.0, 0.16), "KolSag": (kol, 0.0, -0.16),
            "Govde": (egim, 0.0, 0.0), "Kafa": (0.0, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["zipla"] = 0.45

    # düşme: bacaklar açık, kollar yukarı
    eylem = rig.eylem(arm, "dusme")
    for t, sallanma in ((0.0, 0.0), (0.4, 0.12), (0.8, 0.0)):
        _anahtar(arm, kare(t), {
            "BacakSol": (-0.35 + sallanma, 0.0, 0.0),
            "BacakSag": (0.3 - sallanma, 0.0, 0.0),
            "DizSol": (-0.5 - sallanma, 0.0, 0.0), "DizSag": (-0.25, 0.0, 0.0),
            "AyakSol": (0.2, 0.0, 0.0), "AyakSag": (0.1, 0.0, 0.0),
            "KolSol": (-1.3, 0.0, 0.22), "KolSag": (-1.3, 0.0, -0.22),
            "Govde": (-0.08, 0.0, 0.0), "Kafa": (0.05, 0.0, 0.0),
        }, (0.0, 0.0, 0.0))
    rig.bitir(eylem, arm, True)
    sureler["dusme"] = 0.8
    return sureler, adimlar



def main() -> int:
    rig.temizle()
    bpy.context.scene.render.fps = int(KARE_HIZI)

    mesh = govde_mesh()
    yogunluk = modeller.uv_ac(mesh, modeller.BOLGELER["oyuncu"])
    atlas_yolu = os.path.join(VARLIK, "atlas.png")
    if not os.path.exists(atlas_yolu):
        modeller.atlas_uret(atlas_yolu)
    img = bpy.data.images.load(atlas_yolu)
    # TUZAK: burada bir kez `img.filepath = "//atlas.png"` yazilmisti. Kaydedilmemis
    # bir blend dosyasinda "//" cozumlenemiyor, dISa aktarici dokuyu sessizce
    # atliyor ve karakter oyunda BEYAZ cikiyor. Malzeme var, doku yok — hata
    # mesaji da yok. modeller.py'de oldugu gibi yalnizca ad veriliyor.
    img.name = "atlas"
    modeller.malzeme_ata(mesh, img)

    arm = rig.iskelet_kur(KEMIKLER)
    sayim = agirlik_ata(mesh)
    mesh.parent = arm
    mod = mesh.modifiers.new("iskelet", "ARMATURE")
    mod.object = arm

    sureler, adimlar = animasyonlari_uret(arm)
    rig.disa_aktar(mesh, arm, os.path.join(VARLIK, "oyuncu.gltf"))

    ucgen = modeller.ucgen_say(mesh)
    boy = max(v.co.z for v in mesh.data.vertices)
    olcum = {
        "ucgen": ucgen,
        "boy_m": round(boy, 3),
        "kemik": len(KEMIKLER),
        # Ayak IK'sı bu uzunlukları kullanıyor: uyluk + baldır, bacağın
        # uzanabileceği azami mesafe.
        "uyluk_m": round(KALCA_Z - DIZ_Z, 3),
        "baldir_m": round(DIZ_Z - BILEK_Z, 3),
        "bilek_m": round(BILEK_Z, 3),
        "teksel_m": round(yogunluk, 1),
        "animasyon": {ad: round(sn, 3) for ad, sn in sureler.items()},
        # Adım boyu ve kayma oranı: `karakter_testi` bütçeyi burdan okuyor.
        "adim_m": {ad: round(m, 3) for ad, m in adimlar.items()},
        "hiz": dict(HIZ),
        "kayma": {ad: round(HIZ[ad] * sureler[ad] / adimlar[ad], 2)
                  for ad in adimlar},
        "kemik_koseleri": sayim,
    }
    yol = os.path.join(VARLIK, "oyuncu_olcum.json")
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(olcum, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("oyuncu: %d üçgen, %.2f m boy, %d kemik, %.0f teksel/m" % (
        ucgen, boy, len(KEMIKLER), yogunluk))
    print("animasyonlar: %s" % ", ".join(
        "%s %.2f sn" % (a, s) for a, s in sureler.items()))
    for ad in adimlar:
        print("%s: adim %.2f m, cevrim %.2f sn, kayma %.2fx, %.1f adim/sn" % (
            ad, adimlar[ad], sureler[ad],
            HIZ[ad] * sureler[ad] / adimlar[ad], 2.0 / sureler[ad]))
    print("ölçüm -> %s" % yol)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
