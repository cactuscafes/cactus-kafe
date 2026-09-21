"""Cactus 3B — Faz 14: rig'li, iskeletli düşman (Blender / bpy).

    pip install bpy pillow
    python3 oyun3d/araclar/dusman_karakter.py

NEDEN ŞİMDİ: Faz 11-13'ten sonra oyuncu ve dünya canlı, düşman ise ekrandaki
son cansız şeydi — modellenmişti ama kemiksizdi. Hareketi `dusman.gd` ölçek
oynatarak taklit ediyordu (`_model.scale` ile ezme/germe): uzaktan iş görüyor,
yakından "kayan bir kitle" gibi duruyor. Yürümüyor, çiğnemiyor, ölürken
çökmüyor.

SİLUET KORUNDU: yuvarlak ve dikenli. Oyuncudaki kaktüs ve süslemedeki saguaro
uzun ve dik; bu yuvarlak. Tehlikeyi renkten önce siluetten tanımak gerekir —
renk körü oyuncu için tek ipucu budur (Faz 6'daki gerekçe). Faz 14 silueti
değiştirmiyor, ona çene, iki kısa bacak ve kuyruk ekliyor: hareket edebilmesi
için kıpırdayacak bir şeye ihtiyacı vardı.

ORTAK HAT: iskelet kurma, ağırlık, poz yazma ve dışa aktarım `araclar/rig.py`
içinde — oyuncuyla aynı hat. Buraya özgü olan kemik tablosu, mesh, ağırlık
bölgeleri ve animasyonlar.
"""

import json
import math
import os
import random
import sys

import bpy
import bmesh
from mathutils import Matrix

BURASI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, BURASI)
PROJE = os.path.dirname(BURASI)
VARLIK = os.path.join(PROJE, "varliklar")

import modeller  # atlas, UV açma, malzeme, üçgen sayımı
import rig       # ortak rig hattı

KARE_HIZI = rig.KARE_HIZI

# --- ölçüler (metre, Blender Z-up; taban z=0) -------------------------------
## Gövdenin merkezi ve yarıçapı. Kapsül `sahneler/dusman.tscn` içinde
## yarıçap 0.45, yükseklik 1.1 — model onun içinde kalmalı.
GOVDE_Z = 0.46
GOVDE_R = 0.40
BACAK_Z = 0.30       # kalça yüksekliği
AYAK_Z = 0.06
BACAK_X = 0.19
CENE_Y = 0.14
CENE_UC = 0.46

## (ad, baş, uç, ebeveyn) — uç, kemiğin uzadığı yön.
KEMIKLER = [
    ("Kok", (0, 0, BACAK_Z), (0, 0, GOVDE_Z), None),
    ("Govde", (0, 0, GOVDE_Z), (0, 0, 0.74), "Kok"),
    # Çene öne uzanıyor: saldırıda açılıp kapanan tek parça.
    ("Cene", (0, CENE_Y, 0.38), (0, CENE_UC, 0.32), "Kok"),
    ("BacakSol", (-BACAK_X, 0, BACAK_Z), (-BACAK_X - 0.03, 0, AYAK_Z), "Kok"),
    ("BacakSag", (BACAK_X, 0, BACAK_Z), (BACAK_X + 0.03, 0, AYAK_Z), "Kok"),
    ("Kuyruk", (0, -0.24, 0.44), (0, -0.50, 0.58), "Kok"),
]

## Kemiğin yerel X ekseninde pozitif dönüş dünyada hangi yöne gidiyor?
## Aşağı bakan bacak kemikleri ters. Bir kez ölçüldü (bkz. rig.py).
_YON = {"Kok": 1.0, "Govde": 1.0, "Cene": 1.0, "Kuyruk": 1.0,
        "BacakSol": -1.0, "BacakSag": -1.0}

