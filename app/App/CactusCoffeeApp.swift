// Cactus Coffee — 3 sekmeli iOS uygulaması.
// Menü sekmesi canlı menüyü gösterir; Sadakat Kartı ve İletişim tamamen native'dir
// (App Review 4.2 "minimum functionality" gerekçesine cevaben).
//
// Renkler bilinçli olarak sabittir ve uygulama açık temaya kilitlidir: marka rengi
// krem/yeşil, koyu temada beyaz kart üzerine beyaz yazı sorunu böylece oluşmaz.
import SwiftUI
import WebKit
import UIKit
import CoreImage.CIFilterBuiltins

let ANASAYFA_URL = URL(string: "https://cactuscafes.com")!
let MENU_URL = URL(string: "https://cactuscafes.com/menu-podyum.html")!
let API = "https://cactus-rapor-api.batuhanbulut.workers.dev"
// Hesap silme ucu site worker'ında (kart-sil, yönetim anahtarını sunucuda tutar)
let SITE_API = "https://cactus-kafe.batuhanbulut.workers.dev"
let ESIK = 7

let YESIL = Color(red: 0.18, green: 0.35, blue: 0.15)
let YESIL_KOYU = Color(red: 0.10, green: 0.22, blue: 0.08)
let KREM = Color(red: 0.99, green: 0.98, blue: 0.95)
let ALTIN = Color(red: 0.78, green: 0.66, blue: 0.42)
let KOYU = Color(red: 0.16, green: 0.16, blue: 0.16)   // .primary yerine (koyu tema güvenli)
let SOLGUN = Color(red: 0.45, green: 0.45, blue: 0.45) // .secondary yerine

@main
struct CactusCoffeeApp: App {
    var body: some Scene {
        WindowGroup {
            RootView().preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            AnasayfaTab()
                .tabItem { Label("Anasayfa", systemImage: "house.fill") }
            MenuTab()
                .tabItem { Label("Menü", systemImage: "cup.and.saucer.fill") }
            KartTab()
                .tabItem { Label("Sadakat Kartı", systemImage: "star.fill") }
            IletisimTab()
                .tabItem { Label("İletişim", systemImage: "phone.fill") }
        }
        .tint(YESIL)
    }
}

/// Marka logosu — native ekranların tepesinde emoji yerine gerçek logo.
/// Web sekmeleri (Anasayfa/Menü) logoyu sayfanın kendi başlığından zaten
/// gösterdiği için oralarda tekrar edilmiyor; çift logo olmasın.
struct CactusLogo: View {
    var genislik: CGFloat = 150
    /// Koyu zeminde (yeşil kart) açık renkli sürüm kullanılır, yoksa logo kaybolur.
    var acikSurum = false

    var body: some View {
        Image(acikSurum ? "LogoLight" : "Logo")
            .resizable()
            .scaledToFit()
            .frame(width: genislik)
            .accessibilityLabel("Cactus Coffee")
    }
}

// ═══════════════════ ORTAK YARDIMCILAR ═══════════════════

/// Girilen numarayı sunucunun beklediği 11 haneli 05XX biçimine çevirir.
/// Sunucu (rapor-api) yalnızca bu biçimi kabul ediyor, o yüzden kullanıcı
/// hangi alışkanlıkla yazarsa yazsın burada tek biçime indiriyoruz:
///   "+90 555 111 22 33" / "90555…" / "555 111 22 33" / "0555…" → "05551112233"
/// Çevrilemeyen (Türkiye cep numarası olmayan) girdiler için nil döner.
func telNormalize(_ ham: String) -> String? {
    var d = ham.filter { $0.isNumber }
    if d.hasPrefix("90") && d.count == 12 { d = String(d.dropFirst(2)) }  // +90 5xx…
    if d.hasPrefix("0") { d = String(d.dropFirst()) }                     // 0 5xx…
    guard d.count == 10, d.hasPrefix("5") else { return nil }             // 5xx + 7 hane
    return "0" + d
}

func telBicimle(_ ham: String) -> String {
    let d = ham.filter { $0.isNumber }
    guard d.count == 11 else { return ham }
    let p = Array(d)
    return "\(p[0])\(p[1])\(p[2])\(p[3]) \(p[4])\(p[5])\(p[6]) \(p[7])\(p[8]) \(p[9])\(p[10])"
}

