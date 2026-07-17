// Cactus Coffee — 3 sekmeli iOS uygulaması.
// Menü sekmesi siteyi gösterir; Sadakat Kartı ve İletişim tamamen native'dir
// (App Review 4.2 "minimum functionality" gerekçesine cevaben eklendi).
import SwiftUI
import WebKit
import UIKit

let MENU_URL = URL(string: "https://cactuscafes.com/menu-podyum.html")!
let API = "https://cactus-rapor-api.batuhanbulut.workers.dev"
let YESIL = Color(red: 0.18, green: 0.35, blue: 0.15)
let KREM = Color(red: 0.99, green: 0.98, blue: 0.95)
let ALTIN = Color(red: 0.78, green: 0.66, blue: 0.42)
let ESIK = 7

@main
struct CactusCoffeeApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
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

// ═══════════ MENÜ SEKMESİ (web görünümü) ═══════════

struct MenuTab: View {
    @State private var baglantiHatasi = false
    var body: some View {
        ZStack {
            KREM.ignoresSafeArea()
            if baglantiHatasi {
                VStack(spacing: 14) {
                    Text("🌵").font(.system(size: 56))
                    Text("Bağlantı kurulamadı").font(.headline)
                    Text("İnternet bağlantını kontrol edip tekrar dene.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Tekrar Dene") { baglantiHatasi = false }
                        .padding(.horizontal, 26).padding(.vertical, 11)
                        .background(YESIL).foregroundColor(.white).clipShape(Capsule())
                }
                .padding(30)
            } else {
                SiteView(baglantiHatasi: $baglantiHatasi)
            }
        }
    }
}

struct SiteView: UIViewRepresentable {
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
        context.coordinator.webView = wv
        let yenile = UIRefreshControl()
        yenile.addTarget(context.coordinator, action: #selector(Coordinator.yenile(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = yenile
        wv.load(URLRequest(url: MENU_URL))
        return wv
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SiteView
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
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            let scheme = url.scheme ?? ""
            if scheme != "http" && scheme != "https" {
                UIApplication.shared.open(url); decisionHandler(.cancel); return
            }
            let host = url.host ?? ""
            if host.hasSuffix("cactuscafes.com") || host.hasSuffix("workers.dev") {
                decisionHandler(.allow)
            } else if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true {
                UIApplication.shared.open(url); decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}

// ═══════════ SADAKAT KARTI SEKMESİ (tamamen native) ═══════════

enum KartAPI {
    static func sayi(_ v: Any?) -> Int {
        if let i = v as? Int { return i }
        if let d = v as? Double { return Int(d) }
        if let s = v as? String { return Int(s) ?? 0 }
        return 0
    }
    static func bak(_ tel: String) async -> (ad: String, pul: Int, toplam: Int, gecmis: [String])? {
        guard let url = URL(string: API + "/kart/bak?telefon=" + tel),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (j["ok"] as? Bool) == true,
              let m = j["musteri"] as? [String: Any] else { return nil }
        var satirlar: [String] = []
        for g in (j["gecmis"] as? [[String: Any]] ?? []).prefix(5) {
            let tip = (g["tip"] as? String) == "kullandi" ? "🎁 Bedava içecek" : "⭐ +\(sayi(g["miktar"])) yıldız"
            let tarih = String((g["tarih"] as? String ?? "").prefix(10))
            satirlar.append(tip + "  ·  " + tarih)
        }
        return (m["ad"] as? String ?? "", sayi(m["pul"]), sayi(m["toplam_kazanilan"]), satirlar)
    }
    static func kayit(_ tel: String, _ ad: String) async -> Bool {
        guard let url = URL(string: API + "/kart/kayit") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["telefon": tel, "ad": ad])
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return (j["ok"] as? Bool) == true
    }
}

struct KartTab: View {
    @AppStorage("kartTel") private var kayitliTel = ""
    @AppStorage("kartAd") private var kayitliAd = ""
    @State private var girisTel = ""
    @State private var girisAd = ""
    @State private var pul = 0
    @State private var toplam = 0
    @State private var gecmis: [String] = []
    @State private var yukleniyor = false
    @State private var hataMsg = ""