## Oyunun hızları — `betikler/dusman.gd` ile aynı olmalı; test karşılaştırıyor.
HIZ = {"yurume": 1.9, "kosma": 4.3}
## Kayma oranı hedefi (bkz. karakter.py::KAYMA_HEDEFI). Düşman oyuncudan
## kısa bacaklı ve daha hızlı: aynı hedef (2,0) çevrimi 0,2 sn'ye indirip
## bacakları görünmez ederdi. 2,5 seğirten bir böcek temposu veriyor.
KAYMA_HEDEFI = 2.5
## Çevrim bundan kısa olamaz: kısa bacak + yüksek hız çarpımı animasyonu
## titreşime çeviriyor.
ASGARI_CEVRIM = 0.26


def govde_mesh() -> bpy.types.Object:
    """Dikenli gövde + çene + iki bacak + kuyruk, tek mesh.

    Parçalar ayrı nesne değil: iskelet hareketi taşıyor, ayrı nesneler olsa
    her biri ayrı draw call olurdu.
    """
    rast = random.Random(21)   # Faz 2'deki tohum: dikenler aynı yerde kalsın
    bm = bmesh.new()
    govde = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=GOVDE_R)["verts"]
    for v in govde:
        v.co.z *= 0.86
    bmesh.ops.translate(bm, verts=govde, vec=(0, 0, GOVDE_Z))

    # Dikenler: gövdenin dışına bakan küçük koniler.
    for i in range(10):
        aci = i * math.tau / 10.0
        yukseklik = 0.06 + rast.random() * 0.30
        diken = bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=4,
            radius1=0.07, radius2=0.0, depth=0.26,
        )["verts"]
        bmesh.ops.rotate(bm, verts=diken, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(math.radians(90), 3, "Y"))
        bmesh.ops.rotate(bm, verts=diken, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(aci, 3, "Z"))
        bmesh.ops.translate(bm, verts=diken, vec=(
            math.cos(aci) * 0.42, math.sin(aci) * 0.42, GOVDE_Z + yukseklik - 0.42))
    tepe = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=4,
        radius1=0.08, radius2=0.0, depth=0.3,
    )["verts"]
    bmesh.ops.translate(bm, verts=tepe, vec=(0, 0, GOVDE_Z + 0.5))

    # Çene: öne uzanan kama. Kapalıyken gövdenin altına gömülü duruyor,
    # açılınca görünüyor — "ağzı var mı?" sorusu ancak saldırıda cevaplanmalı.
    rig.kutu(bm, (0, (CENE_Y + CENE_UC) * 0.5, 0.34),
             (0.30, CENE_UC - CENE_Y, 0.14), egim=0.45)
    # Bacaklar: kısa, aşağı doğru incelen kütükler.
    for isaret in (-1, 1):
        rig.kutu(bm, (isaret * (BACAK_X + 0.015), 0, (BACAK_Z + AYAK_Z) * 0.5),
                 (0.15, 0.16, BACAK_Z - AYAK_Z + 0.08), egim=-0.25)
    # Kuyruk: arkaya yukarı kalkan koni. Yürürken sallanıyor, dengeyi
    # okutuyor; hareketin "nereye gidiyor" bilgisini artırıyor.
    kuyruk = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=4,
        radius1=0.10, radius2=0.0, depth=0.34,
    )["verts"]
    bmesh.ops.rotate(bm, verts=kuyruk, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.radians(115), 3, "X"))
    bmesh.ops.translate(bm, verts=kuyruk, vec=(0, -0.34, 0.50))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("dusman")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("dusman", me)
    bpy.context.collection.objects.link(obj)
    return obj


def _kemik_sec(ko) -> str:
    """Köşe hangi kemiğe ait? Bölgeye göre."""
    if ko.z < BACAK_Z - 0.02 and abs(ko.x) > 0.10:
        return "BacakSag" if ko.x > 0 else "BacakSol"
    if ko.y > CENE_Y - 0.01 and ko.z < GOVDE_Z + 0.02:
        return "Cene"
    if ko.y < -0.24 and ko.z > 0.40:
        return "Kuyruk"
    if ko.z > GOVDE_Z + 0.24:
        return "Govde"
    return "Kok"


