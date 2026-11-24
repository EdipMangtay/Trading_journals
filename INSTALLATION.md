# Kurulum / Installation (macOS)

Kurulum dosyasını [GitHub Releases](https://github.com/EdipMangtay/Trading_journals/releases/latest) sayfasından indirin. Kaynak kodu ZIP dosyası geliştirme içindir, kurulum için değildir.

## Sistem Gereksinimleri

- **macOS 14 (Sonoma) veya üzeri**
- **Apple Silicon (M1/M2/M3/M4) veya Intel** (Universal Binary)
- Xcode, Swift veya Homebrew kurulu olması gerekmez.

## Kurulum Adımları (Türkçe)

### Yöntem 1: DMG ile Kurulum (Önerilen)
1. **Liquidity-Edge-macOS-Universal.dmg** dosyasını indirin ve çift tıklayarak açın.
2. **Liquidity Edge.app** simgesini **Applications (Uygulamalar)** klasörüne sürükleyin.
3. Uygulamalar klasöründen **Liquidity Edge** uygulamasını başlatın.

### Yöntem 2: PKG Yükleyici ile Kurulum
1. **Liquidity-Edge-macOS-Universal.pkg** dosyasını indirin ve çift tıklayın.
2. Apple Kurulum Sihirbazı adımlarını tamamlayın. Uygulama `/Applications/Liquidity Edge.app` konumuna kurulur.

### İlk Açılışta Gatekeeper Onayı
Bu sürüm açık kaynaklı ad-hoc imza ile paketlenmiştir (Apple Developer ID sertifikası içermez). macOS ilk açılışta güvenlik uyarısı gösterebilir:
1. Uyarı penceresini kapatın ve **Sistem Ayarları → Gizlilik ve Güvenlik** bölümüne gidin.
2. Alt kısımda **Liquidity Edge** için görünen **"Yine de Aç"** butonuna tıklayın (bkz. [Apple kılavuzu](https://support.apple.com/102445)).
3. Alternatif olarak Terminal uygulamasında şu komutu çalıştırabilirsiniz:
   ```bash
   xattr -cr "/Applications/Liquidity Edge.app"
   ```
4. Gatekeeper korumasını sistem genelinde kapatmayın.

## Yerel Veriler ve Güncelleme

- Yeni kurulumlar boş bir günlükle açılır; örnek (demo) çalışma alanı yalnızca Ayarlar'dan isteğe bağlı açılır ve gerçek kayıtlarınıza karışmaz.
- Veritabanınız ve görselleriniz `~/Library/Application Support/LiquidityEdge/Journal.store` konumunda, uygulama paketinden bağımsız saklanır.
- Uygulamayı güncellemek mevcut işlemlerinizi silmez. Yine de büyük güncellemelerden önce Ayarlar → Veri ve Yedek bölümünden JSON yedeği almanız önerilir.
- Eski V1 sürümlerinden geçişte SwiftData V1 → V2 geçişi otomatik ve veri kayıpsız çalışır.

## English Summary

Download **Liquidity-Edge-macOS-Universal.dmg** (drag `Liquidity Edge.app` to Applications) or **Liquidity-Edge-macOS-Universal.pkg** from [GitHub Releases](https://github.com/EdipMangtay/Trading_journals/releases/latest). Requires macOS 14+ (Apple Silicon & Intel Universal). Since this open-source build is ad-hoc signed without an Apple Developer ID certificate, allow the first launch via **System Settings → Privacy & Security → Open Anyway** (or `xattr -cr "/Applications/Liquidity Edge.app"`).

## SHA-256 Doğrulama

İndirdiğiniz paketi doğrulamak için Terminal'de aşağıdaki komutu çalıştırıp `SHA256SUMS-macOS.txt` ile karşılaştırabilirsiniz:

```bash
shasum -a 256 Liquidity-Edge-macOS-Universal.dmg Liquidity-Edge-macOS-Universal.pkg
```