/// "2026-07-15T18:20:00Z" → "15.07.2026"
func tarihBicimle(_ ham: String) -> String {
    let g = String(ham.prefix(10)).split(separator: "-")
    guard g.count == 3 else { return String(ham.prefix(10)) }
    return "\(g[2]).\(g[1]).\(g[0])"
}

func qrUret(_ metin: String) -> UIImage? {
    let filtre = CIFilter.qrCodeGenerator()
    filtre.message = Data(metin.utf8)
    guard let cikti = filtre.outputImage?.transformed(by: CGAffineTransform(scaleX: 7, y: 7)),
          let cg = CIContext().createCGImage(cikti, from: cikti.extent) else { return nil }
    return UIImage(cgImage: cg)
}

func dokunumBasarili() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}

// ═══════════════════ WEB SEKMELERİ (ANASAYFA + MENÜ) ═══════════════════

/// Sitenin bir sayfasını gösteren sekme. Bağlantı koparsa çevrimdışı ekranı çıkar.
struct WebSekmesi: View {
    let url: URL
    @State private var baglantiHatasi = false
    /// Tekrar Dene'de WKWebView'ı yeniden kurmak için — aynı görünüm kalırsa
    /// başarısız sayfa ekranda asılı kalıyor.
    @State private var deneme = 0

    var body: some View {
        ZStack {
            KREM.ignoresSafeArea()
            if baglantiHatasi {
                CevrimdisiEkran { baglantiHatasi = false; deneme += 1 }
            } else {
                SiteView(url: url, baglantiHatasi: $baglantiHatasi)
                    .id(deneme)
            }
        }
    }
}

struct AnasayfaTab: View {
    var body: some View { WebSekmesi(url: ANASAYFA_URL) }
}

struct MenuTab: View {
    var body: some View { WebSekmesi(url: MENU_URL) }
}

struct CevrimdisiEkran: View {
    var tekrarDene: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            CactusLogo(genislik: 170)
            Text("Bağlantı kurulamadı").font(.headline).foregroundColor(KOYU)
            Text("İnternet bağlantını kontrol edip tekrar dene.")
                .font(.subheadline).foregroundColor(SOLGUN)
                .multilineTextAlignment(.center)
            Button(action: tekrarDene) {
                Text("Tekrar Dene").bold()
                    .padding(.horizontal, 26).padding(.vertical, 11)
                    .background(YESIL).foregroundColor(.white).clipShape(Capsule())
            }
        }
        .padding(30)
    }
}

struct HataEkrani: View {
    var mesaj: String
    var tekrarDene: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            CactusLogo(genislik: 150)
            Text("⚠️").font(.system(size: 34))
            Text("Sorun oluştu").font(.headline).foregroundColor(KOYU)
            Text(mesaj)
                .font(.subheadline).foregroundColor(SOLGUN)
                .multilineTextAlignment(.center)
            Button(action: tekrarDene) {
                Text("Tekrar Dene").bold()
                    .padding(.horizontal, 26).padding(.vertical, 11)
                    .background(YESIL).foregroundColor(.white).clipShape(Capsule())
            }
        }
        .padding(30)
    }
}

struct SiteView: UIViewRepresentable {
    let url: URL
    @Binding var baglantiHatasi: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = UIColor(KREM)
        wv.scrollView.backgroundColor = UIColor(KREM)
        context.coordinator.webView = wv

        let yenile = UIRefreshControl()
        yenile.addTarget(context.coordinator, action: #selector(Coordinator.yenile(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = yenile

        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: SiteView
        weak var webView: WKWebView?
        init(_ parent: SiteView) { self.parent = parent }

        @objc func yenile(_ rc: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { rc.endRefreshing() }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                DispatchQueue.main.async { self.parent.baglantiHatasi = true }
            }
        }

