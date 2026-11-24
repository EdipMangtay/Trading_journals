# Liquidity Edge v6.0.0 — Native macOS Sürümü

Apple Silicon ve Intel işlemcili tüm macOS 14+ bilgisayarlar için yerel **Swift, SwiftUI, SwiftData ve Swift Charts** uygulaması.

## Kurulum Dosyaları

Aşağıdaki resmi kurulum dosyalarından birini indirin (kaynak kodu ZIP'ini indirmeyin):

- **Liquidity-Edge-macOS-Universal.dmg** (Önerilen): Açın ve `Liquidity Edge.app` uygulamasını Uygulamalar (`Applications`) klasörüne sürükleyin.
- **Liquidity-Edge-macOS-Universal.pkg**: Standart Apple kurulum sihirbazı ile `/Applications` içine kurun.
- **SHA256SUMS-macOS.txt**: Paket bütünlüğü için SHA-256 özetleri.

## v6.0.0 Yenilikleri

- **Pratik 5 Sekmeli QT & ICT İşlem Giriş Ekranı:** İngilizce trading terminolojisi (`AMDX/XAMD`, `True Open TDO/TSO/T90O`, `Pro-Trend / Counter-Trend`, `ERL ↔ IRL`, `CISD/MSS/IFVG/OB/SSMT/MMXM/PO3/CRT`) + doğal Türkçe yönlendirmeler, canlı üst özet şeridi, tek tıkla `Hızlı Risk %` / `Hızlı R` ve QT hazır şablonları.
- **Yüksek Performans Motoru (~2,5x Hızlanma):** Tek geçişli `AnalyticsEngine`, $O(N)$ dairesel tampon eğrileri, `PreparedQuery` hızlı arama, `O(1)` önbellekli hesap filtreleme, `NSCache` tabanlı `ImageCache` (120fps görsel/çizim) ve arka planda çalışan asenkron Monte Carlo simülasyonu.
- **Üst Düzey UI & Grafik Animasyonları:** Dairesel `ExecutionScoreRing` süreç göstergesi, soldan sağa grafik çizim animasyonu, çift katmanlı ışıltılı `Halo + Core` sermaye eğrileri, taşma korumalı cam crosshair HUD, Trackpad haptik geri bildirimi, kayan kenar çubuğu göstergesi ve ayrıştırılmış çok serili Monte Carlo grafiği.
- **Çoklu Hesap & Prop Firm Risk Merkezi:** Personal, Evaluation ve Funded hesap desteği; statik ve gün sonu (EOD) trailing drawdown, günlük kayıp limiti, minimum işlem günü ve tutarlılık yüzdesi takibi.
- **Strateji Araştırma Laboratuvarı, Günlük Plan & CSV Aktarım Sihirbazı:** Setup × Seans / Enstrüman matrisleri, kayıtlı filtreler, QT/MMXM/CRT kontrol listeleri, kademeli giriş/çıkış (`Fills`) defteri ve geriye dönük tam uyumlu SwiftData V1 → V2 geçişi.

**İlk açılış notu:** Açık kaynaklı ad-hoc imzalı derleme olduğu için macOS ilk açılışta onay isteyebilir. **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** adımını kullanabilir veya `xattr -cr "/Applications/Liquidity Edge.app"` çalıştırabilirsiniz. Detaylar: [INSTALLATION.md](https://github.com/EdipMangtay/Trading_journals/blob/main/INSTALLATION.md).
