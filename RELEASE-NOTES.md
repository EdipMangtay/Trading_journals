# Liquidity Edge v6.0.0 — Native macOS Sürümü

Apple Silicon ve Intel işlemcili tüm macOS 14+ bilgisayarlar için yerel **Swift, SwiftUI, SwiftData ve Swift Charts** uygulaması.

## Kurulum Dosyaları

Aşağıdaki resmi kurulum dosyalarından birini indirin (kaynak kodu ZIP'ini indirmeyin):

- **Liquidity-Edge-macOS-Universal.dmg** (Önerilen): Açın ve `Liquidity Edge.app` uygulamasını Uygulamalar (`Applications`) klasörüne sürükleyin.
- **Liquidity-Edge-macOS-Universal.pkg**: Standart Apple kurulum sihirbazı ile `/Applications` içine kurun.
- **SHA256SUMS-macOS.txt**: Paket bütünlüğü için SHA-256 özetleri.

## v6.0.0 Yenilikleri

- **Esnek 5 Sekmeli QT & ICT İşlem Giriş Ekranı:** İngilizce trading terminolojisi (`AMDX/XAMD`, `True Open TDO/TSO/T90O`, `Pro-Trend / Counter-Trend`, `ERL ↔ IRL`, `CISD/MSS/IFVG/OB/SSMT/MMXM/PO3/CRT`) + doğal Türkçe yönlendirmeler, canlı üst özet şeridi, tek tıkla `Hızlı Risk %` / `Hızlı R`, QT hazır şablonları ve **tüm opsiyonel çiplerde ikinci tıkla seçim kaldırma** esnekliği.
- **Üst Düzey Performans Motoru (~4,7× Hızlanma):** Zero-allocation `PerformanceAccumulator`, önbellekli `L10n` çeviri ve statik regex ön-kontrolü, `O(1)` ön-hesaplanmış `JournalStore` metrik/eğri önbellekleri, toplu `saveBatch` aktarımı, `PreparedQuery` hızlı arama, `NSCache` tabanlı `ImageCache` ve asenkron Monte Carlo simülasyonu.
- **Kurumsal Terminal UI & Grafik Animasyonları:** Canlı bakiye/bugün/seri telemetri şeridi, zengin alt metrikli 5 sütunlu KPI bandı, orantılı süreç sınıflandırma çubuğu, `ExecutionScoreRing`, soldan sağa grafik çizim animasyonu, çift katmanlı ışıltılı `Halo + Core` sermaye eğrileri, cam crosshair HUD, Trackpad haptik geri bildirimi ve yön renkli işlem listesi/detay akışı.
- **Her Yerden Strateji Yönetimi & Çoklu Hesap Risk Merkezi:** Strateji Defteri, Strateji Analizi ve İşlem Editörü içinden anında strateji oluşturma; Personal, Evaluation ve Funded hesap desteği; statik ve gün sonu (EOD) trailing drawdown, günlük kayıp limiti, minimum işlem günü ve tutarlılık yüzdesi takibi.
- **Strateji Araştırma Laboratuvarı, Günlük Plan & RFC-4180 CSV Sihirbazı:** Setup × Seans / Enstrüman matrisleri, kayıtlı filtreler, işlemlere 1 tıkla yüklenebilen QT/MMXM/CRT kontrol listesi şablonları, kademeli giriş/çıkış (`Fills`) defteri, 17 alanlı tırnak duyarlı CSV aktarım sihirbazı ve geriye dönük tam uyumlu SwiftData V1 → V2 geçişi.

**İlk açılış notu:** Açık kaynaklı ad-hoc imzalı derleme olduğu için macOS ilk açılışta onay isteyebilir. **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** adımını kullanabilir veya `xattr -cr "/Applications/Liquidity Edge.app"` çalıştırabilirsiniz. Detaylar: [INSTALLATION.md](https://github.com/EdipMangtay/Trading_journals/blob/main/INSTALLATION.md).