        // tel:/mailto:/WhatsApp sistem uygulamasında, dış siteler Safari'de açılır.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            let scheme = url.scheme ?? ""
            if scheme != "http" && scheme != "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            let host = url.host ?? ""
            if host.hasSuffix("cactuscafes.com") || host.hasSuffix("workers.dev") {
                decisionHandler(.allow)
            } else if navigationAction.targetFrame?.isMainFrame ?? true {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// ═══════════════════ SADAKAT KARTI — API ═══════════════════

struct KartBilgi {
    var ad: String
    var pul: Int
    var toplam: Int
    var gecmis: [String]
}

enum KartAPI {
    static func sayi(_ v: Any?) -> Int {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String { return Int(s) ?? 0 }
        return 0
    }

    static func bak(_ tel: String) async -> KartBilgi? {
        guard let url = URL(string: API + "/kart/bak?telefon=" + tel) else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        do {
            let ikili = try await URLSession.shared.data(for: req)
            guard let j = try? JSONSerialization.jsonObject(with: ikili.0) as? [String: Any],
                  (j["ok"] as? Bool) == true,
                  let m = j["musteri"] as? [String: Any] else { return nil }
            var satirlar: [String] = []
            let ham = j["gecmis"] as? [[String: Any]] ?? []
            for g in ham.prefix(5) {
                let kullandi = (g["tip"] as? String) == "kullandi"
                let etiket = kullandi ? "🎁 Bedava içecek" : "⭐ +\(sayi(g["miktar"])) yıldız"
                satirlar.append(etiket + "   ·   " + tarihBicimle(g["tarih"] as? String ?? ""))
            }
            return KartBilgi(ad: m["ad"] as? String ?? "",
                             pul: sayi(m["pul"]),
                             toplam: sayi(m["toplam_kazanilan"]),
                             gecmis: satirlar)
        } catch {
            return nil
        }
    }

    static func kayit(_ tel: String, _ ad: String) async -> Bool {
        guard let url = URL(string: API + "/kart/kayit") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 8
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["telefon": tel, "ad": ad])
        do {
            let ikili = try await URLSession.shared.data(for: req)
            guard let j = try? JSONSerialization.jsonObject(with: ikili.0) as? [String: Any] else { return false }
            return (j["ok"] as? Bool) == true
        } catch {
            return false
        }
    }

    /// Hesabı kalıcı siler: müşteri kaydı + yıldızlar + işlem geçmişi sunucudan kalkar.
    /// App Store Guideline 5.1.1(v) gereği uygulama içinden sunulur.
    static func hesabiSil(_ tel: String) async -> Bool {
        guard let url = URL(string: SITE_API + "/api/kart-sil") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 12
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["telefon": tel])
        do {
            let ikili = try await URLSession.shared.data(for: req)
            guard let j = try? JSONSerialization.jsonObject(with: ikili.0) as? [String: Any] else { return false }
            return (j["ok"] as? Bool) == true
        } catch {
            return false
        }
    }
}

// ═══════════════════ SADAKAT KARTI — EKRAN ═══════════════════

struct KartTab: View {
    @AppStorage("kartTel") private var kayitliTel = ""
    @AppStorage("kartAd") private var kayitliAd = ""
    @AppStorage("kartPul") private var pul = 0
    @AppStorage("kartToplam") private var toplam = 0

    @State private var gecmis: [String] = []
    @State private var yukleniyor = false
    @State private var hata: String = ""

    var body: some View {
        ZStack {
            KREM.ignoresSafeArea()
            if kayitliTel.count >= 10 {
                if !hata.isEmpty {
                    HataEkrani(mesaj: hata) { hata = ""; Task { await tazele(elle: false) } }
                } else {
                    KartGovde(tel: kayitliTel, ad: kayitliAd, pul: pul, toplam: toplam,
                              gecmis: gecmis, yukleniyor: yukleniyor,
                              yenile: { Task { await tazele(elle: true) } },
                              cikis: cikisYap,
                              hesabiSil: { await hesabiSil() })
                        .refreshable { await tazele(elle: false) }
                }
            } else {
                KayitGovde(tamamlandi: kartaGec)
            }
        }
        .onAppear { if kayitliTel.count >= 10 { Task { await tazele(elle: false) } } }
    }

    private func kartaGec(_ tel: String, _ bilgi: KartBilgi) {
        kayitliTel = tel
        kayitliAd = bilgi.ad
        pul = bilgi.pul
        toplam = bilgi.toplam
        gecmis = bilgi.gecmis
        dokunumBasarili()
    }

    private func cikisYap() {
        kayitliTel = ""; kayitliAd = ""; pul = 0; toplam = 0; gecmis = []
    }

