import AppKit

final class ClockView: NSView {
    private var displayLink: CVDisplayLink?
    private var skin: Skin = Settings.shared.currentSkin
    private var clocxSkin: ClocXSkin? = Settings.shared.loadClocXSkin()
    private var showSecondHand: Bool = Settings.shared.showSecondHand
    private var secondHandJump: Bool = Settings.shared.secondHandJump
    private var showAmPm: Bool = Settings.shared.showAmPm
    private var showDate: Bool = Settings.shared.showDate
    private var hoverTransparent: Bool = Settings.shared.hoverTransparent
    private var isDragging = false
    private var dragStart = NSPoint.zero
    private var calendarPanel: CalendarPanel

    override init(frame: NSRect) {
        fatalError("use init(frame:calendarPanel:)")
    }

    init(frame: NSRect, calendarPanel: CalendarPanel) {
        self.calendarPanel = calendarPanel
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = .clear

        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .settingsChanged, object: nil
        )

        updateTrackingArea()
        startDisplayLink()
    }

    private func startDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let link = displayLink else { return }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.needsDisplay = true }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
    }

    deinit {
        if let link = displayLink { CVDisplayLinkStop(link) }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func settingsChanged() {
        skin = Settings.shared.currentSkin
        clocxSkin = Settings.shared.loadClocXSkin()
        showSecondHand = Settings.shared.showSecondHand
        secondHandJump = Settings.shared.secondHandJump
        showAmPm = Settings.shared.showAmPm
        showDate = Settings.shared.showDate
        hoverTransparent = Settings.shared.hoverTransparent
        updateTrackingArea()
        needsDisplay = true
    }

    // MARK: - Hover-transparent tracking area

    private var trackingArea: NSTrackingArea?

    private func updateTrackingArea() {
        if let old = trackingArea { removeTrackingArea(old); trackingArea = nil }
        guard hoverTransparent else { return }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseEnteredAndExited, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateTrackingArea()
    }

    override func mouseEntered(with event: NSEvent) {
        guard hoverTransparent else { return }
        window?.alphaValue = CGFloat(Settings.shared.hoverOpacity)
    }

    override func mouseExited(with event: NSEvent) {
        window?.alphaValue = CGFloat(Settings.shared.opacity)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(bounds)

        let cal = Calendar.current
        let now = Date()
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let s = cal.component(.second, from: now)
        let ns = cal.component(.nanosecond, from: now)
        // Smooth fractional seconds; jumping mode uses whole seconds
        let frac = secondHandJump ? Double(s) : Double(s) + Double(ns) / 1_000_000_000

        let hourAngle = CGFloat(Double.pi/2 - Double(h % 12) * .pi/6  - Double(m) * .pi/360 - frac * .pi/21600)
        let minAngle  = CGFloat(Double.pi/2 - Double(m) * .pi/30 - frac * .pi/1800)
        let secAngle  = CGFloat(Double.pi/2 - frac * .pi / 30)

        if let cs = clocxSkin {
            drawClocXSkin(ctx, skin: cs, hourAngle: hourAngle, minAngle: minAngle, secAngle: secAngle)
            // Skin-aware overlays (use INI positions/colors when configured)
            drawClocXOverlays(ctx, skin: cs, hour: h, date: now)
        } else {
            drawCodeSkin(ctx, hourAngle: hourAngle, minAngle: minAngle, secAngle: secAngle)
            // Fallback: centered overlays for built-in code skins
            drawCodeSkinOverlays(ctx, hour: h, date: now)
        }
    }

    // MARK: - ClocX original skin renderer

    private func drawClocXSkin(_ ctx: CGContext, skin: ClocXSkin,
                                hourAngle: CGFloat, minAngle: CGFloat, secAngle: CGFloat) {
        let viewSize = min(bounds.width, bounds.height)
        let imgW = skin.faceImage.size.width
        let imgH = skin.faceImage.size.height
        guard imgW > 0, imgH > 0 else { return }

        // Scale factor: fit the longer dimension into viewSize
        let scale = viewSize / max(imgW, imgH)
        let drawW = imgW * scale
        let drawH = imgH * scale
        let originX = bounds.midX - drawW / 2
        let originY = bounds.midY - drawH / 2
        let faceRect = CGRect(x: originX, y: originY, width: drawW, height: drawH)

        // Draw face
        if let cgImg = skin.faceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let img = skin.cutColor.flatMap { ClocXSkinLoader.maskedCGImage(cgImg, cutColor: $0) } ?? cgImg
            ctx.draw(img, in: faceRect)
        }

        // Clock center in view coords
        let cx = originX + skin.centerX * scale
        let cy = originY + (imgH - skin.centerY) * scale  // flip Y (CGContext origin = bottom-left)

        func drawHand(_ hand: HandConfig, angle: CGFloat) {
            let len   = hand.length * scale
            let lap   = hand.lap    * scale
            // Width is in screen points (not image pixels) — matches original ClocX behavior
            let width = max(0.5, hand.width)

            let tipX   = cx + len * cos(angle)
            let tipY   = cy + len * sin(angle)
            let tailX  = cx - lap * cos(angle)
            let tailY  = cy - lap * sin(angle)

            ctx.move(to: CGPoint(x: tailX, y: tailY))
            ctx.addLine(to: CGPoint(x: tipX, y: tipY))
            ctx.setStrokeColor(hand.color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.strokePath()
        }

        func drawHandPNG(_ png: HandPNG, angle: CGFloat) {
            // Place image so pivotX lands at the clock center (cx, cy).
            // In the rotated frame: +X = direction hand points, +Y = perpendicular.
            let rectX = -png.pivotX * scale
            let rectY = -(png.imgH / 2) * scale
            let rectW =  png.imgW * scale
            let rectH =  png.imgH * scale
            ctx.saveGState()
            ctx.translateBy(x: cx, y: cy)
            ctx.rotate(by: angle)
            ctx.draw(png.image, in: CGRect(x: rectX, y: rectY, width: rectW, height: rectH))
            ctx.restoreGState()
        }

        if let png = skin.hourPNG   { drawHandPNG(png, angle: hourAngle) } else { drawHand(skin.hour,   angle: hourAngle) }
        if let png = skin.minutePNG { drawHandPNG(png, angle: minAngle)  } else { drawHand(skin.minute, angle: minAngle)  }
        if showSecondHand {
            if let png = skin.secondPNG { drawHandPNG(png, angle: secAngle) } else { drawHand(skin.second, angle: secAngle) }
        }

        // Center dot — fixed screen size, same as hand widths (no scale)
        let dotR = max(1.5, skin.hour.width * 0.8)
        ctx.addEllipse(in: CGRect(x: cx - dotR, y: cy - dotR, width: dotR*2, height: dotR*2))
        ctx.setFillColor(skin.hour.color.cgColor)
        ctx.fillPath()
    }

    // MARK: - AM/PM and date overlays

    // Skin-aware overlay for ClocX skins: uses INI-defined positions, colors, fonts.
    // Global showAmPm / showDate toggles act as user-level overrides on top of the skin config.
    private func drawClocXOverlays(_ ctx: CGContext, skin: ClocXSkin, hour: Int, date: Date) {
        let imgW = skin.faceImage.size.width
        let imgH = skin.faceImage.size.height
        guard imgW > 0, imgH > 0 else { return }

        let viewSize = min(bounds.width, bounds.height)
        let scale = viewSize / max(imgW, imgH)
        let drawW = imgW * scale
        let drawH = imgH * scale
        let originX = bounds.midX - drawW / 2
        let originY = bounds.midY - drawH / 2

        func drawText(_ cfg: TextOverlayConfig, text: String) {
            let font: NSFont
            if cfg.fontName.isEmpty {
                font = NSFont.systemFont(ofSize: max(6, cfg.fontSize * scale), weight: .regular)
            } else {
                font = NSFont(name: cfg.fontName, size: max(6, cfg.fontSize * scale))
                    ?? NSFont.systemFont(ofSize: max(6, cfg.fontSize * scale), weight: .regular)
            }
            // Add a subtle shadow so text is readable on both light and dark skin backgrounds
            let shadow = NSShadow()
            shadow.shadowOffset = NSSize(width: 0, height: -1)
            shadow.shadowBlurRadius = 2
            // Shadow color is the complement of text color (dark shadow for light text, vice versa)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            cfg.color.usingColorSpace(.sRGB)?.getRed(&r, green: &g, blue: &b, alpha: &a)
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            shadow.shadowColor = luminance > 0.5
                ? NSColor.black.withAlphaComponent(0.6)
                : NSColor.white.withAlphaComponent(0.5)

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: cfg.color,
                .shadow: shadow
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let tw = str.size().width
            let th = str.size().height
            // INI CenterX/Y is the text center in image pixels; flip Y for CGContext
            let px = originX + cfg.centerX * scale - tw / 2
            let py = originY + (imgH - cfg.centerY) * scale - th / 2
            str.draw(at: CGPoint(x: px, y: py))
        }

        if showAmPm {
            let cfg = skin.ampmConfig ?? TextOverlayConfig(
                centerX: imgW / 2, centerY: imgH * 0.65,
                color: .black, fontName: "", fontSize: imgH * 0.045)
            drawText(cfg, text: hour < 12 ? "AM" : "PM")
        }
        if showDate {
            let cfg = skin.dateConfig ?? TextOverlayConfig(
                centerX: imgW / 2, centerY: imgH * 0.72,
                color: .black, fontName: "", fontSize: imgH * 0.045)
            let df = DateFormatter()
            df.dateFormat = "yyyy/M/d"
            drawText(cfg, text: df.string(from: date))
        }
    }

    // Fallback overlay for built-in code skins (no skin config, use fixed position).
    private func drawCodeSkinOverlays(_ ctx: CGContext, hour: Int, date: Date) {
        guard showAmPm || showDate else { return }
        let size = min(bounds.width, bounds.height)
        let cx = bounds.midX
        let cy = bounds.midY

        let fontSize = max(9, size * 0.10)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let color = NSColor.white.withAlphaComponent(0.85)

        var lines: [String] = []
        if showAmPm { lines.append(hour < 12 ? "AM" : "PM") }
        if showDate {
            let df = DateFormatter()
            df.dateFormat = "yyyy/M/d"
            lines.append(df.string(from: date))
        }

        let lineH = fontSize * 1.4
        let totalH = CGFloat(lines.count) * lineH
        var y = cy - size * 0.15 - totalH / 2

        for text in lines {
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
            let str = NSAttributedString(string: text, attributes: attrs)
            let tw = str.size().width
            str.draw(at: CGPoint(x: cx - tw / 2, y: y))
            y += lineH
        }
    }

    // MARK: - Code-based skin renderer (original path)

    private func drawCodeSkin(_ ctx: CGContext, hourAngle: CGFloat, minAngle: CGFloat, secAngle: CGFloat) {
        let size = min(bounds.width, bounds.height)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = size / 2 - 4

        drawFace(ctx, center: center, radius: radius)
        drawTicks(ctx, center: center, radius: radius)
        if skin.showNumbers { drawNumbers(ctx, center: center, radius: radius) }

        drawHand(ctx, center: center, angle: hourAngle,
                 length: radius * 0.55, width: size * 0.045,
                 color: skin.hourHandColor.nsColor, tail: radius * 0.12)
        drawHand(ctx, center: center, angle: minAngle,
                 length: radius * 0.78, width: size * 0.032,
                 color: skin.minuteHandColor.nsColor, tail: radius * 0.12)

        if showSecondHand {
            drawHand(ctx, center: center, angle: secAngle,
                     length: radius * 0.85, width: size * 0.015,
                     color: skin.secondHandColor.nsColor, tail: radius * 0.2)
        }

        drawCenterDot(ctx, center: center, size: size)
    }

    private func drawFace(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let face = CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        )
        ctx.addEllipse(in: face)

        let fc = skin.faceColor.nsColor.withAlphaComponent(CGFloat(skin.faceAlpha))
        ctx.setFillColor(fc.cgColor)

        if skin.showShadow {
            ctx.setShadow(offset: CGSize(width: 2, height: -3), blur: 8,
                          color: NSColor.black.withAlphaComponent(0.3).cgColor)
        }
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        if skin.borderWidth > 0 {
            ctx.addEllipse(in: face.insetBy(dx: CGFloat(skin.borderWidth) / 2,
                                             dy: CGFloat(skin.borderWidth) / 2))
            ctx.setStrokeColor(skin.borderColor.nsColor.cgColor)
            ctx.setLineWidth(CGFloat(skin.borderWidth))
            ctx.strokePath()
        }
    }

    private func drawTicks(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        for i in 0..<60 {
            let angle = CGFloat(i) * .pi / 30
            let isHour = i % 5 == 0
            let outer = radius * 0.93
            let inner = isHour ? radius * 0.78 : radius * 0.88
            let width: CGFloat = isHour ? 2 : 1
            let color = isHour ? skin.hourTickColor.nsColor : skin.minuteTickColor.nsColor

            let x1 = center.x + outer * cos(angle)
            let y1 = center.y + outer * sin(angle)
            let x2 = center.x + inner * cos(angle)
            let y2 = center.y + inner * sin(angle)

            ctx.move(to: CGPoint(x: x1, y: y1))
            ctx.addLine(to: CGPoint(x: x2, y: y2))
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.strokePath()
        }
    }

    private func drawNumbers(_ ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: radius * 0.16, weight: .medium),
            .foregroundColor: skin.numberColor.nsColor
        ]
        for i in 1...12 {
            let angle = CGFloat(i) * .pi / 6 - .pi / 2
            let r = radius * 0.68
            let str = NSAttributedString(string: "\(i)", attributes: attrs)
            let size = str.size()
            let x = center.x + r * cos(angle) - size.width / 2
            let y = center.y + r * sin(angle) - size.height / 2
            str.draw(at: CGPoint(x: x, y: y))
        }
    }

    private func drawHand(_ ctx: CGContext, center: CGPoint,
                          angle: CGFloat, length: CGFloat, width: CGFloat,
                          color: NSColor, tail: CGFloat) {
        let tip = CGPoint(
            x: center.x + length * cos(angle),
            y: center.y + length * sin(angle)
        )
        let tailPt = CGPoint(
            x: center.x - tail * cos(angle),
            y: center.y - tail * sin(angle)
        )
        ctx.move(to: tailPt)
        ctx.addLine(to: tip)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }

    private func drawCenterDot(_ ctx: CGContext, center: CGPoint, size: CGFloat) {
        let r = size * 0.04
        let dot = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        ctx.addEllipse(in: dot)
        ctx.setFillColor(skin.centerDotColor.nsColor.cgColor)
        ctx.fillPath()
    }

    // MARK: - Mouse interaction

    override func mouseDown(with event: NSEvent) {
        isDragging = false
        dragStart = event.locationInWindow
    }

    override func mouseUp(with event: NSEvent) {
        // Only show calendar if we didn't drag
        if !isDragging {
            calendarPanel.toggleNearView(self)
        }
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let win = window else { return }
        let loc = event.locationInWindow
        let dx = loc.x - dragStart.x
        let dy = loc.y - dragStart.y
        // Threshold before treating as a drag (avoids suppressing tap)
        if !isDragging && (abs(dx) > 3 || abs(dy) > 3) {
            isDragging = true
        }
        guard isDragging else { return }
        var origin = win.frame.origin
        origin.x += dx
        origin.y += dy
        win.setFrameOrigin(origin)
        Settings.shared.windowX = Double(origin.x)
        Settings.shared.windowY = Double(origin.y)
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu(title: "Klok")

        let prefsItem = NSMenuItem(title: L10n.menuPrefs, action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let remindersItem = NSMenuItem(title: L10n.menuReminders, action: #selector(openReminders), keyEquivalent: "")
        remindersItem.target = self
        menu.addItem(remindersItem)

        menu.addItem(.separator())

        let topItem = NSMenuItem(title: L10n.menuAlwaysOnTop, action: #selector(toggleAlwaysOnTop), keyEquivalent: "")
        topItem.state = Settings.shared.alwaysOnTop ? .on : .off
        topItem.target = self
        menu.addItem(topItem)

        let pinItem = NSMenuItem(title: L10n.menuPinDesktop, action: #selector(togglePinToDesktop), keyEquivalent: "")
        pinItem.state = Settings.shared.pinToDesktop ? .on : .off
        pinItem.target = self
        menu.addItem(pinItem)

        menu.addItem(.separator())

        // target = nil lets the event travel up the responder chain to NSApplication
        let quitItem = NSMenuItem(title: L10n.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = nil
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func openPreferences() {
        NotificationCenter.default.post(name: .openPreferences, object: nil)
    }

    @objc private func openReminders() {
        NotificationCenter.default.post(name: .openReminders, object: nil)
    }

    @objc private func toggleAlwaysOnTop() {
        Settings.shared.alwaysOnTop.toggle()
    }

    @objc private func togglePinToDesktop() {
        Settings.shared.pinToDesktop.toggle()
    }
}

extension Notification.Name {
    static let openPreferences = Notification.Name("com.klok.openPreferences")
    static let openReminders   = Notification.Name("com.klok.openReminders")
}