def agirlik_ata(obj: bpy.types.Object) -> dict[str, int]:
    """Her köşeyi bir kemiğe bağlar, eklemde iki kemiğe paylaştırır.

    Otomatik ağırlık arayüzsüz ortamda çalışıyor ama sonucu tahmin edilemez;
    bölgeye göre elle atamak hem okunur hem tekrarlanabilir (Faz 11'deki
    gerekçenin aynısı)."""
    for ad, *_ in KEMIKLER:
        obj.vertex_groups.new(name=ad)
    sayim: dict[str, int] = {ad: 0 for ad, *_ in KEMIKLER}
    for v in obj.data.vertices:
        ana = _kemik_sec(v.co)
        sayim[ana] += 1
        if ana.startswith("Bacak") and v.co.z > BACAK_Z - 0.12:
            # Kalça hizası: bacak gövdeyle paylaşıyor, yoksa bacak kırılınca
            # mesh eklemde makaslanıyor.
            pay = min(1.0, (v.co.z - (BACAK_Z - 0.12)) / 0.12) * 0.5
            obj.vertex_groups[ana].add([v.index], 1.0 - pay, "REPLACE")
            obj.vertex_groups["Kok"].add([v.index], pay, "REPLACE")
        elif ana == "Cene" and v.co.y < CENE_Y + 0.06:
            obj.vertex_groups[ana].add([v.index], 0.6, "REPLACE")
            obj.vertex_groups["Kok"].add([v.index], 0.4, "REPLACE")
        elif ana == "Kuyruk" and v.co.y > -0.32:
            obj.vertex_groups[ana].add([v.index], 0.55, "REPLACE")
            obj.vertex_groups["Kok"].add([v.index], 0.45, "REPLACE")
        elif ana == "Govde" and v.co.z < GOVDE_Z + 0.34:
            obj.vertex_groups[ana].add([v.index], 0.6, "REPLACE")
            obj.vertex_groups["Kok"].add([v.index], 0.4, "REPLACE")
        else:
            obj.vertex_groups[ana].add([v.index], 1.0, "REPLACE")
    return sayim


def _anahtar(arm, kare, acilar, konum=None) -> None:
    rig.anahtar(arm, kare, acilar, _YON, "Kok", konum)


