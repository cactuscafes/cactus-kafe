"""Cactus 3B — Faz 2 varlık üretimi (Blender'ın bpy modülü ile).

    pip install bpy pillow
    python3 oyun3d/araclar/modeller.py

Ne yapar: beş low-poly nesneyi modeller, UV açar, ortak bir doku atlasına
yerleştirir, malzemesini kurar ve `varliklar/` altına glTF olarak dışa aktarır.
Ayrıca her nesnenin üçgen sayısını, ölçüsünü ve doku yoğunluğunu ölçüp
`varliklar/olcum.json` dosyasına yazar.

NEDEN BETİK, NEDEN ELLE DEĞİL: Bu ortamda Blender'ın arayüzü yok. Betikle
modellemek elle modellemenin yerini tutmaz — asıl amaç **üretim hattını**
kurmak: UV → atlas → malzeme → glTF → Godot → ölçek/eksen doğrulaması.
Blender'ı kendi makinende açıp aynı nesneleri elle modellediğinde, hattın geri
kalanı olduğu gibi çalışacak; sadece bu dosyanın yerine `.blend` dosyaların
geçecek.

ATLAS MANTIĞI: 2048×2048 tek doku; her nesneye yüzey alanıyla orantılı bir
bölge ayrılır (kaktüs ve kaya 1024², tabela 512×1024, çiçek 512²).
Yüzler baskın eksenlerine göre düzleme yansıtılır, hepsi **aynı ölçekte** raf
paketleyiciyle hücreye dizilir; sığmazsa yoğunluk kademeli düşürülür. Böylece
doku yoğunluğu nesne genelinde eşit kalır. Ölçüm `olcum.json` içinde, kabul
bandıyla birlikte.
"""

import json
import math
import os
import random
import sys

import bpy  # bmesh'ten önce: bpy yüklenmeden bmesh modülü kayıtlı olmuyor
import bmesh
from mathutils import Matrix
from PIL import Image

BURASI = os.path.dirname(os.path.abspath(__file__))
PROJE = os.path.dirname(BURASI)
VARLIK = os.path.join(PROJE, "varliklar")

ATLAS_PX = 2048

# Atlas alanı yüzey alanına göre paylaştırılır: 2.2 m'lik kaktüs, 0.15 m'lik
# çiçekle aynı kareyi alırsa ya kaktüs bulanık olur ya çiçekte doku israf edilir.
# (x, y, genişlik, yükseklik) piksel cinsinden. Tabela dikey bir nesne: 1.9 m
# uzunluğundaki direk kare bölgeye sığmıyor, ona uzun bir dikdörtgen veriliyor.
BOLGELER = {
    "kaktus":  (0, 0, 1024, 1024),
    "kaya":    (1024, 0, 1024, 1024),
    "sandik":  (0, 1024, 1024, 1024),
    "ahsap":   (1024, 1024, 512, 1024),
    "cicek":   (1536, 1024, 512, 512),
}

RENKLER = {
    "kaya":   (0.44, 0.43, 0.41),
    "kaktus": (0.22, 0.44, 0.27),
    "ahsap":  (0.42, 0.29, 0.17),
    "cicek":  (0.85, 0.42, 0.55),
    "sandik": (0.50, 0.37, 0.22),
}


# --- doku atlası -----------------------------------------------------------

