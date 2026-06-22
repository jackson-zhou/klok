import AppKit

struct HandConfig {
    var color: NSColor
    var length: Double   // pixels in original image
    var lap: Double      // extension behind center
    var width: Double
}

// A PNG-based hand sprite (instead of a drawn line).
// `pivotX` is the x-coordinate within the image (in image pixels) that should
// sit at the clock center. The image is drawn horizontally with the tip pointing
// right (+X), then rotated to the target angle.
struct HandPNG {
    let image: CGImage
    let imgW: Double
    let imgH: Double
    let pivotX: Double  // pixels from image left edge to rotation pivot
}

struct TextOverlayConfig {
    let centerX: Double   // image pixels from left
    let centerY: Double   // image pixels from top
    let color: NSColor
    let fontName: String  // empty = system font
    let fontSize: Double
}

struct ClocXSkin {
    let name: String
    let faceImage: NSImage
    // Center in original image pixels (default = image center)
    let centerX: Double
    let centerY: Double
    // Transparent color to mask (for BMP skins)
    let cutColor: NSColor?
    // Line-drawn hand fallback (always present)
    let hour: HandConfig
    let minute: HandConfig
    let second: HandConfig
    // PNG hand sprites (override line hands when present)
    let hourPNG: HandPNG?
    let minutePNG: HandPNG?
    let secondPNG: HandPNG?
    // Skin-defined text overlays (nil = not configured by skin)
    let ampmConfig: TextOverlayConfig?
    let dateConfig: TextOverlayConfig?
}

// MARK: - Shared image masking (used by renderer and thumbnail)

extension ClocXSkinLoader {
    private static var maskCache = NSCache<NSURL, NSImage>()

    /// Returns an NSImage with cutColor pixels replaced by transparent.
    /// Results are cached by URL so thumbnails don't re-process on every scroll.
    static func maskedNSImage(for url: URL, cutColor: NSColor) -> NSImage? {
        let key = url as NSURL
        if let cached = maskCache.object(forKey: key) { return cached }
        guard let src = NSImage(contentsOf: url),
              let cgSrc = src.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let masked = maskedCGImage(cgSrc, cutColor: cutColor) else { return nil }
        let result = NSImage(cgImage: masked, size: src.size)
        maskCache.setObject(result, forKey: key)
        return result
    }

    static func maskedCGImage(_ src: CGImage, cutColor: NSColor) -> CGImage? {
        let w = src.width, h = src.height
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(src, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return nil }
        let buf = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0
        cutColor.usingColorSpace(.sRGB)?.getRed(&cr, green: &cg, blue: &cb, alpha: nil)
        let tr = UInt8(cr * 255), tg = UInt8(cg * 255), tb = UInt8(cb * 255)
        for i in 0 ..< w * h {
            let r = buf[i*4], g = buf[i*4+1], b = buf[i*4+2]
            if abs(Int(r)-Int(tr)) < 16 && abs(Int(g)-Int(tg)) < 16 && abs(Int(b)-Int(tb)) < 16 {
                buf[i*4] = 0; buf[i*4+1] = 0; buf[i*4+2] = 0; buf[i*4+3] = 0
            }
        }
        return ctx.makeImage()
    }
}


final class ClocXSkinLoader {

    static let skinsDir: URL = {
        // Check app bundle Resources/Skins first, then fallback to project dir
        if let bundleURL = Bundle.main.url(forResource: "Skins", withExtension: nil) {
            return bundleURL
        }
        // Dev fallback: next to the executable (swift run puts it in .build/)
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let devDir = exeDir
            .deletingLastPathComponent() // .build/debug
            .deletingLastPathComponent() // .build
            .deletingLastPathComponent() // project root
            .appendingPathComponent("Skins")
        return devDir
    }()

