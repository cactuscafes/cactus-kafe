"""Cactus 3B — Faz 3 ses üretimi.

    python3 oyun3d/araclar/sesler.py

Oyunun bütün ses efektlerini ve müzik döngüsünü sentezleyip `ses/` altına
16-bit mono WAV olarak yazar. Dış bağımlılık yok; sadece standart kütüphane.

NEDEN SENTEZ: Hazır ses indirmek (freesound.org, Kenney) normalde daha hızlı ve
daha iyi sonuç verir — Faz 3'ün asıl dersi lisans okumak ve ses seçmektir. Bu
ortamda o siteler kapalı olduğu için sesler üretiliyor. Yerlerine gerçek ses
koyacaksan dosya adlarını koru; oyun kodunda değişiklik gerekmez.

FAZ 15 — ÇEVRE VE KATMANLI MÜZİK: rüzgâr döngüsü, kuş ötüşü, tür başına
düşman sesleri ve müziğin GERİLİM KATMANI eklendi. Gerilim katmanı ana
döngüyle aynı uzunlukta ve aynı akorlar üzerine kurulu: ikisi aynı anda
çalıyor, biri kısık duruyor (bkz. `betikler/ses.gd`).

TASARIM NOTU: Her efekt kısa (0.05–0.9 sn) ve tepe seviyesi -3 dBFS'e
normalize. Aynı anda birkaç ses çalınca kırpma olmasın diye SFX bus'ı -6 dB'de
başlıyor (bkz. default_bus_layout.tres).
"""

import array
import math
import os
import random
import struct
import wave

ORNEK = 22050
BURASI = os.path.dirname(os.path.abspath(__file__))
SES = os.path.join(os.path.dirname(BURASI), "ses")


# --- temel yapı taşları ----------------------------------------------------

def zarf(n: int, atak: float, sonum: float) -> list[float]:
    """Basit atak/sönüm zarfı (0-1)."""
    a = max(1, int(n * atak))
    d = max(1, int(n * sonum))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        elif i > n - d:
            out.append(max(0.0, (n - i) / d))
        else:
            out.append(1.0)
    return out


def sinus(sure: float, bas: float, son: float, sekil: str = "sin") -> list[float]:
    """Frekansı bas'tan son'a kayan ton."""
    n = int(sure * ORNEK)
    veri = []
    faz = 0.0
    for i in range(n):
        t = i / n
        f = bas * (son / bas) ** t          # üstel kayma: kulağa doğrusal gelir
        faz += 2 * math.pi * f / ORNEK
        if sekil == "kare":
            veri.append(1.0 if math.sin(faz) > 0 else -1.0)
        elif sekil == "ucgen":
            veri.append(2.0 / math.pi * math.asin(math.sin(faz)))
        else:
            veri.append(math.sin(faz))
    return veri


def gurultu(sure: float, tohum: int = 0) -> list[float]:
    rast = random.Random(tohum)
    return [rast.uniform(-1.0, 1.0) for _ in range(int(sure * ORNEK))]


def alcak_gecir(veri: list[float], kesim: float) -> list[float]:
    """Tek kutuplu alçak geçiren süzgeç — gürültüyü 'yumuşatır'."""
    rc = 1.0 / (2 * math.pi * kesim)
    dt = 1.0 / ORNEK
    a = dt / (rc + dt)
    out = []
    onceki = 0.0
    for x in veri:
        onceki += a * (x - onceki)
        out.append(onceki)
    return out


def karistir(*katmanlar: list[float]) -> list[float]:
    n = max(len(k) for k in katmanlar)
    out = [0.0] * n
    for k in katmanlar:
        for i, v in enumerate(k):
            out[i] += v
    return out


def uygula(veri: list[float], z: list[float]) -> list[float]:
    return [v * z[i] for i, v in enumerate(veri)]


