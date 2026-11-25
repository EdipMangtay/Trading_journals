import AppKit
import CryptoKit
import Foundation
import Metal

/// Live hardware capability descriptor so performance engines and UI telemetry
/// adapt dynamically to the host Mac (e.g., Apple M3 Pro 12-core / 36 GB Unified Memory / Metal GPU).
enum HardwareProfile {
    static let coreCount: Int = max(1, ProcessInfo.processInfo.activeProcessorCount)
    static let memoryGB: Int = max(1, Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824.0).rounded()))
    static let metalDeviceName: String = MTLCreateSystemDefaultDevice()?.name ?? "Apple GPU"
    static let isAppleSilicon: Bool = {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }()
    static var badgeLabel: String {
        "\(metalDeviceName) · \(coreCount) Çekirdek · \(memoryGB) GB"
    }
}

/// Thread-safe decoded NSImage cache tuned for Apple Silicon Unified Memory,
/// preventing repeated PNG/JPEG decoding during 120Hz scrolling, hover updates, and zoom drags.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        let highMem = HardwareProfile.memoryGB >= 24
        cache.countLimit = highMem ? 360 : 180
        cache.totalCostLimit = (highMem ? 512 : 256) * 1024 * 1024
    }

    func image(for data: Data, key: String? = nil) -> NSImage? {
        guard !data.isEmpty else { return nil }
        let cacheKey = (key ?? Self.fingerprint(for: data)) as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }
        guard let decoded = NSImage(data: data) else { return nil }
        let pixelCost = Int(max(1, decoded.size.width * decoded.size.height * 4))
        cache.setObject(decoded, forKey: cacheKey, cost: pixelCost)
        return decoded
    }

    /// Concurrently decodes image thumbnails across Apple Silicon cores into Unified Memory.
    func prewarm(_ items: [(data: Data, key: String)]) {
        guard !items.isEmpty else { return }
        DispatchQueue.global(qos: .utility).async {
            if items.count >= 4 {
                DispatchQueue.concurrentPerform(iterations: items.count) { i in
                    _ = self.image(for: items[i].data, key: items[i].key)
                }
            } else {
                for item in items {
                    _ = self.image(for: item.data, key: item.key)
                }
            }
        }
    }

    private static func fingerprint(for data: Data) -> String {
        if data.count <= 65_536 {
            let digest = SHA256.hash(data: data)
            return "\(data.count)-" + digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        }
        var hasher = SHA256()
        hasher.update(data: data.prefix(4096))
        let midStart = data.count / 2
        hasher.update(data: data[midStart..<min(data.count, midStart + 4096)])
        hasher.update(data: data.suffix(4096))
        let digest = hasher.finalize()
        return "\(data.count)-" + digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
