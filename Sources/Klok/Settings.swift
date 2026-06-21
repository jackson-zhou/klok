import Foundation

enum ReminderRepeat: String, Codable {
    case once    // 一次
    case daily   // 每天
    case weekly  // 每周
    case monthly // 每月
    case yearly  // 每年
    case minutely // 每分钟
}

struct Reminder: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var hour: Int
    var minute: Int
    var second: Int = 0
    var repeatType: ReminderRepeat = .daily
    // .once: specific date
    var date: Date?
    // .weekly: Calendar weekday values 1=Sun…7=Sat (empty = every day, legacy)
    var weekdays: [Int] = []
    // .monthly: day of month 1–31
    var monthDay: Int = 1
    // .yearly: month 1–12 and day 1–31
    var yearMonth: Int = 1
    var yearDay: Int = 1
    // .minutely: fire every N minutes
    var minuteInterval: Int = 1
    var showWindow: Bool = true
    var message: String = ""
    var enabled: Bool = true

    var timeString: String {
        String(format: "%02d:%02d:%02d", hour, minute, second)
    }

    var dateString: String {
        guard repeatType == .once, let d = date else {
            switch repeatType {
            case .daily:    return L10n.repeatDaily
            case .weekly:   return L10n.repeatWeekly
            case .monthly:  return L10n.repeatMonthly
            case .yearly:   return L10n.repeatYearly
            case .minutely: return L10n.repeatMinutely
            default:        return ""
            }
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy/M/d"
        return df.string(from: d)
    }
}

final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    var skinID: String {
        get { defaults.string(forKey: "skinID") ?? "classic" }
        set { defaults.set(newValue, forKey: "skinID"); notify() }
    }

    var currentSkin: Skin {
        Skin.all.first { $0.id == skinID } ?? .classic
    }

    var clockSize: Double {
        get { defaults.object(forKey: "clockSize") as? Double ?? 200 }
        set { defaults.set(newValue, forKey: "clockSize"); notify() }
    }

    var opacity: Double {
        get { defaults.object(forKey: "opacity") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "opacity"); notify() }
    }

    var alwaysOnTop: Bool {
        get { defaults.bool(forKey: "alwaysOnTop") }
        set { defaults.set(newValue, forKey: "alwaysOnTop"); notify() }
    }

    var pinToDesktop: Bool {
        get { defaults.bool(forKey: "pinToDesktop") }
        set { defaults.set(newValue, forKey: "pinToDesktop"); notify() }
    }

    // Clock window sits at desktop level (behind all app windows, above wallpaper)
    var embedInDesktop: Bool {
        get { defaults.bool(forKey: "embedInDesktop") }
        set { defaults.set(newValue, forKey: "embedInDesktop"); notify() }
    }

    // Window is transparent to mouse clicks (passes events to whatever is below)
    var clickThrough: Bool {
        get { defaults.bool(forKey: "clickThrough") }
        set { defaults.set(newValue, forKey: "clickThrough"); notify() }
    }

    // Clock fades to nearly invisible when the cursor is over it
    var hoverTransparent: Bool {
        get { defaults.bool(forKey: "hoverTransparent") }
        set { defaults.set(newValue, forKey: "hoverTransparent"); notify() }
    }

    // Alpha value applied when hoverTransparent is active (0.0–1.0, default 0.15)
    var hoverOpacity: Double {
        get { defaults.object(forKey: "hoverOpacity") as? Double ?? 0.15 }
        set { defaults.set(newValue, forKey: "hoverOpacity"); notify() }
    }

    var showSecondHand: Bool {
        get { defaults.object(forKey: "showSecondHand") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showSecondHand"); notify() }
    }

    var secondHandJump: Bool {
        get { defaults.object(forKey: "secondHandJump") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "secondHandJump"); notify() }
    }

    var showAmPm: Bool {
        get { defaults.object(forKey: "showAmPm") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showAmPm"); notify() }
    }

    var showDate: Bool {
        get { defaults.object(forKey: "showDate") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "showDate"); notify() }
    }

    var alarms: [Reminder] {
        get {
            guard let data = defaults.data(forKey: "alarms"),
                  let decoded = try? JSONDecoder().decode([Reminder].self, from: data)
            else { return [] }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "alarms")
            }
        }
    }

    var calendarScale: Double {
        get { defaults.object(forKey: "calendarScale") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "calendarScale"); notify() }
    }

    // Custom date/time format string for the menu bar (empty = use 24h/seconds toggles)
    var menuBarDateFormat: String {
        get { defaults.string(forKey: "menuBarDateFormat") ?? "HH:mm" }
        set { defaults.set(newValue, forKey: "menuBarDateFormat"); notify() }
    }

    // 0=circle  1=calendar-page  2=SF-symbol  3=weekday-badge
    var menuBarIconStyle: Int {
        get { defaults.object(forKey: "menuBarIconStyle") as? Int ?? 3 }
        set { defaults.set(newValue, forKey: "menuBarIconStyle"); notify() }
    }

    // 0=left of text  1=right of text  2=hidden
    var menuBarIconPosition: Int {
        get { defaults.object(forKey: "menuBarIconPosition") as? Int ?? 1 }
        set { defaults.set(newValue, forKey: "menuBarIconPosition"); notify() }
    }

    // Calendar popover settings
    var calShowEventDots: Bool {
        get { defaults.object(forKey: "calShowEventDots") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "calShowEventDots"); notify() }
    }

    var calColorfulDots: Bool {
        get { defaults.object(forKey: "calColorfulDots") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "calColorfulDots"); notify() }
    }

    var calShowEventLocation: Bool {
        get { defaults.object(forKey: "calShowEventLocation") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "calShowEventLocation"); notify() }
    }

    var calShowInactiveDays: Bool {
        get { defaults.object(forKey: "calShowInactiveDays") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "calShowInactiveDays"); notify() }
    }

    var calShowWeekNumbers: Bool {
        get { defaults.object(forKey: "calShowWeekNumbers") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "calShowWeekNumbers"); notify() }
    }

    var menuBarShowSeconds: Bool {        get { defaults.object(forKey: "menuBarShowSeconds") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "menuBarShowSeconds"); notify() }
    }

    var menuBar24Hour: Bool {
        get {
            if let stored = defaults.object(forKey: "menuBar24Hour") as? Bool { return stored }
            // Default: follow system locale
            let fmt = DateFormatter()
            fmt.locale = Locale.current
            fmt.dateStyle = .none
            fmt.timeStyle = .short
            return !fmt.string(from: Date()).contains(fmt.amSymbol)
        }
        set { defaults.set(newValue, forKey: "menuBar24Hour"); notify() }
    }

    var language: String {
        get { defaults.string(forKey: "language") ?? "zh" }
        set { defaults.set(newValue, forKey: "language"); notify() }
    }

    var windowX: Double {
        get { defaults.object(forKey: "windowX") as? Double ?? 100 }
        set { defaults.set(newValue, forKey: "windowX") }
    }

    var windowY: Double {
        get { defaults.object(forKey: "windowY") as? Double ?? 100 }
        set { defaults.set(newValue, forKey: "windowY") }
    }

    // Path to an active ClocX original skin image file (nil = use built-in code skin)
    var clocxSkinPath: String? {
        get { defaults.string(forKey: "clocxSkinPath") }
        set { defaults.set(newValue, forKey: "clocxSkinPath"); notify() }
    }

    func loadClocXSkin() -> ClocXSkin? {
        guard let path = clocxSkinPath else { return nil }
        return ClocXSkinLoader.load(from: URL(fileURLWithPath: path))
    }

    private func notify() {
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("com.klok.settingsChanged")
}
