import AppKit
import ServiceManagement

final class PreferencesWindowController: NSWindowController, NSWindowDelegate {
    private let tabView = NSTabView()
    private var reminderTableView: NSTableView!
    private var reminders: [Reminder] = []
    private var editorController: ReminderEditorWindowController?
    private var suppressAutoClose = false
    private var pluginIDs: [String] = []
    private var initialPluginEnabledStates: [String: Bool] = [:]
    private var pluginRestartPromptShown = false

    init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.prefsTitle
        super.init(window: win)
        win.delegate = self
        win.center()
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        tabView.frame = content.bounds.insetBy(dx: 12, dy: 12)
        tabView.autoresizingMask = [.width, .height]
        tabView.delegate = self
        content.addSubview(tabView)

        tabView.addTabViewItem(makeGeneralTab())
        tabView.addTabViewItem(makeCalendarTab())
        tabView.addTabViewItem(makeAppearanceTab())
        tabView.addTabViewItem(makeRemindersTab())
        tabView.addTabViewItem(makePluginsTab())
    }

    // MARK: - General Tab

    private func makeGeneralTab() -> NSTabViewItem {
        let item = NSTabViewItem(); item.label = L10n.tabGeneral
        let view = NSView()

        let sizeLabel = label(L10n.clockSize)
        sizeLabel.frame = NSRect(x: 20, y: 400, width: 100, height: 22)
        view.addSubview(sizeLabel)

        let sizeSlider = NSSlider(value: Settings.shared.clockSize,
                                  minValue: 100, maxValue: 400,
                                  target: self, action: #selector(sizeChanged(_:)))
        sizeSlider.frame = NSRect(x: 130, y: 400, width: 200, height: 22)
        sizeSlider.tag = 1
        view.addSubview(sizeSlider)

        let sizeValue = NSTextField(labelWithString: "\(Int(Settings.shared.clockSize))px")
        sizeValue.frame = NSRect(x: 338, y: 400, width: 60, height: 22)
        sizeValue.tag = 10
        view.addSubview(sizeValue)

        let opacityLabel = label(L10n.opacity)
        opacityLabel.frame = NSRect(x: 20, y: 365, width: 100, height: 22)
        view.addSubview(opacityLabel)

        let opacitySlider = NSSlider(value: Settings.shared.opacity,
                                     minValue: 0.1, maxValue: 1.0,
                                     target: self, action: #selector(opacityChanged(_:)))
        opacitySlider.frame = NSRect(x: 130, y: 365, width: 200, height: 22)
        opacitySlider.tag = 2
        view.addSubview(opacitySlider)

        let opacityValue = NSTextField(labelWithString: "\(Int(Settings.shared.opacity * 100))%")
        opacityValue.frame = NSRect(x: 338, y: 365, width: 60, height: 22)
        opacityValue.tag = 11
        view.addSubview(opacityValue)

        let alwaysTop = checkbox(L10n.alwaysOnTop, state: Settings.shared.alwaysOnTop,
                                 action: #selector(toggleAlwaysOnTop(_:)))
        alwaysTop.frame = NSRect(x: 20, y: 325, width: 200, height: 22)
        view.addSubview(alwaysTop)

        let pinDesktop = checkbox(L10n.pinToDesktop, state: Settings.shared.pinToDesktop,
                                  action: #selector(togglePinToDesktop(_:)))
        pinDesktop.frame = NSRect(x: 20, y: 295, width: 200, height: 22)
        view.addSubview(pinDesktop)

        let embedDesktop = checkbox(L10n.embedInDesktop, state: Settings.shared.embedInDesktop,
                                    action: #selector(toggleEmbedInDesktop(_:)))
        embedDesktop.frame = NSRect(x: 20, y: 265, width: 200, height: 22)
        view.addSubview(embedDesktop)

        let chkClickThrough = checkbox(L10n.clickThrough, state: Settings.shared.clickThrough,
                                       action: #selector(toggleClickThrough(_:)))
        chkClickThrough.frame = NSRect(x: 20, y: 235, width: 200, height: 22)
        view.addSubview(chkClickThrough)

        let chkHover = checkbox(L10n.hoverTransparent, state: Settings.shared.hoverTransparent,
                                action: #selector(toggleHoverTransparent(_:)))
        chkHover.frame = NSRect(x: 20, y: 205, width: 180, height: 22)
        view.addSubview(chkHover)

        let hoverSlider = NSSlider(value: Settings.shared.hoverOpacity,
                                   minValue: 0.0, maxValue: 0.9,
                                   target: self, action: #selector(hoverOpacityChanged(_:)))
        hoverSlider.frame = NSRect(x: 205, y: 205, width: 140, height: 22)
        hoverSlider.tag = 12
        view.addSubview(hoverSlider)

        let hoverValue = NSTextField(labelWithString: "\(Int(Settings.shared.hoverOpacity * 100))%")
        hoverValue.frame = NSRect(x: 350, y: 205, width: 48, height: 22)
        hoverValue.tag = 13
        view.addSubview(hoverValue)

        let launchLogin = checkbox(L10n.launchAtLogin, state: LaunchAtLogin.isEnabled,
                                   action: #selector(toggleLaunchAtLogin(_:)))
        launchLogin.frame = NSRect(x: 20, y: 135, width: 200, height: 22)
        view.addSubview(launchLogin)

        let langLabel = label(L10n.language)
        langLabel.frame = NSRect(x: 20, y: 100, width: 100, height: 22)
        view.addSubview(langLabel)

        let langSeg = NSSegmentedControl(
            labels: [L10n.langZH, L10n.langZHTW, L10n.langEN],
            trackingMode: .selectOne,
            target: self,
            action: #selector(languageChanged(_:)))
        let langIdx: Int
        switch Settings.shared.language {
        case "zh-TW": langIdx = 1
        case "en":    langIdx = 2
        default:      langIdx = 0
        }
        langSeg.selectedSegment = langIdx
        langSeg.frame = NSRect(x: 130, y: 100, width: 180, height: 22)
        langSeg.tag = 99
        view.addSubview(langSeg)

        

        item.view = view
        return item
    }

    // MARK: - Calendar Tab

    private weak var fmtField: NSTextField?
    private weak var fmtPreviewLabel: NSTextField?
    private var styleButtons: [NSButton] = []

    private func makeCalendarTab() -> NSTabViewItem {
        let item = NSTabViewItem(); item.label = L10n.tabMenuBar
        let view = NSView()
        var y: CGFloat = 436

        // ── Section: 菜单栏 ──────────────────────────────────────────────
        let mbHdr = sectionHeader(L10n.menuBarSection)
        mbHdr.frame = NSRect(x: 16, y: y, width: 380, height: 17)
        view.addSubview(mbHdr)
        y -= 16

        // 4 icon style buttons: circle / calendar-page / SF-symbol / weekday-badge
        let styleSubs = [L10n.styleCircle, L10n.stylePage, L10n.styleSymbol, L10n.styleBadge]
        styleButtons.removeAll()
        let btnSz: CGFloat = 52
        let gap:   CGFloat = 14
        let rowX:  CGFloat = 16
        for i in 0..<4 {
            let btn = NSButton(title: "", target: self, action: #selector(styleSelected(_:)))
            btn.tag = i
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 10
            btn.layer?.borderWidth = 1.5
            btn.image = makeStylePreview(style: i)
            btn.imagePosition = .imageOnly
            btn.frame = NSRect(x: rowX + CGFloat(i) * (btnSz + gap), y: y - btnSz, width: btnSz, height: btnSz)
            view.addSubview(btn)
            styleButtons.append(btn)

            let sub = NSTextField(labelWithString: styleSubs[i])
            sub.font = .systemFont(ofSize: 10)
            sub.textColor = .secondaryLabelColor
            sub.alignment = .center
            sub.frame = NSRect(x: rowX + CGFloat(i) * (btnSz + gap), y: y - btnSz - 15,
                               width: btnSz, height: 14)
            view.addSubview(sub)
        }
        refreshStyleButtons()
        y -= btnSz + 50   // room for sublabels (14pt) + 14px breathing space

        // Icon position segmented control
        let posLbl = label(L10n.menuBarIconPosLabel)
        posLbl.frame = NSRect(x: 16, y: y, width: 80, height: 22)
        view.addSubview(posLbl)

        let posSeg = NSSegmentedControl(
            labels: [L10n.menuBarIconPosLeft, L10n.menuBarIconPosRight, L10n.menuBarIconPosHidden],
            trackingMode: .selectOne, target: self, action: #selector(iconPositionChanged(_:)))
        posSeg.selectedSegment = Settings.shared.menuBarIconPosition
        posSeg.frame = NSRect(x: 100, y: y, width: 280, height: 22)
        posSeg.tag = 77
        view.addSubview(posSeg)
        y -= 34   // extra gap before format row

        // Format row
        let fmtLbl = label(L10n.menuBarFmtLabel)
        fmtLbl.frame = NSRect(x: 16, y: y, width: 64, height: 22)
        view.addSubview(fmtLbl)

        let fmtStr = Settings.shared.menuBarDateFormat
        let field = NSTextField(string: fmtStr)
        field.frame = NSRect(x: 84, y: y, width: 220, height: 22)
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.target = self
        field.action = #selector(fmtFieldChanged(_:))
        field.delegate = self
        view.addSubview(field)
        fmtField = field

        let helpBtn = NSButton(title: "?", target: self, action: #selector(showFmtHelp))
        helpBtn.frame = NSRect(x: 308, y: y, width: 22, height: 22)
        helpBtn.bezelStyle = .circular
        helpBtn.controlSize = .small
        view.addSubview(helpBtn)

        let resetBtn = NSButton(title: L10n.menuBarFmtReset, target: self, action: #selector(resetFmt))
        resetBtn.frame = NSRect(x: 336, y: y, width: 56, height: 22)
        resetBtn.bezelStyle = .rounded
        resetBtn.controlSize = .small
        view.addSubview(resetBtn)
        y -= 26

        // Preview
        let prevLbl = label(L10n.menuBarFmtPreview)
        prevLbl.frame = NSRect(x: 16, y: y, width: 64, height: 22)
        view.addSubview(prevLbl)

        let previewLabel = NSTextField(labelWithString: "")
        previewLabel.frame = NSRect(x: 84, y: y, width: 300, height: 22)
        previewLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        previewLabel.textColor = .secondaryLabelColor
        view.addSubview(previewLabel)
        fmtPreviewLabel = previewLabel
        refreshPreview()
        y -= 34

        // Separator
        let sep1 = NSBox(); sep1.boxType = .separator
        sep1.frame = NSRect(x: 12, y: y + 6, width: 392, height: 4)
        view.addSubview(sep1)
        y -= 12

        // ── Section: 日历 ──────────────────────────────────────────────
        let calHdr = sectionHeader(L10n.calSection)
        calHdr.frame = NSRect(x: 16, y: y, width: 380, height: 17)
        view.addSubview(calHdr)
        y -= 30

        // Calendar font-size row: small Aa — slider — big Aa
        let smallAa = NSTextField(labelWithString: "Aa")
        smallAa.font = .systemFont(ofSize: 11)
        smallAa.textColor = .secondaryLabelColor
        smallAa.frame = NSRect(x: 16, y: y, width: 24, height: 22)
        view.addSubview(smallAa)

        let scaleSlider = NSSlider(value: Settings.shared.calendarScale,
                                   minValue: 0.7, maxValue: 1.4,
                                   target: self, action: #selector(calScaleChanged(_:)))
        scaleSlider.frame = NSRect(x: 44, y: y, width: 310, height: 22)
        scaleSlider.tag = 88
        view.addSubview(scaleSlider)

        let bigAa = NSTextField(labelWithString: "Aa")
        bigAa.font = .systemFont(ofSize: 17)
        bigAa.textColor = .secondaryLabelColor
        bigAa.frame = NSRect(x: 358, y: y - 2, width: 30, height: 26)
        view.addSubview(bigAa)
        y -= 32

        let checkboxDefs: [(String, Bool, Selector)] = [
            (L10n.calShowEventDots,    Settings.shared.calShowEventDots,     #selector(toggleCalEventDots(_:))),
            (L10n.calColorfulDots,     Settings.shared.calColorfulDots,      #selector(toggleCalColorfulDots(_:))),
            (L10n.calShowEventLoc,     Settings.shared.calShowEventLocation,  #selector(toggleCalEventLoc(_:))),
            (L10n.calShowInactiveDays, Settings.shared.calShowInactiveDays,  #selector(toggleCalInactiveDays(_:))),
            (L10n.calShowWeekNumbers,  Settings.shared.calShowWeekNumbers,   #selector(toggleCalWeekNumbers(_:))),
        ]
        for (title, state, action) in checkboxDefs {
            let chk = checkbox(title, state: state, action: action)
            chk.frame = NSRect(x: 16, y: y, width: 370, height: 22)
            view.addSubview(chk)
            y -= 26
        }

        item.view = view
        return item
    }

    // Draws a small 40×40 preview image representing each icon style
    private func makeStylePreview(style: Int) -> NSImage {
        let sz = NSSize(width: 40, height: 40)
        return NSImage(size: sz, flipped: false) { rect in
            let accent = NSColor.controlAccentColor
            switch style {
            case 0: // circle with "21"
                let path = NSBezierPath(ovalIn: rect.insetBy(dx: 6, dy: 6))
                accent.setFill(); path.fill()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
                let s = "21" as NSString
                let siz = s.size(withAttributes: attrs)
                s.draw(at: NSPoint(x: (rect.width - siz.width) / 2,
                                   y: (rect.height - siz.height) / 2), withAttributes: attrs)
            case 1: // calendar page
                let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 5, dy: 4), xRadius: 3, yRadius: 3)
                NSColor.secondaryLabelColor.withAlphaComponent(0.15).setFill(); bg.fill()
                NSColor.secondaryLabelColor.withAlphaComponent(0.4).setStroke()
                bg.lineWidth = 0.75; bg.stroke()
                let band = NSRect(x: 5, y: rect.height - 11, width: rect.width - 10, height: 8)
                let top = NSBezierPath(roundedRect: band, xRadius: 3, yRadius: 3)
                accent.setFill(); top.fill()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
                let s = "21" as NSString
                let siz = s.size(withAttributes: attrs)
                let bodyH = rect.height - 11 - 4
                s.draw(at: NSPoint(x: (rect.width - siz.width) / 2,
                                   y: 4 + (bodyH - siz.height) / 2), withAttributes: attrs)
            case 2: // SF Symbol
                if let img = NSImage(systemSymbolName: "calendar",
                                     accessibilityDescription: nil) {
                    let cfg = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
                    let tinted = img.withSymbolConfiguration(cfg)
                    accent.set()
                    tinted?.draw(in: rect.insetBy(dx: 6, dy: 6))
                }
            default: // 3 = weekday-badge
                let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), xRadius: 6, yRadius: 6)
                NSColor.secondaryLabelColor.withAlphaComponent(0.1).setFill(); bg.fill()
                NSColor.secondaryLabelColor.withAlphaComponent(0.3).setStroke()
                bg.lineWidth = 0.75; bg.stroke()
                let inner = rect.insetBy(dx: 4, dy: 4)
                let split = inner.height * 0.42
                let topBand = NSRect(x: inner.minX, y: inner.maxY - split,
                                     width: inner.width, height: split)
                let topPath = NSBezierPath(roundedRect: topBand, xRadius: 6, yRadius: 6)
                accent.setFill(); topPath.fill()
                // clip bottom corners of topBand to square
                let fillBottom = NSRect(x: topBand.minX, y: topBand.minY,
                                        width: topBand.width, height: 6)
                NSBezierPath(rect: fillBottom).fill()

                let wdAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 8, weight: .semibold),
                    .foregroundColor: NSColor.white
                ]
                let wd = L10n.badgeSatPreview as NSString
                let wdSz = wd.size(withAttributes: wdAttrs)
                wd.draw(at: NSPoint(x: inner.minX + (inner.width - wdSz.width) / 2,
                                    y: topBand.minY + (split - wdSz.height) / 2),
                        withAttributes: wdAttrs)

                let dayAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: NSColor.labelColor
                ]
                let bodyH = inner.height - split
                let day = "21" as NSString
                let daySz = day.size(withAttributes: dayAttrs)
                day.draw(at: NSPoint(x: inner.minX + (inner.width - daySz.width) / 2,
                                     y: inner.minY + (bodyH - daySz.height) / 2),
                         withAttributes: dayAttrs)
            }
            return true
        }
    }

    private func sectionHeader(_ title: String) -> NSTextField {
        let tf = NSTextField(labelWithString: title)
        tf.font = .systemFont(ofSize: 11, weight: .semibold)
        tf.textColor = .secondaryLabelColor
        return tf
    }

    private func refreshStyleButtons() {
        let sel = Settings.shared.menuBarIconStyle
        for btn in styleButtons {
            let isSelected = btn.tag == sel
            btn.layer?.borderColor = isSelected
                ? NSColor.controlAccentColor.cgColor
                : NSColor.separatorColor.cgColor
            btn.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
                : NSColor.clear.cgColor
        }
    }

    @objc private func styleSelected(_ sender: NSButton) {
        Settings.shared.menuBarIconStyle = sender.tag
        refreshStyleButtons()
    }

    @objc private func iconPositionChanged(_ sender: NSSegmentedControl) {
        Settings.shared.menuBarIconPosition = sender.selectedSegment
    }

    @objc private func toggleCalEventDots(_ s: NSButton)    { Settings.shared.calShowEventDots     = s.state == .on }
    @objc private func toggleCalColorfulDots(_ s: NSButton) { Settings.shared.calColorfulDots      = s.state == .on }
    @objc private func toggleCalEventLoc(_ s: NSButton)     { Settings.shared.calShowEventLocation = s.state == .on }
    @objc private func toggleCalInactiveDays(_ s: NSButton) { Settings.shared.calShowInactiveDays  = s.state == .on }
    @objc private func toggleCalWeekNumbers(_ s: NSButton)  { Settings.shared.calShowWeekNumbers   = s.state == .on }

    @objc private func calScaleChanged(_ sender: NSSlider) {
        Settings.shared.calendarScale = sender.doubleValue
    }

    @objc private func showFmtHelp() {
        let tokens: [(String, String)] = [
            ("y / yyyy",                L10n.fmtTokenYear),
            ("M / MM / MMM / MMMM",     L10n.fmtTokenMonth),
            ("d / dd",                  L10n.fmtTokenDay),
            ("E / EEEE",                L10n.fmtTokenWeekday),
            ("H / HH",                  L10n.fmtTokenHour24),
            ("h / hh",                  L10n.fmtTokenHour12),
            ("m / mm",                  L10n.fmtTokenMinute),
            ("s / ss",                  L10n.fmtTokenSecond),
            ("a",                       L10n.fmtTokenAmPm),
            ("w",                       L10n.fmtTokenWeek),
            ("'text'",                  L10n.fmtTokenLiteral),
        ]
        let body = tokens.map { "  \($0.0.padding(toLength: 20, withPad: " ", startingAt: 0))\($0.1)" }.joined(separator: "\n")
        let alert = NSAlert()
        alert.messageText = L10n.menuBarFmtHelp
        alert.informativeText = body
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window!) { _ in }
    }

    @objc private func fmtFieldChanged(_ sender: NSTextField) {
        Settings.shared.menuBarDateFormat = sender.stringValue
        refreshPreview()
    }

    @objc private func resetFmt() {
        let def = L10n.menuBarFmtDefault
        fmtField?.stringValue = def
        Settings.shared.menuBarDateFormat = def
        refreshPreview()
    }

    private func refreshPreview() {
        guard let field = fmtField, let preview = fmtPreviewLabel else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = field.stringValue
        preview.stringValue = fmt.string(from: Date())
    }

    @objc private func toggleMenuBarSeconds(_ sender: NSButton) {
        Settings.shared.menuBarShowSeconds = sender.state == .on
    }

    @objc private func toggleMenuBar24Hour(_ sender: NSButton) {
        Settings.shared.menuBar24Hour = sender.state == .on
    }

    @objc private func sizeChanged(_ sender: NSSlider) {
        let v = sender.doubleValue
        Settings.shared.clockSize = v
        if let lbl = tabView.tabViewItems[0].view?.viewWithTag(10) as? NSTextField {
            lbl.stringValue = "\(Int(v))px"
        }
    }

    @objc private func opacityChanged(_ sender: NSSlider) {
        let v = sender.doubleValue
        Settings.shared.opacity = v
        if let lbl = tabView.tabViewItems[0].view?.viewWithTag(11) as? NSTextField {
            lbl.stringValue = "\(Int(v * 100))%"
        }
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSButton) {
        Settings.shared.alwaysOnTop = sender.state == .on
    }

    @objc private func togglePinToDesktop(_ sender: NSButton) {
        Settings.shared.pinToDesktop = sender.state == .on
    }

    @objc private func toggleEmbedInDesktop(_ sender: NSButton) {
        Settings.shared.embedInDesktop = sender.state == .on
    }

    @objc private func toggleClickThrough(_ sender: NSButton) {
        Settings.shared.clickThrough = sender.state == .on
    }

    @objc private func toggleHoverTransparent(_ sender: NSButton) {
        Settings.shared.hoverTransparent = sender.state == .on
    }

    @objc private func hoverOpacityChanged(_ sender: NSSlider) {
        let v = sender.doubleValue
        Settings.shared.hoverOpacity = v
        if let lbl = tabView.tabViewItems[0].view?.viewWithTag(13) as? NSTextField {
            lbl.stringValue = "\(Int(v * 100))%"
        }
    }

    @objc private func toggleSecondHand(_ sender: NSButton) {
        Settings.shared.showSecondHand = sender.state == .on
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        LaunchAtLogin.setEnabled(sender.state == .on)
    }

    @objc private func languageChanged(_ sender: NSSegmentedControl) {
        let langs = ["zh", "zh-TW", "en"]
        let idx = sender.selectedSegment
        guard idx >= 0, idx < langs.count else { return }
        Settings.shared.language = langs[idx]
    }

    // MARK: - Appearance Tab

    private var skinURLs: [URL] = {
        if let dir = Settings.shared.customSkinDirectory {
            let url = URL(fileURLWithPath: dir)
            let skins = ClocXSkinLoader.availableSkins(in: url)
            if !skins.isEmpty { return skins }
        }
        return ClocXSkinLoader.availableSkins()
    }()
    private var filteredSkinURLs: [URL] = []
    private weak var skinTableView: NSTableView?
    private weak var skinDirPathLabel: NSTextField?
    private weak var skinDirClearButton: NSButton?

    private func makeAppearanceTab() -> NSTabViewItem {
        let item = NSTabViewItem(); item.label = L10n.tabAppearance
        let view = NSView()
        filteredSkinURLs = skinURLs

        // Search field — top, 12px side margins
        let search = NSSearchField(frame: NSRect(x: 12, y: 356, width: 372, height: 24))
        search.placeholderString = L10n.searchSkins
        search.target = self
        search.action = #selector(skinSearchChanged(_:))
        view.addSubview(search)

        // Options row 1: AM/PM  |  日期
        let chkAmPm = checkbox(L10n.showAmPm, state: Settings.shared.showAmPm, action: #selector(toggleAmPm(_:)))
        chkAmPm.frame = NSRect(x: 12, y: 325, width: 186, height: 22)
        view.addSubview(chkAmPm)

        let chkDate = checkbox(L10n.showDate, state: Settings.shared.showDate, action: #selector(toggleDate(_:)))
        chkDate.frame = NSRect(x: 198, y: 325, width: 186, height: 22)
        view.addSubview(chkDate)

        // Options row 2: 秒针  |  跳跃
        let chkSec = checkbox(L10n.showSecondHand, state: Settings.shared.showSecondHand, action: #selector(toggleSecondHandApp(_:)))
        chkSec.frame = NSRect(x: 12, y: 298, width: 186, height: 22)
        view.addSubview(chkSec)

        let chkJump = checkbox(L10n.secondHandJump, state: Settings.shared.secondHandJump, action: #selector(toggleSecondJump(_:)))
        chkJump.frame = NSRect(x: 198, y: 298, width: 186, height: 22)
        view.addSubview(chkJump)

        // Skin directory picker row
        let dirLabel = NSTextField(labelWithString: L10n.skinDirLabel)
        dirLabel.frame = NSRect(x: 12, y: 271, width: 82, height: 17)
        dirLabel.font = .systemFont(ofSize: 12)
        view.addSubview(dirLabel)

        let pathLabel = NSTextField(labelWithString: Settings.shared.customSkinDirectory ?? L10n.skinDirNone)
        pathLabel.frame = NSRect(x: 96, y: 271, width: 170, height: 17)
        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = Settings.shared.customSkinDirectory == nil ? .secondaryLabelColor : .labelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        view.addSubview(pathLabel)
        skinDirPathLabel = pathLabel

        let browseBtn = NSButton(title: L10n.skinDirBrowse, target: self, action: #selector(browseSkinDirectory))
        browseBtn.frame = NSRect(x: 270, y: 267, width: 56, height: 22)
        browseBtn.bezelStyle = .rounded
        browseBtn.font = .systemFont(ofSize: 11)
        view.addSubview(browseBtn)

        let clearBtn = NSButton(title: L10n.skinDirClear, target: self, action: #selector(clearSkinDirectory))
        clearBtn.frame = NSRect(x: 330, y: 267, width: 54, height: 22)
        clearBtn.bezelStyle = .rounded
        clearBtn.font = .systemFont(ofSize: 11)
        clearBtn.isEnabled = Settings.shared.customSkinDirectory != nil
        view.addSubview(clearBtn)
        skinDirClearButton = clearBtn

        // Scroll view fills space below options
        let scroll = NSScrollView(frame: NSRect(x: 12, y: 8, width: 372, height: 252))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        let table = NSTableView()
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("skin"))
        col.title = "Skin"
        col.width = 356
        table.addTableColumn(col)
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.tag = 100
        table.rowHeight = 32
        scroll.documentView = table
        skinTableView = table

        view.addSubview(scroll)
        item.view = view
        return item
    }

    @objc private func toggleAmPm(_ sender: NSButton) {
        Settings.shared.showAmPm = sender.state == .on
    }

    @objc private func toggleDate(_ sender: NSButton) {
        Settings.shared.showDate = sender.state == .on
    }

    @objc private func toggleSecondHandApp(_ sender: NSButton) {
        Settings.shared.showSecondHand = sender.state == .on
    }

    @objc private func toggleSecondJump(_ sender: NSButton) {
        Settings.shared.secondHandJump = sender.state == .on
    }

    @objc private func skinSearchChanged(_ sender: NSSearchField) {
        let query = sender.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        filteredSkinURLs = query.isEmpty ? skinURLs : skinURLs.filter {
            $0.deletingPathExtension().lastPathComponent.lowercased().contains(query)
        }
        skinTableView?.reloadData()
    }

    private func refreshActiveLabel() {}

    @objc private func clearClocXSkin() {}

    @objc private func browseSkinDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.skinDirBrowse
        panel.beginSheetModal(for: window!) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.applySkinDirectory(url)
        }
    }

    @objc private func clearSkinDirectory() {
        Settings.shared.customSkinDirectory = nil
        // If the active skin came from the custom directory, clear it too
        if let activePath = Settings.shared.clocxSkinPath {
            let wasBundled = ClocXSkinLoader.availableSkins().map(\.path).contains(activePath)
            if !wasBundled { Settings.shared.clocxSkinPath = nil }
        }
        reloadSkinList(directory: nil)
    }

    private func applySkinDirectory(_ url: URL) {
        Settings.shared.customSkinDirectory = url.path
        reloadSkinList(directory: url)
    }

    private func reloadSkinList(directory: URL?) {
        if let dir = directory {
            skinURLs = ClocXSkinLoader.availableSkins(in: dir)
        } else {
            skinURLs = ClocXSkinLoader.availableSkins()
        }
        filteredSkinURLs = skinURLs

        let hasCustom = Settings.shared.customSkinDirectory != nil
        skinDirPathLabel?.stringValue = Settings.shared.customSkinDirectory ?? L10n.skinDirNone
        skinDirPathLabel?.textColor = hasCustom ? .labelColor : .secondaryLabelColor
        skinDirClearButton?.isEnabled = hasCustom
        skinTableView?.reloadData()
    }

    // MARK: - Reminders Tab

    private func makeRemindersTab() -> NSTabViewItem {
        let item = NSTabViewItem(); item.label = L10n.tabAlarms
        let view = NSView()
        reminders = Settings.shared.alarms

        // Header label
        let header = NSTextField(labelWithString: L10n.remindersSorted)
        header.font = .systemFont(ofSize: 11)
        header.textColor = .secondaryLabelColor
        header.frame = NSRect(x: 12, y: 352, width: 280, height: 17)
        view.addSubview(header)

        // Table
        let scroll = NSScrollView(frame: NSRect(x: 12, y: 62, width: 280, height: 284))
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        reminderTableView = NSTableView()
        let nameCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameCol.title = L10n.reminderColName; nameCol.width = 130
        let timeCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        timeCol.title = L10n.reminderColTime; timeCol.width = 78
        let dateCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateCol.title = L10n.reminderColDate; dateCol.width = 70
        reminderTableView.addTableColumn(nameCol)
        reminderTableView.addTableColumn(timeCol)
        reminderTableView.addTableColumn(dateCol)
        reminderTableView.dataSource = self
        reminderTableView.delegate = self
        reminderTableView.tag = 200
        reminderTableView.allowsMultipleSelection = false
        scroll.documentView = reminderTableView

        view.addSubview(scroll)

        // Buttons (right side)
        let btnX: CGFloat = 302
        let btnW: CGFloat = 84
        func sideBtn(_ title: String, y: CGFloat, action: Selector) -> NSButton {
            let b = NSButton(title: title, target: self, action: action)
            b.frame = NSRect(x: btnX, y: y, width: btnW, height: 26)
            b.bezelStyle = .rounded
            return b
        }
        view.addSubview(sideBtn(L10n.reminderAdd,    y: 320, action: #selector(addReminder)))
        view.addSubview(sideBtn(L10n.reminderEdit,   y: 288, action: #selector(editReminder)))
        view.addSubview(sideBtn(L10n.reminderDelete, y: 256, action: #selector(deleteReminder)))
        view.addSubview(sideBtn(L10n.reminderTest,   y: 224, action: #selector(testReminder)))

        item.view = view
        return item
    }

    @objc private func addReminder() {
        openEditor(editing: nil)
    }

    @objc private func editReminder() {
        let row = reminderTableView.selectedRow
        guard row >= 0, row < reminders.count else { return }
        openEditor(editing: reminders[row])
    }

    @objc private func deleteReminder() {
        let row = reminderTableView.selectedRow
        guard row >= 0, row < reminders.count else { return }
        reminders.remove(at: row)
        saveReminders()
        reminderTableView.reloadData()
    }

    @objc private func testReminder() {
        let row = reminderTableView.selectedRow
        guard row >= 0, row < reminders.count else { return }
        suppressAutoClose = true
        AlarmManager.shared.fire(reminders[row])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.suppressAutoClose = false
        }
    }

    private func openEditor(editing reminder: Reminder?) {
        let editor = ReminderEditorWindowController(editing: reminder) { [weak self] saved in
            guard let self, let r = saved else { return }
            if let idx = self.reminders.firstIndex(where: { $0.id == r.id }) {
                self.reminders[idx] = r
            } else {
                self.reminders.append(r)
            }
            self.saveReminders()
            self.reminderTableView.reloadData()
            self.editorController = nil
        }
        editorController = editor
        editor.show(relativeTo: window)
    }

    private func saveReminders() {
        reminders.sort { ($0.hour * 3600 + $0.minute * 60 + $0.second) < ($1.hour * 3600 + $1.minute * 60 + $1.second) }
        Settings.shared.alarms = reminders
    }

    private func reminderCell(for row: Int, column: NSTableColumn?, in tableView: NSTableView) -> NSView {
        let r = reminders[row]
        let id = column?.identifier.rawValue ?? ""
        let cell = NSTableCellView()
        let tf = NSTextField(labelWithString: {
            switch id {
            case "name": return r.name
            case "time": return r.timeString
            case "date": return r.dateString
            default:     return ""
            }
        }())
        tf.frame = NSRect(x: 4, y: 4, width: (column?.width ?? 80) - 8, height: 17)
        tf.font = .systemFont(ofSize: 12)
        if !r.enabled { tf.textColor = .secondaryLabelColor }
        cell.addSubview(tf)
        return cell
    }

    // MARK: - Plugins Tab

    private func makePluginsTab() -> NSTabViewItem {
        let item = NSTabViewItem(); item.label = L10n.tabPlugins
        let view = NSView()
        PluginManager.shared.registerBuiltinPlugins()
        let plugins = PluginManager.shared.plugins
        pluginIDs = plugins.map(\.id)
        initialPluginEnabledStates = pluginEnabledStates(for: pluginIDs)

        let box = NSBox(frame: NSRect(x: 12, y: 82, width: 384, height: 330))
        box.title = L10n.pluginListTitle
        box.boxType = .primary
        view.addSubview(box)

        var y: CGFloat = 272
        for (idx, plugin) in plugins.enumerated() {
            let enabled = PluginManager.shared.settings.isEnabled(
                pluginID: plugin.id,
                default: plugin.isEnabledByDefault
            )
            let check = NSButton(checkboxWithTitle: plugin.name, target: self, action: #selector(pluginEnabledChanged(_:)))
            check.state = enabled ? .on : .off
            check.tag = idx
            check.frame = NSRect(x: 24, y: y, width: 180, height: 22)
            box.contentView?.addSubview(check)

            let version = NSTextField(labelWithString: "v\(plugin.version)")
            version.textColor = .secondaryLabelColor
            version.font = .systemFont(ofSize: 11)
            version.frame = NSRect(x: 204, y: y + 1, width: 52, height: 17)
            box.contentView?.addSubview(version)

            let configure = NSButton(title: L10n.pluginConfigure, target: self, action: #selector(configurePlugin(_:)))
            configure.tag = idx
            configure.isEnabled = plugin.isConfigurable
            configure.frame = NSRect(x: 270, y: y - 2, width: 92, height: 26)
            configure.bezelStyle = .rounded
            box.contentView?.addSubview(configure)

            y -= 34
        }

        let hint = NSTextField(wrappingLabelWithString: L10n.pluginRestartHint)
        hint.frame = NSRect(x: 24, y: 28, width: 360, height: 38)
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 12)
        view.addSubview(hint)

        item.view = view
        return item
    }

    @objc private func pluginEnabledChanged(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < pluginIDs.count else { return }
        PluginManager.shared.settings.setEnabled(sender.state == .on, pluginID: pluginIDs[sender.tag])
    }

    @objc private func configurePlugin(_ sender: NSButton) {
        guard sender.tag >= 0, sender.tag < pluginIDs.count,
              let plugin = PluginManager.shared.plugin(withID: pluginIDs[sender.tag])
        else { return }
        plugin.showConfiguration(parentWindow: window)
    }

    // MARK: - Helpers

    private func label(_ s: String) -> NSTextField {
        let f = NSTextField(labelWithString: s)
        f.alignment = .right
        return f
    }

    private func checkbox(_ title: String, state: Bool, action: Selector) -> NSButton {
        let b = NSButton(checkboxWithTitle: title, target: self, action: action)
        b.state = state ? .on : .off
        return b
    }

    func selectTab(index: Int) {
        guard index < tabView.tabViewItems.count else { return }
        tabView.selectTabViewItem(at: index)
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !suppressAutoClose, window?.attachedSheet == nil else { return }
        if hasPluginEnablementChanges(), !pluginRestartPromptShown {
            promptForPluginRestart()
            return
        }
        close()
    }

    private func pluginEnabledStates(for pluginIDs: [String]) -> [String: Bool] {
        Dictionary(uniqueKeysWithValues: pluginIDs.map { pluginID in
            let plugin = PluginManager.shared.plugin(withID: pluginID)
            return (
                pluginID,
                PluginManager.shared.settings.isEnabled(
                    pluginID: pluginID,
                    default: plugin?.isEnabledByDefault ?? true
                )
            )
        })
    }

    private func hasPluginEnablementChanges() -> Bool {
        pluginEnabledStates(for: pluginIDs) != initialPluginEnabledStates
    }

    private func promptForPluginRestart() {
        pluginRestartPromptShown = true
        suppressAutoClose = true
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = L10n.pluginRestartTitle
        alert.informativeText = L10n.pluginRestartMessage
        alert.addButton(withTitle: L10n.pluginRestartNow)
        alert.addButton(withTitle: L10n.pluginRestartLater)

        guard let window else {
            handlePluginRestartResponse(alert.runModal())
            return
        }

        alert.beginSheetModal(for: window) { [weak self] response in
            self?.handlePluginRestartResponse(response)
        }
    }

    private func handlePluginRestartResponse(_ response: NSApplication.ModalResponse) {
        suppressAutoClose = false
        initialPluginEnabledStates = pluginEnabledStates(for: pluginIDs)

        if response == .alertFirstButtonReturn {
            restartApplication()
        } else {
            close()
        }
    }

    private func restartApplication() {
        guard let appURL = restartableAppBundleURL() else {
            showRestartUnavailable()
            return
        }

        UserDefaults.standard.synchronize()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-n", appURL.path]

        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            showRestartFailed(message: error.localizedDescription)
        }
    }

    private func restartableAppBundleURL() -> URL? {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension.lowercased() == "app" else { return nil }
        return bundleURL
    }

    private func showRestartUnavailable() {
        let alert = NSAlert()
        alert.messageText = L10n.pluginRestartTitle
        alert.informativeText = L10n.pluginRestartUnavailable
        alert.addButton(withTitle: L10n.btnOK)
        alert.runModal()
        close()
    }

    private func showRestartFailed(message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.pluginRestartFailed
        alert.informativeText = message
        alert.addButton(withTitle: L10n.btnOK)
        alert.runModal()
    }
}

// MARK: - NSTextFieldDelegate

extension PreferencesWindowController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === fmtField else { return }
        Settings.shared.menuBarDateFormat = field.stringValue
        refreshPreview()
    }
}

// MARK: - NSTableViewDataSource / Delegate

extension PreferencesWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView.tag == 100 {
            return skinURLs.isEmpty ? Skin.all.count : filteredSkinURLs.count
        }
        return reminders.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableView.tag == 100 {
            return skinURLs.isEmpty ? builtinSkinCell(for: row, in: tableView)
                                    : clocxSkinCell(for: row, in: tableView)
        } else {
            return reminderCell(for: row, column: tableColumn, in: tableView)
        }
    }

    // Cell for original ClocX PNG/BMP skins
    private func clocxSkinCell(for row: Int, in tableView: NSTableView) -> NSView {
        let url = filteredSkinURLs[row]
        let skinName = url.deletingPathExtension().lastPathComponent
        let cell = NSTableCellView()
        cell.frame = NSRect(x: 0, y: 0, width: 374, height: 32)

        // Thumbnail with cut-color masking applied
        let thumb = NSImageView(frame: NSRect(x: 6, y: 4, width: 24, height: 24))
        if let skin = ClocXSkinLoader.load(from: url) {
            if let cut = skin.cutColor {
                thumb.image = ClocXSkinLoader.maskedNSImage(for: url, cutColor: cut)
            } else {
                thumb.image = skin.faceImage
            }
        }
        thumb.imageScaling = .scaleProportionallyUpOrDown
        cell.addSubview(thumb)

        let name = NSTextField(labelWithString: skinName)
        name.frame = NSRect(x: 36, y: 8, width: 290, height: 17)
        name.font = .systemFont(ofSize: 12, weight: .medium)
        cell.addSubview(name)

        if Settings.shared.clocxSkinPath == url.path {
            let check = NSTextField(labelWithString: "✓")
            check.frame = NSRect(x: 348, y: 8, width: 20, height: 17)
            check.textColor = .systemBlue
            cell.addSubview(check)
        }
        return cell
    }

    // Fallback: built-in code skins
    private func builtinSkinCell(for row: Int, in tableView: NSTableView) -> NSView {
        let skin = Skin.all[row]
        let cell = NSTableCellView()
        cell.frame = NSRect(x: 0, y: 0, width: 374, height: 32)

        let preview = ClockPreviewView(skin: skin)
        preview.frame = NSRect(x: 6, y: 4, width: 24, height: 24)
        cell.addSubview(preview)

        let name = NSTextField(labelWithString: skin.name)
        name.frame = NSRect(x: 36, y: 8, width: 290, height: 17)
        name.font = .systemFont(ofSize: 12, weight: .medium)
        cell.addSubview(name)

        if skin.id == Settings.shared.skinID && Settings.shared.clocxSkinPath == nil {
            let check = NSTextField(labelWithString: "✓")
            check.frame = NSRect(x: 348, y: 8, width: 20, height: 17)
            check.textColor = .systemBlue
            cell.addSubview(check)
        }
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tv = notification.object as? NSTableView, tv.tag == 100 else { return }
        let row = tv.selectedRow
        guard row >= 0 else { return }

        let prevPath = Settings.shared.clocxSkinPath
        let prevID   = Settings.shared.skinID

        if skinURLs.isEmpty {
            Settings.shared.skinID = Skin.all[row].id
            Settings.shared.clocxSkinPath = nil
        } else {
            Settings.shared.clocxSkinPath = filteredSkinURLs[row].path
        }
        refreshActiveLabel()

        // Only reload the rows whose checkmark state changed (old + new selection)
        var dirty = IndexSet([row])
        if skinURLs.isEmpty {
            if let old = Skin.all.firstIndex(where: { $0.id == prevID }) { dirty.insert(old) }
        } else {
            if let old = filteredSkinURLs.firstIndex(where: { $0.path == prevPath }) { dirty.insert(old) }
        }
        tv.reloadData(forRowIndexes: dirty, columnIndexes: IndexSet(integer: 0))

        // Restore keyboard focus to the table so arrow keys keep working
        tv.window?.makeFirstResponder(tv)
    }

    private func editableField(_ str: String, tag: Int) -> NSTextField {
        let f = NSTextField(string: str)
        f.tag = tag
        f.isBordered = true
        f.isEditable = true
        return f
    }
}

// MARK: - NSTabViewDelegate

extension PreferencesWindowController: NSTabViewDelegate {
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        // Guard: all 4 tabs must already be added before we inspect index 2
        guard tabView.tabViewItems.count > 2,
              tabViewItem === tabView.tabViewItems[2] else { return }
        if let tv = skinTableView {
            tabView.window?.makeFirstResponder(tv)
            if tv.selectedRow < 0 {
                let activeRow: Int?
                if skinURLs.isEmpty {
                    activeRow = Skin.all.firstIndex(where: { $0.id == Settings.shared.skinID })
                } else {
                    activeRow = filteredSkinURLs.firstIndex(where: { $0.path == Settings.shared.clocxSkinPath })
                }
                if let r = activeRow {
                    tv.selectRowIndexes(IndexSet(integer: r), byExtendingSelection: false)
                    tv.scrollRowToVisible(r)
                }
            }
        }
    }
}

// MARK: - Clock Preview Thumbnail

final class ClockPreviewView: NSView {
    let skin: Skin
    init(skin: Skin) { self.skin = skin; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let r = min(bounds.width, bounds.height) / 2 - 2
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.setFillColor(skin.faceColor.nsColor.withAlphaComponent(CGFloat(max(skin.faceAlpha, 0.3))).cgColor)
        ctx.fillPath()
        if skin.borderWidth > 0 {
            ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            ctx.setStrokeColor(skin.borderColor.nsColor.cgColor)
            ctx.setLineWidth(1)
            ctx.strokePath()
        }
        let angle = CGFloat.pi / 4
        ctx.move(to: CGPoint(x: c.x - (r * 0.4) * cos(angle), y: c.y - (r * 0.4) * sin(angle)))
        ctx.addLine(to: CGPoint(x: c.x + (r * 0.55) * cos(angle), y: c.y + (r * 0.55) * sin(angle)))
        ctx.setStrokeColor(skin.hourHandColor.nsColor.cgColor)
        ctx.setLineWidth(2)
        ctx.setLineCap(.round)
        ctx.strokePath()
        let m: CGFloat = .pi / 6
        ctx.move(to: CGPoint(x: c.x - (r * 0.3) * cos(m), y: c.y - (r * 0.3) * sin(m)))
        ctx.addLine(to: CGPoint(x: c.x + (r * 0.75) * cos(m), y: c.y + (r * 0.75) * sin(m)))
        ctx.setStrokeColor(skin.minuteHandColor.nsColor.cgColor)
        ctx.setLineWidth(1.5)
        ctx.strokePath()
    }
}

// MARK: - Launch at Login (macOS 13+, SMAppService)

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently ignore — launch-at-login requires the app to be in /Applications
            // and will fail gracefully during development
        }
    }
}