    // List all available skins from the Skins directory.
    // When both PNG and BMP exist for the same base name, only the PNG is returned
    // because PNGs use real alpha channels while BMPs rely on the red cut-color trick.
    // Hand sprite images (domehour, roman2minute, woodmin, etc.) are excluded
    // by checking aspect ratio — real clock faces are roughly square (ratio ≥ 0.4).
    static func availableSkins(in directory: URL? = nil) -> [URL] {
        let dir = directory ?? skinsDir
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        let all = contents.filter { ["png", "bmp"].contains($0.pathExtension.lowercased()) }

        // Build set of base names that have a PNG version
        let pngBases = Set(
            all.filter { $0.pathExtension.lowercased() == "png" }
               .map { $0.deletingPathExtension().lastPathComponent.lowercased() }
        )

        return all
            .filter { url in
                let ext  = url.pathExtension.lowercased()
                let base = url.deletingPathExtension().lastPathComponent.lowercased()
                // Drop BMP if a PNG counterpart exists
                if ext == "bmp" && pngBases.contains(base) { return false }
                // Drop hand sprite images (extremely non-square)
                if isHandSprite(url) { return false }
                return true
            }
            .sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
    }

    // Returns true if the image is clearly a hand sprite rather than a clock face.
    // Hand sprites (domehour.png, roman2minute.png, woodmin.png, etc.) are very wide
    // relative to their height. Clock faces are roughly square (ratio ≥ 0.4).
    private static func isHandSprite(_ url: URL) -> Bool {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [String: Any],
              let w = props[kCGImagePropertyPixelWidth as String] as? Int,
              let h = props[kCGImagePropertyPixelHeight as String] as? Int,
              w > 0, h > 0 else { return false }
        return Double(min(w, h)) / Double(max(w, h)) < 0.4
    }

