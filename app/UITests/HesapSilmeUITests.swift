// Hesap silme akışının simülatörde uçtan uca sürülmesi.
// Amaç: Apple'a gönderilecek ekran kaydı için akışı otomatik oynatmak ve
// aynı zamanda çökme/donma olmadığını doğrulamak.
//
// Koordinat kullanılmıyor — her öğe erişilebilirlik etiketiyle bulunuyor,
// böylece yerleşim değişse de test kırılmıyor.
import XCTest

final class HesapSilmeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHesapSilmeAkisi() throws {
        let app = XCUIApplication()
        app.launch()

        // ── 1) Sadakat Kartı sekmesi ──
        let sekme = app.tabBars.buttons["Sadakat Kartı"]
        XCTAssertTrue(sekme.waitForExistence(timeout: 30), "Sadakat Kartı sekmesi görünmedi")
        sekme.tap()
        bekle(2)

        // ── 2) Kart oluştur ──
        let telAlani = app.textFields["05XX XXX XX XX"]
        XCTAssertTrue(telAlani.waitForExistence(timeout: 20), "Telefon alanı görünmedi")
        telAlani.tap()
        telAlani.typeText(Self.testNumarasi)
        bekle(1)

        let adAlani = app.textFields["Adın Soyadın"]
        XCTAssertTrue(adAlani.waitForExistence(timeout: 10), "Ad alanı görünmedi")
        adAlani.tap()
        adAlani.typeText("Silme Testi")
        bekle(1)

        // Etiketteki "→" biçim değişikliklerine takılmamak için ön ekle eşleştir.
        let olustur = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Kartımı Oluştur")
        ).firstMatch
        XCTAssertTrue(olustur.waitForExistence(timeout: 10), "Oluştur düğmesi görünmedi")
        // Numara geçersiz kalmışsa düğme pasiftir — dokunmadan önce bunu bilmek isteriz.
        XCTAssertTrue(olustur.isEnabled,
                      "Oluştur düğmesi pasif — telefon alanına metin girilememiş olabilir")
        olustur.tap()

        // ── 3) Kart ekranı açıldı mı? ──
        // Kart ekranının ÜST kısmındaki bir öğeye bakıyoruz; "Hesabımı Sil" en altta
        // olduğu için SwiftUI onu daha oluşturmamış olabilir ve yanlış negatif verir.
        let kasada = app.staticTexts["KASADA GÖSTER"]
        if !kasada.waitForExistence(timeout: 40) {
            tanilariYaz(app)
            XCTFail("Kart ekranı açılmadı — kayıt başarısız olmuş olabilir")
            return
        }
        bekle(2)

        // ── 4) Silme düğmesine kaydır ──
        let silDugmesi = app.buttons["Hesabımı Sil"]
        var deneme = 0
        while !silDugmesi.exists && deneme < 10 {
            app.swipeUp()
            bekle(1)
            deneme += 1
        }
        if !silDugmesi.exists {
            tanilariYaz(app)
            XCTFail("Hesabımı Sil düğmesi bulunamadı")
            return
        }
        bekle(2)
        silDugmesi.tap()

        // ── 5) Onay uyarısı ──
        let uyari = app.alerts.firstMatch
        XCTAssertTrue(uyari.waitForExistence(timeout: 15), "Onay uyarısı çıkmadı")
        bekle(3)
        uyari.buttons["Hesabımı Sil"].tap()

        // ── 6) Sonuç ──
        // Silme başarılıysa kayıt ekranına döneriz; sunucu reddederse hata yazısı çıkar.
        // İkisi de geçerli bir SONUÇ; test burada çökme olmadığını doğruluyor.
        bekle(10)
        if app.staticTexts["Sadakat Kartını Oluştur"].exists {
            print("SONUÇ: hesap silindi, kayıt ekranına dönüldü.")
        } else {
            print("SONUÇ: silme tamamlanmadı — uygulamada hata mesajı gösteriliyor.")
        }
        XCTAssertTrue(app.state == .runningForeground, "Uygulama çöktü ya da arka plana düştü")
    }

    /// Beklenmedik durumda ekranda ne olduğunu loga döker — körlemesine tahmin etmemek için.
    private func tanilariYaz(_ app: XCUIApplication) {
        print("TANI: uygulama durumu = \(app.state.rawValue)")
        for e in app.staticTexts.allElementsBoundByIndex.prefix(25) where !e.label.isEmpty {
            print("TANI metin: \(e.label)")
        }
        for e in app.buttons.allElementsBoundByIndex.prefix(25) where !e.label.isEmpty {
            print("TANI düğme: \(e.label) (aktif: \(e.isEnabled))")
        }
        for e in app.textFields.allElementsBoundByIndex.prefix(10) {
            print("TANI alan: \(e.label) = \(String(describing: e.value))")
        }
    }

    /// Ekran kaydında adımların seçilebilmesi için kasıtlı bekleme.
    private func bekle(_ saniye: TimeInterval) {
        Thread.sleep(forTimeInterval: saniye)
    }

    /// Gerçek müşteri verisine dokunmamak için sahte numara.
    private static var testNumarasi: String {
        ProcessInfo.processInfo.environment["TEST_NUMARASI"] ?? "05550000009"
    }
}
