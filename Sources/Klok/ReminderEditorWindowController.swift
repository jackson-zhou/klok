import AppKit

typealias ReminderEditCallback = (Reminder?) -> Void

final class ReminderEditorWindowController: NSWindowController {
    private let original: Reminder?
    private let callback: ReminderEditCallback

    private let nameField  = NSTextField(string: "")
    private let typePopup  = NSPopUpButton()
    private let datePicker = NSDatePicker()   // .once
    private let timePicker = NSDatePicker()

    // Weekly controls
    private var weekdayBoxes: [NSButton] = []

    // Monthly controls
    private let monthDayField   = NSTextField(string: "1")
    private let monthDayStepper = NSStepper()

    // Yearly controls
    private let yearMonthField   = NSTextField(string: "1")
    private let yearMonthStepper = NSStepper()
    private let yearDayField     = NSTextField(string: "1")
    private let yearDayStepper   = NSStepper()

    // Minutely controls
    private let intervalField   = NSTextField(string: "1")
    private let intervalStepper = NSStepper()

    // Containers for easy show/hide
    private let detailOnce     = NSView()
    private let detailWeekly   = NSView()
    private let detailMonthly  = NSView()
    private let detailYearly   = NSView()
    private let detailMinutely = NSView()

    private let showWinBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let msgField   = NSTextField(string: "")
    private let enabledBox = NSButton(checkboxWithTitle: "", target: nil, action: nil)

