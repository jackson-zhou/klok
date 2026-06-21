import AppKit

// Parses ClocX-compatible skin.ini and loads PNG/BMP images
struct ImageSkin {
    let name: String
    let folder: URL

    let background: NSImage
    let hourHand: NSImage
    let minuteHand: NSImage
    let secondHand: NSImage?

    // Pivot point as fraction of image size (0.0–1.0)
    let hourPivot: CGPoint
    let minutePivot: CGPoint
    let secondPivot: CGPoint

    // Optional: transparent color to mask out (from BMP skins)
    let transparentColor: NSColor?
}

final class ImageSkinLoader {

    // Attempts to load a skin from a folder.
    // Supports ClocX skin.ini format as well as a simple fallback (no ini).
    static func load(from folder: URL) throws -> ImageSkin {
        let ini = try? parseINI(at: folder.appendingPathComponent("skin.ini"))

        func img(_ key: String, fallbacks: [String]) throws -> NSImage {
            // Try ini value first, then fallback names
            var candidates: [String] = []
            if let v = ini?[key] { candidates.append(v) }
            candidates.append(contentsOf: fallbacks)
            for name in candidates {
                let url = folder.appendingPathComponent(name)
                if let image = NSImage(contentsOf: url) { return image }
                // Also try BMP extension
                let bmpURL = folder.appendingPathComponent(
                    (name as NSString).deletingPathExtension + ".bmp")
                if let image = NSImage(contentsOf: bmpURL) { return image }
            }
            throw SkinError.missingImage(candidates.first ?? key)
        }

        func pivot(_ xKey: String, _ yKey: String, image: NSImage) -> CGPoint {
            let w = image.size.width
            let h = image.size.height
            guard w > 0, h > 0 else { return CGPoint(x: 0.5, y: 0.5) }
            if let xs = ini?[xKey], let ys = ini?[yKey],
               let x = Double(xs), let y = Double(ys) {
                // ClocX stores pivot in pixels from top-left; convert to fraction
                return CGPoint(x: x / w, y: y / h)
            }
            return CGPoint(x: 0.5, y: 0.7) // sensible default
        }

        let bg   = try img("Background",  fallbacks: ["background.png","face.png","clock.png"])
        let hour = try img("HourHand",    fallbacks: ["hour.png","hour_hand.png"])
        let min  = try img("MinuteHand",  fallbacks: ["minute.png","min.png","minute_hand.png"])
        let sec  = try? img("SecondHand", fallbacks: ["second.png","sec.png","second_hand.png"])

        let hourPivot   = pivot("HourHandCX",   "HourHandCY",   image: hour)
        let minPivot    = pivot("MinuteHandCX", "MinuteHandCY", image: min)
        let secPivot: CGPoint = {
            guard let s = sec else { return .init(x: 0.5, y: 0.7) }
            return pivot("SecondHandCX", "SecondHandCY", image: s)
        }()

        // Parse transparent color if specified (R,G,B)
        var transColor: NSColor?
        if let tc = ini?["TransparentColor"] {
            let parts = tc.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if parts.count == 3 {
                transColor = NSColor(red: parts[0]/255, green: parts[1]/255,
                                     blue: parts[2]/255, alpha: 1)
            }
        }

        let skinName = ini?["Name"] ?? folder.lastPathComponent

        return ImageSkin(
            name: skinName, folder: folder,
            background: bg,
            hourHand: hour, minuteHand: min, secondHand: sec,
            hourPivot: hourPivot, minutePivot: minPivot, secondPivot: secPivot,
            transparentColor: transColor
        )
    }

    // Scans ~/Library/Application Support/Klok/Skins/ for skin folders
    static func availableSkins() -> [URL] {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Klok/Skins")
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return contents.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    // MARK: - INI parser

    private static func parseINI(at url: URL) throws -> [String: String] {
        let text = try String(contentsOf: url, encoding: .utf8)
        var result: [String: String] = [:]
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix(";"), !trimmed.hasPrefix("["), !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
                result[key] = val
            }
        }
        return result
    }
}

enum SkinError: Error {
    case missingImage(String)
}
