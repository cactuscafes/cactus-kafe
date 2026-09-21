"""Cactus 3B — Faz 16: bölüm sonu canavarı (Blender / bpy).

    pip install bpy pillow
    python3 oyun3d/araclar/boss_karakter.py

NEDEN VAR: üç düşman türü var (Faz 14) ama öğrenileni SINAYAN tek bir
karşılaşma yok. Final bölümü zorluğu düşman yoğunluğuyla kuruyordu; yoğunluk
bir doruk değil, aynı şeyin daha fazlası.

SİLUET: ailenin parçası ama iri ve ALÇAK — dikenli küre ailesinden, dört kat
büyümüş, sırtı plakalı, iki ön kolu var. Oyuncu onu ilk gördüğünde "bu aynı
düşman değil" demeli; boyu (2,6 m) ve genişliği (2,2 m) bunu tek bakışta
söylüyor.

TASARIM KURALI — HER SALDIRININ BİR AÇIĞI VAR: saldırı kalıpları bitince
canavar yoruluyor (`sersem` animasyonu: kafa yerde, gövde alçak). Oyuncunun
üstüne binebileceği tek an o. Bu yüzden `sersem` pozu diğerlerinden BARİZ
farklı olmak zorunda — dövüşün ritmi o pozun okunmasına bağlı.
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

import modeller
import rig

KARE_HIZI = rig.KARE_HIZI

# --- ölçüler (metre, Blender Z-up; taban z=0) -------------------------------
GOVDE_Z = 1.45
GOVDE_R = 0.86
KALCA_Z = 1.05
AYAK_Z = 0.12
BACAK_X = 0.42
OMUZ_X = 0.72
OMUZ_Z = 1.70
EL_Z = 0.95
KAFA_Y = 0.40
AGIZ_Y = 1.00

KEMIKLER = [
    ("Kok", (0, 0, KALCA_Z), (0, 0, GOVDE_Z), None),
    ("Govde", (0, 0, GOVDE_Z), (0, 0, 2.05), "Kok"),
    ("Kafa", (0, KAFA_Y, 1.80), (0, AGIZ_Y, 1.66), "Govde"),
    ("Cene", (0, KAFA_Y + 0.05, 1.56), (0, AGIZ_Y, 1.48), "Kafa"),
    ("KolSol", (-OMUZ_X, 0, OMUZ_Z), (-OMUZ_X - 0.24, 0, EL_Z), "Govde"),
    ("KolSag", (OMUZ_X, 0, OMUZ_Z), (OMUZ_X + 0.24, 0, EL_Z), "Govde"),
    ("BacakSol", (-BACAK_X, 0, KALCA_Z), (-BACAK_X - 0.06, 0, AYAK_Z), "Kok"),
    ("BacakSag", (BACAK_X, 0, KALCA_Z), (BACAK_X + 0.06, 0, AYAK_Z), "Kok"),
    ("Kuyruk", (0, -0.55, 1.35), (0, -1.15, 1.62), "Kok"),
]

## Kemiğin yerel X'inde pozitif dönüş dünyada hangi yöne gidiyor (bkz. rig.py).
_YON = {"Kok": 1.0, "Govde": 1.0, "Kafa": 1.0, "Cene": 1.0, "Kuyruk": 1.0,
        "KolSol": -1.0, "KolSag": -1.0, "BacakSol": -1.0, "BacakSag": -1.0}

## `betikler/boss.gd` ile aynı olmalı; test karşılaştırıyor.
HIZ = {"yurume": 2.6}
KAYMA_HEDEFI = 2.0
ASGARI_CEVRIM = 0.45


def govde_mesh() -> bpy.types.Object:
    """İri gövde + sırt plakaları + çene + iki kol + iki bacak + kuyruk."""
    rast = random.Random(31)
    bm = bmesh.new()
    govde = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=GOVDE_R)["verts"]
    for v in govde:
        v.co.z *= 0.78
        v.co.y *= 1.08
    bmesh.ops.translate(bm, verts=govde, vec=(0, 0, GOVDE_Z))

    # Sırt plakaları: büyük, geriye yatık koniler. Dikenli küre ailesinin
    # işareti ama daha az ve daha iri — uzaktan "zırhlı" okunuyor.
    for i in range(6):
        aci = -0.9 + i * 0.36
        boy = 0.42 + rast.random() * 0.30
        plaka = bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=4,
            radius1=0.20, radius2=0.0, depth=boy,
        )["verts"]
        bmesh.ops.rotate(bm, verts=plaka, cent=(0, 0, 0),
                         matrix=Matrix.Rotation(math.radians(-28), 3, "X"))
        bmesh.ops.translate(bm, verts=plaka, vec=(
            math.sin(aci) * 0.50, -0.10 - math.cos(aci) * 0.18,
            GOVDE_Z + 0.52 + boy * 0.3))

    # Kafa ve çene: öne uzanan kama + altında açılan çene.
    rig.kutu(bm, (0, (KAFA_Y + AGIZ_Y) * 0.5, 1.76), (0.62, AGIZ_Y - KAFA_Y, 0.38),
             egim=0.35)
    rig.kutu(bm, (0, (KAFA_Y + AGIZ_Y) * 0.5 + 0.04, 1.50),
             (0.54, AGIZ_Y - KAFA_Y - 0.06, 0.20), egim=0.5)

    # Kollar: omuzdan yere inen iri kütükler; çarpma saldırısını bunlar yapıyor.
    for isaret in (-1, 1):
        rig.kutu(bm, (isaret * (OMUZ_X + 0.12), 0, (OMUZ_Z + EL_Z) * 0.5),
                 (0.34, 0.36, OMUZ_Z - EL_Z + 0.36), egim=-0.15)
        # Yumruk: kolun ucunda, çarpma anında yere inen parça.
        rig.kutu(bm, (isaret * (OMUZ_X + 0.26), 0, EL_Z - 0.12),
                 (0.42, 0.44, 0.34))

    # Bacaklar: kısa ve kalın; canavar ağır görünmeli.
    for isaret in (-1, 1):
        rig.kutu(bm, (isaret * (BACAK_X + 0.03), 0, (KALCA_Z + AYAK_Z) * 0.5),
                 (0.36, 0.40, KALCA_Z - AYAK_Z + 0.14), egim=-0.2)

    kuyruk = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=4,
        radius1=0.26, radius2=0.0, depth=0.8,
    )["verts"]
    bmesh.ops.rotate(bm, verts=kuyruk, cent=(0, 0, 0),
                     matrix=Matrix.Rotation(math.radians(108), 3, "X"))
    bmesh.ops.translate(bm, verts=kuyruk, vec=(0, -0.85, 1.50))

    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("boss")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("boss", me)
    bpy.context.collection.objects.link(obj)
    return obj


def _kemik_sec(ko) -> str:
    if ko.z < KALCA_Z - 0.05 and abs(ko.x) < OMUZ_X - 0.1:
        return "BacakSag" if ko.x > 0 else "BacakSol"
    if abs(ko.x) > OMUZ_X - 0.25 and ko.z < OMUZ_Z + 0.3:
        return "KolSag" if ko.x > 0 else "KolSol"
    if ko.y > KAFA_Y - 0.05 and ko.z < 1.66:
        return "Cene"
    if ko.y > KAFA_Y - 0.05:
        return "Kafa"
    if ko.y < -0.55 and ko.z > 1.2:
        return "Kuyruk"
    if ko.z > GOVDE_Z + 0.1:
        return "Govde"
    return "Kok"


def agirlik_ata(obj: bpy.types.Object) -> dict[str, int]:
    for ad, *_ in KEMIKLER:
        obj.vertex_groups.new(name=ad)
    sayim: dict[str, int] = {ad: 0 for ad, *_ in KEMIKLER}
    for v in obj.data.vertices:
        ana = _kemik_sec(v.co)
        sayim[ana] += 1
        if ana.startswith("Bacak") and v.co.z > KALCA_Z - 0.2:
            pay = min(1.0, (v.co.z - (KALCA_Z - 0.2)) / 0.2) * 0.5
            obj.vertex_groups[ana].add([v.index], 1.0 - pay, "REPLACE")
            obj.vertex_groups["Kok"].add([v.index], pay, "REPLACE")
        elif ana.startswith("Kol") and v.co.z > OMUZ_Z - 0.18:
            obj.vertex_groups[ana].add([v.index], 0.6, "REPLACE")
            obj.vertex_groups["Govde"].add([v.index], 0.4, "REPLACE")
        elif ana == "Cene" and v.co.y < KAFA_Y + 0.12:
            obj.vertex_groups[ana].add([v.index], 0.6, "REPLACE")
            obj.vertex_groups["Kafa"].add([v.index], 0.4, "REPLACE")
        else:
            obj.vertex_groups[ana].add([v.index], 1.0, "REPLACE")
    return sayim


def _anahtar(arm, kare, acilar, konum=None) -> None:
    rig.anahtar(arm, kare, acilar, _YON, "Kok", konum)


def _poz(kok=0.0, govde=0.0, kafa=0.0, cene=0.0, kol_sol=0.0, kol_sag=0.0,
         bacak_sol=0.0, bacak_sag=0.0, kuyruk=0.0) -> dict:
    return {
        "Kok": (kok, 0.0, 0.0), "Govde": (govde, 0.0, 0.0),
        "Kafa": (kafa, 0.0, 0.0), "Cene": (cene, 0.0, 0.0),
        "KolSol": (kol_sol, 0.0, 0.0), "KolSag": (kol_sag, 0.0, 0.0),
        "BacakSol": (bacak_sol, 0.0, 0.0), "BacakSag": (bacak_sag, 0.0, 0.0),
        "Kuyruk": (kuyruk, 0.0, 0.0),
    }


def animasyonlari_uret(arm: bpy.types.Object) -> tuple[dict, dict]:
    """Sekiz animasyon; her biri dövüşün bir evresine karşılık geliyor."""
    sureler: dict[str, float] = {}
    adimlar: dict[str, float] = {}

    def kare(sn: float) -> float:
        return 1.0 + sn * KARE_HIZI

    # boşta: ağır nefes. İri şeyin yavaş kıpırdaması onu ağır gösteriyor.
    eylem = rig.eylem(arm, "bosta")
    for t, yuk, cene in ((0.0, 0.0, 0.0), (1.1, 0.045, 0.1), (2.2, 0.0, 0.0)):
        _anahtar(arm, kare(t), _poz(govde=-0.04 if yuk > 0 else 0.0, cene=cene,
                                    kuyruk=0.08 if yuk > 0 else 0.0),
                 (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, True)
    sureler["bosta"] = 2.2

    # yürüme: ağır adımlar. Süre adım boyundan hesaplanıyor (bkz. rig.adim_olc).
    eylem = rig.eylem(arm, "yurume")
    sure = 1.2
    for k in range(9):
        t = sure * k / 8.0
        f = math.tau * k / 8.0
        _anahtar(arm, kare(t), _poz(
            govde=0.06, kafa=-0.05,
            kol_sol=math.sin(f + math.pi) * 0.32, kol_sag=math.sin(f) * 0.32,
            bacak_sol=math.sin(f) * 0.42, bacak_sag=math.sin(f + math.pi) * 0.42,
            kuyruk=math.sin(f) * 0.12),
            (0.0, 0.0, abs(math.sin(f)) * 0.05 - 0.025))
    adim = rig.adim_olc(arm, sure, ("BacakSol", "BacakSag"), uc=True)
    gereken = max(adim * KAYMA_HEDEFI / HIZ["yurume"], ASGARI_CEVRIM)
    rig.zamani_olcekle(eylem, gereken / sure)
    rig.bitir(eylem, arm, True)
    sureler["yurume"] = gereken
    adimlar["yurume"] = adim

    # çarpma: TELGRAF (kollar yukarı, gövde geri) → vuruş → toparlanma.
    # Telgraf süresi kodla aynı olmak zorunda (`boss.gd::carpma_telgrafi`);
    # oyuncunun kaçma penceresi o pozun görüldüğü an başlıyor.
    eylem = rig.eylem(arm, "carpma")
    for t, govde, kol, cene, yuk in ((0.0, 0.0, 0.0, 0.0, 0.0),
                                     (0.45, -0.35, -1.25, 0.6, 0.10),
                                     (0.62, 0.45, 0.95, 0.2, -0.18),
                                     (1.10, 0.0, 0.0, 0.0, 0.0)):
        _anahtar(arm, kare(t), _poz(kok=govde * 0.5, govde=govde, kafa=-govde * 0.4,
                                    cene=cene, kol_sol=kol, kol_sag=kol,
                                    kuyruk=-govde * 0.6), (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["carpma"] = 1.10

    # atış: kafa geri, çene açılır, öne savrulur (diken yağmuru).
    eylem = rig.eylem(arm, "atis")
    for t, kafa, cene, govde in ((0.0, 0.0, 0.0, 0.0), (0.38, -0.5, 0.9, -0.2),
                                 (0.55, 0.35, 0.25, 0.15), (0.90, 0.0, 0.0, 0.0)):
        _anahtar(arm, kare(t), _poz(govde=govde, kafa=kafa, cene=cene,
                                    kol_sol=-0.2, kol_sag=-0.2))
    rig.bitir(eylem, arm, False)
    sureler["atis"] = 0.90

    # sersem: DÖVÜŞÜN AÇIĞI. Kafa yerde, gövde çökük, kollar sarkık.
    # Diğer pozlardan bariz farklı: oyuncu bu pozu görünce üstüne binmeli.
    eylem = rig.eylem(arm, "sersem")
    for t, yuk, sallanma in ((0.0, -0.22, 0.0), (0.6, -0.26, 0.08), (1.2, -0.22, 0.0)):
        _anahtar(arm, kare(t), _poz(kok=0.30, govde=0.55, kafa=0.45 + sallanma,
                                    cene=0.35, kol_sol=0.55, kol_sag=0.55,
                                    bacak_sol=0.25, bacak_sag=-0.25,
                                    kuyruk=-0.35), (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, True)
    sureler["sersem"] = 1.2

    # sarsılma: vuruş yedi. Kısa ve sert.
    eylem = rig.eylem(arm, "sarsilma")
    for t, govde, yuk in ((0.0, 0.0, 0.0), (0.10, 0.5, -0.12), (0.45, 0.0, 0.0)):
        _anahtar(arm, kare(t), _poz(kok=govde * 0.5, govde=govde, kafa=govde * 0.5,
                                    cene=0.5, kol_sol=0.3, kol_sag=0.3),
                 (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["sarsilma"] = 0.45

    # kükreme: evre değişimi. Şahlanış — "bu iş daha bitmedi" karesi.
    eylem = rig.eylem(arm, "kukreme")
    for t, govde, cene, kol, yuk in ((0.0, 0.0, 0.0, 0.0, 0.0),
                                     (0.30, -0.55, 1.0, -1.1, 0.16),
                                     (0.75, -0.40, 0.8, -0.9, 0.12),
                                     (1.10, 0.0, 0.0, 0.0, 0.0)):
        _anahtar(arm, kare(t), _poz(kok=govde * 0.6, govde=govde, kafa=govde * 0.8,
                                    cene=cene, kol_sol=kol, kol_sag=kol,
                                    kuyruk=-govde), (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["kukreme"] = 1.10

    # yenilme: öne çöküş. Erime efekti bunun üstünde çalışıyor.
    eylem = rig.eylem(arm, "yenildi")
    for t, govde, yuk, bacak in ((0.0, 0.0, 0.0, 0.0), (0.35, -0.3, 0.05, -0.2),
                                 (0.85, 0.9, -0.45, 0.6), (1.40, 1.0, -0.55, 0.7)):
        _anahtar(arm, kare(t), _poz(kok=govde * 0.5, govde=govde, kafa=govde * 0.6,
                                    cene=0.6, kol_sol=govde * 0.8, kol_sag=govde * 0.8,
                                    bacak_sol=bacak, bacak_sag=bacak,
                                    kuyruk=-govde * 0.5), (0.0, 0.0, yuk))
    rig.bitir(eylem, arm, False)
    sureler["yenildi"] = 1.40
    return sureler, adimlar


def main() -> int:
    rig.temizle()
    bpy.context.scene.render.fps = int(KARE_HIZI)

    mesh = govde_mesh()
    yogunluk = modeller.uv_ac(mesh, modeller.BOLGELER["boss"])
    atlas_yolu = os.path.join(VARLIK, "atlas.png")
    if not os.path.exists(atlas_yolu):
        modeller.atlas_uret(atlas_yolu)
    img = bpy.data.images.load(atlas_yolu)
    img.name = "atlas"
    modeller.malzeme_ata(mesh, img)

    arm = rig.iskelet_kur(KEMIKLER)
    sayim = agirlik_ata(mesh)
    mesh.parent = arm
    mod = mesh.modifiers.new("iskelet", "ARMATURE")
    mod.object = arm

    sureler, adimlar = animasyonlari_uret(arm)
    rig.disa_aktar(mesh, arm, os.path.join(VARLIK, "boss.gltf"))

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
        "kemik_koseleri": sayim,
    }
    yol = os.path.join(VARLIK, "boss_olcum.json")
    with open(yol, "w", encoding="utf-8") as f:
        json.dump(olcum, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print("boss: %d üçgen, %.2f m boy, %.2f m en, %d kemik, %.0f teksel/m" % (
        ucgen, boy, en, len(KEMIKLER), yogunluk))
    print("animasyonlar: %s" % ", ".join(
        "%s %.2f sn" % (a, s) for a, s in sureler.items()))
    print("ölçüm -> %s" % yol)
    return 0


if __name__ == "__main__":
    sys.exit(main())