def _kafes(x: int, y: int, tohum: int) -> float:
    """Kafes noktasında tekrarlanabilir sözde-rastgele değer (0-1)."""
    n = (x * 374761393 + y * 668265263 + tohum * 1442695040) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def _deger_gurultusu(x: float, y: float, adim: int, tohum: int) -> float:
    """Kaba kafes üstünde bilineer aradeğerlenmiş gürültü (0-1).

    Piksel başına rastgelelik yerine bunu kullanıyoruz. Sebebi iki katlı:
    ince beyaz gürültü zaten bir metre öteden görünmüyor, ama PNG'yi
    sıkıştırılamaz hâle getiriyor — atlas 6.7 MB'a çıkmıştı. Kaba kafes hem
    daha iyi görünüyor hem 10 kat küçük dosya veriyor.
    """
    gx, gy = x / adim, y / adim
    x0, y0 = int(gx), int(gy)
    fx, fy = gx - x0, gy - y0
    fx = fx * fx * (3 - 2 * fx)   # smoothstep
    fy = fy * fy * (3 - 2 * fy)
    a = _kafes(x0, y0, tohum)
    b = _kafes(x0 + 1, y0, tohum)
    c = _kafes(x0, y0 + 1, tohum)
    d = _kafes(x0 + 1, y0 + 1, tohum)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def atlas_uret(yol: str) -> None:
    """Bölgeleri desenli doldurup atlası kaydeder."""
    img = Image.new("RGB", (ATLAS_PX, ATLAS_PX), (26, 28, 26))
    px = img.load()
    for ad, (x0, y0, gen_px, yuk_px) in BOLGELER.items():
        renk = RENKLER[ad]
        tohum = hash(ad) & 0xFFFF
        for y in range(yuk_px):
            for x in range(gen_px):
                k = 0.92 + 0.16 * _deger_gurultusu(x, y, 48, tohum)
                if ad == "kaktus":
                    k *= 0.86 + 0.14 * abs(math.sin(x * math.pi / 48.0))
                    # dikenler: düzenli ızgarada, kafes gürültüsüyle seçilmiş
                    if x % 32 < 3 and y % 40 < 3 and _kafes(x // 32, y // 40, tohum) > 0.55:
                        k *= 1.9
                elif ad in ("ahsap", "sandik"):
                    dalga = math.sin((y + math.sin(x * 0.02) * 14.0) * 0.16)
                    k *= 0.86 + 0.14 * dalga
                    k *= 0.94 + 0.12 * _deger_gurultusu(x, y, 12, tohum + 1)
                elif ad == "kaya":
                    kaba = _deger_gurultusu(x, y, 96, tohum + 2)
                    ince = _deger_gurultusu(x, y, 24, tohum + 3)
                    k *= 0.80 + 0.28 * kaba + 0.12 * ince
                elif ad == "cicek":
                    dx = (x - gen_px / 2) / (gen_px / 2)
                    dy = (y - yuk_px / 2) / (yuk_px / 2)
                    k *= 1.18 - 0.45 * min(1.0, math.hypot(dx, dy))
                px[x0 + x, y0 + y] = tuple(
                    max(0, min(255, int(c * 255 * k))) for c in renk
                )
    img.save(yol, optimize=True)


# --- mesh kurucular --------------------------------------------------------

def _nesne(ad: str, bm: bmesh.types.BMesh) -> bpy.types.Object:
    me = bpy.data.meshes.new(ad)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(ad, me)
    bpy.context.collection.objects.link(obj)
    return obj


def _tabana_otur(obj: bpy.types.Object) -> None:
    """Nesnenin orijinini tabanının ortasına taşır.

    Godot'da yerleştirirken en çok işe yarayan şey bu: y = zeminin yüksekliği
    yazınca nesne zemine oturur, 'yarısı gömülü' hesabı yapmak gerekmez.
    """
    me = obj.data
    zmin = min(v.co.z for v in me.vertices)
    xort = sum(v.co.x for v in me.vertices) / len(me.vertices)
    yort = sum(v.co.y for v in me.vertices) / len(me.vertices)
    for v in me.vertices:
        v.co.x -= xort
        v.co.y -= yort
        v.co.z -= zmin


def kaya() -> bpy.types.Object:
    rast = random.Random(7)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.62)
    for v in bm.verts:
        v.co.x *= 1.0 + (rast.random() - 0.5) * 0.55
        v.co.y *= 1.0 + (rast.random() - 0.5) * 0.55
        v.co.z *= 0.62 + rast.random() * 0.30
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.3))
    return _nesne("kaya", bm)