    static func load(from imageURL: URL) -> ClocXSkin? {
        guard let image = NSImage(contentsOf: imageURL) else { return nil }

        let base = imageURL.deletingPathExtension()
        let iniURL = base.appendingPathExtension("ini")
        // INI names are case-insensitive on Windows; try lowercase too
        let iniURLLower = imageURL.deletingLastPathComponent()
            .appendingPathComponent(base.lastPathComponent.lowercased())
            .appendingPathExtension("ini")

        let ini = (try? parseINI(at: iniURL))
            ?? (try? parseINI(at: iniURLLower))
            ?? [:]

        let imgW = image.size.width
        let imgH = image.size.height

        let cx = ini["CenterX"].flatMap(Double.init) ?? (imgW / 2)
        let cy = ini["CenterY"].flatMap(Double.init) ?? (imgH / 2)

        // ClocX default cut color is red (0x0000FF in BGR = red in RGB).
        // Apply it unless: (a) INI explicitly sets a different color, or
        // (b) the image already has a real alpha channel (PNG with transparency).
        let explicitCut = ini["CutColor"].flatMap { parseBGR($0) }
        let cutColor: NSColor?
        if let c = explicitCut {
            cutColor = c
        } else if imageURL.pathExtension.lowercased() == "png" && imageHasAlpha(image) {
            cutColor = nil          // PNG with real alpha — no color masking needed
        } else {
            cutColor = .red         // BMP or opaque PNG — apply default red mask
        }

        // Base default hand lengths on the shorter dimension so non-square skins
        // (e.g. Armbanduhr aus Metall 111x183) get proportional hands for the
        // actual clock face width rather than the taller case height.
        // Multipliers calibrated from real ClocX INI files: hour ≈ 0.27, minute ≈ 0.38,
        // second ≈ 0.42 of the shorter image dimension.
        let faceRef = min(imgW, imgH)
        let hour = HandConfig(
            color: ini["HourColor"].flatMap { parseBGR($0) } ?? .black,
            length: ini["HourLength"].flatMap(Double.init) ?? (faceRef * 0.23),
            lap:    ini["HourLap"].flatMap(Double.init)    ?? 0,
            width:  ini["HourWidth"].flatMap(Double.init)  ?? 3
        )
        let minute = HandConfig(
            color: ini["MinuteColor"].flatMap { parseBGR($0) } ?? .black,
            length: ini["MinuteLength"].flatMap(Double.init) ?? (faceRef * 0.32),
            lap:    ini["MinuteLap"].flatMap(Double.init)    ?? 0,
            width:  ini["MinuteWidth"].flatMap(Double.init)  ?? 2
        )
        let second = HandConfig(
            color: ini["SecondColor"].flatMap { parseBGR($0) } ?? .red,
            length: ini["SecondLength"].flatMap(Double.init) ?? (faceRef * 0.35),
            lap:    ini["SecondLap"].flatMap(Double.init)    ?? 0,
            width:  ini["SecondWidth"].flatMap(Double.init)  ?? 1
        )

        let name = imageURL.deletingPathExtension().lastPathComponent

        // Load PNG hand sprites if specified in the INI.
        // When HourPNGCenterDist is absent, fall back to HourLap so the tail
        // end of the hand sprite aligns correctly with the clock center.
        let hourPNG   = loadHandPNG(ini["HourPNG"],
                                    centerDist: ini["HourPNGCenterDist"].flatMap(Double.init),
                                    lap: hour.lap,
                                    skinDir: imageURL.deletingLastPathComponent(), cutColor: cutColor)
        let minutePNG = loadHandPNG(ini["MinutePNG"],
                                    centerDist: ini["MinutePNGCenterDist"].flatMap(Double.init),
                                    lap: minute.lap,
                                    skinDir: imageURL.deletingLastPathComponent(), cutColor: cutColor)
        let secondPNG = loadHandPNG(ini["SecondPNG"],
                                    centerDist: ini["SecondPNGCenterDist"].flatMap(Double.init),
                                    lap: second.lap,
                                    skinDir: imageURL.deletingLastPathComponent(), cutColor: cutColor)

        // AM/PM overlay: enabled when ShowAMPM=1 or DisableAMPM=0 (default enabled)
        // Build a config whenever the skin defines any AMPM styling, even without a position.
        let ampmEnabled: Bool
        if let show = ini["ShowAMPM"] { ampmEnabled = show.trimmingCharacters(in: .whitespaces) == "1" }
        else if let dis = ini["DisableAMPM"] { ampmEnabled = dis.trimmingCharacters(in: .whitespaces) == "0" }
        else { ampmEnabled = false }

        let ampmHasStyle = ini["AMPMColor"] != nil || ini["AMPMFont"] != nil || ini["AMPMCenterX"] != nil
        let ampmHasPosition = ini["AMPMCenterX"] != nil
        let ampmConfig: TextOverlayConfig? = (ampmEnabled || ampmHasStyle) && !{
            ini["DisableAMPM"].map { $0.trimmingCharacters(in: .whitespaces) == "1" } ?? false
        }() ? TextOverlayConfig(
            centerX:  ini["AMPMCenterX"].flatMap(Double.init) ?? (imgW / 2),
            centerY:  ini["AMPMCenterY"].flatMap(Double.init) ?? (imgH * 0.65),
            color:    ini["AMPMColor"].flatMap { parseBGR($0) } ?? .white,
            fontName: ini["AMPMFont"] ?? "",
            // Use proportional default when no position — INI font size was for a specific window size
            fontSize: ampmHasPosition
                ? (ini["AMPMFontSize"].flatMap(Double.init) ?? (imgH * 0.045))
                : imgH * 0.045
        ) : nil

        // Date overlay: create a config whenever any date styling key is present in the INI.
        // This preserves skin-defined colors/fonts even when the skin omits DateCenterX/Y.
        let dateDisabled = ini["DisableDate"].map { $0.trimmingCharacters(in: .whitespaces) == "1" } ?? false
        let dateHasStyle = ini["DateCenterX"] != nil || ini["DateColor"] != nil || ini["DateFont"] != nil
        let dateHasPosition = ini["DateCenterX"] != nil
        let dateEnabled = dateHasStyle && !dateDisabled

        let dateConfig: TextOverlayConfig? = dateEnabled ? TextOverlayConfig(
            centerX:  ini["DateCenterX"].flatMap(Double.init) ?? (imgW / 2),
            centerY:  ini["DateCenterY"].flatMap(Double.init) ?? (imgH * 0.72),
            color:    ini["DateColor"].flatMap { parseBGR($0) } ?? .white,
            fontName: ini["DateFont"] ?? "",
            // Use proportional default when no position — INI font size was for a specific window size
            fontSize: dateHasPosition
                ? (ini["DateFontSize"].flatMap(Double.init) ?? (imgH * 0.045))
                : imgH * 0.045
        ) : nil

        return ClocXSkin(
            name: name,
            faceImage: image,
            centerX: cx, centerY: cy,
            cutColor: cutColor,
            hour: hour, minute: minute, second: second,
            hourPNG: hourPNG, minutePNG: minutePNG, secondPNG: secondPNG,
            ampmConfig: ampmConfig, dateConfig: dateConfig
        )
    }