    var body: some View {
        ZStack {
            KREM.ignoresSafeArea()
            ScrollView {
                if kayitliTel.count == 11 { kartGovde } else { kayitGovde }
            }
        }
        .onAppear { if kayitliTel.count == 11 { Task { await tazele() } } }
    }

    // — Kayıt / giriş ekranı —
    private var kayitGovde: some View {
        VStack(spacing: 16) {
            Text("🌵").font(.system(size: 52)).padding(.top, 40)
            Text("Sadakat Kartını Oluştur").font(.title2.bold()).foregroundColor(YESIL)
            Text("7 yıldız topla, 1 bedava içecek kazan.\nUygulama yok, kart yok — telefonun yeterli.")
                .font(.subheadline).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            TextField("05XX XXX XX XX", text: $girisTel)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .onChange(of: girisTel) { yeni in
                    girisTel = String(yeni.filter { $0.isNumber }.prefix(11))
                }
            TextField("Adın Soyadın", text: $girisAd)
                .textFieldStyle(.roundedBorder)
            if !hataMsg.isEmpty {
                Text(hataMsg).font(.footnote).foregroundColor(.red)
            }
            Button {
                Task { await kayitOl() }
            } label: {
                if yukleniyor { ProgressView().tint(.white) } else { Text("Kartımı Oluştur →").bold() }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 13)
            .background(girisTel.count == 11 ? YESIL : Color.gray.opacity(0.4))
            .foregroundColor(.white).clipShape(Capsule())
            .disabled(girisTel.count != 11 || yukleniyor)
            Button("Zaten kartın var mı? Telefonla gör") {
                Task { await mevcutKartiGetir() }
            }
            .font(.footnote).foregroundColor(ALTIN)
            Text("🔒 Numaran yalnızca sadakat puanların için kullanılır.")
                .font(.caption2).foregroundColor(.secondary)
        }
        .padding(28)
    }