def animasyonlari_uret(arm: bpy.types.Object) -> tuple[dict, dict]:
    """Altı animasyon. Her biri `betikler/dusman.gd`deki BİR duruma karşılık
    geliyor; durum makinesi kodda, karşılığı burada."""
    sureler: dict[str, float] = {}
    adimlar: dict[str, float] = {}

    def kare(sn: float) -> float:
        return 1.0 + sn * KARE_HIZI

    # boşta: nefes + kuyruk salınımı. Devriye beklerken bile kıpırdamalı;
    # donmuş bir düşman "bozuk" görünüyor.
    eylem = rig.eylem(arm, "bosta")
    for t, yuk, kuyruk in ((0.0, 0.0, 0.0), (0.9, 0.025, 0.14), (1.8, 0.0, 0.0)):
        _anahtar(arm, kare(t), {
            "Kok": (0.0, 0.0, 0.0), "Govde": (-0.04 if yuk > 0 else 0.0, 0.0, 0.0),
            "Cene": (0.06 if yuk > 0 else 0.0, 0.0, 0.0),
            "Kuyruk": (0.0, 0.0, kuyruk),
            "BacakSol": (0.0, 0.0, 0.0), "BacakSag": (0.0, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, True)
    sureler["bosta"] = 1.8

    # yürüme / koşma: aynı kalıp, farklı genlik. Süre ölçümden sonra
    # hıza oturtuluyor (bkz. KAYMA_HEDEFI).
    for ad, sure, bacak, zipzip, egim in (
            ("yurume", 0.8, 0.55, 0.035, 0.05),
            ("kosma", 0.5, 0.85, 0.075, 0.22)):
        eylem = rig.eylem(arm, ad)
        for k in range(9):
            t = sure * k / 8.0
            f = math.tau * k / 8.0
            _anahtar(arm, kare(t), {
                "BacakSol": (math.sin(f) * bacak, 0.0, 0.0),
                "BacakSag": (math.sin(f + math.pi) * bacak, 0.0, 0.0),
                # Gövde adımın tersine sekiyor: iki ayak da yerdeyken alçak,
                # havadayken yüksek. Bu olmadan yürüyüş "kayma" gibi duruyor.
                "Kok": (egim * 0.4, 0.0, 0.0),
                "Govde": (egim, 0.0, 0.0),
                "Cene": (math.sin(f * 2.0) * 0.05, 0.0, 0.0),
                "Kuyruk": (0.0, 0.0, math.sin(f) * 0.22),
            }, (0.0, 0.0, abs(math.sin(f)) * zipzip - zipzip * 0.5))
        adim = rig.adim_olc(arm, sure, ("BacakSol", "BacakSag"), uc=True)
        gereken = max(adim * KAYMA_HEDEFI / HIZ[ad], ASGARI_CEVRIM)
        rig.zamani_olcekle(eylem, gereken / sure)
        rig.bitir(eylem, arm, True)
        sureler[ad] = gereken
        adimlar[ad] = adim

    # farketti: geriye irkilme + çene açılması. Oyuncuya "görüldün" diyen kare
    # bu; `dusman.gd` burada 0,45 sn bekliyor, animasyon o pencereyi dolduruyor.
    eylem = rig.eylem(arm, "farketti")
    for t, govde, cene, yuk in ((0.0, 0.0, 0.0, 0.0), (0.16, -0.38, 0.5, 0.07),
                                (0.45, -0.12, 0.2, 0.02)):
        _anahtar(arm, kare(t), {
            "Kok": (govde * 0.5, 0.0, 0.0), "Govde": (govde, 0.0, 0.0),
            "Cene": (cene, 0.0, 0.0), "Kuyruk": (govde * 0.6, 0.0, 0.0),
            "BacakSol": (-0.2, 0.0, 0.0), "BacakSag": (0.2, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["farketti"] = 0.45

    # saldırı: hazırlıkta geri yaylanma, sonra öne savrulma ve çenenin
    # kapanması. Vuruş anı `dusman.gd`deki `hazirlik` süresiyle aynı yerde.
    eylem = rig.eylem(arm, "saldiri")
    for t, govde, cene, ileri in ((0.0, 0.0, 0.1, 0.0), (0.26, -0.45, 0.75, -0.06),
                                  (0.38, 0.55, -0.1, 0.12), (0.62, 0.0, 0.05, 0.0)):
        _anahtar(arm, kare(t), {
            "Kok": (govde * 0.6, 0.0, 0.0), "Govde": (govde, 0.0, 0.0),
            "Cene": (cene, 0.0, 0.0), "Kuyruk": (-govde * 0.5, 0.0, 0.0),
            "BacakSol": (-0.25, 0.0, 0.0), "BacakSag": (0.25, 0.0, 0.0),
        }, (0.0, ileri, 0.0))
    rig.bitir(eylem, arm, False)
    sureler["saldiri"] = 0.62

    # zıplama: hoplayan alt türü (betikler/dusman_hoplayan.gd) için. Üç evre:
    # çömelme (telgraf), havada gerilme, inişte çöküş. Telgraf olmadan zıplama
    # "haksız" hissettiriyor — oyuncunun kaçacak penceresi görünmüyor.
    eylem = rig.eylem(arm, "zipla")
    for t, bacak, govde, yuk in ((0.0, 0.0, 0.0, 0.0), (0.22, 0.85, 0.3, -0.10),
                                 (0.38, -0.55, -0.35, 0.06), (0.75, 0.0, 0.0, 0.0)):
        _anahtar(arm, kare(t), {
            "Kok": (govde * 0.4, 0.0, 0.0), "Govde": (govde, 0.0, 0.0),
            "Cene": (0.35 if yuk < 0 else 0.1, 0.0, 0.0),
            "Kuyruk": (-govde * 0.8, 0.0, 0.0),
            "BacakSol": (bacak, 0.0, 0.0), "BacakSag": (bacak, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["zipla"] = 0.75

    # ezildi: üstüne binildi. Gövde yassılıyor, bacaklar yana açılıyor.
    eylem = rig.eylem(arm, "ezildi")
    for t, yuk, bacak in ((0.0, 0.0, 0.0), (0.08, -0.16, 0.9), (0.34, 0.0, 0.1)):
        _anahtar(arm, kare(t), {
            "Kok": (0.0, 0.0, 0.0), "Govde": (0.25 if yuk < 0 else 0.0, 0.0, 0.0),
            "Cene": (0.8 if yuk < 0 else 0.1, 0.0, 0.0),
            "Kuyruk": (-0.5 if yuk < 0 else 0.0, 0.0, 0.0),
            "BacakSol": (0.0, 0.0, bacak), "BacakSag": (0.0, 0.0, -bacak),
        }, (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["ezildi"] = 0.34
    return sureler, adimlar


def main() -> int:
    rig.temizle()
    bpy.context.scene.render.fps = int(KARE_HIZI)

    mesh = govde_mesh()
    yogunluk = modeller.uv_ac(mesh, modeller.BOLGELER["dusman"])
    atlas_yolu = os.path.join(VARLIK, "atlas.png")
    if not os.path.exists(atlas_yolu):
        modeller.atlas_uret(atlas_yolu)
    img = bpy.data.images.load(atlas_yolu)
    # TUZAK (Faz 11): burada `img.filepath` yazılırsa dışa aktarıcı dokuyu
    # sessizce atlıyor ve düşman oyunda BEYAZ çıkıyor. Yalnızca ad veriliyor.
    img.name = "atlas"
    modeller.malzeme_ata(mesh, img)

    arm = rig.iskelet_kur(KEMIKLER)
    sayim = agirlik_ata(mesh)
    mesh.parent = arm
    mod = mesh.modifiers.new("iskelet", "ARMATURE")
    mod.object = arm

    sureler, adimlar = animasyonlari_uret(arm)
    rig.disa_aktar(mesh, arm, os.path.join(VARLIK, "dusman.gltf"))

    ucgen = modeller.ucgen_say(mesh)
    boy = max(v.co.z for v in mesh.data.vertices)
    en = max(v.co.x for v in mesh.data.vertices) * 2.0
    olcum = {
        "ucgen": ucgen,
        "boy_m": round(boy, 3),
        "en_m": round(en, 3),
        "kemik": len(KEMIKLER),
        "teksel_m": round(yogunluk, 1),
        "animasyon": {ad: round(sn, 3) for ad, sn in sureler.items()},
        "adim_m": {ad: round(m, 3) for ad, m in adimlar.items()},
        "hiz": dict(HIZ),
        "kayma": {ad: round(HIZ[ad] * sureler[ad] / adimlar[ad], 2)
                  for ad in adimlar},
        "kemik_koseleri": sayim,
    }
    yol = os.path.join(VARLIK, "dusman_olcum.json")
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(olcum, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("düşman: %d üçgen, %.2f m boy, %d kemik, %.0f teksel/m" % (
        ucgen, boy, len(KEMIKLER), yogunluk))
    print("animasyonlar: %s" % ", ".join(
        "%s %.2f sn" % (a, s) for a, s in sureler.items()))
    for ad in adimlar:
        print("%s: adim %.2f m, cevrim %.2f sn, kayma %.2fx" % (
            ad, adimlar[ad], sureler[ad], HIZ[ad] * sureler[ad] / adimlar[ad]))
    print("ölçüm -> %s" % yol)
    return 0


if __name__ == "__main__":
    sys.exit(main())
