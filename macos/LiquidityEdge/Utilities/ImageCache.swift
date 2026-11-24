import AppKit
import CryptoKit
import Foundation

/// Thread-safe decoded NSImage cache preventing repeated PNG/JPEG decoding
/// during SwiftUI scrolling, hover updates, zoom sliders, and annotation drags.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 180
        cache.totalCostLimit = 256 * 1024 * 1024 // 256 MB decoded image ceiling
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

    private static func fingerprint(for data: Data) -> String {
        // Fast content fingerprint: length + prefix/middle/suffix SHA256 slice for large files, full hash for thumbnails
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