def yaz(ad: str, veri: list[float], tepe: float = 0.7) -> None:
    en_buyuk = max(1e-9, max(abs(v) for v in veri))
    olcek = tepe / en_buyuk
    ornekler = array.array("h", (int(max(-1.0, min(1.0, v * olcek)) * 32767) for v in veri))
    yol = os.path.join(SES, ad)
    with wave.open(yol, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(ORNEK)
        f.writeframes(ornekler.tobytes())
    print("  %-14s %5.2f sn  %6d bayt" % (ad, len(veri) / ORNEK, os.path.getsize(yol)))


# --- efektler --------------------------------------------------------------

def adim(tohum: int) -> list[float]:
    """Kum üstünde ayak sesi: süzülmüş gürültü patlaması."""
    g = alcak_gecir(gurultu(0.13, tohum), 1400)
    return uygula(g, zarf(len(g), 0.02, 0.85))


def zipla() -> list[float]:
    ton = sinus(0.20, 300, 720, "ucgen")
    return uygula(ton, zarf(len(ton), 0.02, 0.6))


def inis() -> list[float]:
    ton = sinus(0.18, 190, 70)
    g = alcak_gecir(gurultu(0.18, 5), 900)
    k = karistir(uygula(ton, zarf(len(ton), 0.01, 0.8)),
                 [v * 0.5 for v in uygula(g, zarf(len(g), 0.01, 0.9))])
    return k


def toplama() -> list[float]:
    """İki notalı parlak ping — ödül sesi yukarı çıkmalı."""
    a = uygula(sinus(0.10, 880, 880), zarf(int(0.10 * ORNEK), 0.02, 0.7))
    b = [0.0] * int(0.07 * ORNEK) + uygula(sinus(0.18, 1320, 1320),
                                           zarf(int(0.18 * ORNEK), 0.02, 0.8))
    return karistir(a, b)


def olum() -> list[float]:
    ton = sinus(0.45, 420, 90, "kare")
    g = alcak_gecir(gurultu(0.45, 9), 700)
    return karistir(uygula(ton, zarf(len(ton), 0.01, 0.7)),
                    [v * 0.35 for v in uygula(g, zarf(len(g), 0.02, 0.9))])


def kontrol() -> list[float]:
    a = uygula(sinus(0.14, 660, 660), zarf(int(0.14 * ORNEK), 0.02, 0.7))
    b = [0.0] * int(0.10 * ORNEK) + uygula(sinus(0.26, 990, 990),
                                           zarf(int(0.26 * ORNEK), 0.02, 0.8))
    return karistir(a, b)


def bitis() -> list[float]:
    """Üç notalı kısa fanfar (do-mi-sol)."""
    notalar = [(523.25, 0.0), (659.25, 0.16), (783.99, 0.32)]
    katman = []
    for frek, gecikme in notalar:
        n = uygula(sinus(0.55, frek, frek, "ucgen"), zarf(int(0.55 * ORNEK), 0.02, 0.75))
        katman.append([0.0] * int(gecikme * ORNEK) + n)
    return karistir(*katman)


def hasar() -> list[float]:
    """Oyuncu hasar aldı: sert, kısa, alçak. Ödül seslerinin tersi yönde."""
    ton = sinus(0.28, 260, 90, "kare")
    g = alcak_gecir(gurultu(0.28, 31), 1100)
    return karistir(uygula(ton, zarf(len(ton), 0.005, 0.75)),
                    [v * 0.6 for v in uygula(g, zarf(len(g), 0.005, 0.85))])


def dusman_farketti() -> list[float]:
    """Düşman oyuncuyu gördü: yukarı çıkan iki nota, uyarı niteliğinde."""
    a = uygula(sinus(0.12, 300, 300, "ucgen"), zarf(int(0.12 * ORNEK), 0.03, 0.6))
    b = [0.0] * int(0.09 * ORNEK) + uygula(sinus(0.22, 460, 500, "ucgen"),
                                           zarf(int(0.22 * ORNEK), 0.03, 0.7))
    return karistir(a, b)


def dusman_saldiri() -> list[float]:
    """Savurma: hızla alçalan süzülmüş gürültü."""
    g = alcak_gecir(gurultu(0.22, 44), 2600)
    ton = sinus(0.22, 520, 180)
    return karistir(uygula(g, zarf(len(g), 0.02, 0.8)),
                    [v * 0.4 for v in uygula(ton, zarf(len(ton), 0.02, 0.8))])


def ezme() -> list[float]:
    """Düşmanın üstüne binme: kısa, tok, tatmin edici."""
    ton = sinus(0.16, 620, 150, "ucgen")
    g = alcak_gecir(gurultu(0.16, 77), 1800)
    return karistir(uygula(ton, zarf(len(ton), 0.005, 0.7)),
                    [v * 0.5 for v in uygula(g, zarf(len(g), 0.005, 0.8))])


def dusman_oldu() -> list[float]:
    """Düşman yenildi: aşağı inen üç nota, 'sönme' hissi."""
    katman = []
    for i, frek in enumerate((520.0, 400.0, 280.0)):
        n = uygula(sinus(0.3, frek, frek * 0.85, "ucgen"),
                   zarf(int(0.3 * ORNEK), 0.02, 0.75))
        katman.append([0.0] * int(i * 0.09 * ORNEK) + n)
    g = alcak_gecir(gurultu(0.4, 88), 900)
    katman.append([v * 0.3 for v in uygula(g, zarf(len(g), 0.02, 0.9))])
    return karistir(*katman)


def tik() -> list[float]:
    ton = sinus(0.05, 1200, 900)
    return uygula(ton, zarf(len(ton), 0.05, 0.8))


# --- Faz 15: çevre, tür sesleri ve müzik katmanı ---------------------------

def ruzgar() -> list[float]:
    """8 saniyelik döngü: çölün rüzgârı.

    Süzgeçten geçmiş gürültü + yavaş bir genlik dalgalanması. Döngü noktasında
    duyulmaması için baş ve son 0,4 saniye birbirine karıştırılıyor (crossfade);
    aksi hâlde her 8 saniyede bir 'tık' duyuluyor ve arka plan sesi, varlığını
    en çok o tıkla belli ediyor.
    """
    uzunluk = 8.0
    n = int(uzunluk * ORNEK)
    ham = alcak_gecir(alcak_gecir(gurultu(uzunluk + 0.5, 77), 420.0), 900.0)
    veri = []
    for i in range(len(ham)):
        t = i / ORNEK
        # İki yavaş LFO: tek LFO nefes alıp veren bir makine gibi duyuluyor.
        dalga = 0.55 + 0.30 * math.sin(2 * math.pi * 0.11 * t) \
            + 0.15 * math.sin(2 * math.pi * 0.037 * t + 1.3)
        veri.append(ham[i] * dalga)
    kesisme = int(0.4 * ORNEK)
    dongu = veri[:n]
    for i in range(kesisme):
        oran = i / kesisme
        dongu[i] = dongu[i] * oran + veri[n + i] * (1.0 - oran)
    return dongu


def kus() -> list[float]:
    """Tek bir kuş ötüşü: üç kısa cik. Çevre sesi motoru rastgele aralıklarla
    çalıyor — döngüye gömülü bir kuş, üçüncü tekrarda sahte duyuluyor."""
    parcalar = []
    for i, (bas, son) in enumerate(((2400, 3100), (2900, 2500), (2600, 3300))):
        ton = sinus(0.055, bas, son)
        parcalar.append(uygula(ton, zarf(len(ton), 0.15, 0.6)))
        if i < 2:
            parcalar.append([0.0] * int(0.06 * ORNEK))
    cikti = []
    for p in parcalar:
        cikti.extend(p)
    return cikti


def diken_at() -> list[float]:
    """Atıcının fırlatışı: kısa bir 'tss' + alçalan ton."""
    hava = uygula(alcak_gecir(gurultu(0.16, 5), 3000.0),
                  zarf(int(0.16 * ORNEK), 0.02, 0.85))
    ton = uygula(sinus(0.16, 900, 380, "ucgen"), zarf(int(0.16 * ORNEK), 0.01, 0.9))
    return karistir(hava, [v * 0.5 for v in ton])


def diken_carp() -> list[float]:
    """Dikenin taşa saplanması: tok, kısa."""
    vurus = uygula(alcak_gecir(gurultu(0.09, 9), 1400.0),
                   zarf(int(0.09 * ORNEK), 0.01, 0.9))
    ton = uygula(sinus(0.09, 320, 140), zarf(int(0.09 * ORNEK), 0.01, 0.95))
    return karistir(vurus, [v * 0.6 for v in ton])


def hop() -> list[float]:
    """Hoplayanın sıçrayışı: yukarı kayan kısa bir homurtu."""
    ton = sinus(0.22, 180, 420, "ucgen")
    govde = uygula(ton, zarf(len(ton), 0.05, 0.6))
    hava = uygula(alcak_gecir(gurultu(0.22, 3), 1100.0),
                  zarf(int(0.22 * ORNEK), 0.2, 0.7))
    return karistir(govde, [v * 0.35 for v in hava])


def boss_carp() -> list[float]:
    """Canavarın yere çarpması: derin bir gümbürtü + çakıl.

    Düşmanın "ezme" sesinden farklı olmak zorunda: aynı aileden bir ses,
    oyuncuya "bu da o düşman" diyor. Derin ve uzun olması boyu anlatıyor.
    """
    govde = uygula(sinus(0.55, 120, 38), zarf(int(0.55 * ORNEK), 0.005, 0.85))
    catirti = uygula(alcak_gecir(gurultu(0.55, 17), 700.0),
                     zarf(int(0.55 * ORNEK), 0.01, 0.75))
    ince = uygula(alcak_gecir(gurultu(0.18, 23), 4200.0),
                  zarf(int(0.18 * ORNEK), 0.01, 0.9))
    return karistir(govde, [v * 0.7 for v in catirti], [v * 0.25 for v in ince])


def boss_kukre() -> list[float]:
    """Kükreme: evre değişiminin sesi. Alçalan iki ton + gürültü gövdesi."""
    n = int(0.9 * ORNEK)
    alt = uygula(sinus(0.9, 210, 90, "ucgen"), zarf(n, 0.08, 0.45))
    ust = uygula(sinus(0.9, 320, 140), zarf(n, 0.12, 0.5))
    hava = uygula(alcak_gecir(gurultu(0.9, 41), 1600.0), zarf(n, 0.1, 0.5))
    return karistir(alt, [v * 0.5 for v in ust], [v * 0.45 for v in hava])


def muzik_gerilim() -> list[float]:
    """Müziğin GERİLİM KATMANI — ana döngüyle aynı uzunlukta (16 sn).

    Uyarlanan müzik burada iki parçayı karıştırıp bir üçüncüsünü üretmek
    değil: iki parça AYNI ANDA baştan çalıyor, biri kısık duruyor ve düşman
    kovalarken açılıyor. Bu yüzden bu katmanın uzunluğu ve tempo ızgarası ana
    döngüyle birebir aynı olmak zorunda — yoksa iki parça kayar ve açılış
    anında akort tutmaz.
    """
    uzunluk = 16.0
    n = int(uzunluk * ORNEK)
    cikti = [0.0] * n
    # Kök notaların altına inen bir drone: ana döngünün akorlarıyla uyumlu.
    for frek, oran in ((110.0, 0.30), (146.83, 0.16)):
        faz = 0.0
        for i in range(n):
            faz += 2 * math.pi * frek / ORNEK
            t = i / n
            # Gerilim yavaşça artıyor: döngü boyunca hafif bir kabarma.
            kabarma = 0.75 + 0.25 * math.sin(2 * math.pi * t)
            cikti[i] += (math.sin(faz) * 0.7 + math.sin(faz * 2.01) * 0.3) * oran * kabarma
    # Nabız: saniyede iki vuruş, kalp atışı temposu.
    vurus_sure = 0.5
    for adet in range(int(uzunluk / vurus_sure)):
        basla = int(adet * vurus_sure * ORNEK)
        vurus = uygula(sinus(0.16, 150, 60), zarf(int(0.16 * ORNEK), 0.01, 0.9))
        for k, v in enumerate(vurus):
            if basla + k < n:
                cikti[basla + k] += v * (0.5 if adet % 2 == 0 else 0.3)
    return cikti


def muzik() -> list[float]:
    """16 saniyelik döngü: yumuşak pad akorları + hafif arpej.

    Döngü noktasında tıklama olmaması için akor süreleri döngü uzunluğunu tam
    bölüyor ve son akorun sönümü döngü sonunda sıfıra iniyor.
    """
    uzunluk = 16.0
    n = int(uzunluk * ORNEK)
    cikti = [0.0] * n
    # Am - F - C - G (kaktüs çölü için sakin bir döngü)
    akorlar = [(220.00, 261.63, 329.63), (174.61, 220.00, 261.63),
               (261.63, 329.63, 392.00), (196.00, 246.94, 293.66)]
    akor_suresi = uzunluk / len(akorlar)

    for i, akor in enumerate(akorlar):
        basla = int(i * akor_suresi * ORNEK)
        uzun = int(akor_suresi * ORNEK)
        z = zarf(uzun, 0.15, 0.35)
        for frek in akor:
            faz = 0.0
            for k in range(uzun):
                faz += 2 * math.pi * frek / ORNEK
                # üçgen dalga + hafif detune: pad hissi
                deger = math.sin(faz) * 0.6 + math.sin(faz * 2.003) * 0.15
                cikti[basla + k] += deger * z[k] * 0.22

    # arpej: her yarım saniyede bir kısa nota
    arp = [523.25, 659.25, 783.99, 659.25]
    adim_sure = 0.5
    for adet in range(int(uzunluk / adim_sure)):
        frek = arp[adet % len(arp)]
        basla = int(adet * adim_sure * ORNEK)
        nota = uygula(sinus(0.35, frek, frek), zarf(int(0.35 * ORNEK), 0.03, 0.8))
        for k, v in enumerate(nota):
            if basla + k < n:
                cikti[basla + k] += v * 0.12
    return cikti


def main() -> int:
    os.makedirs(SES, exist_ok=True)
    print("ses üretiliyor ->", SES)
    yaz("adim1.wav", adim(1), 0.45)
    yaz("adim2.wav", adim(2), 0.45)
    yaz("zipla.wav", zipla())
    yaz("inis.wav", inis())
    yaz("toplama.wav", toplama())
    yaz("olum.wav", olum())
    yaz("kontrol.wav", kontrol())
    yaz("bitis.wav", bitis())
    yaz("hasar.wav", hasar())
    yaz("ezme.wav", ezme())
    yaz("dusman_oldu.wav", dusman_oldu(), 0.6)
    yaz("dusman_farketti.wav", dusman_farketti(), 0.6)
    yaz("dusman_saldiri.wav", dusman_saldiri(), 0.6)
    yaz("tik.wav", tik(), 0.5)
    yaz("diken_at.wav", diken_at(), 0.6)
    yaz("diken_carp.wav", diken_carp(), 0.6)
    yaz("hop.wav", hop(), 0.6)
    yaz("boss_carp.wav", boss_carp(), 0.72)
    yaz("boss_kukre.wav", boss_kukre(), 0.68)
    yaz("kus.wav", kus(), 0.45)
    yaz("ruzgar.wav", ruzgar(), 0.5)
    yaz("muzik.wav", muzik(), 0.55)
    yaz("muzik_gerilim.wav", muzik_gerilim(), 0.5)
    toplam = sum(os.path.getsize(os.path.join(SES, f)) for f in os.listdir(SES)
                 if f.endswith(".wav"))
    print("toplam %.2f MB" % (toplam / 1e6))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
