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
        // Her koşuda temiz başla: önceki koşudan kalan kart kaydı akışı bozmasın.
        app.launchArguments += ["-kartTel", "", "-kartAd", "", "-kartPul", "0", "-kartToplam", "0"]
        app.launch()

        // ── 1) Sadakat Kartı sekmesi ──
        let sekme = app.tabBars.buttons["Sadakat Kartı"]
        XCTAssertTrue(sekme.waitForExistence(timeout: 20), "Sadakat Kartı sekmesi görünmedi")
        sekme.tap()
        bekle(2)

        // ── 2) Kart oluştur ──
        let telAlani = app.textFields["05XX XXX XX XX"]
        XCTAssertTrue(telAlani.waitForExistence(timeout: 15), "Telefon alanı görünmedi")
        telAlani.tap()
        telAlani.typeText(Self.testNumarasi)
        bekle(1)

        let adAlani = app.textFields["Adın Soyadın"]
        XCTAssertTrue(adAlani.waitForExistence(timeout: 10), "Ad alanı görünmedi")
        adAlani.tap()
        adAlani.typeText("Silme Testi")
        bekle(1)

        let olustur = app.buttons["Kartımı Oluştur →"]
        XCTAssertTrue(olustur.waitForExistence(timeout: 10), "Oluştur düğmesi görünmedi")
        olustur.tap()

        // ── 3) Kart ekranı açılmalı ──
        let silDugmesi = app.buttons["Hesabımı Sil"]
        XCTAssertTrue(silDugmesi.waitForExistence(timeout: 30),
                      "Kart ekranı açılmadı — kayıt başarısız olmuş olabilir")
        bekle(2)

        // ── 4) Silme düğmesine git ve bas ──
        silDugmesi.tap()
        bekle(2)

        // ── 5) Onay uyarısı ──
        let uyari = app.alerts.firstMatch
        XCTAssertTrue(uyari.waitForExistence(timeout: 10), "Onay uyarısı çıkmadı")
        bekle(2)
        uyari.buttons["Hesabımı Sil"].tap()

        // ── 6) Sonuç ──
        // Silme başarılıysa kayıt ekranına döneriz; sunucu reddederse hata yazısı çıkar.
        // İkisi de geçerli bir SONUÇ; test burada çökme olmadığını doğruluyor.
        bekle(8)
        let kayitEkrani = app.staticTexts["Sadakat Kartını Oluştur"]
        if kayitEkrani.exists {
            print("SONUÇ: hesap silindi, kayıt ekranına dönüldü.")
        } else {
            print("SONUÇ: silme tamamlanmadı — uygulamada hata mesajı gösteriliyor.")
        }
        XCTAssertTrue(app.state == .runningForeground, "Uygulama çöktü ya da arka plana düştü")
    }

    /// Ekran kaydında adımların seçilebilmesi için kasıtlı bekleme.
    private func bekle(_ saniye: TimeInterval) {
        Thread.sleep(forTimeInterval: saniye)
    }

    /// Gerçek müşteri verisine dokunmamak için sabit sahte numara.
    /// Workflow bunu ortam değişkeniyle değiştirebilir.
    private static var testNumarasi: String {
        ProcessInfo.processInfo.environment["TEST_NUMARASI"] ?? "05550000009"
    }
}
