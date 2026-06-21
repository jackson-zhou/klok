import AppKit
import EventKit

// MARK: - Unified calendar panel

final class CalendarPanel: NSPanel {
    private let vc = CalendarViewController()
    var isPinned = false
    private var eventMonitor: Any?

    init() {
        let s = CGFloat(Settings.shared.calendarScale)
        let w = K.W * s
        let h = CalendarViewController.baseH * s
        super.init(contentRect: NSRect(x: 0, y: 0, width: w, height: h),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true

        let size = NSSize(width: w, height: h)
        let vfx = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
        vfx.material = .popover
        vfx.blendingMode = .behindWindow
        vfx.state = .active
        vfx.wantsLayer = true
        vfx.layer?.cornerRadius = 12
        vfx.layer?.masksToBounds = true
        vfx.autoresizingMask = [.width, .height]
        contentView = vfx

        vc.view.frame = NSRect(x: 0, y: 0, width: K.W, height: CalendarViewController.baseH)
        vc.view.autoresizingMask = []
        vfx.addSubview(vc.view)

        // Observe settings changes so the panel resizes live, even when hidden.
        NotificationCenter.default.addObserver(self, selector: #selector(panelSettingsChanged),
                                               name: .settingsChanged, object: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func panelSettingsChanged() {
        applyScale()
    }

    func applyScale() {
        let s = CGFloat(Settings.shared.calendarScale)
        let newW = K.W * s
        let newH = CalendarViewController.baseH * s
        // Keep the top-left corner anchored while resizing
        let origin = NSPoint(x: frame.minX, y: frame.maxY - newH)
        setFrame(NSRect(x: origin.x, y: origin.y, width: newW, height: newH), display: true)
        vc.applyScaleTransform()
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isVisible {
            close()
        } else {
            isPinned = false
            applyScale()
            positionNear(button)
            orderFrontRegardless()
            startEventMonitor()
            vc.updatePinButton()
        }
    }

    func toggleNearView(_ sourceView: NSView) {
        if isVisible {
            close()
        } else {
            isPinned = false
            applyScale()
            positionNearView(sourceView)
            orderFrontRegardless()
            startEventMonitor()
            vc.updatePinButton()
        }
    }

    override func orderOut(_ sender: Any?) {
        stopEventMonitor()
        super.orderOut(sender)
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, !self.isPinned else { return }
            if !self.frame.contains(NSEvent.mouseLocation) {
                self.close()
            }
        }
    }

    private func stopEventMonitor() {
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
        eventMonitor = nil
    }

    private func positionNear(_ button: NSStatusBarButton) {
        guard let screen = button.window?.screen ?? NSScreen.main else { return }
        let btnFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let panelW = frame.width, panelH = frame.height
        var x = btnFrame.midX - panelW / 2
        var y = btnFrame.minY - panelH - 6
        x = max(screen.visibleFrame.minX + 4, min(x, screen.visibleFrame.maxX - panelW - 4))
        y = max(screen.visibleFrame.minY + 4, y)
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionNearView(_ sourceView: NSView) {
        guard let screen = sourceView.window?.screen ?? NSScreen.main,
              let winFrame = sourceView.window?.convertToScreen(sourceView.convert(sourceView.bounds, to: nil)) else { return }
        let panelW = frame.width, panelH = frame.height
        var x = winFrame.midX - panelW / 2
        var y = winFrame.minY - panelH - 6
        x = max(screen.visibleFrame.minX + 4, min(x, screen.visibleFrame.maxX - panelW - 4))
        y = max(screen.visibleFrame.minY + 4, y)
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Layout constants

private enum K {
    static let W: CGFloat        = 320
    static let headerH: CGFloat  = 48
    static let wkdayH: CGFloat   = 24
    static let wnColW: CGFloat   = 28   // week-number column
    static let gridW: CGFloat    = W - wnColW
    static let cellW: CGFloat    = gridW / 7
    static let cellH: CGFloat    = 34
    static let rows: Int         = 6
    static let gridH: CGFloat    = cellH * CGFloat(rows)
    static let evRowH: CGFloat   = 22
    static let toolbarH: CGFloat = 36
}

// MARK: - Day cell

private final class DayCell: NSView {
    var date: Date?
    var isCurrentMonth = true
    var isToday        = false
    var isSelected     = false
    var showDot        = false
    var dotColor: NSColor = .controlAccentColor
    var onTap: ((DayCell) -> Void)?

    private let numLabel = NSTextField(labelWithString: "")
    private let dot      = NSView()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true

        numLabel.alignment = .center
        numLabel.isBezeled = false
        numLabel.drawsBackground = false
        numLabel.isEditable = false
        numLabel.isSelectable = false
        addSubview(numLabel)

        dot.wantsLayer = true
        dot.layer?.cornerRadius = 2.5
        addSubview(dot)

        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        let cx = bounds.midX, cy = bounds.midY
        numLabel.frame = NSRect(x: 0, y: cy - 9, width: bounds.width, height: 18)
        dot.frame = NSRect(x: cx - 2.5, y: 4, width: 5, height: 5)
    }

    func refresh() {
        guard let date, isCurrentMonth || Settings.shared.calShowInactiveDays else {
            // hide overflow cells when setting is off
            numLabel.stringValue = ""
            layer?.backgroundColor = .none
            layer?.cornerRadius = 0
            dot.isHidden = true
            return
        }
        guard date != (nil as Date?) else {
            numLabel.stringValue = ""
            layer?.backgroundColor = .none
            dot.isHidden = true
            return
        }
        let day = Calendar.current.component(.day, from: date)
        numLabel.stringValue = "\(day)"
        layer?.cornerRadius = (min(bounds.width, bounds.height) - 6) / 2

        if isToday {
            layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            numLabel.font = .systemFont(ofSize: 13, weight: .bold)
            numLabel.textColor = .white
        } else if isSelected {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            numLabel.font = .systemFont(ofSize: 13, weight: .medium)
            numLabel.textColor = .labelColor
        } else {
            layer?.backgroundColor = .none
            numLabel.font = .systemFont(ofSize: 13, weight: .regular)
            numLabel.textColor = isCurrentMonth ? .labelColor : .tertiaryLabelColor
        }

        let show = showDot && Settings.shared.calShowEventDots
        dot.isHidden = !show
        if show {
            let effectiveDotColor: NSColor
            if Settings.shared.calColorfulDots {
                effectiveDotColor = isToday ? .white : dotColor
            } else {
                effectiveDotColor = isToday ? .white : .controlAccentColor
            }
            dot.layer?.backgroundColor = effectiveDotColor.cgColor
        }
    }

    @objc private func tapped() { onTap?(self) }
}

// MARK: - Year/Month picker overlay

private final class YearMonthPicker: NSView {
    var onPick: ((Int, Int) -> Void)?   // year, month (1-based)
    var onDismiss: (() -> Void)?

    private let cal       = Calendar.current
    private var pickYear  = Calendar.current.component(.year, from: Date())
    private let yearLabel = NSTextField(labelWithString: "")
    private var monthBtns: [NSButton] = []
    private let currentYear  = Calendar.current.component(.year, from: Date())
    private let currentMonth = Calendar.current.component(.month, from: Date())

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        build()
        addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(bgTapped(_:))))
    }
    required init?(coder: NSCoder) { fatalError() }

    private func build() {
        // year row
        let prevY = NSButton(title: "‹", target: self, action: #selector(prevYear))
        prevY.isBordered = false; prevY.font = .systemFont(ofSize: 18, weight: .light)
        prevY.frame = NSRect(x: 8, y: bounds.height - 44, width: 32, height: 36)
        addSubview(prevY)

        yearLabel.frame = NSRect(x: 44, y: bounds.height - 44, width: bounds.width - 88, height: 36)
        yearLabel.alignment = .center
        yearLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        addSubview(yearLabel)

        let nextY = NSButton(title: "›", target: self, action: #selector(nextYear))
        nextY.isBordered = false; nextY.font = .systemFont(ofSize: 18, weight: .light)
        nextY.frame = NSRect(x: bounds.width - 40, y: bounds.height - 44, width: 32, height: 36)
        addSubview(nextY)

        // 4 × 3 month grid
        let cols = 4, rows = 3
        let pad: CGFloat = 8
        let cellW = (bounds.width - pad * 2) / CGFloat(cols)
        let cellH: CGFloat = 36
        let gridH = cellH * CGFloat(rows)
        let gridTop = (bounds.height - 44 - gridH) / 2

        let names = L10n.isChinese
            ? ["1月","2月","3月","4月","5月","6月","7月","8月","9月","10月","11月","12月"]
            : ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]

        for m in 1...12 {
            let col = (m - 1) % cols
            let row = (m - 1) / cols
            let x = pad + CGFloat(col) * cellW
            let y = gridTop + CGFloat(rows - 1 - row) * cellH
            let btn = NSButton(title: names[m - 1], target: self, action: #selector(monthTapped(_:)))
            btn.tag = m
            btn.isBordered = false
            btn.wantsLayer = true
            btn.layer?.cornerRadius = 8
            btn.font = .systemFont(ofSize: 13)
            btn.frame = NSRect(x: x + 2, y: y + 2, width: cellW - 4, height: cellH - 4)
            addSubview(btn)
            monthBtns.append(btn)
        }

        // cancel / close row at bottom
        let closeBtn = NSButton(title: L10n.isChinese ? "取消" : "Cancel",
                                target: self, action: #selector(dismiss))
        closeBtn.isBordered = false
        closeBtn.font = .systemFont(ofSize: 13)
        closeBtn.contentTintColor = .controlAccentColor
        closeBtn.frame = NSRect(x: 0, y: 4, width: bounds.width, height: 26)
        closeBtn.alignment = .center
        addSubview(closeBtn)

        refreshYear()
    }

    private func refreshYear() {
        yearLabel.stringValue = "\(pickYear)"
        let todayYear  = currentYear
        let todayMonth = currentMonth
        for btn in monthBtns {
            let m = btn.tag
            let isThisMonth = pickYear == todayYear && m == todayMonth
            if isThisMonth {
                btn.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
                btn.contentTintColor = .white
            } else {
                btn.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.0).cgColor
                btn.contentTintColor = .labelColor
            }
        }
    }

    @objc private func prevYear()  { pickYear -= 1; refreshYear() }
    @objc private func nextYear()  { pickYear += 1; refreshYear() }
    @objc private func monthTapped(_ s: NSButton) { onPick?(pickYear, s.tag) }
    @objc private func dismiss()   { onDismiss?() }
    @objc private func bgTapped(_ r: NSClickGestureRecognizer) {
        // only dismiss if click was outside the interactive subviews
        let pt = r.location(in: self)
        let hit = subviews.first { $0 !== self && $0.frame.contains(pt) }
        if hit == nil { onDismiss?() }
    }

    func show(for year: Int) {
        pickYear = year
        refreshYear()
    }
}

// MARK: - View Controller

final class CalendarViewController: NSViewController {
    private let cal = Calendar.current
    private var display  = Date()
    private var selected: Date? = nil

    override init(nibName: NSNib.Name? = nil, bundle: Bundle? = nil) {
        super.init(nibName: nibName, bundle: bundle)
    }
    required init?(coder: NSCoder) { fatalError() }

    private var dayCells: [DayCell] = []
    private var allMonthEvents: [EKEvent] = []
    private var dotsByDay:      [Int: Int]     = [:]
    private var dotColorByDay:  [Int: NSColor] = [:]
    private let store = EKEventStore()

    // Subviews
    private let monthYearBtn = NSButton(title: "", target: nil, action: nil)
    private let evContainer  = NSView()
    private let noEvLabel    = NSTextField(labelWithString: "")
    private var picker: YearMonthPicker?
    private let pinBtn       = NSButton(title: "", target: nil, action: nil)

    private var isDark: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static let baseW: CGFloat = 320
    static let baseH: CGFloat = 400

    override func loadView() {
        let h = K.headerH + K.wkdayH + K.gridH + K.evRowH * 3 + 8 + K.toolbarH
        let v = NSView(frame: NSRect(x: 0, y: 0, width: K.W, height: h))
        v.wantsLayer = true
        view = v
        buildUI()
    }

    // NSPopover picks this up via KVO and resizes its window automatically
    override var preferredContentSize: NSSize {
        get {
            let s = CGFloat(Settings.shared.calendarScale)
            return NSSize(width: Self.baseW * s, height: Self.baseH * s)
        }
        set { super.preferredContentSize = newValue }
    }

    private var viewH: CGFloat { view.bounds.height }

    func applyScaleTransform() {
        let s = CGFloat(Settings.shared.calendarScale)
        view.layer?.anchorPoint = CGPoint(x: 0, y: 0)
        view.layer?.position    = CGPoint(x: 0, y: 0)
        view.layer?.transform   = CATransform3DMakeScale(s, s, 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Register early (once) so we receive updates even before the panel is shown.
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: .settingsChanged, object: nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        display = Date(); selected = nil
        applyScaleTransform()
        updatePinButton()
        reloadMonth(); requestAccess()
    }

    @objc private func settingsChanged() {
        let s = CGFloat(Settings.shared.calendarScale)
        preferredContentSize = NSSize(width: Self.baseW * s, height: Self.baseH * s)
        if let panel = view.window as? CalendarPanel {
            panel.applyScale()
        } else {
            applyScaleTransform()
        }
        reloadMonth()
    }

    // MARK: Build

    private func buildUI() {
        buildHeader()
        buildWeekdayRow()
        buildDayGrid()
        buildSeparator(y: K.toolbarH + K.evRowH * 3 + 8)
        buildEventsArea()
        buildToolbar()
    }

    private func buildHeader() {
        let y = viewH - K.headerH

        // Month+year label (left, tappable)
        monthYearBtn.target = self
        monthYearBtn.action = #selector(togglePicker)
        monthYearBtn.isBordered = false
        monthYearBtn.alignment = .left
        monthYearBtn.font = .systemFont(ofSize: 18, weight: .bold)
        monthYearBtn.frame = NSRect(x: 12, y: y + 10, width: 200, height: 28)
        view.addSubview(monthYearBtn)

        // Right nav: ‹ • ›  (SF Symbols for equal optical size)
        let symCfg = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)

        let prevBtn = NSButton(title: "", target: self, action: #selector(goPrev))
        prevBtn.isBordered = false
        prevBtn.image = NSImage(systemSymbolName: "chevron.left",
                                accessibilityDescription: nil)?.withSymbolConfiguration(symCfg)
        prevBtn.contentTintColor = .secondaryLabelColor
        prevBtn.frame = NSRect(x: K.W - 72, y: y + 13, width: 22, height: 22)
        view.addSubview(prevBtn)

        let dotBtn = NSButton(title: "●", target: self, action: #selector(goToday))
        dotBtn.isBordered = false
        dotBtn.font = .systemFont(ofSize: 9)
        dotBtn.contentTintColor = .controlAccentColor
        dotBtn.frame = NSRect(x: K.W - 46, y: y + 13, width: 22, height: 22)
        view.addSubview(dotBtn)

        let nextBtn = NSButton(title: "", target: self, action: #selector(goNext))
        nextBtn.isBordered = false
        nextBtn.image = NSImage(systemSymbolName: "chevron.right",
                                accessibilityDescription: nil)?.withSymbolConfiguration(symCfg)
        nextBtn.contentTintColor = .secondaryLabelColor
        nextBtn.frame = NSRect(x: K.W - 24, y: y + 13, width: 22, height: 22)
        view.addSubview(nextBtn)

        buildSeparator(y: viewH - K.headerH - 1)
    }

    private func buildWeekdayRow() {
        let y = viewH - K.headerH - K.wkdayH
        // Week-number column header
        let wnHdr = NSTextField(labelWithString: "#")
        wnHdr.tag = 199
        wnHdr.frame = NSRect(x: 0, y: y, width: K.wnColW, height: K.wkdayH)
        wnHdr.alignment = .center
        wnHdr.font = .systemFont(ofSize: 9, weight: .medium)
        wnHdr.textColor = .tertiaryLabelColor
        view.addSubview(wnHdr)

        for (i, lbl) in L10n.calWeekdaysSingle.enumerated() {
            let tf = NSTextField(labelWithString: lbl)
            tf.frame = NSRect(x: K.wnColW + CGFloat(i) * K.cellW, y: y, width: K.cellW, height: K.wkdayH)
            tf.alignment = .center
            tf.font = .systemFont(ofSize: 10, weight: .medium)
            tf.textColor = .secondaryLabelColor
            view.addSubview(tf)
        }
    }

    private func buildDayGrid() {
        let gridTop = viewH - K.headerH - K.wkdayH - K.gridH
        for row in 0..<K.rows {
            // Week number label
            let wnLabel = NSTextField(labelWithString: "")
            wnLabel.tag = 200 + row
            wnLabel.frame = NSRect(x: 0, y: gridTop + CGFloat(K.rows - 1 - row) * K.cellH,
                                   width: K.wnColW, height: K.cellH)
            wnLabel.alignment = .center
            wnLabel.font = .systemFont(ofSize: 9)
            wnLabel.textColor = .tertiaryLabelColor
            view.addSubview(wnLabel)

            for col in 0..<7 {
                let cell = DayCell(frame: NSRect(
                    x: K.wnColW + CGFloat(col) * K.cellW + 1,
                    y: gridTop + CGFloat(K.rows - 1 - row) * K.cellH + 1,
                    width: K.cellW - 2, height: K.cellH - 2))
                cell.onTap = { [weak self] c in self?.cellTapped(c) }
                view.addSubview(cell)
                dayCells.append(cell)
            }
        }
    }

    private func buildEventsArea() {
        let evH = K.evRowH * 3 + 8
        evContainer.frame = NSRect(x: 0, y: K.toolbarH, width: K.W, height: evH)
        view.addSubview(evContainer)

        noEvLabel.frame = NSRect(x: 12, y: (evH - 16) / 2, width: K.W - 24, height: 16)
        noEvLabel.font = .systemFont(ofSize: 11)
        noEvLabel.textColor = .tertiaryLabelColor
        noEvLabel.alignment = .center
        evContainer.addSubview(noEvLabel)
    }

    private func buildToolbar() {
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: K.W, height: K.toolbarH))
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.addSubview(bar)
        buildSeparator(y: K.toolbarH)

        let symCfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)

        // Pin button — bottom-right
        pinBtn.target = self
        pinBtn.action = #selector(togglePin)
        pinBtn.isBordered = false
        pinBtn.image = NSImage(systemSymbolName: "pin",
                               accessibilityDescription: nil)?.withSymbolConfiguration(symCfg)
        pinBtn.contentTintColor = .secondaryLabelColor
        pinBtn.frame = NSRect(x: K.W - 34, y: (K.toolbarH - 22) / 2, width: 26, height: 22)
        bar.addSubview(pinBtn)
    }

    @objc private func togglePin() {
        guard let panel = view.window as? CalendarPanel else { return }
        panel.isPinned.toggle()
        updatePinButton()
    }

    func updatePinButton() {
        let panel = view.window as? CalendarPanel
        let pinned = panel?.isPinned ?? false
        let symCfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        let name = pinned ? "pin.fill" : "pin"
        pinBtn.image = NSImage(systemSymbolName: name,
                               accessibilityDescription: nil)?.withSymbolConfiguration(symCfg)
        pinBtn.contentTintColor = pinned ? .controlAccentColor : .secondaryLabelColor
    }

    @objc private func closePanel() {
        view.window?.orderOut(nil)
    }

    private func buildSeparator(y: CGFloat) {
        let sep = NSView(frame: NSRect(x: 0, y: y, width: K.W, height: 0.5))
        sep.wantsLayer = true
        sep.layer?.backgroundColor = NSColor.separatorColor.cgColor
        view.addSubview(sep)
    }

    // MARK: Reload

    private func reloadMonth() {
        let fmt = DateFormatter()
        fmt.dateFormat = L10n.isChinese ? "M月 yyyy" : "MMMM yyyy"
        monthYearBtn.title = fmt.string(from: display)

        let comps = cal.dateComponents([.year, .month], from: display)
        let first  = cal.date(from: comps)!
        let wdFirst = cal.component(.weekday, from: first) - 1
        let daysInMonth = cal.range(of: .day, in: .month, for: display)!.count
        let prev = cal.date(byAdding: .month, value: -1, to: display)!
        let daysInPrev = cal.range(of: .day, in: .month, for: prev)!.count
        let next = cal.date(byAdding: .month, value:  1, to: display)!
        let todayComps = cal.dateComponents([.year, .month, .day], from: Date())
        let isCurMonth = comps.year == todayComps.year && comps.month == todayComps.month

        let showWN = Settings.shared.calShowWeekNumbers

        for (i, cell) in dayCells.enumerated() {
            let offset = i - wdFirst + 1
            let (day, isCur, monthOffset): (Int, Bool, Int)
            if offset < 1 {
                day = daysInPrev + offset; isCur = false; monthOffset = -1
            } else if offset > daysInMonth {
                day = offset - daysInMonth; isCur = false; monthOffset = 1
            } else {
                day = offset; isCur = true; monthOffset = 0
            }

            var dc = monthOffset == 0 ? comps :
                cal.dateComponents([.year,.month], from: monthOffset == -1 ? prev : next)
            dc.day = day
            cell.date = cal.date(from: dc)
            cell.isCurrentMonth = isCur
            cell.isToday = isCurMonth && isCur && day == todayComps.day
            cell.isSelected = selected.map { cal.isDate($0, inSameDayAs: cell.date ?? .distantPast) } ?? false
            cell.showDot = isCur && (dotsByDay[day] ?? 0) > 0
            cell.dotColor = dotColorByDay[day] ?? .controlAccentColor
            cell.refresh()
        }

        // Week numbers — show or clear
        for row in 0..<K.rows {
            if let wnLabel = view.viewWithTag(200 + row) as? NSTextField {
                if showWN, let d = dayCells[row * 7].date {
                    wnLabel.stringValue = "\(cal.component(.weekOfYear, from: d))"
                } else {
                    wnLabel.stringValue = ""
                }
            }
        }
        // Header "#" label (tag 199)
        if let hdr = view.viewWithTag(199) as? NSTextField {
            hdr.stringValue = showWN ? "#" : ""
        }

        reloadEvents()
    }

    private func reloadEvents() {
        evContainer.subviews.forEach { $0.removeFromSuperview() }
        evContainer.addSubview(noEvLabel)

        let target: Date
        if let s = selected { target = s }
        else if isViewingCurrentMonth { target = Date() }
        else { target = cal.date(from: cal.dateComponents([.year,.month], from: display))! }

        let dayStart = cal.startOfDay(for: target)
        let dayEnd   = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let events   = allMonthEvents
            .filter { $0.startDate < dayEnd && ($0.endDate ?? $0.startDate) > dayStart }
            .sorted { $0.isAllDay && !$1.isAllDay || $0.startDate < $1.startDate }

        let evH = evContainer.bounds.height
        if events.isEmpty {
            let fmt = DateFormatter(); fmt.dateStyle = .medium; fmt.timeStyle = .none
            noEvLabel.stringValue = L10n.isChinese
                ? "\(fmt.string(from: target)) 无日程"
                : "No events on \(fmt.string(from: target))"
            noEvLabel.frame = NSRect(x: 12, y: (evH - 16) / 2, width: K.W - 24, height: 16)
            return
        }

        noEvLabel.stringValue = ""
        let showLoc = Settings.shared.calShowEventLocation
        let useColors = Settings.shared.calColorfulDots
        // When showing location, each event takes 2 lines (rowH*2); cap accordingly
        let effectiveRowH: CGFloat = showLoc ? K.evRowH * 2 : K.evRowH
        let maxItems = max(1, Int(evH / effectiveRowH))

        for (idx, ev) in events.prefix(maxItems).enumerated() {
            let y = evH - CGFloat(idx + 1) * effectiveRowH
            let row = NSView(frame: NSRect(x: 0, y: y, width: K.W, height: effectiveRowH))

            let calColor = ev.calendar?.color ?? NSColor.controlAccentColor
            let dotColor = useColors ? calColor : NSColor.controlAccentColor

            let dot = NSView(frame: NSRect(x: 10, y: (effectiveRowH - 8) / 2, width: 8, height: 8))
            dot.wantsLayer = true
            dot.layer?.backgroundColor = dotColor.cgColor
            dot.layer?.cornerRadius = 4
            row.addSubview(dot)

            let timeStr = ev.isAllDay ? (L10n.isChinese ? "全天" : "all-day") : {
                let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: ev.startDate)
            }()
            let timeLbl = NSTextField(labelWithString: timeStr)
            timeLbl.frame = NSRect(x: 22, y: showLoc ? effectiveRowH / 2 + 1 : (effectiveRowH - 13) / 2,
                                   width: 44, height: 13)
            timeLbl.font = .monospacedDigitSystemFont(ofSize: 10, weight: .regular)
            timeLbl.textColor = .secondaryLabelColor
            row.addSubview(timeLbl)

            let titleLbl = NSTextField(labelWithString: ev.title ?? "")
            titleLbl.frame = NSRect(x: 70, y: showLoc ? effectiveRowH / 2 + 1 : (effectiveRowH - 13) / 2,
                                    width: K.W - 78, height: 13)
            titleLbl.font = .systemFont(ofSize: 11)
            titleLbl.textColor = .labelColor
            titleLbl.lineBreakMode = .byTruncatingTail
            row.addSubview(titleLbl)

            if showLoc, let loc = ev.location, !loc.isEmpty {
                let locLbl = NSTextField(labelWithString: loc)
                locLbl.frame = NSRect(x: 70, y: 3, width: K.W - 78, height: 12)
                locLbl.font = .systemFont(ofSize: 10)
                locLbl.textColor = .secondaryLabelColor
                locLbl.lineBreakMode = .byTruncatingTail
                row.addSubview(locLbl)
            }

            evContainer.addSubview(row)
        }
    }

    private var isViewingCurrentMonth: Bool {
        let d = cal.dateComponents([.year,.month], from: display)
        let t = cal.dateComponents([.year,.month], from: Date())
        return d.year == t.year && d.month == t.month
    }

    // MARK: Picker

    @objc private func togglePicker() {
        if let p = picker {
            p.removeFromSuperview(); picker = nil; return
        }
        let pickerH = viewH - K.headerH
        let p = YearMonthPicker(frame: NSRect(x: 0, y: 0, width: K.W, height: pickerH))
        p.show(for: cal.component(.year, from: display))
        p.onPick = { [weak self] year, month in
            guard let self else { return }
            var dc = DateComponents(); dc.year = year; dc.month = month; dc.day = 1
            self.display = self.cal.date(from: dc) ?? self.display
            self.selected = nil
            self.dotsByDay = [:]; self.allMonthEvents = []
            self.picker?.removeFromSuperview(); self.picker = nil
            self.reloadMonth(); self.loadEvents()
        }
        p.onDismiss = { [weak self] in
            self?.picker?.removeFromSuperview(); self?.picker = nil
        }
        view.addSubview(p)
        picker = p
    }

    // MARK: EventKit

    private func requestAccess() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess: loadEvents()
        case .notDetermined:
            if #available(macOS 14.0, *) {
                store.requestFullAccessToEvents { [weak self] ok, _ in
                    if ok { DispatchQueue.main.async { self?.loadEvents() } }
                }
            } else {
                store.requestAccess(to: .event) { [weak self] ok, _ in
                    if ok { DispatchQueue.main.async { self?.loadEvents() } }
                }
            }
        default: break
        }
    }

    private func loadEvents() {
        guard let start = cal.date(from: cal.dateComponents([.year,.month], from: display)),
              let end   = cal.date(byAdding: .month, value: 1, to: start) else { return }
        let evs = store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: nil))
        var dots:   [Int: Int]     = [:]
        var colors: [Int: NSColor] = [:]
        for e in evs {
            let d = cal.component(.day, from: e.startDate)
            dots[d, default: 0] += 1
            // keep the first (earliest) calendar color per day
            if colors[d] == nil { colors[d] = e.calendar?.color }
        }
        DispatchQueue.main.async { [weak self] in
            self?.dotsByDay     = dots
            self?.dotColorByDay = colors.compactMapValues { $0 }
            self?.allMonthEvents = evs
            self?.reloadMonth()
        }
    }

    // MARK: Actions

    @objc private func goPrev() {
        display = cal.date(byAdding: .month, value: -1, to: display) ?? display
        dotsByDay = [:]; allMonthEvents = []; reloadMonth(); loadEvents()
    }
    @objc private func goNext() {
        display = cal.date(byAdding: .month, value:  1, to: display) ?? display
        dotsByDay = [:]; allMonthEvents = []; reloadMonth(); loadEvents()
    }
    @objc private func goToday() {
        display = Date(); selected = nil
        dotsByDay = [:]; allMonthEvents = []; reloadMonth(); loadEvents()
    }

    private func cellTapped(_ cell: DayCell) {
        guard let d = cell.date else { return }
        selected = (selected.map { cal.isDate($0, inSameDayAs: d) } ?? false) ? nil : d
        // Navigate to that month if it's an overflow day
        let dc = cal.dateComponents([.year,.month], from: d)
        let curDc = cal.dateComponents([.year,.month], from: display)
        if dc.year != curDc.year || dc.month != curDc.month {
            display = cal.date(from: dc)!
            dotsByDay = [:]; allMonthEvents = []; loadEvents()
        }
        reloadMonth()
    }
}
