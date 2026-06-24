import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var clockWindowController: ClockWindowController!
    private var preferencesController: PreferencesWindowController?
    private var statusItem: NSStatusItem!
    private var clockTimer: Timer?
    let calendarPanel = CalendarPanel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        clockWindowController = ClockWindowController(calendarPanel: calendarPanel)
        clockWindowController.showClock()
        AlarmManager.shared.start()
        PluginManager.shared.activateEnabledPlugins()
        setupStatusBarItem()

        NotificationCenter.default.addObserver(
            self, selector: #selector(openPreferences),
            name: .openPreferences, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(openPreferencesGeneral),
            name: .openPreferencesGeneral, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(openReminders),
            name: .openReminders, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged),
            name: .settingsChanged, object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        PluginManager.shared.deactivatePlugins()
        AlarmManager.shared.stop()
        clockTimer?.invalidate()
    }

    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = statusItem.button {
            btn.action = #selector(statusBarClicked(_:))
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
            btn.target = self
        }
        updateStatusBarTitle()
        startClockTimer()
    }

    private func startClockTimer() {
        clockTimer?.invalidate()
        // Fire on the next whole second, then every second
        let now = Date()
        let delay = 1.0 - now.timeIntervalSince(Date(timeIntervalSince1970: now.timeIntervalSince1970.rounded(.down)))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.updateStatusBarTitle()
            self?.clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.updateStatusBarTitle()
            }
        }
    }

    private func updateStatusBarTitle() {
        guard let btn = statusItem?.button else { return }
        statusItem.isVisible = true

        let now  = Date()
        let cal  = Calendar.current
        let day  = cal.component(.day, from: now)

        let fmt  = DateFormatter()
        let custom = Settings.shared.menuBarDateFormat
        fmt.dateFormat = custom.isEmpty ? autoFormat() : custom
        let timeStr = fmt.string(from: now)

        let position = Settings.shared.menuBarIconPosition
        if position == 2 {
            btn.attributedTitle = makeTimeAttrString(timeStr, now: now)
            btn.image = nil
            btn.imagePosition = .noImage
            return
        }

        // Build the icon
        let icon: NSImage?
        switch Settings.shared.menuBarIconStyle {
        case 0:  icon = makeCircleImage(day: day)
        case 1:  icon = makeCalendarPageImage(day: day)
        case 2:
            let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            icon = NSImage(systemSymbolName: "calendar",
                           accessibilityDescription: nil)?.withSymbolConfiguration(cfg)
        default: icon = makeBadgeImage(day: day, date: now)   // style 3
        }

        btn.image = icon
        let gap = "\u{2002}"
        let fullStr = (position == 1) ? timeStr + gap : gap + timeStr
        btn.attributedTitle = makeTimeAttrString(fullStr, now: now)
        btn.imagePosition = (position == 1) ? .imageRight : .imageLeft
    }

    private func makeTimeAttrString(_ fullStr: String, now: Date) -> NSAttributedString {
        let base = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let ampm = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize + 2, weight: .regular)
        let attr = NSMutableAttributedString(string: fullStr, attributes: [.font: base])
        let custom = Settings.shared.menuBarDateFormat
        guard !Settings.shared.menuBar24Hour && custom.isEmpty else { return attr }
        let ampmFmt = DateFormatter()
        ampmFmt.dateFormat = "a"
        let marker = ampmFmt.string(from: now)
        if let range = fullStr.range(of: marker) {
            attr.addAttribute(.font, value: ampm, range: NSRange(range, in: fullStr))
        }
        return attr
    }

    private func autoFormat() -> String {
        if Settings.shared.menuBar24Hour {
            return Settings.shared.menuBarShowSeconds ? "HH:mm:ss" : "HH:mm"
        } else {
            return Settings.shared.menuBarShowSeconds ? "h:mm:ss a" : "h:mm a"
        }
    }

    private func makeCircleImage(day: Int) -> NSImage {
        NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            let circle = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            NSColor.controlAccentColor.setFill(); circle.fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let s = "\(day)" as NSString
            let sz = s.size(withAttributes: attrs)
            s.draw(at: NSPoint(x: (rect.width - sz.width) / 2,
                               y: (rect.height - sz.height) / 2), withAttributes: attrs)
            return true
        }
    }

    private func makeCalendarPageImage(day: Int) -> NSImage {
        NSImage(size: NSSize(width: 16, height: 18), flipped: false) { rect in
            let bg = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
            NSColor.secondaryLabelColor.withAlphaComponent(0.15).setFill(); bg.fill()
            NSColor.secondaryLabelColor.withAlphaComponent(0.5).setStroke()
            bg.lineWidth = 0.5; bg.stroke()
            let band = NSRect(x: 0.5, y: rect.height - 5.5, width: rect.width - 1, height: 5)
            let top = NSBezierPath(roundedRect: band, xRadius: 2, yRadius: 2)
            NSColor.controlAccentColor.setFill(); top.fill()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            let s = "\(day)" as NSString
            let sz = s.size(withAttributes: attrs)
            let bodyH = rect.height - 5
            s.draw(at: NSPoint(x: (rect.width - sz.width) / 2,
                               y: (bodyH - sz.height) / 2), withAttributes: attrs)
            return true
        }
    }

    private func makeBadgeImage(day: Int, date: Date) -> NSImage {
        NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            // Outer border + background
            let r = rect.insetBy(dx: 0.75, dy: 0.75)
            let bg = NSBezierPath(roundedRect: r, xRadius: 3.5, yRadius: 3.5)
            NSColor.secondaryLabelColor.withAlphaComponent(0.08).setFill(); bg.fill()
            NSColor.white.setStroke()
            bg.lineWidth = 1.0; bg.stroke()

            // Top accent band (~40% height)
            let splitY = r.minY + r.height * 0.60
            let topBand = NSRect(x: r.minX, y: splitY, width: r.width, height: r.maxY - splitY)
            let topPath = NSBezierPath(roundedRect: topBand, xRadius: 3.5, yRadius: 3.5)
            NSColor.controlAccentColor.setFill(); topPath.fill()
            // Square off the bottom corners of the band
            NSBezierPath(rect: NSRect(x: r.minX, y: splitY, width: r.width, height: 4)).fill()

            // Weekday abbreviation in band — use 2-char form (周日 / Sun)
            let cal = Calendar.current
            let wdIdx = cal.component(.weekday, from: date) - 1
            let wdStr = (L10n.calWeekdaysFull[wdIdx]) as NSString
            let wdAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 6, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let wdSz = wdStr.size(withAttributes: wdAttrs)
            let bandH = r.maxY - splitY
            wdStr.draw(at: NSPoint(
                x: r.minX + (r.width - wdSz.width) / 2,
                y: splitY + (bandH - wdSz.height) / 2 - 0.5),
                withAttributes: wdAttrs)

            // Day number in body
            let bodyAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
            let dayStr = "\(day)" as NSString
            let daySz = dayStr.size(withAttributes: bodyAttrs)
            let bodyH = splitY - r.minY
            dayStr.draw(at: NSPoint(
                x: r.minX + (r.width - daySz.width) / 2,
                y: r.minY + (bodyH - daySz.height) / 2),
                withAttributes: bodyAttrs)
            return true
        }
    }

    private var lastLanguage: String = Settings.shared.language

    @objc private func settingsChanged() {
        updateStatusBarTitle()
        let current = Settings.shared.language
        guard current != lastLanguage else { return }
        lastLanguage = current
        if preferencesController?.window?.isVisible == true {
            preferencesController?.close()
            preferencesController = nil
        }
    }

    @objc private func statusBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleCalendarPopover(sender)
        }
    }

    private func toggleCalendarPopover(_ sender: NSStatusBarButton) {
        calendarPanel.toggle(relativeTo: sender)
    }

    private func showStatusMenu() {
        guard let btn = statusItem.button,
              let event = NSApp.currentEvent else { return }
        let menu = NSMenu()
        let prefsItem = NSMenuItem(title: L10n.menuPrefs, action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        let remindersItem = NSMenuItem(title: L10n.menuReminders, action: #selector(openReminders), keyEquivalent: "")
        remindersItem.target = self
        menu.addItem(remindersItem)
        PluginMenuBuilder.appendPluginItems(
            from: PluginManager.shared.menuRegistry,
            location: .statusMenu,
            to: menu
        )
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: L10n.menuQuit, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.target = NSApp
        menu.addItem(quitItem)
        NSMenu.popUpContextMenu(menu, with: event, for: btn)
    }

    @objc func openPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.showWindow(nil)
        preferencesController?.selectTab(index: 1)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openPreferencesGeneral() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.showWindow(nil)
        preferencesController?.selectTab(index: 0)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func openReminders() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController()
        }
        preferencesController?.showWindow(nil)
        preferencesController?.selectTab(index: 3)
        NSApp.activate(ignoringOtherApps: true)
    }
}