def kaktus() -> bpy.types.Object:
    bm = bmesh.new()
    # gövde
    govde = bmesh.ops.create_cone(
        bm, cap_ends=True, cap_tris=False, segments=10,
        radius1=0.24, radius2=0.19, depth=2.2,
    )["verts"]
    bmesh.ops.translate(bm, verts=govde, vec=(0, 0, 1.1))
    # iki kol: silindir + yukarı dönen uç
    for yon, yukseklik, uzunluk in ((1.0, 1.15, 0.52), (-1.0, 1.55, 0.42)):
        yatay = bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=8,
            radius1=0.11, radius2=0.11, depth=uzunluk,
        )["verts"]
        bmesh.ops.rotate(
            bm, verts=yatay, cent=(0, 0, 0),
            matrix=Matrix.Rotation(math.radians(90), 3, "Y"),
        )
        bmesh.ops.translate(
            bm, verts=yatay, vec=(yon * (0.20 + uzunluk / 2), 0, yukseklik),
        )
        dikey = bmesh.ops.create_cone(
            bm, cap_ends=True, cap_tris=False, segments=8,
            radius1=0.11, radius2=0.09, depth=0.55,
        )["verts"]
        bmesh.ops.translate(
            bm, verts=dikey,
            vec=(yon * (0.20 + uzunluk), 0, yukseklik + 0.24),
        )
    return _nesne("kaktus", bm)


def tabela() -> bpy.types.Object:
    bm = bmesh.new()
    direk = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, verts=direk, vec=(0.09, 0.09, 1.9))
    bmesh.ops.translate(bm, verts=direk, vec=(0, 0, 0.95))
    tahta = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, verts=tahta, vec=(1.15, 0.07, 0.42))
    bmesh.ops.translate(bm, verts=tahta, vec=(0, 0, 1.62))
    bmesh.ops.rotate(
        bm, verts=tahta, cent=(0, 0, 1.62),
        matrix=Matrix.Rotation(math.radians(-7), 3, "Y"),
    )
    return _nesne("tabela", bm)


def sandik() -> bpy.types.Object:
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=0.8)
    bmesh.ops.bevel(
        bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
        offset=0.045, segments=2, affect="EDGES", profile=0.5,
    )
    # üstte hafif çıkıntılı kapak
    kapak = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    bmesh.ops.scale(bm, verts=kapak, vec=(0.86, 0.86, 0.07))
    bmesh.ops.translate(bm, verts=kapak, vec=(0, 0, 0.42))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.4))
    return _nesne("sandik", bm)


def cicek() -> bpy.types.Object:
    bm = bmesh.new()
    orta = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.10)["verts"]
    bmesh.ops.scale(bm, verts=orta, vec=(1.0, 1.0, 0.75))
    for i in range(5):
        aci = i * math.tau / 5.0
        yaprak = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=0.11)["verts"]
        bmesh.ops.scale(bm, verts=yaprak, vec=(1.5, 0.85, 0.32))
        bmesh.ops.rotate(
            bm, verts=yaprak, cent=(0, 0, 0),
            matrix=Matrix.Rotation(aci, 3, "Z"),
        )
        bmesh.ops.translate(
            bm, verts=yaprak,
            vec=(math.cos(aci) * 0.16, math.sin(aci) * 0.16, 0.0),
        )
    bmesh.ops.translate(bm, verts=bm.verts, vec=(0, 0, 0.11))
    return _nesne("cicek", bm)


# --- UV, malzeme, ölçüm ----------------------------------------------------