    // Resolve a hand PNG path from the INI (may be relative like "roman2/roman2hour.png"
    // or a bare filename like "arnehour.hpng"). Since our Skins folder is flat (extracted
    // from the installer without subdirectories), fall back to just the filename when the
    // full path doesn't exist.
    private static func loadHandPNG(_ path: String?, centerDist: Double?, lap: Double,
                                    skinDir: URL, cutColor: NSColor?) -> HandPNG? {
        guard let path = path, !path.isEmpty else { return nil }

        // Try path relative to skin's directory, then just the filename in skinsDir
        let candidates = [
            skinDir.appendingPathComponent(path),
            skinsDir.appendingPathComponent(path),
            skinsDir.appendingPathComponent(URL(fileURLWithPath: path).lastPathComponent)
        ]
        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let nsImg = NSImage(contentsOf: url),
              let cgSrc = nsImg.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        let w = Double(cgSrc.width)
        let h = Double(cgSrc.height)

        // Apply masking: use same cut color as face, unless image has real alpha
        let cgImg: CGImage
        if imageHasAlpha(nsImg) {
            cgImg = cgSrc
        } else if let cut = cutColor, let masked = maskedCGImage(cgSrc, cutColor: cut) {
            cgImg = masked
        } else if let masked = maskedCGImage(cgSrc, cutColor: .red) {
            cgImg = masked
        } else {
            cgImg = cgSrc
        }

        // pivotX: point within the image that sits at the clock center.
        // CenterDist (explicit) = distance from image center to pivot → pivotX = w/2 - centerDist.
        // When not specified: pivot = lap pixels from the left (tail) edge of the image,
        // matching how ClocX lays out hand sprites with no explicit CenterDist.
        let pivotX: Double
        if let cd = centerDist {
            pivotX = w / 2 - cd
        } else {
            pivotX = lap
        }

        return HandPNG(image: cgImg, imgW: w, imgH: h, pivotX: pivotX)
    }

    // Returns true if the image actually contains non-opaque pixels
    // (i.e. it was saved with a real alpha channel, not just a cut color trick).
    private static func imageHasAlpha(_ image: NSImage) -> Bool {
        guard let cgImg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return false
        }
        let info = cgImg.alphaInfo
        switch info {
        case .none, .noneSkipFirst, .noneSkipLast:
            return false
        default:
            // Has alpha channel — sample a small strip to see if any pixel is actually transparent
            let w = min(cgImg.width, 64), h = min(cgImg.height, 64)
            guard let ctx = CGContext(data: nil, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
                  let thumb = cgImg.cropping(to: CGRect(x: 0, y: 0,
                                                         width: cgImg.width, height: cgImg.height))
            else { return true }
            ctx.draw(thumb, in: CGRect(x: 0, y: 0, width: w, height: h))
            guard let data = ctx.data else { return true }
            let buf = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
            for i in 0 ..< w * h {
                if buf[i * 4 + 3] < 250 { return true }
            }
            return false
        }
    }

    // MARK: - INI parser (flat key=value, ignores sections)

    private static func parseINI(at url: URL) throws -> [String: String] {
        let text = try String(contentsOf: url, encoding: .windowsCP1252)
        var result: [String: String] = [:]
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.hasPrefix(";"), !line.hasPrefix("["), !line.isEmpty else { continue }
            // Strip inline comments
            let noComment = line.components(separatedBy: ";").first ?? line
            let parts = noComment.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let val = String(parts[1]).trimmingCharacters(in: .whitespaces)
            result[key] = val
        }
        return result
    }

    // ClocX colors: BGR hex string like "0x0000FF" or plain decimal
    private static func parseBGR(_ s: String) -> NSColor? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        var raw: UInt64 = 0
        if trimmed.hasPrefix("0x") || trimmed.hasPrefix("0X") {
            let hex = String(trimmed.dropFirst(2))
            guard let v = UInt64(hex, radix: 16) else { return nil }
            raw = v
        } else if let v = UInt64(trimmed) {
            raw = v
        } else {
            return nil
        }
        // BGR → RGB
        let b = CGFloat((raw >> 16) & 0xFF) / 255
        let g = CGFloat((raw >> 8)  & 0xFF) / 255
        let r = CGFloat( raw        & 0xFF) / 255
        return NSColor(red: r, green: g, blue: b, alpha: 1)
    }
}