    /// Sunucudaki kayıt silinirse cihazdaki kopyayı da temizler.
    /// Sunucu silmeyi onaylamazsa yerel veri KORUNUR — kullanıcıya hata gösterilir.
    @MainActor private func hesabiSil() async -> Bool {
        guard await KartAPI.hesabiSil(kayitliTel) else { return false }
        cikisYap()
        dokunumBasarili()
        return true
    }

    @MainActor private func tazele(elle: Bool) async {
        yukleniyor = true
        defer { yukleniyor = false }
        do {
            if let v = await KartAPI.bak(kayitliTel) {
                pul = v.pul
                toplam = v.toplam
                gecmis = v.gecmis
                if !v.ad.isEmpty { kayitliAd = v.ad }
                if elle { dokunumBasarili() }
                hata = ""
            } else {
                hata = "Kart yüklenemedi. İnternet bağlantınızı kontrol edip tekrar dene."
            }
        } catch {
            hata = "Bağlantı hatası. Tekrar denemek için dokunun."
        }
    }
}

// ── Kayıt / giriş ekranı ──

struct KayitGovde: View {
    var tamamlandi: (String, KartBilgi) -> Void

    @State private var tel = ""
    @State private var ad = ""
    @State private var yukleniyor = false
    @State private var hata = ""

    /// 12 hane: "+90" ile yazanlar da sığsın (normalize ederken kırpılır)
    private var telBinding: Binding<String> {
        Binding(get: { tel },
                set: { tel = String($0.filter { $0.isNumber }.prefix(12)) })
    }

    private var gecerliTel: String? { telNormalize(tel) }

    var body: some View {
        ScrollView {
            VStack(spacing: 15) {
                CactusLogo(genislik: 180).padding(.top, 34)
                Text("Sadakat Kartını Oluştur")
                    .font(.title2.bold()).foregroundColor(YESIL)
                Text("7 yıldız topla, 1 bedava içecek kazan.\nÜyelik yok, şifre yok — telefonun yeterli.")
                    .font(.subheadline).foregroundColor(SOLGUN)
                    .multilineTextAlignment(.center)

                TextField("05XX XXX XX XX", text: telBinding)
                    .keyboardType(.numberPad)
                    .textContentType(.telephoneNumber)
                    .textFieldStyle(.roundedBorder)
                TextField("Adın Soyadın", text: $ad)
                    .textContentType(.name)
                    .textFieldStyle(.roundedBorder)

                if !hata.isEmpty {
                    Text(hata).font(.footnote).foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button { Task { await gonder() } } label: {
                    Group {
                        if yukleniyor { ProgressView().tint(.white) }
                        else { Text("Kartımı Oluştur →").bold() }
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 13)
                    .background(gecerliTel != nil ? YESIL : Color.gray.opacity(0.4))
                    .foregroundColor(.white).clipShape(Capsule())
                }
                .disabled(gecerliTel == nil || yukleniyor)

                Button("Zaten kartın var mı? Telefonla gör") {
                    Task { await mevcutuGetir() }
                }
                .font(.footnote).foregroundColor(ALTIN)

                Text("🔒 Numaran yalnızca sadakat puanların için kullanılır.")
                    .font(.caption2).foregroundColor(SOLGUN)
                    .padding(.top, 4)
            }
            .padding(26)
        }
    }

    @MainActor private func gonder() async {
        hata = ""
        // Sunucu yalnızca 11 haneli 05XX numarasını kabul ediyor — girdiyi ona çeviriyoruz.
        guard let no = gecerliTel else {
            hata = "Cep numaranı 05XX XXX XX XX biçiminde gir (örn. 0555 111 22 33)."
            return
        }
        yukleniyor = true
        defer { yukleniyor = false }
        // Numara zaten kayıtlıysa doğrudan kartı aç
        if let v = await KartAPI.bak(no) { tamamlandi(no, v); return }
        let temizAd = ad.trimmingCharacters(in: .whitespaces)
        guard temizAd.count >= 2 else {
            hata = "Adını soyadını da yazar mısın?"
            return
        }
        if await KartAPI.kayit(no, temizAd) {
            let v = await KartAPI.bak(no) ?? KartBilgi(ad: temizAd, pul: 1, toplam: 1, gecmis: [])
            tamamlandi(no, v)
        } else {
            hata = "Kayıt yapılamadı — internetini kontrol edip tekrar dene."
        }
    }

    @MainActor private func mevcutuGetir() async {
        hata = ""
        guard let no = gecerliTel else {
            hata = "Cep numaranı 05XX XXX XX XX biçiminde gir (örn. 0555 111 22 33)."
            return
        }
        yukleniyor = true
        defer { yukleniyor = false }
        if let v = await KartAPI.bak(no) {
            tamamlandi(no, v)
        } else {
            hata = "Bu numaraya kayıtlı kart bulunamadı."
        }
    }
}

// ── Kart ekranı ──

struct KartGovde: View {
    let tel: String
    let ad: String
    let pul: Int
    let toplam: Int
    let gecmis: [String]
    let yukleniyor: Bool
    let yenile: () -> Void
    let cikis: () -> Void
    let hesabiSil: () async -> Bool

