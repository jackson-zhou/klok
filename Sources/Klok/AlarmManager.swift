import AppKit
import UserNotifications

final class AlarmManager {
    static let shared = AlarmManager()
    private var timer: Timer?
    private var firedOnceIDs: Set<UUID> = []
    // Prevents double-fire from timer jitter: skip if fired within last 30 s
    private var lastFiredAt: [UUID: Date] = [:]

    func start() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.checkReminders()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func guardFire(_ reminder: Reminder, minInterval: TimeInterval = 30) -> Bool {
        if let last = lastFiredAt[reminder.id], Date().timeIntervalSince(last) < minInterval {
            return false
        }
        lastFiredAt[reminder.id] = Date()
        return true
    }

    private func checkReminders() {
        let cal = Calendar.current
        let now = Date()
        let h   = cal.component(.hour,   from: now)
        let m   = cal.component(.minute, from: now)
        let s   = cal.component(.second, from: now)
        let wd  = cal.component(.weekday, from: now)  // 1=Sun…7=Sat
        let dom = cal.component(.day,    from: now)
        let mo  = cal.component(.month,  from: now)

        for reminder in Settings.shared.alarms where reminder.enabled {
            switch reminder.repeatType {

            case .minutely:
                let interval = max(1, reminder.minuteInterval)
                guard m % interval == 0, s == reminder.second else { continue }
                guard guardFire(reminder, minInterval: Double(interval) * 60 - 5) else { continue }
                fire(reminder)

            case .daily:
                guard reminder.hour == h, reminder.minute == m, reminder.second == s else { continue }
                guard guardFire(reminder) else { continue }
                fire(reminder)

            case .weekly:
                guard reminder.hour == h, reminder.minute == m, reminder.second == s else { continue }
                let days = reminder.weekdays
                guard days.isEmpty || days.contains(wd) else { continue }
                guard guardFire(reminder) else { continue }
                fire(reminder)

            case .monthly:
                guard reminder.hour == h, reminder.minute == m, reminder.second == s else { continue }
                guard reminder.monthDay == dom else { continue }
                guard guardFire(reminder) else { continue }
                fire(reminder)

            case .yearly:
                guard reminder.hour == h, reminder.minute == m, reminder.second == s else { continue }
                guard reminder.yearMonth == mo, reminder.yearDay == dom else { continue }
                guard guardFire(reminder) else { continue }
                fire(reminder)

            case .once:
                guard !firedOnceIDs.contains(reminder.id) else { continue }
                guard reminder.hour == h, reminder.minute == m, reminder.second == s else { continue }
                if let d = reminder.date {
                    guard cal.isDate(d, inSameDayAs: now) else { continue }
                }
                firedOnceIDs.insert(reminder.id)
                fire(reminder)
                var updated = Settings.shared.alarms
                if let idx = updated.firstIndex(where: { $0.id == reminder.id }) {
                    updated[idx].enabled = false
                    Settings.shared.alarms = updated
                }
            }
        }
    }

    func fire(_ reminder: Reminder) {
        if reminder.showWindow {
            DispatchQueue.main.async {
                guard !ReminderPopupController.isActive(for: reminder.id) else { return }
                ReminderPopupController(reminder: reminder).show()
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = L10n.alarmTitle
            content.body = reminder.message.isEmpty ? reminder.name : reminder.message
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req, withCompletionHandler: nil)
        }
    }
}

// MARK: - Reminder popup window

final class ReminderPopupController: NSWindowController, NSWindowDelegate {
    private let reminder: Reminder
    // Keeps popups alive until they are dismissed
    private static var active: [ReminderPopupController] = []

    static func isActive(for id: UUID) -> Bool {
        active.contains { $0.reminder.id == id }
    }

    init(reminder: Reminder) {
        self.reminder = reminder
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = L10n.alarmTitle
        win.level = .floating
        super.init(window: win)
        win.delegate = self
        win.center()
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        ReminderPopupController.active.append(self)
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let nameLabel = NSTextField(labelWithString: reminder.name)
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.frame = NSRect(x: 20, y: 110, width: 280, height: 20)
        content.addSubview(nameLabel)

        let msgLabel = NSTextField(wrappingLabelWithString: reminder.message)
        msgLabel.frame = NSRect(x: 20, y: 55, width: 280, height: 50)
        msgLabel.textColor = .secondaryLabelColor
        content.addSubview(msgLabel)

        let btn = NSButton(title: L10n.reminderDismiss, target: self, action: #selector(dismiss))
        btn.frame = NSRect(x: 220, y: 15, width: 80, height: 28)
        btn.keyEquivalent = "\r"
        content.addSubview(btn)
    }

    @objc private func dismiss() { window?.close() }

    func windowWillClose(_ notification: Notification) {
        ReminderPopupController.active.removeAll { $0 === self }
    }
}
