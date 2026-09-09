#!/usr/bin/env python3
"""NDJSON yedegini (d1-yedek dali) SQLite/D1 INSERT ifadelerine cevirir.

Kullanim:
    gunzip -c yedek/cactus-adisyon-events-2026-01-01.ndjson.gz \
      | python3 .github/scripts/ndjson-to-sql.py > geri.sql
    npx wrangler d1 execute cactus-adisyon-events --remote --file geri.sql

INSERT OR IGNORE kullanilir: mevcut kayitlar korunur, yalniz eksikler eklenir
(id sutunu UNIQUE). seq yeniden uretilir (AUTOINCREMENT); sira server_ts ile korunur.
Sema bu betikte yok — once: wrangler d1 execute <db> --remote --file schema-adisyon-events.sql
"""
import json
import sys

TABLO = "adisyon_events"
SUTUNLAR = ("id", "sube", "type", "masa", "payload", "ts", "server_ts", "cihaz_id")
METIN = {"id", "sube", "type", "payload", "cihaz_id"}


def tirnakla(deger):
    """SQLite metin literali — tek tirnaklar ikilenir."""
    return "'" + str(deger).replace("'", "''") + "'"


def sql_degeri(sutun, satir):
    ham = satir.get(sutun)
    if ham is None:
        return "NULL"
    if sutun == "payload":
        # payload DB'de TEXT (JSON string) olarak duruyor
        return tirnakla(ham if isinstance(ham, str) else json.dumps(ham, ensure_ascii=False))
    if sutun in METIN:
        return tirnakla(ham)
    if isinstance(ham, bool) or not isinstance(ham, (int, float)):
        raise ValueError(f"{sutun} sayisal olmali, gelen: {ham!r}")
    return str(ham)


def main():
    kaynak = open(sys.argv[1], encoding="utf-8") if len(sys.argv) > 1 else sys.stdin
    yazildi = 0
    with kaynak:
        for no, ham_satir in enumerate(kaynak, 1):
            ham_satir = ham_satir.strip()
            if not ham_satir:
                continue
            try:
                satir = json.loads(ham_satir)
            except json.JSONDecodeError as e:
                sys.exit(f"HATA: {no}. satir gecerli JSON degil: {e}")
            eksik = [s for s in SUTUNLAR if s != "masa" and satir.get(s) is None]
            if eksik:
                sys.exit(f"HATA: {no}. satirda zorunlu alan eksik: {', '.join(eksik)}")
            try:
                degerler = ",".join(sql_degeri(s, satir) for s in SUTUNLAR)
            except ValueError as e:
                sys.exit(f"HATA: {no}. satir: {e}")
            print(f"INSERT OR IGNORE INTO {TABLO} ({','.join(SUTUNLAR)}) VALUES ({degerler});")
            yazildi += 1
    print(f"-- {yazildi} kayit", file=sys.stderr)


if __name__ == "__main__":
    main()