    init(editing reminder: Reminder? = nil, callback: @escaping ReminderEditCallback) {
        self.original = reminder
        self.callback = callback
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.reminderEditorTitle
        super.init(window: win)
        win.center()
        buildUI()
        populate(reminder)
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(relativeTo parent: NSWindow?) {
        if let p = parent { p.beginSheet(window!) { _ in } } else { showWindow(nil) }
    }

    // MARK: - UI construction

    private func buildUI() {
        guard let v = window?.contentView else { return }

        func lbl(_ s: String, x: CGFloat, y: CGFloat, w: CGFloat = 72) -> NSTextField {
            let f = NSTextField(labelWithString: s)
            f.alignment = .right
            f.frame = NSRect(x: x, y: y, width: w, height: 22)
            return f
        }
        func stepper(min: Double, max: Double, val: Double) -> NSStepper {
            let s = NSStepper()
            s.minValue = min; s.maxValue = max; s.valueWraps = false
            s.doubleValue = val
            s.frame = NSRect(x: 0, y: 0, width: 19, height: 22)
            return s
        }

        // ── Name ──
        v.addSubview(lbl(L10n.reminderName, x: 12, y: 348))
        nameField.frame = NSRect(x: 90, y: 348, width: 290, height: 22)
        v.addSubview(nameField)

        // ── Type ──
        v.addSubview(lbl(L10n.reminderType, x: 12, y: 316))
        typePopup.addItems(withTitles: [L10n.repeatOnce, L10n.repeatDaily, L10n.repeatWeekly,
                                        L10n.repeatMonthly, L10n.repeatYearly, L10n.repeatMinutely])
        typePopup.frame = NSRect(x: 90, y: 316, width: 140, height: 22)
        typePopup.target = self; typePopup.action = #selector(typeChanged)
        v.addSubview(typePopup)

        // ── Detail panels (all at y=282) ──
        let detailY: CGFloat = 282
        let detailH: CGFloat = 26
        for panel in [detailOnce, detailWeekly, detailMonthly, detailYearly, detailMinutely] {
            panel.frame = NSRect(x: 0, y: detailY, width: 400, height: detailH)
            panel.isHidden = true
            v.addSubview(panel)
        }
        v.addSubview(lbl(L10n.reminderDate, x: 12, y: 2, w: 72))

        // Once: date picker
        detailOnce.addSubview(lbl(L10n.reminderDate, x: 12, y: 2))
        datePicker.datePickerStyle = .textFieldAndStepper
        datePicker.datePickerElements = .yearMonthDay
        datePicker.dateValue = Date()
        datePicker.frame = NSRect(x: 90, y: 2, width: 190, height: 22)
        detailOnce.addSubview(datePicker)

        // Weekly: 7 day-checkboxes
        let days = L10n.calWeekdays  // ["日","一","二","三","四","五","六"]
        detailWeekly.addSubview(lbl(L10n.reminderWeekOn, x: 12, y: 2))
        for (i, title) in days.enumerated() {
            let btn = NSButton(checkboxWithTitle: title, target: nil, action: nil)
            btn.frame = NSRect(x: 90 + CGFloat(i) * 44, y: 2, width: 42, height: 22)
            detailWeekly.addSubview(btn)
            weekdayBoxes.append(btn)
        }

        // Monthly: day stepper
        detailMonthly.addSubview(lbl(L10n.reminderMonthDay, x: 12, y: 2))
        monthDayField.frame = NSRect(x: 90, y: 2, width: 44, height: 22)
        monthDayField.isEditable = true; monthDayField.isBordered = true
        monthDayStepper.minValue = 1; monthDayStepper.maxValue = 31
        monthDayStepper.valueWraps = false; monthDayStepper.doubleValue = 1
        monthDayStepper.frame = NSRect(x: 136, y: 2, width: 19, height: 22)
        monthDayStepper.target = self; monthDayStepper.action = #selector(monthDayStepperChanged)
        detailMonthly.addSubview(monthDayField)
        detailMonthly.addSubview(monthDayStepper)
        // Yearly: month + day steppers
        detailYearly.addSubview(lbl(L10n.reminderYearMonth, x: 12, y: 2, w: 44))
        yearMonthField.frame = NSRect(x: 58, y: 2, width: 40, height: 22)
        yearMonthField.isEditable = true; yearMonthField.isBordered = true
        yearMonthStepper.minValue = 1; yearMonthStepper.maxValue = 12
        yearMonthStepper.valueWraps = false; yearMonthStepper.doubleValue = 1
        yearMonthStepper.frame = NSRect(x: 100, y: 2, width: 19, height: 22)
        yearMonthStepper.target = self; yearMonthStepper.action = #selector(yearMonthStepperChanged)
        detailYearly.addSubview(yearMonthField)
        detailYearly.addSubview(yearMonthStepper)

        detailYearly.addSubview(lbl(L10n.reminderYearDay, x: 128, y: 2, w: 36))
        yearDayField.frame = NSRect(x: 166, y: 2, width: 40, height: 22)
        yearDayField.isEditable = true; yearDayField.isBordered = true
        yearDayStepper.minValue = 1; yearDayStepper.maxValue = 31
        yearDayStepper.valueWraps = false; yearDayStepper.doubleValue = 1
        yearDayStepper.frame = NSRect(x: 208, y: 2, width: 19, height: 22)
        yearDayStepper.target = self; yearDayStepper.action = #selector(yearDayStepperChanged)
        detailYearly.addSubview(yearDayField)
        detailYearly.addSubview(yearDayStepper)

        // Minutely: interval stepper
        detailMinutely.addSubview(lbl(L10n.reminderInterval, x: 12, y: 2))
        intervalField.frame = NSRect(x: 90, y: 2, width: 44, height: 22)
        intervalField.isEditable = true; intervalField.isBordered = true
        intervalStepper.minValue = 1; intervalStepper.maxValue = 60
        intervalStepper.valueWraps = false; intervalStepper.doubleValue = 1
        intervalStepper.frame = NSRect(x: 136, y: 2, width: 19, height: 22)
        intervalStepper.target = self; intervalStepper.action = #selector(intervalStepperChanged)
        detailMinutely.addSubview(intervalField)
        detailMinutely.addSubview(intervalStepper)
        let minsLbl = NSTextField(labelWithString: L10n.reminderMinutes)
        minsLbl.frame = NSRect(x: 160, y: 2, width: 60, height: 22)
        detailMinutely.addSubview(minsLbl)

        // ── Time ──
        v.addSubview(lbl(L10n.reminderTime, x: 12, y: 250))
        timePicker.datePickerStyle = .textFieldAndStepper
        timePicker.datePickerElements = .hourMinuteSecond
        timePicker.dateValue = Date()
        timePicker.frame = NSRect(x: 90, y: 250, width: 160, height: 22)
        v.addSubview(timePicker)

        // ── Show window ──
        showWinBox.title = L10n.reminderShowWin
        showWinBox.state = .on
        showWinBox.frame = NSRect(x: 90, y: 218, width: 260, height: 22)
        v.addSubview(showWinBox)

        // ── Message ──
        v.addSubview(lbl(L10n.reminderMessage, x: 12, y: 178))
        msgField.frame = NSRect(x: 90, y: 118, width: 290, height: 56)
        msgField.cell?.wraps = true; msgField.cell?.isScrollable = false
        v.addSubview(msgField)

        // ── Enabled ──
        enabledBox.title = isChinese ? "启用" : "Enabled"
        enabledBox.state = .on
        enabledBox.frame = NSRect(x: 90, y: 85, width: 100, height: 22)
        v.addSubview(enabledBox)

        // ── Buttons ──
        let ok = NSButton(title: L10n.btnOK, target: self, action: #selector(save))
        ok.frame = NSRect(x: 302, y: 18, width: 78, height: 28)
        ok.keyEquivalent = "\r"
        v.addSubview(ok)

        let cancel = NSButton(title: L10n.btnCancel, target: self, action: #selector(cancel))
        cancel.frame = NSRect(x: 216, y: 18, width: 78, height: 28)
        cancel.keyEquivalent = "\u{1b}"
        v.addSubview(cancel)
    }

    private var isChinese: Bool { Settings.shared.language == "zh" }

    // MARK: - Populate from existing reminder

    private func populate(_ r: Reminder?) {
        guard let r = r else { updateDetailPanel(); return }
        nameField.stringValue = r.name
        let idx = [ReminderRepeat.once, .daily, .weekly, .monthly, .yearly, .minutely]
            .firstIndex(of: r.repeatType) ?? 1
        typePopup.selectItem(at: idx)

        if let d = r.date { datePicker.dateValue = d }

        // Weekdays: Calendar weekday 1=Sun (index 0) … 7=Sat (index 6)
        for (i, btn) in weekdayBoxes.enumerated() {
            btn.state = r.weekdays.contains(i + 1) ? .on : .off
        }

        monthDayField.stringValue = "\(r.monthDay)"
        monthDayStepper.doubleValue = Double(r.monthDay)

        yearMonthField.stringValue = "\(r.yearMonth)"
        yearMonthStepper.doubleValue = Double(r.yearMonth)
        yearDayField.stringValue = "\(r.yearDay)"
        yearDayStepper.doubleValue = Double(r.yearDay)

        intervalField.stringValue = "\(max(1, r.minuteInterval))"
        intervalStepper.doubleValue = Double(max(1, r.minuteInterval))

        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = r.hour; comps.minute = r.minute; comps.second = r.second
        if let t = cal.date(from: comps) { timePicker.dateValue = t }

        showWinBox.state = r.showWindow ? .on : .off
        msgField.stringValue = r.message
        enabledBox.state = r.enabled ? .on : .off
        updateDetailPanel()
    }

    @objc private func typeChanged() { updateDetailPanel() }

    private func updateDetailPanel() {
        let type: ReminderRepeat = [.once, .daily, .weekly, .monthly, .yearly, .minutely][typePopup.indexOfSelectedItem]
        detailOnce.isHidden     = type != .once
        detailWeekly.isHidden   = type != .weekly
        detailMonthly.isHidden  = type != .monthly
        detailYearly.isHidden   = type != .yearly
        detailMinutely.isHidden = type != .minutely
        // Hide detail area entirely for .daily
    }

    // MARK: - Stepper actions

    @objc private func monthDayStepperChanged() {
        let v = Int(monthDayStepper.doubleValue)
        monthDayField.stringValue = "\(v)"
    }
    @objc private func yearMonthStepperChanged() {
        let v = Int(yearMonthStepper.doubleValue)
        yearMonthField.stringValue = "\(v)"
    }
    @objc private func yearDayStepperChanged() {
        let v = Int(yearDayStepper.doubleValue)
        yearDayField.stringValue = "\(v)"
    }
    @objc private func intervalStepperChanged() {
        let v = Int(intervalStepper.doubleValue)
        intervalField.stringValue = "\(v)"
    }

    // MARK: - Save / Cancel

    @objc private func save() {
        let cal = Calendar.current
        let t = timePicker.dateValue
        let h = cal.component(.hour,   from: t)
        let m = cal.component(.minute, from: t)
        let s = cal.component(.second, from: t)
        let repeatType: ReminderRepeat = [.once, .daily, .weekly, .monthly, .yearly, .minutely][typePopup.indexOfSelectedItem]

        var r = original ?? Reminder(name: "", hour: h, minute: m)
        r.name       = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        r.hour = h; r.minute = m; r.second = s
        r.repeatType = repeatType
        r.date       = repeatType == .once ? datePicker.dateValue : nil

        // Weekdays: collect checked boxes; Calendar weekday 1=Sun … 7=Sat
        r.weekdays = weekdayBoxes.enumerated()
            .compactMap { $0.element.state == .on ? $0.offset + 1 : nil }

        r.monthDay = max(1, min(31, Int(monthDayField.stringValue) ?? Int(monthDayStepper.doubleValue)))
        r.yearMonth = max(1, min(12, Int(yearMonthField.stringValue) ?? Int(yearMonthStepper.doubleValue)))
        r.yearDay   = max(1, min(31, Int(yearDayField.stringValue) ?? Int(yearDayStepper.doubleValue)))
        r.minuteInterval = max(1, min(60, Int(intervalField.stringValue) ?? Int(intervalStepper.doubleValue)))

        r.showWindow = showWinBox.state == .on
        r.message    = msgField.stringValue
        r.enabled    = enabledBox.state == .on

        dismiss(); callback(r)
    }

    @objc private func cancel() { dismiss(); callback(nil) }

    private func dismiss() {
        if let sheet = window, let parent = sheet.sheetParent {
            parent.endSheet(sheet)
        } else {
            close()
        }
    }
}