    @State private var silOnayi = false
    @State private var siliniyor = false
    @State private var silHatasi = ""

    private var gosterilen: Int { pul % ESIK }
    private var hak: Int { pul / ESIK }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                dijitalKart
                if hak > 0 { hediyeSeridi }
                kasiyerKutusu
                HStack(spacing: 12) {
                    Kutucuk(deger: "\(pul)", etiket: "Mevcut yıldız")
                    Kutucuk(deger: "\(toplam)", etiket: "Toplam yıldız")
                }
                if !gecmis.isEmpty { gecmisBolumu }
                altDugmeler
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 26)
        }
    }

    private var dijitalKart: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                // Yeşil gradyan üzerinde açık renkli logo
                CactusLogo(genislik: 120, acikSurum: true)
                Spacer()
                Text("☕").font(.title3)
            }
            Text(ad.isEmpty ? "Üye" : ad).font(.headline)
            YildizSirasi(dolu: gosterilen)
            ProgressView(value: Double(gosterilen), total: Double(ESIK)).tint(ALTIN)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(gosterilen)/\(ESIK)").font(.title3.bold())
                    Text("Yıldız").font(.caption2).opacity(0.85)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(hak) hak").font(.title3.bold())
                    Text("Bedava içecek").font(.caption2).opacity(0.85)
                }
            }
        }
        .padding(20)
        .foregroundColor(.white)
        .background(
            LinearGradient(colors: [YESIL, YESIL_KOYU],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.top, 18)
    }

    private var hediyeSeridi: some View {
        HStack(spacing: 10) {
            Text("🎉").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Bedava içecek hakkın var!")
                    .font(.subheadline.bold()).foregroundColor(KOYU)
                Text("Kasada bu ekranı göster — ödemeyi bırak bize.")
                    .font(.caption).foregroundColor(SOLGUN)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(ALTIN.opacity(0.16))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // Kasiyer numarayı hızlıca girebilsin: büyük numara + QR
    private var kasiyerKutusu: some View {
        VStack(spacing: 10) {
            Text("KASADA GÖSTER").font(.caption2.bold()).foregroundColor(SOLGUN)
            Text(telBicimle(tel))
                .font(.system(.title2, design: .monospaced).bold())
                .foregroundColor(KOYU)
            if let qr = qrUret(tel) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 120, height: 120)
            }
            Text("Yıldızın bu numaraya işlenir")
                .font(.caption2).foregroundColor(SOLGUN)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var gecmisBolumu: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SON İŞLEMLER").font(.caption.bold()).foregroundColor(SOLGUN)
            ForEach(gecmis, id: \.self) { satir in
                Text(satir)
                    .font(.footnote).foregroundColor(KOYU)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var altDugmeler: some View {
        VStack(spacing: 12) {
            Button(action: yenile) {
                Label(yukleniyor ? "Yenileniyor…" : "Yenile", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold()).foregroundColor(YESIL)
            }
            .disabled(yukleniyor)

            ShareLink(item: URL(string: "https://cactuscafes.com/kart.html")!,
                      message: Text("Cactus Coffee'de 7 yıldıza 1 içecek bedava — kartını oluştur! 🌵")) {
                Label("Arkadaşına öner", systemImage: "square.and.arrow.up")
                    .font(.footnote).foregroundColor(ALTIN)
            }

            Button("Çıkış Yap", action: cikis)
                .font(.caption).foregroundColor(SOLGUN)

            hesapSilmeBolumu
        }
        .padding(.top, 4)
    }

    // Guideline 5.1.1(v): hesap uygulama içinden, tek adımda kalıcı silinebilmeli.
    private var hesapSilmeBolumu: some View {
        VStack(spacing: 6) {
            Button(role: .destructive) { silOnayi = true } label: {
                Text(siliniyor ? "Siliniyor…" : "Hesabımı Sil")
                    .font(.caption.bold()).foregroundColor(.red)
            }
            .disabled(siliniyor)

            Text("Kartın, yıldızların ve işlem geçmişin kalıcı olarak silinir.")
                .font(.caption2).foregroundColor(SOLGUN)
                .multilineTextAlignment(.center)

            if !silHatasi.isEmpty {
                Text(silHatasi)
                    .font(.caption2).foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 10)
        .alert("Hesabını sil", isPresented: $silOnayi) {
            Button("Vazgeç", role: .cancel) {}
            Button("Hesabımı Sil", role: .destructive) {
                silHatasi = ""
                Task { @MainActor in
                    siliniyor = true
                    let oldu = await hesabiSil()
                    siliniyor = false
                    if !oldu {
                        silHatasi = "Hesap silinemedi. İnternetini kontrol edip tekrar dene."
                    }
                }
            }
        } message: {
            Text("Sadakat kartın, yıldızların ve tüm işlem geçmişin sunucudan kalıcı olarak silinecek. Bu işlem geri alınamaz.")
        }
    }
}

struct YildizSirasi: View {
    let dolu: Int
    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<ESIK, id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(i < dolu ? ALTIN : Color.white.opacity(0.18))
                        .frame(width: 34, height: 34)
                    if i < dolu { Text("⭐").font(.system(size: 15)) }
                }
            }
        }
    }
}

