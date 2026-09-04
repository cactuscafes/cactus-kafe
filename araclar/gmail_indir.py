#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gmail RAW çıktısını .eml'e çevirir.

Gmail bağlayıcısının `get_message(messageFormat="RAW")` çıktısı, base64url
kodlu tam MIME iletisini `raw` alanında taşır. Bu betik o JSON dosyalarını
earsiv_ayikla.py'nin okuyabileceği .eml dosyalarına dönüştürür.

Kullanım:
  python3 gmail_indir.py <raw_json...> -d gelen/
  python3 earsiv_ayikla.py gelen/ -o e-arsiv --vkn <VKN>
"""
import argparse, base64, email, email.policy, json, os, re, sys


def eml_yaz(json_yolu, hedef_dizin):
    with open(json_yolu, encoding="utf-8") as f:
        veri = json.load(f)
    ham_b64 = veri.get("raw")
    if not ham_b64:
        print(f"  ! 'raw' alanı yok, atlandı: {json_yolu}", file=sys.stderr)
        return None
    # base64url; dolgu eksik olabilir
    ham = base64.urlsafe_b64decode(ham_b64 + "=" * (-len(ham_b64) % 4))

    msg = email.message_from_bytes(ham, policy=email.policy.default)
    konu = (msg.get("Subject") or veri.get("id") or "ileti").strip()
    ad = re.sub(r"[^\w\s.-]", "_", konu)[:60].strip() or "ileti"
    hedef = os.path.join(hedef_dizin, f"{ad}_{veri.get('id', '')[:8]}.eml")

    os.makedirs(hedef_dizin, exist_ok=True)
    with open(hedef, "wb") as f:
        f.write(ham)

    ekler = [p.get_filename() for p in msg.walk() if p.get_filename()]
    print(f"  {os.path.basename(hedef)}  ({len(ham):,} bayt, {len(ekler)} ek: {', '.join(ekler) or '-'})")
    return hedef


def main(argv=None):
    ap = argparse.ArgumentParser(description="Gmail RAW JSON -> .eml")
    ap.add_argument("json_dosyalari", nargs="+")
    ap.add_argument("-d", "--dizin", default="gelen", help="hedef klasör (varsayılan: gelen)")
    a = ap.parse_args(argv)

    yazilan = [y for y in (eml_yaz(j, a.dizin) for j in a.json_dosyalari) if y]
    print(f"\n{len(yazilan)} ileti {a.dizin}/ altına yazıldı.")
    print(f"Sonraki adım: python3 earsiv_ayikla.py {a.dizin} -o e-arsiv --vkn <VKN>")
    return 0


if __name__ == "__main__":
    sys.exit(main())