def _raf_paketle(kutular: list[tuple[float, float]], bosluk: float
                 ) -> list[tuple[float, float]] | None:
    """Basit raf (shelf) paketleyici: adaları soldan sağa, satır satır dizer.

    Kutular (genişlik, yükseklik) olarak 0-1 hücre biriminde gelir. Sığmazsa
    None döner; çağıran yoğunluğu düşürüp yeniden dener — gerçek UV paketleme
    araçlarının yaptığı da budur.
    """
    sira = sorted(range(len(kutular)), key=lambda i: -kutular[i][1])
    konum: list[tuple[float, float]] = [(0.0, 0.0)] * len(kutular)
    x = y = bosluk
    raf_yuksekligi = 0.0
    for i in sira:
        w, h = kutular[i]
        if w > 1.0 - 2 * bosluk or h > 1.0 - 2 * bosluk:
            return None
        if x + w > 1.0 - bosluk:            # satır doldu, alt rafa geç
            x = bosluk
            y += raf_yuksekligi + bosluk
            raf_yuksekligi = 0.0
        if y + h > 1.0 - bosluk:            # hücreye sığmadı
            return None
        konum[i] = (x, y)
        x += w + bosluk
        raf_yuksekligi = max(raf_yuksekligi, h)
    return konum


def uv_ac(obj: bpy.types.Object, bolge: tuple[int, int, int, int],
          hedef_yogunluk: float = 380.0) -> float:
    """Her yüzü baskın eksenine göre düzleme yansıtır, adaları hücreye paketler.

    Bütün adalar **aynı ölçekte** yerleştirilir: doku yoğunluğu nesnenin her
    yerinde eşit olur. Sığmazsa yoğunluk kademeli düşürülür. Dönen değer,
    fiilen kullanılan metre başına teksel sayısı.

    Önceki sürüm her yüzü hücrenin tamamına yayıyordu; küçük pah yüzleri 3000
    teksel/m alırken büyük yüzler 200'de kalıyordu. Aynı nesnede yoğunluk farkı
    demek, dokunun bir yerde bulanık bir yerde israf olması demek.
    """
    me = obj.data
    kat = me.uv_layers.new(name="UVMap") if not me.uv_layers else me.uv_layers[0]
    bx, by, bgen, byuk = bolge

    yuzler = []
    for poly in me.polygons:
        n = poly.normal
        eksen = max(range(3), key=lambda i: abs(n[i]))
        i, j = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[eksen]
        noktalar = [
            (me.vertices[me.loops[li].vertex_index].co[i],
             me.vertices[me.loops[li].vertex_index].co[j])
            for li in poly.loop_indices
        ]
        amin = min(p[0] for p in noktalar)
        bmin = min(p[1] for p in noktalar)
        genislik = max(1e-5, max(p[0] for p in noktalar) - amin)
        yukseklik = max(1e-5, max(p[1] for p in noktalar) - bmin)
        yuzler.append((poly.loop_indices, noktalar, amin, bmin, genislik, yukseklik))

    yogunluk = hedef_yogunluk
    for _ in range(60):
        # Bölge kare olmayabilir: her eksen kendi ölçeğiyle 0-1'e taşınır,
        # metre başına teksel iki eksende de aynı kalır.
        olcek_x = yogunluk / bgen
        olcek_y = yogunluk / byuk
        kutular = [(g * olcek_x, y * olcek_y) for *_, g, y in yuzler]
        konumlar = _raf_paketle(kutular, bosluk=3.0 / min(bgen, byuk))
        if konumlar is not None:
            break
        yogunluk *= 0.88
    else:
        raise RuntimeError("%s: UV adaları bölgeye sığmadı" % obj.name)

    for (loop_indices, noktalar, amin, bmin, _g, _y), (ux, uy) in zip(yuzler, konumlar):
        for li, (a, b) in zip(loop_indices, noktalar):
            u = ux + (a - amin) * olcek_x
            v = uy + (b - bmin) * olcek_y
            # V EKSENİ — bu satır iki kere yanlış yazıldı, ölçerek oturdu:
            # Blender UV'nin başlangıcı sol ALT, glTF'inki sol ÜST. Dışa
            # aktarıcı v'yi çevirir (v_gltf = 1 - v_blender), Godot ise glTF
            # değerini olduğu gibi kullanır. Bölgeleri görüntü koordinatıyla
            # hesapladığımız için çevirmeyi burada telafi ediyoruz.
            kat.data[li].uv = ((bx + u * bgen) / ATLAS_PX,
                               1.0 - (by + v * byuk) / ATLAS_PX)

    return yogunluk