struct Kutucuk: View {
    let deger: String
    let etiket: String
    var body: some View {
        VStack(spacing: 3) {
            Text(deger).font(.title2.bold()).foregroundColor(YESIL)
            Text(etiket).font(.caption2).foregroundColor(SOLGUN)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// ═══════════════════ İLETİŞİM SEKMESİ ═══════════════════

struct IletisimTab: View {
    var body: some View {
        ZStack {
            KREM.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    CactusLogo(genislik: 190).padding(.top, 26)
                    Text("Podyumpark AVM · Bursa")
                        .font(.subheadline).foregroundColor(SOLGUN)
                        .padding(.bottom, 6)

                    IletisimSatiri(ikon: "phone.fill", baslik: "Bizi Ara",
                                   alt: "0538 014 66 00", link: "tel:+905380146600")
                    IletisimSatiri(ikon: "message.fill", baslik: "WhatsApp",
                                   alt: "Mesaj yaz", link: "https://wa.me/905380146600")
                    IletisimSatiri(ikon: "map.fill", baslik: "Yol Tarifi",
                                   alt: "Podyumpark AVM, Bursa",
                                   link: "https://maps.apple.com/?q=Cactus%20Coffee%20Podyumpark%20AVM%20Bursa")
                    IletisimSatiri(ikon: "camera.fill", baslik: "Instagram",
                                   alt: "@cactuscafe.tr", link: "https://instagram.com/cactuscafe.tr")
                    IletisimSatiri(ikon: "globe", baslik: "Web Sitemiz",
                                   alt: "cactuscafes.com", link: "https://cactuscafes.com")

                    ShareLink(item: URL(string: "https://cactuscafes.com")!,
                              message: Text("Cactus Coffee — Podyumpark 🌵")) {
                        Label("Cactus'u Paylaş", systemImage: "square.and.arrow.up")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 13)
                            .background(YESIL).foregroundColor(.white).clipShape(Capsule())
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
    }
}

struct IletisimSatiri: View {
    let ikon: String
    let baslik: String
    let alt: String
    let link: String

    var body: some View {
        Button {
            if let u = URL(string: link) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: ikon)
                    .frame(width: 40, height: 40)
                    .background(YESIL.opacity(0.1))
                    .foregroundColor(YESIL)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(baslik).font(.subheadline.bold()).foregroundColor(KOYU)
                    Text(alt).font(.caption).foregroundColor(SOLGUN)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption).foregroundColor(SOLGUN)
            }
            .padding(12)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
