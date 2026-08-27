import Cocoa
import ImageIO

@MainActor
enum ThumbnailLoader {
    private static var cache = [String: NSImage]()

    /// Returns a downsampled 88x88 (Retina 44pt) cached thumbnail without loading full-size bitmaps.
    static func thumbnail(for url: URL, maxDimension: CGFloat = 88) -> NSImage? {
        let path = url.path
        if let existing = cache[path] {
            return existing
        }

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            return nil
        }

        let thumb = NSImage(cgImage: cgImage, size: NSSize(width: 44, height: 44))
        if cache.count > 300 {
            cache.removeAll()
        }
        cache[path] = thumb
        return thumb
    }

    static func invalidate() {
        cache.removeAll()
    }
}