def malzeme_ata(obj: bpy.types.Object, img: bpy.types.Image) -> None:
    mat = bpy.data.materials.new("%s_malzeme" % obj.name)
    mat.use_nodes = True
    agac = mat.node_tree
    bsdf = next(n for n in agac.nodes if n.type == "BSDF_PRINCIPLED")
    doku = agac.nodes.new("ShaderNodeTexImage")
    doku.image = img
    doku.interpolation = "Closest"  # low-poly stilinde keskin teksel
    agac.links.new(bsdf.inputs["Base Color"], doku.outputs["Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    bsdf.inputs["Metallic"].default_value = 0.0
    obj.data.materials.append(mat)


def ucgen_say(obj: bpy.types.Object) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def disa_aktar(obj: bpy.types.Object, yol: str) -> None:
    for o in bpy.context.scene.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=yol,
        export_format="GLTF_SEPARATE",
        use_selection=True,
        export_yup=True,          # Blender Z-up -> glTF/Godot Y-up
        export_apply=True,
        export_keep_originals=True,  # atlası kopyalama, ortak dosyaya başvur
    )


def main() -> int:
    os.makedirs(VARLIK, exist_ok=True)
    atlas_yolu = os.path.join(VARLIK, "atlas.png")
    atlas_uret(atlas_yolu)

    # Boş sahne: bpy modülü varsayılan küp/kamera/ışıkla açılır.
    bpy.ops.wm.read_factory_settings(use_empty=True)
    img = bpy.data.images.load(atlas_yolu)
    img.name = "atlas"

    kurucular = {
        "kaya": (kaya, "kaya"),
        "kaktus": (kaktus, "kaktus"),
        "tabela": (tabela, "ahsap"),
        "sandik": (sandik, "sandik"),
        "cicek": (cicek, "cicek"),
    }

    rapor: dict[str, dict] = {}
    for ad, (kur, hucre_adi) in kurucular.items():
        obj = kur()
        _tabana_otur(obj)
        yogunluk = uv_ac(obj, BOLGELER[hucre_adi])
        malzeme_ata(obj, img)
        boyut = obj.dimensions
        disa_aktar(obj, os.path.join(VARLIK, "%s.gltf" % ad))
        rapor[ad] = {
            "ucgen": ucgen_say(obj),
            "boyut_m": [round(boyut.x, 3), round(boyut.y, 3), round(boyut.z, 3)],
            "teksel_metre": round(yogunluk, 1),
            "bolge": hucre_adi,
            "bolge_px": list(BOLGELER[hucre_adi]),
            "taban_renk": [round(c, 3) for c in RENKLER[hucre_adi]],
            "atlas_px": ATLAS_PX,
        }
        print("%-8s %4d üçgen  %5.2f×%5.2f×%5.2f m  %6.0f teksel/m" % (
            ad, rapor[ad]["ucgen"], boyut.x, boyut.y, boyut.z, yogunluk))

    rapor["_bant"] = {"teksel_metre_min": 250, "teksel_metre_max": 420,
                      "ucgen_ust_sinir": 500}
    with open(os.path.join(VARLIK, "olcum.json"), "w", encoding="utf-8") as f:
        json.dump(rapor, f, ensure_ascii=False, indent=2, sort_keys=True)

    kotu = [a for a, d in rapor.items() if not a.startswith("_")
            and (d["ucgen"] > 500 or not 250 <= d["teksel_metre"] <= 420)]
    if kotu:
        print("BÜTÇE DIŞI:", ", ".join(kotu), file=sys.stderr)
        return 1
    print("varlıklar üretildi ->", VARLIK)
    return 0


if __name__ == "__main__":
    sys.exit(main())