    // — Kart ekranı —
    private var kartGovde: some View {
        let gosterilen = pul % ESIK
        let hak = pul / ESIK
        return VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("CACTUS").font(.system(.title3, design: .serif).bold())
                    Spacer()
                    Text("☕").font(.title3)
                }
                Text(kayitliAd.isEmpty ? "Üye" : kayitliAd).font(.headline)
                HStack(spacing: 8) {
                    ForEach(0..<ESIK, id: \.self) { i in
                        ZStack {
                            Circle()
                                .fill(i < gosterilen ? ALTIN : Color.white.opacity(0.18))
                                .frame(width: 36, height: 36)
                            if i < gosterilen { Text("⭐").font(.system(size: 16)) }
                        }
                    }
                }
                ProgressView(value: Double(gosterilen), total: Double(ESIK)).tint(ALTIN)
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(gosterilen)/\(ESIK)").font(.title3.bold())
                        Text("Yıldız").font(.caption2).opacity(0.8)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(hak) hak").font(.title3.bold())
                        Text("Bedava içecek").font(.caption2).opacity(0.8)
                    }
                }
            }
            .padding(20).foregroundColor(.white)
            .background(LinearGradient(colors: [YESIL, Color(red: 0.10, green: 0.22, blue: 0.08)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.top, 20)

            if hak > 0 {
                HStack(spacing: 10) {
                    Text("🎉").font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Bedava içecek hakkın var!").font(.subheadline.bold())
                        Text("Kasada bu ekranı göster — ödemeyi bırak bize.")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14).background(ALTIN.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            HStack {
                istatistik("\(pul)", "Mevcut yıldız")
                istatistik("\(toplam)", "Toplam yıldız")
            }

            if !gecmis.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SON İŞLEMLER").font(.caption.bold()).foregroundColor(.secondary)
                    ForEach(gecmis, id: \.self) { satir in
                        Text(satir).font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10).background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            Button {
                Task { await tazele(); dokunum() }
            } label: {
                Label(yukleniyor ? "Yenileniyor…" : "Yenile", systemImage: "arrow.clockwise")
                    .font(.subheadline.bold())
            }
            .disabled(yukleniyor)

            ShareLink(item: URL(string: "https://cactuscafes.com/kart.html")!,
                      message: Text("Cactus Coffee'de 7 yıldıza 1 içecek bedava — kartını oluştur! 🌵")) {
                Label("Arkadaşına öner", systemImage: "square.and.arrow.up").font(.footnote)
            }

            Button("Çıkış Yap") {
                kayitliTel = ""; kayitliAd = ""; pul = 0; toplam = 0; gecmis = []
            }
            .font(.caption).foregroundColor(.secondary).padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }

    private func istatistik(_ deger: String, _ etiket: String) -> some View {
        VStack(spacing: 2) {
            Text(deger).font(.title2.bold()).foregroundColor(YESIL)
            Text(etiket).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func dokunum() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    @MainActor private func tazele() async {
        yukleniyor = true
        defer { yukleniyor = false }
        if let v = await KartAPI.bak(kayitliTel) {
            pul = v.pul; toplam = v.toplam; gecmis = v.gecmis
            if !v.ad.isEmpty { kayitliAd = v.ad }
        }
    }

    @MainActor private func kayitOl() async {
        hataMsg = ""
        guard girisTel.count == 11, girisTel.hasPrefix("0") else {
            hataMsg = "Lütfen 11 haneli numaranı gir (05XX...)."; return
        }
        yukleniyor = true
        defer { yukleniyor = false }
        // Numara zaten kayıtlıysa doğrudan kartı getir; değilse kayıt aç.
        if let v = await KartAPI.bak(girisTel) {
            kayitliTel = girisTel; kayitliAd = v.ad
            pul = v.pul; toplam = v.toplam; gecmis = v.gecmis
            dokunum(); return
        }
        guard girisAd.trimmingCharacters(in: .whitespaces).count >= 2 else {
            hataMsg = "Adını soyadını da yazar mısın?"; return
        }
        if await KartAPI.kayit(girisTel, girisAd.trimmingCharacters(in: .whitespaces)) {
            kayitliTel = girisTel; kayitliAd = girisAd
            await tazele(); dokunum()
        } else {
            hataMsg = "Kayıt yapılamadı — internetini kontrol edip tekrar dene."
        }
    }

    @MainActor private func mevcutKartiGetir() async {
        hataMsg = ""
        guard girisTel.count == 11 else { hataMsg = "Önce telefon numaranı yaz."; return }
        yukleniyor = true
        defer { yukleniyor = false }
        if let v = await KartAPI.bak(girisTel) {
            kayitliTel = girisTel; kayitliAd = v.ad
            pul = v.pul; toplam = v.toplam; gecmis = v.gecmis
            dokunum()
        } else {
            hataMsg = "Bu numaraya kayıtlı kart bulunamadı."
        }
    }
}

// ═══════════ İLETİŞİM SEKMESİ (native) ═══════════

struct IletisimTab: View {
    var body: some View {
        ZStack {
            KREM.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 14) {
                    Text("🌵").font(.system(size: 48)).padding(.top, 30)
                    Text("Cactus Coffee").font(.title2.bold()).foregroundColor(YESIL)
                    Text("Podyumpark AVM · Bursa").font(.subheadline).foregroundColor(.secondary)

                    satir("phone.fill", "Bizi Ara", "0538 014 66 00", "tel:+905380146600")
                    satir("message.fill", "WhatsApp", "Mesaj yaz", "https://wa.me/905380146600")
                    satir("map.fill", "Yol Tarifi", "Podyumpark AVM, Bursa",
                          "https://maps.apple.com/?q=Cactus+Coffee+Podyumpark+AVM+Bursa")
                    satir("camera.fill", "Instagram", "@cactuscafe.tr", "https://instagram.com/cactuscafe.tr")
                    satir("globe", "Web Sitemiz", "cactuscafes.com", "https://cactuscafes.com")

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

    private func satir(_ ikon: String, _ baslik: String, _ alt: String, _ link: String) -> some View {
        Button {
            if let u = URL(string: link) { UIApplication.shared.open(u) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: ikon)
                    .frame(width: 40, height: 40)
                    .background(YESIL.opacity(0.1)).foregroundColor(YESIL)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(baslik).font(.subheadline.bold()).foregroundColor(.primary)
                    Text(alt).font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(12).background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
