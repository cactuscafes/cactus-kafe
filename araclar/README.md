# araclar/ — muhasebe yardımcıları

Siteye ait değildir; elle çalıştırılan yardımcı betiklerdir.

## earsiv_ayikla.py

E-postalardaki ve klasördeki e-Arşiv / e-Fatura eklerini tarayıp tek bir
Excel/CSV tablosuna döker.

```bash
pip install openpyxl pypdf
python3 araclar/earsiv_ayikla.py <klasor> -o e-arsiv-nisan --vkn <kendi VKN'niz>
```

* Girdi: `.eml` (ekleri açılır), `.zip` (özyinelemeli), `.xml` (UBL-TR), `.pdf` (GİB e-Arşiv).
* Çıktı: `<ad>.xlsx` (başlık dondurma + otomatik filtre + TOPLAM satırı) ve `<ad>.csv` (UTF-8 BOM, `;` ayraç — Excel-TR uyumlu).
* ETTN ile tekilleştirir; aynı fatura hem XML hem PDF geldiyse XML'i tercih eder.
* KDV'yi oran bazında dökümler, KDV tevkifatını (vergi kodu 9015) ayrı sütunda tutar.
* `--vkn` verilirse her satırı ALIŞ / SATIŞ olarak işaretler.

Fatura olmayan ekler (imza, reklam görseli vb.) atlanır ve özet çıktıda listelenir.
