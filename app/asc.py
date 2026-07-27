#!/usr/bin/env python3
"""App Store Connect otomasyonu — GitHub Actions içinden çalışır.

Yaptıkları:
  1. Yüklenen build'in Apple tarafında işlenmesini bekler
  2. Sürüm sayfasına o build'i seçer
  3. İnceleme notlarını (App Review Information → Notes) yazar
  4. İstenirse sürümü incelemeye gönderir

Ortam değişkenleri:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH   → App Store Connect API anahtarı
  BUNDLE_ID                                  → com.cactuscafes.coffee
  BUILD_NUMARASI                             → örn. 3
  SURUM                                      → örn. 1.0
  INCELEMEYE_GONDER                          → "true" ise incelemeye gönderir
  INCELEME_NOTU_DOSYASI                      → (opsiyonel) notların olduğu dosya
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT

TABAN = "https://api.appstoreconnect.apple.com"
KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ["ASC_KEY_PATH"]
BUNDLE_ID = os.environ.get("BUNDLE_ID", "com.cactuscafes.coffee")
BUILD_NO = os.environ["BUILD_NUMARASI"]
SURUM = os.environ.get("SURUM", "1.0")
GONDER = os.environ.get("INCELEMEYE_GONDER", "false").lower() == "true"
NOT_DOSYASI = os.environ.get("INCELEME_NOTU_DOSYASI", "")
SADECE_DURUM = os.environ.get("DURUM_RAPORU", "false").lower() == "true"

# Sürüm sayfası düzenlenebilir durumdayken build seçilebilir
DUZENLENEBILIR = {
    "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED",
    "METADATA_REJECTED", "INVALID_BINARY", "DEVELOPER_REMOVED_FROM_SALE",
}


def jeton():
    with open(KEY_PATH, "r") as f:
        gizli = f.read()
    simdi = int(time.time())
    return jwt.encode(
        {"iss": ISSUER, "iat": simdi, "exp": simdi + 19 * 60, "aud": "appstoreconnect-v1"},
        gizli,
        algorithm="ES256",
        headers={"kid": KEY_ID, "typ": "JWT"},
    )


def istek(yol, yontem="GET", govde=None):
    url = yol if yol.startswith("http") else TABAN + yol
    veri = json.dumps(govde).encode() if govde is not None else None
    r = urllib.request.Request(url, data=veri, method=yontem)
    r.add_header("Authorization", "Bearer " + jeton())
    if veri:
        r.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(r) as c:
            ham = c.read()
            return json.loads(ham) if ham else {}
    except urllib.error.HTTPError as e:
        detay = e.read().decode("utf-8", "replace")
        print(f"⚠️  API hatası {e.code} — {yontem} {yol}\n{detay}", file=sys.stderr)
        raise


def uygulama_id():
    c = istek(f"/v1/apps?filter[bundleId]={BUNDLE_ID}&limit=1")
    if not c.get("data"):
        sys.exit(f"❌ {BUNDLE_ID} kimlikli uygulama App Store Connect'te bulunamadı.")
    u = c["data"][0]
    print(f"✓ Uygulama: {u['attributes'].get('name')} (id {u['id']})")
    return u["id"]


def build_bekle(app_id, dakika=40):
    """Yüklenen build işlenene kadar bekler (Apple tarafı 5-30 dk sürebilir)."""
    bitis = time.time() + dakika * 60
    uyarildi = False
    while time.time() < bitis:
        c = istek(
            f"/v1/builds?filter[app]={app_id}&filter[version]={BUILD_NO}"
            "&limit=1&sort=-uploadedDate"
        )
        if c.get("data"):
            b = c["data"][0]
            durum = b["attributes"].get("processingState")
            if durum == "VALID":
                print(f"✓ Build {BUILD_NO} işlendi ve hazır (id {b['id']})")
                return b["id"]
            if durum in ("INVALID", "FAILED"):
                sys.exit(f"❌ Build {BUILD_NO} Apple tarafında reddedildi: {durum}")
            print(f"… build {BUILD_NO} işleniyor ({durum}) — 60 sn sonra tekrar bakılacak")
        elif not uyarildi:
            print(f"… build {BUILD_NO} henüz görünmedi, bekleniyor")
            uyarildi = True
        time.sleep(60)
    sys.exit(f"❌ Build {BUILD_NO} {dakika} dakikada işlenmedi. Apple yavaş olabilir; "
             f"iş akışını 'sadece gönder' modunda tekrar çalıştırabilirsin.")


def surum_bul(app_id):
    c = istek(f"/v1/apps/{app_id}/appStoreVersions?limit=20")
    for v in c.get("data", []):
        a = v["attributes"]
        if a.get("versionString") == SURUM and a.get("appStoreState") in DUZENLENEBILIR:
            print(f"✓ Sürüm {SURUM} düzenlenebilir durumda ({a.get('appStoreState')})")
            return v["id"]
    mevcut = [(v['attributes'].get('versionString'), v['attributes'].get('appStoreState'))
              for v in c.get("data", [])]
    sys.exit(f"❌ {SURUM} sürümü düzenlenebilir değil. Mevcut sürümler: {mevcut}")


def build_sec(surum_id, build_id):
    istek(f"/v1/appStoreVersions/{surum_id}/relationships/build", "PATCH",
          {"data": {"type": "builds", "id": build_id}})
    print("✓ Build sürüme bağlandı")


def inceleme_notu_yaz(surum_id):
    if not NOT_DOSYASI or not os.path.exists(NOT_DOSYASI):
        return
    with open(NOT_DOSYASI, "r", encoding="utf-8") as f:
        notlar = f.read().strip()
    if not notlar:
        return
    nitelik = {"notes": notlar}
    try:
        mevcut = istek(f"/v1/appStoreVersions/{surum_id}/appStoreReviewDetail")
        d = mevcut.get("data")
    except urllib.error.HTTPError:
        d = None
    if d:
        istek(f"/v1/appStoreReviewDetails/{d['id']}", "PATCH",
              {"data": {"type": "appStoreReviewDetails", "id": d["id"], "attributes": nitelik}})
    else:
        istek("/v1/appStoreReviewDetails", "POST", {"data": {
            "type": "appStoreReviewDetails",
            "attributes": nitelik,
            "relationships": {"appStoreVersion": {
                "data": {"type": "appStoreVersions", "id": surum_id}}},
        }})
    print("✓ İnceleme notları yazıldı")


def incelemeye_gonder(app_id, surum_id):
    c = istek(f"/v1/reviewSubmissions?filter[app]={app_id}&filter[state]=READY_FOR_REVIEW,"
              f"WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES&limit=10")
    acik = c.get("data") or []
    if any(s["attributes"].get("state") in ("WAITING_FOR_REVIEW", "IN_REVIEW") for s in acik):
        print("ℹ️  Zaten incelemede bekleyen bir gönderim var — yenisi oluşturulmadı.")
        return

    # Retten kalan açık gönderimler: önce öğelerini sök, sonra dosyayı iptal et
    for eski in acik:
        durum = eski["attributes"].get("state")
        try:
            ogeler = istek(f"/v1/reviewSubmissions/{eski['id']}/items?limit=50")
            for oge in ogeler.get("data", []):
                try:
                    istek(f"/v1/reviewSubmissionItems/{oge['id']}", "DELETE")
                    print("✓ Eski gönderimden öğe söküldü")
                except urllib.error.HTTPError:
                    print("⚠️  Öğe sökülemedi — iptalle devam")
        except urllib.error.HTTPError:
            pass
        try:
            istek(f"/v1/reviewSubmissions/{eski['id']}", "PATCH", {"data": {
                "type": "reviewSubmissions", "id": eski["id"],
                "attributes": {"canceled": True},
            }})
            print(f"✓ Eski gönderim iptal edildi ({durum})")
        except urllib.error.HTTPError:
            print(f"⚠️  Eski gönderim iptal edilemedi ({durum}) — devam deneniyor")

    gonderim_id = istek("/v1/reviewSubmissions", "POST", {"data": {
        "type": "reviewSubmissions",
        "attributes": {"platform": "IOS"},
        "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
    }})["data"]["id"]
    print("✓ Yeni gönderim dosyası açıldı")

    # İptal Apple tarafında yayılana kadar sürüm "başka gönderimde" görünebilir — sabırla dene
    for deneme in range(10):
        try:
            istek("/v1/reviewSubmissionItems", "POST", {"data": {
                "type": "reviewSubmissionItems",
                "relationships": {
                    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": gonderim_id}},
                    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": surum_id}},
                },
            }})
            print("✓ Sürüm gönderim dosyasına eklendi")
            break
        except urllib.error.HTTPError as e:
            if e.code == 409 and deneme < 9:
                print(f"… sürüm henüz serbest değil — 15 sn sonra tekrar (deneme {deneme + 1}/10)")
                time.sleep(15)
            else:
                raise

    istek(f"/v1/reviewSubmissions/{gonderim_id}", "PATCH", {"data": {
        "type": "reviewSubmissions", "id": gonderim_id, "attributes": {"submitted": True},
    }})
    print("🚀 Sürüm incelemeye gönderildi.")


def rejection_detaylari(surum_id):
    try:
        c = istek(f"/v1/appStoreVersions/{surum_id}/appStoreReviewDetail")
        d = c.get("data")
        if d and d.get("attributes", {}).get("rejectionNotes"):
            print("\n📋 RET NEDENI:")
            print(d["attributes"]["rejectionNotes"])
    except urllib.error.HTTPError:
        pass


def durum_raporu(app_id):
    c = istek(f"/v1/apps/{app_id}/appStoreVersions?limit=5")
    for v in c.get("data", []):
        a = v["attributes"]
        durum = a.get('appStoreState')
        print(f"SÜRÜM {a.get('versionString')}: {durum}")
        if durum == "REJECTED":
            rejection_detaylari(v["id"])
    c = istek(f"/v1/reviewSubmissions?filter[app]={app_id}&limit=5")
    for g in c.get("data", []):
        a = g["attributes"]
        print(f"GÖNDERİM: {a.get('state')} (gönderildi: {a.get('submittedDate')})")
    c = istek(f"/v1/builds?filter[app]={app_id}&limit=3&sort=-uploadedDate")
    for b in c.get("data", []):
        a = b["attributes"]
        print(f"BUILD {a.get('version')}: {a.get('processingState')}")


def main():
    app_id = uygulama_id()
    if SADECE_DURUM:
        durum_raporu(app_id)
        return
    build_id = build_bekle(app_id)
    surum_id = surum_bul(app_id)
    build_sec(surum_id, build_id)
    inceleme_notu_yaz(surum_id)
    if GONDER:
        incelemeye_gonder(app_id, surum_id)
    else:
        print("ℹ️  İncelemeye gönderilmedi (istenmedi). App Store Connect'ten elle "
              "gönderebilir ya da iş akışını 'incelemeye gönder' seçeneğiyle çalıştırabilirsin.")


if __name__ == "__main__":
    main()
