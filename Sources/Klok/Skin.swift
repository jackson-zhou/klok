import AppKit

struct SkinColor: Codable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double

    var nsColor: NSColor { NSColor(red: r, green: g, blue: b, alpha: a) }

    init(_ color: NSColor) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.usingColorSpace(.sRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        r = Double(red); g = Double(green); b = Double(blue); a = Double(alpha)
    }

    init(r: Double, g: Double, b: Double, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }

    static func hex(_ hex: String, alpha: Double = 1) -> SkinColor {
        let s = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        let v = UInt64(s, radix: 16) ?? 0
        return SkinColor(
            r: Double((v >> 16) & 0xFF) / 255,
            g: Double((v >> 8) & 0xFF) / 255,
            b: Double(v & 0xFF) / 255,
            a: alpha
        )
    }
}

struct Skin: Codable, Identifiable {
    var id: String
    var name: String

    // Face
    var faceColor: SkinColor
    var faceAlpha: Double
    var borderColor: SkinColor
    var borderWidth: Double

    // Ticks
    var hourTickColor: SkinColor
    var minuteTickColor: SkinColor
    var showNumbers: Bool
    var numberColor: SkinColor

    // Hands
    var hourHandColor: SkinColor
    var minuteHandColor: SkinColor
    var secondHandColor: SkinColor
    var centerDotColor: SkinColor

    // Shadow
    var showShadow: Bool
}

extension Skin {
    static let classic = Skin(
        id: "classic", name: "Classic",
        faceColor: .hex("FFFFFF"), faceAlpha: 0.95,
        borderColor: .hex("333333"), borderWidth: 2,
        hourTickColor: .hex("222222"), minuteTickColor: .hex("888888"),
        showNumbers: true, numberColor: .hex("111111"),
        hourHandColor: .hex("111111"), minuteHandColor: .hex("111111"),
        secondHandColor: .hex("E02020"), centerDotColor: .hex("E02020"),
        showShadow: true
    )

    static let dark = Skin(
        id: "dark", name: "Dark",
        faceColor: .hex("1A1A2E"), faceAlpha: 0.97,
        borderColor: .hex("4A4A8A"), borderWidth: 1.5,
        hourTickColor: .hex("8888CC"), minuteTickColor: .hex("444466"),
        showNumbers: true, numberColor: .hex("AAAADD"),
        hourHandColor: .hex("DDDDFF"), minuteHandColor: .hex("BBBBEE"),
        secondHandColor: .hex("FF6666"), centerDotColor: .hex("FF6666"),
        showShadow: false
    )

    static let minimal = Skin(
        id: "minimal", name: "Minimal",
        faceColor: .init(r: 1, g: 1, b: 1, a: 0), faceAlpha: 0,
        borderColor: .init(r: 0, g: 0, b: 0, a: 0), borderWidth: 0,
        hourTickColor: .hex("222222"), minuteTickColor: .hex("AAAAAA"),
        showNumbers: false, numberColor: .hex("333333"),
        hourHandColor: .hex("111111"), minuteHandColor: .hex("333333"),
        secondHandColor: .hex("CC3333"), centerDotColor: .hex("111111"),
        showShadow: false
    )

    static let neon = Skin(
        id: "neon", name: "Neon",
        faceColor: .hex("050510"), faceAlpha: 0.92,
        borderColor: .hex("00FFCC"), borderWidth: 1,
        hourTickColor: .hex("00FFCC"), minuteTickColor: .hex("006655"),
        showNumbers: true, numberColor: .hex("00FFCC"),
        hourHandColor: .hex("00FFCC"), minuteHandColor: .hex("00DDAA"),
        secondHandColor: .hex("FF00AA"), centerDotColor: .hex("FF00AA"),
        showShadow: false
    )

    static let vintage = Skin(
        id: "vintage", name: "Vintage",
        faceColor: .hex("F5E6C8"), faceAlpha: 0.98,
        borderColor: .hex("8B6914"), borderWidth: 3,
        hourTickColor: .hex("5C3D0E"), minuteTickColor: .hex("A0845A"),
        showNumbers: true, numberColor: .hex("3D2200"),
        hourHandColor: .hex("3D2200"), minuteHandColor: .hex("5C3D0E"),
        secondHandColor: .hex("8B1A1A"), centerDotColor: .hex("5C3D0E"),
        showShadow: true
    )

    static let steel = Skin(
        id: "steel", name: "Steel",
        faceColor: .hex("D0D8E4"), faceAlpha: 0.97,
        borderColor: .hex("7A8BA0"), borderWidth: 4,
        hourTickColor: .hex("2B3A4A"), minuteTickColor: .hex("8899AA"),
        showNumbers: false, numberColor: .hex("2B3A4A"),
        hourHandColor: .hex("1A2A3A"), minuteHandColor: .hex("2B3A4A"),
        secondHandColor: .hex("CC4400"), centerDotColor: .hex("1A2A3A"),
        showShadow: true
    )

    static let all: [Skin] = [.classic, .dark, .minimal, .neon, .vintage, .steel]
}
