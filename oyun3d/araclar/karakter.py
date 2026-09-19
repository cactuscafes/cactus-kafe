"""Cactus 3B — Faz 11: rig'li, iskeletli oyuncu karakteri (Blender / bpy).

    pip install bpy pillow
    python3 oyun3d/araclar/karakter.py

Ne yapar: low-poly bir kaktüs karakteri modeller, ona yedi kemikli bir iskelet
kurar, mesh'i kemiklere bağlar (skinning), beş animasyonu (boşta, yürüme,
koşma, zıplama, düşme) keyframe'ler ve hepsini tek bir glTF olarak
`varliklar/oyuncu.gltf` dosyasına yazar.

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

## Kemik adları Godot'ya aynen geçiyor; animasyon izleri bu adlara bağlı.
KEMIKLER = [
    # ad, baş, uç, ebeveyn
    ("Kalca", (0, 0, KALCA_Z), (0, 0, KALCA_Z + 0.18), None),
    ("Govde", (0, 0, KALCA_Z + 0.18), (0, 0, GOVDE_Z), "Kalca"),
    ("Kafa", (0, 0, GOVDE_Z), (0, 0, KAFA_Z), "Govde"),
    ("KolSol", (-KOL_X, 0, KOL_Z), (-KOL_X - 0.10, 0, KOL_Z + 0.34), "Govde"),
    ("KolSag", (KOL_X, 0, KOL_Z), (KOL_X + 0.10, 0, KOL_Z + 0.34), "Govde"),
    ("BacakSol", (-BACAK_X, 0, KALCA_Z), (-BACAK_X, 0, AYAK), "Kalca"),
    ("BacakSag", (BACAK_X, 0, KALCA_Z), (BACAK_X, 0, AYAK), "Kalca"),
]

KARE_HIZI = 30.0


def _temizle() -> None:
    for koleksiyon in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures,
                       bpy.data.actions, bpy.data.materials, bpy.data.images):
        for veri in list(koleksiyon):
            koleksiyon.remove(veri, do_unlink=True)


def _kutu(bm, merkez, olcu, egim=0.0):
    """Eksen hizalı kutu; `egim` üst yüzü daraltır (koniklik)."""
    cx, cy, cz = merkez
    gx, gy, gz = (o * 0.5 for o in olcu)
    ust = 1.0 - egim
    kose = [
        (cx - gx, cy - gy, cz - gz), (cx + gx, cy - gy, cz - gz),
        (cx + gx, cy + gy, cz - gz), (cx - gx, cy + gy, cz - gz),
        (cx - gx * ust, cy - gy * ust, cz + gz), (cx + gx * ust, cy - gy * ust, cz + gz),
        (cx + gx * ust, cy + gy * ust, cz + gz), (cx - gx * ust, cy + gy * ust, cz + gz),
    ]
    v = [bm.verts.new(k) for k in kose]
    for yuz in [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
                (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
        bm.faces.new([v[i] for i in yuz])
    return v


def govde_mesh() -> bpy.types.Object:
    """Kaktüs karakter: gövde, kafa, iki kol pedi, iki bacak.

    Parçalar ayrı ada değil tek mesh: iskelet zaten hareketi taşıyor, ayrı
    nesneler olsa her biri ayrı draw call olurdu.
    """
    bm = bmesh.new()
    # Gövde: yukarı doğru hafif incelen bir prizma.
    _kutu(bm, (0, 0, (KALCA_Z + GOVDE_Z) * 0.5 - 0.03),
          (0.46, 0.34, GOVDE_Z - KALCA_Z + 0.30), egim=0.12)
    # Kafa: kaktüsün tepesi, gövdeden dar.
    _kutu(bm, (0, 0, (GOVDE_Z + KAFA_Z) * 0.5 + 0.06),
          (0.36, 0.30, KAFA_Z - GOVDE_Z + 0.16), egim=0.18)
    # Kollar: saguaro pedi gibi yana çıkıp yukarı dönüyor.
    for isaret in (-1, 1):
        _kutu(bm, (isaret * (KOL_X + 0.02), 0, KOL_Z + 0.02), (0.20, 0.17, 0.15))
        _kutu(bm, (isaret * (KOL_X + 0.07), 0, KOL_Z + 0.20), (0.15, 0.15, 0.30))
    # Bacaklar.
    for isaret in (-1, 1):
        _kutu(bm, (isaret * BACAK_X, 0, KALCA_Z * 0.5), (0.17, 0.17, KALCA_Z + 0.04))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("oyuncu")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("oyuncu", me)
    bpy.context.collection.objects.link(obj)
    return obj


def iskelet_kur() -> bpy.types.Object:
    arm_veri = bpy.data.armatures.new("iskelet")
    arm = bpy.data.objects.new("iskelet", arm_veri)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for ad, bas, uc, ebeveyn in KEMIKLER:
        kemik = arm_veri.edit_bones.new(ad)
        kemik.head = Vector(bas)
        kemik.tail = Vector(uc)
        if ebeveyn is not None:
            kemik.parent = arm_veri.edit_bones[ebeveyn]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def _kemik_sec(ko: Vector) -> str:
    """Bir köşe hangi kemiğe ait? Bölgeye göre: bacak / kol / kafa / gövde.

    Ağırlıklar keskin (0/1) değil, eklem çevresinde yumuşatılıyor
    (`agirlik_ata`); burada yalnızca ana kemik seçiliyor.
    """
    if ko.z < KALCA_Z - 0.02 and abs(ko.x) > 0.04:
        return "BacakSol" if ko.x < 0 else "BacakSag"
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
_YON = {"BacakSol": -1.0, "BacakSag": -1.0, "KolSol": 1.0, "KolSag": 1.0,
        "Govde": 1.0, "Kafa": 1.0, "Kalca": 1.0}


def _poz(arm: bpy.types.Object, ad: str) -> bpy.types.PoseBone:
    kemik = arm.pose.bones[ad]
    kemik.rotation_mode = "XYZ"
    return kemik


def _anahtar(arm: bpy.types.Object, kare: float, acilar: dict[str, tuple],
             konum: tuple | None = None) -> None:
    for ad, aci in acilar.items():
        kemik = _poz(arm, ad)
        kemik.rotation_euler = (aci[0] * _YON[ad], aci[1], aci[2])
        kemik.keyframe_insert("rotation_euler", frame=kare)
    kalca = _poz(arm, "Kalca")
    kalca.location = Vector(konum or (0.0, 0.0, 0.0))
    kalca.keyframe_insert("location", frame=kare)


def _eylem(arm: bpy.types.Object, ad: str) -> bpy.types.Action:
    eylem = bpy.data.actions.new(ad)
    eylem.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = eylem
    # Blender 4.4+ "slot"lu eylemler: keyframe eklemeden önce slot atanmazsa
    # anahtarlar hiçbir yere yazılmıyor ve dışa aktarımda animasyon boş çıkıyor.
    if hasattr(arm.animation_data, "action_slot") and eylem.slots:
        arm.animation_data.action_slot = eylem.slots[0]
    return eylem


def _bitir(eylem: bpy.types.Action, arm: bpy.types.Object, dongu: bool) -> None:
    eylem.use_cyclic = dongu
    arm.animation_data.action = None


def animasyonlari_uret(arm: bpy.types.Object) -> dict[str, float]:
    """Beş animasyon. Hareket dili Faz 1'deki yordamsal sürümle aynı tutuldu:
    oyunun hissi değişmemeli, yalnızca altındaki iskelet değişmeli."""
    sureler: dict[str, float] = {}

    def kare(sn: float) -> float:
        return 1.0 + sn * KARE_HIZI

    # boşta: hafif nefes, kollar dışa açık
    eylem = _eylem(arm, "bosta")
    for t, yuk in ((0.0, 0.0), (1.3, 0.022), (2.6, 0.0)):
        _anahtar(arm, kare(t), {
            "Govde": (0.0, 0.0, 0.0), "Kafa": (0.0, 0.0, 0.0),
            "KolSol": (0.05 if t == 1.3 else 0.0, 0.0, 0.10),
            "KolSag": (-0.05 if t == 1.3 else 0.0, 0.0, -0.10),
            "BacakSol": (0.0, 0.0, 0.0), "BacakSag": (0.0, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    _bitir(eylem, arm, True)
    sureler["bosta"] = 2.6

    # yürüme / koşma: aynı kalıp, farklı genlik ve süre
    for ad, sure, bacak, kol, zipzip, egim in (
            ("yurume", 0.9, 0.45, 0.28, 0.04, 0.03),
            ("kosma", 0.55, 0.85, 0.55, 0.09, 0.16)):
        eylem = _eylem(arm, ad)
        for k in range(9):
            t = sure * k / 8.0
            f = math.tau * k / 8.0
            _anahtar(arm, kare(t), {
                "BacakSol": (math.sin(f) * bacak, 0.0, 0.0),
                "BacakSag": (math.sin(f + math.pi) * bacak, 0.0, 0.0),
                "KolSol": (math.sin(f + math.pi) * kol, 0.0, 0.10),
                "KolSag": (math.sin(f) * kol, 0.0, -0.10),
                "Govde": (egim, 0.0, 0.0),
                "Kafa": (-egim * 0.6, 0.0, 0.0),   # baş yere değil ileri baksın
            }, (0.0, 0.0, abs(math.sin(f)) * zipzip - zipzip * 0.5))
        _bitir(eylem, arm, True)
        sureler[ad] = sure

    # zıplama: çöküp itme
    eylem = _eylem(arm, "zipla")
    for t, bacak_s, bacak_g, kol, egim, yuk in (
            (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
            (0.18, -0.9, 0.5, -1.1, -0.12, 0.05),
            (0.45, -0.5, 0.25, -0.8, -0.05, 0.02)):
        _anahtar(arm, kare(t), {
            "BacakSol": (bacak_s, 0.0, 0.0), "BacakSag": (bacak_g, 0.0, 0.0),
            "KolSol": (kol, 0.0, 0.16), "KolSag": (kol, 0.0, -0.16),
            "Govde": (egim, 0.0, 0.0), "Kafa": (0.0, 0.0, 0.0),
        }, (0.0, 0.0, yuk))
    _bitir(eylem, arm, False)
    sureler["zipla"] = 0.45

    # düşme: bacaklar açık, kollar yukarı
    eylem = _eylem(arm, "dusme")
    for t, sallanma in ((0.0, 0.0), (0.4, 0.12), (0.8, 0.0)):
        _anahtar(arm, kare(t), {
            "BacakSol": (-0.35 + sallanma, 0.0, 0.0),
            "BacakSag": (0.3 - sallanma, 0.0, 0.0),
            "KolSol": (-1.3, 0.0, 0.22), "KolSag": (-1.3, 0.0, -0.22),
            "Govde": (-0.08, 0.0, 0.0), "Kafa": (0.05, 0.0, 0.0),
        }, (0.0, 0.0, 0.0))
    _bitir(eylem, arm, True)
    sureler["dusme"] = 0.8
    return sureler


def disa_aktar(mesh: bpy.types.Object, arm: bpy.types.Object, yol: str) -> None:
    for o in bpy.context.scene.objects:
        o.select_set(False)
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=yol,
        export_format="GLTF_SEPARATE",
        use_selection=True,
        export_yup=True,
        export_apply=False,          # skinning'li mesh'te modifier uygulanmaz
        export_skins=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_bake_animation=True,
        export_optimize_animation_size=False,
        export_keep_originals=True,
    )


def main() -> int:
    _temizle()
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

    arm = iskelet_kur()
    sayim = agirlik_ata(mesh)
    mesh.parent = arm
    mod = mesh.modifiers.new("iskelet", "ARMATURE")
    mod.object = arm

    sureler = animasyonlari_uret(arm)
    disa_aktar(mesh, arm, os.path.join(VARLIK, "oyuncu.gltf"))

    ucgen = modeller.ucgen_say(mesh)
    boy = max(v.co.z for v in mesh.data.vertices)
    olcum = {
        "ucgen": ucgen,
        "boy_m": round(boy, 3),
        "kemik": len(KEMIKLER),
        "teksel_m": round(yogunluk, 1),
        "animasyon": {ad: round(sn, 2) for ad, sn in sureler.items()},
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
    print("ölçüm -> %s" % yol)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
