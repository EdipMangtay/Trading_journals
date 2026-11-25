# Liquidity Edge v6.3.2 — Native macOS Sürümü

Apple Silicon ve Intel işlemcili tüm macOS 14+ bilgisayarlar için yerel **Swift, SwiftUI, SwiftData, Accelerate, PDFKit ve Swift Charts** uygulaması (%100 cihaz içi, bulutsuz ve sıfır görüntü işleme/OCR).

## v6.3.2 Yenilikleri

- **Ultra Cihaz İçi AI & ML Motoru (`EdgeMLEngine`):** Zaman sönümlü `L2 Logistic Regression` + `L2 Ridge Regression` + `Empirical Bayes` karması, çok çekirdekli paralel kronolojik **Walk-Forward ROC-AUC / Brier Skill** doğrulaması, **CUSUM & EWMA Piyasa Rejimi & Risk Çarpanı (`1.10x` / `1.00x` / `0.75x` / `0.50x`)**, **AI Filtre Karşı-Olgusal Sermaye Simülatörü**, `vDSP` hızlandırmalı kosinüs benzerlikli **`k-NN` İşlem Otopsisi**, **Quarter-Kelly Risk Planlayıcı**, 10 niyetli **AI İşlem Koçu (`⌘K` & ML Keşif)** ve `< 0.1 ms` 64-bit `FNV-1a` imza önbelleği.
- **Tek Tıkla Kurumsal PDF Performans Karnesi (`PDFReportService` / `PDFKit`):** `ReviewsView` (Günlük/Haftalık/Aylık değerlendirmeler) ve `AnalyticsView` (Analizler/Strateji/İstatistikler) içinden vektörel Equity eğrisi, Disiplin Notu (`S+`–`D`), AI Rejim/Walk-Forward telemetrisi, en güçlü kurulumlar, seans dağılımı ve kural ihlali maliyetiyle 2 sayfalık kurumsal A4 PDF raporu dışa aktarımı.
- **macOS Üst Menü Çubuğu Canlı Killzone & AI Rejim Asistanı (`MenuBarController` / `KillzoneClockEngine`):** Yerel AppKit `NSStatusBar` + `NSPopover` mimarisiyle uygulama arka plandayken dahi canlı Killzone geri sayımı, 18:00 NY True Day bazlı Çeyreklik Faz (`6S`, `90DK`, `22.5DK` Q1–Q4), aktif AI Rejim & Risk Çarpanı, anlık bugünkü plana hızlı not ekleme ve tek tıkla kısayollar.
- **Sıfır Boşta CPU Tüketimi & 60/60 Otomatik Test:** `PerformanceCharts` içindeki 120 FPS CPU tüketen sonsuz nabız döngüsü kaldırılarak boşta **`%0,0 CPU`** tüketimine ulaşıldı; 68 ekran/sekme düzen testi, tüm buton/silme akışları, AI/PDFKit/Killzone stres testleri ve canlı açılış testi (`verify-installed.swift`) eksiksiz doğrulandı.

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
