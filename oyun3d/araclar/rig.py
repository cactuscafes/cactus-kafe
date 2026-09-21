"""Ortak rig hattı: iskelet kurma, ağırlık, animasyon ve glTF dışa aktarımı.

NEDEN AYRI DOSYA (Faz 14): Faz 11-12'de yalnızca oyuncu rig'liydi ve bütün
hat `karakter.py` içindeydi. Düşman da rig'lenince aynı kodun ikinci kopyası
gerekecekti — kemik kurma, slot'lu eylem tuzağı, f-eğrisi erişimi, dışa
aktarım bayrakları. Bunlar karaktere özgü değil, HATTA özgü.

Karaktere özgü olan burada DEĞİL: kemik tablosu, mesh, ağırlık bölgeleri ve
animasyonun kendisi her karakterin kendi dosyasında kalıyor.

KEMİK EKSENİ TUZAĞI: Blender'da kemikler kendi +Y'si boyunca uzar. Aşağı
bakan bir kemiğin yerel X'i dünya X'iyle aynı yöne bakmaz; bu yüzden salınım
işaretleri kemik başına bir kez ölçülüp bir tabloya yazılıyor (`yon`
sözlükleri). "Sağ bacak ters sallanıyor" hatasının kaynağı hep budur.
"""

import bpy
from mathutils import Vector

KARE_HIZI = 30.0


def temizle() -> None:
    """Sahneyi tamamen boşaltır. `bpy` modülü varsayılan küp/kamera/ışıkla
    açılıyor; onlar dışa aktarıma sızarsa dosyada fazladan mesh çıkıyor."""
    for koleksiyon in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures,
                       bpy.data.actions, bpy.data.materials, bpy.data.images):
        for veri in list(koleksiyon):
            koleksiyon.remove(veri, do_unlink=True)


def kutu(bm, merkez, olcu, egim=0.0):
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


def iskelet_kur(kemikler: list[tuple], ad: str = "iskelet") -> bpy.types.Object:
    """Kemik tablosundan iskelet: (ad, baş, uç, ebeveyn) dörtlüleri."""
    arm_veri = bpy.data.armatures.new(ad)
    arm = bpy.data.objects.new(ad, arm_veri)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for kemik_ad, bas, uc, ebeveyn in kemikler:
        kemik = arm_veri.edit_bones.new(kemik_ad)
        kemik.head = Vector(bas)
        kemik.tail = Vector(uc)
        if ebeveyn is not None:
            kemik.parent = arm_veri.edit_bones[ebeveyn]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def poz(arm: bpy.types.Object, ad: str) -> bpy.types.PoseBone:
    kemik = arm.pose.bones[ad]
    kemik.rotation_mode = "XYZ"
    return kemik


def anahtar(arm: bpy.types.Object, kare: float, acilar: dict[str, tuple],
            yon: dict[str, float], kok: str,
            konum: tuple | None = None) -> None:
    """Bir kareye poz yazar. `yon`, kemik başına X dönüş işareti; `kok`,
    konumu taşıyan kemik (gövdenin zıplaması/çömelmesi oradan geliyor)."""
    for ad, aci in acilar.items():
        kemik = poz(arm, ad)
        kemik.rotation_euler = (aci[0] * yon[ad], aci[1], aci[2])
        kemik.keyframe_insert("rotation_euler", frame=kare)
    kok_kemik = poz(arm, kok)
    kok_kemik.location = Vector(konum or (0.0, 0.0, 0.0))
    kok_kemik.keyframe_insert("location", frame=kare)


def eylem(arm: bpy.types.Object, ad: str) -> bpy.types.Action:
    yeni = bpy.data.actions.new(ad)
    yeni.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = yeni
    # Blender 4.4+ "slot"lu eylemler: keyframe eklemeden önce slot atanmazsa
    # anahtarlar hiçbir yere yazılmıyor ve dışa aktarımda animasyon boş çıkıyor.
    if hasattr(arm.animation_data, "action_slot") and yeni.slots:
        arm.animation_data.action_slot = yeni.slots[0]
    return yeni


def bitir(eylem_: bpy.types.Action, arm: bpy.types.Object, dongu: bool) -> None:
    eylem_.use_cyclic = dongu
    arm.animation_data.action = None


def egriler(eylem_: bpy.types.Action) -> list:
    """Eylemin f-eğrileri. Blender 4.4+ katmanlı eylemlerde `action.fcurves`
    yok: eğriler katman > şerit > slot torbasının içinde duruyor. Eski API de
    destekleniyor ki betik iki sürümde de çalışsın."""
    if hasattr(eylem_, "fcurves"):
        return list(eylem_.fcurves)
    liste: list = []
    for katman in eylem_.layers:
        for serit in katman.strips:
            for slot in eylem_.slots:
                torba = serit.channelbag(slot)
                if torba is not None:
                    liste.extend(torba.fcurves)
    return liste


def zamani_olcekle(eylem_: bpy.types.Action, oran: float) -> None:
    """Eylemin süresini oranla çarpar — poz aynı, tempo değişir.

    Animasyonu iki kez kurmak yerine anahtarların zamanı ölçekleniyor: adım
    boyu tempodan bağımsız (aynı açılar, aynı mesafe), dolayısıyla ölçüm bir
    kez yapılıp süre sonradan yerine oturtulabiliyor."""
    for eg in egriler(eylem_):
        for nokta_grubu in eg.keyframe_points:
            for nokta in (nokta_grubu.co, nokta_grubu.handle_left,
                          nokta_grubu.handle_right):
                nokta.x = 1.0 + (nokta.x - 1.0) * oran
        eg.update()


def adim_olc(arm: bpy.types.Object, sure: float, ayaklar: tuple[str, str],
             uc: bool = False) -> float:
    """Bir çevrimde atılan yol (metre). ÖLÇÜLÜR, hesaplanmaz.

    Adım boyunu formülle tahmin etmek (2·bacak·sin(genlik)) dizi ve ayağı yok
    sayıyor; ikisi de adımı kısaltıyor. Onun yerine poz gerçekten
    değerlendiriliyor ve iki ayağın en açık olduğu an ölçülüyor: gövde bir
    adımda tam o kadar ilerler. Çevrim iki adım, yani iki katı.

    Eylem çağrı sırasında `arm`a bağlı olmalı (`bitir`den ÖNCE).

    `uc`: kemiğin BAŞI değil UCU ölçülür. Tek kemikli bacakta (düşman) baş
    kalçadır ve hiç kıpırdamaz — ölçüm sıfır çıkar. Çok kemikli bacakta
    (oyuncu) ayak kemiğinin başı bilektir ve zaten hareket eder."""
    sahne = bpy.context.scene
    en_acik = 0.0
    for k in range(9):
        f = 1.0 + sure * KARE_HIZI * k / 8.0
        sahne.frame_set(int(f), subframe=f - int(f))
        bpy.context.view_layer.update()
        # Blender'da +Y ileri (dışa aktarımda Godot'nun -Z'si oluyor).
        sol = (arm.pose.bones[ayaklar[0]].tail.y if uc
               else arm.pose.bones[ayaklar[0]].head.y)
        sag = (arm.pose.bones[ayaklar[1]].tail.y if uc
               else arm.pose.bones[ayaklar[1]].head.y)
        en_acik = max(en_acik, abs(sol - sag))
    return en_acik * 2.0


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
