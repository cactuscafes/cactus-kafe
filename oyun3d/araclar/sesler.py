"""Cactus 3B — Faz 3 ses üretimi.

    python3 oyun3d/araclar/sesler.py

Oyunun bütün ses efektlerini ve müzik döngüsünü sentezleyip `ses/` altına
16-bit mono WAV olarak yazar. Dış bağımlılık yok; sadece standart kütüphane.

NEDEN SENTEZ: Hazır ses indirmek (freesound.org, Kenney) normalde daha hızlı ve
daha iyi sonuç verir — Faz 3'ün asıl dersi lisans okumak ve ses seçmektir. Bu
ortamda o siteler kapalı olduğu için sesler üretiliyor. Yerlerine gerçek ses
koyacaksan dosya adlarını koru; oyun kodunda değişiklik gerekmez.

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


def tik() -> list[float]:
    ton = sinus(0.05, 1200, 900)
    return uygula(ton, zarf(len(ton), 0.05, 0.8))


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
    yaz("tik.wav", tik(), 0.5)
    yaz("muzik.wav", muzik(), 0.55)
    toplam = sum(os.path.getsize(os.path.join(SES, f)) for f in os.listdir(SES)
                 if f.endswith(".wav"))
    print("toplam %.2f MB" % (toplam / 1e6))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
