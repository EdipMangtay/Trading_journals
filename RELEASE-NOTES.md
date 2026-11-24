# Liquidity Edge v6.0.0 — Native macOS Sürümü

Apple Silicon ve Intel işlemcili tüm macOS 14+ bilgisayarlar için yerel **Swift, SwiftUI, SwiftData ve Swift Charts** uygulaması.

## Kurulum Dosyaları

Aşağıdaki resmi kurulum dosyalarından birini indirin (kaynak kodu ZIP'ini indirmeyin):

- **Liquidity-Edge-macOS-Universal.dmg** (Önerilen): Açın ve `Liquidity Edge.app` uygulamasını Uygulamalar (`Applications`) klasörüne sürükleyin.
- **Liquidity-Edge-macOS-Universal.pkg**: Standart Apple kurulum sihirbazı ile `/Applications` içine kurun.
- **SHA256SUMS-macOS.txt**: Paket bütünlüğü için SHA-256 özetleri.

## v6.0.0 Yenilikleri

- **Yenilenen Performans Masası ve Grafik Animasyonları:** Kayan cam crosshair HUD tooltip'leri, çift katmanlı ışıltılı sermaye eğrileri, yay animasyonlu kayan sekmeler, dağılım grafiği projeksiyon kılavuzları, etkileşimli zamanlama ısı haritası ve özelleştirilebilir widget düzeni.
- **Çoklu Hesap & Prop Firm Risk Merkezi:** Personal, Evaluation ve Funded hesap desteği; statik ve gün sonu (EOD) trailing drawdown, günlük kayıp limiti, minimum işlem günü ve tutarlılık yüzdesi takibi.
- **Strateji Araştırma Laboratuvarı:** QT, MMXM, PO3, SSMT, TSMO ve CRT kurulumları için Setup × Seans, Setup × Enstrüman çapraz matrisleri, A/B teyit karşılaştırmaları ve kayıtlı filtre ön ayarları.
- **Kantitatif Analiz & Monte Carlo:** Deterministik bootstrap ve sıra karıştırma (shuffle) simülasyonları, 5./50./95. yüzdelik dilim bantları, su altı (drawdown) toparlanma süresi ve hareketli beklenti analizi.
- **İşlem Planı & Yapılandırılmış Kontrol Listeleri:** Günlük piyasa senaryoları, likidite hedefleri ve QT/MMXM/CRT şablonlu ön/son kontrol listeleri.
- **Gelişmiş İşlem İnceleyici & Gerçekleşme Defteri:** Kademeli giriş/çıkış (Fills), kayma (slippage) maliyeti, kontrat puan değeri ve kontrol listesi yanıtları.
- **CSV Aktarım Sihirbazı:** Sütun eşleme, veri doğrulama, yineleme tespiti ve seçilen hesaba güvenli aktarım.
- **Veri Güvenliği (SwiftData V1 → V2):** Mevcut tüm eski kayıtlar, görseller, çizimler ve yedekler kayıpsız korunur.

**İlk açılış notu:** Açık kaynaklı ad-hoc imzalı derleme olduğu için macOS ilk açılışta onay isteyebilir. **Sistem Ayarları → Gizlilik ve Güvenlik → Yine de Aç** adımını kullanabilir veya `xattr -cr "/Applications/Liquidity Edge.app"` çalıştırabilirsiniz. Detaylar: [INSTALLATION.md](https://github.com/EdipMangtay/Trading_journals/blob/main/INSTALLATION.md).
